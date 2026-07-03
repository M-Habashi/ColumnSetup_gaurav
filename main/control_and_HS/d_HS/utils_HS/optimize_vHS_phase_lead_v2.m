function result = optimize_vHS_phase_lead_v2(user_config)
%OPTIMIZE_VHS_PHASE_LEAD_V2 Constraint-aware vHS phase_lead optimizer.
% Finds the phase_lead prefilter G_T(s) = k_T*prod(s + zi)/prod(s + pi)
% (pi > zi) applied to the numerical dd command that minimizes J4 while
% holding the num*G_T*PID*H_dc_dm*exp NCF margin at or above a target.
%
% Compared with the legacy optimize_vHS_phase_lead engine, this version:
%   1. Simulates each candidate as one assembled closed-loop LTI system
%      (state transition via ltitr) instead of a per-sample MATLAB loop:
%      numerically equivalent, about two orders of magnitude faster.
%   2. Evaluates the NCF margin analytically from the precomputed base
%      open-loop response (exact tustin identity): microseconds per
%      candidate, so a dense feasibility map is built before any
%      simulation runs.
%   3. Treats the NCF target as a hard constraint (feasible-first
%      ranking and an fmincon nonlinear constraint) instead of a 1e8
%      soft penalty that conditioned the old objective badly.
%   4. Samples the NCF constraint boundary explicitly (the optimum is
%      usually active there), then refines with adaptive zoom plus an
%      optional fmincon polish.
%
% result = OPTIMIZE_VHS_PHASE_LEAD_V2(config) runs the optimization and
% returns a result struct. See defaultConfigV2() below for every option.
% The specimen, exp_tf and FEM files are loaded exactly like the legacy
% optimizer (interactive picker unless a file is configured), and the
% saved phase_lead MAT file keeps the legacy format so vHS.m loads it
% unchanged.
%
% Extending the objective: the score minimized among feasible candidates
% is  objective = J4 + sum(extra penalties) + custom term.  Add entries
% to config.extra_penalties (fields: metric, weight, threshold, power)
% to penalize any metric field, or set config.custom_objective_fcn =
% @(metrics, signals, phase_lead) ... for arbitrary terms.

if nargin < 1 || isempty(user_config)
    user_config = struct();
end
if ischar(user_config) || isstring(user_config)
    % optimize_vHS_phase_lead_v2('helpers') exposes the internal building
    % blocks for tests and external tooling.
    assert(strcmp(char(user_config), 'helpers'), ...
        'optimize_vHS_phase_lead_v2:InvalidRequest', ...
        'The only supported text argument is ''helpers''.')
    result = struct( ...
        'default_config', @defaultConfigV2, ...
        'merge_config', @mergeStructV2, ...
        'normalize_config', @normalizeConfigV2, ...
        'prepare', @preparePhaseLeadProblemV2, ...
        'evaluate', @evaluateCandidateV2, ...
        'ncf_from_center_ratio', @ncfFromCenterRatio, ...
        'phase_lead_from_center_ratio', @phaseLeadFromCenterRatioV2);
    return
end

engine_dir = fileparts(mfilename('fullpath'));
hs_dir = fileparts(engine_dir);
project_root = fileparts(fileparts(hs_dir));
addpath(engine_dir);
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', ...
    'id_utils'));

config = mergeStructV2(defaultConfigV2(), user_config);
config = normalizeConfigV2(config);

total_timer = tic;
fprintf('\n=== vHS phase_lead optimizer v2 ===\n')
fprintf(['Goal: NCF margin >= %.4g with minimum J4 | sections = %d | ' ...
    'record fraction = %.3g\n'], config.target_ncf_margin, ...
    config.phase_lead_section_count, config.optimization_record_fraction)

problem = preparePhaseLeadProblemV2(project_root, config, ...
    config.optimization_record_fraction);

state = newSearchState(problem);
[state, baseline] = evaluateLogged(state, [], 'baseline');
fprintf(['Baseline (no phase_lead): J4 = %.4g %%, NCF = %.6g, ' ...
    'stable = %d   [%.2f s/eval]\n'], baseline.metrics.j4_percent, ...
    baseline.metrics.num_phase_lead_exp_ncf_margin, ...
    baseline.metrics.stable, baseline.metrics.eval_seconds)

state = mapStage(state);
state = exploreStage(state);
state = zoomStage(state);
state = polishStage(state);

result = finalizeOptimization(state, baseline, project_root, ...
    total_timer);
end

%% ----------------------------------------------------------------------
%% Configuration
%% ----------------------------------------------------------------------

function config = defaultConfigV2()
config = struct( ...
    ... % --- record / plant inputs (same meaning as the legacy engine)
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.2, ...
    'time_scale_factor', 1, ...
    'force_sign', 1.0, ...
    'optimization_record_fraction', 1.0, ...
    'k_exp_r', 1.0, ...
    'sample_dt', 1/2048, ...
    'h_dc_dm_model_file', '', ...
    'fem_file', '', ...
    'specimen_file', '', ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    ... % --- goal
    'target_ncf_margin', 0.45, ...
    'minimum_stability_margin', 0, ...
    'num_phase_lead_exp_margin_frequency_hz', [0.1 80], ...
    'num_phase_lead_exp_margin_point_count', 10000, ...
    ... % --- search space
    'phase_lead_section_count', 1, ...
    'center_frequency_bounds_hz', [0.5 80], ...
    'ratio_bounds', [1.01 25], ...
    ... % --- stage budgets
    'map_center_count', 96, ...
    'map_ratio_count', 72, ...
    'explore_budget', 90, ...
    'boundary_budget', 45, ...
    'zoom_seed_count', 3, ...
    'zoom_iterations', 5, ...
    'zoom_grid_size', 5, ...
    'use_fmincon_polish', true, ...
    'polish_start_count', 2, ...
    'polish_max_evaluations', 150, ...
    'polish_max_iterations', 60, ...
    ... % --- objective extensions
    'extra_penalties', [], ...
    'custom_objective_fcn', [], ...
    'max_dc_dm_penalty_weight', 0, ...      % legacy alias
    'max_dd_lead_dc_penalty_weight', 0, ... % legacy alias
    'minimum_margin_penalty_weight', 1e8, ... % legacy score only
    ... % --- reporting / output
    'progress_interval_seconds', 2, ...
    'checkpoint_min_interval_seconds', 5, ...
    'phase_lead_file_name', '', ...
    'save_results', true, ...
    'save_best_checkpoint', true, ...
    'best_checkpoint_file', '', ...
    'plot_results', true, ...
    'print_validation_tables', true);
end

function config = mergeStructV2(config, override)
fields = fieldnames(override);
for field_id = 1:numel(fields)
    config.(fields{field_id}) = override.(fields{field_id});
end
end

function config = normalizeConfigV2(config)
% Accept legacy option names so old wrapper configs keep working.
if isfield(config, 'minimum_num_phase_lead_exp_ncf_margin') ...
        && ~isempty(config.minimum_num_phase_lead_exp_ncf_margin)
    config.target_ncf_margin = ...
        config.minimum_num_phase_lead_exp_ncf_margin;
end
config.minimum_num_phase_lead_exp_ncf_margin = config.target_ncf_margin;
validateattributes(config.target_ncf_margin, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<', 1}, mfilename, ...
    'config.target_ncf_margin');
validateattributes(config.phase_lead_section_count, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, ...
    'config.phase_lead_section_count');
validateattributes(config.optimization_record_fraction, {'numeric'}, ...
    {'scalar', 'real', 'positive', '<=', 1}, mfilename, ...
    'config.optimization_record_fraction');

config.extra_penalties = normalizeExtraPenalties(config.extra_penalties);
if config.max_dc_dm_penalty_weight ~= 0
    config.extra_penalties(end+1) = penaltyTerm('max_dc_dm_ratio', ...
        config.max_dc_dm_penalty_weight, 0, 1);
end
if config.max_dd_lead_dc_penalty_weight ~= 0
    config.extra_penalties(end+1) = penaltyTerm('max_dd_lead_dc_ratio', ...
        config.max_dd_lead_dc_penalty_weight, 0, 1);
end
if ~isempty(config.custom_objective_fcn)
    validateattributes(config.custom_objective_fcn, ...
        {'function_handle'}, {}, mfilename, 'config.custom_objective_fcn');
end
end

function term = penaltyTerm(metric, weight, threshold, power)
term = struct('metric', metric, 'weight', weight, ...
    'threshold', threshold, 'power', power);
end

function terms = normalizeExtraPenalties(terms)
if isempty(terms)
    terms = repmat(penaltyTerm('', 0, 0, 1), 0, 1);
    return
end
validateattributes(terms, {'struct'}, {}, mfilename, ...
    'config.extra_penalties');
normalized = repmat(penaltyTerm('', 0, 0, 1), numel(terms), 1);
for term_id = 1:numel(terms)
    term = terms(term_id);
    assert(isfield(term, 'metric') && isfield(term, 'weight'), ...
        'optimize_vHS_phase_lead_v2:InvalidPenalty', ...
        'extra_penalties entries need at least metric and weight fields.')
    if ~isfield(term, 'threshold') || isempty(term.threshold)
        threshold = 0;
    else
        threshold = term.threshold;
    end
    if ~isfield(term, 'power') || isempty(term.power)
        power = 1;
    else
        power = term.power;
    end
    normalized(term_id) = penaltyTerm(char(string(term.metric)), ...
        term.weight, threshold, power);
end
terms = normalized;
end

%% ----------------------------------------------------------------------
%% Problem preparation (loads specimen / exp_tf / FEM like the legacy
%% optimizer and precomputes everything reusable across candidates)
%% ----------------------------------------------------------------------

function problem = preparePhaseLeadProblemV2(project_root, config, ...
        record_fraction)
hs = struct( ...
    'earthquake_type', config.earthquake_type, ...
    'intensity_factor', config.intensity_factor, ...
    'time_scale_factor', config.time_scale_factor, ...
    'force_sign', config.force_sign);

