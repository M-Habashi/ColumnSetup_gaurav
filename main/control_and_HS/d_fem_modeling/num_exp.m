%% NUMERICAL-EXPERIMENTAL SUBSTRUCTURE COMPARISON
%% Units
% Input FEM: geometry/displacement [m], K [N/m], M [kg], C [N*s/m].
% Earthquake acceleration [m/s^2], force [N]; plotted displacement [m].
% Load a saved numerical FEM and couple its retained interface translation
% to the specimen's measured scalar stiffness k.
%
% The experimental substructure returns horizontal restoring force only:
%   F_exp = k*u_I.
% The numerical interface roller carries the vertical reaction, so no axial
% load is transferred to the experiment. Interface moment is also omitted.
% The interface displacement is used directly; there is no half-drift or
% double-curvature factor of two.

clearvars -except outputVerificationFile; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

%% INPUTS
earthquake_id = 1;
earthquake_scale = 1.0;
damping_ratio = 0.02;
k_exp_r = 1.0;

%% SAVED FEM
[numerical_data, numerical_file, ~] = load_saved_result_file( ...
    project_root, fullfile('fem', 'num'), false);
assert(isfield(numerical_data, 'fem_num'), ...
    'The selected file does not contain fem_num.');
fem_num = numerical_data.fem_num;

reference_file = fullfile(project_root, 'saved_results', 'fem', 'ref', ...
    fem_num.reference_filename);
reference_data = load(reference_file, 'fem_ref');
fem_ref = reference_data.fem_ref;

frame = fem_num.frame;
n_story = frame.n_story;
floor_dofs = fem_num.floor_dofs;
interface_dof = fem_num.interface_dof;
k_experimental = k_exp_r*fem_num.experimental_k;
K_reference = fem_ref.K;
M_reference = fem_ref.M;
K_numerical = fem_num.K;

