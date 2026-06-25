%% Optimize vHS Phase Lead After Numerical DD
% The compensated path is:
% raw numerical dd -> G_T -> actuator tracking loop -> measured dm -> force.
% G_T(s) = k_T*(s + z1)/(s + p1), with p1 > z1.

clearvars -except phase_lead_optimizer_config ncfmargin ncf_margin ...
    fem_file_override ...
    specimen_file_override exp_specimen_file_override ...
    h_dc_dm_model_file_override pid_gain_override; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
hs_dir = fileparts(script_dir);
project_root = fileparts(fileparts(hs_dir));
addpath(script_dir);
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
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
if exist('ncfmargin', 'var') && ~isempty(ncfmargin)
    config.minimum_num_delay_comp_exp_ncf_margin = ncfmargin;
elseif exist('ncf_margin', 'var') && ~isempty(ncf_margin)
    config.minimum_num_delay_comp_exp_ncf_margin = ncf_margin;
end
if exist('fem_file_override', 'var') && ~isempty(fem_file_override)
    config.fem_file = fem_file_override;
end
if exist('exp_specimen_file_override', 'var') ...
        && ~isempty(exp_specimen_file_override)
    config.specimen_file = exp_specimen_file_override;
elseif exist('specimen_file_override', 'var') ...
        && ~isempty(specimen_file_override)
    config.specimen_file = specimen_file_override;
end

problem = prepareVhsPhaseLeadProblem(project_root, config);
baseline = evaluateVhsPhaseLead(problem, []);
log_entries = summarizeCandidate('baseline', baseline);

fprintf('\nBaseline without phase lead\n')
printCandidate(baseline)

[grid_candidates, log_entries, best_checkpoint] = evaluatePhaseLeadGrid( ...
    problem, baseline, log_entries);
[best, log_entries] = optimizePhaseLeadForPerformance( ...
    problem, baseline, log_entries, grid_candidates, best_checkpoint);

phase_lead_result_table = struct2table(log_entries);
phase_lead_result_table = sortrows(phase_lead_result_table, 'Score');
baseline_metrics = baseline.metrics;
best_phase_lead = best.phase_lead;
best_metrics = best.metrics;

fprintf('\nBest candidate\n')
printCandidate(best)
disp(phase_lead_result_table(:, {'Stage', 'Score', 'Zero_Hz', ...
    'Pole_Hz', 'Gain', 'MaxPhaseLead_deg', 'ResponseNRMSE_percent', ...
    'TrackingNRMSE_percent', 'StabilityMargin', ...
    'NumDelayCompExpNCFMargin', 'MaxAbsPole', 'PeakCommandRatio'}))

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

if config.save_results
    results_dir = fullfile(project_root, 'saved_results', 'models');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir)
    end
    run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    delay_comp_paths = saveDelayCompensatorFiles(project_root, ...
        run_timestamp, best);
    phase_lead_results_path = fullfile(results_dir, ...
        sprintf('vHS_phase_lead_%s.mat', run_timestamp));
    save(phase_lead_results_path, 'config', 'baseline_metrics', ...
        'best_phase_lead', 'best_metrics', 'recommended_phase_lead_override', ...
        'phase_lead_result_table', 'delay_comp_paths')
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
    'specimen_file', '', ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    'center_frequency_bounds_hz', [0.5 80], ...
    'ratio_bounds', [1.01 25], ...
    'grid_center_hz', [1 2 3 4 8 12 18 27 40 60], ...
    'grid_ratio', [1.05 1.2 1.5 2 3 5 8 12 14 15 18], ...
    'start_points', [3 14; 4 15; 5 17; 4 2; 8 3; 12 5; 20 8; 40 5], ...
    'minimum_stability_margin', 0, ...
    'minimum_num_delay_comp_exp_ncf_margin', 0, ...
    'num_delay_comp_exp_margin_frequency_hz', [0.1 80], ...
    'minimum_margin_penalty_weight', 1e8, ...
    'use_fmincon', true, ...
    'use_parallel_grid', true, ...
    'max_abs_pole_target', 0.998, ...
    'tracking_error_weight', 0.20, ...
    'lead_change_weight', 0.02, ...
    'pole_penalty_weight', 200, ...
    'command_ratio_penalty_weight', 20, ...
    'max_peak_command_ratio', 3, ...
    'max_iterations', 50, ...
    'max_function_evaluations', 200, ...
    'plot_results', true, ...
    'save_results', true, ...
    'print_best_checkpoint', true, ...
    'save_best_checkpoint', true, ...
    'print_optimizer_progress', true, ...
    'best_checkpoint_interval_trials', 10, ...
    'fmincon_progress_interval_evaluations', 25, ...
    'best_checkpoint_file', '');