if isempty(config.specimen_file)
    [specimen, specimen_file, ~] = load_saved_result_file( ...
        project_root, 'specimens', true);
else
    [specimen, specimen_file, ~] = load_saved_result_file( ...
        project_root, 'specimens', false, config.specimen_file);
end
config.specimen_file = specimen_file;
specimen_si = specimen_params_si(specimen);
hs.specimen_file = specimen_file;

[PID_H_dc_dm, pid_values, h_dc_dm_model_file, actuator_open_loop] = ...
    loadPidHdcDmModelV2(project_root, config.h_dc_dm_model_file, ...
    config.pid_gain_override, config.sample_dt);
config.h_dc_dm_model_file = h_dc_dm_model_file;
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, config.sample_dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

if isempty(config.fem_file)
    [fem, fem_file, ~] = loadFemDefinition(project_root, true);
elseif ~isfile(config.fem_file)
    warning('optimize_vHS_phase_lead_v2:MissingFemFile', ...
        'Configured FEM file not found: %s. Select a FEM file instead.', ...
        config.fem_file)
    [fem, fem_file, ~] = loadFemDefinition(project_root, true);
else
    [fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
        config.fem_file);
end
config.fem_file = fem_file;
hs.fem_file = fem_file;

if config.save_results
    phase_lead_dir = fullfile(project_root, 'saved_results', 'phase_lead');
    config.phase_lead_file_name = promptPhaseLeadFileNameV2( ...
        phase_lead_dir, '');
end

fprintf('Specimen file: %s\n', specimen_file)
fprintf('Actuator model file: %s\n', h_dc_dm_model_file)
fprintf('FEM file: %s\n', fem_file)

fem_num = fem.num;
fem_ref = fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

hs.fem = fem;
hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.K_if = K_if;
hs.K_ii = K_ii;
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, fem);
hs.damping_ratio = hs.damping.target_ratio;

earthquakes = load(fullfile(project_root, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);
if record_fraction < 1
    n_record = max(2, ceil(record_fraction*numel(hs.time)));
    hs.time = hs.time(1:n_record);
    hs.ag = hs.ag(1:n_record);
end

real_time = hs.time*hs.time_scale_factor;
n_step = ceil(real_time(end)/config.sample_dt) + 1;
hs_real_time = (0:n_step-1)'*config.sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(hs.time, hs.ag, hs_model_time, 'linear', 0);
reference_load_sample = -(fem_ref.M*fem_ref.influence)*ag_sample';
u_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    fem_ref.M, hs.C, fem_ref.K, reference_load_sample);
d_reference_sample = referenceControlDisplacement(fem_ref, ...
    u_reference_sample);
num_model = numericalSubstructureDiscreteV2(hs, config.sample_dt);
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, ...
    num_model.D_fm, config.sample_dt);
k_experimental = config.k_exp_r*specimen_si.stiffness;
margin_frequency_hz = logspace( ...
    log10(config.num_phase_lead_exp_margin_frequency_hz(1)), ...
    log10(config.num_phase_lead_exp_margin_frequency_hz(2)), ...
    config.num_phase_lead_exp_margin_point_count).';
margin_frequency_rad_s = 2*pi*margin_frequency_hz;
base_open_loop = -minreal(num_tf*(k_experimental/1000) ...
    * PID_H_dc_dm, [], false);
base_open_loop_response = squeeze(freqresp(base_open_loop, ...
    margin_frequency_rad_s));
% Exact tustin identity: the discrete lead response at e^(jwT) equals the
% continuous lead evaluated at s = j*(2/T)*tan(w*T/2).
margin_bilinear_s = 1i*(2/config.sample_dt) ...
    *tan(margin_frequency_rad_s*config.sample_dt/2);

problem = struct( ...
    'config', config, ...
    'project_root', project_root, ...
    'fem', fem, ...
    'fem_file', fem_file, ...
    'record_fraction', record_fraction, ...
    'specimen', specimen, ...
    'specimen_file', specimen_file, ...
    'h_dc_dm_model_file', h_dc_dm_model_file, ...
    'hs', hs, ...
    'sample_dt', config.sample_dt, ...
    'time', hs_real_time, ...
    'ag_sample', ag_sample, ...
    'u_reference_sample', u_reference_sample(:, 1:hs.n_floor), ...
    'd_reference_sample', d_reference_sample, ...
    'k_experimental', k_experimental, ...
    'k_mm', k_experimental/1000, ...
    'num_model', num_model, ...
    'num_tf', num_tf, ...
    'margin_frequency_rad_s', margin_frequency_rad_s, ...
    'margin_bilinear_s', margin_bilinear_s, ...
    'base_open_loop_response', base_open_loop_response(:), ...
    'PID_H_dc_dm', PID_H_dc_dm, ...
    'actuator_open_loop', actuator_open_loop, ...
    'pid_values', pid_values, ...
    'digital_controller', digital_controller, ...
    'actuator_ss', discreteSisoStruct(PID_H_dc_dm, config.sample_dt), ...
    'controller_ss', discreteSisoStruct(digital_controller, ...
        config.sample_dt), ...
    'metric', validation_metrics());
end

function [PID_H_dc_dm, pid_values, model_file, actuator_open_loop] = ...
        loadPidHdcDmModelV2(project_root, model_file, ...
        pid_gain_override, sample_time)
if isempty(model_file)
    [~, model_file, ~] = load_saved_result_file(project_root, 'exp_tf');
end
if ~any(strcmp({whos('-file', model_file).name}, 'H_dc_dm'))
    error('optimize_vHS_phase_lead_v2:MissingHdcDmModel', ...
        ['No saved model file containing H_dc_dm was found. Run ' ...
        'control_and_HS\\b_system_id\\sys_id.m first, or choose a ' ...
        'different saved_results\\exp_tf file.'])
end

model = load(model_file, 'H_dc_dm', 'pid_values');
H_dc_dm = model.H_dc_dm;
if isfield(model, 'pid_values')
    pid_values = model.pid_values;
else
    pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
pid_values = applyPidGainOverrideV2(pid_values, pid_gain_override);
pid_values.PID_scale = 1;
if get(H_dc_dm, 'Ts') == 0
    H_dc_dm = c2d(H_dc_dm, sample_time, 'zoh');
elseif abs(get(H_dc_dm, 'Ts')-sample_time) > 10*eps(sample_time)
    H_dc_dm = d2d(H_dc_dm, sample_time, 'zoh');
end
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, sample_time, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
actuator_open_loop = digital_controller*H_dc_dm;
PID_H_dc_dm = feedback(actuator_open_loop, 1);
end

function pid_values = applyPidGainOverrideV2(pid_values, pid_gain_override)
if isempty(pid_gain_override)
    return
end
if isnumeric(pid_gain_override)
    pid_values.P = pid_gain_override(1);
    pid_values.I = pid_gain_override(2);
    pid_values.D = pid_gain_override(3);
    pid_values.derivative_filter_N = pid_gain_override(4);
elseif isstruct(pid_gain_override)
    fields = {'P', 'I', 'D', 'derivative_filter_N'};
    for field_id = 1:numel(fields)
        field = fields{field_id};
        if isfield(pid_gain_override, field)
            pid_values.(field) = pid_gain_override.(field);
        end
    end
end
end

function model = numericalSubstructureDiscreteV2(hs, sample_time)
n = hs.n_floor;
h = sample_time;
beta = 1/4;
gamma = 1/2;
a0 = 1/(beta*h^2);
a1 = gamma/(beta*h);
a2 = 1/(beta*h);
a3 = 1/(2*beta)-1;
a4 = gamma/beta-1;
a5 = h*(gamma/(2*beta)-1);

effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
solver = effective_stiffness\eye(n);
state_to_displacement = solver * [a0*hs.M + a1*hs.C, ...
    a2*hs.M + a4*hs.C, a3*hs.M + a5*hs.C];
force_to_displacement = solver*(hs.force_to_floor*hs.force_sign);
ag_to_displacement = solver*hs.ground_force_gain;

model.A = zeros(3*n);
model.B_fm = zeros(3*n, 1);
model.B_ag = zeros(3*n, 1);
model.A(1:n, :) = state_to_displacement;
model.B_fm(1:n) = force_to_displacement;
model.B_ag(1:n) = ag_to_displacement;
model.A(2*n+1:3*n, :) = a0*(state_to_displacement ...
    - [eye(n), zeros(n), zeros(n)]) ...
    - a2*[zeros(n), eye(n), zeros(n)] ...
    - a3*[zeros(n), zeros(n), eye(n)];
model.B_fm(2*n+1:3*n) = a0*force_to_displacement;
model.B_ag(2*n+1:3*n) = a0*ag_to_displacement;
model.A(n+1:2*n, :) = [zeros(n), eye(n), zeros(n)] ...
    + h*((1-gamma)*[zeros(n), zeros(n), eye(n)] ...
    + gamma*model.A(2*n+1:3*n, :));
model.B_fm(n+1:2*n) = h*gamma*model.B_fm(2*n+1:3*n);
model.B_ag(n+1:2*n) = h*gamma*model.B_ag(2*n+1:3*n);
model.C = 1000*(hs.interface_from_floor*state_to_displacement);
model.D_fm = 1000*(hs.interface_from_floor*force_to_displacement ...
    + hs.interface_from_force*hs.force_sign);
model.D_ag = 1000*(hs.interface_from_floor*ag_to_displacement);
end

function sys = discreteSisoStruct(system_model, sample_time)
if get(system_model, 'Ts') == 0
    system_model = c2d(system_model, sample_time, 'zoh');
elseif abs(get(system_model, 'Ts')-sample_time) > 10*eps(sample_time)
    system_model = d2d(system_model, sample_time, 'zoh');
end
system_model = ss(system_model);
[A, B, C, D] = ssdata(system_model);
n_state = size(A, 1);
sys.A = A;
sys.B = reshape(B, n_state, 1);
sys.C = reshape(C, 1, n_state);
sys.D = D(1);
end

