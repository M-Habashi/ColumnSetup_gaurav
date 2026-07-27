function setup = prepare_sol_osi_runtime(projectFolder, dt, hs, pid_values)
%PREPARE_SOL_OSI_RUNTIME Prepare canonical fixed-size Speedgoat parameters.

defaults = struct('target_outer_ncf', 0.45, ...
    'osi_gain_min', 0.20, 'osi_gain_initial', 1.0);

target = defaults.target_outer_ncf;
if isfield(hs, 'target_outer_ncf'), target = hs.target_outer_ncf; end
a_min = defaults.osi_gain_min;
if isfield(hs, 'osi_gain_min'), a_min = hs.osi_gain_min; end
a_init = defaults.osi_gain_initial;
if isfield(hs, 'osi_gain_initial'), a_init = hs.osi_gain_initial; end

override = struct('osi', struct(), 'auth', struct());
if isfield(hs, 'sol_osi_override') && ~isempty(hs.sol_osi_override)
    names = fieldnames(hs.sol_osi_override);
    for i = 1:numel(names)
        override.(names{i}) = hs.sol_osi_override.(names{i});
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

cfg = sol_osi('config', dt, C*H_dc_dm, override.osi);
prm = gpt5_6_4_auth('params', override.auth);
prm.dt_update = cfg.step_s;
assert(numel(cfg.rho_grid) <= 25, ...
    'SOL_OSI fit grid exceeds the 25 scheduled candidate ticks.')

osi_dfm = 0;
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
    osi_dfm = 1000*(hs.interface_from_floor*force_to_displacement ...
        + hs.interface_from_force*force_sign);
end

% Index map is kept in sync with unpackConfig in sol_osi_runtime.
osis = [cfg.dt; cfg.fs; cfg.step_n; cfg.segment_n; ...
    cfg.spectral_alpha; cfg.margin_alpha; cfg.residual_alpha; ...
    cfg.power_floor; cfg.eta_A; cfg.cap; cfg.warm_steps; ...
    numel(cfg.freq_hz); cfg.nominal; numel(cfg.rho_grid); ...
    cfg.drive_alpha; cfg.fit_floor; cfg.recover_alpha; cfg.detector_max; ...
    cfg.reference_stride; cfg.reference_level_beta; ...
    cfg.hard_activity_gain; cfg.rho_detect; ...
    double(cfg.no_evidence_prior); cfg.level_fit_gain; ...
    cfg.level_fit_start_ratio];
osiw = cfg.window;
osibins = [cfg.bin, double(cfg.keep), double(cfg.rho_fit_keep), ...
    real(cfg.L0), imag(cfg.L0), cfg.shape, cfg.nominal_curve];
osirho = cfg.rho_grid(:);
osiauth = [prm.target; prm.guard; prm.deadband; prm.rate; ...
    prm.max_step; prm.a_min; prm.a_max; prm.a_init; prm.dt_update];
osi_reserved1 = 0;
osi_reserved2 = 0;

assignin('caller', 'osis', osis);
assignin('caller', 'osiw', osiw);
assignin('caller', 'osibins', osibins);
assignin('caller', 'osirho', osirho);
assignin('caller', 'osiauth', osiauth);
assignin('caller', 'osi_reserved1', osi_reserved1);
assignin('caller', 'osi_reserved2', osi_reserved2);
assignin('caller', 'osi_dfm', osi_dfm);
assignin('base', 'osi_dfm', osi_dfm);

setup = struct('exp_tf_file', exp_tf_file, 'exp_tf_name', exp_tf_name, ...
    'version', 'SOL-OSI (simplified V6)', ...
    'pid_values', pid_values, ...
    'cfg', cfg, 'prm', prm, 'osis', osis, 'osiw', osiw, ...
    'osibins', osibins, 'osirho', osirho, 'osiauth', osiauth, ...
    'osi_reserved1', osi_reserved1, 'osi_reserved2', osi_reserved2, ...
    'osi_dfm', osi_dfm, ...
    'target_outer_ncf', target, 'gain_initial', a_init, ...
    'gain_min', a_min, 'publish_ticks', 32);
end
