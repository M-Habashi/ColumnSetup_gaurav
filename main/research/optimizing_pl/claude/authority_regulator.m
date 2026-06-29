function [a, e, state] = authority_regulator(a, gm_estimate, cfg, state)
%AUTHORITY_REGULATOR One closed-loop update of the PID authority a from a margin error.
% Regulates the (inner) gain margin to a setpoint by moving the authority a in the
% direction the error demands. This is safe to close as a loop ONLY because the
% margin-vs-a map has a FIXED, KNOWN sign (lower a => higher GM, monotone and
% closed form, see predict_inner_margin) -- the integral correction can never
% chase the wrong way, unlike retuning P, I, or the lead ratio.
%
%   e = gm_set - gm_estimate            % e > 0  => margin too LOW => lower a
%   if estimate invalid (NaN/Inf): HOLD a (never relax on a dropout)
%   if |e| <= deadband:            no change
%   else: da = -k_down*e (e>0, fast)  OR  -k_up*e (e<0, slow);  rate-limit; saturate
%
% Design rules baked in (and why):
%   * ASYMMETRIC k_down >> k_up: losing margin (damage) must be corrected fast;
%     recovering performance (raising a) should be slow and cautious.
%   * RATE LIMIT + DEADBAND: the margin estimate (e.g. OSI Spk) is windowed and
%     noisy; keep adaptation slow vs the estimation window and ignore small errors.
%   * SATURATE a in [a_min, a_max] with clamping (anti-windup); a_min keeps enough
%     bandwidth that tracking does not collapse.
%   * HOLD ON DROPOUT: with weak excitation the margin cannot be estimated; freeze
%     a rather than drift.
%
% cfg fields (optional): gm_set (10 dB), k_down (0.15), k_up (0.03),
%   rate_limit (0.05 per step), deadband_db (0.5), a_min (0.3), a_max (1.0).
% state (optional) carries a running error integral for diagnostics only.

if nargin < 3, cfg = struct(); end
if nargin < 4, state = struct(); end
if ~isfield(state, 'e_sum'), state.e_sum = 0; end
if ~isfield(state, 'held'), state.held = false; end
d = struct('gm_set', 10, 'k_down', 0.15, 'k_up', 0.03, 'rate_limit', 0.05, ...
    'deadband_db', 0.5, 'a_min', 0.3, 'a_max', 1.0);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(cfg, f{i}) || isempty(cfg.(f{i})), cfg.(f{i}) = d.(f{i}); end
end

if ~isfinite(gm_estimate)
    e = NaN; state.held = true;             % dropout: hold a
    return
end
state.held = false;
e = cfg.gm_set - gm_estimate;               % e > 0 => need more margin => lower a
state.e_sum = state.e_sum + e;
if abs(e) <= cfg.deadband_db
    return
end
if e > 0
    da = -cfg.k_down*e;                      % fast down
else
    da = -cfg.k_up*e;                        % slow up
end
da = max(min(da, cfg.rate_limit), -cfg.rate_limit);
a = max(min(a + da, cfg.a_max), cfg.a_min); % saturate / anti-windup
end
