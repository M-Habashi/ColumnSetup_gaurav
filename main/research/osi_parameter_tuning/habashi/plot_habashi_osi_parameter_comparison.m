function out = plot_habashi_osi_parameter_comparison(data, data_file, ...
        new_params, current_params)
%PLOT_HABASHI_OSI_PARAMETER_COMPARISON Replay and plot fable OSI tuning.

if nargin == 0
    script_root = fileparts(mfilename('fullpath'));
    projectFolder = fileparts(fileparts(fileparts(script_root)));
    addpath(projectFolder)
    addpath(genpath(fullfile(projectFolder, 'helpers')))
    addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
    addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))

    [new_params, current_params] = habashi_osi_parameter_sets(projectFolder);
    [data, data_file] = load_saved_result_file(projectFolder, 'tests');
elseif nargin < 4
    error(['plot_habashi_osi_parameter_comparison requires either no ', ...
        'inputs, or data, data_file, new_params, and current_params.'])
end

projectFolder = new_params.projectFolder;
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))

record = localExtractRecord(data);
new_replay = localReplayFable(record, new_params);
current_replay = localReplayFable(record, current_params);
fig = localPlot(record, data_file, new_replay, current_replay, ...
    new_params, current_params);

out = struct('file', data_file, ...
    'record', record, ...
    'new', new_replay, ...
    'current', current_replay, ...
    'figure', fig, ...
    'new_params', new_params, ...
    'current_params', current_params);
end

function record = localExtractRecord(data)
if isfield(data, 'result') && isstruct(data.result)
    data = data.result;
end

if all(isfield(data, {'dd', 'dm'}))
    dd = data.dd(:);
    dm = data.dm(:);
    if isfield(data, 't') && numel(data.t) == numel(dm)
        t = data.t(:);
    elseif isfield(data, 'tt') && numel(data.tt) == numel(dm)
        t = data.tt(:);
    else
        t = [];
    end
else
    sig = data.logsout.FileLogSignals{1}.Values;
    names = localSignalNames(sig);
    dd = sig.Data(:, localSignalIndex(names, 'dd', 1));
    dm = sig.Data(:, localSignalIndex(names, 'dm', 3));
    t = sig.Time(:);
end

if isfield(data, 'dt') && ~isempty(data.dt)
    dt = data.dt;
elseif isfield(data, 'fs') && ~isempty(data.fs)
    dt = 1/data.fs;
elseif ~isempty(t)
    dt = mean(diff(t));
else
    error('Record must contain dt, fs, or a time vector.')
end

if isempty(t)
    t = (0:numel(dm)-1)'*dt;
end

command_gain = localCommandGain(data, numel(dm));
record = struct('t', t(:), 'dd', dd(:), 'dm', dm(:), 'dt', dt, ...
    'command_gain', command_gain);
end

function idx = localSignalIndex(names, token, fallback)
idx = find(strcmpi(names, token), 1);
if isempty(idx)
    idx = find(contains(lower(names), lower(token)), 1);
end
if isempty(idx)
    idx = fallback;
end
end

function names = localSignalNames(sig)
names = strings(1, size(sig.Data, 2));
try
    u = string({sig.DataInfo.Units});
    if numel(u) == numel(names)
        names = u;
    end
end
try
    n = string({sig.Name});
    if numel(n) == numel(names) && any(strlength(n) > 0)
        names = n;
    end
end
end

function command_gain = localCommandGain(data, n)
command_gain = [];
direct_names = {'dc_gain', 'dcGain', 'dc_gain_log', 'dcGainLog', ...
    'command_gain', 'commandGain', 'cmd_gain', 'cmdGain', ...
    'command_gain_log', 'commandGainLog'};
for i = 1:numel(direct_names)
    if isfield(data, direct_names{i}) && numel(data.(direct_names{i})) == n
        command_gain = data.(direct_names{i})(:);
        return
    end
end

if isfield(data, 'Results')
    results = data.Results;
    if iscell(results)
        results = results{1};
    end
    if size(results, 1) == n && size(results, 2) >= 21
        command_gain = results(:, 21);
        return
    elseif size(results, 2) == n && size(results, 1) >= 21
        command_gain = results(21, :)';
        return
    end
end

