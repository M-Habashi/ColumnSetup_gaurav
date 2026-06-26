function [metric_table, comparison] = compare_hs_test_to_reference( ...
        fem, recorded_data, earthquake_type, intensity_factor, ...
        time_scale_factor, force_sign)
%COMPARE_HS_TEST_TO_REFERENCE Compare recorded HS data with full FEM reference.
% Units:
%   recorded data: t [s], dm [mm], fm [N].
%   FEM/reference displacements are compared in [m].
%   J1 [ms]; J2-J7 [%].

project_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'));
addpath(fullfile(project_folder, 'results_analysis'));

if nargin < 2
    recorded_data = [];
end
data = loadRecordedData(recorded_data, project_folder);
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
fem = loadFemData(fem, data, project_folder);
[earthquake_type, intensity_factor, time_scale_factor, force_sign] = ...
    getComparisonInputs(data, nargin, earthquake_type, intensity_factor, ...
    time_scale_factor, force_sign);

t = data.t(:);
dm = data.dm(:);
fm = data.fm(:);
if isfield(data, 'dt')
    dt = data.dt;
else
    dt = mean(diff(t));
end
pause_enable = getPauseEnable(data, numel(t));
n = min([numel(t), numel(dm), numel(fm), numel(pause_enable)]);
t = t(1:n);
dm = dm(1:n);
fm = fm(1:n);
pause_enable = pause_enable(1:n);

hs = buildHsModel(fem, earthquake_type, intensity_factor, ...
    time_scale_factor, force_sign, project_folder);
[u_test, u_control_test_mm, effective_time] = replayRecordedHs( ...
    fm, pause_enable, dt, hs);
[u_reference, u_control_reference] = fullReferenceAtEffectiveTime( ...
    fem.ref, hs, effective_time, dt);
plotReferenceControlDisplacement(effective_time, dm, ...
    u_control_reference, pause_enable, fem.ref);
plotFloorReferenceComparison(effective_time, u_test, u_reference, pause_enable);

running = pause_enable == 0;
metric = validation_metrics();
u_control_reference_mm = 1000*u_control_reference;
% J1-J3 compare measured dm to the replayed numerical control point.
% J4-J6 compare replayed numerical floor responses to the full FEM floors.
% J7 compares measured dm to the full FEM control point as NMSE.
values = [ ...
    metric.J1(dm(running), u_control_test_mm(running), dt); ...
    metric.J2(dm(running), u_control_test_mm(running)); ...
    metric.J3(dm(running), u_control_test_mm(running)); ...
    metric.J4(u_test(running, 1), u_reference(running, 1)); ...
    metric.J5(u_test(running, 2), u_reference(running, 2)); ...
    metric.J6(u_test(running, 3), u_reference(running, 3)); ...
    metric.J7(dm(running), u_control_reference_mm(running))];

metric_table = table( ...
    ["dm vs replayed numerical control-point delay"; ...
     "dm vs replayed numerical control-point normalized RMS error"; ...
     "dm vs replayed numerical control-point peak error"; ...
     "First-floor normalized RMS error"; ...
     "Second-floor normalized RMS error"; ...
     "Third-floor normalized RMS error"; ...
     "dm vs full FEM control-point NMSE"], ...
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
        'u_control_test_mm', u_control_test_mm, ...
        'u_control_reference', u_control_reference);
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
else
    data = recorded_data;
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

% Keep this duplicated helper synced with control_and_HS\d_HS\vHS.m.
% If the full FEM control-point reconstruction changes here, update both files.
function u_control = referenceControlDisplacement(fem_ref, floor_response)
assembly = fem_ref.assembly;
retained = assembly.retained_dofs(:);
internal = assembly.internal_dofs(:);
K_full = assembly.K_full;
q_internal = -(K_full(internal, internal) ...
    \(K_full(internal, retained)*floor_response'))';

n = size(floor_response, 1);
q = zeros(n, size(K_full, 1));
q(:, retained) = floor_response;
q(:, internal) = q_internal;

height = fem_ref.experimental_column.height;
story_height = fem_ref.frame.story_height;
xi = height/story_height;
N1 = 1 - 3*xi^2 + 2*xi^3;
N2 = story_height*(xi - 2*xi^2 + xi^3);
N3 = 3*xi^2 - 2*xi^3;
N4 = story_height*(-xi^2 + xi^3);

joint_rotation = assembly.joint_rotation_dofs;
theta_base = getDofSignal(q, joint_rotation(1, 1));
theta_floor = getDofSignal(q, joint_rotation(1, 2));
u_control = N1*zeros(n, 1) - N2*theta_base ...
    + N3*floor_response(:, 1) - N4*theta_floor;
end

function value = getDofSignal(q, dof)
if dof > 0
    value = q(:, dof);
else
    value = zeros(size(q, 1), 1);
end
end

function plotReferenceControlDisplacement(effective_time, dm, ...
        u_control_reference, pause_enable, fem_ref)
active = pause_enable == 0;
if ~any(active)
    active = true(size(pause_enable));
end

x = effective_time(active);
dm = dm(active);
u_control_reference = u_control_reference(active);

colors = getPlotColors();
figure('Color', 'w', 'Name', 'HS analytical FEM reference comparison');
plot(x, dm, '-', 'Color', colors.blue, 'LineWidth', 1.1, ...
    'DisplayName', 'dm measured displacement');
hold on
plot(x, 1000*u_control_reference, 'k-', 'LineWidth', 2.0, ...
    'DisplayName', 'analytical FEM reference at control point');
hold off
grid on
xlabel('Effective HS time (s)')
ylabel('Displacement (mm)')
title(sprintf('Analytical FEM reference vs measured displacement at %.4g m', ...
    fem_ref.experimental_column.height))
legend_handle = legend('Location', 'best');
legend_handle.ItemHitFcn = @toggleSignalVisibility;
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
figure('Color', 'w', 'Name', 'HS replayed numerical floor comparison');
layout = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:3
    ax = nexttile;
    plot(ax, x, u_reference(:, floor_id), 'k--', 'LineWidth', 2.2, ...
        'DisplayName', 'full FEM reference');
    hold(ax, 'on')
    plot(ax, x, u_test(:, floor_id), '-', 'Color', colors.copperwood, ...
        'LineWidth', 1.2, 'DisplayName', 'replayed numerical');
    hold(ax, 'off')
    grid(ax, 'on')
    ylabel(ax, sprintf('Floor %d (m)', floor_id))
    if floor_id == 1
        legend_handle = legend(ax, 'Location', 'best');
        legend_handle.ItemHitFcn = @toggleSignalVisibility;
    end
    if floor_id == 3
        xlabel(ax, 'Effective HS time (s)')
    end
end
title(layout, 'Full FEM reference vs replayed numerical floor response')
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

function colors = getPlotColors()
colors.blue = hexToRgb('007CA8');
colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hex_color)
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end

function u = newmarkAverageAcceleration(time, M, C, K, force)
n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);
v = zeros(n_step, n_dof);
a = zeros(n_step, n_dof);
a(1, :) = (M\(force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    h = time(step)-time(step-1);
    a0 = 1/(beta*h^2);
    a1 = gamma/(beta*h);
    a2 = 1/(beta*h);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = h*(gamma/(2*beta)-1);

    effective_stiffness = K+a0*M+a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)'+a2*v(step-1, :)'+a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)'+a4*v(step-1, :)'+a5*a(step-1, :)');

    u(step, :) = (effective_stiffness\effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)'-a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)'+h*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end
