%% Optimize vHS phase_lead After Numerical DD
% The phase_lead path is:
% raw numerical dd -> G_T -> actuator tracking loop -> measured dm -> force.
% G_T(s) = k_T*prod(s + zi)/prod(s + pi), with pi > zi.

clearvars -except phase_lead_optimizer_config ncfmargin ncf_margin ...
    fem_file_override ...
    specimen_file_override exp_specimen_file_override ...
    h_dc_dm_model_file_override pid_gain_override ...
    phase_lead_file_name_override; clc; close all;

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
if exist('phase_lead_file_name_override', 'var') ...
        && ~isempty(phase_lead_file_name_override)
    config.phase_lead_file_name = phase_lead_file_name_override;
end
if exist('ncfmargin', 'var') && ~isempty(ncfmargin)
    config.minimum_num_phase_lead_exp_ncf_margin = ncfmargin;
elseif exist('ncf_margin', 'var') && ~isempty(ncf_margin)
    config.minimum_num_phase_lead_exp_ncf_margin = ncf_margin;
end
config = enforceMinimumOptimizationRecordFraction(config);
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
validateattributes(config.phase_lead_section_count, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, ...
    'config.phase_lead_section_count');

optimization_problem = prepareVhsPhaseLeadProblem(project_root, config, ...
    config.optimization_record_fraction);
config = optimization_problem.config;
compact_output = useCompactOptimizerOutput(config);
optimization_baseline = evaluateVhsPhaseLead(optimization_problem, []);
log_entries = summarizeCandidate('baseline', optimization_baseline);

if ~compact_output
    fprintf('\nOptimization baseline without phase_lead\n')
    printCandidate(optimization_baseline)
end

[grid_candidates, log_entries, best_checkpoint] = evaluatePhaseLeadGrid( ...
    optimization_problem, optimization_baseline, log_entries);
[optimization_best, log_entries] = optimizePhaseLeadForPerformance( ...
    optimization_problem, optimization_baseline, log_entries, ...
    grid_candidates, best_checkpoint);

optimization_result_table = struct2table(log_entries);
optimization_result_table = sortrows(optimization_result_table, 'Score');

if ~compact_output
    fprintf('\nBest optimization candidate on %.3g of the record\n', ...
        config.optimization_record_fraction)
    printCandidate(optimization_best)
    disp(optimization_result_table(:, {'Stage', 'Score', 'Zero_Hz', ...
        'Pole_Hz', 'Gain', 'MaxPhaseLead_deg', 'J4_percent', ...
        'TrackingNRMSE_percent', 'StabilityMargin', ...
        'NumPhaseLeadExpNCFMargin', 'MaxAbsPole', 'PeakCommandRatio', ...
        'MaxDCDMRatio', 'MaxDDLeadDCRatio'}))
end

best_phase_lead = optimization_best.phase_lead;
report_problem = prepareVhsPhaseLeadProblem(project_root, config, 1);
config = report_problem.config;
compact_output = useCompactOptimizerOutput(config);
baseline = evaluateVhsPhaseLead(report_problem, []);
best = evaluateVhsPhaseLead(report_problem, best_phase_lead);
phase_lead_result_table = struct2table([ ...
    summarizeCandidate('full_baseline', baseline); ...
    summarizeCandidate('full_best', best)]);
baseline_metrics = baseline.metrics;
best_metrics = best.metrics;

if compact_output
    printCandidate(best, config)
else
    fprintf('\nFull-record baseline without phase_lead\n')
    printCandidate(baseline)
    fprintf('\nFull-record selected candidate\n')
    printCandidate(best)
    disp(phase_lead_result_table(:, {'Stage', 'Score', 'Zero_Hz', ...
        'Pole_Hz', 'Gain', 'MaxPhaseLead_deg', 'J4_percent', ...
        'TrackingNRMSE_percent', 'StabilityMargin', ...
        'NumPhaseLeadExpNCFMargin', 'MaxAbsPole', 'PeakCommandRatio', ...
        'MaxDCDMRatio', 'MaxDDLeadDCRatio'}))
end

baseline_feasible = candidateMeetsMinimums(baseline, config, Inf);
recommend_best = best.phase_lead.enabled ...
    && (~baseline_feasible || best.metrics.score < baseline.metrics.score);
if ~recommend_best
    recommended_phase_lead_override = [];
    if ~compact_output
        fprintf(['\nRecommendation: leave phase_lead disabled for this objective; ' ...
            'the best active candidate did not improve the baseline score.\n'])
    end
else
    recommended_phase_lead_override = struct('enabled', true, ...
        'gain', best_phase_lead.gain, ...
        'zero_hz', best_phase_lead.zero_hz, ...
        'pole_hz', best_phase_lead.pole_hz);
    if ~compact_output
        fprintf('\nRecommended phase_lead configuration:\nphase_lead = %s;\n', ...
            phaseLeadStructLiteral(best_phase_lead))
    end
end

if config.save_results
    phase_lead_paths = savePhaseLeadFiles(project_root, ...
        best, config, baseline_metrics, best_phase_lead, ...
        best_metrics, recommended_phase_lead_override, ...
        phase_lead_result_table, optimization_result_table);
    if ~compact_output
        fprintf('\nSaved phase_lead optimization results = %s\n', ...
            phase_lead_paths.Path(1))
    end
else
    phase_lead_paths = table;
end

if config.plot_results
    plotPhaseLeadOptimization(report_problem, baseline, best)
