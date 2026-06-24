%% Optimize vHS Phase Lead After Numerical DD
% The compensated path is:
% raw numerical dd -> G_T -> actuator tracking loop -> measured dm -> force.
% G_T(s) = k_T*(s + z1)/(s + p1), with p1 > z1.

clearvars -except phase_lead_optimizer_config fem_file_override ...
    h_dc_dm_model_file_override pid_gain_override; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', ...
    'id_utils'));

config = defaultPhaseLeadOptimizerConfig();
if exist('phase_lead_optimizer_config', 'var') ...
        && ~isempty(phase_lead_optimizer_config)
    config = mergeStruct(config, phase_lead_optimizer_config);
end
if exist('pid_gain_override', 'var')
    config.pid_gain_override = pid_gain_override;
end
if exist('h_dc_dm_model_file_override', 'var') ...
        && ~isempty(h_dc_dm_model_file_override)
    config.h_dc_dm_model_file = h_dc_dm_model_file_override;
end
if exist('fem_file_override', 'var') && ~isempty(fem_file_override)
    config.fem_file = fem_file_override;
end

problem = prepareVhsPhaseLeadProblem(project_root, config);
baseline = evaluateVhsPhaseLead(problem, []);
log_entries = summarizeCandidate('baseline', baseline);

fprintf('\nBaseline without phase lead\n')
printCandidate(baseline)

[grid_candidates, log_entries] = evaluatePhaseLeadGrid(problem, log_entries);
[best, log_entries] = optimizePhaseLeadForPerformance( ...
    problem, baseline, log_entries, grid_candidates);
[stability_designs, log_entries] = optimizePhaseLeadForStabilityTargets( ...
    problem, baseline, log_entries, grid_candidates);

phase_lead_result_table = struct2table(log_entries);
phase_lead_result_table = sortrows(phase_lead_result_table, 'Score');
phase_lead_stability_table = stabilityDesignsToTable(stability_designs);
baseline_metrics = baseline.metrics;
best_phase_lead = best.phase_lead;
best_metrics = best.metrics;

fprintf('\nBest candidate\n')
printCandidate(best)
disp(phase_lead_result_table(:, {'Stage', 'Score', 'Zero_Hz', ...
    'Pole_Hz', 'Gain', 'MaxPhaseLead_deg', 'ResponseNRMSE_percent', ...
    'TrackingNRMSE_percent', 'StabilityMargin', 'MaxAbsPole', ...
    'PeakCommandRatio'}))

baseline_feasible = candidateMeetsMinimums(baseline, config, Inf);
recommend_best = best.phase_lead.enabled ...
    && (~baseline_feasible || best.metrics.score < baseline.metrics.score);
if ~recommend_best
    recommended_phase_lead_override = [];
    fprintf(['\nRecommendation: leave phase lead disabled for this objective; ' ...
        'the best active candidate did not improve the baseline score.\n'])
