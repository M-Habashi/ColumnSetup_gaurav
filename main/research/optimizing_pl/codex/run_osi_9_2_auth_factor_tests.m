function result = run_osi_9_2_auth_factor_tests(caseNames)
%RUN_OSI_9_2_AUTH_FACTOR_TESTS Run simplified Method 9.2 authority tests.
% Method 9.2 keeps the current M9.1 OSI estimate, then maps authority as:
% auth_factor = clamp(OSI / target_ncf, 0, 1).

if nargin < 1 || isempty(caseNames)
    caseNames = 'all';
end

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(scriptFolder)));
addpath(scriptFolder)
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

outputFolder = fullfile(scriptFolder, 'osi_9_2_auth_factor_tests');
figureFolder = fullfile(outputFolder, 'figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

cases = localCases(projectFolder);
caseMask = localCaseMask(cases, caseNames);
caseResult = repmat(localEmptyCaseResult, 0, 1);
lastFile = '';
lastData = [];

for k = reshape(find(caseMask), 1, [])
    testCase = cases(k);
    if ~builtin('strcmp', lastFile, testCase.file)
        lastData = localLoadSavedResult(testCase.file);
        lastFile = testCase.file;
    end

    fprintf('\nRunning OSI 9.2 test case: %s\n', testCase.name)
    replay = localReplayMethod92(projectFolder, testCase, lastData);
    [figPath, pngPath] = localPlotCase(testCase, lastData, replay, ...
        figureFolder);

    item = localEmptyCaseResult;
    item.name = testCase.name;
    item.file = testCase.file;
    item.figure = figPath;
    item.png = pngPath;
    item.replay = replay;
    caseResult(end + 1) = item; %#ok<AGROW>
end

summary = localSummary(caseResult);
createdText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
result = struct('summary', summary, ...
    'cases', caseResult, ...
    'method', '9.2 direct OSI/target authority', ...
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

function cases = localCases(projectFolder)
recordFiles = { ...
    fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
        '20260617_1731_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
        '20260617_1749_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
        '20260630_1930_testing_OSI.mat')};
recordLabels = {'20260617_1731', '20260617_1749', '20260630_1930'};

scenarios = struct( ...
    'suffix', 'current_split_band', ...
    'st_branch_hz', [2 30], ...
    'residual_branch_hz', [40 80], ...
    'pause_windows_s', zeros(0, 2));

cases = repmat(localCaseTemplate('', '', scenarios(1)), 0, 1);
for i = 1:numel(recordFiles)
    for j = 1:numel(scenarios)
        cases(end + 1) = localCaseTemplate(recordFiles{i}, ...
            recordLabels{i}, scenarios(j)); %#ok<AGROW>
    end
end
end

function item = localCaseTemplate(filePath, recordLabel, scenario)
item = struct( ...
    'name', [recordLabel '_' scenario.suffix], ...
    'file', filePath, ...
    'recordLabel', recordLabel, ...
    'inputSignal', 'dd', ...
    'outputSignal', 'dm', ...
    'target_ncf', 0.3, ...
    'st_branch_hz', scenario.st_branch_hz, ...
    'residual_branch_hz', scenario.residual_branch_hz, ...
    'pause_windows_s', scenario.pause_windows_s);
end

function mask = localCaseMask(cases, caseNames)
knownNames = {cases.name};
if ischar(caseNames) || isstring(caseNames)
    requested = cellstr(caseNames);
elseif iscell(caseNames)
    requested = caseNames;
else
    error('caseNames must be ''all'', a case name, or a cell array.')
end

if any(builtin('strcmpi', requested, 'all'))
    mask = true(size(cases));
    return
end

mask = false(size(cases));
missing = {};
for i = 1:numel(requested)
    hit = builtin('strcmpi', knownNames, requested{i});
    if ~any(hit)
        missing{end + 1} = requested{i}; %#ok<AGROW>
    end
    mask = mask | hit;
end

if ~isempty(missing)
    error('Unknown OSI test case(s): %s. Known cases: %s', ...
        strjoin(missing, ', '), strjoin(knownNames, ', '))
end
end

function data = localLoadSavedResult(filePath)
assert(isfile(filePath), 'Saved result not found: %s', filePath)
loaded = load(filePath);
if isfield(loaded, 'result') && isstruct(loaded.result)
    data = loaded.result;
else
    data = loaded;
end

required = {'t', 'dd', 'dm', 'dt', 'fs'};
for i = 1:numel(required)
    assert(isfield(data, required{i}), ...
        'Saved result %s is missing field %s.', filePath, required{i})
end
end

function replay = localReplayMethod92(projectFolder, testCase, data)
t = data.t(:);
dd = data.(testCase.inputSignal)(:);
dm = data.(testCase.outputSignal)(:);
dt = data.dt;

hs = struct( ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', 'exp_tf', ...
        'tf_sp1_5000_20260627_233333.mat'), ...
    'osi_gain_initial', 1, ...
    'osi_gain_min', 0, ...
    'target_outer_ncf', testCase.target_ncf, ...
    'osi_branch_split_hz', [], ...
    'osi_st_branch_hz', testCase.st_branch_hz, ...
    'osi_residual_branch_hz', testCase.residual_branch_hz);
setup = prepare_osi_gain_runtime(projectFolder, dt, hs);
cfg = setup.m91_cfg;
state = m91_adaptive_margin('state', cfg);

nWindow = floor((min(numel(dd), numel(dm)) - cfg.window_n) ...
    /cfg.update_interval_n) + 1;
assert(nWindow > 0, 'Record is shorter than the OSI window.')

