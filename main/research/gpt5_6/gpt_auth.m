function [a_next, state, info] = gpt_auth(varargin)
%GPT_AUTH Branch-free log-integral NCF authority regulator.
%
%   prm = gpt_auth('params', override)
%   state = gpt_auth('state', prm)
%   [a, state, info] = gpt_auth(b, b_full, residual_weight, state, prm)
%
% Reducing authority increases the NCF margin, so one log-integral update
% regulates the continuous reading onto b_ref.  The quiet-band evidence
% weight doubles the base guard and deadband when the hazard band is not
% directly observed.  A four-times rolling prediction horizon supplies
% the positive recovery boost; there are no modes, latches, counters, or
% separate recovery state.

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'params'
            if nargin >= 2, override = varargin{2}; else, override = struct(); end
            a_next = makeParams(override);
        case 'state'
            prm = varargin{2};
            a_next = struct('a', prm.a_init);
        otherwise
            error('gpt_auth:UnknownCommand', ...
                'Use ''params'', ''state'', or a numeric step call.')
    end
    state = [];
    info = [];
    return
end

b = varargin{1};
b_full = varargin{2};
residual_weight = varargin{3};
state = varargin{4};
prm = varargin{5};

a0 = min(max(state.a, prm.a_min), prm.a_max);
b_ref = prm.target+prm.guard*(1+min(max(residual_weight, 0), 1));
e_raw = b-b_ref;
db = prm.deadband*(1+min(max(residual_weight, 0), 1));
e = sign(e_raw)*max(abs(e_raw)-db,0);
headroom = 1/sqrt(2)-b_ref;
coherent = min(1,max(0,(0.60-residual_weight)/0.40));
full_safe = min(1,max(0,(b_full-prm.target)/prm.guard));
rate = prm.rate*sqrt(a0)*(1+coherent*full_safe*prm.up_boost* ...
    (max(e,0)/headroom)^2);
log_a = log(a0)+rate*prm.dt_update*e;
a_free = exp(min(max(log_a, log(prm.a_min)), log(prm.a_max)));
a_next = a0+min(max(a_free-a0,-prm.max_step),prm.max_step);
state.a = a_next;
info = struct('a_target', a_next, 'margin_error', e_raw, ...
    'regulated_error', e, 'coherent_weight', coherent, ...
    'full_safe_weight', full_safe, 'rate', rate);
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.55, ...
    'guard', 0.02, ...
    'deadband', 0.008, ...
    'rate', 5.0, ...
    'up_boost', 400.0, ...
    'max_step', 0.15, ...
    'a_min', 0.08, ...
    'a_max', 1.0, ...
    'a_init', 1.0, ...
    'dt_update', 0.125);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('gpt_auth:UnknownParameter', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