if isfield(data, 'logsout')
    sig = data.logsout.FileLogSignals{1}.Values;
    names = localSignalNames(sig);
    hit = strcmpi(names, 'dc_gain') ...
        | strcmpi(names, 'dcGain') ...
        | contains(lower(names), 'dc_gain') ...
        | (contains(lower(names), 'command') & contains(lower(names), 'gain'));
    if ~any(hit)
        hit = contains(lower(names), 'cmd') & contains(lower(names), 'gain');
    end
    idx = find(hit, 1);
    if ~isempty(idx) && size(sig.Data, 1) == n
        command_gain = sig.Data(:, idx);
    end
end
end

function replay = localReplayFable(record, prm)
hs = struct('exp_tf_file', prm.exp_tf_file, ...
    'target_outer_ncf', prm.target_outer_ncf, ...
    'osi_gain_min', prm.osi_gain_min, ...
    'osi_gain_initial', prm.osi_gain_initial, ...
    'fable_osi_override', prm.osi_override, ...
    'fable_auth_override', prm.auth_override, ...
    'fable_pred_enable', prm.fable_pred_enable);
setup = prepare_fable_runtime(prm.projectFolder, record.dt, hs);

dd = record.dd(:);
dm = record.dm(:);
t = record.t(:);
step_n = setup.cfg.step_n;
N = floor(min(numel(dd), numel(dm))/step_n)*step_n;
half = round(step_n/2);
n_step = floor((N - half)/step_n);

tc = NaN(n_step, 1);
b_osi = NaN(n_step, 1);
b_st = NaN(n_step, 1);
b_res = NaN(n_step, 1);
b_fast = NaN(n_step, 1);
auth = NaN(n_step, 1);
trip_reason = zeros(n_step, 1);
valid = false(n_step, 1);
decision = zeros(n_step, 1);

clear fable_osi_runtime
fprintf('Replaying %s parameters through fable_osi_runtime ...\n', prm.name)
k = 0;
for i = 1:N
    [ai, bi, bsti, bresi, bfi, tri, vi, di] = fable_osi_runtime( ...
        dd(i), dm(i), 1, setup.fbls, setup.fblw, setup.fblbins, ...
        setup.fblfw, setup.fblfbins, setup.fblag, setup.fbla);
    if i > half && mod(i - half, step_n) == 0 && k < n_step
        k = k + 1;
        tc(k) = t(i - half);
        auth(k) = ai;
        b_osi(k) = bi;
        b_st(k) = bsti;
        b_res(k) = bresi;
        b_fast(k) = bfi;
        trip_reason(k) = tri;
        valid(k) = vi ~= 0;
        decision(k) = di;
    end
end
clear fable_osi_runtime

replay = struct('tc', tc, ...
    'auth', auth, ...
    'b_osi', b_osi, ...
    'b_st', b_st, ...
    'b_res', b_res, ...
    'b_fast', b_fast, ...
    'trip_reason', trip_reason, ...
    'valid', valid, ...
    'decision', decision, ...
    'setup', setup);
end

function fig = localPlot(record, data_file, new_replay, current_replay, ...
        new_params, current_params)
blue = [0 124 168]/255;
copper = [172 100 32]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;
purple = [116 5 138]/255;
black = [0 0 0];
gray = [0.45 0.45 0.45];
trip_new_color = red;
trip_current_color = black;

