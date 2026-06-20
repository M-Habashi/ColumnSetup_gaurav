%% THREE-STORY FRAME RESPONSE TO EARTHQUAKE EXCITATION
% Condensed 2-D frame FEM based on docs/work_done/frame_fem_definition.html. Column and
% beam and column bending, joint rotations, semi-rigid
% beam connections, and base rotational springs are represented.

clearvars -except outputVerificationFile;
clc;
close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(fileparts(script_dir)));
addpath(fullfile(fileparts(script_dir), 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));

%% INPUTS
% Earthquake record: 1 = El Centro,      2 = Northridge,
%                    3 = Kobe,           4 = Loma Prieta,
%                    5 = Chi-Chi,        6 = Imperial Valley,
%                    7 = Landers,        8 = Tabas,
%                    9 = San Fernando,  10 = Tohoku
earthquake_id = 4;

% Dimensionless multiplier applied to the selected acceleration record.
earthquake_scale = 1.0;

% Modal damping ratio applied to all three modes.
damping_ratio = 0.02;

[fem_data, fem_file, ~] = load_saved_result_file( ...
    project_root, fullfile('fem', 'ref'), false);
assert(isfield(fem_data, 'fem_ref'), ...
    'The selected file does not contain fem_ref.');
fem_ref = fem_data.fem_ref;
frame = fem_ref.frame;
beam_connection_k = frame.beam_connection_k;
base_rotation_k = frame.base_rotation_k;

%% UNIT CONSTANTS AND INPUT CHECKS
% The analysis uses only kg, N, mm, and s. Acceleration is converted to
% mm/s^2 for the analysis and divided by g0 only when it is plotted.
g0 = 9806.65;                       % gravitational acceleration [mm/s^2]

validateattributes(earthquake_id, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 10}, mfilename, 'earthquake_id');
validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'earthquake_scale');
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1}, mfilename, 'damping_ratio');

%% FRAME GEOMETRY AND MATERIAL
n_story = frame.n_story;
n_bay = frame.n_bay;
bay_width = frame.bay_width;         % [mm]
story_height = frame.story_height;   % [mm]
E = frame.E;                         % [N/mm^2]

%% AISC W-SECTION PROPERTIES
% Exact SAP2000 v26 AISC15 section properties [mm^4].
section = frame.section;

%% SAVED FRAME STIFFNESS
K = fem_ref.K;                                           % [N/mm]
frame_model = fem_ref.assembly;

%% LUMPED FLOOR MASS MATRIX
% The HTML level values are used numerically as physical lumped masses.
floor_mass_kg = fem_ref.floor_mass_kg;                    % [kg]
M_kg = diag(floor_mass_kg);                               % physical mass [kg]

% In an N-mm-s equation, 1 kg = 0.001 N*s^2/mm. This conversion makes the
% dynamic mass matrix exactly consistent with K [N/mm], acceleration
% [mm/s^2], and generalized force [N].
M = fem_ref.M;                                            % [N*s^2/mm]
influence = fem_ref.influence;

%% MODAL PROPERTIES AND DAMPING MATRIX
[modes, omega2] = eig(K, M, 'vector');
[omega, mode_order] = sort(sqrt(omega2));                 % [rad/s]
modes = modes(:, mode_order);