end

if ~compact_output
    printPhaseLeadValidationMetrics(report_problem, baseline, best)
    printPhaseLeadStabilitySummary(report_problem, best_phase_lead)
end

function config = defaultPhaseLeadOptimizerConfig()
config = struct( ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.2, ...
    'time_scale_factor', 1, ...
    'force_sign', 1.0, ...
    'optimization_record_fraction', 0.25, ...
    'minimum_optimization_record_fraction', 0, ...
    'k_exp_r', 1.0, ...
    'sample_dt', 1/2048, ...
    'h_dc_dm_model_file', '', ...
    'phase_lead_file_name', '', ...
    'fem_file', '', ...
    'specimen_file', '', ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    'phase_lead_section_count', 1, ...
    'center_frequency_bounds_hz', [0.5 80], ...
    'ratio_bounds', [1.01 25], ...
    'grid_center_hz', [1 2 3 4 8 12 18 27 40 60], ...
    'grid_ratio', [1.05 1.2 1.5 2 3 5 8 12 14 15 18], ...
    'start_points', [], ...
    'fmincon_grid_start_count', 0, ...
    'compact_optimizer_output', false, ...
    'minimum_stability_margin', 0, ...
    'minimum_num_phase_lead_exp_ncf_margin', 0, ...
    'num_phase_lead_exp_margin_frequency_hz', [0.1 80], ...
    'num_phase_lead_exp_margin_point_count', 10000, ...
    'minimum_margin_penalty_weight', 1e8, ...
    'max_dc_dm_penalty_weight', 0, ...
    'max_dd_lead_dc_penalty_weight', 0, ...
    'use_fmincon', true, ...
    'use_parallel_grid', true, ...
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

function tf = useCompactOptimizerOutput(config)
tf = isfield(config, 'compact_optimizer_output') ...
    && config.compact_optimizer_output;
end

function config = enforceMinimumOptimizationRecordFraction(config)
if ~isfield(config, 'minimum_optimization_record_fraction') ...
        || isempty(config.minimum_optimization_record_fraction)
    config.minimum_optimization_record_fraction = 0;
end
validateattributes(config.minimum_optimization_record_fraction, ...
    {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative', '<=', 1}, ...
    mfilename, 'config.minimum_optimization_record_fraction');
if config.optimization_record_fraction ...
        < config.minimum_optimization_record_fraction
    config.optimization_record_fraction = ...
        config.minimum_optimization_record_fraction;
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

if ~useCompactOptimizerOutput(config)
    fprintf('\nGrid search for phase_lead candidates\n')
end
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
    if ~useCompactOptimizerOutput(config)
        fprintf('Parallel grid enabled with %d workers.\n', pool.NumWorkers)
    end
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
    phaseLeadFromCenterRatio(candidate_input(1), candidate_input(2), ...
    problem.config.phase_lead_section_count)));
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
    if ~useCompactOptimizerOutput(config)
        fprintf('\nfmincon refinement disabled; using best grid candidate only.\n')
    end
    best = ensureFullCandidate(problem, best);
    checkpoint.best = reduceCandidate(best);
    checkpoint.best_feasible = best_feasible;
    writePerformanceCheckpoint(checkpoint, problem, 'performance_final', true);
    return
end
if exist('fmincon', 'file') ~= 2
    if ~useCompactOptimizerOutput(config)
        fprintf('\nfmincon is unavailable; using best grid candidate only.\n')
    end
    best = ensureFullCandidate(problem, best);
    checkpoint.best = reduceCandidate(best);
    checkpoint.best_feasible = best_feasible;
    writePerformanceCheckpoint(checkpoint, problem, 'performance_final', true);
    return
end

if ~useCompactOptimizerOutput(config)
    fprintf('\nLocal performance refinement using fmincon\n')
end
[lower_bounds, upper_bounds, start_points] = optimizerSearchSetup( ...
    config, best, grid_candidates);
options = phaseLeadFminconOptions(config);
n_start = size(start_points, 1);
checkpoint.total_trials = checkpoint.total_trials + n_start;
for start_id = 1:size(start_points, 1)
    if ~useCompactOptimizerOutput(config)
        fprintf('Performance fmincon start %d/%d\n', start_id, n_start)
    end
    x0 = log(start_points(start_id, :));
    x0 = min(max(x0, lower_bounds), upper_bounds);
    fmincon_start_time = tic;
    last_fmincon_funccount = -Inf;
    options_start = options;
    options_start.OutputFcn = @reportPerformanceFminconProgress;
    x_opt = fmincon(@(x) phaseLeadObjective(x, problem), x0, ...
        [], [], [], [], lower_bounds, upper_bounds, ...
        [], options_start);
    candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x_opt, config));
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
        optimizerSearchSetup(config, seed_candidate, grid_candidates)
section_count = config.phase_lead_section_count;
section_ratio_bounds = config.ratio_bounds.^(1/section_count);
lower_bounds = log([ ...
    repmat(config.center_frequency_bounds_hz(1), 1, section_count), ...
    repmat(section_ratio_bounds(1), 1, section_count)]);
upper_bounds = log([ ...
    repmat(config.center_frequency_bounds_hz(2), 1, section_count), ...
    repmat(section_ratio_bounds(2), 1, section_count)]);
if seed_candidate.phase_lead.enabled
    seed_point = [seed_candidate.phase_lead.center_frequency_hz, ...
        max(seed_candidate.phase_lead.section_ratio, section_ratio_bounds(1))];