%% ----------------------------------------------------------------------
%% Fast candidate evaluation (assembled closed loop + ltitr)
%% ----------------------------------------------------------------------

function candidate = evaluateCandidateV2(problem, phase_lead_override)
eval_timer = tic;
phase_lead = normalizePhaseLeadConfig(phase_lead_override, ...
    problem.config.phase_lead_section_count);
lead = discreteSisoStruct(buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt), problem.sample_dt);
loop = buildClosedLoopV2(problem, lead);
stability = closedLoopStabilityV2(loop, lead, problem);
freq_metrics = numPhaseLeadExpMetricsV2(problem, phase_lead);
if stability.coupled_max_abs_pole < 1
    signals = simulateClosedLoopV2(problem, loop);
else
    signals = [];
end
metrics = scoreCandidateV2(problem, phase_lead, signals, stability, ...
    freq_metrics);
candidate = struct('phase_lead', phase_lead, 'stability', stability, ...
    'num_phase_lead_exp_metrics', freq_metrics, 'signals', signals, ...
    'metrics', metrics);
candidate.metrics.eval_seconds = toc(eval_timer);
end

function loop = buildClosedLoopV2(problem, lead)
% Stack [x_num; x_lead; x_actuator] and close the algebraic loop exactly
% like the legacy per-sample recursion:
%   dd -> lead -> dd_lead -> actuator -> dm -> force -> numerical model.
act = problem.actuator_ss;
num = problem.num_model;
k_mm = problem.k_mm;
n_num = size(num.A, 1);
n_lead = size(lead.A, 1);
n_act = size(act.A, 1);

den = 1 - num.D_fm*k_mm*act.D*lead.D;
C_dd = [num.C, num.D_fm*k_mm*act.D*lead.C, num.D_fm*k_mm*act.C]/den;
D_dd = num.D_ag/den;
C_dd_lead = lead.D*C_dd;
C_dd_lead(n_num+1:n_num+n_lead) = C_dd_lead(n_num+1:n_num+n_lead) ...
    + lead.C;
D_dd_lead = lead.D*D_dd;
C_dm = act.D*C_dd_lead;
C_dm(n_num+n_lead+1:end) = C_dm(n_num+n_lead+1:end) + act.C;
D_dm = act.D*D_dd_lead;
C_force = k_mm*C_dm;
D_force = k_mm*D_dm;

A_cl = blkdiag(num.A, lead.A, act.A);
A_cl(1:n_num, :) = A_cl(1:n_num, :) + num.B_fm*C_force;
A_cl(n_num+1:n_num+n_lead, :) = A_cl(n_num+1:n_num+n_lead, :) ...
    + lead.B*C_dd;
A_cl(n_num+n_lead+1:end, :) = A_cl(n_num+n_lead+1:end, :) ...
    + act.B*C_dd_lead;
B_cl = [num.B_ag + num.B_fm*D_force; lead.B*D_dd; act.B*D_dd_lead];

loop = struct('A', A_cl, 'B', B_cl, ...
    'C_dd', C_dd, 'D_dd', D_dd, ...
    'C_dd_lead', C_dd_lead, 'D_dd_lead', D_dd_lead, ...
    'C_dm', C_dm, 'D_dm', D_dm, ...
    'n_num', n_num, 'n_lead', n_lead, 'n_act', n_act);
end

function stability = closedLoopStabilityV2(loop, lead, problem)
closed_loop_poles = eig(loop.A);
actuator_poles = eig(problem.actuator_ss.A);
lead_poles = eig(lead.A);
[coupled_max_abs_pole, dominant_index] = max(abs(closed_loop_poles));
dominant_pole = closed_loop_poles(dominant_index);
stability.actuator_max_abs_pole = max([abs(actuator_poles); 0]);
stability.lead_max_abs_pole = max([abs(lead_poles); 0]);
stability.coupled_max_abs_pole = coupled_max_abs_pole;
stability.actuator_stable = stability.actuator_max_abs_pole < 1 ...
    && stability.lead_max_abs_pole < 1;
stability.coupled_stable = stability.coupled_max_abs_pole < 1;
stability.dominant_pole = dominant_pole;
stability.dominant_frequency_hz = abs(angle(dominant_pole)) ...
    /(2*pi*problem.sample_dt);
stability.closed_loop_poles = closed_loop_poles;
end

function signals = simulateClosedLoopV2(problem, loop)
% Identical recursion to the legacy per-sample loop: step 1 is never
% processed (all signals zero there) and the recorded floor displacement
% at step k is the numerical state after the step-k update.
ag = problem.ag_sample(:);
n_step = numel(ag);
n_state = size(loop.A, 1);
states = zeros(n_step, n_state);
if n_step >= 2
    states(2:end, :) = stateTransition(loop.A, loop.B, ag(2:end), ...
        zeros(n_state, 1));
end
dd = states*loop.C_dd.' + loop.D_dd*ag;
dd_lead = states*loop.C_dd_lead.' + loop.D_dd_lead*ag;
dm = states*loop.C_dm.' + loop.D_dm*ag;
n_floor = problem.hs.n_floor;
u_floors = states*loop.A(1:n_floor, :).' + ag*loop.B(1:n_floor).';
force = problem.k_mm*dm;
dd(1) = 0;
dd_lead(1) = 0;
dm(1) = 0;
force(1) = 0;
u_floors(1, :) = 0;

% dc is a monitoring output: the digital PID filtering (dd_lead - dm).
ctrl = problem.controller_ss;
tracking_error = dd_lead - dm;
n_ctrl = size(ctrl.A, 1);
ctrl_states = zeros(n_step, n_ctrl);
if n_step >= 2
    ctrl_states(2:end, :) = stateTransition(ctrl.A, ctrl.B, ...
        tracking_error(2:end), zeros(n_ctrl, 1));
end
dc = ctrl_states*ctrl.C.' + ctrl.D*tracking_error;

signals = struct( ...
    'u_num_floors_sample', u_floors, ...
    'dd_sample', dd, ...
    'dd_lead_sample', dd_lead, ...
    'dm_sample', dm, ...
    'dc_sample', dc, ...
    'force_sample', force);
end

function states = stateTransition(A, B, input, x0)
% x(k+1) = A*x(k) + B*u(k); returns states BEFORE each input is applied.
if exist('ltitr', 'builtin') == 5 || exist('ltitr', 'file') == 2
    states = ltitr(A, B, input(:), x0);
    return
end
n_step = size(input, 1);
states = zeros(n_step, size(A, 1));
x = x0;
for step = 1:n_step
    states(step, :) = x.';
    x = A*x + B*input(step);
end
end

function metrics = scoreCandidateV2(problem, phase_lead, signals, ...
        stability, freq_metrics)
config = problem.config;
if isempty(signals)
    j4_percent = Inf;
    j4_raw_percent = Inf;
    response_nrmse_percent = Inf;
    tracking_nrmse_percent = Inf;
    lead_change_percent = Inf;
    peak_command_ratio = Inf;
    max_dc_dm_ratio = Inf;
    max_dd_lead_dc_ratio = Inf;
else
    metric = problem.metric;
    response_error = signals.u_num_floors_sample ...
        - problem.u_reference_sample;
    j4_percent = metric.J4(signals.u_num_floors_sample(:, 1), ...
        problem.u_reference_sample(:, 1));
    % Unrounded J4: the official metric rounds to 0.01 %, which makes the
    % objective a staircase (zero gradient between steps). Optimize the
    % continuous value and report the official rounded one alongside.
    j4_raw_percent = 100*std(signals.u_num_floors_sample(:, 1) ...
        - problem.u_reference_sample(:, 1)) ...
        /std(problem.u_reference_sample(:, 1));
    response_nrmse_percent = 100*rms(response_error(:)) ...
        /max(rms(problem.u_reference_sample(:)), eps);
    tracking_nrmse_percent = 100*rms(signals.dd_lead_sample ...
        - signals.dm_sample)/max(rms(signals.dd_lead_sample), eps);
    lead_change_percent = 100*rms(signals.dd_lead_sample ...
        - signals.dd_sample)/max(rms(signals.dd_sample), eps);
    peak_command_ratio = max(abs(signals.dd_lead_sample)) ...
        /max(max(abs(signals.dd_sample)), eps);
    max_dc_dm_ratio = max(abs(signals.dc_sample)) ...
        /max(max(abs(signals.dm_sample)), eps);
    max_dd_lead_dc_ratio = max(abs(signals.dd_lead_sample)) ...
        /max(max(abs(signals.dc_sample)), eps);
end
stability_margin = 1 - stability.coupled_max_abs_pole;
ncf_margin = freq_metrics.ncf_margin;
minimum_ncf_shortfall = max(0, config.target_ncf_margin - ncf_margin);
minimum_margin_shortfall = max(0, config.minimum_stability_margin ...
    - stability_margin);

metrics = struct( ...
    'j4_percent', j4_percent, ...
    'j4_raw_percent', j4_raw_percent, ...
    'response_nrmse_percent', response_nrmse_percent, ...
    'tracking_nrmse_percent', tracking_nrmse_percent, ...
    'lead_change_percent', lead_change_percent, ...
    'peak_command_ratio', peak_command_ratio, ...
    'max_dc_dm_ratio', max_dc_dm_ratio, ...
    'max_dd_lead_dc_ratio', max_dd_lead_dc_ratio, ...
    'stability_margin', stability_margin, ...
    'num_phase_lead_exp_gm_db', freq_metrics.gm_db, ...
    'num_phase_lead_exp_pm_deg', freq_metrics.pm_deg, ...
    'num_phase_lead_exp_ncf_margin', ncf_margin, ...
    'minimum_margin_shortfall', minimum_margin_shortfall, ...
    'minimum_ncf_shortfall', minimum_ncf_shortfall, ...
    'max_abs_pole', stability.coupled_max_abs_pole, ...
    'stable', stability.coupled_stable);

[penalty_total, penalty_detail] = applyExtraPenalties(config, metrics);
objective = j4_raw_percent + penalty_total;
if ~isempty(config.custom_objective_fcn) && ~isempty(signals)
    objective = objective + config.custom_objective_fcn(metrics, ...
        signals, phase_lead);
