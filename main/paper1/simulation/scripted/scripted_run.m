function output = scripted_run(options, projectRoot)
%SCRIPTED_RUN Execute all nominal and requested perturbed trials.

arguments
    options (1,1) struct
    projectRoot (1,:) char
end

% Keep older programmatic callers compatible with the pre-alpha_start API.
if ~isfield(options, 'alpha_start')
    options.alpha_start = 1;
end
% A short run name drives filenames; a readable title is retained as data.
% Keep test_name as a compatibility alias for older callers.
if ~isfield(options, 'run_name')
    options.run_name = options.test_name;
end
if ~isfield(options, 'run_title')
    options.run_title = options.run_name;
end
% Keep pre-Bouc-Wen programmatic callers compatible. These defaults are
% inert unless consider_damage selects degrading Bouc-Wen mode (2).
boucWenDefaults = struct( ...
    'post_yield_ratio', 0.001, ...
    'n', 8, ...
    'u_y', 1.25, ... % [mm]
    'sigma', 0.769230769230769, ...
    'delta_nu', 0.05, ... % [mm^-2]
    'delta_eta', 0.011, ... % [mm^-2]
    'q', 6, ... % yield-proximity energy exponent [-]
    'lse_window', 1); % [s]
boucWenFields = fieldnames(boucWenDefaults);
for fieldIndex = 1:numel(boucWenFields)
    fieldName = boucWenFields{fieldIndex};
    if ~isfield(options, fieldName)
        options.(fieldName) = boucWenDefaults.(fieldName);
    end
end
if options.modified == 1
    phaseLeadDefaults = struct( ...
        'lead_gain', 31.6431547, ...
        'lead_zero', 49.3502225, ...
        'lead_pole', 1657.846121);
else
    phaseLeadDefaults = struct( ...
        'lead_gain', 50.8316336027, ...
        'lead_zero', 168.6036181018, ...
        'lead_pole', 8570.3973394443);
end
phaseLeadFields = fieldnames(phaseLeadDefaults);
for fieldIndex = 1:numel(phaseLeadFields)
    fieldName = phaseLeadFields{fieldIndex};
    if ~isfield(options, fieldName)
        options.(fieldName) = phaseLeadDefaults.(fieldName);
    end
end
% Repeatable A/B switching defaults. b_th_2 supplies hysteresis above the
% A-to-B threshold, and A must remain above it continuously for the hold.
if ~isfield(options, 'b_th_2')
    options.b_th_2 = 0.15;
end
if ~isfield(options, 'switch_back_hold')
    options.switch_back_hold = 2;
end
if ~isfield(options, 'switch_transition_duration')
    options.switch_transition_duration = 0.25;
end
scripted_validate_options(options);

fprintf('=====================================================\n')
fprintf('     VIRTUAL RTHS MDOF BENCHMARK CONTROL PROBLEM     \n')
fprintf('              Pure MATLAB Simulation Tool            \n')
fprintf('=====================================================\n\n')

numTrials = 1 + options.num_add;
jValues = zeros(numTrials, 9);
test = cell(numTrials, 1);
resultFiles = cell(numTrials, 1);
retainedTrial = struct;
nominalParams = struct;
coupledDamping = table();
controllerCharacteristics = table();
controllerCTune = struct;
resultsDir = fullfile(projectRoot, 'Results');
if ~isfolder(resultsDir)
    mkdir(resultsDir);
end
filePrefix = scripted_result_prefix(options.run_name, resultsDir);