else
    seed_point = zeros(0, 2*section_count);
end
start_points = expandPhaseLeadStartPoints(config.start_points, ...
    section_count);
grid_start_points = bestGridStartPoints(config, grid_candidates, ...
    section_count);
start_points = unique([seed_point; grid_start_points; start_points], ...
    'rows', 'stable');
end

function start_points = bestGridStartPoints(config, grid_candidates, ...
        section_count)
start_count = max(0, round(config.fmincon_grid_start_count));
if start_count == 0 || isempty(grid_candidates)
    start_points = zeros(0, 2*section_count);
    return
end

scores = arrayfun(@(candidate) candidate.metrics.score, grid_candidates);
[~, order] = sort(scores);
start_count = min(start_count, numel(order));
start_points = zeros(start_count, 2*section_count);
for start_id = 1:start_count
    phase_lead = grid_candidates(order(start_id)).phase_lead;
    start_points(start_id, :) = [phase_lead.center_frequency_hz, ...
        phase_lead.section_ratio];
end
end

function start_points = expandPhaseLeadStartPoints(start_points, section_count)
if isempty(start_points)
    start_points = zeros(0, 2*section_count);
    return
end
if size(start_points, 2) == 2*section_count
    return
end
if size(start_points, 2) ~= 2
    error('optimize_vHS_phase_lead:InvalidStartPoints', ...
        'start_points must have 2 or 2*phase_lead_section_count columns.')
end

center_factors = defaultSectionCenterFactors(section_count);
expanded_points = zeros(size(start_points, 1), 2*section_count);
for point_id = 1:size(start_points, 1)
    center_hz = start_points(point_id, 1);
    total_ratio = start_points(point_id, 2);
    expanded_points(point_id, :) = [center_hz*center_factors, ...
        repmat(total_ratio^(1/section_count), 1, section_count)];
end
start_points = expanded_points;
end

function center_factors = defaultSectionCenterFactors(section_count)
if section_count == 1
    center_factors = 1;
else
    center_factors = logspace(log10(0.75), log10(1.35), section_count);
end
end

function options = phaseLeadFminconOptions(config)
if useCompactOptimizerOutput(config)
    display_mode = 'off';
else
    display_mode = 'final';
end
options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'Display', display_mode, ...
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
if useCompactOptimizerOutput(config)
    fprintf(['fmincon %s start %d/%d: evaluations %d/%d, ' ...
        'elapsed %s, ETA %s, fval %.6g\n'], ...
        status, start_id, n_start, funccount, max_evaluations, ...
        formatDurationSeconds(elapsed_seconds), ...
        formatDurationSeconds(remaining_seconds), fval)
    last_funccount = funccount;
    return
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
    if ~useCompactOptimizerOutput(config)
        fprintf(['Parallel grid disabled; Parallel Computing Toolbox ' ...
            'is unavailable.\n'])
    end
    return
end

try
    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool;
    end
    tf = ~isempty(pool);
catch err
    if ~useCompactOptimizerOutput(config)
        fprintf('Parallel grid disabled: %s\n', err.message)
    end
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
        remaining_seconds, problem.config)
end
if checkpoint.save_enabled
    checkpoint_dir = fileparts(best_checkpoint_file);
    if ~isempty(checkpoint_dir) && ~exist(checkpoint_dir, 'dir')
        mkdir(checkpoint_dir)
    end
    config = problem.config;
    fprintf('***saving***\n')
    save(best_checkpoint_file, 'best_checkpoint', ...
        'best_checkpoint_metrics', 'best_checkpoint_phase_lead', ...
        'best_checkpoint_feasible', 'best_checkpoint_trial_count', ...
        'best_checkpoint_history', 'best_checkpoint_updated_at', ...
        'best_checkpoint_stage', 'config')
    if best_checkpoint_trial_count > 0
        phase_lead_checkpoint_file = saveCheckpointPhaseLeadFile( ...
            problem, best_checkpoint, best_checkpoint_stage, ...
            best_checkpoint_trial_count);
        fprintf('Saved phase_lead file trial %d: %s\n', ...
            best_checkpoint_trial_count, phase_lead_checkpoint_file)
    end
    if useCompactOptimizerOutput(problem.config)
        fprintf('Saved best checkpoint trial %d: %s\n', ...
            best_checkpoint_trial_count, best_checkpoint_file)
    end
elseif checkpoint.print_enabled || checkpoint.progress_enabled
    fprintf('***not saving: save_best_checkpoint is false***\n')
end
end

function entry = checkpointEntry(stage, trial_count, candidate, feasible)
entry = struct( ...
    'Stage', string(stage), ...
    'Trial', trial_count, ...
    'Feasible', feasible, ...
    'Score', candidate.metrics.score, ...
    'J4_percent', candidate.metrics.j4_percent, ...
    'NumPhaseLeadExpNCFMargin', ...
        candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    'MaxDCDMRatio', candidate.metrics.max_dc_dm_ratio, ...
    'MaxDDLeadDCRatio', candidate.metrics.max_dd_lead_dc_ratio, ...
    'Zero_Hz', candidate.phase_lead.zero_hz, ...
    'Pole_Hz', candidate.phase_lead.pole_hz, ...
    'Gain', candidate.phase_lead.gain);
end