end

function config = mergeStruct(config, override)
fields = fieldnames(override);
for field_id = 1:numel(fields)
    config.(fields{field_id}) = override.(fields{field_id});
end
end

function [grid_candidates, log_entries, checkpoint] = evaluatePhaseLeadGrid( ...
        problem, baseline, log_entries)
config = problem.config;
grid_centers = config.grid_center_hz(:);
grid_ratios = config.grid_ratio(:);
n_candidate = numel(grid_centers)*numel(grid_ratios);
candidate_inputs = zeros(n_candidate, 2);
grid_candidates = repmat(struct('phase_lead', [], 'metrics', []), ...
    n_candidate, 1);
grid_index = 0;

fprintf('\nGrid search for phase-lead candidates\n')
baseline_feasible = candidateMeetsMinimums(baseline, config, Inf);
checkpoint = startPerformanceCheckpoint(problem, baseline, ...
    baseline_feasible, n_candidate);
for center_id = 1:numel(grid_centers)
    for ratio_id = 1:numel(grid_ratios)
        grid_index = grid_index + 1;
        candidate_inputs(grid_index, :) = [grid_centers(center_id), ...
            grid_ratios(ratio_id)];
    end
end

if useParallelGrid(config)
    pool = gcp('nocreate');
    fprintf('Parallel grid enabled with %d workers.\n', pool.NumWorkers)
    queue = parallel.pool.DataQueue;
    afterEach(queue, @recordParallelGridCheckpoint);
    parfor candidate_id = 1:n_candidate
        candidate = evaluateGridCandidate(problem, ...
            candidate_inputs(candidate_id, :));
        grid_candidates(candidate_id, 1) = candidate;
        send(queue, candidate)
    end
    while checkpoint.enabled && checkpoint.trial_count < n_candidate
        pause(0.01)
    end
else
    for candidate_id = 1:n_candidate
        grid_candidates(candidate_id, 1) = evaluateGridCandidate( ...
            problem, candidate_inputs(candidate_id, :));
        checkpoint = recordPerformanceCheckpoint(checkpoint, problem, ...
            'grid', grid_candidates(candidate_id), false);
    end
end
checkpoint = writePerformanceCheckpoint(checkpoint, problem, ...
    'grid_final', true);

for candidate_id = 1:n_candidate
    log_entries(end+1, 1) = summarizeCandidate('grid', ...
        grid_candidates(candidate_id)); %#ok<AGROW>
end

    function recordParallelGridCheckpoint(candidate)
    checkpoint = recordPerformanceCheckpoint(checkpoint, problem, ...
        'grid', candidate, false);
    end
end

function candidate = evaluateGridCandidate(problem, candidate_input)
candidate = reduceCandidate(evaluateVhsPhaseLead(problem, ...
    phaseLeadFromCenterRatio(candidate_input(1), candidate_input(2))));
end

function [best, log_entries] = optimizePhaseLeadForPerformance( ...
        problem, baseline, log_entries, grid_candidates, checkpoint)
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
    checkpoint.best = reduceCandidate(best);
    checkpoint.best_feasible = best_feasible;
    writePerformanceCheckpoint(checkpoint, problem, 'performance_final', true);
    return
end
if exist('fmincon', 'file') ~= 2
    fprintf('\nfmincon is unavailable; using best grid candidate only.\n')
    best = ensureFullCandidate(problem, best);
    checkpoint.best = reduceCandidate(best);
    checkpoint.best_feasible = best_feasible;
    writePerformanceCheckpoint(checkpoint, problem, 'performance_final', true);
    return
end

fprintf('\nLocal performance refinement using fmincon\n')
[lower_bounds, upper_bounds, start_points] = optimizerSearchSetup( ...
    config, best);