end

% Legacy-compatible penalized score (used only to rank infeasible
% candidates and to keep saved tables comparable with old runs).
score = objective ...
    + config.minimum_margin_penalty_weight*minimum_ncf_shortfall^2;
if stability.coupled_max_abs_pole >= 1
    score = 1e6*(1 + stability.coupled_max_abs_pole - 1) ...
        + config.minimum_margin_penalty_weight*minimum_ncf_shortfall^2;
end

metrics.objective = objective;
metrics.performance_score = objective;
metrics.score = score;
metrics.extra_penalty_total = penalty_total;
metrics.extra_penalty_detail = penalty_detail;
metrics.max_dc_dm_penalty = penaltyByMetric(penalty_detail, ...
    'max_dc_dm_ratio');
metrics.max_dd_lead_dc_penalty = penaltyByMetric(penalty_detail, ...
    'max_dd_lead_dc_ratio');
metrics.feasible = candidateIsFeasible(metrics, config);
metrics.eval_seconds = 0;
end

function [total, detail] = applyExtraPenalties(config, metrics)
terms = config.extra_penalties;
total = 0;
detail = repmat(struct('metric', '', 'value', 0, 'penalty', 0), ...
    numel(terms), 1);
for term_id = 1:numel(terms)
    term = terms(term_id);
    value = metrics.(term.metric);
    penalty = term.weight*max(0, value - term.threshold)^term.power;
    total = total + penalty;
    detail(term_id) = struct('metric', term.metric, 'value', value, ...
        'penalty', penalty);
end
end

function penalty = penaltyByMetric(detail, metric_name)
penalty = 0;
for term_id = 1:numel(detail)
    if strcmp(detail(term_id).metric, metric_name)
        penalty = penalty + detail(term_id).penalty;
    end
end
end

function tf = candidateIsFeasible(metrics, config)
tolerance = 1e-9;
tf = metrics.stable ...
    && metrics.stability_margin + tolerance ...
        >= config.minimum_stability_margin ...
    && metrics.num_phase_lead_exp_ncf_margin + tolerance ...
        >= config.target_ncf_margin;
end

function better = candidateBeats(a, b)
% Feasible-first ranking; among feasible, lower objective wins; among
% infeasible, lower legacy score (smaller shortfall) wins.
if a.metrics.feasible ~= b.metrics.feasible
    better = a.metrics.feasible;
    return
end
if a.metrics.feasible
    better = a.metrics.objective < b.metrics.objective;
else
    better = a.metrics.score < b.metrics.score;
end
end

%% ----------------------------------------------------------------------
%% Cheap analytic NCF machinery (no simulation, no tf objects)
%% ----------------------------------------------------------------------

function response = leadResponseAnalytic(problem, phase_lead)
s_eq = problem.margin_bilinear_s(:);
if ~phase_lead.enabled
    response = ones(size(s_eq));
    return
end
response = phase_lead.gain*ones(size(s_eq));
for section_id = 1:phase_lead.section_count
    response = response ...
        .*(s_eq + phase_lead.zero_rad_s(section_id)) ...
        ./(s_eq + phase_lead.pole_rad_s(section_id));
end
end

function metrics = numPhaseLeadExpMetricsV2(problem, phase_lead)
open_loop = problem.base_open_loop_response ...
    .*leadResponseAnalytic(problem, phase_lead);
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    stabilityMarginsFromResponseV2(open_loop);
end

function ncf = ncfFromCenterRatio(problem, center_hz, total_ratio)
% NCF margin for equal-split sections; center_hz and total_ratio are
% equal-length vectors of candidates.
section_count = problem.config.phase_lead_section_count;
base = problem.base_open_loop_response;
s_eq = problem.margin_bilinear_s;
center_hz = center_hz(:).';
section_ratio = total_ratio(:).'.^(1/section_count);
z_rad = 2*pi*center_hz./sqrt(section_ratio);
p_rad = 2*pi*center_hz.*sqrt(section_ratio);
n_candidate = numel(center_hz);
ncf = zeros(1, n_candidate);
chunk = max(1, floor(2e6/numel(s_eq)));
for start_id = 1:chunk:n_candidate
    ids = start_id:min(start_id+chunk-1, n_candidate);
    section_response = section_ratio(ids).*(s_eq + z_rad(ids)) ...
        ./(s_eq + p_rad(ids));
    open_loop = base.*section_response.^section_count;
    ncf(ids) = min(abs(1 + open_loop) ...
        ./sqrt(2*(1 + abs(open_loop).^2)), [], 1);
end
end

function [gain_margin_db, phase_margin_deg, ncf_margin] = ...
        stabilityMarginsFromResponseV2(response)
response = response(:);
imag_response = imag(response);
phase_crossings = find(imag_response(1:end-1).*imag_response(2:end) <= 0);
gain_candidates = [];
for i = phase_crossings.'
    fraction = -imag_response(i)/(imag_response(i+1) - imag_response(i));
    crossing_response = response(i) + ...
        fraction*(response(i+1) - response(i));
    if real(crossing_response) < 0
        candidate = 1/abs(crossing_response);
        if candidate >= 1
            gain_candidates(end+1, 1) = candidate; %#ok<AGROW>
        end
    end
end
gain_margin_db = 20*log10(min([gain_candidates; Inf]));

log_magnitude = log(abs(response));
gain_crossings = find(log_magnitude(1:end-1).*log_magnitude(2:end) <= 0);
phase_deg = unwrap(angle(response))*180/pi;
phase_candidates = [];
for i = gain_crossings.'
    fraction = -log_magnitude(i)/(log_magnitude(i+1) - log_magnitude(i));
    crossing_phase = phase_deg(i) + fraction*(phase_deg(i+1) - phase_deg(i));
    candidate = mod(180 + crossing_phase + 180, 360) - 180;
    if candidate > 0
        phase_candidates(end+1, 1) = candidate; %#ok<AGROW>
    end
end
phase_margin_deg = min([phase_candidates; Inf]);

normalized_distance = abs(1 + response) ./ ...
    sqrt(2*(1 + abs(response).^2));
ncf_margin = min(normalized_distance);
end

%% ----------------------------------------------------------------------
%% Search state, logging, progress reporting
%% ----------------------------------------------------------------------

function state = newSearchState(problem)
state = struct( ...
    'problem', problem, ...
    'config', problem.config, ...
    'best', [], ...
    'history', [], ...
    'sim_count', 0, ...
    'start_time', tic, ...
    'stage', '', ...
    'stage_index', 0, ...
    'stage_total', 0, ...
    'stage_start', tic, ...
    'last_progress_time', -Inf, ...
    'last_checkpoint_time', -Inf, ...
    'map', []);
state.seen = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

function state = beginStage(state, stage, total)
state.stage = stage;
state.stage_index = 0;
state.stage_total = total;
state.stage_start = tic;
state.last_progress_time = -Inf;
end

function [state, candidate, was_cached] = evaluateLogged(state, ...
        phase_lead_override, stage)
key = candidateKey(state.problem, phase_lead_override);
was_cached = state.seen.isKey(key);
if was_cached
    candidate = state.seen(key);
    return
end
candidate = evaluateCandidateV2(state.problem, phase_lead_override);
reduced = struct('phase_lead', candidate.phase_lead, ...
    'metrics', candidate.metrics);
state.seen(key) = reduced;
state.sim_count = state.sim_count + 1;
state.stage_index = state.stage_index + 1;
state.history = [state.history; ...
    historyEntry(stage, state.sim_count, candidate)];

is_new_best = isempty(state.best) || candidateBeats(reduced, state.best);
if is_new_best
    state.best = reduced;
    printNewBest(state, reduced);
    state = maybeSaveCheckpoint(state, stage, false);
else
    state = printStageProgress(state, false);
end
end

function key = candidateKey(problem, phase_lead_override)
phase_lead = normalizePhaseLeadConfig(phase_lead_override, ...
    problem.config.phase_lead_section_count);
if ~phase_lead.enabled
    key = 'disabled';
    return
end
key = sprintf('%.6e_', phase_lead.gain, phase_lead.zero_hz, ...
    phase_lead.pole_hz);
end

function entry = historyEntry(stage, trial, candidate)
entry = struct( ...
    'Stage', string(stage), ...
    'Trial', trial, ...
    'Feasible', candidate.metrics.feasible, ...
    'Objective', candidate.metrics.objective, ...
    'Score', candidate.metrics.score, ...
    'J4_percent', candidate.metrics.j4_percent, ...
    'J4_raw_percent', candidate.metrics.j4_raw_percent, ...
    'NumPhaseLeadExpNCFMargin', ...
        candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    'Zero_Hz', candidate.phase_lead.zero_hz, ...
    'Pole_Hz', candidate.phase_lead.pole_hz, ...
    'Gain', candidate.phase_lead.gain, ...
    'Center_Hz', candidate.phase_lead.center_frequency_hz, ...
    'Ratio', candidate.phase_lead.section_ratio, ...
    'MaxPhaseLead_deg', candidate.phase_lead.max_phase_lead_deg, ...
    'TrackingNRMSE_percent', candidate.metrics.tracking_nrmse_percent, ...
    'PeakCommandRatio', candidate.metrics.peak_command_ratio, ...
    'MaxDCDMRatio', candidate.metrics.max_dc_dm_ratio, ...
    'MaxDDLeadDCRatio', candidate.metrics.max_dd_lead_dc_ratio, ...
    'StabilityMargin', candidate.metrics.stability_margin, ...
    'MaxAbsPole', candidate.metrics.max_abs_pole, ...
    'Stable', candidate.metrics.stable, ...
    'EvalSeconds', candidate.metrics.eval_seconds);
end

function printNewBest(state, candidate)
if strcmp(state.stage, '') || strcmp(state.stage, 'baseline')
    return