tc = NaN(nWindow, 1);
ncfSelected = NaN(nWindow, 1);
ncfSt = NaN(nWindow, 1);
ncfResidual = NaN(nWindow, 1);
authFactor = NaN(nWindow, 1);
paused = false(nWindow, 1);
lastMargin = cfg.nominal;
lastAuth = osi_method_9_2_auth_factor(lastMargin, testCase.target_ncf);

for k = 1:nWindow
    idx = (k - 1)*cfg.update_interval_n + (1:cfg.window_n);
    windowStart = t(idx(1));
    windowEnd = t(idx(end));
    tc(k) = windowEnd;

    if localWindowIntersectsPause(windowStart, windowEnd, ...
            testCase.pause_windows_s)
        paused(k) = true;
        ncfSelected(k) = lastMargin;
        authFactor(k) = lastAuth;
        continue
    end

    [margin, state, info] = m91_adaptive_margin(dd(idx), dm(idx), ...
        cfg, state);
    lastMargin = margin;
    lastAuth = osi_method_9_2_auth_factor(margin, testCase.target_ncf);
    ncfSelected(k) = margin;
    ncfSt(k) = info.ncf_st;
    ncfResidual(k) = info.ncf_residual;
    authFactor(k) = lastAuth;
end

replay = struct( ...
    'tc', tc, ...
    'ncf_st', ncfSt, ...
    'ncf_residual', ncfResidual, ...
    'ncf_selected', ncfSelected, ...
    'auth_factor', authFactor, ...
    'paused', paused, ...
    'cfg', cfg, ...
    'setup', setup, ...
    'target_ncf', testCase.target_ncf, ...
    'law', 'auth_factor = clamp(OSI / target_ncf, 0, 1)', ...
    'input_signal', testCase.inputSignal);
end

function tf = localWindowIntersectsPause(windowStart, windowEnd, pauses)
tf = false;
for i = 1:size(pauses, 1)
    tf = tf || (windowStart <= pauses(i, 2) && windowEnd >= pauses(i, 1));
end
end

function [figPath, pngPath] = localPlotCase(testCase, data, replay, ...
        figureFolder)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;

safeName = regexprep(testCase.name, '[^\w-]', '_');
figPath = fullfile(figureFolder, [safeName '.fig']);
pngPath = fullfile(figureFolder, [safeName '.png']);

fig = figure('Name', ['M9.2 ' testCase.name], 'Color', 'w', ...
    'Visible', 'on', 'Position', [100 100 1100 720]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

[tp, dmPlot] = localThin(data.t(:), data.dm(:));
[tcPlot, ncfSt] = localThin(replay.tc, replay.ncf_st);
[~, ncfResidual] = localThin(replay.tc, replay.ncf_residual);
[~, ncfSelected] = localThin(replay.tc, replay.ncf_selected);
[~, authFactor] = localThin(replay.tc, replay.auth_factor);

axDm = nexttile;
plot(tp, dmPlot, 'Color', blue, 'LineWidth', 1)
grid on
ylabel('dm (mm)', 'Interpreter', 'none')
title(sprintf('M9.2 %s, auth=clamp(OSI/%.2f), S/T %.0f-%.0f Hz, residual %.0f-%.0f Hz', ...
    testCase.name, testCase.target_ncf, testCase.st_branch_hz(1), ...
    testCase.st_branch_hz(2), testCase.residual_branch_hz(1), ...
    testCase.residual_branch_hz(2)), 'Interpreter', 'none')

axOsi = nexttile;
yyaxis left
hSt = plot(tcPlot, ncfSt, '--', 'Color', green, ...
    'LineWidth', 1);
hold on
hResidual = plot(tcPlot, ncfResidual, '--', 'Color', red, ...
    'LineWidth', 1);
hSelected = plot(tcPlot, ncfSelected, '-', 'Color', [0 0 0], ...
    'LineWidth', 1.5);
yline(testCase.target_ncf, ':', 'target NCF', 'Color', [0.25 0.25 0.25], ...
    'HandleVisibility', 'off', 'Interpreter', 'none');
ylabel('OSI', 'Interpreter', 'none')
grid on

yyaxis right
hAuth = plot(tcPlot, authFactor, '-', 'Color', copper, ...
    'LineWidth', 1.25);
ylabel('auth_factor', 'Interpreter', 'none')
ylim([0 1.05])
xlabel('Time (s)')
linkaxes([axDm axOsi], 'x')

if any(replay.paused)
    pauseTimes = unique(testCase.pause_windows_s(:));
    for i = 1:numel(pauseTimes)
        xline(pauseTimes(i), ':', 'Color', [0.35 0.35 0.35], ...
            'HandleVisibility', 'off');
    end
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
fprintf(fid, 'Generated by `run_osi_9_2_auth_factor_tests.m`.\n\n');
fprintf(fid, 'Trial law: `auth_factor = clamp(OSI / target_ncf, 0, 1)`.\n\n');
fprintf(fid, 'There is no low/high threshold split, no confirmation counter, no slow recovery, no guarded margin, and no fallback target. The target NCF is required and is `0.3` for these cases.\n\n');
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

fprintf(fid, '\n## Figures\n\n');
for i = 1:numel(result.cases)
    [~, pngName, pngExt] = fileparts(result.cases(i).png);
    fprintf(fid, '### %s\n\n', result.cases(i).name);
    fprintf(fid, '![%s](figures/%s%s)\n\n', result.cases(i).name, ...
        pngName, pngExt);
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
fprintf(fid, '<p>Research-only simplified trial. Authority is calculated directly from the selected OSI as <code>auth_factor = clamp(OSI / target_ncf, 0, 1)</code>. Target NCF is required and is <code>0.3</code> in this run.</p>\n');
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

function item = localEmptyCaseResult
item = struct('name', '', 'file', '', 'figure', '', 'png', '', ...
    'replay', []);
end