options = phaseLeadFminconOptions(config);
n_start = size(start_points, 1);
checkpoint.total_trials = checkpoint.total_trials + n_start;
for start_id = 1:size(start_points, 1)
    fprintf('Performance fmincon start %d/%d\n', start_id, n_start)
    x0 = log(start_points(start_id, :));
    x0 = min(max(x0, lower_bounds), upper_bounds);
    fmincon_start_time = tic;
    last_fmincon_funccount = -Inf;
    options_start = options;
    options_start.OutputFcn = @reportPerformanceFminconProgress;
    x_opt = fmincon(@(x) phaseLeadObjective(x, problem), x0, ...
        [], [], [], [], lower_bounds, upper_bounds, ...
        @(x) phaseLeadConstraints(x, problem, Inf), options_start);
    candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x_opt));
    log_entries(end+1, 1) = summarizeCandidate( ...
        'fmincon', candidate); %#ok<AGROW>
    [best, best_feasible] = keepBetterPerformanceCandidate( ...
        best, best_feasible, candidate, config);
    checkpoint = recordPerformanceCheckpoint(checkpoint, problem, ...
        'fmincon', candidate, true);
end
best = ensureFullCandidate(problem, best);
checkpoint.best = reduceCandidate(best);
checkpoint.best_feasible = best_feasible;
writePerformanceCheckpoint(checkpoint, problem, 'performance_final', true);

    function stop = reportPerformanceFminconProgress(~, optim_values, state)
    [stop, last_fmincon_funccount] = reportFminconProgress(config, ...
        'performance', start_id, ...
        n_start, fmincon_start_time, last_fmincon_funccount, ...
        optim_values, state);
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

function [stop, last_funccount] = reportFminconProgress(config, stage, ...
        start_id, n_start, ...
        start_time, last_funccount, optim_values, state)
stop = false;
if ~config.print_optimizer_progress || ~isfield(optim_values, 'funccount')
    return
end
funccount = optim_values.funccount;
is_done = strcmp(state, 'done');
is_iter = strcmp(state, 'iter');
is_init = strcmp(state, 'init');
interval = max(1, round(config.fmincon_progress_interval_evaluations));
if ~(is_init || is_iter || is_done)
    return
end
if is_iter && funccount-last_funccount < interval
    return
end
elapsed_seconds = toc(start_time);
max_evaluations = config.max_function_evaluations;
remaining_seconds = estimateRemainingSeconds(elapsed_seconds, ...
    min(funccount, max_evaluations), max_evaluations);
if isfield(optim_values, 'fval')
    fval = optim_values.fval;
else
    fval = NaN;
end
if is_done
    status = 'done';
elseif is_init
    status = 'init';
else
    status = 'iter';
end
fprintf(['%s fmincon %s start %d/%d: evaluations %d/%d, ' ...
    'elapsed %s, budget ETA %s, fval %.6g\n'], ...
    stage, status, start_id, n_start, funccount, max_evaluations, ...
    formatDurationSeconds(elapsed_seconds), ...
    formatDurationSeconds(remaining_seconds), fval)
last_funccount = funccount;
end

function tf = useParallelGrid(config)
tf = false;
if ~config.use_parallel_grid
    return
end
if exist('gcp', 'file') ~= 2 || exist('parpool', 'file') ~= 2 ...
        || ~license('test', 'Distrib_Computing_Toolbox')
    fprintf('Parallel grid disabled; Parallel Computing Toolbox is unavailable.\n')
    return
end

try
    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool;
    end
    tf = ~isempty(pool);
catch err
    fprintf('Parallel grid disabled: %s\n', err.message)
end
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

function checkpoint = startPerformanceCheckpoint(problem, best, best_feasible, ...
        total_trials)
config = problem.config;
checkpoint = struct( ...
    'enabled', config.print_best_checkpoint || config.save_best_checkpoint ...
        || config.print_optimizer_progress, ...
    'print_enabled', config.print_best_checkpoint, ...
    'progress_enabled', config.print_optimizer_progress, ...
    'save_enabled', config.save_best_checkpoint, ...
    'interval_trials', max(1, round(config.best_checkpoint_interval_trials)), ...
    'total_trials', total_trials, ...
    'trial_count', 0, ...
    'start_time', tic, ...
    'best', reduceCandidate(best), ...
    'best_feasible', best_feasible, ...
    'history', checkpointEntry('baseline', 0, best, best_feasible), ...
    'file', bestCheckpointFile(problem));
