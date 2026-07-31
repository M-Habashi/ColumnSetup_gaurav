function out = sol_osi_replay(command, varargin)
%SOL_OSI_REPLAY Canonical offline SOL-OSI and authority replay.
%   cfg = sol_osi_replay('config', dt, initial_loop_tf, override)
%   out = sol_osi_replay('run', t, u_osi, dm, dt, initial_loop_tf, override, a)
%   The optional a is the authority that acted during an open-loop replay.

switch lower(command)
    case 'config'
        override = optional(varargin, 3, struct());
        out = struct('osi', sol_osi('config', varargin{1}, ...
            varargin{2}, fieldOr(override, 'osi', struct())), ...
            'auth', gpt5_6_4_auth('params', ...
            fieldOr(override, 'auth', struct())));
        out.auth.dt_update = out.osi.step_s;
    case 'run'
        out = runReplay(varargin{:});
    otherwise
        error('sol_osi_replay:UnknownCommand', 'Use ''config'' or ''run''.')
end
end

function out = runReplay(t, u, dm, dt, initial_loop_tf, override, a_acted)
% Units: t [s], u/dm [mm], dt [s], a_acted/auth_factor [-].
if nargin < 6 || isempty(override), override = struct(); end
if nargin < 7, a_acted = []; end
cfg = sol_osi_replay('config', dt, initial_loop_tf, override);
osi_state = sol_osi('state', cfg.osi);
auth_state = gpt5_6_4_auth('state', cfg.auth);
n = min([numel(t), numel(u), numel(dm)]);
n_step = floor(n/cfg.osi.step_n);
out = struct('tc', NaN(n_step, 1), 'b', NaN(n_step, 1), ...
    'b_st', NaN(n_step, 1), 'b_res', NaN(n_step, 1), ...
    'b_raw', NaN(n_step, 1), 'b_full', NaN(n_step, 1), ...
    'residual_weight', NaN(n_step, 1), 'rho', NaN(n_step, 1), ...
    'auth_factor', NaN(n_step, 1), 'cfg', cfg);
for k = 1:n_step
    ii = (k-1)*cfg.osi.step_n+(1:cfg.osi.step_n);
    if isempty(a_acted)
        osi_state.a_cmd = auth_state.a;
    else
        osi_state.a_cmd = a_acted(ii(1));
    end
    [out.b(k), osi_state, info] = sol_osi( ...
        u(ii), dm(ii), cfg.osi, osi_state);
    [auth_state.a, auth_state, auth_info] = gpt5_6_4_auth( ...
        out.b(k), info.full_margin, info.residual_weight, ...
        auth_state, cfg.auth);
    out.tc(k) = t(ii(end));
    out.b_st(k) = info.b_st;
    out.b_res(k) = info.b_res;
    out.b_raw(k) = info.b_raw;
    out.b_full(k) = info.full_margin;
    out.residual_weight(k) = info.residual_weight;
    out.rho(k) = info.rho;
    out.auth_factor(k) = auth_info.a_target;
end
end

function value = fieldOr(s, name, default)
if isfield(s, name), value = s.(name); else, value = default; end
end

function value = optional(args, index, default)
if numel(args) >= index, value = args{index}; else, value = default; end
end
