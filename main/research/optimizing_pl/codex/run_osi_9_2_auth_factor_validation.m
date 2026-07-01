function result = run_osi_9_2_auth_factor_validation(caseNames)
%RUN_OSI_9_2_AUTH_FACTOR_VALIDATION Compare Method 9.2 update laws.
% Replays the OSI_tests case matrix and writes an HTML comparison report
% under OSI_tests.

if nargin < 1 || isempty(caseNames)
    caseNames = 'all';
end

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(scriptFolder)));
addpath(scriptFolder)
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

outputFolder = fullfile(projectFolder, 'OSI_tests', ...
    'osi_9_2_auth_factor_validation');
figureFolder = fullfile(outputFolder, 'figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

methods = localMethods;
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

    fprintf('\nRunning OSI 9.2 validation case: %s\n', testCase.name)
    replay = localReplayVariants(projectFolder, testCase, lastData, ...
        methods);
    [figPath, pngPath] = localPlotCase(testCase, lastData, replay, methods, ...
        figureFolder);

    item = localEmptyCaseResult;
    item.name = testCase.name;
    item.file = testCase.file;
    item.figure = figPath;
    item.png = pngPath;
    item.replay = replay;
    caseResult(end + 1) = item; %#ok<AGROW>
end

summary = localSummary(caseResult, methods);
methodSummary = localMethodSummary(summary, methods);
createdText = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
htmlFile = fullfile(outputFolder, 'osi_9_2_auth_factor_validation.html');
resultFile = fullfile(outputFolder, 'osi_9_2_auth_factor_validation_result.mat');
result = struct();
result.summary = summary;
result.method_summary = methodSummary;
result.cases = caseResult;
result.methods = methods;
result.recommended_method = 'm92_slew';
result.output_folder = outputFolder;
result.figure_folder = figureFolder;
result.html_file = htmlFile;
result.created = createdText;

save(resultFile, 'result', '-v7.3')
localWriteHtml(htmlFile, result, resultFile)

disp(methodSummary)
fprintf('\nSaved %s\n', resultFile)
fprintf('Saved %s\n', htmlFile)
fprintf('Saved figures under %s\n', figureFolder)
end

function methods = localMethods
methods = struct( ...
    'id', {'m92_direct', 'm92_slew', 'm92_ema'}, ...
    'label', {'9.2 direct', '9.2 median+slew', '9.2 EMA'}, ...
    'description', { ...
        'Memoryless clamp(OSI / target NCF).', ...
        'Median-of-3 OSI despike, fast bounded drops, slow gated recovery.', ...
        'Fast-down slow-up exponential smoothing.'});
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

function replay = localReplayVariants(projectFolder, testCase, data, methods)
t = data.t(:);
dd = data.(testCase.inputSignal)(:);
dm = data.(testCase.outputSignal)(:);
dt = data.dt;

hs = struct( ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', 'exp_tf', ...
        'tf_sp1_5000_20260627_233333.mat'), ...
    'osi_gain_initial', 1, ...
    'osi_gain_min', 0.05, ...
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

nMethod = numel(methods);
tc = NaN(nWindow, 1);
ncfSelected = NaN(nWindow, 1);
ncfSt = NaN(nWindow, 1);
ncfResidual = NaN(nWindow, 1);
authFactor = NaN(nWindow, nMethod);
paused = false(nWindow, 1);

params = struct('a_min', 0.05, ...
    'down_deadband', 0.005, ...
    'down_rate_per_s', 8.0, ...
    'up_deadband', 0.02, ...
    'up_rate_per_s', 0.15, ...
    'up_hold_s', 0.5, ...
    'valid_confirm_n', 5, ...
    'ema_alpha_down', 0.50, ...
    'ema_alpha_up', 0.05);

lastMargin = cfg.nominal;
authDirect = osi_method_9_2_auth_factor(lastMargin, testCase.target_ncf);
authSlew = min(1, max(params.a_min, authDirect));
authEma = authSlew;
slewBuffer = lastMargin*ones(3, 1);
slewHold = 0;
slewValid = params.valid_confirm_n;
emaValid = params.valid_confirm_n;

for k = 1:nWindow
    idx = (k - 1)*cfg.update_interval_n + (1:cfg.window_n);
    windowStart = t(idx(1));
    windowEnd = t(idx(end));
    tc(k) = windowEnd;

    if localWindowIntersectsPause(windowStart, windowEnd, ...
            testCase.pause_windows_s)
        paused(k) = true;
        ncfSelected(k) = lastMargin;
        authFactor(k, :) = [authDirect authSlew authEma];
        slewValid = 0;
        emaValid = 0;
        continue
    end

    [margin, state, info] = m91_adaptive_margin(dd(idx), dm(idx), ...
        cfg, state);
    lastMargin = margin;
    ncfSelected(k) = margin;
    ncfSt(k) = info.ncf_st;
    ncfResidual(k) = info.ncf_residual;

    authDirect = osi_method_9_2_auth_factor(margin, testCase.target_ncf);
    [authSlew, slewBuffer, slewHold, slewValid] = ...
        osi_method_9_2_auth_slew(margin, authSlew, slewBuffer, ...
        slewHold, slewValid, testCase.target_ncf, ...
        cfg.update_interval_actual_s, params.a_min, ...
        params.down_deadband, params.down_rate_per_s, ...
        params.up_deadband, params.up_rate_per_s, params.up_hold_s, ...
        params.valid_confirm_n);
    [authEma, emaValid] = osi_method_9_2_auth_ema(margin, authEma, ...
        emaValid, testCase.target_ncf, params.a_min, ...
        params.ema_alpha_down, params.ema_alpha_up, ...
        params.valid_confirm_n);
    authFactor(k, :) = [authDirect authSlew authEma];
end

replay = struct();
replay.tc = tc;
replay.ncf_st = ncfSt;
replay.ncf_residual = ncfResidual;
replay.ncf_selected = ncfSelected;
replay.auth_factor = authFactor;
replay.paused = paused;
replay.cfg = cfg;
replay.setup = setup;
replay.target_ncf = testCase.target_ncf;
replay.params = params;
replay.method_ids = {methods.id};
replay.method_labels = {methods.label};
replay.input_signal = testCase.inputSignal;
end

function tf = localWindowIntersectsPause(windowStart, windowEnd, pauses)
tf = false;
for i = 1:size(pauses, 1)
    tf = tf || (windowStart <= pauses(i, 2) && windowEnd >= pauses(i, 1));
end
end

function [figPath, pngPath] = localPlotCase(testCase, data, replay, methods, ...
        figureFolder)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;
black = [0 0 0];
gray = [0.35 0.35 0.35];

safeName = regexprep(testCase.name, '[^\w-]', '_');
figPath = fullfile(figureFolder, [safeName '.fig']);
pngPath = fullfile(figureFolder, [safeName '.png']);

fig = figure('Name', ['M9.2 validation ' testCase.name], ...
    'Color', 'w', 'Visible', 'on', 'Position', [100 100 1120 760]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

nData = numel(data.t);
dataStep = max(1, ceil(nData/4500));
dataIdx = unique([1:dataStep:nData, nData]);
tp = data.t(dataIdx);
dmPlot = data.dm(dataIdx);

nReplay = numel(replay.tc);
replayStep = max(1, ceil(nReplay/4500));
replayIdx = unique([1:replayStep:nReplay, nReplay]);
tcPlot = replay.tc(replayIdx);
selected = replay.ncf_selected(replayIdx);
authPlot = replay.auth_factor(replayIdx, :);

axDm = nexttile;
plot(tp, dmPlot, 'Color', blue, 'LineWidth', 1)
grid on
ylabel('dm (mm)', 'Interpreter', 'none')
title(sprintf('%s, S/T %.0f-%.0f Hz, residual %.0f-%.0f Hz', ...
    testCase.name, testCase.st_branch_hz(1), testCase.st_branch_hz(2), ...
    testCase.residual_branch_hz(1), testCase.residual_branch_hz(2)), ...
    'Interpreter', 'none')

axOsi = nexttile;
yyaxis left
hOsi = plot(tcPlot, selected, '--', 'Color', black, 'LineWidth', 1.5);
hold on
yline(testCase.target_ncf, ':', 'target NCF', 'Color', gray, ...
    'HandleVisibility', 'off', 'Interpreter', 'none');
ylabel('Selected OSI', 'Interpreter', 'none')
grid on

yyaxis right
hAuth = gobjects(numel(methods), 1);
colors = [red; copper; green];
for i = 1:numel(methods)
    hAuth(i) = plot(tcPlot, authPlot(:, i), '-', ...
        'Color', colors(i, :), 'LineWidth', 1.25);
    hold on
end
ylabel('auth_factor', 'Interpreter', 'none')
ylim([0 1.05])
xlabel('Time (s)')
linkaxes([axDm axOsi], 'x')

if any(replay.paused)
    pauseTimes = unique(testCase.pause_windows_s(:));
    for i = 1:numel(pauseTimes)
        xline(pauseTimes(i), ':', 'Color', gray, ...
            'HandleVisibility', 'off');
    end
end

legend([hOsi; hAuth], [{'OSI selected'}, {methods.label}], ...
    'Location', 'best', 'Interpreter', 'none')

savefig(fig, figPath)
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, pngPath, 'Resolution', 150)
else
    print(fig, pngPath, '-dpng', '-r150')
end
drawnow
end

function summary = localSummary(caseResult, methods)
nCase = numel(caseResult);
nMethod = numel(methods);
nRow = nCase*nMethod;
caseNames = cell(nRow, 1);
methodIds = cell(nRow, 1);
methodLabels = cell(nRow, 1);
windows = zeros(nRow, 1);
pausedWindows = zeros(nRow, 1);
minOsi = NaN(nRow, 1);
meanOsi = NaN(nRow, 1);
minAuth = NaN(nRow, 1);
meanAuth = NaN(nRow, 1);
finalAuth = NaN(nRow, 1);
maxStep = NaN(nRow, 1);
totalVariation = NaN(nRow, 1);
glitchCount = zeros(nRow, 1);
pauseStd = NaN(nRow, 1);
resumeMaxStep = NaN(nRow, 1);

row = 0;
for i = 1:nCase
    r = caseResult(i).replay;
    for j = 1:nMethod
        row = row + 1;
        auth = r.auth_factor(:, j);
        caseNames{row} = caseResult(i).name;
        methodIds{row} = methods(j).id;
        methodLabels{row} = methods(j).label;
        windows(row) = numel(r.tc);
        pausedWindows(row) = nnz(r.paused);
        minOsi(row) = min(r.ncf_selected, [], 'omitnan');
        meanOsi(row) = mean(r.ncf_selected, 'omitnan');
        minAuth(row) = min(auth, [], 'omitnan');
        meanAuth(row) = mean(auth, 'omitnan');
        finalAuth(row) = auth(find(isfinite(auth), 1, 'last'));
        [maxStep(row), totalVariation(row)] = localStepMetrics(auth);
        glitchCount(row) = localGlitchCount(auth, 0.08, 3);
        pauseStd(row) = localPauseStd(auth, r.paused);
        resumeMaxStep(row) = localResumeMaxStep(auth, r.paused, ...
            max(1, round(5/r.cfg.update_interval_actual_s)));
    end
end

summary = table(caseNames, methodIds, methodLabels, windows, ...
    pausedWindows, minOsi, meanOsi, minAuth, meanAuth, finalAuth, ...
    maxStep, totalVariation, glitchCount, pauseStd, resumeMaxStep, ...
    'VariableNames', {'Case', 'MethodId', 'Method', 'Windows', ...
    'PausedWindows', 'MinOSI', 'MeanOSI', 'MinAuthFactor', ...
    'MeanAuthFactor', 'FinalAuthFactor', 'MaxAbsStep', ...
    'TotalVariation', 'GlitchCount', 'PauseStd', 'ResumeMaxStep'});
end

function methodSummary = localMethodSummary(summary, methods)
nMethod = numel(methods);
methodIds = cell(nMethod, 1);
methodLabels = cell(nMethod, 1);
worstMinAuth = NaN(nMethod, 1);
meanAuth = NaN(nMethod, 1);
meanMaxStep = NaN(nMethod, 1);
meanTotalVariation = NaN(nMethod, 1);
totalGlitches = zeros(nMethod, 1);
maxPauseStd = NaN(nMethod, 1);
maxResumeStep = NaN(nMethod, 1);
for i = 1:nMethod
    mask = builtin('strcmp', summary.MethodId, methods(i).id);
    methodIds{i} = methods(i).id;
    methodLabels{i} = methods(i).label;
    worstMinAuth(i) = min(summary.MinAuthFactor(mask), [], 'omitnan');
    meanAuth(i) = mean(summary.MeanAuthFactor(mask), 'omitnan');
    meanMaxStep(i) = mean(summary.MaxAbsStep(mask), 'omitnan');
    meanTotalVariation(i) = mean(summary.TotalVariation(mask), 'omitnan');
    totalGlitches(i) = sum(summary.GlitchCount(mask));
    maxPauseStd(i) = max(summary.PauseStd(mask), [], 'omitnan');
    maxResumeStep(i) = max(summary.ResumeMaxStep(mask), [], 'omitnan');
end
methodSummary = table(methodIds, methodLabels, worstMinAuth, meanAuth, ...
    meanMaxStep, meanTotalVariation, totalGlitches, maxPauseStd, ...
    maxResumeStep, 'VariableNames', {'MethodId', 'Method', ...
    'WorstMinAuthFactor', 'MeanAuthFactor', 'MeanMaxAbsStep', ...
    'MeanTotalVariation', 'TotalGlitches', 'MaxPauseStd', ...
    'MaxResumeMaxStep'});
end

function [maxStep, totalVariation] = localStepMetrics(auth)
finiteAuth = auth(isfinite(auth));
if numel(finiteAuth) < 2
    maxStep = NaN;
    totalVariation = NaN;
    return
end
d = abs(diff(finiteAuth));
maxStep = max(d);
totalVariation = sum(d);
end

function n = localGlitchCount(auth, threshold, maxRunLength)
below = auth < threshold & isfinite(auth);
n = 0;
i = 1;
while i <= numel(below)
    if below(i)
        j = i;
        while j <= numel(below) && below(j)
            j = j + 1;
        end
        runLength = j - i;
        if runLength <= maxRunLength
            n = n + 1;
        end
        i = j;
    else
        i = i + 1;
    end
end
end

function value = localPauseStd(auth, paused)
if ~any(paused)
    value = NaN;
    return
end
segment = auth(paused);
segment = segment(isfinite(segment));
if numel(segment) < 2
    value = 0;
else
    value = std(segment);
end
end

function value = localResumeMaxStep(auth, paused, resumeWindowN)
value = NaN;
if ~any(paused)
    return
end
resumeIdx = find(diff([paused; false]) == -1) + 1;
steps = [];
for i = 1:numel(resumeIdx)
    i0 = resumeIdx(i);
    i1 = min(numel(auth), i0 + resumeWindowN);
    if i1 > i0
        steps = [steps; abs(diff(auth(i0:i1)))]; %#ok<AGROW>
    end
end
steps = steps(isfinite(steps));
if ~isempty(steps)
    value = max(steps);
end
end

function localWriteHtml(htmlFile, result, resultFile)
fid = fopen(htmlFile, 'w');
cleanup = onCleanup(@() fclose(fid));
[~, resultName, resultExt] = fileparts(resultFile);
summary = result.summary;
methodSummary = result.method_summary;

fprintf(fid, '<!doctype html>\n<html lang="en">\n<head>\n');
fprintf(fid, '<meta charset="utf-8">\n');
fprintf(fid, '<meta name="viewport" content="width=device-width, initial-scale=1">\n');
fprintf(fid, '<title>OSI 9.2 Auth-Factor Validation</title>\n');
fprintf(fid, '<style>\n');
fprintf(fid, ':root{color-scheme:light;--ink:#202124;--muted:#5f6368;--line:#d9dde1;--soft:#f5f7f8;--panel:#fff;--copper:#ac6420;--green:#39bf5e;--red:#901500}*{box-sizing:border-box}body{margin:0;background:var(--soft);color:var(--ink);font:15px/1.45 Aptos,Calibri,sans-serif}main{max-width:1240px;margin:0 auto;padding:28px 22px 44px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:22px}h1{font-size:30px;line-height:1.12;margin:0 0 8px;letter-spacing:0}h2{font-size:19px;margin:28px 0 12px;letter-spacing:0}h3{font-size:16px;margin:0 0 10px;letter-spacing:0}p{margin:0 0 10px;color:var(--muted)}code{font-family:Consolas,"Cascadia Mono",monospace;font-size:.94em}.run-meta{display:flex;flex-wrap:wrap;gap:0;margin-top:14px;border-top:1px solid var(--line);border-bottom:1px solid var(--line)}.run-meta div{padding:9px 18px 9px 0;margin-right:18px;border-right:1px solid var(--line)}.run-meta div:last-child{border-right:0}.run-meta span{color:var(--muted);font-size:12px;margin-right:6px}.run-meta strong{font-size:14px;font-weight:650}.table-wrap{overflow-x:auto;background:var(--panel);border:1px solid var(--line);border-radius:4px}table{width:100%%;border-collapse:collapse;min-width:980px}th,td{border-bottom:1px solid #e7eaed;padding:8px 10px;text-align:right;white-space:nowrap}th:first-child,td:first-child,th:nth-child(2),td:nth-child(2){text-align:left}th{background:#eceff1;color:#3f4348;font-size:12px;font-weight:650}tr:last-child td{border-bottom:0}.plots{display:grid;grid-template-columns:1fr;gap:18px}.plot{background:var(--panel);border:1px solid var(--line);border-radius:4px;padding:14px}.plot-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px}.legend{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0 0}.swatch{display:inline-flex;align-items:center;gap:6px;color:var(--muted);font-size:13px}.swatch:before{content:"";width:18px;height:3px;background:#111;display:inline-block}.direct:before{background:var(--red)}.slew:before{background:var(--copper)}.ema:before{background:var(--green)}.osi:before{background:#111}img{display:block;width:100%%;height:auto;border:1px solid #e1e4e8;background:#fff;margin-top:10px}@media(max-width:820px){main{padding:20px 14px 34px}.run-meta{display:block}.run-meta div{border-right:0;margin-right:0}.plot-head{display:block}h1{font-size:26px}}\n');
fprintf(fid, '</style>\n</head>\n<body>\n<main>\n<header>\n');
fprintf(fid, '<h1>OSI 9.2 Auth-Factor Validation</h1>\n');
fprintf(fid, '<p>Offline replay of the OSI_tests case matrix. Direct 9.2 is compared against two smooth update laws using the same selected OSI trace in each case.</p>\n');
fprintf(fid, '<div class="run-meta"><div><span>Cases</span><strong>%d</strong></div><div><span>Methods</span><strong>%d</strong></div><div><span>Recommended</span><strong>median+slew</strong></div><div><span>Generated</span><strong>%s</strong></div></div>\n', ...
    numel(result.cases), numel(result.methods), result.created);
fprintf(fid, '</header>\n');

fprintf(fid, '<section>\n<h2>Method Comparison</h2>\n');
fprintf(fid, '<div class="table-wrap"><table><thead><tr><th>Method</th><th>Worst min auth</th><th>Mean auth</th><th>Mean max step</th><th>Mean total variation</th><th>Total glitches</th><th>Max pause std</th><th>Max resume step</th></tr></thead><tbody>\n');
for i = 1:height(methodSummary)
    fprintf(fid, '<tr><td>%s</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.2f</td><td>%d</td><td>%.5f</td><td>%.4f</td></tr>\n', ...
        localHtmlEscape(methodSummary.Method{i}), ...
        methodSummary.WorstMinAuthFactor(i), ...
        methodSummary.MeanAuthFactor(i), ...
        methodSummary.MeanMaxAbsStep(i), ...
        methodSummary.MeanTotalVariation(i), ...
        methodSummary.TotalGlitches(i), ...
        methodSummary.MaxPauseStd(i), ...
        methodSummary.MaxResumeMaxStep(i));
end
fprintf(fid, '</tbody></table></div>\n');
fprintf(fid, '<p><code>%s%s</code></p>\n', resultName, resultExt);
fprintf(fid, '</section>\n');

fprintf(fid, '<section>\n<h2>Per-Case Metrics</h2>\n');
fprintf(fid, '<div class="table-wrap"><table><thead><tr><th>Case</th><th>Method</th><th>Paused</th><th>Min OSI</th><th>Mean OSI</th><th>Min auth</th><th>Mean auth</th><th>Final auth</th><th>Max step</th><th>Total variation</th><th>Glitches</th><th>Pause std</th><th>Resume max step</th></tr></thead><tbody>\n');
for i = 1:height(summary)
    fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%d</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.2f</td><td>%d</td><td>%.5f</td><td>%.4f</td></tr>\n', ...
        localHtmlEscape(summary.Case{i}), ...
        localHtmlEscape(summary.Method{i}), ...
        summary.PausedWindows(i), summary.MinOSI(i), ...
        summary.MeanOSI(i), summary.MinAuthFactor(i), ...
        summary.MeanAuthFactor(i), summary.FinalAuthFactor(i), ...
        summary.MaxAbsStep(i), summary.TotalVariation(i), ...
        summary.GlitchCount(i), summary.PauseStd(i), ...
        summary.ResumeMaxStep(i));