end
fprintf(['  * new best [%s %d/%d]: J4 = %.4g %%, NCF = %.6g, ' ...
    'feasible = %d | %s\n'], state.stage, state.stage_index, ...
    max(state.stage_total, state.stage_index), ...
    candidate.metrics.j4_percent, ...
    candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    candidate.metrics.feasible, phaseLeadShort(candidate.phase_lead))
end

function state = printStageProgress(state, force)
config = state.config;
elapsed_since_print = toc(state.stage_start) - state.last_progress_time;
if ~force && elapsed_since_print < config.progress_interval_seconds
    return
end
elapsed = toc(state.stage_start);
total = max(state.stage_total, state.stage_index);
if state.stage_index > 0 && total > state.stage_index
    eta = elapsed/state.stage_index*(total - state.stage_index);
else
    eta = NaN;
end
if isempty(state.best)
    best_text = 'best: none yet';
elseif state.best.metrics.feasible
    best_text = sprintf('best J4 %.4g %% (NCF %.4g) %s', ...
        state.best.metrics.j4_percent, ...
        state.best.metrics.num_phase_lead_exp_ncf_margin, ...
        phaseLeadShort(state.best.phase_lead));
else
    best_text = sprintf('best (infeasible) NCF %.4g, J4 %.4g %%', ...
        state.best.metrics.num_phase_lead_exp_ncf_margin, ...
        state.best.metrics.j4_percent);
end
fprintf('  %s %d/%d (%.0f%%) | elapsed %s | ETA %s | %s\n', ...
    state.stage, state.stage_index, total, ...
    100*state.stage_index/max(total, 1), ...
    formatDurationSecondsV2(elapsed), formatDurationSecondsV2(eta), ...
    best_text)
state.last_progress_time = toc(state.stage_start);
end

function text = phaseLeadShort(phase_lead)
if ~phase_lead.enabled
    text = 'disabled';
    return
end
text = sprintf('z %s Hz, p %s Hz, k %.4g', ...
    vectorLiteralV2(phase_lead.zero_hz), ...
    vectorLiteralV2(phase_lead.pole_hz), phase_lead.gain);
end

function text = formatDurationSecondsV2(seconds)
if isnan(seconds) || isinf(seconds)
    text = '--:--:--';
    return
end
seconds = max(0, round(seconds));
hours = floor(seconds/3600);
minutes = floor(mod(seconds, 3600)/60);
seconds = mod(seconds, 60);
text = sprintf('%02d:%02d:%02d', hours, minutes, seconds);
end

function state = maybeSaveCheckpoint(state, stage, force)
config = state.config;
if ~config.save_best_checkpoint || isempty(state.best)
    return
end
since_last = toc(state.start_time) - state.last_checkpoint_time;
if ~force && since_last < config.checkpoint_min_interval_seconds
    return
end
checkpoint_file = bestCheckpointFileV2(state.problem);
checkpoint_dir = fileparts(checkpoint_file);
if ~isempty(checkpoint_dir) && ~exist(checkpoint_dir, 'dir')
    mkdir(checkpoint_dir)
end
best_checkpoint = state.best;
best_checkpoint_metrics = state.best.metrics;
best_checkpoint_phase_lead = state.best.phase_lead;
best_checkpoint_feasible = state.best.metrics.feasible;
best_checkpoint_trial_count = state.sim_count;
best_checkpoint_stage = string(stage);
best_checkpoint_updated_at = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));
config_saved = sanitizeConfigForSave(config);
save(checkpoint_file, 'best_checkpoint', 'best_checkpoint_metrics', ...
    'best_checkpoint_phase_lead', 'best_checkpoint_feasible', ...
    'best_checkpoint_trial_count', 'best_checkpoint_stage', ...
    'best_checkpoint_updated_at', 'config_saved')
state.last_checkpoint_time = toc(state.start_time);
end

function checkpoint_file = bestCheckpointFileV2(problem)
if ~isempty(problem.config.best_checkpoint_file)
    checkpoint_file = char(problem.config.best_checkpoint_file);
    if ~isAbsolutePathV2(checkpoint_file)
        checkpoint_file = fullfile(problem.project_root, checkpoint_file);
    end
    return
end
checkpoint_file = fullfile(problem.project_root, 'saved_results', ...
    'phase_lead', 'vHS_phase_lead_v2_best_checkpoint.mat');
end

function tf = isAbsolutePathV2(path)
tf = startsWith(path, filesep) ...
    || startsWith(path, '\\') ...
    || ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
end

function config = sanitizeConfigForSave(config)
if ~isempty(config.custom_objective_fcn)
    config.custom_objective_fcn = ...
        ['<function handle removed for save: ' ...
        func2str(config.custom_objective_fcn) '>'];
end
end

%% ----------------------------------------------------------------------
%% Stage 1: analytic NCF feasibility map
%% ----------------------------------------------------------------------

function state = mapStage(state)
config = state.config;
problem = state.problem;
stage_timer = tic;
centers = logspace(log10(config.center_frequency_bounds_hz(1)), ...
    log10(config.center_frequency_bounds_hz(2)), ...
    config.map_center_count).';
ratios = logspace(log10(config.ratio_bounds(1)), ...
    log10(config.ratio_bounds(2)), config.map_ratio_count).';
fprintf('\n[1/4] Feasibility map: %d x %d = %d candidates (analytic NCF)\n', ...
    numel(centers), numel(ratios), numel(centers)*numel(ratios))

ncf_map = zeros(numel(centers), numel(ratios));
for center_id = 1:numel(centers)
    ncf_map(center_id, :) = ncfFromCenterRatio(problem, ...
        centers(center_id)*ones(size(ratios)), ratios);
end
feasible_mask = ncf_map + 1e-9 >= config.target_ncf_margin;
boundary = ncfBoundaryPoints(state, centers, ratios, ncf_map);

state.map = struct('centers', centers, 'ratios', ratios, ...
    'ncf', ncf_map, 'feasible', feasible_mask, 'boundary', boundary);
fprintf(['      done in %.2f s | feasible %d/%d (%.1f%%) | ' ...
    'NCF range [%.4g, %.4g] | boundary points %d\n'], ...
    toc(stage_timer), nnz(feasible_mask), numel(feasible_mask), ...
    100*nnz(feasible_mask)/numel(feasible_mask), min(ncf_map(:)), ...
    max(ncf_map(:)), size(boundary, 1))
if ~any(feasible_mask(:))
    fprintf(['      WARNING: no candidate in the search box reaches ' ...
        'NCF %.4g (max achievable %.4g). The search will minimize ' ...
        'the shortfall instead.\n'], config.target_ncf_margin, ...
        max(ncf_map(:)))
end
end

