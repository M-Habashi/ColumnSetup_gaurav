function [metric_table, comparison] = compare_hs_response_to_reference( ...
        fem, recorded_data, earthquake_type, intensity_factor, ...
        time_scale_factor, force_sign, options)
%COMPARE_HS_RESPONSE_TO_REFERENCE Compare HS data with full FEM reference.
% Units:
%   recorded data: t [s], dm [mm], fm [N].
%   FEM/reference displacements are compared in [m].
%   J1 [ms]; J2-J7 [%].

project_folder = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(project_folder, 'helpers', 'utils'));
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'));
addpath(fullfile(project_folder, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
addpath(fullfile(project_folder, 'results_analysis'));

if nargin < 2
    recorded_data = [];
end
if nargin < 1
    fem = [];
end
if nargin < 3
    earthquake_type = [];
end
if nargin < 4
    intensity_factor = [];
end
if nargin < 5
    time_scale_factor = [];
end
if nargin < 6
    force_sign = [];
end
if nargin < 7 || isempty(options)
    options = struct();
end
plot_enabled = getOption(options, 'plot', true);

data = loadRecordedData(recorded_data, project_folder);
fem = loadFemData(fem, data, project_folder);
[earthquake_type, intensity_factor, time_scale_factor, force_sign] = ...
    getComparisonInputs(data, min(nargin, 6), earthquake_type, ...
    intensity_factor, time_scale_factor, force_sign);

t = data.t(:);
dm = data.dm(:);
fm = data.fm(:);
if isfield(data, 'dt')
    dt = data.dt;
else
    dt = mean(diff(t));
end
if isfield(data, 'fs')
    fs = data.fs;
else
    fs = 1/dt;
end
pause_enable = getPauseEnable(data, numel(t));
n = min([numel(t), numel(dm), numel(fm), numel(pause_enable)]);
t = t(1:n);
dm = dm(1:n);
dm_filtfilt = filtfiltDm(dm, fs, 20, 6);
fm = fm(1:n);
pause_enable = pause_enable(1:n);

hs = buildHsModel(fem, earthquake_type, intensity_factor, ...
    time_scale_factor, force_sign, project_folder);
[u_test, u_control_test_mm, effective_time] = replayRecordedHs( ...
    fm, pause_enable, dt, hs);
[u_reference, u_control_reference] = fullReferenceAtEffectiveTime( ...
    fem.ref, hs, effective_time, dt);
if plot_enabled
    plotReferenceControlDisplacement(effective_time, dm, dm_filtfilt, fm, ...
        u_control_test_mm, u_control_reference, ...
        pause_enable, fem.ref);
    plotFloorReferenceComparison(effective_time, u_test, u_reference, ...
        pause_enable);
    plotResponseFrequencyContent(hs, fem.num, u_test, effective_time, ...
        pause_enable, dt);
end

running = pause_enable == 0;
metric = validation_metrics();
u_control_reference_mm = 1000*u_control_reference;
% J1-J3 compare measured dm to d_n from the numerical sub.
% J4-J6 compare x1_n/x2_n/x3_n numerical sub floors to x1_r/x2_r/x3_r.
% J7 compares measured dm to d_r as NMSE.
values = [ ...
    metric.J1(dm_filtfilt(running), u_control_test_mm(running), dt); ...
    metric.J2(dm_filtfilt(running), u_control_test_mm(running)); ...
    metric.J3(dm_filtfilt(running), u_control_test_mm(running)); ...
    metric.J4(u_test(running, 1), u_reference(running, 1)); ...
    metric.J5(u_test(running, 2), u_reference(running, 2)); ...
    metric.J6(u_test(running, 3), u_reference(running, 3)); ...
    metric.J7(dm_filtfilt(running), u_control_reference_mm(running))];

metric_table = table( ...
    ["finddelay(d_n, dm_filtfilt)*dt"; ...
     "100*std(dm_filtfilt - d_n)/std(d_n)"; ...
     "100*max(abs(dm_filtfilt - d_n))/max(abs(d_n))"; ...
     "100*std(x1_n - x1_r)/std(x1_r)"; ...
     "100*std(x2_n - x2_r)/std(x2_r)"; ...
     "100*std(x3_n - x3_r)/std(x3_r)"; ...
     "100*mean((dm_filtfilt - d_r)^2)/mean(d_r^2)"], ...
    ["ms"; "%"; "%"; "%"; "%"; "%"; "%"], ...
    values, ...
    'RowNames', {'J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'J7'}, ...
    'VariableNames', {'Description', 'Unit', 'Value'});

if nargout == 0
    disp('Hybrid Simulation Reference Comparison')
    disp(metric_table)
end

if nargout > 1
    comparison = struct('t', t, 'effective_time', effective_time, ...
        'pause_enable', pause_enable, 'u_test', u_test, ...
        'u_reference', u_reference, ...
        'dm_filtfilt', dm_filtfilt, ...
        'u_control_test_mm', u_control_test_mm, ...
        'u_control_reference', u_control_reference);
end
end

function value = getOption(options, name, default_value)
if isfield(options, name)
    value = options.(name);
else
    value = default_value;
end
end

function data = loadRecordedData(recorded_data, project_folder)
if nargin < 1 || isempty(recorded_data) ...
        || ((ischar(recorded_data) || isstring(recorded_data)) ...
        && ~isfile(recorded_data))
    if nargin >= 1 && ~isempty(recorded_data)
        fprintf('Recorded data file not found: %s\n', recorded_data)
    end
    [data, recorded_data] = load_saved_result_file(project_folder, ...
        'tests', true);
    fprintf('Loaded recorded data: %s\n', recorded_data)
elseif ischar(recorded_data) || isstring(recorded_data)
    data = load(recorded_data);
    if isfield(data, 'result') && isstruct(data.result)
        data = data.result;
    end
else
    data = recorded_data;
    if isfield(data, 'result') && isstruct(data.result)
        data = data.result;
    end
end
end

function fem = loadFemData(fem, data, project_folder)
if isstruct(fem) && isfield(fem, 'num') && isfield(fem, 'ref')
    return
end

if ischar(fem) || isstring(fem)
    if isfile(fem)
        fem_data = load(fem, 'fem');
        fem = fem_data.fem;
        return
    end
    fprintf('FEM file not found: %s\n', fem)
end

if isfield(data, 'hs') && isfield(data.hs, 'fem')
    fem = data.hs.fem;
    return
end

fem_data = load_saved_result_file(project_folder, 'fem', true);
assert(isfield(fem_data, 'fem'), 'Selected FEM file does not contain fem.')
fem = fem_data.fem;
end

function [earthquake_type, intensity_factor, time_scale_factor, force_sign] = ...
        getComparisonInputs(data, n_input, earthquake_type, intensity_factor, ...
        time_scale_factor, force_sign)
if n_input < 3 || isempty(earthquake_type)
    assert(isfield(data, 'hs') && isfield(data.hs, 'earthquake_type'), ...
        'earthquake_type must be passed or stored in recorded data hs.')
    earthquake_type = data.hs.earthquake_type;
end
if n_input < 4 || isempty(intensity_factor)
    assert(isfield(data, 'hs') && isfield(data.hs, 'intensity_factor'), ...
        'intensity_factor must be passed or stored in recorded data hs.')
    intensity_factor = data.hs.intensity_factor;
end
if n_input < 5 || isempty(time_scale_factor)
    assert(isfield(data, 'hs') && isfield(data.hs, 'time_scale_factor'), ...
        'time_scale_factor must be passed or stored in recorded data hs.')
    time_scale_factor = data.hs.time_scale_factor;
end
if n_input < 6 || isempty(force_sign)
    if isfield(data, 'hs') && isfield(data.hs, 'force_sign')
        force_sign = data.hs.force_sign;
    else
        force_sign = 1.0;
    end
end
end

function pause_enable = getPauseEnable(data, n)
if isfield(data, 'dd_pause_enable_log') && ~isempty(data.dd_pause_enable_log)
    pause_enable = data.dd_pause_enable_log(:);
elseif isfield(data, 'dd_pause_enable') && ~isempty(data.dd_pause_enable)
    pause_enable = data.dd_pause_enable(:);
elseif isfield(data, 'Results') && numel(data.Results) >= 1 ...
        && size(data.Results{1}, 2) >= 10
    pause_enable = data.Results{1}(:, 10);
else
    pause_enable = zeros(n, 1);
end
end

function hs = buildHsModel(fem, earthquake_type, intensity_factor, ...
        time_scale_factor, force_sign, project_folder)
fem_num = fem.num;
fem_ref = fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

hs.fem = fem;
hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.K_if = K_if;
hs.K_ii = K_ii;
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, fem);
hs.damping_ratio = hs.damping.target_ratio;
hs.earthquake_type = earthquake_type;
hs.intensity_factor = intensity_factor;

earthquakes = load(fullfile(project_folder, 'input_signals', ...
    'earthquakes.mat'), earthquake_type);
earthquake = earthquakes.(earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = intensity_factor*earthquake(:, 2);
hs.time_scale_factor = time_scale_factor;
hs.force_sign = force_sign;
end

function [u_test, u_control_test_mm, effective_time] = replayRecordedHs( ...
        fm, pause_enable, dt, hs)
n = numel(fm);
state = [];
u_test = zeros(n, hs.n_floor);
u_control_test_mm = zeros(n, 1);
effective_time = zeros(n, 1);
for step = 2:n
    [u_control_test_mm(step), state] = step_HS( ...
        fm(step), pause_enable(step), dt, hs, state);
    u_test(step, :) = state(1:hs.n_floor)';
    effective_time(step) = effective_time(step - 1);
    if pause_enable(step) == 0
        effective_time(step) = effective_time(step) + dt;
    end
end
end

function [u_reference, u_control_reference] = fullReferenceAtEffectiveTime(fem_ref, hs, ...
        effective_time, dt)
reference_time = (0:round(max(effective_time)/dt))'*dt;
reference_model_time = reference_time/hs.time_scale_factor;
ag = interp1(hs.time, hs.ag, reference_model_time, 'linear', 0);
reference_load = -(fem_ref.M*fem_ref.influence)*ag';
u_reference_grid = newmarkAverageAcceleration(reference_time, ...
    fem_ref.M, hs.C, fem_ref.K, reference_load);
u_control_grid = referenceControlDisplacement(fem_ref, u_reference_grid);
reference_index = round(effective_time/dt) + 1;
u_reference = u_reference_grid(reference_index, :);
u_control_reference = u_control_grid(reference_index);
end

function plotReferenceControlDisplacement(effective_time, dm, dm_filtfilt, fm, ...
        u_control_test_mm, u_control_reference, pause_enable, fem_ref)
active = pause_enable == 0;
if ~any(active)
    active = true(size(pause_enable));
end

x = effective_time(active);
dm = dm(active);
dm_filtfilt = dm_filtfilt(active);
fm = fm(active);
u_control_test_mm = u_control_test_mm(active);
u_control_reference = u_control_reference(active);

colors = getPlotColors();
figure('Color', 'w', 'Name', 'HS control-point displacement and force comparison');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax(1) = nexttile;
plot(ax(1), x, u_control_test_mm, 'k--', 'LineWidth', 2.0, ...
    'DisplayName', 'd\_n (numerical sub)');
hold(ax(1), 'on')
plot(ax(1), x, dm, '-', 'Color', colors.blue, 'LineWidth', 1.0, ...
    'DisplayName', 'dm (measured)');
plot(ax(1), x, dm_filtfilt, '-', 'Color', colors.blue, ...
    'LineWidth', 1.3, 'DisplayName', 'dm\_filtfilt');
plot(ax(1), x, 1000*u_control_reference, '-', ...
    'Color', colors.green, 'LineWidth', 1.2, ...
    'DisplayName', 'd\_r (full FEM)');
hold(ax(1), 'off')
grid(ax(1), 'on')
ylabel(ax(1), 'Displacement (mm)')
legend_handle = legend(ax(1), 'Location', 'best');
legend_handle.ItemHitFcn = @toggleSignalVisibility;

ax(2) = nexttile;
plot(ax(2), x, fm, '-', 'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm (measured force)');
grid(ax(2), 'on')
setForceYTicks(ax(2), fm)
xlabel(ax(2), 'Effective HS time (s)')
ylabel(ax(2), 'Force (N)')
legend_handle = legend(ax(2), 'Location', 'best');
legend_handle.ItemHitFcn = @toggleSignalVisibility;

title(layout, sprintf('Control-point displacement and force at %.4g m', ...
    fem_ref.experimental_column.height))
linkaxes(ax, 'x')
end

function setForceYTicks(ax, fm)
force_limit = max(abs(fm(isfinite(fm))));
if isempty(force_limit) || force_limit == 0
    return
end
tick_step = niceTickStep(force_limit/5);
force_limit = tick_step*ceil(force_limit/tick_step);
ylim(ax, [-force_limit force_limit])
yticks(ax, -force_limit:tick_step:force_limit)
end

function step = niceTickStep(raw_step)
base = 10^floor(log10(raw_step));
candidates = base*[1 2 5 10];
[~, idx] = min(abs(candidates-raw_step));
step = candidates(idx);
end

function plotFloorReferenceComparison(effective_time, u_test, ...
        u_reference, pause_enable)
active = pause_enable == 0;
if ~any(active)
    active = true(size(pause_enable));
end

x = effective_time(active);
u_test = u_test(active, :);
u_reference = u_reference(active, :);

colors = getPlotColors();
figure('Color', 'w', 'Name', 'HS numerical sub floor comparison');
layout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:3
    ax = nexttile;
    plot(ax, x, u_reference(:, floor_id), '--', ...
        'Color', colors.dark_green, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('x%d\\_r (full FEM)', floor_id));
    hold(ax, 'on')
    plot(ax, x, u_test(:, floor_id), '-', 'Color', colors.blue, ...
        'LineWidth', 1.2, ...
        'DisplayName', sprintf('x%d\\_n (numerical sub)', floor_id));
    hold(ax, 'off')
    grid(ax, 'on')
    ylabel(ax, sprintf('Floor %d (m)', floor_id))
    legend_handle = legend(ax, 'Location', 'best');
    legend_handle.ItemHitFcn = @toggleSignalVisibility;
    if floor_id == 3
        xlabel(ax, 'Effective HS time (s)')
    end
end
title(layout, 'Full FEM reference vs numerical sub floor response')
end

function plotResponseFrequencyContent(hs, fem_num, u_test, effective_time, ...
        pause_enable, dt)
active = pause_enable == 0;
if ~any(active)
    active = true(size(pause_enable));
end

selected_response = u_test(active, :);
selected_time = effective_time(active);
test_duration = selected_time(end) - selected_time(1);
if test_duration <= 0
    test_duration = hs.time(end)*hs.time_scale_factor;
end
ag_sample = interp1(hs.time, hs.ag, ...
    selected_time/hs.time_scale_factor, 'linear', 0);
unit_scale_response = hybrid_response_at_time_scale( ...
    hs, fem_num, fem_num.experimental_k, dt, 1);
plot_hs_response_frequency_content(hs, selected_response, ...
    unit_scale_response, 1/dt, 100, test_duration, ag_sample);
end

function toggleSignalVisibility(~, event)
ax = ancestor(event.Peer, 'axes');
x_limits = xlim(ax);
y_limits = ylim(ax);
if strcmp(event.Peer.Visible, 'on')
    event.Peer.Visible = 'off';
else
    event.Peer.Visible = 'on';
end
xlim(ax, x_limits);
ylim(ax, y_limits);
set(ax, 'XLimMode', 'manual', 'YLimMode', 'manual')
end

function y = filtfiltDm(dm, fs, cutoff_hz, order)
[b, a] = butter(order, cutoff_hz/(fs/2), 'low');
y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function colors = getPlotColors()
colors.green = hexToRgb('39BF5E');
colors.dark_green = hexToRgb('006B2E');
colors.blue = hexToRgb('007CA8');
colors.purple = hexToRgb('74058A');
colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hex_color)
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end