checkpoint = writePerformanceCheckpoint(checkpoint, problem, ...
    'baseline', true);
end

function checkpoint = recordPerformanceCheckpoint(checkpoint, problem, ...
        stage, candidate, force)
if ~checkpoint.enabled
    return
end
checkpoint.trial_count = checkpoint.trial_count + 1;
[checkpoint.best, checkpoint.best_feasible] = ...
    keepBetterPerformanceCandidate(checkpoint.best, ...
    checkpoint.best_feasible, reduceCandidate(candidate), problem.config);
checkpoint.history(end+1, 1) = checkpointEntry(stage, ...
    checkpoint.trial_count, checkpoint.best, checkpoint.best_feasible);
if force || mod(checkpoint.trial_count, checkpoint.interval_trials) == 0
    checkpoint = writePerformanceCheckpoint(checkpoint, problem, ...
        stage, true);
end
end

function checkpoint = writePerformanceCheckpoint(checkpoint, problem, ...
        stage, force)
if ~checkpoint.enabled || ~force
    return
end
best_checkpoint = checkpoint.best;
best_checkpoint_metrics = best_checkpoint.metrics;
best_checkpoint_phase_lead = best_checkpoint.phase_lead;
best_checkpoint_feasible = checkpoint.best_feasible;
best_checkpoint_trial_count = checkpoint.trial_count;
best_checkpoint_history = checkpoint.history;
best_checkpoint_file = checkpoint.file;
best_checkpoint_updated_at = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));
best_checkpoint_stage = string(stage);
if checkpoint.print_enabled || checkpoint.progress_enabled
    elapsed_seconds = toc(checkpoint.start_time);
    remaining_seconds = estimateRemainingSeconds(elapsed_seconds, ...
        best_checkpoint_trial_count, checkpoint.total_trials);
    printBestCheckpoint(char(best_checkpoint_stage), ...
        best_checkpoint_trial_count, checkpoint.total_trials, ...
        best_checkpoint_feasible, best_checkpoint, elapsed_seconds, ...
        remaining_seconds)
end
if checkpoint.save_enabled
    checkpoint_dir = fileparts(best_checkpoint_file);
    if ~isempty(checkpoint_dir) && ~exist(checkpoint_dir, 'dir')
        mkdir(checkpoint_dir)
    end
    config = problem.config;
    save(best_checkpoint_file, 'best_checkpoint', ...
        'best_checkpoint_metrics', 'best_checkpoint_phase_lead', ...
        'best_checkpoint_feasible', 'best_checkpoint_trial_count', ...
        'best_checkpoint_history', 'best_checkpoint_updated_at', ...
        'best_checkpoint_stage', 'config')
end
end

function entry = checkpointEntry(stage, trial_count, candidate, feasible)
entry = struct( ...
    'Stage', string(stage), ...
    'Trial', trial_count, ...
    'Feasible', feasible, ...
    'Score', candidate.metrics.score, ...
    'ResponseNRMSE_percent', candidate.metrics.response_nrmse_percent, ...
    'TrackingNRMSE_percent', candidate.metrics.tracking_nrmse_percent, ...
    'StabilityMargin', candidate.metrics.stability_margin, ...
    'NumDelayCompExpNCFMargin', ...
        candidate.metrics.num_delay_comp_exp_ncf_margin, ...
    'MaxAbsPole', candidate.metrics.max_abs_pole, ...
    'Zero_Hz', candidate.phase_lead.zero_hz, ...
    'Pole_Hz', candidate.phase_lead.pole_hz, ...
    'Gain', candidate.phase_lead.gain);
end

function printBestCheckpoint(stage, trial_count, total_trials, feasible, ...
        candidate, elapsed_seconds, remaining_seconds)
if total_trials > 0
    progress = 100*trial_count/total_trials;
else
    progress = 0;
