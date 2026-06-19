projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\main';
repoFolder = fileparts(projectFolder);
outputFolder = fullfile(repoFolder, '.codex', 'verification', 'fixed_baseline_compare');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder)
end

baselineFile = fullfile(repoFolder, '.codex', 'verification', 'file_log_move_test', 'baseline_pre_move.mat');
currentSavedFile = fullfile(projectFolder, 'saved_results', '20260601', '20260601_1146_config.mat');
currentFile = fullfile(outputFolder, 'current_20260601_1146_config.mat');
copyfile(currentSavedFile, currentFile)

baseline = load(baselineFile);
current = load(currentFile);

baselineMetrics = getMetrics(baseline);
currentMetrics = getMetrics(current);
metricNames = {'duration_s'; 'sample_count'; 'fs_hz'; 'dt_s'; 'rms_dd_minus_dm_mm'};
baselineValues = [baselineMetrics.duration; baselineMetrics.sampleCount; baselineMetrics.fs; baselineMetrics.dt; baselineMetrics.rmsError];
currentValues = [currentMetrics.duration; currentMetrics.sampleCount; currentMetrics.fs; currentMetrics.dt; currentMetrics.rmsError];
differences = currentValues - baselineValues;

n = min([numel(baseline.dd), numel(current.dd), numel(baseline.dm), numel(current.dm), numel(baseline.fm), numel(current.fm)]);
signalMetricNames = {'rms_current_minus_baseline_dd_mm'; 'rms_current_minus_baseline_dm_mm'; 'rms_current_minus_baseline_fm_N'};
signalMetricValues = [
    sqrt(mean((current.dd(1:n) - baseline.dd(1:n)).^2, 'omitnan'));
    sqrt(mean((current.dm(1:n) - baseline.dm(1:n)).^2, 'omitnan'));
    sqrt(mean((current.fm(1:n) - baseline.fm(1:n)).^2, 'omitnan'))];

save(fullfile(outputFolder, 'comparison_metrics.mat'), ...
    'baselineFile', 'currentSavedFile', 'currentFile', ...
    'metricNames', 'baselineValues', 'currentValues', 'differences', ...
    'signalMetricNames', 'signalMetricValues')

fid = fopen(fullfile(outputFolder, 'comparison_metrics.txt'), 'w');
fprintf(fid, 'fixed_baseline_file: %s\n', baselineFile);
fprintf(fid, 'current_saved_file: %s\n', currentSavedFile);
fprintf(fid, 'current_artifact_file: %s\n\n', currentFile);
fprintf(fid, 'metric,baseline,current,difference\n');
for k = 1:numel(metricNames)
    fprintf(fid, '%s,%.12g,%.12g,%.12g\n', metricNames{k}, baselineValues(k), currentValues(k), differences(k));
end
fprintf(fid, '\nsignal_metric,value\n');
for k = 1:numel(signalMetricNames)
    fprintf(fid, '%s,%.12g\n', signalMetricNames{k}, signalMetricValues(k));
end
fclose(fid);

colors.green = hexToRgb('39BF5E');
colors.black = [0 0 0];
colors.blue = hexToRgb('007CA8');
colors.red = hexToRgb('901500');
colors.purple = hexToRgb('74058A');
colors.copperwood = hexToRgb('AC6420');

plotSingleRun(current, colors, 'Current run: 20260601_1146_config.mat')
print(gcf, fullfile(outputFolder, 'current_20260601_1146_config.png'), '-dpng', '-r150')

plotBaselineComparison(baseline, current, colors)
print(gcf, fullfile(outputFolder, 'baseline_vs_current_20260601_1146_config.png'), '-dpng', '-r150')

fprintf('Fixed-baseline comparison complete.\n')
fprintf('Current saved file: %s\n', currentSavedFile)
fprintf('Current artifact file: %s\n', currentFile)
fprintf('Duration: %.3f s\n', currentMetrics.duration)
fprintf('Sample count: %d\n', currentMetrics.sampleCount)
fprintf('fs: %.6g Hz\n', currentMetrics.fs)
fprintf('dt: %.6g s\n', currentMetrics.dt)
fprintf('RMS(dd - dm): %.6g mm\n', currentMetrics.rmsError)
fprintf('Delta RMS(dd - dm): %.12g mm\n', differences(5))

function metrics = getMetrics(data)
t = data.t(:);
dd = data.dd(:);
dm = data.dm(:);
n = min([numel(t), numel(dd), numel(dm)]);
t = t(1:n);
dd = dd(1:n);
dm = dm(1:n);
metrics.duration = t(end) - t(1);
metrics.sampleCount = n;
metrics.fs = data.fs;
metrics.dt = data.dt;
metrics.rmsError = sqrt(mean((dd - dm).^2, 'omitnan'));
end

function plotSingleRun(data, colors, figureName)
t = data.t(:);
dd = data.dd(:);
dc = data.dc(:);
dm = data.dm(:);
fm = data.fm(:);
n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm)]);
t = t(1:n);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);
figure('Name', figureName, 'Visible', 'off', 'Position', [100 100 1400 850]);
subplot(2, 1, 1)
hDesired = plot(t, dd, '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'dd desired displacement'); hold on
plot(t, dc, '-', 'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'dc command displacement');
plot(t, dm, '-', 'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'dm measured displacement');
uistack(hDesired, 'top')
grid on
xlabel('Time (s)')
ylabel('Displacement (mm)')
title('Displacement Tracking')
legend('Location', 'best')
subplot(2, 1, 2)
plot(t, fm, '-', 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'fm measured force');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
legend('Location', 'best')
end

function plotBaselineComparison(baseline, current, colors)
n = min([numel(baseline.t), numel(current.t), numel(baseline.dd), numel(current.dd), numel(baseline.dm), numel(current.dm), numel(baseline.fm), numel(current.fm)]);
t = current.t(1:n);
figure('Name', 'Fixed baseline vs current run', 'Visible', 'off', 'Position', [100 100 1400 900]);
subplot(3, 1, 1)
plot(t, baseline.dd(1:n), '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'baseline dd'); hold on
plot(t, current.dd(1:n), '-', 'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'current dd')
grid on
ylabel('Desired disp. (mm)')
title('Fixed Baseline vs Current')
legend('Location', 'best')
subplot(3, 1, 2)
plot(t, baseline.dm(1:n), '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'baseline dm'); hold on
plot(t, current.dm(1:n), '-', 'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'current dm')
grid on
ylabel('Measured disp. (mm)')
legend('Location', 'best')
subplot(3, 1, 3)
plot(t, baseline.fm(1:n), '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'baseline fm'); hold on
plot(t, current.fm(1:n), '-', 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'current fm')
grid on
xlabel('Time (s)')
ylabel('Force (N)')
legend('Location', 'best')
end

function rgb = hexToRgb(hexColor)
rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end