else
    recommended_phase_lead_override = struct('enabled', true, ...
        'gain', best_phase_lead.gain, ...
        'zero_hz', best_phase_lead.zero_hz, ...
        'pole_hz', best_phase_lead.pole_hz);
    fprintf(['\nRecommended phase-lead configuration:\nphase_lead = ' ...
        'struct(''enabled'', true, ''gain'', %.12g, ' ...
        '''zero_hz'', %.12g, ''pole_hz'', %.12g);\n'], ...
        best_phase_lead.gain, best_phase_lead.zero_hz, ...
        best_phase_lead.pole_hz)
end

recommended_stability_phase_lead_overrides = ...
    stabilityOverridesFromDesigns(stability_designs);
if ~isempty(stability_designs)
    fprintf('\nNRMSE-capped high-stability compensators\n')
    disp(phase_lead_stability_table)
    for design_id = 1:numel(stability_designs)
        variable_name = sprintf('phase_lead_override_nrms%d', ...
            round(stability_designs(design_id).target_nrmse_percent));
        printPhaseLeadOverride(variable_name, ...
            stability_designs(design_id).candidate)
    end
end

if config.save_results
    results_dir = fullfile(project_root, 'saved_results', 'models');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir)
    end
    run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    delay_comp_paths = saveDelayCompensatorFiles(project_root, ...
        run_timestamp, best, stability_designs);
    phase_lead_results_path = fullfile(results_dir, ...
        sprintf('vHS_phase_lead_%s.mat', run_timestamp));
    save(phase_lead_results_path, 'config', 'baseline_metrics', ...
        'best_phase_lead', 'best_metrics', 'recommended_phase_lead_override', ...
        'recommended_stability_phase_lead_overrides', ...
        'phase_lead_result_table', 'phase_lead_stability_table', ...
        'delay_comp_paths')
    fprintf('\nSaved phase-lead optimization results = %s\n', ...
        phase_lead_results_path)
else
    phase_lead_results_path = '';
end

if config.plot_results
    plotPhaseLeadOptimization(problem, baseline, best)
end

function config = defaultPhaseLeadOptimizerConfig()
config = struct( ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.2, ...
    'time_scale_factor', 1, ...
    'force_sign', 1.0, ...
    'k_exp_r', 1.0, ...
    'sample_dt', 1/2048, ...
    'h_dc_dm_model_file', '', ...
    'fem_file', '', ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    'center_frequency_bounds_hz', [0.5 80], ...
    'ratio_bounds', [1.01 25], ...
    'grid_center_hz', [1 2 3 4 8 12 18 27 40 60], ...
    'grid_ratio', [1.05 1.2 1.5 2 3 5 8 12 14 15 18], ...
    'start_points', [3 14; 4 15; 5 17; 4 2; 8 3; 12 5; 20 8; 40 5], ...
    'minimum_stability_margin', 0, ...
    'stability_nrmse_targets_percent', [20 40], ...
    'stability_tie_break_weight', 1e-8, ...
    'minimum_margin_penalty_weight', 1e8, ...
    'use_fmincon', true, ...
    'use_stability_fmincon', false, ...
    'max_abs_pole_target', 0.998, ...
    'tracking_error_weight', 0.20, ...
    'lead_change_weight', 0.02, ...
    'pole_penalty_weight', 200, ...
    'command_ratio_penalty_weight', 20, ...
    'max_peak_command_ratio', 3, ...
    'max_iterations', 50, ...
    'max_function_evaluations', 200, ...
    'plot_results', true, ...
    'save_results', true);
end

function config = mergeStruct(config, override)
fields = fieldnames(override);
for field_id = 1:numel(fields)
    config.(fields{field_id}) = override.(fields{field_id});
end
end

function [grid_candidates, log_entries] = evaluatePhaseLeadGrid( ...
        problem, log_entries)
config = problem.config;
grid_centers = config.grid_center_hz(:);
grid_ratios = config.grid_ratio(:);
grid_candidates = repmat(struct('phase_lead', [], 'metrics', []), ...
    numel(grid_centers)*numel(grid_ratios), 1);
grid_index = 0;

fprintf('\nGrid search for phase-lead candidates\n')
for center_id = 1:numel(grid_centers)
    for ratio_id = 1:numel(grid_ratios)
        candidate = evaluateVhsPhaseLead(problem, ...
            phaseLeadFromCenterRatio(grid_centers(center_id), ...
            grid_ratios(ratio_id)));
        grid_index = grid_index + 1;
        log_entries(end+1, 1) = summarizeCandidate('grid', candidate);
        grid_candidates(grid_index, 1) = reduceCandidate(candidate);
    end
end
end

function [best, log_entries] = optimizePhaseLeadForPerformance( ...
        problem, baseline, log_entries, grid_candidates)
config = problem.config;
best = baseline;
best_feasible = candidateMeetsMinimums(best, config, Inf);

for candidate_id = 1:numel(grid_candidates)
    [best, best_feasible] = keepBetterPerformanceCandidate( ...
        best, best_feasible, grid_candidates(candidate_id), config);
end

if ~config.use_fmincon
    fprintf('\nfmincon refinement disabled; using best grid candidate only.\n')
    best = ensureFullCandidate(problem, best);
    return
end
if exist('fmincon', 'file') ~= 2
    fprintf('\nfmincon is unavailable; using best grid candidate only.\n')
    best = ensureFullCandidate(problem, best);
    return
end

fprintf('\nLocal performance refinement using fmincon\n')
[lower_bounds, upper_bounds, start_points] = optimizerSearchSetup( ...
    config, best);
options = phaseLeadFminconOptions(config);
for start_id = 1:size(start_points, 1)
    x0 = log(start_points(start_id, :));
    x0 = min(max(x0, lower_bounds), upper_bounds);
    x_opt = fmincon(@(x) phaseLeadObjective(x, problem), x0, ...
        [], [], [], [], lower_bounds, upper_bounds, ...
        @(x) phaseLeadConstraints(x, problem, Inf), options);
    candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x_opt));
    log_entries(end+1, 1) = summarizeCandidate('fmincon', candidate);
    [best, best_feasible] = keepBetterPerformanceCandidate( ...
        best, best_feasible, candidate, config);
end
best = ensureFullCandidate(problem, best);
end

function [stability_designs, log_entries] = ...
        optimizePhaseLeadForStabilityTargets(problem, baseline, log_entries, ...
        grid_candidates)
targets = problem.config.stability_nrmse_targets_percent(:);
stability_designs = struct('target_nrmse_percent', {}, ...
    'candidate', {}, 'feasible', {});
if isempty(targets)
    return
end

for target_id = 1:numel(targets)
    target_nrmse = targets(target_id);
    fprintf('\nSearching high-stability compensator with response NRMSE <= %.6g %%\n', ...
        target_nrmse)
    [candidate, feasible, log_entries] = optimizeStabilityForNrmseCap( ...
        problem, baseline, target_nrmse, log_entries, grid_candidates);
    stability_designs(end+1, 1) = struct( ... %#ok<AGROW>
        'target_nrmse_percent', target_nrmse, ...
        'candidate', candidate, ...
        'feasible', feasible);
end
end

function [best, best_feasible, log_entries] = optimizeStabilityForNrmseCap( ...
        problem, baseline, target_nrmse, log_entries, grid_candidates)
config = problem.config;
best = baseline;
best_feasible = candidateMeetsMinimums(best, config, target_nrmse);
stage_prefix = sprintf('nrms%g', target_nrmse);

for candidate_id = 1:numel(grid_candidates)
    [best, best_feasible] = keepBetterStabilityCandidate( ...
        best, best_feasible, grid_candidates(candidate_id), config, ...
        target_nrmse);
end
log_entries(end+1, 1) = summarizeCandidate( ...
    sprintf('%s_selected', stage_prefix), best);

if ~config.use_stability_fmincon
    fprintf('Stability fmincon refinement disabled for %.6g %% NRMSE cap.\n', ...
        target_nrmse)
    return
end
if exist('fmincon', 'file') ~= 2
    return
end

fprintf('Local stability refinement using fmincon for %.6g %% NRMSE cap\n', ...
    target_nrmse)
[lower_bounds, upper_bounds, start_points] = optimizerSearchSetup( ...
    config, best);
options = phaseLeadFminconOptions(config);
for start_id = 1:size(start_points, 1)
    x0 = log(start_points(start_id, :));
    x0 = min(max(x0, lower_bounds), upper_bounds);
    x_opt = fmincon(@(x) stabilityObjective(x, problem, target_nrmse), ...
        x0, [], [], [], [], lower_bounds, upper_bounds, ...
        @(x) phaseLeadConstraints(x, problem, target_nrmse), options);
    candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x_opt));
    log_entries(end+1, 1) = summarizeCandidate( ...
        sprintf('%s_fmincon', stage_prefix), candidate);
    [best, best_feasible] = keepBetterStabilityCandidate( ...
        best, best_feasible, candidate, config, target_nrmse);
end
end

function [lower_bounds, upper_bounds, start_points] = ...
        optimizerSearchSetup(config, seed_candidate)
lower_bounds = log([config.center_frequency_bounds_hz(1), ...
    config.ratio_bounds(1)]);
upper_bounds = log([config.center_frequency_bounds_hz(2), ...
    config.ratio_bounds(2)]);
if seed_candidate.phase_lead.enabled
    seed_point = [seed_candidate.phase_lead.center_frequency_hz, ...
        max(seed_candidate.phase_lead.high_frequency_gain, ...
        config.ratio_bounds(1))];
else
    seed_point = zeros(0, 2);
end
start_points = unique([seed_point; config.start_points], ...
    'rows', 'stable');
end

function options = phaseLeadFminconOptions(config)
options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'Display', 'final', ...
    'MaxIterations', config.max_iterations, ...
    'MaxFunctionEvaluations', config.max_function_evaluations);
end

function candidate = reduceCandidate(candidate)
candidate = struct('phase_lead', candidate.phase_lead, ...
    'metrics', candidate.metrics);
end

function candidate = ensureFullCandidate(problem, candidate)
if isfield(candidate, 'signals')
    return
end
candidate = evaluateVhsPhaseLead(problem, candidate.phase_lead);
end

function [best, best_feasible] = keepBetterPerformanceCandidate( ...
        best, best_feasible, candidate, config)
candidate_feasible = candidateMeetsMinimums(candidate, config, Inf);
if candidate_feasible
    if ~best_feasible || candidate.metrics.score < best.metrics.score
        best = candidate;
        best_feasible = true;
    end
elseif ~best_feasible && candidate.metrics.score < best.metrics.score
    best = candidate;
end
end

function [best, best_feasible] = keepBetterStabilityCandidate( ...
        best, best_feasible, candidate, config, target_nrmse)
candidate_feasible = candidateMeetsMinimums(candidate, config, ...
    target_nrmse);
if candidate_feasible && ~best_feasible
    best = candidate;
    best_feasible = true;
elseif candidate_feasible && best_feasible
    if stabilitySortScore(candidate, config) < stabilitySortScore(best, config)
        best = candidate;
    end
elseif ~candidate_feasible && ~best_feasible ...
        && constraintViolation(candidate, config, target_nrmse) ...
            < constraintViolation(best, config, target_nrmse)
    best = candidate;
end
end

function tf = candidateMeetsMinimums(candidate, config, max_response_nrmse)
tolerance = 1e-9;
tf = candidate.metrics.stable ...
    && candidate.metrics.stability_margin + tolerance ...
        >= config.minimum_stability_margin;
if isfinite(max_response_nrmse)
    tf = tf && candidate.metrics.response_nrmse_percent ...
        <= max_response_nrmse + tolerance;
end
end

function score = stabilitySortScore(candidate, config)
score = -candidate.metrics.stability_margin ...
    + config.stability_tie_break_weight*candidate.metrics.score;
end

function violation = constraintViolation(candidate, config, max_response_nrmse)
violation = max(0, candidate.metrics.max_abs_pole - 1) ...
    + max(0, config.minimum_stability_margin ...
        - candidate.metrics.stability_margin);
if isfinite(max_response_nrmse)
    violation = violation + max(0, candidate.metrics.response_nrmse_percent ...
        - max_response_nrmse)/max(max_response_nrmse, 1);
end
end

function problem = prepareVhsPhaseLeadProblem(project_root, config)
hs = struct( ...
    'earthquake_type', config.earthquake_type, ...
    'intensity_factor', config.intensity_factor, ...
    'time_scale_factor', config.time_scale_factor, ...
    'force_sign', config.force_sign);
if isempty(config.fem_file)
    fem_files = dir(fullfile(project_root, 'saved_results', 'fem', ...
        'fem_*.mat'));
    assert(~isempty(fem_files), ...
        'No FEM files found under saved_results\\fem.')
    [~, order] = sort([fem_files.datenum], 'descend');
    config.fem_file = fullfile(fem_files(order(1)).folder, ...
        fem_files(order(1)).name);
end
[fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
    config.fem_file);
hs.fem_file = fem_file;

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
if isfield(fem, 'damping_ratio')
    hs.damping_ratio = fem.damping_ratio;
else
    hs.damping_ratio = 0.03;
end

[modes, omega2] = eig(fem_ref.K, fem_ref.M, 'vector');
[omega, order] = sort(sqrt(real(omega2)));
modes = real(modes(:, order));
for mode_id = 1:size(modes, 2)
    modes(:, mode_id) = modes(:, mode_id) ...
        /sqrt(modes(:, mode_id)'*fem_ref.M*modes(:, mode_id));
end
hs.C = fem_ref.M*modes*diag(2*hs.damping_ratio*omega)*modes'*fem_ref.M;

earthquakes = load(fullfile(project_root, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);

[PID_H_dc_dm, pid_values, h_dc_dm_model_file] = loadPidHdcDmModel( ...
    project_root, config.h_dc_dm_model_file, config.pid_gain_override, ...
    config.sample_dt);
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, config.sample_dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

real_time = hs.time*hs.time_scale_factor;
n_step = ceil(real_time(end)/config.sample_dt) + 1;
hs_real_time = (0:n_step-1)'*config.sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(hs.time, hs.ag, hs_model_time, 'linear', 0);
reference_load_sample = -(fem_ref.M*fem_ref.influence)*ag_sample';
u_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    fem_ref.M, hs.C, fem_ref.K, reference_load_sample);

problem = struct( ...
    'config', config, ...
    'fem', fem, ...
    'fem_file', fem_file, ...
    'h_dc_dm_model_file', h_dc_dm_model_file, ...
    'hs', hs, ...
    'sample_dt', config.sample_dt, ...
    'time', hs_real_time, ...
    'ag_sample', ag_sample, ...
    'u_reference_sample', u_reference_sample(:, 1:hs.n_floor), ...
    'k_experimental', config.k_exp_r*fem_num.experimental_k, ...
    'num_model', numericalSubstructureDiscrete(hs, config.sample_dt), ...
    'PID_H_dc_dm', PID_H_dc_dm, ...
    'digital_controller', digital_controller);
end

function score = phaseLeadObjective(x, problem)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x));
score = candidate.metrics.score;
end

function score = stabilityObjective(x, problem, max_response_nrmse)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x));
score = stabilitySortScore(candidate, problem.config) ...
    + problem.config.minimum_margin_penalty_weight ...
        * constraintViolation(candidate, problem.config, max_response_nrmse)^2;
end

function [c, ceq] = phaseLeadConstraints(x, problem, max_response_nrmse)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x));
c = candidate.metrics.max_abs_pole - 1;
if problem.config.minimum_stability_margin > 0
    c(end+1, 1) = problem.config.minimum_stability_margin ...
        - candidate.metrics.stability_margin;
end
if isfinite(max_response_nrmse)
    c(end+1, 1) = candidate.metrics.response_nrmse_percent ...
        - max_response_nrmse;
end
ceq = [];
end

function candidate = evaluateVhsPhaseLead(problem, phase_lead_override)
phase_lead = normalizePhaseLeadConfig(phase_lead_override);
num_model = problem.num_model;
actuator = discreteSiso(problem.PID_H_dc_dm, problem.sample_dt);
lead_filter = discreteSiso(buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt), problem.sample_dt);
controller = discreteSiso(problem.digital_controller, problem.sample_dt);
stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
    problem.k_experimental, problem.sample_dt);

n_step = numel(problem.time);
u_num_floors_sample = zeros(n_step, problem.hs.n_floor);
dd_sample = zeros(n_step, 1);
dd_lead_sample = zeros(n_step, 1);
dm_sample = zeros(n_step, 1);
dc_sample = zeros(n_step, 1);
force_sample = zeros(n_step, 1);
x_num = zeros(size(num_model.A, 1), 1);
k_mm = problem.k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;
for step = 2:n_step
    dd_sample(step) = (num_model.C*x_num ...
        + num_model.D_fm*k_mm*actuator.D*lead_filter.C*lead_filter.x ...
        + num_model.D_fm*k_mm*actuator.C*actuator.x ...
        + num_model.D_ag*problem.ag_sample(step))/denominator;
    dd_lead_sample(step) = outputDiscreteSiso(lead_filter, dd_sample(step));
    dm_sample(step) = outputDiscreteSiso(actuator, dd_lead_sample(step));
    force_sample(step) = k_mm*dm_sample(step);
    dc_sample(step) = outputDiscreteSiso(controller, ...
        dd_lead_sample(step)-dm_sample(step));
    x_num = num_model.A*x_num + num_model.B_fm*force_sample(step) ...
        + num_model.B_ag*problem.ag_sample(step);
    lead_filter = updateDiscreteSiso(lead_filter, dd_sample(step));
    actuator = updateDiscreteSiso(actuator, dd_lead_sample(step));
    controller = updateDiscreteSiso(controller, ...
        dd_lead_sample(step)-dm_sample(step));
    u_num_floors_sample(step, :) = x_num(1:problem.hs.n_floor)';
end

signals = struct( ...
    'u_num_floors_sample', u_num_floors_sample, ...
    'dd_sample', dd_sample, ...
    'dd_lead_sample', dd_lead_sample, ...
    'dm_sample', dm_sample, ...
    'dc_sample', dc_sample, ...
    'force_sample', force_sample);
metrics = scoreVhsPhaseLead(problem, signals, stability);
candidate = struct('phase_lead', phase_lead, 'stability', stability, ...
    'signals', signals, 'metrics', metrics);
end

function metrics = scoreVhsPhaseLead(problem, signals, stability)
config = problem.config;
response_error = signals.u_num_floors_sample - problem.u_reference_sample;
response_nrmse_percent = 100*rms(response_error(:)) ...
    /max(rms(problem.u_reference_sample(:)), eps);
tracking_nrmse_percent = 100*rms(signals.dd_lead_sample - signals.dm_sample) ...
    /max(rms(signals.dd_lead_sample), eps);
lead_change_percent = 100*rms(signals.dd_lead_sample - signals.dd_sample) ...
    /max(rms(signals.dd_sample), eps);
peak_command_ratio = max(abs(signals.dd_lead_sample)) ...
    /max(max(abs(signals.dd_sample)), eps);
pole_excess = max(0, stability.coupled_max_abs_pole ...
    - config.max_abs_pole_target);
pole_scale = max(1e-6, 1 - config.max_abs_pole_target);
command_ratio_excess = max(0, peak_command_ratio ...
    - config.max_peak_command_ratio);
stability_margin = 1 - stability.coupled_max_abs_pole;
minimum_margin_shortfall = max(0, config.minimum_stability_margin ...
    - stability_margin);

performance_score = response_nrmse_percent ...
    + config.tracking_error_weight*tracking_nrmse_percent ...
    + config.lead_change_weight*lead_change_percent;
score = performance_score ...
    + config.pole_penalty_weight*(pole_excess/pole_scale)^2 ...
    + config.command_ratio_penalty_weight*command_ratio_excess^2 ...
    + config.minimum_margin_penalty_weight*minimum_margin_shortfall^2;
if stability.coupled_max_abs_pole >= 1
    score = score + 1e6*(1 + stability.coupled_max_abs_pole - 1);
end

metrics = struct( ...
    'score', score, ...
    'performance_score', performance_score, ...
    'response_nrmse_percent', response_nrmse_percent, ...
    'tracking_nrmse_percent', tracking_nrmse_percent, ...
    'lead_change_percent', lead_change_percent, ...
    'peak_command_ratio', peak_command_ratio, ...
    'stability_margin', stability_margin, ...
    'minimum_margin_shortfall', minimum_margin_shortfall, ...
    'max_abs_pole', stability.coupled_max_abs_pole, ...
    'stable', stability.coupled_stable);
end

function phase_lead = phaseLeadFromX(x)
center_hz = exp(x(1));
ratio = exp(x(2));
phase_lead = phaseLeadFromCenterRatio(center_hz, ratio);
end

function phase_lead = phaseLeadFromCenterRatio(center_hz, ratio)
zero_hz = center_hz/sqrt(ratio);
pole_hz = center_hz*sqrt(ratio);
gain = ratio;
phase_lead = normalizePhaseLeadConfig([gain, zero_hz, pole_hz]);
end

function entry = summarizeCandidate(stage, candidate)
entry = struct( ...
    'Stage', string(stage), ...
    'Score', candidate.metrics.score, ...
    'PerformanceScore', candidate.metrics.performance_score, ...
    'Zero_Hz', candidate.phase_lead.zero_hz, ...
    'Pole_Hz', candidate.phase_lead.pole_hz, ...
    'Gain', candidate.phase_lead.gain, ...
    'Center_Hz', candidate.phase_lead.center_frequency_hz, ...
    'MaxPhaseLead_deg', candidate.phase_lead.max_phase_lead_deg, ...
    'ResponseNRMSE_percent', candidate.metrics.response_nrmse_percent, ...
    'TrackingNRMSE_percent', candidate.metrics.tracking_nrmse_percent, ...
    'LeadChange_percent', candidate.metrics.lead_change_percent, ...
    'PeakCommandRatio', candidate.metrics.peak_command_ratio, ...
    'StabilityMargin', candidate.metrics.stability_margin, ...
    'MaxAbsPole', candidate.metrics.max_abs_pole, ...
    'Stable', candidate.metrics.stable);
end

function printCandidate(candidate)
fprintf(['Score = %.6g, response NRMSE = %.6g %%, ' ...
    'tracking NRMSE = %.6g %%, stability margin = %.12g, ' ...
    'max |pole| = %.12g\n'], ...
    candidate.metrics.score, candidate.metrics.response_nrmse_percent, ...
    candidate.metrics.tracking_nrmse_percent, ...
    candidate.metrics.stability_margin, ...
    candidate.metrics.max_abs_pole)
if candidate.phase_lead.enabled
    fprintf(['G_T: k_T = %.12g, z1 = %.12g Hz, p1 = %.12g Hz, ' ...
        'DC gain = %.12g, max lead = %.6g deg at %.6g Hz\n'], ...
        candidate.phase_lead.gain, candidate.phase_lead.zero_hz, ...
        candidate.phase_lead.pole_hz, candidate.phase_lead.dc_gain, ...
        candidate.phase_lead.max_phase_lead_deg, ...
        candidate.phase_lead.center_frequency_hz)
else
    fprintf('G_T: disabled\n')
end
end

function printPhaseLeadOverride(variable_name, candidate)
if ~candidate.phase_lead.enabled
    fprintf('\n%s = [];\n', variable_name)
    return
end
fprintf(['\n%s = struct(''enabled'', true, ''gain'', %.12g, ' ...
    '''zero_hz'', %.12g, ''pole_hz'', %.12g); ' ...
    '%% response NRMSE %.6g %%, stability margin %.12g\n'], ...
    variable_name, candidate.phase_lead.gain, ...
    candidate.phase_lead.zero_hz, candidate.phase_lead.pole_hz, ...
    candidate.metrics.response_nrmse_percent, ...
    candidate.metrics.stability_margin)
