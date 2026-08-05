anfunction result = design_lqr_baseline
%DESIGN_LQR_BASELINE Tune one 7k LQR gain and evaluate it on both plants.

models = build_lqr_state_space_models;
system7k = models.system_7k;
system5k = models.system_5k;
frequencyScale = models.frequency_scale_rad_per_second;
optimizationTime = linspace(0, 0.25, 5001).';
options = optimset('Display', 'off', 'TolX', 1e-7);
optimalLogRatio = fminbnd(@(logRatio) lqrObjective(logRatio, ...
    system7k, frequencyScale, optimizationTime), 0, 3, options);
qy = 10^optimalLogRatio;
ru = 1;
[K, ~, closedLoopPoles7k] = lqr(system7k.A, system7k.B, ...
    qy*(system7k.C.'*system7k.C), ru);
nbar = -1/(system7k.C*((system7k.A - system7k.B*K) \ ...
    system7k.B));

closedLoop7k = ss(frequencyScale*(system7k.A - system7k.B*K), ...
    frequencyScale*system7k.B*nbar, system7k.C, 0);
closedLoop5k = ss(frequencyScale*(system5k.A - system5k.B*K), ...
    frequencyScale*system5k.B*nbar, system5k.C, 0);
metrics7k = responseMetrics(closedLoop7k, system7k, K, nbar, ...
    frequencyScale);
metrics5k = responseMetrics(closedLoop5k, system5k, K, nbar, ...
    frequencyScale);

gainLog10Ratio = linspace(-12, 12, 481).';
gainTable = zeros(numel(gainLog10Ratio), numel(K));
for i = 1:numel(gainLog10Ratio)
    gainTable(i, :) = lqr(system7k.A, system7k.B, ...
        10^gainLog10Ratio(i)*(system7k.C.'*system7k.C), 1);
end

result = struct;
result.qy = qy;
result.ru = ru;
result.qy_over_ru = qy/ru;
result.K = K;
result.nbar = nbar;
result.closed_loop_poles_7k = closedLoopPoles7k;
result.closed_loop_poles_5k = eig(system5k.A - system5k.B*K);
result.metrics_7k = metrics7k;
result.metrics_5k = metrics5k;
result.models = models;
result.gain_log10_ratio = gainLog10Ratio;
result.gain_table = gainTable;

assets = lqg_assets;
outputFile = fullfile(assets.results, 'lqr_baseline_design.mat');
save(outputFile, 'result')

browserData = struct( ...
    'frequencyScaleRadPerSecond', frequencyScale, ...
    'optimized', struct('qy', qy, 'ru', ru, 'K', K, 'nbar', nbar, ...
        'metrics7k', metrics7k, 'metrics5k', metrics5k), ...
    'gainLog10Ratio', gainLog10Ratio, ...
    'gainTable', gainTable, ...
    'systems', [browserSystem('7k', system7k), ...
        browserSystem('5k', system5k)]);
browserFile = fullfile(fileparts(mfilename('fullpath')), ...
    'lqg_lqr_data.js');
fileId = fopen(browserFile, 'w');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'window.lqgLqrData = %s;\n', jsonencode(browserData));

fprintf('Optimized 7k qy = %.9g, ru = %.9g\n', qy, ru)
fprintf('7k: overshoot %.6g%%, settling %.6g s, peak command %.6g\n', ...
    metrics7k.overshoot_percent, metrics7k.settling_time_s, ...
    metrics7k.peak_command)
fprintf('5k with identical K: stable %d, overshoot %.6g%%, settling %.6g s\n', ...
    metrics5k.stable, metrics5k.overshoot_percent, ...
    metrics5k.settling_time_s)
fprintf('Saved LQR design to %s\n', outputFile)
fprintf('Saved browser data to %s\n', browserFile)
end

function objective = lqrObjective(logRatio, system7k, frequencyScale, time)
    K = lqr(system7k.A, system7k.B, ...
        10^logRatio*(system7k.C.'*system7k.C), 1);
    Acl = system7k.A - system7k.B*K;
    nbar = -1/(system7k.C*(Acl \ system7k.B));
    response = step(ss(frequencyScale*Acl, ...
        frequencyScale*system7k.B*nbar, system7k.C, 0), time);
    overshoot = max(0, (max(response) - 1)*100);
    outside = abs(response - 1) > 0.02;
    lastOutside = find(outside, 1, 'last');
    if isempty(lastOutside)
        settlingTime = 0;
    elseif lastOutside < numel(time)
        settlingTime = time(lastOutside + 1);
    else
        settlingTime = time(end);
    end
    objective = overshoot + 0.01*settlingTime;
end

function metrics = responseMetrics(closedLoop, system, K, nbar, frequencyScale)
    time = linspace(0, 3, 6001).';
    response = step(closedLoop, time);
    finalValue = dcgain(closedLoop);
    overshoot = max(0, (max(response) - finalValue) / ...
        max(abs(finalValue), eps)*100);
    outside = abs(response - finalValue) > 0.02*max(abs(finalValue), eps);
    lastOutside = find(outside, 1, 'last');
    if isempty(lastOutside)
        settlingTime = 0;
    elseif lastOutside < numel(time)
        settlingTime = time(lastOutside + 1);
    else
        settlingTime = Inf;
    end
    commandSystem = ss(frequencyScale*(system.A - system.B*K), ...
        frequencyScale*system.B*nbar, -K, nbar);
    command = step(commandSystem, time);
    metrics = struct( ...
        'stable', isstable(closedLoop), ...
        'final_value', finalValue, ...
        'overshoot_percent', overshoot, ...
        'settling_time_s', settlingTime, ...
        'peak_command', max(abs(command)));
end

function output = browserSystem(id, system)
    output = struct('id', id, 'A', system.A, 'B', system.B, ...
        'C', system.C, 'D', system.D);
end
