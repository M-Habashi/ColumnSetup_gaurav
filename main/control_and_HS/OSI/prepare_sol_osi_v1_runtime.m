function setup = prepare_sol_osi_v1_runtime(projectFolder, dt, hs, pid_values)
%PREPARE_SOL_OSI_V1_RUNTIME Prepare former production V1 target parameters.

defaults = struct('target_outer_ncf', 0.45, ...
    'osi_gain_min', 0.20, 'osi_gain_initial', 1.0);

target = defaults.target_outer_ncf;
if isfield(hs, 'target_outer_ncf'), target = hs.target_outer_ncf; end
a_min = defaults.osi_gain_min;
if isfield(hs, 'osi_gain_min'), a_min = hs.osi_gain_min; end
a_init = defaults.osi_gain_initial;
if isfield(hs, 'osi_gain_initial'), a_init = hs.osi_gain_initial; end

override = struct('osi', struct(), 'auth', struct());
if isfield(hs, 'gpt5_6_override') && ~isempty(hs.gpt5_6_override)
    names = fieldnames(hs.gpt5_6_override);
    for i = 1:numel(names)
        override.(names{i}) = hs.gpt5_6_override.(names{i});
    end
end
override.auth.target = target;
override.auth.a_min = a_min;
override.auth.a_init = a_init;

[exp_tf_data, exp_tf_file, exp_tf_name] = ...
    load_saved_result_file(projectFolder, 'exp_tf', false, hs.exp_tf_file);
assert(isfield(exp_tf_data, 'H_dc_dm'), ...
    'The selected exp_tf file must contain H_dc_dm.')
H_dc_dm = exp_tf_data.H_dc_dm;
if get(H_dc_dm, 'Ts') == 0
    H_dc_dm = c2d(H_dc_dm, dt, 'zoh');
elseif abs(get(H_dc_dm, 'Ts') - dt) > 10*eps(dt)
    H_dc_dm = d2d(H_dc_dm, dt, 'zoh');
end
if nargin < 4 || isempty(pid_values)
    if isfield(exp_tf_data, 'pid_values')
        pid_values = exp_tf_data.pid_values;
    else
        pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
            'derivative_filter_N', 512);
    end
end
if ~isfield(pid_values, 'derivative_filter_N')
    pid_values.derivative_filter_N = 512;
end
C = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

cfg = sol_osi_v1('config', dt, C*H_dc_dm, override.osi);
prm = gpt5_6_4_auth('params', override.auth);
prm.dt_update = cfg.step_s;
assert(numel(cfg.rho_grid) <= cfg.step_n - 7, ...
    'SOL_OSI fit grid is too large for one scheduled update frame.')

gpt_dfm = 0;
has_hs_dfm = isfield(hs, 'M') && isfield(hs, 'C') && isfield(hs, 'K') ...
    && isfield(hs, 'force_to_floor') ...
    && isfield(hs, 'interface_from_floor') ...
    && isfield(hs, 'interface_from_force');
if has_hs_dfm
    force_sign = 1;
    if isfield(hs, 'force_sign'), force_sign = hs.force_sign; end
    effective_stiffness = hs.K + 4/dt^2*hs.M + 2/dt*hs.C;
    force_to_displacement = effective_stiffness\ ...
        (hs.force_to_floor*force_sign);
    gpt_dfm = 1000*(hs.interface_from_floor*force_to_displacement ...
        + hs.interface_from_force*force_sign);
end

% Index map is kept in sync with unpackConfig in sol_osi_v1_runtime.
gpts = [cfg.dt; cfg.fs; cfg.step_n; cfg.segment_n; ...
    cfg.spectral_alpha; cfg.margin_alpha; cfg.residual_alpha; ...
    cfg.power_floor; cfg.quiet_rms; cfg.cap; cfg.warm_steps; ...
    numel(cfg.freq_hz); cfg.nominal; numel(cfg.rho_grid); ...
    cfg.drive_alpha; cfg.fit_floor; cfg.leak_alpha; cfg.detector_max; ...
    cfg.reference_stride; cfg.reference_level_beta; ...
    cfg.residual_memory_gain; cfg.memory_release_ratio; ...
    cfg.memory_reengage_ratio; cfg.level_fit_gain; ...
    cfg.level_fit_start_ratio];
gptw = cfg.window;
gptbins = [cfg.bin, double(cfg.keep), double(cfg.res_keep), ...
    real(cfg.L0), imag(cfg.L0), cfg.shape, cfg.nominal_curve];
gptrho = cfg.rho_grid(:);
gptauth = [prm.target; prm.guard; prm.deadband; prm.rate; ...
    prm.max_step; prm.a_min; prm.a_max; prm.a_init; prm.dt_update];
gpt_reserved1 = 0;
gpt_reserved2 = 0;

assignin('caller', 'gpts', gpts);
assignin('caller', 'gptw', gptw);
assignin('caller', 'gptbins', gptbins);
assignin('caller', 'gptrho', gptrho);
assignin('caller', 'gptauth', gptauth);
assignin('caller', 'gpt_reserved1', gpt_reserved1);
assignin('caller', 'gpt_reserved2', gpt_reserved2);
assignin('caller', 'gpt_dfm', gpt_dfm);
assignin('base', 'gpt_dfm', gpt_dfm);

setup = struct('exp_tf_file', exp_tf_file, 'exp_tf_name', exp_tf_name, ...
    'version', 'SOL-OSI V1', ...
    'pid_values', pid_values, ...
    'cfg', cfg, 'prm', prm, 'gpts', gpts, 'gptw', gptw, ...
    'gptbins', gptbins, 'gptrho', gptrho, 'gptauth', gptauth, ...
    'gpt_reserved1', gpt_reserved1, 'gpt_reserved2', gpt_reserved2, ...
    'gpt_dfm', gpt_dfm, ...
    'target_outer_ncf', target, 'gain_initial', a_init, ...
    'gain_min', a_min, 'publish_ticks', 32);
end