end

function overrides = stabilityOverridesFromDesigns(stability_designs)
n_design = numel(stability_designs);
overrides = struct('target_nrmse_percent', cell(n_design, 1), ...
    'feasible', cell(n_design, 1), ...
    'phase_lead_override', cell(n_design, 1), ...
    'metrics', cell(n_design, 1));
for design_id = 1:n_design
    candidate = stability_designs(design_id).candidate;
    overrides(design_id).target_nrmse_percent = ...
        stability_designs(design_id).target_nrmse_percent;
    overrides(design_id).feasible = stability_designs(design_id).feasible;
    overrides(design_id).phase_lead_override = ...
        phaseLeadOverrideFromCandidate(candidate);
    overrides(design_id).metrics = candidate.metrics;
end
end

function phase_lead_override = phaseLeadOverrideFromCandidate(candidate)
if candidate.phase_lead.enabled
    phase_lead_override = struct('enabled', true, ...
        'gain', candidate.phase_lead.gain, ...
        'zero_hz', candidate.phase_lead.zero_hz, ...
        'pole_hz', candidate.phase_lead.pole_hz);
else
    phase_lead_override = [];
end
end

function T = stabilityDesignsToTable(stability_designs)
if isempty(stability_designs)
    T = table();
    return
end

n_design = numel(stability_designs);
target_nrmse_percent = zeros(n_design, 1);
feasible = false(n_design, 1);
score = zeros(n_design, 1);
response_nrmse_percent = zeros(n_design, 1);
tracking_nrmse_percent = zeros(n_design, 1);
stability_margin = zeros(n_design, 1);
max_abs_pole = zeros(n_design, 1);
zero_hz = zeros(n_design, 1);
pole_hz = zeros(n_design, 1);
gain = zeros(n_design, 1);

