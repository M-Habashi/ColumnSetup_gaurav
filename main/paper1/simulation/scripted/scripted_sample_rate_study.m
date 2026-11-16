% SCRIPTED_SAMPLE_RATE_STUDY Compare scripted and Simulink runs by fs.

clearvars;
close all;

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);
addpath(fullfile(projectRoot, 'helper'));

rates = [4096 2048 1024];
studyDir = fullfile(projectRoot, 'Results', 'sample_rate_study');
if ~isfolder(studyDir)
    mkdir(studyDir);
end

originalFolder = pwd;
folderCleanup = onCleanup(@() cd(originalFolder));
cd(projectRoot);

runs = repmat(struct('fs', [], 'scripted', struct, ...
    'simulink', struct), 1, numel(rates));
controllerRows = zeros(numel(rates), 10);

for rateIndex = 1:numel(rates)
    fs = rates(rateIndex);
    dt_rths = 1 / fs;
    fprintf('\n=====================================================\n');
    fprintf('Sample-rate study: %d Hz (dt = %.12g sec)\n', fs, dt_rths);
    fprintf('=====================================================\n');

    % Reproduce the nominal main-run setup in the base workspace used by
    % the Simulink model and by helper/sim_helper.m.
    Building_c = 1;
    plot_on = 'n';
    modified = 1;
    consider_damage = 0;
    b_th = 0.13;
    num_add = 0;
    enable_indicator_plot = 0;
    test_name = sprintf('rate_study_simulink_%d', fs);
    real_time = 'n';
    ii = 1;
    num_t = 1;

    rng('default');
    F1_input_file;
    F1_Modifications;
    F2_controller;

    simulink_file = 'vRTHS_2024';
    if ~bdIsLoaded(simulink_file)
        load_system(simulink_file);
    end
    set_param(simulink_file, 'FastRestart', 'off');
    set_param(simulink_file, 'SolverType', 'Fixed-step', ...
        'Solver', 'ode4', 'StartTime', '0', 'StopTime', 'tend', ...
        'FixedStep', 'dt_rths', 'SimulationMode', 'accelerator');

    sim(simulink_file);
    simulinkResult = struct;
    simulinkResult.t = t;
    simulinkResult.EQ_input = EQ_input;
    simulinkResult.X_m = X_m;
    simulinkResult.Num_resp = Num_resp;
    simulinkResult.Force_act = Force_act;
    simulinkResult.alpha = alpha;
    simulinkResult.indicator = indicator;
    simulinkResult.Ref_Resp = lsim(sys_r, simulinkResult.EQ_input, ...
        simulinkResult.t);
    simulinkResult.eval_crit = blk_evaluation(simulinkResult, dt_rths);

    options = struct('Building_c', 1, 'plot_on', 'n', 'modified', 1, ...
        'consider_damage', 0, 'alpha_min', 0.5, 'b_th', 0.13, 'num_add', 0, ...
        'enable_indicator_plot', 0, ...
        'test_name', sprintf('rate_study_scripted_%d', fs), 'fs', fs, ...
        'bw_a', 80, 'pm_a', 60, 'bw_b', 60, 'pm_b', 60, ...
        'bw_c', 40, 'pm_c', 60, ...
        'start_c', 'A', 'switch_on', 1);
    rng('default');
    params = scripted_build_trial(options, projectRoot, 1);
    scriptedResult = scripted_engine(params);
    scriptedResult.eval_crit = blk_evaluation(scriptedResult, ...
        params.dt_rths);

    [leadNumerator, leadDenominator] = ss2tf(params.Apred, params.Bpred, ...
        params.Cpred, params.Dpred);
    [piNumerator, piDenominator] = ss2tf(params.Acd, params.Bcd, ...
        params.Ccd, params.Dcd);
    controllerRows(rateIndex, :) = [fs, params.dt_rths, ...
        leadNumerator(1:2), leadDenominator(1:2), ...
        piNumerator(1:2), piDenominator(1:2)];

    simulinkPath = fullfile(studyDir, ...
        sprintf('simulink_%dHz.mat', fs));
    scriptedPath = fullfile(studyDir, ...
        sprintf('scripted_%dHz.mat', fs));
    save(simulinkPath, '-struct', 'simulinkResult');
    save(scriptedPath, '-struct', 'scriptedResult');

    runs(rateIndex).fs = fs;
    runs(rateIndex).scripted = scriptedResult;
    runs(rateIndex).simulink = simulinkResult;
end