function printBestCheckpoint(stage, trial_count, total_trials, feasible, ...
        candidate, elapsed_seconds, remaining_seconds, config)
if total_trials > 0
    progress = 100*trial_count/total_trials;
else
    progress = 0;
end
if useCompactOptimizerOutput(config)
    printCompactCandidate(candidate, sprintf( ...
        'Best checkpoint trial %d/%d (%.1f%%, elapsed %s, ETA %s): ', ...
        trial_count, total_trials, progress, ...
        formatDurationSeconds(elapsed_seconds), ...
        formatDurationSeconds(remaining_seconds)))
    return
end
fprintf(['\nBest checkpoint [%s, trial %d/%d, %.1f%%, ' ...
    'elapsed %s, ETA %s, feasible = %d]: score %.6g, ' ...
    'J4 %.6g %%, NCF %.12g, max dc/dm %.6g, ' ...
    'max dd_lead/dc %.6g\n'], ...
    stage, trial_count, total_trials, progress, ...
    formatDurationSeconds(elapsed_seconds), ...
    formatDurationSeconds(remaining_seconds), feasible, ...
    candidate.metrics.score, candidate.metrics.j4_percent, ...
    candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    candidate.metrics.max_dc_dm_ratio, ...
    candidate.metrics.max_dd_lead_dc_ratio)
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
    'phase_lead', 'vHS_phase_lead_best_checkpoint.mat');
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
    && candidate.metrics.num_phase_lead_exp_ncf_margin + tolerance ...
        >= config.minimum_num_phase_lead_exp_ncf_margin;
if isfinite(max_response_nrmse)
    tf = tf && candidate.metrics.response_nrmse_percent ...
        <= max_response_nrmse + tolerance;
end
end

function problem = prepareVhsPhaseLeadProblem(project_root, config, record_fraction)
if nargin < 3 || isempty(record_fraction)
    record_fraction = 1;
end
validateattributes(record_fraction, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<=', 1}, mfilename, ...
    'record_fraction');
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
    loadPidHdcDmModel( ...
        project_root, config.h_dc_dm_model_file, ...
        config.pid_gain_override, config.sample_dt);
config.h_dc_dm_model_file = h_dc_dm_model_file;
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, config.sample_dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

if isempty(config.fem_file)
    [fem, fem_file, ~] = loadFemDefinition(project_root, true);
elseif ~isfile(config.fem_file)
    warning('optimize_vHS_phase_lead:MissingFemFile', ...
        'Configured FEM file not found: %s. Select a FEM file instead.', ...
        config.fem_file)
    [fem, fem_file, ~] = loadFemDefinition(project_root, true);
else
    [fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
        config.fem_file);
end
config.fem_file = fem_file;
hs.fem_file = fem_file;

if ~useCompactOptimizerOutput(config)
    fprintf('\nphase_lead optimizer inputs\n')
    fprintf('Experimental specimen file: %s\n', specimen_file)
    fprintf('Experimental transfer function file: %s\n', h_dc_dm_model_file)
    fprintf('FEM file: %s\n', fem_file)
    fprintf('Record fraction: %.6g\n', record_fraction)
end

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
num_model = numericalSubstructureDiscrete(hs, config.sample_dt);
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
    'num_model', num_model, ...
    'num_tf', num_tf, ...
    'margin_frequency_rad_s', margin_frequency_rad_s, ...
    'base_open_loop_response', base_open_loop_response(:), ...
    'PID_H_dc_dm', PID_H_dc_dm, ...
    'actuator_open_loop', actuator_open_loop, ...
    'pid_values', pid_values, ...
    'digital_controller', digital_controller);
end

function score = phaseLeadObjective(x, problem)
candidate = evaluateVhsPhaseLead(problem, phaseLeadFromX(x, problem.config));
score = candidate.metrics.score;
end

function candidate = evaluateVhsPhaseLead(problem, phase_lead_override)
phase_lead = normalizePhaseLeadConfig(phase_lead_override, ...
    problem.config.phase_lead_section_count);
num_model = problem.num_model;
actuator = discreteSiso(problem.PID_H_dc_dm, problem.sample_dt);
lead_filter = discreteSiso(buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt), problem.sample_dt);
controller = discreteSiso(problem.digital_controller, problem.sample_dt);
stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
    problem.k_experimental, problem.sample_dt);
num_phase_lead_exp_metrics = numPhaseLeadExpMetrics(problem, phase_lead);

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
    num_phase_lead_exp_metrics);
candidate = struct('phase_lead', phase_lead, 'stability', stability, ...
    'num_phase_lead_exp_metrics', num_phase_lead_exp_metrics, ...
    'signals', signals, 'metrics', metrics);
end

function metrics = scoreVhsPhaseLead(problem, signals, stability, ...
        num_phase_lead_exp_metrics)
config = problem.config;
response_error = signals.u_num_floors_sample - problem.u_reference_sample;
metric = validation_metrics();
j4_percent = metric.J4(signals.u_num_floors_sample(:, 1), ...
    problem.u_reference_sample(:, 1));
response_nrmse_percent = 100*rms(response_error(:)) ...
    /max(rms(problem.u_reference_sample(:)), eps);
tracking_nrmse_percent = 100*rms(signals.dd_lead_sample - signals.dm_sample) ...
    /max(rms(signals.dd_lead_sample), eps);
lead_change_percent = 100*rms(signals.dd_lead_sample - signals.dd_sample) ...
    /max(rms(signals.dd_sample), eps);