for design_id = 1:n_design
    candidate = stability_designs(design_id).candidate;
    target_nrmse_percent(design_id) = ...
        stability_designs(design_id).target_nrmse_percent;
    feasible(design_id) = stability_designs(design_id).feasible;
    score(design_id) = candidate.metrics.score;
    response_nrmse_percent(design_id) = ...
        candidate.metrics.response_nrmse_percent;
    tracking_nrmse_percent(design_id) = ...
        candidate.metrics.tracking_nrmse_percent;
    stability_margin(design_id) = candidate.metrics.stability_margin;
    max_abs_pole(design_id) = candidate.metrics.max_abs_pole;
    zero_hz(design_id) = candidate.phase_lead.zero_hz;
    pole_hz(design_id) = candidate.phase_lead.pole_hz;
    gain(design_id) = candidate.phase_lead.gain;
end

T = table(target_nrmse_percent, feasible, score, ...
    response_nrmse_percent, tracking_nrmse_percent, ...
    stability_margin, max_abs_pole, zero_hz, pole_hz, gain, ...
    'VariableNames', {'TargetNRMSE_percent', 'Feasible', 'Score', ...
    'ResponseNRMSE_percent', 'TrackingNRMSE_percent', ...
    'StabilityMargin', 'MaxAbsPole', 'Zero_Hz', 'Pole_Hz', 'Gain'});
