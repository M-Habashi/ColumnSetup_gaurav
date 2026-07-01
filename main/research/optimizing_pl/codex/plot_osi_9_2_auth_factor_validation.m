function plotFiles = plot_osi_9_2_auth_factor_validation(resultFile)
%PLOT_OSI_9_2_AUTH_FACTOR_VALIDATION Generate 9.2 validation comparison plots.
% Loads the saved validation result and regenerates plot PNGs without
% rerunning the M9.1 replay.

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(scriptFolder)));
if nargin < 1 || isempty(resultFile)
    resultFile = fullfile(projectFolder, 'OSI_tests', ...
        'osi_9_2_auth_factor_validation', ...
        'osi_9_2_auth_factor_validation_result.mat');
end

loaded = load(resultFile);
assert(isfield(loaded, 'result'), 'Result MAT must contain result.')
result = loaded.result;

outputFolder = fileparts(resultFile);
figureFolder = fullfile(outputFolder, 'figures');
comparisonFolder = fullfile(outputFolder, 'comparison_plots');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end
if ~exist(comparisonFolder, 'dir')
    mkdir(comparisonFolder)
end

plotFiles = {};
plotFiles = [plotFiles; plotCaseSeries(result, figureFolder)];
plotFiles{end + 1, 1} = plotMethodSummary(result, comparisonFolder);
plotFiles{end + 1, 1} = plotCaseMetric(result, comparisonFolder, ...
    'TotalVariation', 'Total variation', 'total_variation_by_case.png');
plotFiles{end + 1, 1} = plotCaseMetric(result, comparisonFolder, ...
    'MaxAbsStep', 'Max abs step', 'max_step_by_case.png');
plotFiles{end + 1, 1} = plotCaseMetric(result, comparisonFolder, ...
    'MinAuthFactor', 'Min auth factor', 'min_auth_by_case.png');

fprintf('Generated %d validation comparison plot files under %s\n', ...
    numel(plotFiles), outputFolder)
end

function plotFiles = plotCaseSeries(result, figureFolder)
plotFiles = cell(numel(result.cases), 1);
colors = methodColors(result.methods);
osiColor = [0 0 0];
gray = [0.35 0.35 0.35];

for caseId = 1:numel(result.cases)
    caseItem = result.cases(caseId);
    r = caseItem.replay;
    safeName = regexprep(caseItem.name, '[^\w-]', '_');
    pngPath = fullfile(figureFolder, [safeName '.png']);

    fig = figure('Name', ['M9.2 validation ' caseItem.name], ...
        'Color', 'w', 'Visible', 'on', 'Position', [100 100 1120 720]);
    tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', ...
        'Padding', 'compact')

    replayIdx = thinIndex(numel(r.tc), 4500);
    tc = r.tc(replayIdx);
    selected = r.ncf_selected(replayIdx);
    auth = r.auth_factor(replayIdx, :);

    nexttile
    plot(tc, selected, '--', 'Color', osiColor, 'LineWidth', 1.5)
    hold on
    yline(r.target_ncf, ':', 'target NCF', 'Color', gray, ...
        'HandleVisibility', 'off', 'Interpreter', 'none');
    grid on
    ylabel('Selected OSI', 'Interpreter', 'none')
    title(caseItem.name, 'Interpreter', 'none')

    nexttile
    h = gobjects(numel(result.methods), 1);
    for methodId = 1:numel(result.methods)
        h(methodId) = plot(tc, auth(:, methodId), '-', ...
            'Color', colors(methodId, :), 'LineWidth', 1.25);
        hold on
    end
    grid on
    ylabel('auth_factor', 'Interpreter', 'none')
    xlabel('Time (s)', 'Interpreter', 'none')
    ylim([0 1.05])
    if any(r.paused)
        pauseTimes = pauseBounds(r.tc, r.paused);
        for i = 1:numel(pauseTimes)
            xline(pauseTimes(i), ':', 'Color', gray, ...
                'HandleVisibility', 'off');
        end
    end
    legend(h, {result.methods.label}, 'Location', 'best', ...
        'Interpreter', 'none')

    exportPng(fig, pngPath)
    drawnow
    plotFiles{caseId} = pngPath;
end
end