peak_command_ratio = max(abs(signals.dd_lead_sample)) ...
    /max(max(abs(signals.dd_sample)), eps);
max_dc_dm_ratio = max(abs(signals.dc_sample)) ...
    /max(max(abs(signals.dm_sample)), eps);
max_dc_dm_penalty = config.max_dc_dm_penalty_weight*max_dc_dm_ratio;
max_dd_lead_dc_ratio = max(abs(signals.dd_lead_sample)) ...
    /max(max(abs(signals.dc_sample)), eps);
max_dd_lead_dc_penalty = ...
    config.max_dd_lead_dc_penalty_weight*max_dd_lead_dc_ratio;
stability_margin = 1 - stability.coupled_max_abs_pole;
minimum_margin_shortfall = max(0, config.minimum_stability_margin ...
    - stability_margin);
num_phase_lead_exp_ncf_margin = num_phase_lead_exp_metrics.ncf_margin;
minimum_ncf_shortfall = max(0, ...
    config.minimum_num_phase_lead_exp_ncf_margin ...
    - num_phase_lead_exp_ncf_margin);

performance_score = j4_percent + max_dc_dm_penalty ...
    + max_dd_lead_dc_penalty;
score = performance_score ...
    + config.minimum_margin_penalty_weight*minimum_ncf_shortfall^2;
if stability.coupled_max_abs_pole >= 1
    score = score + 1e6*(1 + stability.coupled_max_abs_pole - 1);
end

metrics = struct( ...
    'score', score, ...
    'performance_score', performance_score, ...
    'j4_percent', j4_percent, ...
    'response_nrmse_percent', response_nrmse_percent, ...
    'tracking_nrmse_percent', tracking_nrmse_percent, ...
    'lead_change_percent', lead_change_percent, ...
    'peak_command_ratio', peak_command_ratio, ...
    'max_dc_dm_ratio', max_dc_dm_ratio, ...
    'max_dc_dm_penalty', max_dc_dm_penalty, ...
    'max_dd_lead_dc_ratio', max_dd_lead_dc_ratio, ...
    'max_dd_lead_dc_penalty', max_dd_lead_dc_penalty, ...
    'stability_margin', stability_margin, ...
    'num_phase_lead_exp_gm_db', num_phase_lead_exp_metrics.gm_db, ...
    'num_phase_lead_exp_pm_deg', num_phase_lead_exp_metrics.pm_deg, ...
    'num_phase_lead_exp_ncf_margin', num_phase_lead_exp_ncf_margin, ...
    'minimum_margin_shortfall', minimum_margin_shortfall, ...
    'minimum_ncf_shortfall', minimum_ncf_shortfall, ...
    'max_abs_pole', stability.coupled_max_abs_pole, ...
    'stable', stability.coupled_stable);
end

function metrics = numPhaseLeadExpMetrics(problem, phase_lead)
phase_lead_tf_discrete = buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt);
lead_response = squeeze(freqresp(phase_lead_tf_discrete, ...
    problem.margin_frequency_rad_s));
open_loop_response = problem.base_open_loop_response.*lead_response(:);
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    stabilityMarginsFromResponse(open_loop_response);
end

function [gain_margin_db, phase_margin_deg, ncf_margin] = ...
        stabilityMarginsFromResponse(response)
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

function phase_lead = phaseLeadFromX(x, config)
section_count = config.phase_lead_section_count;
values = exp(x(:).');
center_hz = values(1:section_count);
ratio = values(section_count+1:2*section_count);
phase_lead = phaseLeadFromCentersRatios(center_hz, ratio);
end

function phase_lead = phaseLeadFromCenterRatio(center_hz, ratio, ...
        section_count)
center_hz = center_hz*ones(1, section_count);
ratio = repmat(ratio^(1/section_count), 1, section_count);
phase_lead = phaseLeadFromCentersRatios(center_hz, ratio);
end

function phase_lead = phaseLeadFromCentersRatios(center_hz, ratio)
zero_hz = center_hz./sqrt(ratio);
pole_hz = center_hz.*sqrt(ratio);
gain = prod(ratio);
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
    'J4_percent', candidate.metrics.j4_percent, ...
    'ResponseNRMSE_percent', candidate.metrics.response_nrmse_percent, ...
    'TrackingNRMSE_percent', candidate.metrics.tracking_nrmse_percent, ...
    'LeadChange_percent', candidate.metrics.lead_change_percent, ...
    'PeakCommandRatio', candidate.metrics.peak_command_ratio, ...
    'MaxDCDMRatio', candidate.metrics.max_dc_dm_ratio, ...
    'MaxDCDMPenalty', candidate.metrics.max_dc_dm_penalty, ...
    'MaxDDLeadDCRatio', candidate.metrics.max_dd_lead_dc_ratio, ...
    'MaxDDLeadDCPenalty', candidate.metrics.max_dd_lead_dc_penalty, ...
    'StabilityMargin', candidate.metrics.stability_margin, ...
    'NumPhaseLeadExpNCFMargin', ...
        candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    'MaxAbsPole', candidate.metrics.max_abs_pole, ...
    'Stable', candidate.metrics.stable);
end

function printCandidate(candidate, config)
if nargin > 1 && useCompactOptimizerOutput(config)
    printCompactCandidate(candidate, 'Final best: ')
    return