end

function delay_comp_paths = saveDelayCompensatorFiles(project_root, ...
        run_timestamp, best, stability_designs)
delay_comp_dir = fullfile(project_root, 'saved_results', 'phase_lead');
if ~exist(delay_comp_dir, 'dir')
    mkdir(delay_comp_dir)
end

n_paths = 1 + numel(stability_designs);
label = strings(n_paths, 1);
path = strings(n_paths, 1);
[label(1), path(1)] = saveCandidateDelayCompensator( ...
    delay_comp_dir, sprintf('phase_lead_dd_performance_%s.mat', ...
    run_timestamp), 'performance', best);

for design_id = 1:numel(stability_designs)
    target_nrmse = stability_designs(design_id).target_nrmse_percent;
    tag = nrmseTargetTag(target_nrmse);
    row = design_id + 1;
    [label(row), path(row)] = saveCandidateDelayCompensator( ...
        delay_comp_dir, sprintf('phase_lead_dd_%s_%s.mat', tag, ...
        run_timestamp), sprintf('%g_percent_nrmse_stability', ...
        target_nrmse), stability_designs(design_id).candidate);
end

delay_comp_paths = table(label, path, ...
    'VariableNames', {'Label', 'Path'});
end

function [label, path] = saveCandidateDelayCompensator( ...
        delay_comp_dir, file_name, label, candidate)
