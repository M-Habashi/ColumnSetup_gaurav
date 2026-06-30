function [knob, e] = margin_law(knob, margin, cfg)
%MARGIN_LAW One asymmetric update of the normalized intervention knob from a margin.
% The knob is a single normalized actuation level in [knob_min, knob_max]: 0 means
% "no intervention" (nominal controller) and larger means "more intervention" (lower
% authority, less integral, lower cutoff, deeper notch -- whatever the method maps it
% to). Every method shares this law; only the knob->controller map differs.
%
%   e = b_target - margin           % e > 0  => margin too LOW  => raise the knob
%
% Rules (encode "accept higher, highly penalize lower"):
%   * margin invalid (NaN/Inf)         -> HOLD (never relax on an estimator dropout)
%   * e >  deadband (below target)     -> raise knob FAST:  +k_down*e   (the penalty)
%   * margin > target + relax_band     -> lower knob SLOWLY: -k_up*|e|  (cautious giveback)
%   * otherwise                        -> HOLD
% The step is rate-limited and the knob saturated to [knob_min, knob_max].
%
% cfg fields used: b_target, deadband, relax_band, k_down, k_up, rate_limit,
%                  knob_min, knob_max.

if nargin < 3, cfg = struct(); end
knob_max = getf(cfg,'knob_max',1.0);
knob_min = getf(cfg,'knob_min',0.0);

if ~isfinite(margin)
    e = NaN;                       % dropout: hold the current knob
    return
end

e = cfg.b_target - margin;
if e > cfg.deadband
    dk =  cfg.k_down * e;                      % below target: correct hard and fast
elseif margin > cfg.b_target + cfg.relax_band
    dk = -cfg.k_up * abs(e);                   % safely above: relax slowly
else
    dk = 0;                                    % in the accept band: hold
end

dk   = max(min(dk, cfg.rate_limit), -cfg.rate_limit);   % rate limit
knob = max(min(knob + dk, knob_max), knob_min);         % saturate / anti-windup
end

function v = getf(s,f,d), if isfield(s,f) && ~isempty(s.(f)), v=s.(f); else, v=d; end, end
