function [a_next, state, info] = gpt5_6_4_auth(varargin)
%GPT5_6_4_AUTH Rate-limited NCF authority regulator.
%   prm = gpt5_6_4_auth('params', override)
%   state = gpt5_6_4_auth('state', prm)
%   [a, state, info] = gpt5_6_4_auth(b, b_full, residual_weight, state, prm)

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'params'
            override = struct();
            if nargin >= 2, override = varargin{2}; end
            a_next = makeParams(override);
        case 'state'
            prm = varargin{2};
            a_next = struct('a', prm.a_init);
        otherwise
            error('gpt5_6_4_auth:UnknownCommand', ...
                'Use ''params'', ''state'', or a numeric step call.')
    end
    state = [];
    info = [];
    return
end

b = varargin{1};
b_full = varargin{2};
residual_weight = min(max(varargin{3}, 0), 1);
state = varargin{4};
prm = varargin{5};
a0 = min(max(state.a, prm.a_min), prm.a_max);
b_ref = prm.target+prm.guard*(1+residual_weight);
e_raw = b-b_ref;
e = sign(e_raw)*max(abs(e_raw)-prm.deadband*(1+residual_weight), 0);
headroom = 1/sqrt(2)-b_ref;
coherent = min(1, max(0, (0.60-residual_weight)/0.40));
full_safe = min(1, max(0, (b_full-prm.target)/prm.guard));
rate = prm.rate*sqrt(a0)*(1+coherent*full_safe*prm.up_boost* ...
    (max(e, 0)/headroom)^2);
log_a = log(a0)+rate*prm.dt_update*e;
a_free = exp(min(max(log_a, log(prm.a_min)), log(prm.a_max)));
a_next = a0+min(max(a_free-a0, -prm.max_step), prm.max_step);
state.a = a_next;
info = struct('a_target', a_next, 'margin_error', e_raw, ...
    'regulated_error', e, 'rate', rate);
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.55, ...
    'guard', 0.02, ...
    'deadband', 0.008, ...
    'rate', 5.0, ...
    'up_boost', 400.0, ...
    'max_step', 0.05, ...
    'a_min', 0.20, ...
    'a_max', 1.0, ...
    'a_init', 1.0, ...
    'dt_update', 0.125);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('gpt5_6_4_auth:UnknownParameter', ...
            'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
