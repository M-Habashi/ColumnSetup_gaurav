function [a_next, ast, decision] = fable_auth(b, valid_up, trip_reason, ...
    b_fast, pred_margin, pred_valid, alpha_grid, ast, prm, st_binding, ...
    regime_recal)
%FABLE_AUTH Supervisory authority-factor law driven by the fable OSI.
%
%   [a_next, ast, decision] = fable_auth(b, valid_up, trip_reason, ...
%       b_fast, pred_margin, pred_valid, alpha_grid, ast, prm, st_binding)
%
% Inputs (per OSI step, cadence prm.dt_update):
%   b           - slow margin estimate (NaN when the OSI has no evidence)
%   valid_up    - true when the margin is backed by coherent input (ST
%                 branch): required to allow model-guided recovery speed
%   trip_reason - fast-path trip from fable_osi: 0 none, 1 quiet-band
%                 burst (divergence-like), 2 fast ST margin collapse
%   b_fast      - fast short-memory margin (NaN if unavailable): sizes the
%                 immediate drop on a type-2 trip
%   pred_margin - margin predicted at relative loop-gain multipliers
%                 alpha_grid (from fable_osi info); the loop at multiplier
%                 alpha has authority alpha*ast.a
%   pred_valid  - whether pred_margin is usable this update
%   ast         - state struct from fable_auth('state', prm)
%   prm         - parameter struct from fable_auth('params', ...) overrides
%   st_binding  - true when the margin deficit sits inside the coherently
%                 observed band (info.st_binding): then the predicted safe
%                 authority covers the problem and bounds the shed, which
%                 prevents pointless slam-to-floor overshoot. A residual-
%                 driven deficit is outside the prediction's sight, so the
%                 shed compounds until the evidence clears.
%
% Also:  prm = fable_auth('params', override);  ast = fable_auth('state', prm)
%
% Design contract (safety first, then performance):
%   1. Fast trips act IMMEDIATELY (within one 0.125 s step):
%      - burst trips (reason 1) compound x trip_drop every step while the
%        divergence evidence persists;
%      - fast-ST trips (reason 2) apply ONE decisive drop sized by the fast
%        margin, a*(b_fast/target)^power_law (at most trip_drop), then hand
%        regulation to the confirmed path - no pointless slam to the floor;
%        the trip re-arms after the cooldown.
%   2. NEVER increase authority on the same update that shows a deficit,
%      during the post-event cooldown, or while the margin is NaN.
%   3. Confirmed deficit => move DOWN toward the better (smaller) of a
%      model-predicted safe authority and a power-law fallback, rate
%      limited; a severe deficit acts immediately.
%   4. Recovery is slow, hold-time gated, and CAPPED by the predicted safe
%      authority when a prediction exists. Without coherent input the law
%      still probes upward, but three times slower, so a silent record can
%      recover while the fast guard and residual branch stand watch
%      ("probe and verify").
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
            a_next = struct('a', valid_up.a_init, 'b_filt', NaN, ...
                'below_n', 0, 'above_n', 0, 'trip_cool', 0, ...
                'blind_hops', 0, 'a_latch', valid_up.a_max, ...
                'trip_armed', true, 'trip_age', 1e6, ...
                'a_pre_trip', valid_up.a_init);
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
a = ast.a;
ast.trip_age = min(ast.trip_age + 1, 1e6);

% --- trip undo: a confirmed excitation-regime recalibration right after a
% fast trip means the trip WAS the transition, not the plant - restore ----
if regime_recal && ast.trip_age <= round(2.5/prm.dt_update)
    a = max(a, ast.a_pre_trip);
    ast.a_latch = prm.a_max;
    ast.trip_cool = 0;
    ast.trip_armed = true;
    ast.a = min(max(a, prm.a_min), prm.a_max);
    a_next = ast.a;
    return
end

% --- fast trips: act immediately, regardless of margin validity ---------
if trip_reason == 1
    % quiet-band burst: divergence-like evidence - compound every step
    if ast.trip_age > round(prm.trip_cool_s/prm.dt_update)
        ast.a_pre_trip = a;    % remember for a possible regime undo
    end
    ast.trip_age = 0;
    a = max(prm.a_min, a*prm.trip_drop);
    ast.trip_cool = round(prm.trip_cool_s/prm.dt_update);
    ast.trip_armed = false;
    ast.above_n = 0;
    ast.below_n = 0;
    decision = 4;
    ast.a = min(max(a, prm.a_min), prm.a_max);
    % a trip is hard evidence the plant changed while the prediction may
    % not see where: latch the recovery ceiling (slowly forgotten)
    ast.a_latch = min(ast.a_latch, max(prm.latch_relax*ast.a, 2*prm.a_min));
    a_next = ast.a;
    return
elseif trip_reason == 2 && ast.trip_armed
    % fast ST collapse: ONE decisive drop sized by the fast margin, then
    % the confirmed path (which sees the fast dip in b) regulates
    ast.a_pre_trip = a;
    ast.trip_age = 0;
    r = prm.trip_drop;
    if isfinite(b_fast)
        r = min(prm.trip_drop, ...
            (max(b_fast, 0.05)/prm.target)^prm.power_law);
    end
    a = max(prm.a_min, a*r);
    ast.trip_cool = round(prm.trip_cool_s/prm.dt_update);
    ast.trip_armed = false;
    ast.above_n = 0;
    decision = 4;
    ast.a = min(max(a, prm.a_min), prm.a_max);
    ast.a_latch = min(ast.a_latch, max(prm.latch_relax*ast.a, 2*prm.a_min));
    a_next = ast.a;
    return