% Mass-normalize each mode using the consistent dynamic mass matrix.
for mode_id = 1:n_story
    modes(:, mode_id) = modes(:, mode_id) / ...
        sqrt(modes(:, mode_id)' * M * modes(:, mode_id));
end

frequency_hz = omega / (2*pi);                            % [Hz]
C = M * modes * diag(2*damping_ratio*omega) * modes' * M; % [N*s/mm]

assert(all(eig(M) > 0), 'The mass matrix must be positive definite.');
assert(norm(K-K', 'fro') < 1e-10*norm(K, 'fro'), ...
    'The stiffness matrix must be symmetric.');
assert(all(eig(K) > 0), 'The stiffness matrix must be positive definite.');
assert(size(frame_model.K_full, 1) > n_story, ...
    'The frame FEM must contain rotational DOFs before condensation.');

%% LOAD THE EARTHQUAKE
script_dir = fileparts(mfilename('fullpath'));
earthquake_file = fullfile(project_root, 'input_signals', 'earthquakes.mat');
assert(isfile(earthquake_file), 'Earthquake file not found: %s', earthquake_file);

record_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
record_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};
earthquake_data = load(earthquake_file, record_fields{earthquake_id});
record = earthquake_data.(record_fields{earthquake_id});

time = record(:, 1);                                      % [s]
ag = record(:, 2) * 1000 * earthquake_scale;              % [mm/s^2]

assert(size(record, 2) == 2, 'Earthquake record must contain [time, acceleration].');
assert(all(isfinite(record), 'all'), 'Earthquake record contains nonfinite values.');
assert(all(diff(time) > 0), 'Earthquake time values must be strictly increasing.');

%% EARTHQUAKE FORCE AND NEWMARK RESPONSE
% Relative-coordinate equation:
%   M*u_rel_ddot + C*u_rel_dot + K*u_rel = -M*r*ag
% M [N*s^2/mm] times ag [mm/s^2] gives force directly in N.
effective_force = -(M * influence) * ag';                 % [N]
[u_relative, ~, ~] = newmarkAverageAcceleration( ...
    time, M, C, K, effective_force);

assert(all(isfinite(u_relative), 'all'), 'The calculated response is not finite.');
if earthquake_scale == 0
    assert(max(abs(u_relative), [], 'all') < 1e-12, ...
        'A zero earthquake scale must produce zero displacement.');
end

%% REPORT MODEL PROPERTIES
fprintf('\nThree-story condensed frame FEM reference model\n');
fprintf('FEM file: %s\n', fem_file);
fprintf('Beam-column rotational stiffness: %s N*mm/rad\n', ...
    stiffnessText(beam_connection_k));
fprintf('Base rotational stiffness: %s N*mm/rad\n', ...
    stiffnessText(base_rotation_k));
fprintf('\nNATURAL FREQUENCIES OF THE BUILDING\n');
for mode_id = 1:n_story
    fprintf('  Mode %d: %.4f Hz\n', mode_id, frequency_hz(mode_id));
end
fprintf('\nPeak ground acceleration: %.4f g\n\n', max(abs(ag))/g0);
fprintf('PEAK RELATIVE FLOOR DISPLACEMENTS\n');
for floor_id = 1:n_story
    fprintf('  Floor %d: %.4f mm\n', floor_id, ...
        max(abs(u_relative(:, floor_id))));
end
fprintf('\n');

%% FIGURE 1: EARTHQUAKE AND RELATIVE FLOOR DISPLACEMENTS
figure('Color', 'w', 'Name', 'Earthquake and relative floor response');
response_layout = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(time, ag/g0, 'k-', 'LineWidth', 1.1);
ylabel('a_g (g)');
title(sprintf('%s earthquake (scale = %.3g)', ...
    record_names{earthquake_id}, earthquake_scale));
grid on;

floor_colors = lines(n_story);
for floor_id = 1:n_story
    nexttile;
    plot(time, u_relative(:, floor_id), 'Color', floor_colors(floor_id, :), ...
        'LineWidth', 1.1);
    ylabel(sprintf('Floor %d (mm)', floor_id));
    grid on;
end
xlabel('Time (s)');
title(response_layout, 'Ground acceleration and relative floor displacements');
subtitle(response_layout, sprintf('Natural frequencies: %.3f, %.3f, %.3f Hz', ...
    frequency_hz(1), frequency_hz(2), frequency_hz(3)));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% FIGURE 2: FRAME, MEMBER SECTIONS, DOFS, AND APPLIED LOADS
[~, peak_index] = max(abs(ag));

plotFrameModel(n_bay, n_story, bay_width, story_height, ...
    floor_mass_kg, ag(peak_index)/g0);

%% LOCAL FUNCTIONS
function value = stiffnessText(stiffness)
if isinf(stiffness)
    value = 'Inf (rigid)';
else
    value = sprintf('%.6g', stiffness);
end
end

function [u, v, a] = newmarkAverageAcceleration(time, M, C, K, force)
% Integrate M*a+C*v+K*u=force using beta=1/4 and gamma=1/2.
n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);                                 % [mm]
v = zeros(n_step, n_dof);                                 % [mm/s]
a = zeros(n_step, n_dof);                                 % [mm/s^2]
a(1, :) = (M \ (force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    dt = time(step) - time(step-1);
    a0 = 1/(beta*dt^2);
    a1 = gamma/(beta*dt);
    a2 = 1/(beta*dt);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = dt*(gamma/(2*beta)-1);

    effective_stiffness = K + a0*M + a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)' + a2*v(step-1, :)' + a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)' + a4*v(step-1, :)' + a5*a(step-1, :)');

    u(step, :) = (effective_stiffness \ effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)' - a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)' + dt*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end

