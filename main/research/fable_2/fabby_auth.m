function [a_next, ast] = fabby_auth(b, pred, agrid, blind, ast, prm)
%FABBY_AUTH Margin-tracking authority law with model-verified recovery.
%
%   prm = fabby_auth('params', override)
%   ast = fabby_auth('state', prm)
%   [a, ast] = fabby_auth(b, pred, agrid, blind, ast, prm)  % one 0.125 s step
%
% Inputs per step (from fabby_osi): the reported margin b (always finite),
% the authority-prediction curve pred(agrid) - the margin the loop would
% have at relative gain multipliers agrid, model-verified on the driven
% band - and blind in [0,1]: how much of the loop's hazard region the
% prediction canNOT see (populated quiet band = the command does not
% drive the frequencies where this rig goes unstable). The sprint is
% scaled by (1 - blind): a certification that does not cover the hazard
% band is not a certification.
%
% Two states (authority a, recovery confidence conf), one rate equation:
%
%   d ln a / dt = - ( k_dn*d + k_dn2*d^2 )          d = relu(target-b)/target
%                 + k_creep * s                     s = relu(b-target-db_up)/target
%                 + min( k_sprint*ln(alpha_safe), r_max ) * conf
%
%   alpha_safe = how far the prediction path certifies authority may rise
%          from here: the (interpolated) alpha in [1, min(a_max/a,
%          pred_horizon)] where pred crosses target + db_up, walked as a
%          path minimum (the margin is not monotone in loop gain, and
%          authority passes through every intermediate value on its way up);
%   conf = first-order filter of how clearly the CURRENT reading sits
%          above the target: sat( (b - target - conf_off)/conf_w ),
%          tau_conf up / tau_conf_dn down.
%
% Why each term earns its place:
%   * SHED is quadratic in the deficit: a grazing dip (d ~ 0.05) nibbles
%     at ~0.3 ln/s while a collapsing reading (d ~ 0.4) sheds at ~5 ln/s.
%     Large drops in authority therefore only happen when the margin
%     evidence itself is large - "strongly justified" by construction.
%   * CREEP is the always-on proportional recovery. It needs no model and
%     no confidence: any surplus pulls a up. It is what keeps regulation
%     alive where the prediction is blind (quiet-band deficits).
%   * SPRINT drives a toward the certified-safe point a*alpha_safe at a
%     rate proportional to the certified distance, tapering smoothly to
%     zero as it lands on the predicted target crossing. For a healed /
%     idle plant alpha_safe pins at the horizon and the sprint runs at
%     r_max (floor to full ~1.3 s); for a damaged plant the crossing sits
%     just above the equilibrium, so an over-shed is reclaimed within a
%     couple of seconds but the authority never charges past the point
%     the model can defend. conf multiplies it so one noisy healthy-
%     looking reading cannot trigger a sprint into a quiet-band deficit
%     the prediction cannot see.
%
% Because fabby_osi always reports a finite margin (silence/idle reads as
% the healthy ceiling), the sprint also covers blind recovery: no
% evidence -> b = ceiling, pred = ceiling -> conf charges -> a returns.
% No trips, latches, cooldowns, deadlocks, or NaN holds.

if ischar(b)
    switch lower(b)
        case 'params'
            if nargin >= 2, ovr = pred; else, ovr = struct(); end
            a_next = makeParams(ovr);
        case 'state'
            a_next = struct('a', pred.a_init, 'conf', 0);
        otherwise
            error('fabby_auth:UnknownCommand', ...
                'Use ''params'', ''state'', or the numeric step call.')
    end
    ast = [];
    return
end

% certified-safe authority multiplier: walk the pred path outward from
% alpha = 1 while the predicted margin stays above target + db_up, and
% interpolate the crossing - alpha_safe is how far the model VERIFIES the
% authority may rise from here. The walk (path minimum, not a pointwise
% lookup) matters because the margin is not monotone in loop gain and
% authority passes through every intermediate value. The horizon caps the
% extrapolation: a weak-signal FRF stretched 10x+ is noise-dominated and
% would bias the certification low exactly when recovery from a deep shed
% matters most; certifying only the next factor-of-pred_horizon and
% re-verifying from fresh data while climbing reaches full authority in a
% few estimator lengths anyway.
alpha_hi = min(prm.a_max/max(ast.a, prm.a_min), prm.pred_horizon);
thr = prm.target + prm.db_up;
alpha_safe = 1;
if pred(1) >= thr
    k = 1;
    while k < numel(agrid) && agrid(k+1) <= alpha_hi && pred(k+1) >= thr
        k = k + 1;
    end
    alpha_safe = min(agrid(k), alpha_hi);
    if k < numel(agrid) && agrid(k) < alpha_hi && pred(k+1) < thr
        % interpolate the alpha where the prediction crosses the threshold
        f = (pred(k) - thr)/max(pred(k) - pred(k+1), 1e-9);
        alpha_safe = min(agrid(k) + f*(agrid(k+1) - agrid(k)), alpha_hi);
    end
end

% recovery confidence: trust builds slowly (tau_conf) while the reading
% sits clearly above target, and evaporates fast (tau_conf_dn) the moment
% it does not - a 1 s noise spike can then never charge the sprint, while
% a genuinely healed/idle loop (readings clear for seconds) gets it fully
conf_raw = max(0, min(1, (b - prm.target - prm.conf_off)/prm.conf_w));
if conf_raw >= ast.conf
    tau_c = prm.tau_conf;
else
    tau_c = prm.tau_conf_dn;
end
ast.conf = ast.conf + (conf_raw - ast.conf)*prm.dt_update/tau_c;

d  = max(prm.target - b, 0)/prm.target;
s  = max(b - prm.target - prm.db_up, 0)/prm.target;

% the sprint drives a toward the certified-safe point a*alpha_safe at a
% rate proportional to the certified distance ln(alpha_safe): far below
% the safe point it runs at r_max, and it tapers smoothly to zero as the
% authority lands on the predicted target crossing - so an over-shed is
% reclaimed in a couple of seconds instead of crawling back on the creep
rate = -(prm.k_dn*d + prm.k_dn2*d^2) + prm.k_creep*s ...
    + min(prm.k_sprint*log(alpha_safe), prm.r_max)*ast.conf*(1 - blind);
ast.a = min(max(ast.a*exp(rate*prm.dt_update), prm.a_min), prm.a_max);
a_next = ast.a;
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.55, ...    % margin level to regulate onto
    'db_up', 0.025, ...    % rest band above target (anti-flicker)
    'k_dn', 6.0, ...       % linear shed gain (small deficits: gentle)
    'k_dn2', 25.0, ...     % quadratic shed gain (collapses: fast)
    'k_creep', 0.5, ...    % model-free proportional recovery
    'k_sprint', 3.0, ...   % sprint gain per ln of certified headroom
    'pred_horizon', 4.0, ...% max gain multiplier certified per step
    'r_max', 2.0, ...      % sprint ceiling (ln/s): floor->full ~1.3 s
    'conf_off', 0.03, ...  % reading must clear target+this to charge conf
    'conf_w', 0.05, ...    % conf ramp width above that
    'tau_conf', 1.2, ...   % conf build-up time (sprint trust)
    'tau_conf_dn', 0.8, ...% conf evaporation time on ambiguous readings
    'a_min', 0.08, ...
    'a_max', 1.0, ...
    'a_init', 1.0, ...
    'dt_update', 0.125);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('fabby_auth:UnknownParam', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