end

if ast.trip_cool > 0
    ast.trip_cool = ast.trip_cool - 1;
    if ast.trip_cool == 0
        ast.trip_armed = true;
    end
end

% --- no evidence: hold ----------------------------------------------------
if isnan(b)
    ast.blind_hops = ast.blind_hops + 1;
    ast.above_n = 0;
    a_next = a;
    return
end
ast.blind_hops = 0;

if isnan(ast.b_filt)
    ast.b_filt = b;
else
    ast.b_filt = (1 - prm.filt_alpha)*ast.b_filt + prm.filt_alpha*b;
end

severe = b < prm.sev_frac*prm.target;
low = b < prm.target;
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
%   a_pred_up: largest alpha reachable from 1 through safe values -> caps
%              recovery
a_pred_dn = NaN;
a_pred_up = NaN;
if pred_valid
    okp = pred_margin >= prm.target + prm.pred_guard;
    [~, i1] = min(abs(alpha_grid - 1));
    j = i1;
    while j >= 1 && ~okp(j)
        j = j - 1;
    end
    if j >= 1
        a_pred_dn = alpha_grid(j)*a;
    else
        a_pred_dn = alpha_grid(1)*a;   % nothing predicted safe: max shed
    end
    if okp(i1)
        j = i1;
        while j < numel(alpha_grid) && okp(j+1)
            j = j + 1;
        end
        a_pred_up = alpha_grid(j)*a;
    else
        a_pred_up = a;                 % current point not predicted safe
    end
end

if severe || ast.below_n >= prm.down_confirm_n
    % ---------------- confirmed deficit: shed authority -----------------
    a_pl = a*(max(b, 0.02)/prm.target)^prm.power_law;
    a_tgt = min(a_pl, a);
    if ~severe && st_binding && pred_valid && ~isnan(a_pred_dn) ...
            && a_pred_dn < a
        % the model sees the binding frequency: shed toward the predicted
        % safe authority instead of compounding to the floor. If the
        % prediction is optimistic the margin stays low and the refreshed
        % prediction keeps walking the target down - it self-corrects.
        a_tgt = max(a_tgt, prm.pred_floor_frac*a_pred_dn);
    end
    rate = prm.down_rate;
    if severe
        rate = prm.sev_down_rate;
        decision = 2;
    else
        decision = 1;
    end
    a = max(a_tgt, a - rate*prm.dt_update);
    if ~st_binding
        % residual/blind deficit: the hazard band is invisible, so block
        % recovery for a while and LATCH a slowly-forgetting authority
        % ceiling - do not re-probe known-bad territory right away.
        ast.trip_cool = max(ast.trip_cool, ...
            round(prm.trip_cool_s/prm.dt_update));
        ast.a_latch = min(ast.a_latch, ...
            max(prm.latch_relax*a, 2*prm.a_min));
    end
    ast.above_n = 0;
elseif b >= prm.target + prm.up_db && ast.trip_cool <= 0 && a < prm.a_max
    % ---------------- healthy: hold-gated slow recovery -----------------
    ast.above_n = ast.above_n + 1;
    hold_n = max(1, round(prm.up_hold_s/prm.dt_update));
    if ast.above_n >= hold_n
        if valid_up
            rate = prm.up_rate;
        else
            rate = prm.up_rate_blind;
        end
        a_cap = min(prm.a_max, ast.a_latch);
        if pred_valid && ~isnan(a_pred_up)
            % stop short of the predicted boundary: absorbs estimator lag
            % and mild prediction optimism instead of limit-cycling on it
            a_cap = min(a_cap, max(prm.pred_floor_frac*a_pred_up, a));
        end
        a = min(a_cap, a + rate*prm.dt_update);
        decision = 3;
    end
else
    % deadband between target and target+up_db: hold, reset the up timer
    ast.above_n = 0;
end

% the latched ceiling forgets slowly, so a healed plant can recover fully
ast.a_latch = ast.a_latch ...
    + (prm.a_max - ast.a_latch)*prm.dt_update/prm.latch_decay_tau_s;

ast.a = min(max(a, prm.a_min), prm.a_max);
a_next = ast.a;
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.30, ...        % margin floor to defend
    'up_db', 0.04, ...         % recovery hysteresis above target
    'sev_frac', 0.60, ...      % b < sev_frac*target => severe (immediate)
    'down_confirm_n', 3, ...   % consecutive low updates to confirm
    'a_min', 0.08, ...
    'a_max', 1.00, ...
    'a_init', 1.00, ...
    'dt_update', 0.125, ...    % seconds between OSI steps
    'down_rate', 1.0, ...      % authority units per second (confirmed)
    'sev_down_rate', 3.0, ...  % severe shed rate
    'up_rate', 0.02, ...       % model-verified recovery (per second)
    'up_rate_blind', 0.007, ...% probe-and-verify recovery (no coherence)
    'up_hold_s', 3.0, ...      % healthy dwell before any recovery
    'power_law', 1.5, ...
    'pred_guard', 0.03, ...    % predicted margin must clear target+guard
    'pred_floor_frac', 0.90, ...% shed floor / recovery cap vs predicted-safe a
    'latch_relax', 1.15, ...   % latched ceiling relative to post-shed a
    'latch_decay_tau_s', 200, ...% forgetting time of the latched ceiling
    'trip_drop', 0.60, ...     % multiplicative drop on a fast-guard trip
    'trip_cool_s', 5.0, ...
    'filt_alpha', 0.3);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('fable_auth:UnknownParam', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