path = string(fullfile(delay_comp_dir, file_name));
delay_comp_tf = continuousPhaseLeadTransferFunction(candidate.phase_lead);
phase_lead = candidate.phase_lead;
metrics = candidate.metrics;
delay_comp_label = label;
delay_comp_name = file_name;
created_at = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
save(char(path), 'delay_comp_tf', 'phase_lead', 'metrics', ...
    'delay_comp_label', 'delay_comp_name', 'created_at')
label = string(label);
end

function tag = nrmseTargetTag(target_nrmse)
tag = strrep(sprintf('nrms%g', target_nrmse), '.', 'p');
tag = strrep(tag, '-', 'm');
end

function delay_comp_tf = continuousPhaseLeadTransferFunction(phase_lead)
phase_lead = normalizePhaseLeadConfig(phase_lead);
if ~phase_lead.enabled
    delay_comp_tf = tf(1);
    return
end

delay_comp_tf = phase_lead.gain ...
    * tf([1 phase_lead.zero_rad_s], [1 phase_lead.pole_rad_s]);
end

function [PID_H_dc_dm, pid_values, model_file] = loadPidHdcDmModel( ...
        project_root, model_file, pid_gain_override, sample_time)
if isempty(model_file)
    model_dir = fullfile(project_root, 'saved_results', 'models');
    files = dir(fullfile(model_dir, '*.mat'));
    [~, order] = sort([files.datenum], 'descend');
    files = files(order);
    for file_id = 1:numel(files)
        candidate = fullfile(files(file_id).folder, files(file_id).name);
        names = {whos('-file', candidate).name};
        if any(strcmp(names, 'H_dc_dm'))
            model_file = candidate;
            break
        end
    end