[~, record_name] = fileparts(data_file);
n_fast_new = nnz(new_replay.trip_reason ~= 0);
n_fast_current = nnz(current_replay.trip_reason ~= 0);
n_emergency_new = localEmergencyDropCount(new_replay);
n_emergency_current = localEmergencyDropCount(current_replay);
fig = figure('Color', 'w', 'Position', [80 80 1200 820], ...
    'Name', ['Habashi OSI tuning - ' record_name], ...
    'NumberTitle', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

ax1 = nexttile;
stride = max(1, floor(numel(record.t)/10000));
plot(ax1, record.t(1:stride:end), record.dm(1:stride:end), ...
    'Color', blue, 'LineWidth', 1)
grid(ax1, 'on')
ylabel(ax1, 'dm (mm)', 'Interpreter', 'none')
title(ax1, sprintf(['%s | fast trips new/current: %d/%d | ', ...
    'emergency drops new/current: %d/%d'], record_name, n_fast_new, ...
    n_fast_current, n_emergency_new, n_emergency_current), ...
    'Interpreter', 'none')

ax2 = nexttile;
hold(ax2, 'on')
localPlotPair(ax2, new_replay.tc, new_replay.b_osi, ...
    current_replay.tc, current_replay.b_osi, 'b_osi', black, false)
localPlotPair(ax2, new_replay.tc, new_replay.b_st, ...
    current_replay.tc, current_replay.b_st, 'b_st', green, false)
localPlotPair(ax2, new_replay.tc, new_replay.b_res, ...
    current_replay.tc, current_replay.b_res, 'b_res', red, false)
localPlotPair(ax2, new_replay.tc, new_replay.b_fast, ...
    current_replay.tc, current_replay.b_fast, 'b_fast', copper, false)
localPlotFastTripLines(ax2, new_replay, 'new', '-', trip_new_color)
localPlotFastTripLines(ax2, current_replay, 'current', '--', ...
    trip_current_color)
localPlotEmergencyDropLines(ax2, new_replay, 'new', '-', purple)
localPlotEmergencyDropLines(ax2, current_replay, 'current', '--', gray)
grid(ax2, 'on')
ylabel(ax2, 'OSI margin', 'Interpreter', 'none')
legend2 = legend(ax2, 'Location', 'best', 'Interpreter', 'none');
legend2.ItemHitFcn = @localToggleLegendItem;

ax3 = nexttile;
hold(ax3, 'on')
localPlotPair(ax3, new_replay.tc, new_replay.auth, ...
    current_replay.tc, current_replay.auth, 'authority factor', ...
    purple, true)
localPlotFastTripLines(ax3, new_replay, 'new', '-', trip_new_color)
localPlotFastTripLines(ax3, current_replay, 'current', '--', ...
    trip_current_color)
localPlotFastTrips(ax3, new_replay, 'new', 'v', trip_new_color)
localPlotFastTrips(ax3, current_replay, 'current', 'x', trip_current_color)
localPlotEmergencyDrops(ax3, new_replay, 'new', 's', purple)
localPlotEmergencyDrops(ax3, current_replay, 'current', 'd', gray)
if ~isempty(record.command_gain)
    plot(ax3, record.t, record.command_gain, ':', 'Color', gray, ...
        'LineWidth', 1.4, 'DisplayName', 'dc gain (logged)')
end
grid(ax3, 'on')
ylabel(ax3, 'factor', 'Interpreter', 'none')
xlabel(ax3, 'time (s)', 'Interpreter', 'none')
legend3 = legend(ax3, 'Location', 'best', 'Interpreter', 'none');
legend3.ItemHitFcn = @localToggleLegendItem;

linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [record.t(1) record.t(min(numel(record.t), ...
    numel(record.dm)))])

fprintf('\nReplay summary\n')
fprintf('  new target/current target: %.6g / %.6g\n', ...
    new_params.target_outer_ncf, current_params.target_outer_ncf)
fprintf('  new min authority/current min authority: %.6g / %.6g\n', ...
    min(new_replay.auth, [], 'omitnan'), ...
    min(current_replay.auth, [], 'omitnan'))
fprintf('  new fast trips/current fast trips: %d / %d\n', ...
    n_fast_new, n_fast_current)
fprintf('  new emergency drops/current emergency drops: %d / %d\n', ...
    n_emergency_new, n_emergency_current)
fprintf('  dc gain logged: %d\n', ~isempty(record.command_gain))
localPrintDropAnalysis('new', new_replay, new_params)
localPrintDropAnalysis('current', current_replay, current_params)
end

function n = localEmergencyDropCount(replay)
n = nnz(localEmergencyDropIndex(replay));
end

function idx = localEmergencyDropIndex(replay)
emergency = replay.decision(:) == 2 ...
    & isfinite(replay.tc(:)) ...
    & isfinite(replay.auth(:));
if isempty(emergency)
    idx = emergency;
    return
end
idx = emergency & ~[false; emergency(1:end-1)];
end

function localPrintDropAnalysis(label, replay, params)
auth = replay.auth(:);
da = [NaN; diff(auth)];
idx = find(isfinite(da) & da <= -0.05, 1);
if isempty(idx)
    fprintf('  %s first drop: none >= 0.05 authority units\n', label)
    return
end

target = params.target_outer_ncf;
sev_frac = 0.60;
if isfield(params.auth_override, 'sev_frac') ...
        && ~isempty(params.auth_override.sev_frac)
    sev_frac = params.auth_override.sev_frac;
end
sev_limit = sev_frac*target;
decision = replay.decision(idx);
trip_reason = replay.trip_reason(idx);
b = replay.b_osi(idx);

