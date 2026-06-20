%% NUMERICAL-EXPERIMENTAL SUBSTRUCTURE COMPARISON
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
project_root = fileparts(script_dir);
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

%% INPUTS AND SAVED FEM
earthquake_id = 1;
earthquake_scale = 1.0;
damping_ratio = 0.02;

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
k_experimental = fem_num.experimental_k;
K_reference = fem_ref.K;
M_reference = fem_ref.M;
K_numerical = fem_num.K;
M_numerical = fem_num.M;

validateattributes(earthquake_id, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 10});
validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1});

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
C_numerical = zeros(size(K_numerical));
C_numerical(floor_dofs, floor_dofs) = C_reference;

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
ag = record(:, 2)*1000*earthquake_scale;               % [mm/s^2]

reference_load = -(M_reference*fem_ref.influence)*ag'; % [N]
numerical_load = -(M_numerical*fem_num.influence)*ag'; % [N]

%% REFERENCE AND COUPLED TIME INTEGRATION
n_step = numel(time);
n_num_dof = size(K_numerical, 1);
u_reference = zeros(n_step, n_story);
v_reference = zeros(n_step, n_story);
a_reference = zeros(n_step, n_story);
u_num_exp = zeros(n_step, n_num_dof);
v_num_exp = zeros(n_step, n_num_dof);
a_num_exp = zeros(n_step, n_num_dof);
experimental_force = zeros(n_step, 1);

a_reference(1, :) = (M_reference\reference_load(:, 1))';
a_num_exp(1, floor_dofs) = a_reference(1, :);
beta = 1/4;
gamma = 1/2;

for step = 2:n_step
    dt = time(step)-time(step-1);
    c0 = 1/(beta*dt^2);
    c1 = gamma/(beta*dt);
    c2 = 1/(beta*dt);
    c3 = 1/(2*beta)-1;
    c4 = gamma/beta-1;
    c5 = dt*(gamma/(2*beta)-1);

    rhs_ref = reference_load(:, step) ...
        + M_reference*(c0*u_reference(step-1, :)' ...
        + c2*v_reference(step-1, :)'+c3*a_reference(step-1, :)') ...
        + C_reference*(c1*u_reference(step-1, :)' ...
        + c4*v_reference(step-1, :)'+c5*a_reference(step-1, :)');
    u_reference(step, :) = ...
        ((K_reference+c0*M_reference+c1*C_reference)\rhs_ref)';
    a_reference(step, :) = (c0*(u_reference(step, :)' ...
        - u_reference(step-1, :)')-c2*v_reference(step-1, :)' ...
        - c3*a_reference(step-1, :)')';
    v_reference(step, :) = (v_reference(step-1, :)' ...
        + dt*((1-gamma)*a_reference(step-1, :)' ...
        + gamma*a_reference(step, :)'))';

    rhs_num = numerical_load(:, step) ...
        + M_numerical*(c0*u_num_exp(step-1, :)' ...
        + c2*v_num_exp(step-1, :)'+c3*a_num_exp(step-1, :)') ...
        + C_numerical*(c1*u_num_exp(step-1, :)' ...
        + c4*v_num_exp(step-1, :)'+c5*a_num_exp(step-1, :)');

    % Exact linear solution of the horizontal force exchange. Adding k at
    % the interface is equivalent to applying -F_exp there with F_exp=k*u_I.
    effective_stiffness = K_numerical+c0*M_numerical+c1*C_numerical;
    effective_stiffness(interface_dof, interface_dof) = ...
        effective_stiffness(interface_dof, interface_dof)+k_experimental;
    u_num_exp(step, :) = (effective_stiffness\rhs_num)';
    experimental_force(step) = ...
        k_experimental*u_num_exp(step, interface_dof);
    a_num_exp(step, :) = (c0*(u_num_exp(step, :)' ...
        - u_num_exp(step-1, :)')-c2*v_num_exp(step-1, :)' ...
        - c3*a_num_exp(step-1, :)')';
    v_num_exp(step, :) = (v_num_exp(step-1, :)' ...
        + dt*((1-gamma)*a_num_exp(step-1, :)' ...
        + gamma*a_num_exp(step, :)'))';
end

u_num_floors = u_num_exp(:, floor_dofs);
maximum_error = max(abs(u_num_floors-u_reference), [], 'all');
metric = validation_metrics();
J4 = metric.J4(u_num_floors(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_floors(:, 1), u_reference(:, 1));
J6 = metric.J6(u_num_floors(:, 2), u_reference(:, 2));
J7 = metric.J7(u_num_floors(:, 3), u_reference(:, 3));

fprintf('\n%s numerical-experimental partition\n', record_names{earthquake_id});
fprintf('Numerical FEM: %s\n', numerical_file);
fprintf('Reference FEM: %s\n', reference_file);
fprintf('Experimental stiffness k: %.6f N/mm\n', k_experimental);
fprintf('Interface: horizontal force only; roller carries axial reaction\n');
fprintf('Maximum floor displacement difference: %.6e mm\n', maximum_error);
fprintf('Peak interface displacement: %.6f mm\n', ...
    max(abs(u_num_exp(:, interface_dof))));
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
    ylabel(ax, sprintf('Floor %d (mm)', floor_id));
    if floor_id == 1, legend(ax, 'Location', 'best'); end
end
xlabel(ax, 'Time (s)');
title(layout, sprintf('%s: reference and numerical-experimental response', ...
    record_names{earthquake_id}));
subtitle(layout, sprintf('Maximum floor difference = %.3e mm', maximum_error));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% PARTITION GEOMETRY
frame_x = (0:frame.n_bay)*frame.bay_width;
frame_y = (0:frame.n_story)*frame.story_height;
interface_y = fem_num.interface.height_mm;
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
subtitle('The roller carries the vertical reaction; no experimental axial load or moment');
axis equal; axis off;
xlim([-0.45*frame.bay_width, frame_x(end)+0.45*frame.bay_width]);
ylim([-0.15*frame.story_height, frame_y(end)+0.35*frame.story_height]);
hold off;