if bdIsLoaded('vRTHS_2024')
    set_param('vRTHS_2024', 'FastRestart', 'off');
end

controllerCoefficients = array2table(controllerRows, 'VariableNames', ...
    {'FsHz', 'DtSec', 'LeadB0', 'LeadB1', 'LeadA0', 'LeadA1', ...
    'OriginalPiB0', 'OriginalPiB1', 'OriginalPiA0', 'OriginalPiA1'});
indicatorSchedule = table(rates(:), 1 ./ rates(:), 100 ./ rates(:), ...
    'VariableNames', {'FsHz', 'DtSec', 'IndicatorPeriodSec'});

rateRows = zeros(numel(rates), 17);
for rateIndex = 1:numel(rates)
    result = runs(rateIndex).scripted;
    forceCapacityIndex = find(abs(result.Force_act.Data) >= 8900, 1);
    displacementIndex = find(abs(result.X_m.Data) >= 0.1, 1);
    forceCapacityTime = NaN;
    displacementTime = NaN;
    if ~isempty(forceCapacityIndex)
        forceCapacityTime = result.t(forceCapacityIndex);
    end
    if ~isempty(displacementIndex)
        displacementTime = result.t(displacementIndex);
    end
    rateRows(rateIndex, :) = [rates(rateIndex), numel(result.t), ...
        result.t(end), max(abs(result.X_m.Data), [], 'all'), ...
        max(abs(result.Num_resp.Data(:, 1:3)), [], 'all'), ...
        max(abs(result.Force_act.Data), [], 'all'), forceCapacityTime, ...
        displacementTime, result.eval_crit];
end
rateOutcomes = array2table(rateRows, 'VariableNames', ...
    [{'FsHz', 'Samples', 'EndTimeSec', 'MaxAbsXm', 'MaxAbsNumDisp', ...
    'MaxAbsForce', 'ForceCapacityExceededAtSec', ...
    'XmExceededPointOneAtSec'}, cellstr(compose('J%d', 1:9))]);

disp('\nDiscrete controller coefficients:');
disp(controllerCoefficients);
disp('Indicator schedule:');
disp(indicatorSchedule);

report = scripted_compare_sample_rates(runs);
sameRateRows = zeros(numel(rates), 5);
for rateIndex = 1:numel(rates)
    signalErrors = report.same_rate(rateIndex).signal_errors;
    metricErrors = report.same_rate(rateIndex).j_metrics;
    relativeMetricErrors = metricErrors.RelativeDifferencePercent;
    sameRateRows(rateIndex, :) = [rates(rateIndex), ...
        max(signalErrors.NormalizedRmsPercent), ...
        max(signalErrors.NormalizedPeakPercent), ...
        max(metricErrors.AbsoluteDifference), ...
        max(relativeMetricErrors, [], 'omitnan')];
end
sameRateSummary = array2table(sameRateRows, 'VariableNames', ...
    {'FsHz', 'MaxSignalNormalizedRmsPercent', ...
    'MaxSignalNormalizedPeakPercent', 'MaxJAbsoluteDifference', ...
    'MaxJRelativeDifferencePercent'});

rateEffectMetricTables = cell(numel(report.rate_effect_scripted), 1);
for comparisonIndex = 1:numel(report.rate_effect_scripted)
    metricTable = report.rate_effect_scripted(comparisonIndex).j_metrics;
    metricTable.FsHz = repmat(rates(comparisonIndex + 1), height(metricTable), 1);
    rateEffectMetricTables{comparisonIndex} = movevars(metricTable, ...
        'FsHz', 'Before', 'Metric');
end
rateEffectMetrics = vertcat(rateEffectMetricTables{:});

save(fullfile(studyDir, 'sample_rate_report.mat'), 'report', ...
    'controllerCoefficients', 'indicatorSchedule', 'rateOutcomes', ...
    'sameRateSummary', 'rateEffectMetrics');
writetable(controllerCoefficients, ...
    fullfile(studyDir, 'controller_coefficients.csv'));
writetable(indicatorSchedule, ...
    fullfile(studyDir, 'indicator_schedule.csv'));
writetable(rateOutcomes, fullfile(studyDir, 'rate_outcomes.csv'));
writetable(sameRateSummary, ...
    fullfile(studyDir, 'same_rate_fidelity.csv'));
writetable(rateEffectMetrics, ...
    fullfile(studyDir, 'rate_effect_metrics.csv'));

disp(['Sample-rate study saved to ', studyDir]);
clear folderCleanup;