if decision == 4 || trip_reason ~= 0
    cause = sprintf('fast trip, trip_reason=%g', trip_reason);
elseif decision == 2
    cause = sprintf('severe margin shed: b_osi %.3g < %.3g', ...
        b, sev_limit);
elseif decision == 1
    cause = sprintf('confirmed low-margin shed: b_osi %.3g < target %.3g', ...
        b, target);
elseif decision == 3
    cause = 'recovery step';
else
    cause = sprintf('decision %g', decision);
end

fprintf(['  %s first drop: t=%.3f s, auth %.3g -> %.3g, ', ...
    'decision=%g, %s\n'], label, replay.tc(idx), auth(idx-1), ...
    auth(idx), decision, cause)
fprintf(['    margins at drop: b_osi=%.3g, b_st=%.3g, ', ...
    'b_res=%.3g, b_fast=%.3g\n'], replay.b_osi(idx), ...
    replay.b_st(idx), replay.b_res(idx), replay.b_fast(idx))
end

function localPlotFastTripLines(ax, replay, label, line_style, color)
t_trip = replay.tc(replay.trip_reason ~= 0 & isfinite(replay.tc));
if isempty(t_trip)
    return
end
t_trip = unique(t_trip(:)');
yl = ylim(ax);
for i = 1:numel(t_trip)
    if i == 1
        display_name = ['fast trip line ' label];
        handle_visibility = 'on';
    else
        display_name = '';
        handle_visibility = 'off';
    end
    plot(ax, [t_trip(i) t_trip(i)], yl, line_style, ...
        'Color', color, ...
        'LineWidth', 1.4, ...
        'DisplayName', display_name, ...
        'HandleVisibility', handle_visibility)
end
ylim(ax, yl)
end

function localPlotFastTrips(ax, replay, label, marker, color)
idx = replay.trip_reason ~= 0 & isfinite(replay.tc) & isfinite(replay.auth);
if ~any(idx)
    return
end
plot(ax, replay.tc(idx), replay.auth(idx), marker, ...
    'Color', color, ...
    'MarkerFaceColor', color, ...
    'LineStyle', 'none', ...
    'MarkerSize', 9, ...
    'LineWidth', 1.8, ...
    'DisplayName', ['fast trip ' label])
end

function localPlotEmergencyDropLines(ax, replay, label, line_style, color)
t_drop = replay.tc(localEmergencyDropIndex(replay));
if isempty(t_drop)
    return
end
t_drop = unique(t_drop(:)');
yl = ylim(ax);
for i = 1:numel(t_drop)
    if i == 1
        display_name = ['emergency drop line ' label];
        handle_visibility = 'on';
    else
        display_name = '';
        handle_visibility = 'off';
    end
    plot(ax, [t_drop(i) t_drop(i)], yl, line_style, ...
        'Color', color, ...
        'LineWidth', 1.4, ...
        'DisplayName', display_name, ...
        'HandleVisibility', handle_visibility)
end
ylim(ax, yl)
end

function localPlotEmergencyDrops(ax, replay, label, marker, color)
idx = localEmergencyDropIndex(replay);
if ~any(idx)
    return
end
plot(ax, replay.tc(idx), replay.auth(idx), marker, ...
    'Color', color, ...
    'MarkerFaceColor', 'w', ...
    'LineStyle', 'none', ...
    'MarkerSize', 9, ...
    'LineWidth', 1.8, ...
    'DisplayName', ['emergency drop ' label])
end

function localPlotPair(ax, t_new, y_new, t_current, y_current, ...
        label, color, use_stairs)
if use_stairs
    stairs(ax, t_new, y_new, '-', 'Color', color, 'LineWidth', 1, ...
        'DisplayName', [label ' new'])
    stairs(ax, t_current, y_current, '--', 'Color', color, ...
        'LineWidth', 2, 'DisplayName', [label ' current'])
else
    plot(ax, t_new, y_new, '-', 'Color', color, 'LineWidth', 1, ...
        'DisplayName', [label ' new'])
    plot(ax, t_current, y_current, '--', 'Color', color, ...
        'LineWidth', 2, 'DisplayName', [label ' current'])
end
end

function localToggleLegendItem(~, evt)
if strcmp(evt.Peer.Visible, 'on')
    evt.Peer.Visible = 'off';
else
    evt.Peer.Visible = 'on';
end
end
