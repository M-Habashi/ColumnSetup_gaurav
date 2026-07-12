function out = plot_habashi_osi_parameter_comparison(data, data_file, ...
        new_params, current_params)
%PLOT_HABASHI_OSI_PARAMETER_COMPARISON Replay and plot GPT-5.6.4 tuning.
% Replays a saved test record through the deployed Speedgoat runtime
% (gpt5_6_runtime.m, parameters packed by prepare_gpt5_6_runtime.m) once
% with the editable "new" parameters and once with the "current"
% implementation defaults, then overlays margins and authority.
%
% The OSI drive tap is u_osi when the record provides it (the runtime's dd
% input on the rig); plain dd is force-echo biased and used only as a
% fallback for legacy records.

if nargin == 0
    script_root = fileparts(mfilename('fullpath'));
    projectFolder = fileparts(fileparts(fileparts(script_root)));
    addpath(projectFolder)
    addpath(genpath(fullfile(projectFolder, 'helpers')))
    addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

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

record = localExtractRecord(data);
new_replay = localReplayGpt(record, new_params);
current_replay = localReplayGpt(record, current_params);
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

if isfield(data, 'u_osi') && isfield(data, 'dm')
    dd = data.u_osi(:);          % the runtime's dd input on the rig
    dm = data.dm(:);
    dd_source = 'u_osi';
elseif all(isfield(data, {'dd', 'dm'}))
    dd = data.dd(:);
    dm = data.dm(:);
    dd_source = 'dd (legacy fallback, force-echo biased)';
else
    sig = data.logsout.FileLogSignals{1}.Values;
    names = localSignalNames(sig);
    dd = sig.Data(:, localSignalIndex(names, 'u_osi', ...
        localSignalIndex(names, 'dd', 1)));
    dm = sig.Data(:, localSignalIndex(names, 'dm', 3));
    dd_source = 'logsout';
end
if isfield(data, 't') && numel(data.t) == numel(dm)
    t = data.t(:);
elseif isfield(data, 'tt') && numel(data.tt) == numel(dm)
    t = data.tt(:);
else
    t = [];
end
fprintf('OSI drive tap: %s\n', dd_source)

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

function replay = localReplayGpt(record, prm)
hs = struct('exp_tf_file', prm.exp_tf_file, ...
    'target_outer_ncf', prm.target_outer_ncf, ...
    'osi_gain_min', prm.osi_gain_min, ...
    'osi_gain_initial', prm.osi_gain_initial, ...
    'gpt5_6_override', struct('osi', prm.osi_override, ...
    'auth', prm.auth_override));
setup = prepare_gpt5_6_runtime(prm.projectFolder, record.dt, hs);

dd = record.dd(:);
dm = record.dm(:);
t = record.t(:);
step_n = setup.cfg.step_n;
publish_ticks = setup.publish_ticks;
N = min(numel(dd), numel(dm));
n_step = floor((N - publish_ticks)/step_n);

tc = NaN(n_step, 1);
b_osi = NaN(n_step, 1);
b_st = NaN(n_step, 1);
b_res = NaN(n_step, 1);
auth = NaN(n_step, 1);
valid = false(n_step, 1);
decision = zeros(n_step, 1);

clear gpt5_6_runtime
fprintf('Replaying %s parameters through gpt5_6_runtime ...\n', prm.name)
for i = 1:N
    [ai, bi, bsti, bresi, ~, ~, vi, di] = gpt5_6_runtime( ...
        dd(i), dm(i), 1, setup.gpts, setup.gptw, setup.gptbins, ...
        setup.gptrho, setup.gptauth, 0, 0);
    k = (i - publish_ticks)/step_n;
    if k >= 1 && k == round(k) && k <= n_step
        tc(k) = t(min(i, numel(t)));
        auth(k) = ai;
        b_osi(k) = bi;
        b_st(k) = bsti;
        b_res(k) = bresi;
        valid(k) = vi ~= 0;
        decision(k) = di;
    end
end
clear gpt5_6_runtime

replay = struct('tc', tc, ...
    'auth', auth, ...
    'b_osi', b_osi, ...
    'b_st', b_st, ...
    'b_res', b_res, ...
    'valid', valid, ...
    'decision', decision, ...
    'setup', setup);
end

function fig = localPlot(record, data_file, new_replay, current_replay, ...
        new_params, current_params)
blue = [0 124 168]/255;
green = [57 191 94]/255;
red = [144 21 0]/255;
purple = [116 5 138]/255;
black = [0 0 0];
gray = [0.45 0.45 0.45];

[~, record_name] = fileparts(data_file);
travel_new = sum(abs(diff(new_replay.auth(isfinite(new_replay.auth)))));
travel_current = sum(abs(diff( ...
    current_replay.auth(isfinite(current_replay.auth)))));
fig = figure('Color', 'w', 'Position', [80 80 1200 820], ...
    'Name', ['Habashi GPT-5.6.4 tuning - ' record_name], ...
    'NumberTitle', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact')

ax1 = nexttile;
stride = max(1, floor(numel(record.t)/10000));
plot(ax1, record.t(1:stride:end), record.dm(1:stride:end), ...
    'Color', blue, 'LineWidth', 1)
grid(ax1, 'on')
ylabel(ax1, 'dm (mm)', 'Interpreter', 'none')
title(ax1, sprintf('%s | authority travel new/current: %.2f/%.2f', ...
    record_name, travel_new, travel_current), 'Interpreter', 'none')

ax2 = nexttile;
hold(ax2, 'on')
localPlotPair(ax2, new_replay.tc, new_replay.b_osi, ...
    current_replay.tc, current_replay.b_osi, 'b_osi', black, false)
localPlotPair(ax2, new_replay.tc, new_replay.b_st, ...
    current_replay.tc, current_replay.b_st, 'b_st', green, false)
localPlotPair(ax2, new_replay.tc, new_replay.b_res, ...
    current_replay.tc, current_replay.b_res, 'b_res', red, false)
yline(ax2, new_params.target_outer_ncf, ':', 'Color', gray, ...
    'LineWidth', 1.4, 'DisplayName', 'target')
grid(ax2, 'on')
ylabel(ax2, 'OSI margin', 'Interpreter', 'none')
legend2 = legend(ax2, 'Location', 'best', 'Interpreter', 'none');
legend2.ItemHitFcn = @localToggleLegendItem;

ax3 = nexttile;
hold(ax3, 'on')
localPlotPair(ax3, new_replay.tc, new_replay.auth, ...
    current_replay.tc, current_replay.auth, 'authority factor', ...
    purple, true)
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
fprintf('  new authority travel/current authority travel: %.3g / %.3g\n', ...
    travel_new, travel_current)
fprintf('  dc gain logged: %d\n', ~isempty(record.command_gain))
localPrintDropAnalysis('new', new_replay)
localPrintDropAnalysis('current', current_replay)
end

function localPrintDropAnalysis(label, replay)
auth = replay.auth(:);
da = [NaN; diff(auth)];
idx = find(isfinite(da) & da <= -0.05, 1);
if isempty(idx)
    fprintf('  %s first drop: none >= 0.05 authority units\n', label)
    return
end
fprintf('  %s first drop: t=%.3f s, auth %.3g -> %.3g\n', ...
    label, replay.tc(idx), auth(idx-1), auth(idx))
fprintf('    margins at drop: b_osi=%.3g, b_st=%.3g, b_res=%.3g\n', ...
    replay.b_osi(idx), replay.b_st(idx), replay.b_res(idx))
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