end
if isempty(model_file)
    error('optimize_vHS_phase_lead:MissingHdcDmModel', ...
        'No saved model file containing H_dc_dm was found.')
end

model = load(model_file, 'H_dc_dm', 'pid_values');
H_dc_dm = model.H_dc_dm;
if isfield(model, 'pid_values')
    pid_values = model.pid_values;
else
    pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
pid_values = applyPidGainOverride(pid_values, pid_gain_override);
if get(H_dc_dm, 'Ts') == 0
    H_dc_dm = c2d(H_dc_dm, sample_time, 'zoh');
elseif abs(get(H_dc_dm, 'Ts')-sample_time) > 10*eps(sample_time)
    H_dc_dm = d2d(H_dc_dm, sample_time, 'zoh');
end
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, sample_time, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
PID_H_dc_dm = feedback(digital_controller*H_dc_dm, 1);
end

function pid_values = applyPidGainOverride(pid_values, pid_gain_override)
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

function model = numericalSubstructureDiscrete(hs, sample_time)
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

function stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
        k_experimental, sample_time)
k_mm = k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;
dd_from_num = num_model.C/denominator;
dd_from_lead = num_model.D_fm*k_mm*actuator.D*lead_filter.C ...
    /denominator;
dd_from_actuator = num_model.D_fm*k_mm*actuator.C/denominator;
dd_lead_from_num = lead_filter.D*dd_from_num;
dd_lead_from_lead = lead_filter.C + lead_filter.D*dd_from_lead;
dd_lead_from_actuator = lead_filter.D*dd_from_actuator;
force_from_num = k_mm*actuator.D*dd_lead_from_num;
force_from_lead = k_mm*actuator.D*dd_lead_from_lead;
force_from_actuator = k_mm*(actuator.C ...
    + actuator.D*dd_lead_from_actuator);
