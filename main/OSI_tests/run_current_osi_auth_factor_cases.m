function results = run_current_osi_auth_factor_cases
%RUN_CURRENT_OSI_AUTH_FACTOR_CASES Plot current OSI/auth-factor for 3 records.
% The script recomputes OSI/auth_factor from dd and dm. It does not use any
% OSI values saved in the records.

projectFolder = fileparts(fileparts(mfilename('fullpath')));
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

records = localRecords(projectFolder);
figureFolder = fullfile(projectFolder, 'OSI_tests', 'figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

results = repmat(struct('name', '', 'file', '', 'figure', '', ...
    'png', '', 'replay', []), 0, 1);

for k = 1:numel(records)
    record = records(k);
    fprintf('\nPlotting OSI/auth_factor for %s\n', record.name)

    data = localLoadSavedResult(record.file);
    replay = localReplayCurrentImplementation(projectFolder, data);
    [figPath, pngPath] = localPlotRecord(record, data, replay, ...
        figureFolder);

    results(end + 1) = struct('name', record.name, ...
        'file', record.file, ...
        'figure', figPath, ...
        'png', pngPath, ...
        'replay', replay); %#ok<AGROW>
end
end

function records = localRecords(projectFolder)
records = struct( ...
    'name', { ...
        '20260617_1731', ...
        '20260617_1749', ...
        '20260630_1930'}, ...
    'file', { ...
        fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
            '20260617_1731_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
        fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
            '20260617_1749_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
        fullfile(projectFolder, 'saved_results', 'tests', 'important', ...
            '20260630_1930_testing_OSI.mat')});
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

function replay = localReplayCurrentImplementation(projectFolder, data)
dd = data.dd(:);
dm = data.dm(:);
dt = data.dt;

hs = struct( ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', 'exp_tf', ...
        'tf_sp1_5000_20260627_233333.mat'), ...
    'osi_gain_initial', 0.3, ...
    'osi_gain_min', 0.08, ...
    'target_outer_ncf', 0.3, ...
    'osi_branch_split_hz', [], ...
    'osi_st_branch_hz', [2 30], ...
    'osi_residual_branch_hz', [40 80]);

setup = prepare_osi_gain_runtime(projectFolder, dt, hs);
cfg = setup.m91_cfg;
state = m91_adaptive_margin('state', cfg);

nWindow = floor((min(numel(dd), numel(dm)) - cfg.window_n) ...
    /cfg.update_interval_n) + 1;
tc = NaN(nWindow, 1);
ncfSt = NaN(nWindow, 1);
ncfResidual = NaN(nWindow, 1);
ncfSelected = NaN(nWindow, 1);
authFactor = NaN(nWindow, 1);

auth = osigs(1);
marginFiltered = osigs(2);
marginGuarded = osigs(2);
aboveCount = 0;
belowCount = 0;

for k = 1:nWindow
    idx = (k - 1)*cfg.update_interval_n + (1:cfg.window_n);
    tc(k) = data.t(idx(end));

    [margin, state, info] = m91_adaptive_margin(dd(idx), dm(idx), ...
        cfg, state);
    ncfSt(k) = info.ncf_st;
    ncfResidual(k) = info.ncf_residual;
    ncfSelected(k) = margin;

    [auth, marginFiltered, marginGuarded, aboveCount, belowCount] = ...
        auth_stability_gain(margin, auth, marginFiltered, ...
        marginGuarded, aboveCount, belowCount, osigs(2), ...
        cfg.update_interval_actual_s, osigs(3), osigs(4), ...
        osigs(5), osigs(6), osigs(7), osigs(8), osigs(9), ...
        osigs(10), osigs(11), osigs(12), osigs(13), osigs(14), ...
        osigs(15), osigs(16));
    authFactor(k) = auth;
end

replay = struct('tc', tc, ...
    'ncf_st', ncfSt, ...
    'ncf_residual', ncfResidual, ...
    'ncf_selected', ncfSelected, ...
    'auth_factor', authFactor, ...
    'cfg', cfg, ...
    'setup', setup);
end

function [figPath, pngPath] = localPlotRecord(record, data, replay, ...
        figureFolder)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;

figPath = fullfile(figureFolder, [record.name '_current_osi_auth.fig']);
pngPath = fullfile(figureFolder, [record.name '_current_osi_auth.png']);

fig = figure('Name', record.name, 'Color', 'w', ...
    'Position', [100 100 1120 760]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

axDm = nexttile;
plot(data.t(:), data.dm(:), 'Color', blue, 'LineWidth', 1)
grid on
ylabel('dm (mm)', 'Interpreter', 'none')
title([record.name ' current OSI/auth-factor'], 'Interpreter', 'none')

axOsi = nexttile;
yyaxis left
hSt = plot(replay.tc, replay.ncf_st, '--', 'Color', green, ...
    'LineWidth', 1);
hold on
hResidual = plot(replay.tc, replay.ncf_residual, '--', 'Color', red, ...
    'LineWidth', 1);
hSelected = plot(replay.tc, replay.ncf_selected, '-', 'Color', [0 0 0], ...
    'LineWidth', 1.5);
ylabel('OSI', 'Interpreter', 'none')
grid on

yyaxis right
hAuth = plot(replay.tc, replay.auth_factor, '-', 'Color', copper, ...
    'LineWidth', 1.25);
ylabel('auth_factor', 'Interpreter', 'none')
xlabel('Time (s)')
linkaxes([axDm axOsi], 'x')

legend([hSt hResidual hSelected hAuth], ...
    {'OSI S/T branch', 'OSI residual branch', 'OSI selected', ...
    'auth_factor'}, 'Location', 'best', 'Interpreter', 'none')

savefig(fig, figPath)
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, pngPath, 'Resolution', 150)
else
    print(fig, pngPath, '-dpng', '-r150')
end
end