end
fprintf(['\nBest checkpoint [%s, trial %d/%d, %.1f%%, ' ...
    'elapsed %s, ETA %s, feasible = %d]\n' ...
    '  score %.6g, response NRMSE %.6g %%, tracking NRMSE %.6g %%, ' ...
    'stability margin %.12g, num_delay_comp_exp NCF %.12g, ' ...
    'max |pole| %.12g\n'], stage, trial_count, total_trials, progress, ...
    formatDurationSeconds(elapsed_seconds), ...
    formatDurationSeconds(remaining_seconds), feasible, ...
    candidate.metrics.score, candidate.metrics.response_nrmse_percent, ...
    candidate.metrics.tracking_nrmse_percent, ...
    candidate.metrics.stability_margin, ...
    candidate.metrics.num_delay_comp_exp_ncf_margin, ...
    candidate.metrics.max_abs_pole)
if candidate.phase_lead.enabled
    fprintf('  G_T: k_T %.12g, z1 %.12g Hz, p1 %.12g Hz\n', ...
        candidate.phase_lead.gain, candidate.phase_lead.zero_hz, ...
        candidate.phase_lead.pole_hz)
else
    fprintf('  G_T: disabled\n')
end
end

function remaining_seconds = estimateRemainingSeconds(elapsed_seconds, ...
        completed_count, total_count)
if completed_count <= 0 || total_count <= completed_count
    remaining_seconds = NaN;
    return
end
remaining_seconds = elapsed_seconds/completed_count ...
    *(total_count-completed_count);
end

function text = formatDurationSeconds(seconds)
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

function checkpoint_file = bestCheckpointFile(problem)
if ~isempty(problem.config.best_checkpoint_file)
    checkpoint_file = char(problem.config.best_checkpoint_file);
    if ~isAbsolutePath(checkpoint_file)
        checkpoint_file = fullfile(problem.project_root, checkpoint_file);
    end
    return
end
checkpoint_file = fullfile(problem.project_root, 'saved_results', ...
    'delay_comp', 'vHS_phase_lead_best_checkpoint.mat');
end

function tf = isAbsolutePath(path)
tf = startsWith(path, filesep) ...
    || startsWith(path, '\\') ...
    || ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
end

function tf = candidateMeetsMinimums(candidate, config, max_response_nrmse)
tolerance = 1e-9;
tf = candidate.metrics.stable ...
    && candidate.metrics.stability_margin + tolerance ...
        >= config.minimum_stability_margin ...
    && candidate.metrics.num_delay_comp_exp_ncf_margin + tolerance ...
        >= config.minimum_num_delay_comp_exp_ncf_margin;
if isfinite(max_response_nrmse)
    tf = tf && candidate.metrics.response_nrmse_percent ...
        <= max_response_nrmse + tolerance;
end
end

function problem = prepareVhsPhaseLeadProblem(project_root, config)
hs = struct( ...
    'earthquake_type', config.earthquake_type, ...
    'intensity_factor', config.intensity_factor, ...
    'time_scale_factor', config.time_scale_factor, ...
    'force_sign', config.force_sign);
if isempty(config.fem_file)
    [fem, fem_file, ~] = loadFemDefinition(project_root, true);
else
    [fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
        config.fem_file);
end
config.fem_file = fem_file;
hs.fem_file = fem_file;

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
fprintf('\nPhase-lead optimizer inputs\n')
fprintf('FEM file: %s\n', fem_file)
fprintf('Experimental specimen file: %s\n', specimen_file)

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
num_model = numericalSubstructureDiscrete(hs, config.sample_dt);
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, ...
    num_model.D_fm, config.sample_dt);

problem = struct( ...
    'config', config, ...
    'project_root', project_root, ...
    'fem', fem, ...
    'fem_file', fem_file, ...
    'specimen', specimen, ...
    'specimen_file', specimen_file, ...
    'h_dc_dm_model_file', h_dc_dm_model_file, ...
    'hs', hs, ...
    'sample_dt', config.sample_dt, ...
    'time', hs_real_time, ...
    'ag_sample', ag_sample, ...
    'u_reference_sample', u_reference_sample(:, 1:hs.n_floor), ...
    'k_experimental', config.k_exp_r*specimen_si.stiffness, ...
    'num_model', num_model, ...
    'num_tf', num_tf, ...
    'PID_H_dc_dm', PID_H_dc_dm, ...
    'digital_controller', digital_controller);
end

function score = phaseLeadObjective(x, problem)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x));
score = candidate.metrics.score;
end

