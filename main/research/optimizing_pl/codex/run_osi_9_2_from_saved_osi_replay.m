function result = run_osi_9_2_from_saved_osi_replay()
%RUN_OSI_9_2_FROM_SAVED_OSI_REPLAY Apply Method 9.2 to saved OSI traces.
% This is the fast research path for trialing the simplified authority law:
% auth_factor = clamp(OSI / target_ncf, 0, 1).

scriptFolder = fileparts(mfilename('fullpath'));
sourceFile = fullfile(scriptFolder, 'osi_auth_factor_tests', ...
    'osi_auth_factor_test_result.mat');
assert(isfile(sourceFile), 'Missing source OSI replay: %s', sourceFile)

loaded = load(sourceFile);
source = loaded.result;
outputFolder = fullfile(scriptFolder, 'osi_9_2_auth_factor_tests');
figureFolder = fullfile(outputFolder, 'figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

caseResult = source.cases;
for i = 1:numel(caseResult)
    replay = caseResult(i).replay;
    if isfield(replay, 'setup') && isfield(replay.setup, 'target_outer_ncf')
        targetNcf = replay.setup.target_outer_ncf;
    else
        error('Case %s is missing a required target NCF.', caseResult(i).name)
    end

    replay.target_ncf = targetNcf;
    replay.law = 'auth_factor = clamp(OSI / target_ncf, 0, 1)';
    replay.auth_factor = osi_method_9_2_auth_factor( ...
        replay.ncf_selected, targetNcf);
    replay.ncf_filtered = [];
    caseResult(i).replay = replay;
    [caseResult(i).figure, caseResult(i).png] = localPlotCase( ...
        caseResult(i), figureFolder);
end

summary = localSummary(caseResult);
createdText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
result = struct('summary', summary, ...
    'cases', caseResult, ...
    'method', '9.2 direct OSI/target authority from saved OSI replay', ...
    'source_file', sourceFile, ...
    'output_folder', outputFolder, ...
    'figure_folder', figureFolder, ...
    'created', createdText);

resultFile = fullfile(outputFolder, 'osi_9_2_auth_factor_test_result.mat');
save(resultFile, 'result', '-v7.3')
reportFile = fullfile(outputFolder, 'osi_9_2_auth_factor_test_report.md');
localWriteMarkdown(reportFile, result, resultFile)
htmlFile = fullfile(outputFolder, 'osi_9_2_auth_factor_test_report.html');
localWriteHtml(htmlFile, result)

disp(summary)
fprintf('\nSaved %s\n', resultFile)
fprintf('Saved %s\n', reportFile)
fprintf('Saved %s\n', htmlFile)
fprintf('Saved figures under %s\n', figureFolder)
end

function [figPath, pngPath] = localPlotCase(caseItem, figureFolder)
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;
r = caseItem.replay;

safeName = regexprep(caseItem.name, '[^\w-]', '_');
figPath = fullfile(figureFolder, [safeName '.fig']);
pngPath = fullfile(figureFolder, [safeName '.png']);

fig = figure('Name', ['M9.2 ' caseItem.name], 'Color', 'w', ...
    'Visible', 'on', 'Position', [100 100 1100 720]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

[tp, selected] = localThin(r.tc, r.ncf_selected);
[~, ncfSt] = localThin(r.tc, r.ncf_st);
[~, ncfResidual] = localThin(r.tc, r.ncf_residual);
[~, authFactor] = localThin(r.tc, r.auth_factor);

nexttile
plot(tp, selected, '-', 'Color', [0 0 0], 'LineWidth', 1.2)
hold on
yline(r.target_ncf, ':', 'target NCF', 'Color', [0.35 0.35 0.35], ...
    'Interpreter', 'none');
grid on
ylabel('Selected OSI', 'Interpreter', 'none')
title(sprintf('M9.2 %s, auth=clamp(OSI/%.2f)', ...
    caseItem.name, r.target_ncf), 'Interpreter', 'none')

nexttile
yyaxis left
hSt = plot(tp, ncfSt, '--', 'Color', green, 'LineWidth', 1);
hold on
hResidual = plot(tp, ncfResidual, '--', 'Color', red, ...
    'LineWidth', 1);
hSelected = plot(tp, selected, '-', 'Color', [0 0 0], ...
    'LineWidth', 1.5);
ylabel('OSI', 'Interpreter', 'none')
grid on

yyaxis right
hAuth = plot(tp, authFactor, '-', 'Color', copper, ...
    'LineWidth', 1.25);
ylabel('auth_factor', 'Interpreter', 'none')
ylim([0 1.05])
xlabel('Time (s)')

if any(r.paused)
    pauseIdx = find(r.paused);
    xline(r.tc(pauseIdx(1)), ':', 'pause interval', ...
        'Color', [0.35 0.35 0.35], 'HandleVisibility', 'off', ...
        'Interpreter', 'none');
end

legend([hSt hResidual hSelected hAuth], ...
    {'OSI S/T branch', 'OSI residual branch', 'OSI selected', ...
    'auth_factor = OSI / target'}, 'Location', 'best', ...
    'Interpreter', 'none')

savefig(fig, figPath)
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, pngPath, 'Resolution', 150)
else
    print(fig, pngPath, '-dpng', '-r150')
end
drawnow
end

function [tx, yx] = localThin(t, y)
n = numel(t);
targetN = 4500;
step = max(1, ceil(n/targetN));
idx = unique([1:step:n, n]);
tx = t(idx);
yx = y(idx);
end

function summary = localSummary(caseResult)
n = numel(caseResult);
caseNames = cell(n, 1);
windows = zeros(n, 1);
pausedWindows = zeros(n, 1);
minOsi = NaN(n, 1);
meanOsi = NaN(n, 1);
minAuth = NaN(n, 1);
meanAuth = NaN(n, 1);
finalAuth = NaN(n, 1);
for i = 1:n
    caseNames{i} = caseResult(i).name;
    r = caseResult(i).replay;
    windows(i) = numel(r.tc);
    pausedWindows(i) = nnz(r.paused);
    minOsi(i) = min(r.ncf_selected, [], 'omitnan');
    meanOsi(i) = mean(r.ncf_selected, 'omitnan');
    minAuth(i) = min(r.auth_factor, [], 'omitnan');
    meanAuth(i) = mean(r.auth_factor, 'omitnan');
    finalAuth(i) = r.auth_factor(find(isfinite(r.auth_factor), 1, 'last'));
end
summary = table(caseNames, windows, pausedWindows, minOsi, meanOsi, ...
    minAuth, meanAuth, finalAuth, 'VariableNames', {'Case', ...
    'Windows', 'PausedWindows', 'MinOSI', 'MeanOSI', ...
    'MinAuthFactor', 'MeanAuthFactor', 'FinalAuthFactor'});
end

function localWriteMarkdown(reportFile, result, resultFile)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
[~, resultName, resultExt] = fileparts(resultFile);

fprintf(fid, '# OSI Method 9.2 direct authority test\n\n');
fprintf(fid, 'Generated by `run_osi_9_2_from_saved_osi_replay.m`.\n\n');
fprintf(fid, 'Trial law: `auth_factor = clamp(OSI / target_ncf, 0, 1)`.\n\n');
fprintf(fid, 'The target NCF is required. No fallback target, guarded margin, confirmation counter, low/high split, or slow recovery is used.\n\n');
fprintf(fid, 'Source OSI replay: `%s`.\n\n', result.source_file);
fprintf(fid, 'Result MAT: `%s%s`\n\n', resultName, resultExt);
fprintf(fid, '## Summary\n\n');
fprintf(fid, '| Case | Windows | Paused windows | Min OSI | Mean OSI | Min auth_factor | Mean auth_factor | Final auth_factor |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(result.summary)
    fprintf(fid, '| %s | %d | %d | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        result.summary.Case{i}, result.summary.Windows(i), ...
        result.summary.PausedWindows(i), result.summary.MinOSI(i), ...
        result.summary.MeanOSI(i), result.summary.MinAuthFactor(i), ...
        result.summary.MeanAuthFactor(i), ...
        result.summary.FinalAuthFactor(i));
end
end

function localWriteHtml(htmlFile, result)
fid = fopen(htmlFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '<!doctype html>\n<html lang="en">\n<head>\n');
fprintf(fid, '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n');
fprintf(fid, '<title>OSI Method 9.2 Auth Factor Tests</title>\n');
fprintf(fid, '<style>body{margin:0;background:#f5f6f7;color:#202124;font:15px/1.45 "Segoe UI",Arial,sans-serif}main{max-width:1180px;margin:0 auto;padding:28px 22px 42px}header{border-bottom:1px solid #d7d9dc;margin-bottom:22px;padding-bottom:18px}h1{font-size:28px;line-height:1.15;margin:0 0 8px;letter-spacing:0}h2{font-size:18px;margin:28px 0 12px;letter-spacing:0}h3{font-size:16px;margin:0 0 10px;letter-spacing:0}p{margin:0 0 10px;color:#5f6368}code{font-family:Consolas,"Cascadia Mono",monospace;font-size:.94em}.meta{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-top:16px}.metric{background:#fff;border:1px solid #d7d9dc;border-radius:4px;padding:11px 12px}.metric span{display:block;color:#5f6368;font-size:12px;margin-bottom:3px}.metric strong{font-size:18px;font-weight:650}.table-wrap{overflow-x:auto;background:#fff;border:1px solid #d7d9dc;border-radius:4px}table{width:100%%;border-collapse:collapse;min-width:920px}th,td{border-bottom:1px solid #e6e7e9;padding:8px 10px;text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{background:#eceef0;color:#3f4348;font-size:12px;font-weight:650}tr:last-child td{border-bottom:0}.plots{display:grid;grid-template-columns:1fr;gap:18px}.plot{background:#fff;border:1px solid #d7d9dc;border-radius:4px;padding:14px}.plot-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:10px}.plot a{color:#007ca8;font-weight:600;text-decoration:none}.plot a:hover{text-decoration:underline}img{display:block;width:100%%;height:auto;border:1px solid #e1e3e5;background:#fff}@media(max-width:760px){main{padding:20px 14px 32px}.meta{grid-template-columns:1fr}.plot-head{display:block}}</style>\n');
fprintf(fid, '</head>\n<body>\n<main>\n<header>\n');
fprintf(fid, '<h1>OSI Method 9.2 Auth-Factor Trial</h1>\n');
fprintf(fid, '<p>Research-only simplified trial. Authority is calculated directly from selected OSI as <code>auth_factor = clamp(OSI / target_ncf, 0, 1)</code>. No fallback target or recovery logic is used.</p>\n');
fprintf(fid, '<div class="meta"><div class="metric"><span>Cases</span><strong>%d</strong></div><div class="metric"><span>Method</span><strong>9.2 direct</strong></div><div class="metric"><span>Generated</span><strong>%s</strong></div></div>\n', ...
    numel(result.cases), result.created);
fprintf(fid, '</header>\n<section>\n<h2>Summary</h2>\n<div class="table-wrap">\n<table>\n<thead><tr><th>Case</th><th>Windows</th><th>Paused</th><th>Min OSI</th><th>Mean OSI</th><th>Min auth</th><th>Mean auth</th><th>Final auth</th></tr></thead>\n<tbody>\n');
for i = 1:height(result.summary)
    fprintf(fid, '<tr><td>%s</td><td>%d</td><td>%d</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.4f</td></tr>\n', ...
        result.summary.Case{i}, result.summary.Windows(i), ...
        result.summary.PausedWindows(i), result.summary.MinOSI(i), ...
        result.summary.MeanOSI(i), result.summary.MinAuthFactor(i), ...
        result.summary.MeanAuthFactor(i), ...
        result.summary.FinalAuthFactor(i));
end
fprintf(fid, '</tbody>\n</table>\n</div>\n</section>\n<section>\n<h2>Plots</h2>\n<div class="plots">\n');
for i = 1:numel(result.cases)
    [~, pngName, pngExt] = fileparts(result.cases(i).png);
    fprintf(fid, '<article class="plot"><div class="plot-head"><h3>%s</h3><span>PNG export</span></div><img src="figures/%s%s" alt="%s Method 9.2 plot"></article>\n', ...
        result.cases(i).name, pngName, pngExt, ...
        result.cases(i).name);
end
fprintf(fid, '</div>\n</section>\n</main>\n</body>\n</html>\n');
end