end
fprintf(fid, '</tbody></table></div>\n</section>\n');

fprintf(fid, '<section>\n<h2>Plots</h2>\n');
fprintf(fid, '<div class="legend"><span class="swatch osi">OSI selected</span><span class="swatch direct">9.2 direct</span><span class="swatch slew">9.2 median+slew</span><span class="swatch ema">9.2 EMA</span></div>\n');
fprintf(fid, '<div class="plots">\n');
for i = 1:numel(result.cases)
    [~, pngName, pngExt] = fileparts(result.cases(i).png);
    fprintf(fid, '<article class="plot"><div class="plot-head"><h3>%s</h3><span>PNG export</span></div><img src="figures/%s%s" alt="%s OSI 9.2 authority validation plot"></article>\n', ...
        localHtmlEscape(result.cases(i).name), pngName, pngExt, ...
        localHtmlEscape(result.cases(i).name));
end
fprintf(fid, '</div>\n</section>\n</main>\n</body>\n</html>\n');
end

function text = localHtmlEscape(text)
text = char(text);
text = strrep(text, '&', '&amp;');
text = strrep(text, '<', '&lt;');
text = strrep(text, '>', '&gt;');
text = strrep(text, '"', '&quot;');
text = strrep(text, '''', '&#39;');
end

function item = localEmptyCaseResult
item = struct('name', '', 'file', '', 'figure', '', 'png', '', ...
    'replay', []);
end
