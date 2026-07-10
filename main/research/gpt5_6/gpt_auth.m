function [a_next, state, info] = gpt_auth(varargin)
%GPT_AUTH Symmetric log-domain authority tracker for GPT_OSI.
%
%   prm = gpt_auth('params', override)
%   state = gpt_auth('state', prm)
%   [a, state, info] = gpt_auth(b, Lhat, b_res, state, prm)
%
% The measured loop estimate is rescaled over candidate authority values.
% The largest value whose predicted NCF margin clears target+guard is the
% coherent safe authority.  The residual term supplies the same proportional
% correction when the binding frequency is unexcited.  A single log-domain
% first-order update approaches the smaller target without mode switches,
% separate up/down laws, counters, latches, or commit gates.

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'params'
            if nargin >= 2, override = varargin{2}; else, override = struct(); end
            a_next = makeParams(override);
        case 'state'
            prm = varargin{2};
            a_next = struct('a', prm.a_init);
        otherwise
            error('gpt_auth:UnknownCommand', 'Use ''params'', ''state'', or a numeric step call.')
    end
    state = [];
    info = [];
    return
end

b = varargin{1};
Lhat = varargin{2};
b_res = varargin{3};
state = varargin{4};
prm = varargin{5};

a0 = min(max(state.a, prm.a_min), prm.a_max);
a_grid = linspace(prm.a_min, prm.a_max, prm.grid_n).';
pred = zeros(prm.grid_n, 1);
for i = 1:prm.grid_n
    L = (a_grid(i)/a0)*Lhat;
    curve = abs(1+L)./sqrt(2*(1+abs(L).^2));
    pred(i) = min(curve);
end

safe = find(pred >= prm.target+prm.guard);
if isempty(safe)
    a_ncf = prm.a_min;
else
    a_ncf = a_grid(safe(end));
end

a_res = a0*(max(b_res, 0.02)/prm.target)^prm.residual_power;
a_star = min(a_ncf, a_res);
a_star = min(max(a_star, prm.a_min), prm.a_max);

q = 1-exp(-prm.dt_update/prm.tau_s);
a_next = exp(log(a0)+q*(log(a_star)-log(a0)));
a_next = min(max(a_next, prm.a_min), prm.a_max);
state.a = a_next;

info = struct('a_target', a_star, 'a_ncf', a_ncf, ...
    'a_residual', a_res, 'pred_margin', pred, 'a_grid', a_grid, ...
    'margin_error', b-prm.target);
end

function prm = makeParams(override)
prm = struct( ...
    'target', 0.55, ...
    'guard', 0.015, ...
    'tau_s', 0.25, ...
    'residual_power', 2.0, ...
    'a_min', 0.08, ...
    'a_max', 1.0, ...
    'a_init', 1.0, ...
    'dt_update', 0.125, ...
    'grid_n', 65);
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(prm, names{i})
        error('gpt_auth:UnknownParameter', 'Unknown parameter: %s', names{i})
    end
    prm.(names{i}) = override.(names{i});
end
end