end
fprintf(['Score = %.6g, J4 = %.6g %%, ' ...
    'tracking NRMSE = %.6g %%, stability margin = %.12g, ' ...
    'num_phase_lead_exp NCF = %.12g, max |pole| = %.12g\n'], ...
    candidate.metrics.score, candidate.metrics.j4_percent, ...
    candidate.metrics.tracking_nrmse_percent, ...
    candidate.metrics.stability_margin, ...
    candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    candidate.metrics.max_abs_pole)
if candidate.phase_lead.enabled
    fprintf('G_T: %s\n', phaseLeadSummary(candidate.phase_lead))
else
    fprintf('G_T: disabled\n')
end
end

function printCompactCandidate(candidate, prefix)
if nargin < 2
    prefix = '';
end
fprintf(['%sScore = %.6g, J4 = %.6g %%, ncf = %.12g, ' ...
    'dd_lead/dc= %.6g, dc/dm = %.6g\n'], ...
    prefix, candidate.metrics.score, candidate.metrics.j4_percent, ...
    candidate.metrics.num_phase_lead_exp_ncf_margin, ...
    candidate.metrics.max_dd_lead_dc_ratio, ...
    candidate.metrics.max_dc_dm_ratio)
end

function text = phaseLeadSummary(phase_lead)
text = sprintf(['k_T = %.12g, z_hz = %s, p_hz = %s, DC gain = %.12g, ' ...
    'max lead = %.6g deg at %.6g Hz'], ...
    phase_lead.gain, matlabVectorLiteral(phase_lead.zero_hz), ...
    matlabVectorLiteral(phase_lead.pole_hz), phase_lead.dc_gain, ...
    phase_lead.max_phase_lead_deg, ...
    phase_lead.max_phase_lead_frequency_hz);
end