function pngPath = plotMethodSummary(result, comparisonFolder)
summary = result.method_summary;
colors = methodColors(result.methods);
pngPath = fullfile(comparisonFolder, 'method_summary.png');

fig = figure('Name', 'M9.2 method summary', 'Color', 'w', ...
    'Visible', 'on', 'Position', [100 100 1080 620]);
tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact')

nexttile
bar(summary.WorstMinAuthFactor, 'FaceColor', 'flat', 'CData', colors)
title('Worst min auth factor', 'Interpreter', 'none')
ylabel('auth_factor', 'Interpreter', 'none')
ylim([0 1])
grid on
set(gca, 'XTickLabel', summary.Method, 'XTickLabelRotation', 20, ...
    'TickLabelInterpreter', 'none')

nexttile
bar(summary.MeanMaxAbsStep, 'FaceColor', 'flat', 'CData', colors)
title('Mean max abs step', 'Interpreter', 'none')
ylabel('auth_factor/update', 'Interpreter', 'none')
grid on
set(gca, 'XTickLabel', summary.Method, 'XTickLabelRotation', 20, ...
    'TickLabelInterpreter', 'none')

nexttile
bar(summary.MeanTotalVariation, 'FaceColor', 'flat', 'CData', colors)
title('Mean total variation', 'Interpreter', 'none')
ylabel('sum |delta auth|', 'Interpreter', 'none')
grid on
set(gca, 'XTickLabel', summary.Method, 'XTickLabelRotation', 20, ...
    'TickLabelInterpreter', 'none')

exportPng(fig, pngPath)
drawnow
end

function pngPath = plotCaseMetric(result, comparisonFolder, metricName, ...
        yLabelText, fileName)
summary = result.summary;
methods = result.methods;
caseNames = unique(summary.Case, 'stable');
values = NaN(numel(caseNames), numel(methods));
for i = 1:numel(caseNames)
    for j = 1:numel(methods)
        mask = strcmp(summary.Case, caseNames{i}) ...
            & strcmp(summary.MethodId, methods(j).id);
        values(i, j) = summary.(metricName)(mask);
    end
end

pngPath = fullfile(comparisonFolder, fileName);
fig = figure('Name', ['M9.2 ' metricName], 'Color', 'w', ...
    'Visible', 'on', 'Position', [100 100 1220 620]);
b = bar(values, 'grouped');
colors = methodColors(methods);
for j = 1:numel(b)
    b(j).FaceColor = colors(j, :);
end
grid on
ylabel(yLabelText, 'Interpreter', 'none')
title(['Case comparison: ' yLabelText], 'Interpreter', 'none')
set(gca, 'XTick', 1:numel(caseNames), ...
    'XTickLabel', shortCaseNames(caseNames), ...
    'XTickLabelRotation', 25, 'TickLabelInterpreter', 'none')
legend({methods.label}, 'Location', 'best', 'Interpreter', 'none')

exportPng(fig, pngPath)
drawnow
end

function idx = thinIndex(n, targetN)
step = max(1, ceil(n/targetN));
idx = unique([1:step:n, n]);
end

function labels = shortCaseNames(caseNames)
labels = caseNames;
for i = 1:numel(labels)
    labels{i} = strrep(labels{i}, '20260617_', '');
    labels{i} = strrep(labels{i}, '_', ' ');
end
end

function bounds = pauseBounds(t, paused)
bounds = [];
startIdx = find(diff([false; paused]) == 1);
endIdx = find(diff([paused; false]) == -1);
for i = 1:numel(startIdx)
    bounds = [bounds; t(startIdx(i)); t(endIdx(i))]; %#ok<AGROW>
end
end

function colors = methodColors(methods)
colors = zeros(numel(methods), 3);
for i = 1:numel(methods)
    switch methods(i).id
        case 'm92_direct'
            colors(i, :) = [144 21 0]/255;
        case 'm92_slew'
            colors(i, :) = [172 100 32]/255;
        case 'm92_ema'
            colors(i, :) = [57 191 94]/255;
        otherwise
            colors(i, :) = [0 124 168]/255;
    end
end
end

function exportPng(fig, pngPath)
[folder, baseName] = fileparts(pngPath);
savefig(fig, fullfile(folder, [baseName '.fig']))
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, pngPath, 'Resolution', 150)
else
    print(fig, pngPath, '-dpng', '-r150')
end
end