function [c, ceq] = phaseLeadConstraints(x, problem, max_response_nrmse)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x));
c = candidate.metrics.max_abs_pole - 1;
if problem.config.minimum_stability_margin > 0
    c(end+1, 1) = problem.config.minimum_stability_margin ...
        - candidate.metrics.stability_margin;
end
if problem.config.minimum_num_delay_comp_exp_ncf_margin > 0
    c(end+1, 1) = ...
        problem.config.minimum_num_delay_comp_exp_ncf_margin ...
        - candidate.metrics.num_delay_comp_exp_ncf_margin;
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
num_delay_comp_exp_metrics = numDelayCompExpMetrics(problem, phase_lead);

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
metrics = scoreVhsPhaseLead(problem, signals, stability, ...
    num_delay_comp_exp_metrics);
candidate = struct('phase_lead', phase_lead, 'stability', stability, ...
    'num_delay_comp_exp_metrics', num_delay_comp_exp_metrics, ...
    'signals', signals, 'metrics', metrics);
end

function metrics = scoreVhsPhaseLead(problem, signals, stability, ...
        num_delay_comp_exp_metrics)
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
num_delay_comp_exp_ncf_margin = num_delay_comp_exp_metrics.ncf_margin;
minimum_ncf_shortfall = max(0, ...
    config.minimum_num_delay_comp_exp_ncf_margin ...
    - num_delay_comp_exp_ncf_margin);

performance_score = response_nrmse_percent ...
    + config.tracking_error_weight*tracking_nrmse_percent ...
    + config.lead_change_weight*lead_change_percent;
score = performance_score ...
    + config.pole_penalty_weight*(pole_excess/pole_scale)^2 ...
    + config.command_ratio_penalty_weight*command_ratio_excess^2 ...
    + config.minimum_margin_penalty_weight*minimum_margin_shortfall^2 ...
    + config.minimum_margin_penalty_weight*minimum_ncf_shortfall^2;
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
    'num_delay_comp_exp_gm_db', num_delay_comp_exp_metrics.gm_db, ...
    'num_delay_comp_exp_pm_deg', num_delay_comp_exp_metrics.pm_deg, ...
    'num_delay_comp_exp_ncf_margin', num_delay_comp_exp_ncf_margin, ...
    'minimum_margin_shortfall', minimum_margin_shortfall, ...
    'minimum_ncf_shortfall', minimum_ncf_shortfall, ...
    'max_abs_pole', stability.coupled_max_abs_pole, ...
    'stable', stability.coupled_stable);
end

function metrics = numDelayCompExpMetrics(problem, phase_lead)
delay_comp_tf_discrete = buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt);
open_loop = -minreal(problem.num_tf*(problem.k_experimental/1000) ...
    * delay_comp_tf_discrete*problem.PID_H_dc_dm, [], false);
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    custom_stability_margins(open_loop, ...
    problem.config.num_delay_comp_exp_margin_frequency_hz);
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
    'NumDelayCompExpNCFMargin', ...
        candidate.metrics.num_delay_comp_exp_ncf_margin, ...
    'MaxAbsPole', candidate.metrics.max_abs_pole, ...
    'Stable', candidate.metrics.stable);
end

function printCandidate(candidate)
fprintf(['Score = %.6g, response NRMSE = %.6g %%, ' ...
    'tracking NRMSE = %.6g %%, stability margin = %.12g, ' ...
    'num_delay_comp_exp NCF = %.12g, max |pole| = %.12g\n'], ...
    candidate.metrics.score, candidate.metrics.response_nrmse_percent, ...
    candidate.metrics.tracking_nrmse_percent, ...
    candidate.metrics.stability_margin, ...
    candidate.metrics.num_delay_comp_exp_ncf_margin, ...
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

function delay_comp_paths = saveDelayCompensatorFiles(project_root, ...
        run_timestamp, best)
delay_comp_dir = fullfile(project_root, 'saved_results', 'delay_comp');
if ~exist(delay_comp_dir, 'dir')
    mkdir(delay_comp_dir)
end

label = strings(1, 1);
path = strings(1, 1);
[label(1), path(1)] = saveCandidateDelayCompensator( ...
    delay_comp_dir, sprintf('phase_lead_dd_performance_%s.mat', ...
    run_timestamp), 'performance', best);

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
