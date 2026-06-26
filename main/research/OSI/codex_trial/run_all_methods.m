%% Run All Online Stability Indicator Trials
if ~exist('rerunTrials', 'var')
    rerunTrials = true;
end
clearvars -except rerunTrials
clc
close all

codexTrialDir = fileparts(mfilename('fullpath'));
projectDir = fileparts(fileparts(fileparts(codexTrialDir)));

testFile = fullfile(projectDir, 'saved_results', 'tests', 'important', ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');
timeRange = [620 770.1];

trialNames = { ...
    'Raw single-window H1 FRF'; ...
    'Smoothed Welch H1 FRF'; ...
    'Smoothed Welch H2 FRF'; ...
    'Stable per-window tfest'; ...
    'Smoothed nominal correction'; ...
    'FRF state filter + smoothed margin'};

trialCount = numel(trialNames);

if rerunTrials
    for trialNumber = 1:trialCount
        trialScript = fullfile(codexTrialDir, sprintf('trial_%d', trialNumber), ...
            sprintf('run_trial_%d.m', trialNumber));
        run_trial_script(trialScript)
    end
end

data = load(testFile, 't', 'dd', 'dm');
plotIdx = data.t >= timeRange(1) & data.t <= timeRange(2);
plotSamples = find(plotIdx);
plotStride = max(1, floor(numel(plotSamples)/5000));
plotSamples = plotSamples(1:plotStride:end);
trialResults = cell(trialCount, 1);
for trialNumber = 1:trialCount
    resultFile = fullfile(codexTrialDir, sprintf('trial_%d', trialNumber), ...
        sprintf('trial_%d_results.csv', trialNumber));
    trialResults{trialNumber} = readtable(resultFile);
end

fig = figure('Color', 'w', 'Name', 'Online NCF Indicator Trials');
layout = tiledlayout(fig, 4, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, 'Online Stability Indicator Trial Comparison: 0.5 s Updates')

ax = nexttile(layout, 1);
hide_axes_toolbar(ax)
plot(ax, data.t(plotSamples), data.dd(plotSamples), 'k--', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'dd')
hold(ax, 'on')
plot(ax, data.t(plotSamples), data.dm(plotSamples), '-', ...
    'LineWidth', 1.0, ...
    'Color', [0 0.486 0.659], 'DisplayName', 'dm')
grid(ax, 'on')
xlim(ax, timeRange)
xlabel(ax, 'Time (s)')
ylabel(ax, 'Displacement')
title(ax, 'dd and dm response')
legend(ax, 'Location', 'best')

for trialNumber = 1:trialCount
    ax = nexttile(layout, trialNumber + 1);
    hide_axes_toolbar(ax)
    results = trialResults{trialNumber};
    plot(ax, results.Time_s, results.NCFMargin, '-', ...
        'LineWidth', 1.1, ...
        'Color', [0 0.486 0.659], ...
        'DisplayName', 'Estimated NCF')
    hold(ax, 'on')
    if ismember('BaselineNCF', results.Properties.VariableNames)
        yline(ax, results.BaselineNCF(1), 'k--', 'LineWidth', 1.0, ...
            'DisplayName', 'Nominal baseline')
    end
    grid(ax, 'on')
    xlim(ax, timeRange)
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'NCF margin')
    title(ax, sprintf('Trial %d: %s', trialNumber, trialNames{trialNumber}))
    legend(ax, 'Location', 'best')
end

ax = nexttile(layout, trialCount + 2);
hide_axes_toolbar(ax)
colors = lines(trialCount);
overlayTrials = [2 3 5 6];
for trialNumber = overlayTrials
    results = trialResults{trialNumber};
    plot(ax, results.Time_s, results.NCFMargin, '-', ...
        'LineWidth', 1.4, 'Color', colors(trialNumber, :), ...
        'DisplayName', sprintf('Trial %d', trialNumber))
    hold(ax, 'on')
end
if ismember('BaselineNCF', trialResults{1}.Properties.VariableNames)
    yline(ax, trialResults{1}.BaselineNCF(1), 'k--', 'LineWidth', 1.0, ...
        'DisplayName', 'Nominal baseline')
end
grid(ax, 'on')
xlim(ax, timeRange)
xlabel(ax, 'Time (s)')
ylabel(ax, 'NCF margin')
title(ax, 'Informative smoothed indicators')
legend(ax, 'Location', 'best')

exportgraphics(fig, fullfile(codexTrialDir, 'all_methods_summary.png'), ...
    'Resolution', 180)

function run_trial_script(scriptPath)
scriptDir = fileparts(scriptPath);
cd(scriptDir)
edit(scriptPath)
drawnow
run(scriptPath)
end

function hide_axes_toolbar(ax)
try
    ax.Toolbar.Visible = 'off';
catch
end
try
    disableDefaultInteractivity(ax)
catch
end
end
