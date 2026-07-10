function [a_next, ast, decision] = fable_auth_cand(b, valid_up, trip_reason, ...
    b_fast, pred_margin, pred_valid, alpha_grid, ast, prm, st_binding, ...
    regime_recal)
%FABLE_AUTH_CAND Candidate law: healed-evidence-aware blind recovery.
% Differences vs fable_auth (HEAD):
%   * latch_decay_tau_s default back to 120 s (post-shed caution restored)
%   * ast.heal_n counts consecutive published margins >= target+up_deadband;
%     it survives evidence loss (NaN) and resets on any deficit or trip.
%   * When evidence disappears AFTER heal_confirm_n healthy hops, the blind
%     probe starts after blind_up_after_heal_s (not blind_up_after_s), runs
%     at up_rate (not up_rate_blind), and the latch is released with
%     heal_latch_tau_s. Otherwise the classic cautious probe applies.
%   * Confirmed-healed measured recovery also decays the latch at the heal
%     tau, and a latch within min_step/2 of a_max snaps to a_max (removes
%     the asymptotic stall just below full authority).
%
%   [a_next, ast, decision] = fable_auth(b, valid_up, trip_reason, ...
%       b_fast, pred_margin, pred_valid, alpha_grid, ast, prm, st_binding, ...
%       regime_recal)
%
% REGULATION CONTRACT (what the law does):
%   The law REGULATES the reported OSI margin b onto prm.target:
%     * b >= target          -> authority recovers toward a_max (= 1), and
%                               stays there while the margin holds. A healthy
%                               loop therefore runs at FULL authority.
%     * b <  target          -> authority sheds multiplicatively,
%                               a <- a*(b/target)^down_power, rate-limited,
%                               until the margin climbs back to the target.
%     * b << target (severe) -> immediate shed, no confirmation, no commit
%                               gate: crashes are caught within one update.
%     * fast-guard trips     -> act within one 0.125 s step (see below).
%   The closed loop settles where b ~= target (or at a_max when the loop is
%   healthier than the target even at full authority).
%
% Inputs (per OSI step, cadence prm.dt_update):
%   b           - slow margin estimate (NaN when the OSI has no evidence)
%   valid_up    - true when the margin is backed by coherent input (ST
%                 branch): allows the faster model-verified recovery rate
%   trip_reason - fast-path trip from fable_osi: 0 none, 1 quiet-band
%                 burst (divergence-like), 2 fast ST margin collapse
%   b_fast      - fast short-memory margin (NaN if unavailable): sizes the
%                 immediate drop on a type-2 trip
%   pred_margin - margin predicted at relative loop-gain multipliers
%                 alpha_grid (from fable_osi info); the loop at multiplier
%                 alpha has authority alpha*ast.a
%   pred_valid  - whether pred_margin is usable this update
%   ast         - state struct from fable_auth('state', prm)
%   prm         - parameter struct from fable_auth('params', overrides)
%   st_binding  - true when the margin deficit sits inside the coherently
%                 observed band (info.st_binding): then the predicted safe
%                 authority covers the problem and bounds the shed. A
%                 residual-driven deficit is outside the prediction's
%                 sight, so the shed compounds until the evidence clears.
%   regime_recal- one-shot flag from fable_osi: an excitation-regime
%                 recalibration was just confirmed (used to UNDO a fast
%                 trip that was really the excitation transition)
%
% Also:  prm = fable_auth('params', override);  ast = fable_auth('state', prm)
%
% ------------------------------------------------------------------------
% TUNING GUIDE - every knob, what it does, and which way to turn it.
% (Defaults in makeParams below; override any subset via the 'params' call.)
%
%   REGULATION SETPOINT
%   target          The OSI level to defend/track (default 0.55). Raising
%                   it makes the system run more conservatively (authority
%                   sheds earlier); it must stay below the healthy-loop
%                   margin at full authority or the law will permanently
%                   detune the loop trying to reach an unreachable margin.
%
%   SMOOTHNESS OF THE REGULATED SIGNAL
%   b_filt_tau_s    EMA time constant applied to b before it sizes sheds
%                   and gates recovery. Larger = smoother, more constant
%                   authority; smaller = more reactive. 0 disables the
%                   filter entirely (raw b drives everything). Drop
%                   DETECTION always also watches the raw b, so smoothing
%                   never delays catching a genuine collapse by more than
%                   down_confirm_n updates.
%
%   DROP (SHED) BEHAVIOR - how fast/deep authority falls on a deficit
%   down_deadband   Margin must fall below target - down_deadband to count
%                   as a deficit. Widen to ignore tiny grazes of the
%                   target (less flicker), narrow for tight regulation.
%   down_confirm_n  Consecutive low updates before a (non-severe) shed
%                   starts. More = fewer false sheds on noise, but adds
%                   n*dt_update of reaction delay.
%   down_power      Exponent of the multiplicative shed
%                   a*(b/target)^down_power. Higher = more aggressive
%                   (deeper) correction per update; 1 = proportional.
%   down_rate       Max shed speed in authority units/s for a confirmed
%                   (non-severe) deficit. This is the main "catch drops
%                   fast" knob: raise it to shed faster.
%   down_settle_s   The margin estimate lags the loop by its analysis-
%                   window flush, so each shed is SIZED ONCE from current
%                   evidence and then held for down_settle_s before being
%                   re-sized (re-deriving a multiplicative shed from the
%                   same stale reading every step would compound one dip
%                   into a slam to the floor). Lower = more aggressive
%                   re-shedding, higher (toward the OSI window length) =
%                   gentler, more staircase-like sheds.
%   re_shed_delta   A margin reading this much BELOW the one that sized
%                   the active shed re-sizes it immediately (fresh
%                   evidence of continued decline bypasses the settle
%                   hold). Lower = more reactive to genuine decline.
%   sev_frac        b < sev_frac*target (RAW b, unfiltered) is treated as
%                   severe: immediate shed, bypassing confirmation, the
%                   commit gate and the ordinary rate limit.
%   sev_down_rate   Shed speed for severe deficits (units/s). Keep high;
%                   this is the emergency path.
%
%   RECOVERY BEHAVIOR - how authority comes back
%   up_deadband     Margin must exceed target + up_deadband before
%                   recovery is considered (hysteresis). Widen to make
%                   recovery more cautious and kill target-hugging
%                   oscillation; narrow for faster reclaim.
%   up_hold_s       The margin must hold above the recovery threshold this
%                   long before authority starts moving up. Longer = more
%                   constant authority, later recovery.
%   up_rate         Base recovery speed (units/s) when the margin is
%                   model-verified (coherent input present).
%   up_rate_blind   Recovery speed with NO coherent input ("probe and
%                   verify"): the loop feels its way up while the burst
%                   guard and residual branch stand watch. Keep several
%                   times slower than up_rate.
%   up_prop         Surplus-proportional recovery boost: the effective up
%                   rate is up_rate*(1 + up_prop*(b_filt - target -
%                   up_deadband)/target). 0 = constant-rate recovery;
%                   higher = sprint back when the margin is comfortably
%                   high, creep when barely above target. This is the
%                   "recovery may be fast or slow, whatever performs"
%                   knob.
%   blind_up_after_s  Blind-probe recovery: after this long with NO
%                   margin evidence at all (b = NaN because the tap is
%                   idle / the evidence gate is disarmed), authority
%                   creeps back up at up_rate_blind, capped by the
%                   post-event latch and a_max. A quiet loop cannot be
%                   hurt by a higher authority, and if excitation
%                   returns degraded the severe/trip paths shed within
%                   one or two updates. Inf (default) disables it and
%                   restores the classic "no evidence -> hold forever"
%                   behavior. This is what lets authority come back
%                   after a shed even when the test goes quiet.
%
%   ANTI-FLICKER COMMIT GATE
%   min_step        The COMMITTED authority (what the loop sees) only
%                   moves when the internally regulated value has drifted
%                   at least this far from it. Bigger = steppier, more
%                   constant authority (fewer, larger moves); 0 = fully
%                   continuous. Severe sheds and fast trips bypass the
%                   gate. Because the internal value keeps integrating,
%                   the gate NEVER deadlocks slow recovery - it just
%                   quantizes it into min_step-sized steps.
%
%   MODEL-PREDICTED SAFE AUTHORITY (from the fable_osi prediction curve)
%   use_pred        1 = use the prediction to floor sheds / cap recovery,
%                   0 = pure power-law regulation (cheaper, more shed
%                   overshoot). Turn off only if the Speedgoat budget
%                   demands disabling the prediction grid in the OSI too.
%   pred_guard      Predicted margin must clear target + pred_guard to
%                   count as safe. This is ALSO the recovery standoff:
%                   authority may climb up to (but not past) the
%                   interpolated boundary where the predicted margin
%                   crosses target + pred_guard. Widen if the prediction
%                   proves optimistic on your rig.
%   pred_floor_frac Shed floor as a fraction of the predicted-safe
%                   authority (0.90 = a confirmed shed stops 10% below
%                   the predicted-safe point instead of slamming to the
%                   power-law floor). Applies to the DOWN path only.
%
%   FAST-TRIP RESPONSE (driven by fable_osi's fast guards)
%   trip_drop       Multiplicative drop on a trip (0.60 = shed 40%
%                   instantly). Burst trips compound this every step while
%                   the divergence evidence persists.
%   trip_power      A fast-ST trip is sized a*(b_fast/target)^trip_power
%                   (never milder than trip_drop allows). Higher = deeper
%                   drop for a given fast-margin reading.
%   trip_cool_s     Cooldown after a trip during which recovery is blocked
%                   and the trip re-arms.
%   trip_undo_s     A trip followed within this window by a confirmed
%                   excitation-regime recalibration is undone (the "trip"
%                   was the test phase changing, not the plant).
%   self_move_gate_s / self_move_frac
%                   A fast-ST (FRF-change) trip is honored only when the
%                   COMMITTED authority has been steady - moved less than
%                   self_move_frac (relative) per update - for the last
%                   self_move_gate_s. The estimator watches the total
%                   loop, which includes the authority itself: the law's
%                   own moves read as an FRF change and would otherwise
%                   self-trip. Real damage arrives while a is static, so
%                   the gate costs nothing there; burst (divergence)
%                   trips are never gated.
%
%   POST-EVENT CAUTION (latched ceiling)
%   latch_relax     After a trip or a residual-driven (invisible-band)
%                   shed, recovery is capped at latch_relax x the post-
%                   shed authority: hard evidence of a plant change is not
%                   re-probed immediately.
%   latch_decay_tau_s  How slowly that latched ceiling is forgotten
%                   (seconds). Raise for more caution after events; lower
%                   to let a healed plant recover sooner.
%
%   BOUNDS / CADENCE
%   a_min, a_max    Authority floor and ceiling (a_max is also the value
%                   held whenever b >= target and nothing is latched).
%   a_init          Startup authority (recommend 1.0: the law defends the
%                   margin, starting detuned is not needed).
%   dt_update       Seconds between calls (the OSI step cadence).
% ------------------------------------------------------------------------
%
% Design contract (safety first, then performance):
%   1. Fast trips act IMMEDIATELY (within one 0.125 s step).
%   2. NEVER increase authority on the same update that shows a deficit,
%      during the post-event cooldown, or while the margin is NaN.
%   3. Severe deficits (raw b < sev_frac*target) shed immediately;
%      ordinary deficits need down_confirm_n consecutive low updates.
%   4. Recovery is hysteretic (up_deadband), hold-time gated (up_hold_s)
%      and capped by the predicted-safe authority and the post-event
%      latch. Without coherent input recovery still probes upward, slower.
%   5. All state is scalar; the law is codegen-friendly.
%
% decision codes: 0 hold, 1 down, 2 severe down, 3 up, 4 fast trip.

if ischar(b)
    switch lower(b)
        case 'params'
            if nargin >= 2
                a_next = makeParams(valid_up);
            else
                a_next = makeParams(struct());
            end
        case 'state'
            a_next = struct('a', valid_up.a_init, ...
                'a_cont', valid_up.a_init, ...
                'b_filt', NaN, ...
                'below_n', 0, 'above_n', 0, 'trip_cool', 0, ...
                'blind_hops', 0, 'a_latch', valid_up.a_max, ...
                'trip_armed', true, 'trip_age', 1e6, ...
                'a_pre_trip', valid_up.a_init, ...
                'a_shed_tgt', NaN, 'b_shed_ref', NaN, ...
                'shed_settle', 0, 'move_age', 1e6, 'heal_n', 0);
        otherwise
            error('fable_auth:UnknownCommand', ...
                'Use ''params'', ''state'', or the numeric step call.')
    end
    ast = [];
    decision = [];
    return
end

if nargin < 11
    regime_recal = false;
end

decision = 0;
a_entry = ast.a;
ast.trip_age = min(ast.trip_age + 1, 1e6);

% --- trip undo: a confirmed excitation-regime recalibration right after a
% fast trip means the trip WAS the transition, not the plant - restore ----
if regime_recal && ast.trip_age <= round(prm.trip_undo_s/prm.dt_update)
    ast.a_cont = max(ast.a_cont, ast.a_pre_trip);
    ast.a_latch = prm.a_max;
    ast.trip_cool = 0;
    ast.trip_armed = true;
    ast.a_cont = min(max(ast.a_cont, prm.a_min), prm.a_max);
    ast.a = ast.a_cont;              % commit (bypass the min_step gate)
    ast = trackMove(ast, a_entry, prm);
    a_next = ast.a;
    return
end

% --- fast trips: act immediately, regardless of margin validity ---------
if trip_reason == 1
    % quiet-band burst: divergence-like evidence - compound every step
    if ast.trip_age > round(prm.trip_cool_s/prm.dt_update)
        ast.a_pre_trip = ast.a_cont;   % remember for a possible regime undo
    end
    ast.trip_age = 0;
    ast.a_cont = max(prm.a_min, ast.a_cont*prm.trip_drop);
    ast.trip_cool = round(prm.trip_cool_s/prm.dt_update);
    ast.trip_armed = false;
    ast.above_n = 0;
    ast.below_n = 0;
    ast.heal_n = 0;
    decision = 4;
    ast.a_cont = min(max(ast.a_cont, prm.a_min), prm.a_max);
    % a trip is hard evidence the plant changed while the prediction may
    % not see where: latch the recovery ceiling (slowly forgotten)
    ast.a_latch = min(ast.a_latch, ...
        max(prm.latch_relax*ast.a_cont, 2*prm.a_min));
    ast.a = ast.a_cont;              % commit (bypass the min_step gate)
    ast = trackMove(ast, a_entry, prm);
    a_next = ast.a;
    return
elseif trip_reason == 2 && ast.trip_armed ...
        && ast.move_age >= round(prm.self_move_gate_s/prm.dt_update)
    % the FRF-change detector watches the TOTAL loop, which includes the
    % authority: honor its trip only when the committed authority has
    % been steady, so the law never trips on its own motion (the margin
    % dip still feeds the ordinary regulation path either way)
    % fast ST collapse: ONE decisive drop sized by the fast margin, then
    % the confirmed path (which sees the fast dip in b) regulates
    ast.a_pre_trip = ast.a_cont;
    ast.trip_age = 0;
    r = prm.trip_drop;
    if isfinite(b_fast)
        r = min(prm.trip_drop, ...
            (max(b_fast, 0.05)/prm.target)^prm.trip_power);
    end
    ast.a_cont = max(prm.a_min, ast.a_cont*r);
    ast.trip_cool = round(prm.trip_cool_s/prm.dt_update);
    ast.trip_armed = false;
    ast.above_n = 0;
    ast.heal_n = 0;
    decision = 4;
    ast.a_cont = min(max(ast.a_cont, prm.a_min), prm.a_max);
    ast.a_latch = min(ast.a_latch, ...
        max(prm.latch_relax*ast.a_cont, 2*prm.a_min));
    ast.a = ast.a_cont;              % commit (bypass the min_step gate)
    ast = trackMove(ast, a_entry, prm);
    a_next = ast.a;
    return
end

if ast.trip_cool > 0
    ast.trip_cool = ast.trip_cool - 1;
    if ast.trip_cool == 0
        ast.trip_armed = true;
    end
end

% --- no evidence: hold, then probe ------------------------------------------
if isnan(b)
    ast.blind_hops = ast.blind_hops + 1;
    ast.above_n = 0;
    % blind-probe recovery: after blind_up_after_s of continuous
    % no-evidence (idle tap / gate disarmed) creep authority back up at
    % the probe rate. The burst guard keeps watching the response, any
    % trip sheds immediately, and once evidence returns the ordinary
    % regulation path takes over on the next update.
    % CANDIDATE: if the LAST published evidence before the blank was
    % heal_confirm_n consecutive healthy readings, the loop went quiet in
    % a verified-healthy state: probe sooner (blind_up_after_heal_s), at
    % the model-verified rate, and release the caution latch quickly.
    healed = ast.heal_n >= prm.heal_confirm_n;
    if healed
        blind_after = prm.blind_up_after_heal_s;
        blind_rate = prm.up_rate;
        latch_tau = prm.heal_latch_tau_s;
    else
        blind_after = prm.blind_up_after_s;
        blind_rate = prm.up_rate_blind;
        latch_tau = prm.latch_decay_tau_s;
    end
    if isfinite(blind_after) && ast.trip_cool <= 0 ...
            && ast.blind_hops >= round(blind_after/prm.dt_update) ...
            && ast.a_cont < prm.a_max
        a_before = ast.a_cont;
        ast.a_latch = ast.a_latch + (prm.a_max - ast.a_latch) ...
            *prm.dt_update/latch_tau;
        if ast.a_latch > prm.a_max - prm.min_step/2
            ast.a_latch = prm.a_max;   % kill the asymptotic stall
        end
        a_cap = min(prm.a_max, ast.a_latch);
        ast.a_cont = min(a_cap, ...
            ast.a_cont + blind_rate*prm.dt_update);
        ast.a_cont = min(max(ast.a_cont, prm.a_min), prm.a_max);
        if abs(ast.a_cont - ast.a) >= prm.min_step ...
                || (ast.a_cont >= prm.a_max - 1e-12 && ast.a < prm.a_max)
            ast.a = ast.a_cont;
        end
        if ast.a_cont > a_before
            decision = 3;
        end
    end
    ast = trackMove(ast, a_entry, prm);
    a_next = ast.a;
    return
end
ast.blind_hops = 0;

% --- smoothness filter on the regulated margin ----------------------------
if isnan(ast.b_filt)
    ast.b_filt = b;
else
    ast.b_filt = (1 - prm.filt_alpha)*ast.b_filt + prm.filt_alpha*b;
end

% severe watches the RAW margin (a crash must not wait for the filter);
% deficit detection watches BOTH raw and filtered so smoothing can shape
% the response without hiding a genuine drop
severe = b < prm.sev_frac*prm.target;
low = min(b, ast.b_filt) < prm.target - prm.down_deadband;
% CANDIDATE: consecutive-healthy counter (raw published margin); survives
% evidence loss, resets on any sub-threshold reading, deficit, or trip
if b >= prm.target + prm.up_deadband
    ast.heal_n = min(ast.heal_n + 1, 1e6);
else
    ast.heal_n = 0;
end
if low
    ast.below_n = ast.below_n + 1;
else
    ast.below_n = 0;
end

% Predicted safe authorities from the relative margin curve. The chordal
% margin is NOT monotone in loop gain (a huge-gain loop is again "far"
% from -1 pointwise), and authority moves continuously through every
% intermediate value - so only the contiguous safe set around the current
% operating point (alpha = 1) is admissible:
%   a_pred_dn: first safe alpha at/below 1  -> bounds a confirmed shed
%   a_pred_up: the safe-interval BOUNDARY above 1 (linearly interpolated
%              between grid points so a coarse grid cannot strand the
%              recovery below a genuinely-safe full authority) -> caps
%              recovery. The pred_guard margin slack is the standoff; no
%              additional haircut is applied on the way up.
a_pred_dn = NaN;
a_pred_up = NaN;
if pred_valid && prm.use_pred ~= 0
    thr = prm.target + prm.pred_guard;
    okp = pred_margin >= thr;
    [~, i1] = min(abs(alpha_grid - 1));
    j = i1;
    while j >= 1 && ~okp(j)
        j = j - 1;
    end
    if j >= 1
        a_pred_dn = alpha_grid(j)*ast.a_cont;
    else
        a_pred_dn = alpha_grid(1)*ast.a_cont;  % nothing predicted safe
    end
    if okp(i1)
        j = i1;
        while j < numel(alpha_grid) && okp(j+1)
            j = j + 1;
        end
        if j < numel(alpha_grid) ...
                && pred_margin(j) > pred_margin(j+1) + 1e-12
            % interpolate the alpha where the predicted margin crosses thr
            frac = (pred_margin(j) - thr) ...
                /(pred_margin(j) - pred_margin(j+1));
            alpha_b = alpha_grid(j) ...
                + frac*(alpha_grid(j+1) - alpha_grid(j));
        else
            alpha_b = alpha_grid(j);
        end
        a_pred_up = alpha_b*ast.a_cont;
    else
        a_pred_up = ast.a_cont;        % current point not predicted safe
    end
end

if ast.shed_settle > 0
    ast.shed_settle = ast.shed_settle - 1;
end

commit = false;
if severe || ast.below_n >= prm.down_confirm_n
    % ---------------- confirmed deficit: shed authority -----------------
    if severe
        b_size = b;                    % act on the fast raw signal
    else
        b_size = ast.b_filt;           % act on the smooth signal
    end
    % (Re)size the shed from CURRENT evidence only when the estimator has
    % had time to absorb the previous action (down_settle_s), or when the
    % margin made a fresh move lower (re_shed_delta). The margin estimate
    % lags the loop by its analysis-window flush; re-deriving a
    % multiplicative shed from the same stale reading every step would
    % compound one dip into a slam to the floor.
    fresh = isnan(ast.b_shed_ref) ...
        || b_size < ast.b_shed_ref - prm.re_shed_delta;
    if fresh || ast.shed_settle <= 0
        a_pl = ast.a_cont*(max(b_size, 0.02)/prm.target)^prm.down_power;
        a_tgt = min(a_pl, ast.a_cont);
        if st_binding && ~isnan(a_pred_dn) && a_pred_dn < ast.a_cont
            % the model sees the binding frequency: shed toward the
            % predicted safe authority instead of compounding to the
            % floor. If the prediction is optimistic the margin stays low
            % and the refreshed prediction keeps walking the target down
            % - it self-corrects.
            a_tgt = max(a_tgt, prm.pred_floor_frac*a_pred_dn);
        end
        ast.a_shed_tgt = a_tgt;
        ast.b_shed_ref = b_size;
        ast.shed_settle = max(1, round(prm.down_settle_s/prm.dt_update));
    end
    if severe
        rate = prm.sev_down_rate;
        decision = 2;
        commit = true;                 % emergencies bypass the commit gate
    else
        rate = prm.down_rate;
        decision = 1;
    end
    ast.a_cont = min(ast.a_cont, ...
        max(ast.a_shed_tgt, ast.a_cont - rate*prm.dt_update));
    if ~st_binding
        % residual/blind deficit: the hazard band is invisible, so block
        % recovery for a while and LATCH a slowly-forgetting authority
        % ceiling - do not re-probe known-bad territory right away.
        ast.trip_cool = max(ast.trip_cool, ...
            round(prm.trip_cool_s/prm.dt_update));
        ast.a_latch = min(ast.a_latch, ...
            max(prm.latch_relax*ast.a_cont, 2*prm.a_min));
    end
    ast.above_n = 0;
elseif ast.b_filt >= prm.target + prm.up_deadband && ast.trip_cool <= 0 ...
        && ast.a_cont < prm.a_max
    % ---------------- healthy: hold-gated recovery ----------------------
    ast.a_shed_tgt = NaN;              % the deficit is over: next shed
    ast.b_shed_ref = NaN;              % gets sized from fresh evidence
    ast.above_n = ast.above_n + 1;
    hold_n = max(1, round(prm.up_hold_s/prm.dt_update));
    if ast.above_n >= hold_n
        if valid_up
            rate = prm.up_rate;
        else
            rate = prm.up_rate_blind;
        end
        % surplus-proportional boost: sprint when comfortably healthy,
        % creep when barely above target
        surplus = max(0, ast.b_filt - prm.target - prm.up_deadband);
        rate = rate*(1 + prm.up_prop*surplus/prm.target);
        a_cap = min(prm.a_max, ast.a_latch);
        if ~isnan(a_pred_up)
            % never climb past the predicted safe boundary (which already
            % stands pred_guard of margin short of the target crossing);
            % the up_deadband hysteresis supplies the standoff below it
            a_cap = min(a_cap, max(a_pred_up, ast.a_cont));
        end
        ast.a_cont = min(a_cap, ast.a_cont + rate*prm.dt_update);
        decision = 3;
    end
else
    % deadband between target and target+up_deadband: hold, reset up timer
    ast.above_n = 0;
    if ~low
        ast.a_shed_tgt = NaN;
        ast.b_shed_ref = NaN;
    end
end

% the latched ceiling forgets slowly, so a healed plant can recover fully;
% CANDIDATE: confirmed healthy evidence releases the caution latch at the
% fast heal tau instead of waiting out the slow decay
if ast.heal_n >= prm.heal_confirm_n
    latch_tau = prm.heal_latch_tau_s;
else
    latch_tau = prm.latch_decay_tau_s;
end
ast.a_latch = ast.a_latch ...
    + (prm.a_max - ast.a_latch)*prm.dt_update/latch_tau;
if ast.a_latch > prm.a_max - prm.min_step/2
    ast.a_latch = prm.a_max;           % kill the asymptotic stall
end

ast.a_cont = min(max(ast.a_cont, prm.a_min), prm.a_max);

% --- anti-flicker commit gate ---------------------------------------------
% The loop only sees ast.a. It follows the internally regulated a_cont in
% steps of at least min_step (bounds always commit so the gate can never
% strand the authority just short of a_min/a_max).
if commit ...
        || abs(ast.a_cont - ast.a) >= prm.min_step ...
        || (ast.a_cont <= prm.a_min + 1e-12 && ast.a > prm.a_min) ...
        || (ast.a_cont >= prm.a_max - 1e-12 && ast.a < prm.a_max)
    ast.a = ast.a_cont;
end
ast = trackMove(ast, a_entry, prm);
a_next = ast.a;
end

function ast = trackMove(ast, a_entry, prm)
% age of the last material COMMITTED-authority move (self-motion gate for
% the fast FRF-change trip)
if abs(ast.a - a_entry) > prm.self_move_frac*max(a_entry, prm.a_min)
    ast.move_age = 0;
else
    ast.move_age = min(ast.move_age + 1, 1e6);
end
end

function prm = makeParams(override)
% Defaults tuned for the RTHS column rig at dt_update = 0.125 s.
% See the TUNING GUIDE in the header for what each knob does.
prm = struct( ...
    'target', 0.55, ...        % OSI level to regulate onto
    'a_min', 0.08, ...
    'a_max', 1.00, ...
    'a_init', 1.00, ...
    'dt_update', 0.125, ...    % seconds between OSI steps
    'b_filt_tau_s', 0.4, ...   % margin smoothing (0 = off)
    'down_deadband', 0.01, ... % dead zone below target
    'down_confirm_n', 2, ...   % consecutive low updates to confirm
    'down_power', 1.5, ...     % shed aggressiveness exponent
    'down_rate', 2.0, ...      % max confirmed shed speed (units/s)
    'down_settle_s', 1.25, ... % hold a sized shed this long before resizing
    're_shed_delta', 0.02, ... % fresh-evidence margin drop that resizes now
    'sev_frac', 0.60, ...      % raw b < sev_frac*target => severe
    'sev_down_rate', 8.0, ...  % severe shed speed (units/s)
    'up_deadband', 0.02, ...   % recovery hysteresis above target
    'up_hold_s', 1.5, ...      % healthy dwell before recovery starts
    'up_rate', 0.08, ...       % model-verified recovery speed (units/s)
    'up_rate_blind', 0.02, ... % probe-and-verify recovery (no coherence)
    'up_prop', 3.0, ...        % surplus-proportional recovery boost
    'blind_up_after_s', Inf, ...% blind-probe recovery delay (Inf = hold)
    'min_step', 0.02, ...      % commit gate (0 = continuous authority)
    'use_pred', 1, ...         % consult the predicted-safe authority
    'pred_guard', 0.03, ...    % predicted margin must clear target+guard
    'pred_floor_frac', 0.90, ...% shed floor / recovery cap vs predicted a
    'trip_drop', 0.60, ...     % multiplicative drop on a fast-guard trip
    'trip_power', 1.5, ...     % fast-ST trip sizing exponent
    'trip_cool_s', 5.0, ...
    'trip_undo_s', 2.5, ...    % regime-recal window that undoes a trip
    'self_move_gate_s', 1.5, ...% authority must be steady this long for a
    ...                        % fast-ST trip to be honored (anti self-trip)
    'self_move_frac', 0.02, ...% relative move that counts as "not steady"
    'latch_relax', 1.15, ...   % latched ceiling relative to post-shed a
    'latch_decay_tau_s', 120, ...% forgetting time of the latched ceiling
    'heal_confirm_n', 3, ...   % consecutive healthy hops = verified healed
    'heal_latch_tau_s', 2, ... % latch release once healed is confirmed
    'blind_up_after_heal_s', 1); % blind-probe delay when healed-then-quiet
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('fable_auth:UnknownParam', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
% derived: EMA coefficient for the b filter (1 = no filtering)
if prm.b_filt_tau_s <= 0
    prm.filt_alpha = 1;
else
    prm.filt_alpha = 1 - exp(-prm.dt_update/prm.b_filt_tau_s);
end
end