function plotFrameModel(n_bay, n_story, bay_width, story_height, ...
        floor_mass_kg, peak_ag_g)
% Draw the structural idealization and the loads represented by the model.
figure('Color', 'w', 'Name', 'Three-story frame FEM model');
hold on;
axis equal;
axis off;

x = (0:n_bay)*bay_width;
y = (0:n_story)*story_height;
color_beam = [0.15, 0.45, 0.75];
color_ext = [0.85, 0.33, 0.10];
color_int = [0.20, 0.60, 0.30];

% Columns, colored by section.
for column_id = 1:(n_bay+1)
    column_color = color_int;
    if column_id == 1 || column_id == n_bay+1
        column_color = color_ext;
    end
    for story_id = 1:n_story
        plot(x(column_id)*[1, 1], y(story_id:story_id+1), '-', ...
            'Color', column_color, 'LineWidth', 3);
    end
end

% Beams and downward distributed gravity-load arrows.
for level_id = 1:n_story
    plot([x(1), x(end)], y(level_id+1)*[1, 1], '-', ...
        'Color', color_beam, 'LineWidth', 3);
    arrow_x = linspace(x(1)+0.35*bay_width, x(end)-0.35*bay_width, 9);
    arrow_length = 0.18*story_height;
    quiver(arrow_x, repmat(y(level_id+1)+arrow_length, size(arrow_x)), ...
        zeros(size(arrow_x)), -arrow_length*ones(size(arrow_x)), 0, ...
        'Color', [0.35, 0.35, 0.35], 'LineWidth', 1, 'MaxHeadSize', 0.8);
    level_weight_kgf = floor_mass_kg(level_id);
    level_weight_kip = level_weight_kgf*9.80665/4448.2216152605;
    text(x(end)+0.12*bay_width, y(level_id+1)+0.08*story_height, ...
        sprintf('W = %.2f kip (= %.0f kgf)', level_weight_kip, ...
        level_weight_kgf), 'Color', [0.25, 0.25, 0.25]);
end

% Fixed supports.
for column_id = 1:(n_bay+1)
    plot(x(column_id)+0.16*bay_width*[-1, 1], [0, 0], 'k-', 'LineWidth', 2);
    for hatch_id = -2:2
        hx = x(column_id)+hatch_id*0.055*bay_width;
        plot([hx-0.035*bay_width, hx], [-0.08*story_height, 0], 'k-');
    end
end

% Retained horizontal floor DOFs.
for floor_id = 1:n_story
    dof_y = y(floor_id+1);
    dof_arrow_y = dof_y-0.13*story_height;
    quiver(x(end)+0.05*bay_width, dof_arrow_y, 0.42*bay_width, 0, 0, ...
        'Color', [0.49, 0.18, 0.56], 'LineWidth', 1.8, 'MaxHeadSize', 0.7);
    text(x(end)+0.22*bay_width, dof_y-0.27*story_height, ...
        sprintf('u_%d', floor_id), 'Color', [0.49, 0.18, 0.56], ...
        'FontWeight', 'bold');
end

% Ground-acceleration arrow at the base.
ground_direction = sign(peak_ag_g);
if ground_direction == 0
    ground_direction = 1;
end
quiver(x(1)+0.9*bay_width, -0.30*story_height, ...
    ground_direction*1.2*bay_width, 0, 0, 'Color', 'k', ...
    'LineWidth', 2, 'MaxHeadSize', 0.6);
text(x(1)+1.5*bay_width, -0.46*story_height, ...
    sprintf('a_g at peak = %.3f g', peak_ag_g), ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Dummy handles make a compact section/load legend.
h_beam = plot(nan, nan, '-', 'Color', color_beam, 'LineWidth', 3);
h_ext = plot(nan, nan, '-', 'Color', color_ext, 'LineWidth', 3);
h_int = plot(nan, nan, '-', 'Color', color_int, 'LineWidth', 3);
h_gravity = plot(nan, nan, 'v', 'Color', [0.35, 0.35, 0.35], ...
    'MarkerFaceColor', [0.35, 0.35, 0.35]);
legend([h_beam, h_ext, h_int, h_gravity], ...
    {'W8x24 beams', 'W8x28 exterior columns', 'W8x35 interior columns', ...
     'Gravity load'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal');

xlim([-0.8*bay_width, x(end)+0.75*bay_width]);
ylim([-0.55*story_height, y(end)+0.45*story_height]);
title('Three-story frame: members, retained DOFs, and applied loads');
hold off;
end
