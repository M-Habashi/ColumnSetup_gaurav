function results = run_osi_9_3_auth_factor_cases
%RUN_OSI_9_3_AUTH_FACTOR_CASES Plot Method 9.3 median+slew authority.
% Method 9.3 is the former m92_slew research law: recompute OSI from dd/dm,
% then update auth_factor with median despiking and slew-limited recovery.

projectFolder = fileparts(fileparts(mfilename('fullpath')));
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
addpath(fullfile(projectFolder, 'research', 'optimizing_pl', 'codex'))

records = localRecords(projectFolder);
figureFolder = fullfile(projectFolder, 'OSI_tests', 'figures_9_3');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder)
end

results = repmat(struct('name', '', 'file', '', 'figure', '', ...
    'png', '', 'replay', []), 0, 1);

for k = 1:numel(records)
    record = records(k);
    fprintf('\nPlotting OSI 9.3 median+slew for %s\n', record.name)

    data = localLoadSavedResult(record.file);
    replay = localReplayMethod93(projectFolder, data);
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

function replay = localReplayMethod93(projectFolder, data)
dd = data.dd(:);
dm = data.dm(:);
dt = data.dt;
targetNcf = 0.3;

hs = struct( ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', 'exp_tf', ...
        'tf_sp1_5000_20260627_233333.mat'), ...
    'osi_gain_initial', 1, ...
    'osi_gain_min', 0.05, ...
    'target_outer_ncf', targetNcf, ...
    'osi_branch_split_hz', [], ...
    'osi_st_branch_hz', [2 30], ...
    'osi_residual_branch_hz', [40 80]);

setup = prepare_osi_gain_runtime(projectFolder, dt, hs);
cfg = setup.m91_cfg;
state = m91_adaptive_margin('state', cfg);

params = struct('a_min', 0.05, ...
    'down_deadband', 0.005, ...
    'down_rate_per_s', 8.0, ...
    'up_deadband', 0.02, ...
    'up_rate_per_s', 0.15, ...
    'up_hold_s', 0.5, ...
    'valid_confirm_n', 5);

nWindow = floor((min(numel(dd), numel(dm)) - cfg.window_n) ...
    /cfg.update_interval_n) + 1;
tc = NaN(nWindow, 1);
ncfSt = NaN(nWindow, 1);
ncfResidual = NaN(nWindow, 1);
ncfSelected = NaN(nWindow, 1);
authFactor = NaN(nWindow, 1);

lastMargin = cfg.nominal;
auth = min(1, max(params.a_min, lastMargin/targetNcf));
buffer = lastMargin*ones(3, 1);
holdCount = 0;
validCount = params.valid_confirm_n;

for k = 1:nWindow
    idx = (k - 1)*cfg.update_interval_n + (1:cfg.window_n);
    tc(k) = data.t(idx(end));

    [margin, state, info] = m91_adaptive_margin(dd(idx), dm(idx), ...
        cfg, state);
    lastMargin = margin;
    ncfSt(k) = info.ncf_st;
    ncfResidual(k) = info.ncf_residual;
    ncfSelected(k) = margin;

    [auth, buffer, holdCount, validCount] = osi_method_9_2_auth_slew( ...
        lastMargin, auth, buffer, holdCount, validCount, targetNcf, ...
        cfg.update_interval_actual_s, params.a_min, ...
        params.down_deadband, params.down_rate_per_s, ...
        params.up_deadband, params.up_rate_per_s, params.up_hold_s, ...
        params.valid_confirm_n);
    authFactor(k) = auth;
end

replay = struct('tc', tc, ...
    'ncf_st', ncfSt, ...
    'ncf_residual', ncfResidual, ...
    'ncf_selected', ncfSelected, ...
    'auth_factor', authFactor, ...
    'target_ncf', targetNcf, ...
    'params', params, ...
    'cfg', cfg, ...
    'setup', setup);
end

function [figPath, pngPath] = localPlotRecord(record, data, replay, ...
        figureFolder)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;

figPath = fullfile(figureFolder, [record.name '_osi_9_3_auth.fig']);
pngPath = fullfile(figureFolder, [record.name '_osi_9_3_auth.png']);

fig = figure('Name', [record.name ' OSI 9.3'], 'Color', 'w', ...
    'Position', [140 120 1120 760]);
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

axDm = nexttile;
plot(data.t(:), data.dm(:), 'Color', blue, 'LineWidth', 1)
grid on
ylabel('dm (mm)', 'Interpreter', 'none')
title([record.name ' OSI 9.3 median+slew'], 'Interpreter', 'none')

axOsi = nexttile;
yyaxis left
hSt = plot(replay.tc, replay.ncf_st, '--', 'Color', green, ...
    'LineWidth', 1);
hold on
hResidual = plot(replay.tc, replay.ncf_residual, '--', 'Color', red, ...
    'LineWidth', 1);
hSelected = plot(replay.tc, replay.ncf_selected, '-', 'Color', [0 0 0], ...
    'LineWidth', 1.5);
yline(replay.target_ncf, ':', 'target NCF', 'Color', [0.35 0.35 0.35], ...
    'HandleVisibility', 'off', 'Interpreter', 'none');
ylabel('OSI', 'Interpreter', 'none')
grid on

yyaxis right
hAuth = plot(replay.tc, replay.auth_factor, '-', 'Color', copper, ...
    'LineWidth', 1.25);
ylabel('auth_factor', 'Interpreter', 'none')
ylim([0 1.05])
xlabel('Time (s)')
linkaxes([axDm axOsi], 'x')

legend([hSt hResidual hSelected hAuth], ...
    {'OSI S/T branch', 'OSI residual branch', 'OSI selected', ...
    '9.3 auth_factor'}, 'Location', 'best', 'Interpreter', 'none')

savefig(fig, figPath)
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, pngPath, 'Resolution', 150)
else
    print(fig, pngPath, '-dpng', '-r150')
end
end