function text = phaseLeadStructLiteral(phase_lead)
text = sprintf(['struct(''enabled'', true, ''gain'', %.12g, ' ...
    '''zero_hz'', %s, ''pole_hz'', %s)'], ...
    phase_lead.gain, matlabVectorLiteral(phase_lead.zero_hz), ...
    matlabVectorLiteral(phase_lead.pole_hz));
end

function text = matlabVectorLiteral(values)
values = values(:).';
parts = arrayfun(@(value) sprintf('%.12g', value), values, ...
    'UniformOutput', false);
if isscalar(values)
    text = parts{1};
else
    text = ['[' strjoin(parts, ' ') ']'];
end
end

function phase_lead_paths = savePhaseLeadFiles(project_root, ...
        best, config, baseline_metrics, best_phase_lead, ...
        best_metrics, recommended_phase_lead_override, ...
        phase_lead_result_table, optimization_result_table)
phase_lead_dir = fullfile(project_root, 'saved_results', 'phase_lead');
if ~exist(phase_lead_dir, 'dir')
    mkdir(phase_lead_dir)
end

label = strings(1, 1);
path = strings(1, 1);
file_name = promptPhaseLeadFileName(phase_lead_dir, ...
    config.phase_lead_file_name);
[label(1), path(1)] = saveCandidatePhaseLead( ...
    phase_lead_dir, file_name, 'performance', best, config, baseline_metrics, ...
    best_phase_lead, best_metrics, recommended_phase_lead_override, ...
    phase_lead_result_table, optimization_result_table);

phase_lead_paths = table(label, path, ...
    'VariableNames', {'Label', 'Path'});
end

function file_name = promptPhaseLeadFileName(phase_lead_dir, file_name)
if nargin > 1 && ~isempty(file_name)
    file_name = cleanPhaseLeadFileName(file_name);
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
        file_name = cleanPhaseLeadFileName(file_name);
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

function file_name = cleanPhaseLeadFileName(file_name)
[folder, name, ext] = fileparts(char(file_name));
if ~isempty(folder)
    error('optimize_vHS_phase_lead:InvalidFileName', ...
        'Enter only a filename, not a folder path.')
end
if isempty(ext)
    ext = '.mat';
elseif ~strcmpi(ext, '.mat')
    error('optimize_vHS_phase_lead:InvalidFileName', ...
        'Use a .mat filename.')
end
file_name = [name ext];
end

function [label, path] = saveCandidatePhaseLead( ...
        phase_lead_dir, file_name, label, candidate, config, ...
        baseline_metrics, best_phase_lead, best_metrics, ...
        recommended_phase_lead_override, phase_lead_result_table, ...
        optimization_result_table)
path = string(fullfile(phase_lead_dir, file_name));
phase_lead_tf = continuousPhaseLeadTransferFunction(candidate.phase_lead);
phase_lead = candidate.phase_lead;
metrics = candidate.metrics;
phase_lead_label = label;
phase_lead_name = file_name;
created_at = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
save(char(path), 'phase_lead_tf', 'phase_lead', 'metrics', ...
    'phase_lead_label', 'phase_lead_name', 'created_at', ...
    'config', 'baseline_metrics', 'best_phase_lead', 'best_metrics', ...
    'recommended_phase_lead_override', 'phase_lead_result_table', ...
    'optimization_result_table')
verifySavedPhaseLeadFile(path, phase_lead);
label = string(label);
end

function path = saveCheckpointPhaseLeadFile( ...
        problem, candidate, checkpoint_stage, checkpoint_trial_count)
if isempty(problem.config.phase_lead_file_name)
    path = "";
    return
end
phase_lead_dir = fullfile(problem.project_root, 'saved_results', ...
    'phase_lead');
if ~exist(phase_lead_dir, 'dir')
    mkdir(phase_lead_dir)
end
file_name = cleanPhaseLeadFileName(problem.config.phase_lead_file_name);
path = string(fullfile(phase_lead_dir, file_name));
phase_lead_tf = continuousPhaseLeadTransferFunction(candidate.phase_lead);
phase_lead = candidate.phase_lead;
metrics = candidate.metrics;
config = problem.config;
phase_lead_label = 'checkpoint';
phase_lead_name = file_name;
created_at = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
saved_from_checkpoint = struct('stage', checkpoint_stage, ...
    'trial_count', checkpoint_trial_count);
save(char(path), 'phase_lead_tf', 'phase_lead', 'metrics', ...
    'phase_lead_label', 'phase_lead_name', 'created_at', 'config', ...
    'saved_from_checkpoint')
verifySavedPhaseLeadFile(path, phase_lead);
end

function verifySavedPhaseLeadFile(path, expected_phase_lead)
saved = load(char(path), 'phase_lead_tf', 'phase_lead');
assert(isfield(saved, 'phase_lead_tf') && isa(saved.phase_lead_tf, 'tf'), ...
    'optimize_vHS_phase_lead:SaveFailed', ...
    'Saved phase_lead file is missing phase_lead_tf.')
assert(isfield(saved, 'phase_lead') ...
    && isequaln(saved.phase_lead, expected_phase_lead), ...
    'optimize_vHS_phase_lead:SaveFailed', ...
    'Saved phase_lead file does not match the selected candidate.')
end

function phase_lead_tf = continuousPhaseLeadTransferFunction(phase_lead)
phase_lead = normalizePhaseLeadConfig(phase_lead);
if ~phase_lead.enabled
    phase_lead_tf = tf(1);
    return
end

phase_lead_tf = phase_lead.gain ...
    * tf(poly(-phase_lead.zero_rad_s), poly(-phase_lead.pole_rad_s));
end

function printPhaseLeadValidationMetrics(problem, baseline, best)
metric_table = buildPhaseLeadValidationMetricTable(problem, baseline, best);
if best.phase_lead.enabled
    control_path_label = 'num*G_T*PID*H_{dc,dm}*exp';
else
    control_path_label = 'num*PID*H_{dc,dm}*exp';
end
fprintf('Control path: %s\n', control_path_label);
disp(metric_table)
end

function metric_table = buildPhaseLeadValidationMetricTable( ...
        problem, baseline, best)
metric = validation_metrics();
baseline_values = phaseLeadValidationValues(problem, baseline);
best_values = phaseLeadValidationValues(problem, best);
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

    function values = phaseLeadValidationValues(problem_local, candidate)
    fs = 1/problem_local.sample_dt;
    dm_filtfilt = localFiltfiltDm(candidate.signals.dm_sample, fs, 20, 6);
    d_r_mm = 1000*problem_local.d_reference_sample(:);
    values = [ ...
        metric.J1(dm_filtfilt, candidate.signals.dd_sample, ...
            problem_local.sample_dt); ...
        metric.J2(dm_filtfilt, candidate.signals.dd_sample); ...
        metric.J3(dm_filtfilt, candidate.signals.dd_sample); ...
        metric.J4(candidate.signals.u_num_floors_sample(:, 1), ...
            problem_local.u_reference_sample(:, 1)); ...
        metric.J5(candidate.signals.u_num_floors_sample(:, 2), ...
            problem_local.u_reference_sample(:, 2)); ...
        metric.J6(candidate.signals.u_num_floors_sample(:, 3), ...
            problem_local.u_reference_sample(:, 3)); ...
        metric.J7(dm_filtfilt, d_r_mm)];
    end
end

function y = localFiltfiltDm(dm, fs, cutoff_hz, order)
[b, a] = butter(order, cutoff_hz/(fs/2), 'low');
y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function printPhaseLeadStabilitySummary(problem, phase_lead)
phase_lead_tf_discrete = buildPhaseLeadFilter(phase_lead, ...
    problem.sample_dt);
hybrid_margin_frequency_hz = [0.1, 80];
vhs_stability_table = buildVhsStabilityTable(problem.PID_H_dc_dm, ...
    problem.actuator_open_loop, problem.hs, problem.k_experimental, ...
    problem.sample_dt, phase_lead_tf_discrete, hybrid_margin_frequency_hz);

disp('Stability table')
disp(vhs_stability_table)
auth_target_ncf = 0.6;
if isfield(problem.pid_values, 'PID_scale')
    pid_scale = problem.pid_values.PID_scale;
else
    pid_scale = 1;
end
[auth_stability_factor, auth_stability_ncf] = recommendAuthStabilityFactor( ...
    problem.actuator_open_loop, pid_scale, auth_target_ncf, ...
    hybrid_margin_frequency_hz);
fprintf(['Recommended auth_stability_factor for PID+H_dc_dm NCF %.3f: ' ...
    '%.4g (estimated NCF %.4g)\n'], auth_target_ncf, ...
    auth_stability_factor, auth_stability_ncf);
end

function stability_table = buildVhsStabilityTable(PID_H_dc_dm, ...
        actuator_open_loop, hs, k_experimental, sample_time, ...
        phase_lead_tf_discrete, freq_range_hz)
num_model = numericalSubstructureDiscrete(hs, sample_time);
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, ...
    num_model.D_fm, sample_time);
k_mm = k_experimental/1000;
actuator = discreteSiso(PID_H_dc_dm, sample_time);
unity_filter = discreteSiso(tf(1), sample_time);
phase_lead_filter = discreteSiso(phase_lead_tf_discrete, sample_time);
num_exp_stability = analyzeActuatorLoop(num_model, actuator, ...
    unity_filter, k_experimental, sample_time);
num_phase_lead_exp_stability = analyzeActuatorLoop(num_model, actuator, ...
    phase_lead_filter, k_experimental, sample_time);

exp_metrics = stabilityMetrics(actuator_open_loop, ...
    maxAbsPole(PID_H_dc_dm), freq_range_hz);
num_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*PID_H_dc_dm), ...
    num_exp_stability.coupled_max_abs_pole, freq_range_hz);
num_phase_lead_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*phase_lead_tf_discrete*PID_H_dc_dm), ...
    num_phase_lead_exp_stability.coupled_max_abs_pole, freq_range_hz);

stability_table = array2table([ ...
    metricColumn(exp_metrics), ...
    metricColumn(num_exp_metrics), ...
    metricColumn(num_phase_lead_exp_metrics)], ...
    'VariableNames', {'PID_H_dc_dm', 'num_exp', ...
    'num_phase_lead_exp'}, ...
    'RowNames', {'GM_dB', 'PM_deg', 't_cr_s', 'NCF_margin', ...
    'MaxAbsZPole'});
end

function metrics = stabilityMetrics(open_loop, max_abs_z_pole, freq_range_hz)
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    custom_stability_margins(open_loop, freq_range_hz);
margins = allmargin(open_loop);
metrics.t_cr_s = min([margins.DelayMargin(:); Inf]);
metrics.max_abs_z_pole = max_abs_z_pole;
end

function values = metricColumn(metrics)
values = [metrics.gm_db; metrics.pm_deg; metrics.t_cr_s; ...
    metrics.ncf_margin; metrics.max_abs_z_pole];
end

function [factor, ncf_margin] = recommendAuthStabilityFactor( ...
        open_loop, current_factor, target_ncf, freq_range_hz)
current_factor = max(abs(current_factor), eps);
factors = linspace(0.02, 1, 80).';
ncf = NaN(size(factors));
for i = 1:numel(factors)
    [~, ~, ncf(i)] = custom_stability_margins( ...
        (factors(i)/current_factor)*open_loop, freq_range_hz);
end
ok = ncf >= target_ncf;
if any(ok)
    idx = find(ok, 1, 'last');
else
    [~, idx] = max(ncf);
end
factor = factors(idx);
ncf_margin = ncf(idx);
end

function value = maxAbsPole(system_model)
poles = pole(system_model);
value = max([abs(poles(:)); 0]);
end

function [PID_H_dc_dm, pid_values, model_file, actuator_open_loop] = ...
        loadPidHdcDmModel( ...
        project_root, model_file, pid_gain_override, sample_time)
if isempty(model_file)
    [~, model_file, ~] = load_saved_result_file(project_root, 'exp_tf');
end
if ~any(strcmp({whos('-file', model_file).name}, 'H_dc_dm'))
    error('optimize_vHS_phase_lead:MissingHdcDmModel', ...
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
pid_values = applyPidGainOverride(pid_values, pid_gain_override);
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

function plotPhaseLeadOptimization(problem, ~, best)
colors = getPlotColors();
figure('Color', 'w', 'Name', 'PID_H_dc_dm control check');
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
addPeakLines(ax, best.signals.dm_sample, 'dm', colors.blue, 'mm');
addPeakLines(ax, best.signals.dc_sample, 'dc', colors.copperwood, 'mm');
hold(ax, 'off')
grid(ax, 'on')
ylabel(ax, 'Displacement (mm)')
makeLegendToggle(ax);

ax = nexttile;
plot(ax, problem.time, best.signals.force_sample, '-', ...
    'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm (measured force)');
hold(ax, 'on')
addPeakLines(ax, best.signals.force_sample, 'fm', colors.purple, 'N');
hold(ax, 'off')
grid(ax, 'on')
ylabel(ax, 'Force (N)')
xlabel(ax, 'Real time (s)')
makeLegendToggle(ax);
title(layout, 'num*PID*H_{dc,dm}*exp control check')
linkaxes(findall(gcf, 'Type', 'axes'), 'x');
end

function addPeakLines(ax, signal, label, color, unit_name)
max_value = max(signal);
min_value = min(signal);
yline(ax, max_value, '--', sprintf('%s max = %.6g %s', ...
    label, max_value, unit_name), 'Color', color, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
yline(ax, min_value, '--', sprintf('%s min = %.6g %s', ...
    label, min_value, unit_name), 'Color', color, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
end

function makeLegendToggle(ax)
legend_handle = legend(ax, 'Location', 'best');
legend_handle.ItemHitFcn = @toggleLegendItem;
end

function toggleLegendItem(~, event)
target = event.Peer;
if strcmp(target.Visible, 'on')
    target.Visible = 'off';
else
    target.Visible = 'on';
end
end

function colors = getPlotColors()
colors.green = hexToRgb('39BF5E');
colors.blue = hexToRgb('007CA8');
colors.copperwood = hexToRgb('AC6420');
colors.red = hexToRgb('901500');
colors.purple = hexToRgb('74058A');
end

function rgb = hexToRgb(hex_color)
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end