validateattributes(earthquake_id, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 10});
validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1});
validateattributes(k_exp_r, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<=', 1});

%% DAMPING
[modes, omega2] = eig(K_reference, M_reference, 'vector');
[omega, order] = sort(sqrt(omega2));
modes = modes(:, order);
for mode_id = 1:n_story
    modes(:, mode_id) = modes(:, mode_id)/ ...
        sqrt(modes(:, mode_id)'*M_reference*modes(:, mode_id));
end
C_reference = M_reference*modes*diag(2*damping_ratio*omega) ...
    *modes'*M_reference;

%% EARTHQUAKE INPUT
record_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
record_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};
earthquake_file = fullfile(project_root, 'input_signals', 'earthquakes.mat');
data = load(earthquake_file, record_fields{earthquake_id});
record = data.(record_fields{earthquake_id});
time = record(:, 1);
ag = record(:, 2)*earthquake_scale;                    % [m/s^2]

reference_load = -(M_reference*fem_ref.influence)*ag'; % [N]
numerical_mass = fem_num.M(floor_dofs, floor_dofs);
numerical_load = -(numerical_mass*ones(n_story, 1))*ag'; % [N]

%% MATLAB TIME INTEGRATION
% lsim integrates the equivalent continuous-time state-space systems.
simulation_time = time-time(1);
integration_dt = min(median(diff(simulation_time)), ...
    1/(20*max(omega/(2*pi))));
n_integration_interval = ceil(simulation_time(end)/integration_dt);
integration_time = linspace(0, simulation_time(end), ...
    n_integration_interval+1)';
zero = zeros(n_story);
identity = eye(n_story);

A_reference = [zero, identity; ...
    -M_reference\K_reference, -M_reference\C_reference];
B_reference = [zero; M_reference\identity];
reference_system = ss(A_reference, B_reference, ...
    [identity, zero], zero);
reference_load_fine = interp1(simulation_time, reference_load', ...
    integration_time, 'linear');
u_reference_fine = lsim(reference_system, reference_load_fine, ...
    integration_time);
u_reference = interp1(integration_time, u_reference_fine, ...
    simulation_time, 'linear');

% Add the experimental scalar stiffness at the massless interface, then
% statically condense that interface for the floor-only state-space model.
K_coupled = K_numerical;
K_coupled(interface_dof, interface_dof) = ...
    K_coupled(interface_dof, interface_dof)+k_experimental;
K_floor_floor = K_coupled(floor_dofs, floor_dofs);
K_floor_interface = K_coupled(floor_dofs, interface_dof);
K_interface_floor = K_coupled(interface_dof, floor_dofs);
K_interface_interface = K_coupled(interface_dof, interface_dof);
K_hybrid = K_floor_floor-K_floor_interface ...
    *(K_interface_interface\K_interface_floor);

A_hybrid = [zero, identity; ...
    -numerical_mass\K_hybrid, -numerical_mass\C_reference];
B_hybrid = [zero; numerical_mass\identity];
hybrid_system = ss(A_hybrid, B_hybrid, [identity, zero], zero);
numerical_load_fine = interp1(simulation_time, numerical_load', ...
    integration_time, 'linear');
u_num_floors_fine = lsim(hybrid_system, numerical_load_fine, ...
    integration_time);
u_num_floors = interp1(integration_time, u_num_floors_fine, ...
    simulation_time, 'linear');

interface_from_floors = -(K_interface_interface\K_interface_floor);
interface_displacement = (interface_from_floors*u_num_floors')';
experimental_force = k_experimental*interface_displacement;

maximum_error = max(abs(u_num_floors-u_reference), [], 'all');
metric = validation_metrics();
J4 = metric.J4(u_num_floors(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_floors(:, 1), u_reference(:, 1));
J6 = metric.J6(u_num_floors(:, 2), u_reference(:, 2));
J7 = metric.J7(u_num_floors(:, 3), u_reference(:, 3));

fprintf('\n%s numerical-experimental partition\n', record_names{earthquake_id});
fprintf('Numerical FEM: %s\n', numerical_file);
fprintf('Reference FEM: %s\n', reference_file);
fprintf('Experimental reduction factor: %.3f\n', ...
    k_exp_r);
fprintf('Reduced experimental stiffness k: %.6f N/m\n', k_experimental);
fprintf('Interface: horizontal force only; roller carries axial reaction\n');
fprintf('Maximum floor displacement difference: %.6e m\n', maximum_error);
fprintf('Peak interface displacement: %.6f m\n', ...
    max(abs(interface_displacement)));
fprintf('Peak experimental force: %.6f N\n\n', max(abs(experimental_force)));
fprintf('J4 = %.2f%%, J5 = %.2f%%, J6 = %.2f%%, J7 = %.2f%%\n\n', ...
    J4, J5, J6, J7);

%% RESPONSE COMPARISON
floor_colors = lines(n_story);
figure('Color', 'w', 'Name', 'Reference and num-exp comparison');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    plot(ax, time, u_reference(:, floor_id), 'k--', 'LineWidth', 2.2, ...
        'DisplayName', 'Reference');
    hold(ax, 'on');
    plot(ax, time, u_num_floors(:, floor_id), '-', ...
        'Color', floor_colors(floor_id, :), 'LineWidth', 1.1, ...
        'DisplayName', 'Numerical-experimental');
    hold(ax, 'off'); grid(ax, 'on');
    ylabel(ax, sprintf('Floor %d (m)', floor_id));
    if floor_id == 1, legend(ax, 'Location', 'best'); end
end
xlabel(ax, 'Time (s)');
title(layout, sprintf('%s: reference and numerical-experimental response', ...
    record_names{earthquake_id}));
subtitle(layout, sprintf('Maximum floor difference = %.3e m', maximum_error));
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

% Numerical column bases: a hinge rotation DOF connected to k_theta.
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
    'u_I; F_{exp}=k u_I; vertical roller', ...
    'Color', [0.56 0.08 0], 'VerticalAlignment', 'bottom');
title('Hybrid partition: horizontal force only at the interface');
subtitle(['All joints: rotational DOF. Numerical bases: hinge + k_\theta. ' ...
    'Interface: vertical roller.']);
axis equal; axis off;
xlim([-0.45*frame.bay_width, frame_x(end)+0.45*frame.bay_width]);
ylim([-0.25*frame.story_height, frame_y(end)+0.35*frame.story_height]);
hold off;