for trialIndex = 1:numTrials
    params = scripted_build_trial(options, projectRoot, trialIndex);
    if trialIndex == 1
        nominalParams = params;
        coupledDamping = scripted_coupled_damping_table(params);
        controllerCTune = params.controller_c_report;
    end
    simulatedTrial = scripted_engine(params);
    if trialIndex == 1
        retainedTrial = simulatedTrial;
    end
    % F3_simulation only extracts simOut while EQ_input is absent. Match
    % that observable behavior: later simulations execute, but evaluation
    % and saved signals remain the nominal trial's values.
    trial = retainedTrial;
    metrics = blk_evaluation(trial, params.dt_rths);

    jValues(trialIndex, :) = metrics;
    if trialIndex == 1
        test{trialIndex} = 'Nominal';
        trialLabel = 'Nom_';
    else
        test{trialIndex} = sprintf('Perturbed_ %d', trialIndex - 1);
        trialLabel = sprintf('Pert_%d', trialIndex - 1);
    end

    resultPath = fullfile(resultsDir, sprintf('%s_%s.mat', filePrefix, trialLabel));
    resultFiles{trialIndex} = resultPath;

    t = trial.t;
    Ref_Resp = trial.Ref_Resp;
    Num_resp = trial.Num_resp;
    X_m = trial.X_m;
    eval_crit = metrics;
    alpha = trial.alpha;
    BoucWen = trial.BoucWen;
    BoucWen_energy = trial.BoucWen_energy;
    Restoring_force = trial.Restoring_force;
    LSE_stiffness = trial.LSE_stiffness;
    lse_window = params.lse_window;
    indicator = trial.indicator;
    indicator_a = trial.indicator_a;
    indicator_b = trial.indicator_b;
    controller_beta = trial.beta;
    active_controller_a = trial.active_controller_a;
    switch_event = trial.switch_event;
    PI_command = trial.PI_command;
    PI_command_max_mm = 1000 * max(abs(PI_command.Data), [], 'all');
    run_name = options.run_name;
    run_title = options.run_title;
    trial_name = test{trialIndex};
    save(resultPath, 't', 'Ref_Resp', 'Num_resp', 'X_m', ...
        'eval_crit', 'alpha', 'BoucWen', 'BoucWen_energy', ...
        'Restoring_force', 'LSE_stiffness', 'lse_window', 'indicator', ...
        'indicator_a', 'indicator_b', 'controller_beta', ...
        'active_controller_a', 'switch_event', 'PI_command', ...
        'PI_command_max_mm', 'run_name', 'run_title', 'trial_name', ...
        'options');

    if trialIndex == 1
        commandMaximum = scripted_command_maxima_cache( ...
            projectRoot, params, PI_command_max_mm, resultPath);
        controllerCharacteristics = ...
            scripted_controller_characteristics_table( ...
            params, commandMaximum);
    end

    if max(abs(trial.Force_act.Data), [], 'all') >= 8900
        warning('scripted:ActuatorCapacity', ...
            'WARNING. The actuator capacity was exceeded.')
    end

    if strcmpi(options.plot_on, 'y')
        blk_plot_rths(trial, params.tend);
    end
    if options.enable_indicator_plot == 1
        exportHysteresis = contains(lower(string(options.run_name)), ...
            'case_04');
        blk_plot_indicator(trial, resultPath, exportHysteresis);
    end

    output = trial;
    output.eval_crit = metrics;
end

output.test = test;
for column = 1:9
    output.(sprintf('J%d', column)) = jValues(:, column);
end
output.Results = array2table(jValues, ...
    'VariableNames', compose('J%d', 1:9), 'RowNames', test);
output.CoupledDamping = coupledDamping;
output.ControllerCharacteristics = controllerCharacteristics;
output.PI_command_max_mm = ...
    1000 * max(abs(output.PI_command.Data), [], 'all');
output.ControllerCTune = controllerCTune;
output.LastRunConfiguration = scripted_last_run_configuration( ...
    projectRoot, nominalParams);
output.RunName = options.run_name;
output.RunTitle = options.run_title;
output.ResultFiles = resultFiles;

final_results = struct( ...
    'RunName', options.run_name, ...
    'RunTitle', options.run_title, ...
    'SavedAt', datetime('now'), ...
    'Options', options, ...
    'Trials', {test}, ...
    'JIndicators', output.Results, ...
    'SignalFiles', {resultFiles}, ...
    'CoupledDamping', coupledDamping, ...
    'ControllerCharacteristics', controllerCharacteristics, ...
    'ControllerCTune', controllerCTune, ...
    'LastRunConfiguration', output.LastRunConfiguration);
summaryPath = fullfile(resultsDir, sprintf('%s_results.mat', filePrefix));
save(summaryPath, 'final_results');
output.FinalResults = final_results;
output.SummaryFile = summaryPath;
end

function prefix = scripted_result_prefix(runName, resultsDir)
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
if strcmpi(runName, 'None')
    basePrefix = ['Data_' timestamp];
else
    basePrefix = regexprep(strtrim(char(string(runName))), ...
        '[^A-Za-z0-9_-]+', '_');
    basePrefix = regexprep(basePrefix, '^_+|_+$', '');
    if isempty(basePrefix)
        error('scripted:RunName', ...
            'run_name must contain at least one letter or number.')
    end
end

prefix = basePrefix;
if isfile(fullfile(resultsDir, sprintf('%s_Nom_.mat', prefix))) || ...
        isfile(fullfile(resultsDir, sprintf('%s_results.mat', prefix)))
    prefix = sprintf('%s_%s', basePrefix, timestamp);
end
end