function boundary = ncfBoundaryPoints(state, centers, ratios, ncf_map)
% Interpolated (center, ratio) points where NCF crosses the target,
% bisected onto the feasible side so they can be simulated directly.
target = state.config.target_ncf_margin;
log_ratio = log(ratios(:).');
boundary = zeros(0, 2);
for center_id = 1:numel(centers)
    row = ncf_map(center_id, :) - target;
    crossings = find(row(1:end-1).*row(2:end) < 0);
    for k = crossings
        if row(k) >= 0
            feasible_log_ratio = log_ratio(k);
            infeasible_log_ratio = log_ratio(k+1);
        else
            feasible_log_ratio = log_ratio(k+1);
            infeasible_log_ratio = log_ratio(k);
        end
        refined = bisectBoundaryRatio(state.problem, ...
            centers(center_id), feasible_log_ratio, ...
            infeasible_log_ratio, target);
        boundary(end+1, :) = [centers(center_id), refined]; %#ok<AGROW>
    end
end
end

function ratio = bisectBoundaryRatio(problem, center_hz, ...
        feasible_log_ratio, infeasible_log_ratio, target)
for iteration = 1:8
    middle = (feasible_log_ratio + infeasible_log_ratio)/2;
    ncf = ncfFromCenterRatio(problem, center_hz, exp(middle));
    if ncf + 1e-9 >= target
        feasible_log_ratio = middle;
    else
        infeasible_log_ratio = middle;
    end
end
ratio = exp(feasible_log_ratio);
end

%% ----------------------------------------------------------------------
%% Stage 2: J4 exploration (feasible interior + NCF boundary)
%% ----------------------------------------------------------------------

function state = exploreStage(state)
config = state.config;
map = state.map;
interior = feasibleInteriorPoints(map, config.explore_budget);
boundary = strideSelect(map.boundary, config.boundary_budget);
plan = [interior; boundary];
if isempty(plan)
    % Nothing feasible: probe the highest-NCF points so refinement has
    % sensible seeds to reduce the shortfall from.
    [~, order] = sort(map.ncf(:), 'descend');
    take = order(1:min(config.explore_budget, numel(order)));
    [center_id, ratio_id] = ind2sub(size(map.ncf), take);
    plan = [map.centers(center_id), map.ratios(ratio_id)];
    fprintf(['\n[2/4] J4 exploration: %d highest-NCF probes ' ...
        '(no feasible region in the map)\n'], size(plan, 1))
else
    fprintf(['\n[2/4] J4 exploration: %d interior + %d boundary ' ...
        'simulations\n'], size(interior, 1), size(boundary, 1))
end
state = beginStage(state, 'explore', size(plan, 1));
for plan_id = 1:size(plan, 1)
    phase_lead = phaseLeadFromCenterRatioV2(plan(plan_id, 1), ...
        plan(plan_id, 2), config.phase_lead_section_count);
    [state, ~] = evaluateLogged(state, phase_lead, 'explore');
end
state = printStageProgress(state, true);
state = maybeSaveCheckpoint(state, 'explore', true);
end

function points = feasibleInteriorPoints(map, budget)
% Coarse sublattice of the feasible region, spread over the map.
points = zeros(0, 2);
if budget <= 0 || ~any(map.feasible(:))
    return
end
[n_center, n_ratio] = size(map.feasible);
stride = 1;
while true
    center_ids = 1:stride:n_center;
    ratio_ids = 1:stride:n_ratio;
    mask = map.feasible(center_ids, ratio_ids);
    if nnz(mask) <= budget || stride > max(n_center, n_ratio)
        break
    end
    stride = stride + 1;
end
[center_sub, ratio_sub] = find(mask);
points = [map.centers(center_ids(center_sub(:))), ...
    map.ratios(ratio_ids(ratio_sub(:)))];
points = strideSelect(points, budget);
end

function points = strideSelect(points, budget)
if isempty(points) || size(points, 1) <= budget
    return
end
ids = round(linspace(1, size(points, 1), budget));
points = points(unique(ids), :);
end

function phase_lead = phaseLeadFromCenterRatioV2(center_hz, ratio, ...
        section_count)
center_hz = center_hz*ones(1, section_count);
ratio = repmat(ratio^(1/section_count), 1, section_count);
phase_lead = phaseLeadFromCentersRatiosV2(center_hz, ratio);
end

function phase_lead = phaseLeadFromCentersRatiosV2(center_hz, ratio)
zero_hz = center_hz./sqrt(ratio);
pole_hz = center_hz.*sqrt(ratio);
gain = prod(ratio);
phase_lead = normalizePhaseLeadConfig([gain, zero_hz, pole_hz]);
end

%% ----------------------------------------------------------------------
%% Stage 3: adaptive zoom refinement around the top seeds
%% ----------------------------------------------------------------------

function state = zoomStage(state)
config = state.config;
seeds = pickZoomSeeds(state);
if isempty(seeds)
    fprintf('\n[3/4] Local zoom refinement skipped: no seeds.\n')
    return
end
grid_n = max(3, round(config.zoom_grid_size));
budget_estimate = size(seeds, 1)*config.zoom_iterations*grid_n^2;
fprintf('\n[3/4] Local zoom refinement: %d seed(s) x %d iterations\n', ...
    size(seeds, 1), config.zoom_iterations)
state = beginStage(state, 'zoom', budget_estimate);

log_center_bounds = log(config.center_frequency_bounds_hz);
log_ratio_bounds = log(config.ratio_bounds);
map_spacing = [ ...
    diff(log(config.center_frequency_bounds_hz)) ...
        /max(config.map_center_count - 1, 1), ...
    diff(log(config.ratio_bounds))/max(config.map_ratio_count - 1, 1)];

for seed_id = 1:size(seeds, 1)
    location = log(seeds(seed_id, :));
    half_width = 1.5*map_spacing;
    seed_best = [];
    for iteration = 1:config.zoom_iterations
        center_axis = linspace( ...
            max(location(1) - half_width(1), log_center_bounds(1)), ...
            min(location(1) + half_width(1), log_center_bounds(2)), ...
            grid_n);
        ratio_axis = linspace( ...
            max(location(2) - half_width(2), log_ratio_bounds(1)), ...
            min(location(2) + half_width(2), log_ratio_bounds(2)), ...
            grid_n);
        [center_grid, ratio_grid] = ndgrid(exp(center_axis), ...
            exp(ratio_axis));
        candidates = [center_grid(:), ratio_grid(:)];
        ncf = ncfFromCenterRatio(state.problem, candidates(:, 1), ...
            candidates(:, 2));
        near_feasible = ncf + 0.02 >= config.target_ncf_margin;
        if ~any(near_feasible)
            % Fully infeasible box: keep the best-NCF corner to walk
            % the shortfall down.
            [~, keep] = max(ncf);
            near_feasible(keep) = true;
        end
        candidates = candidates(near_feasible, :);
        for candidate_id = 1:size(candidates, 1)
            phase_lead = phaseLeadFromCenterRatioV2( ...
                candidates(candidate_id, 1), ...
                candidates(candidate_id, 2), ...
                config.phase_lead_section_count);
            [state, candidate] = evaluateLogged(state, phase_lead, ...
                'zoom');
            reduced = struct('phase_lead', candidate.phase_lead, ...
                'metrics', candidate.metrics);
            if isempty(seed_best) || candidateBeats(reduced, seed_best)
                seed_best = reduced;
            end
        end
        if ~isempty(seed_best)
            location = log([ ...
                geometricMean(seed_best.phase_lead.center_frequency_hz), ...
                prod(seed_best.phase_lead.section_ratio)]);
        end
        half_width = half_width/2;
    end
end
state = printStageProgress(state, true);
state = maybeSaveCheckpoint(state, 'zoom', true);
end

function value = geometricMean(values)
value = exp(mean(log(values)));
end

function seeds = pickZoomSeeds(state)
% Top distinct evaluated candidates (feasible-first), separated by a
% minimum distance in log space so seeds do not collapse to one basin.
config = state.config;
history = state.history;
if isempty(history)
    seeds = zeros(0, 2);
    return
end
enabled = arrayfun(@(entry) entry.Gain > 0 ...
    && all(isfinite(entry.Center_Hz)), history);
history = history(enabled);
if isempty(history)
    seeds = zeros(0, 2);
    return
end
ranking = sortrows([~[history.Feasible].', [history.Objective].', ...
    [history.Score].', (1:numel(history)).'], [1 2 3]);
seeds = zeros(0, 2);
for rank_id = 1:size(ranking, 1)
    entry = history(ranking(rank_id, 4));
    point = [geometricMean(entry.Center_Hz), prod(entry.Ratio)];
    if isempty(seeds) || all(sum(abs(log(seeds) - log(point)), 2) > 0.2)
        seeds(end+1, :) = point; %#ok<AGROW>
    end
    if size(seeds, 1) >= config.zoom_seed_count
        break
    end
end
end

%% ----------------------------------------------------------------------
%% Stage 4: fmincon polish with the NCF target as a hard constraint
%% ----------------------------------------------------------------------

function state = polishStage(state)
config = state.config;
if ~config.use_fmincon_polish
    fprintf('\n[4/4] fmincon polish disabled by config.\n')
    return
end
if exist('fmincon', 'file') ~= 2
    fprintf('\n[4/4] fmincon polish skipped: Optimization Toolbox missing.\n')
    return
end
starts = polishStartPoints(state);
if isempty(starts)
    fprintf('\n[4/4] fmincon polish skipped: no start points.\n')
    return
end
section_count = config.phase_lead_section_count;
section_ratio_bounds = config.ratio_bounds.^(1/section_count);
lower_bounds = log([ ...
    repmat(config.center_frequency_bounds_hz(1), 1, section_count), ...
    repmat(section_ratio_bounds(1), 1, section_count)]);
upper_bounds = log([ ...
    repmat(config.center_frequency_bounds_hz(2), 1, section_count), ...
    repmat(section_ratio_bounds(2), 1, section_count)]);
fprintf('\n[4/4] fmincon polish (NCF >= %.4g as nonlinear constraint), %d start(s)\n', ...
    config.target_ncf_margin, size(starts, 1))
state = beginStage(state, 'polish', ...
    size(starts, 1)*config.polish_max_evaluations);
options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'Display', 'off', ...
    'MaxIterations', config.polish_max_iterations, ...
    'MaxFunctionEvaluations', config.polish_max_evaluations, ...
    'FiniteDifferenceType', 'central');
for start_id = 1:size(starts, 1)
    x0 = min(max(log(starts(start_id, :)), lower_bounds), upper_bounds);
    try
        x_optimal = fmincon(@polishObjective, x0, [], [], [], [], ...
            lower_bounds, upper_bounds, @polishConstraint, options);
        [state, ~] = evaluateLogged(state, ...
            phaseLeadFromXV2(x_optimal, section_count), 'polish');
    catch err
        fprintf('      fmincon start %d failed: %s\n', start_id, ...
            err.message)
    end
end
state = printStageProgress(state, true);
state = maybeSaveCheckpoint(state, 'polish', true);

    function objective = polishObjective(x)
    [state, candidate] = evaluateLogged(state, ...
        phaseLeadFromXV2(x, section_count), 'polish');
    objective = candidate.metrics.objective;
    if ~isfinite(objective)
        objective = 1e6*(1 + candidate.metrics.max_abs_pole);
    end
    end

    function [inequality, equality] = polishConstraint(x)
    phase_lead = normalizePhaseLeadConfig( ...
        phaseLeadFromXV2(x, section_count), section_count);
    freq_metrics = numPhaseLeadExpMetricsV2(state.problem, phase_lead);
    lead = discreteSisoStruct(buildPhaseLeadFilter(phase_lead, ...
        state.problem.sample_dt), state.problem.sample_dt);
    loop = buildClosedLoopV2(state.problem, lead);
    stability_margin = 1 - max(abs(eig(loop.A)));
    inequality = [ ...
        config.target_ncf_margin - freq_metrics.ncf_margin; ...
        config.minimum_stability_margin - stability_margin];
    equality = [];
    end
end

function starts = polishStartPoints(state)
config = state.config;
starts = zeros(0, 2*config.phase_lead_section_count);
if isempty(state.history)
    return
end
seeds = pickZoomSeeds(state);
take = min(size(seeds, 1), max(1, round(config.polish_start_count)));
for seed_id = 1:take
    center_hz = seeds(seed_id, 1) ...
        *ones(1, config.phase_lead_section_count);
    section_ratio = seeds(seed_id, 2)^ ...
        (1/config.phase_lead_section_count) ...
        *ones(1, config.phase_lead_section_count);
    starts(end+1, :) = [center_hz, section_ratio]; %#ok<AGROW>
end
end

