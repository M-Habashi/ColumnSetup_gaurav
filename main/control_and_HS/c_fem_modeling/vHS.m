%% VIRTUAL HYBRID SIMULATION
%% Units
% Input FEM: geometry/displacement [m], K [N/m], M [kg], C [N*s/m].
% Earthquake acceleration [m/s^2], force [N]; plotted displacement [m].
% The Hybrid Simulation path uses the same step_HS function as Simulink.

clearvars -except outputVerificationFile fem_file_override; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

%% INPUTS
% earthquake_type options: 'el_centro', 'imperial_valley', 'northridge',
% 'kobe', 'loma_prieta', 'san_fernando', 'tabas', 'chi_chi', 'landers',
% 'tohoku'.
hs = struct( ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 1.0, ...
    'time_scale_factor', 1.0, ...
    'force_sign', 1.0);
k_exp_r = 1.0;

%% SAVED FEM AND HS SETUP
if exist('fem_file_override', 'var') && ~isempty(fem_file_override)
    [fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
        fem_file_override);
else
    [fem, fem_file, ~] = loadFemDefinition(project_root, false);
end
hs.fem_file = fem_file;

fem_num = fem.num;
fem_ref = fem.ref;
frame = fem_num.frame;
n_story = frame.n_story;
k_experimental = k_exp_r*fem_num.experimental_k;

