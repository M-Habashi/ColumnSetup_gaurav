function [metric_table, comparison] = compare_hs_test_to_reference( ...
        fem, recorded_data, earthquake_type, intensity_factor, ...
        time_scale_factor, force_sign)
%COMPARE_HS_TEST_TO_REFERENCE Compare recorded HS data with full FEM reference.
% Units:
%   recorded data: t [s], dm [mm], fm [N].
%   FEM/reference displacements are compared in [m].
%   J1 [ms]; J2-J7 [%].

if nargin < 6
    force_sign = 1.0;
end

data = loadRecordedData(recorded_data);
project_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'));
addpath(fullfile(project_folder, 'results_analysis'));

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
[u_test, effective_time] = replayRecordedHs(fm, pause_enable, dt, hs);
[u_reference, u_control_reference] = fullReferenceAtEffectiveTime( ...
    fem.ref, hs, effective_time, dt);
plotReferenceControlDisplacement(effective_time, dm, ...
    u_control_reference, pause_enable, fem.ref);

running = pause_enable == 0;
metric = validation_metrics();
u_control_reference_mm = 1000*u_control_reference;
values = [ ...
    metric.J1(dm(running), u_control_reference_mm(running), dt); ...
    metric.J2(dm(running), u_control_reference_mm(running)); ...
    metric.J3(dm(running), u_control_reference_mm(running)); ...
    metric.J4(u_test(running, 1), u_reference(running, 1)); ...
    metric.J5(u_test(running, 1), u_reference(running, 1)); ...
    metric.J6(u_test(running, 2), u_reference(running, 2)); ...
    metric.J7(u_test(running, 3), u_reference(running, 3))];

metric_table = table( ...
    ["Control-point delay"; ...
     "Control-point normalized RMS error"; ...
     "Control-point peak error"; ...
     "First-floor normalized RMS error"; ...
     "First-floor peak error"; ...
     "Second-floor normalized RMS error"; ...
     "Third-floor normalized RMS error"], ...
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
        'u_control_reference', u_control_reference);
end
end

function data = loadRecordedData(recorded_data)
if ischar(recorded_data) || isstring(recorded_data)
    data = load(recorded_data);
else
    data = recorded_data;
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
if isfield(fem, 'damping_ratio')
    hs.damping_ratio = fem.damping_ratio;
else
    hs.damping_ratio = 0.03;
end

[modes, omega2] = eig(fem_ref.K, fem_ref.M, 'vector');
[omega, order] = sort(sqrt(real(omega2)));
modes = real(modes(:, order));
for mode_id = 1:size(modes, 2)
    modes(:, mode_id) = modes(:, mode_id) ...
        /sqrt(modes(:, mode_id)'*fem_ref.M*modes(:, mode_id));
end
hs.C = fem_ref.M*modes*diag(2*hs.damping_ratio*omega)*modes'*fem_ref.M;

earthquakes = load(fullfile(project_folder, 'input_signals', ...
    'earthquakes.mat'), earthquake_type);
earthquake = earthquakes.(earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = intensity_factor*earthquake(:, 2);
hs.time_scale_factor = time_scale_factor;
hs.force_sign = force_sign;
end

function [u_test, effective_time] = replayRecordedHs(fm, pause_enable, dt, hs)
n = numel(fm);
state = [];
u_test = zeros(n, hs.n_floor);
effective_time = zeros(n, 1);
for step = 2:n
    [~, state] = step_HS(fm(step), pause_enable(step), dt, hs, state);
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