function phase_lead = phaseLeadFromXV2(x, section_count)
values = exp(x(:).');
center_hz = values(1:section_count);
ratio = values(section_count+1:2*section_count);
phase_lead = phaseLeadFromCentersRatiosV2(center_hz, ratio);
end

%% ----------------------------------------------------------------------
%% Finalization: full-record validation, tables, saving, plots
%% ----------------------------------------------------------------------

function result = finalizeOptimization(state, optimization_baseline, ...
        project_root, total_timer)
config = state.config;
fprintf(['\nSearch finished: %d simulations in %s. ' ...
    'Validating on the full record...\n'], state.sim_count, ...
    formatDurationSecondsV2(toc(state.start_time)))

if config.optimization_record_fraction < 1
    report_problem = preparePhaseLeadProblemV2(project_root, ...
        config, 1);
else
    report_problem = state.problem;
end
baseline = evaluateCandidateV2(report_problem, []);
if isempty(state.best) || ~state.best.phase_lead.enabled
    best = baseline;
else
    best = evaluateCandidateV2(report_problem, state.best.phase_lead);
end

% Rank exactly like the search: feasible first (by objective, which
% equals the legacy score there), infeasible by shortfall-penalized
% score so near-target candidates surface instead of unsafe ones.
optimization_result_table = struct2table(state.history);
optimization_result_table = sortrows(optimization_result_table, ...
    {'Feasible', 'Score'}, {'descend', 'ascend'});
phase_lead_result_table = struct2table([ ...
    historyEntry('full_baseline', 0, baseline); ...
    historyEntry('full_best', 0, best)]);

fprintf('\n--- Result summary (full record) ---\n')
fprintf(['Baseline : J4 = %.6g %%, NCF = %.6g, GM = %.4g dB, ' ...
    'PM = %.4g deg\n'], baseline.metrics.j4_percent, ...
    baseline.metrics.num_phase_lead_exp_ncf_margin, ...
    baseline.metrics.num_phase_lead_exp_gm_db, ...
    baseline.metrics.num_phase_lead_exp_pm_deg)
fprintf(['Best     : J4 = %.6g %%, NCF = %.6g, GM = %.4g dB, ' ...
    'PM = %.4g deg, feasible = %d\n'], best.metrics.j4_percent, ...
    best.metrics.num_phase_lead_exp_ncf_margin, ...
    best.metrics.num_phase_lead_exp_gm_db, ...
    best.metrics.num_phase_lead_exp_pm_deg, best.metrics.feasible)
if best.phase_lead.enabled
    fprintf('G_T      : %s\n', phaseLeadSummaryV2(best.phase_lead))
end
top_rows = min(10, height(optimization_result_table));
disp(optimization_result_table(1:top_rows, {'Stage', 'Feasible', ...
    'Objective', 'J4_percent', 'NumPhaseLeadExpNCFMargin', 'Zero_Hz', ...
    'Pole_Hz', 'Gain', 'MaxPhaseLead_deg'}))

if ~best.metrics.feasible
    fprintf(['\nNOTE: the NCF target %.4g is not reachable inside the ' ...
        'search bounds; the reported best is the candidate that gets ' ...
        'closest (NCF %.6g) with the lowest J4. Consider lowering the ' ...
        'target, widening the bounds, or using more sections.\n'], ...
        config.target_ncf_margin, ...
        best.metrics.num_phase_lead_exp_ncf_margin)
end
best_reduced = struct('phase_lead', best.phase_lead, ...
    'metrics', best.metrics);
baseline_reduced = struct('phase_lead', baseline.phase_lead, ...
    'metrics', baseline.metrics);
recommend_best = best.phase_lead.enabled ...
    && candidateBeats(best_reduced, baseline_reduced);
if recommend_best
    recommended_phase_lead_override = struct('enabled', true, ...
        'gain', best.phase_lead.gain, ...
        'zero_hz', best.phase_lead.zero_hz, ...
        'pole_hz', best.phase_lead.pole_hz);
    fprintf('\nRecommended phase_lead configuration:\nphase_lead = %s;\n', ...
        phaseLeadStructLiteralV2(best.phase_lead))
else
    recommended_phase_lead_override = [];
    fprintf(['\nRecommendation: leave phase_lead disabled; no ' ...
        'candidate improved on the baseline.\n'])
end

saved_paths = table;
if config.save_results
    saved_paths = savePhaseLeadFilesV2(project_root, best, config, ...
        baseline.metrics, best.phase_lead, best.metrics, ...
        recommended_phase_lead_override, phase_lead_result_table, ...
        optimization_result_table);
    fprintf('\nSaved phase_lead optimization results = %s\n', ...
        saved_paths.Path(1))
end

if config.plot_results
    plotSearchMap(state, best)
    plotTimeDomainCheck(report_problem, best)
end

if config.print_validation_tables
    printValidationMetricsV2(report_problem, baseline, best)
    printStabilitySummaryV2(report_problem, best.phase_lead)
end

fprintf('\nTotal optimizer time: %s (%d closed-loop simulations)\n', ...
    formatDurationSecondsV2(toc(total_timer)), state.sim_count)

result = struct( ...
    'best_phase_lead', best.phase_lead, ...
    'best_metrics', best.metrics, ...
    'baseline_metrics', baseline.metrics, ...
    'best', best, ...
    'baseline', baseline, ...
    'optimization_baseline_metrics', optimization_baseline.metrics, ...
    'recommended_phase_lead_override', recommended_phase_lead_override, ...
    'optimization_result_table', optimization_result_table, ...
    'phase_lead_result_table', phase_lead_result_table, ...
    'map', state.map, ...
    'config', sanitizeConfigForSave(config), ...
    'sim_count', state.sim_count, ...
    'saved_paths', saved_paths);
end

function text = phaseLeadSummaryV2(phase_lead)
text = sprintf(['k_T = %.12g, z_hz = %s, p_hz = %s, DC gain = %.12g, ' ...
    'max lead = %.6g deg at %.6g Hz'], ...
    phase_lead.gain, vectorLiteralV2(phase_lead.zero_hz), ...
    vectorLiteralV2(phase_lead.pole_hz), phase_lead.dc_gain, ...
    phase_lead.max_phase_lead_deg, ...
    phase_lead.max_phase_lead_frequency_hz);
end

function text = phaseLeadStructLiteralV2(phase_lead)
text = sprintf(['struct(''enabled'', true, ''gain'', %.12g, ' ...
    '''zero_hz'', %s, ''pole_hz'', %s)'], ...
    phase_lead.gain, vectorLiteralV2(phase_lead.zero_hz), ...
    vectorLiteralV2(phase_lead.pole_hz));
end

function text = vectorLiteralV2(values)
values = values(:).';
parts = arrayfun(@(value) sprintf('%.12g', value), values, ...
    'UniformOutput', false);
if isscalar(values)
    text = parts{1};
else
    text = ['[' strjoin(parts, ' ') ']'];
end
end

%% ----------------------------------------------------------------------
%% Saving (legacy-compatible phase_lead MAT format)
%% ----------------------------------------------------------------------

function saved_paths = savePhaseLeadFilesV2(project_root, best, ...
        config, baseline_metrics, best_phase_lead, best_metrics, ...
        recommended_phase_lead_override, phase_lead_result_table, ...
        optimization_result_table)
phase_lead_dir = fullfile(project_root, 'saved_results', 'phase_lead');
if ~exist(phase_lead_dir, 'dir')
    mkdir(phase_lead_dir)
end
file_name = promptPhaseLeadFileNameV2(phase_lead_dir, ...
    config.phase_lead_file_name);
path = string(fullfile(phase_lead_dir, file_name));
phase_lead_tf = continuousPhaseLeadTransferFunctionV2(best.phase_lead);
phase_lead = best.phase_lead;
metrics = best.metrics;
phase_lead_label = 'performance';
phase_lead_name = file_name;
created_at = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
config = sanitizeConfigForSave(config);
save(char(path), 'phase_lead_tf', 'phase_lead', 'metrics', ...
    'phase_lead_label', 'phase_lead_name', 'created_at', ...
    'config', 'baseline_metrics', 'best_phase_lead', 'best_metrics', ...
    'recommended_phase_lead_override', 'phase_lead_result_table', ...
    'optimization_result_table')
verifySavedPhaseLeadFileV2(path, phase_lead);
saved_paths = table(string(phase_lead_label), path, ...
    'VariableNames', {'Label', 'Path'});
end

function file_name = promptPhaseLeadFileNameV2(phase_lead_dir, file_name)
if ~isempty(file_name)
    file_name = cleanPhaseLeadFileNameV2(file_name);
    return
end
while true
    file_name = strtrim(input( ...
        'phase_lead file name to save under saved_results/phase_lead: ', ...
        's'));
    if isempty(file_name)
        fprintf('Enter a nonempty MAT filename.\n')
        continue
    end
    try
        file_name = cleanPhaseLeadFileNameV2(file_name);
    catch err
        fprintf('%s\n', err.message)
        continue
    end
    file_path = fullfile(phase_lead_dir, file_name);
    if isfile(file_path)
        overwrite = strtrim(input( ...
            sprintf('File exists: %s. Overwrite? [y/N]: ', file_name), 's'));
        if ~any(strcmpi(overwrite, {'y', 'yes'}))
            continue
        end
    end
    return
end
end

function file_name = cleanPhaseLeadFileNameV2(file_name)
[folder, name, ext] = fileparts(char(file_name));
if ~isempty(folder)
    error('optimize_vHS_phase_lead_v2:InvalidFileName', ...
        'Enter only a filename, not a folder path.')
end
if isempty(ext)
    ext = '.mat';
elseif ~strcmpi(ext, '.mat')
    error('optimize_vHS_phase_lead_v2:InvalidFileName', ...
        'Use a .mat filename.')
end
file_name = [name ext];
end

function verifySavedPhaseLeadFileV2(path, expected_phase_lead)
saved = load(char(path), 'phase_lead_tf', 'phase_lead');
assert(isfield(saved, 'phase_lead_tf') && isa(saved.phase_lead_tf, 'tf'), ...
    'optimize_vHS_phase_lead_v2:SaveFailed', ...
    'Saved phase_lead file is missing phase_lead_tf.')
assert(isfield(saved, 'phase_lead') ...
    && isequaln(saved.phase_lead, expected_phase_lead), ...
    'optimize_vHS_phase_lead_v2:SaveFailed', ...
    'Saved phase_lead file does not match the selected candidate.')
end

function phase_lead_tf = continuousPhaseLeadTransferFunctionV2(phase_lead)
phase_lead = normalizePhaseLeadConfig(phase_lead);
if ~phase_lead.enabled
    phase_lead_tf = tf(1);
    return
end
phase_lead_tf = phase_lead.gain ...
    * tf(poly(-phase_lead.zero_rad_s), poly(-phase_lead.pole_rad_s));
end

%% ----------------------------------------------------------------------
%% Plots
%% ----------------------------------------------------------------------

function plotSearchMap(state, best)
map = state.map;
if isempty(map)
    return
end
config = state.config;
colors = plotColorsV2();
figure('Color', 'w', 'Name', 'phase_lead NCF feasibility map');
[ratio_grid, center_grid] = meshgrid(map.ratios, map.centers);
contourf(center_grid, ratio_grid, map.ncf, 20, 'LineStyle', 'none')
hold on
contour(center_grid, ratio_grid, map.ncf, ...
    config.target_ncf_margin*[1 1], 'LineColor', 'k', 'LineWidth', 2)
history = state.history;
enabled = arrayfun(@(entry) entry.Gain > 0 ...
    && all(isfinite(entry.Center_Hz)), history);
history = history(enabled);
if ~isempty(history)
    center_points = arrayfun(@(entry) geometricMean(entry.Center_Hz), ...
        history);
    ratio_points = arrayfun(@(entry) prod(entry.Ratio), history);
    feasible_points = [history.Feasible];
    scatter(center_points(~feasible_points), ...
        ratio_points(~feasible_points), 14, colors.red, 'filled', ...
        'MarkerFaceAlpha', 0.5)
    scatter(center_points(feasible_points), ...
        ratio_points(feasible_points), 14, colors.green, 'filled', ...
        'MarkerFaceAlpha', 0.7)
end
if best.phase_lead.enabled
    plot(geometricMean(best.phase_lead.center_frequency_hz), ...
        prod(best.phase_lead.section_ratio), 'p', ...
        'MarkerSize', 16, 'MarkerFaceColor', colors.copperwood, ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1.2)
end
hold off
set(gca, 'XScale', 'log', 'YScale', 'log')
colorbar_handle = colorbar;
colorbar_handle.Label.String = 'NCF margin';
xlabel('Center frequency \surd(z\cdotp) (Hz)')
ylabel('Total pole/zero ratio')
title(sprintf(['NCF feasibility map (target %.3g, black contour) | ' ...
    'dots: simulated candidates | star: best'], ...
    config.target_ncf_margin))
end

function plotTimeDomainCheck(problem, best)
colors = plotColorsV2();
figure('Color', 'w', 'Name', 'phase_lead v2 control check');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
plot(ax, problem.time, best.signals.dd_sample, 'k--', 'LineWidth', 2.2, ...
    'DisplayName', 'd\_n (numerical sub)');
hold(ax, 'on')
if best.phase_lead.enabled
    plot(ax, problem.time, best.signals.dd_lead_sample, '--', ...
        'Color', colors.green, 'LineWidth', 1.5, ...
        'DisplayName', 'phase_lead d\_n');
end
plot(ax, problem.time, 1000*problem.d_reference_sample, '-', ...
    'Color', colors.red, 'LineWidth', 1.1, ...
    'DisplayName', 'd\_r (full FEM)');
plot(ax, problem.time, best.signals.dc_sample, '-', ...
    'Color', colors.copperwood, 'LineWidth', 1.0, ...
    'DisplayName', 'dc (command)');
plot(ax, problem.time, best.signals.dm_sample, '-', ...
    'Color', colors.blue, 'LineWidth', 1.0, ...
    'DisplayName', 'dm (measured)');
hold(ax, 'off')
grid(ax, 'on')
ylabel(ax, 'Displacement (mm)')
legend(ax, 'Location', 'best');

ax = nexttile;
plot(ax, problem.time, best.signals.force_sample, '-', ...
    'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm (measured force)');
grid(ax, 'on')
ylabel(ax, 'Force (N)')
xlabel(ax, 'Real time (s)')
legend(ax, 'Location', 'best');
title(layout, 'num*G_T*PID*H_{dc,dm}*exp control check (v2 best)')
linkaxes(findall(gcf, 'Type', 'axes'), 'x');
end

function colors = plotColorsV2()
colors.green = hexToRgbV2('39BF5E');
colors.blue = hexToRgbV2('007CA8');
colors.copperwood = hexToRgbV2('AC6420');
colors.red = hexToRgbV2('901500');
colors.purple = hexToRgbV2('74058A');
end

function rgb = hexToRgbV2(hex_color)
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end

%% ----------------------------------------------------------------------
%% Validation tables (same reporting as the legacy engine)
%% ----------------------------------------------------------------------

function printValidationMetricsV2(problem, baseline, best)
metric_table = buildValidationMetricTableV2(problem, baseline, best);
if best.phase_lead.enabled
    control_path_label = 'num*G_T*PID*H_{dc,dm}*exp';
else
    control_path_label = 'num*PID*H_{dc,dm}*exp';
end
fprintf('\nControl path: %s\n', control_path_label);
disp(metric_table)
end

function metric_table = buildValidationMetricTableV2(problem, baseline, ...
        best)
metric = validation_metrics();
baseline_values = validationValuesV2(problem, baseline, metric);
best_values = validationValuesV2(problem, best, metric);
metric_names = {'J1'; 'J2'; 'J3'; 'J4'; 'J5'; 'J6'; 'J7'};
metric_descriptions = { ...
    'finddelay(d_n, dm_filtfilt)*dt'; ...
    '100*std(dm_filtfilt - d_n)/std(d_n)'; ...
    '100*max(abs(dm_filtfilt - d_n))/max(abs(d_n))'; ...
    '100*std(x1_n - x1_r)/std(x1_r)'; ...
    '100*std(x2_n - x2_r)/std(x2_r)'; ...
    '100*std(x3_n - x3_r)/std(x3_r)'; ...
    '100*mean((dm_filtfilt - d_r)^2)/mean(d_r^2)'};
metric_units = {'ms'; '%'; '%'; '%'; '%'; '%'; '%'};
metric_table = table(metric_names, metric_descriptions, metric_units, ...
    [NaN; NaN; NaN; baseline_values(4:6); NaN], ...
    best_values, ...
    'VariableNames', {'Metric', 'Description', 'Unit', ...
        'NumExp', 'ControlPath'});
end

function values = validationValuesV2(problem, candidate, metric)
fs = 1/problem.sample_dt;
dm_filtfilt = filtfiltDmV2(candidate.signals.dm_sample, fs, 20, 6);
d_r_mm = 1000*problem.d_reference_sample(:);
values = [ ...
    metric.J1(dm_filtfilt, candidate.signals.dd_sample, ...
        problem.sample_dt); ...
    metric.J2(dm_filtfilt, candidate.signals.dd_sample); ...
    metric.J3(dm_filtfilt, candidate.signals.dd_sample); ...
    metric.J4(candidate.signals.u_num_floors_sample(:, 1), ...
        problem.u_reference_sample(:, 1)); ...
    metric.J5(candidate.signals.u_num_floors_sample(:, 2), ...
        problem.u_reference_sample(:, 2)); ...
    metric.J6(candidate.signals.u_num_floors_sample(:, 3), ...
        problem.u_reference_sample(:, 3)); ...
    metric.J7(dm_filtfilt, d_r_mm)];
end

function y = filtfiltDmV2(dm, fs, cutoff_hz, order)
[b, a] = butter(order, cutoff_hz/(fs/2), 'low');
y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function printStabilitySummaryV2(problem, phase_lead)
phase_lead_tf_discrete = buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt);
hybrid_margin_frequency_hz = [0.1, 80];
stability_table = buildStabilityTableV2(problem, ...
    phase_lead_tf_discrete, hybrid_margin_frequency_hz);
disp('Stability table')
disp(stability_table)
end

function stability_table = buildStabilityTableV2(problem, ...
        phase_lead_tf_discrete, freq_range_hz)
num_tf = problem.num_tf;
k_mm = problem.k_mm;
PID_H_dc_dm = problem.PID_H_dc_dm;
unity_lead = discreteSisoStruct(tf(1, 1, problem.sample_dt), ...
    problem.sample_dt);
lead = discreteSisoStruct(phase_lead_tf_discrete, problem.sample_dt);
num_exp_loop = buildClosedLoopV2(problem, unity_lead);
num_lead_exp_loop = buildClosedLoopV2(problem, lead);

exp_metrics = stabilityMetricsV2(problem.actuator_open_loop, ...
    maxAbsPoleV2(PID_H_dc_dm), freq_range_hz);
num_exp_metrics = stabilityMetricsV2( ...
    -minreal(num_tf*k_mm*PID_H_dc_dm), ...
    max(abs(eig(num_exp_loop.A))), freq_range_hz);
num_phase_lead_exp_metrics = stabilityMetricsV2( ...
    -minreal(num_tf*k_mm*phase_lead_tf_discrete*PID_H_dc_dm), ...
    max(abs(eig(num_lead_exp_loop.A))), freq_range_hz);

stability_table = array2table([ ...
    metricColumnV2(exp_metrics), ...
    metricColumnV2(num_exp_metrics), ...
    metricColumnV2(num_phase_lead_exp_metrics)], ...
    'VariableNames', {'PID_H_dc_dm', 'num_exp', ...
    'num_phase_lead_exp'}, ...
    'RowNames', {'GM_dB', 'PM_deg', 't_cr_s', 'NCF_margin', ...
    'MaxAbsZPole'});
end

function metrics = stabilityMetricsV2(open_loop, max_abs_z_pole, ...
        freq_range_hz)
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    custom_stability_margins(open_loop, freq_range_hz);
margins = allmargin(open_loop);
metrics.t_cr_s = min([margins.DelayMargin(:); Inf]);
metrics.max_abs_z_pole = max_abs_z_pole;
end

function values = metricColumnV2(metrics)
values = [metrics.gm_db; metrics.pm_deg; metrics.t_cr_s; ...
    metrics.ncf_margin; metrics.max_abs_z_pole];
end

function value = maxAbsPoleV2(system_model)
poles = pole(system_model);
value = max([abs(poles(:)); 0]);
end