validateattributes(k_exp_r, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<=', 1});

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
    hs.damping_ratio = 0.02;
end
[modes, omega2] = eig(fem_ref.K, fem_ref.M, 'vector');
[omega, order] = sort(sqrt(real(omega2)));
modes = real(modes(:, order));
for mode_id = 1:size(modes, 2)
    modes(:, mode_id) = modes(:, mode_id) ...
        /sqrt(modes(:, mode_id)'*fem_ref.M*modes(:, mode_id));
end
hs.C = fem_ref.M*modes*diag(2*hs.damping_ratio*omega)*modes'*fem_ref.M;
earthquakes = load(fullfile(project_root, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);

%% REFERENCE RESPONSE
model_time = hs.time;
real_time = model_time*hs.time_scale_factor;
ag = hs.ag;

reference_load = -(fem_ref.M*fem_ref.influence)*ag';
u_reference = newmarkAverageAcceleration(model_time, fem_ref.M, hs.C, ...
    fem_ref.K, reference_load);

%% VIRTUAL SPRING-FEEDBACK REFERENCE
K_coupled = fem_num.K;
K_coupled(interface_dof, interface_dof) = ...
    K_coupled(interface_dof, interface_dof) + k_experimental;
K_floor_floor = K_coupled(floor_dofs, floor_dofs);
K_floor_interface = K_coupled(floor_dofs, interface_dof);
K_interface_floor = K_coupled(interface_dof, floor_dofs);
K_interface_interface = K_coupled(interface_dof, interface_dof);
K_hybrid_reference = K_floor_floor - K_floor_interface ...
    *(K_interface_interface\K_interface_floor);
interface_from_floors = -(K_interface_interface\K_interface_floor);

%% HYBRID RESPONSE THROUGH THE SHARED STEP FUNCTION
hs_sample_dt = 1/2048;
n_hs_sample = ceil(real_time(end)/hs_sample_dt) + 1;
hs_real_time = (0:n_hs_sample-1)'*hs_sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(model_time, ag, hs_model_time, 'linear', 0);
numerical_load_sample = hs.ground_force_gain*ag_sample';
u_hybrid_reference_sample = newmarkAverageAcceleration(hs_model_time, ...
    hs.M, hs.C, K_hybrid_reference, numerical_load_sample);
interface_displacement_reference_sample = ...
    (interface_from_floors*u_hybrid_reference_sample')';
measured_force_sample = k_experimental*interface_displacement_reference_sample;

state = [];
u_num_floors_sample = zeros(numel(hs_real_time), n_story);
interface_displacement_sample = zeros(numel(hs_real_time), 1);
experimental_force_sample = zeros(numel(hs_real_time), 1);
dd_hs_sample = zeros(numel(hs_real_time), 1);

for step = 2:numel(hs_real_time)
    fm = measured_force_sample(step);
    [dd_hs_sample(step), state] = step_HS(fm, 0, hs_sample_dt, hs, state);
    u_num_floors_sample(step, :) = state(1:n_story)';
    interface_displacement_sample(step) = dd_hs_sample(step)/1000;
    experimental_force_sample(step) = fm;
end

u_num_floors = interp1(hs_real_time, u_num_floors_sample, real_time, ...
    'linear');
u_hybrid_reference = interp1(hs_real_time, u_hybrid_reference_sample, ...
    real_time, 'linear');
interface_displacement = interp1(hs_real_time, ...
    interface_displacement_sample, real_time, 'linear');
experimental_force = interp1(hs_real_time, experimental_force_sample, ...
    real_time, 'linear');

step_error = max(abs(u_num_floors-u_hybrid_reference), [], 'all');
reference_error = max(abs(u_num_floors-u_reference), [], 'all');
metric = validation_metrics();
J4 = metric.J4(u_num_floors(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_floors(:, 1), u_reference(:, 1));
J6 = metric.J6(u_num_floors(:, 2), u_reference(:, 2));
J7 = metric.J7(u_num_floors(:, 3), u_reference(:, 3));

fprintf('\n%s Hybrid Simulation partition\n', hs.earthquake_type);
fprintf('FEM file: %s\n', fem_file);
fprintf('Intensity factor: %.3g\n', hs.intensity_factor);
fprintf(['Time scale factor: %.3g; sample dt is unchanged and the ' ...
    'earthquake is stretched in real time\n'], hs.time_scale_factor);
fprintf('Experimental reduction factor: %.3f\n', k_exp_r);
fprintf('Reduced experimental stiffness k: %.6f N/m\n', k_experimental);
fprintf('Interface: horizontal force only; roller carries axial reaction\n');
fprintf('Maximum step_HS vs spring-reference floor difference: %.6e m\n', ...
    step_error);
fprintf('Maximum Hybrid Simulation vs full-reference floor difference: %.6e m\n', ...
    reference_error);
fprintf('Peak interface displacement: %.6f m\n', ...
    max(abs(interface_displacement)));
fprintf('Peak experimental force: %.6f N\n\n', max(abs(experimental_force)));
fprintf('J4 = %.2f%%, J5 = %.2f%%, J6 = %.2f%%, J7 = %.2f%%\n\n', ...
    J4, J5, J6, J7);

%% RESPONSE COMPARISON
floor_colors = lines(n_story);
figure('Color', 'w', 'Name', 'Reference and HS comparison');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    plot(ax, real_time, u_reference(:, floor_id), 'k--', 'LineWidth', 2.2, ...
        'DisplayName', 'Reference');
    hold(ax, 'on');
    plot(ax, real_time, u_num_floors(:, floor_id), '-', ...
        'Color', floor_colors(floor_id, :), 'LineWidth', 1.1, ...
        'DisplayName', 'Hybrid Simulation');
    hold(ax, 'off'); grid(ax, 'on');
    ylabel(ax, sprintf('Floor %d (m)', floor_id));
    if floor_id == 1, legend(ax, 'Location', 'best'); end
end
xlabel(ax, 'Real time (s)');
title(layout, sprintf('%s: reference and Hybrid Simulation response', ...
    hs.earthquake_type));
subtitle(layout, sprintf('Maximum hybrid-reference floor difference = %.3e m', ...
    reference_error));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% PARTITION GEOMETRY
frame_x = (0:frame.n_bay)*frame.bay_width;
frame_y = (0:frame.n_story)*frame.story_height;
interface_y = fem_num.interface.height;
figure('Color', 'w', 'Name', 'Numerical-experimental partition');
hold on;
for level_id = 2:numel(frame_y)
    plot([frame_x(1), frame_x(end)], frame_y(level_id)*[1 1], ...
        'k-', 'LineWidth', 3);
end
for column_id = 1:numel(frame_x)
    lower_y = 0;
    if column_id == 1, lower_y = interface_y; end
    plot(frame_x(column_id)*[1 1], [lower_y, frame_y(end)], ...
        'k-', 'LineWidth', 3);
end

for column_id = 2:numel(frame_x)
    base_x = frame_x(column_id);
    plot(base_x, 0, 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.4);
    spring_angle = linspace(0, 2.5*pi, 60);
    spring_radius = linspace(0.025, 0.10, numel(spring_angle))*frame.bay_width;
    plot(base_x+spring_radius.*cos(spring_angle), ...
        -0.08*frame.story_height+spring_radius.*sin(spring_angle), ...
        'k-', 'LineWidth', 1.2);
end
plot(frame_x(1)*[1 1], [0, interface_y], '-', ...
    'Color', [0.56 0.08 0], 'LineWidth', 6);
plot(frame_x(1), interface_y, 'v', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.56 0.08 0]);
quiver(frame_x(1)+0.5*frame.bay_width, interface_y, ...
    -0.35*frame.bay_width, 0, 0, 'Color', [0.56 0.08 0], ...
    'LineWidth', 1.8, 'MaxHeadSize', 0.8);
text(frame_x(1)+0.12*frame.bay_width, interface_y, ...
    'u_I; F_{exp}; vertical roller', ...
    'Color', [0.56 0.08 0], 'VerticalAlignment', 'bottom');
title('Hybrid partition: horizontal force only at the interface');
subtitle(['All joints: rotational DOF. Numerical bases: hinge + k_\theta. ' ...
    'Interface: vertical roller.']);
axis equal; axis off;
xlim([-0.45*frame.bay_width, frame_x(end)+0.45*frame.bay_width]);
ylim([-0.25*frame.story_height, frame_y(end)+0.35*frame.story_height]);
hold off;

function u = newmarkAverageAcceleration(time, M, C, K, force)
% Units: time [s], M [kg], C [N*s/m], K [N/m], force [N], output u [m].
n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);
v = zeros(n_step, n_dof);
a = zeros(n_step, n_dof);
a(1, :) = (M\(force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    dt = time(step)-time(step-1);
    a0 = 1/(beta*dt^2);
    a1 = gamma/(beta*dt);
    a2 = 1/(beta*dt);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = dt*(gamma/(2*beta)-1);

    effective_stiffness = K+a0*M+a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)'+a2*v(step-1, :)'+a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)'+a4*v(step-1, :)'+a5*a(step-1, :)');

    u(step, :) = (effective_stiffness\effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)'-a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)'+dt*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end