closed_loop_A = [ ...
    num_model.A + num_model.B_fm*force_from_num, ...
    num_model.B_fm*force_from_lead, ...
    num_model.B_fm*force_from_actuator; ...
    lead_filter.B*dd_from_num, ...
    lead_filter.A + lead_filter.B*dd_from_lead, ...
    lead_filter.B*dd_from_actuator; ...
    actuator.B*dd_lead_from_num, ...
    actuator.B*dd_lead_from_lead, ...
    actuator.A + actuator.B*dd_lead_from_actuator];
closed_loop_poles = eig(closed_loop_A);
actuator_poles = eig(actuator.A);
lead_poles = eig(lead_filter.A);
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
    /(2*pi*sample_time);
stability.closed_loop_poles = closed_loop_poles;
end

function system = discreteSiso(system_model, sample_time)
if get(system_model, 'Ts') == 0
    system_model = c2d(system_model, sample_time, 'zoh');
elseif abs(get(system_model, 'Ts')-sample_time) > 10*eps(sample_time)
    system_model = d2d(system_model, sample_time, 'zoh');
end
system_model = ss(system_model);
[system.A, system.B, system.C, system.D] = ssdata(system_model);
system.x = zeros(size(system.A, 1), 1);
system.u = 0;
end

function y = outputDiscreteSiso(system, u)
if nargin < 2
    u = system.u;
end
y = system.C*system.x + system.D*u;
y = y(1);
end

function system = updateDiscreteSiso(system, u)
system.x = system.A*system.x + system.B*u;
system.u = u;
end

function u = newmarkAverageAcceleration(time, M, C, K, force)
n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);
v = zeros(n_step, n_dof);
a = zeros(n_step, n_dof);
a(1, :) = (M\(force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    dt = time(step)-time(step-1);
    a0 = 1/(beta*dt^2);
    a1 = gamma/(beta*dt);
    a2 = 1/(beta*dt);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = dt*(gamma/(2*beta)-1);
    effective_stiffness = K+a0*M+a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)'+a2*v(step-1, :)'+a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)'+a4*v(step-1, :)'+a5*a(step-1, :)');
    u(step, :) = (effective_stiffness\effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)'-a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)'+dt*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end

function plotPhaseLeadOptimization(problem, baseline, best)
colors = getPlotColors();
figure('Color', 'w', 'Name', 'vHS phase-lead optimization');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
plot(ax, problem.time, problem.u_reference_sample(:, 1), 'k--', ...
    'LineWidth', 2.0, 'DisplayName', 'reference');
hold(ax, 'on')
plot(ax, problem.time, baseline.signals.u_num_floors_sample(:, 1), '-', ...
    'Color', colors.blue, 'LineWidth', 1.1, 'DisplayName', 'no lead');
plot(ax, problem.time, best.signals.u_num_floors_sample(:, 1), '-', ...
    'Color', colors.copperwood, 'LineWidth', 1.1, 'DisplayName', 'best lead');
hold(ax, 'off')
grid(ax, 'on')
ylabel(ax, 'Floor 1 (m)')
legend(ax, 'Location', 'best')

ax = nexttile;
plot(ax, problem.time, best.signals.dd_sample, 'k--', 'LineWidth', 2.0, ...
    'DisplayName', 'raw numerical dd');
hold(ax, 'on')
plot(ax, problem.time, best.signals.dd_lead_sample, '--', ...
    'Color', colors.green, 'LineWidth', 1.5, ...
    'DisplayName', 'phase-lead desired dd');
plot(ax, problem.time, best.signals.dm_sample, '-', ...
    'Color', colors.blue, 'LineWidth', 1.1, ...
    'DisplayName', 'measured dm');
hold(ax, 'off')
grid(ax, 'on')
ylabel(ax, 'Displacement (mm)')
xlabel(ax, 'Real time (s)')
legend(ax, 'Location', 'best')
title(layout, 'Phase lead inserted directly after numerical dd')
end

function colors = getPlotColors()
colors.green = hexToRgb('39BF5E');
colors.blue = hexToRgb('007CA8');
colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hex_color)
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end
