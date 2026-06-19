%% THREE-STORY FRAME RESPONSE TO EARTHQUAKE EXCITATION
% Three-DOF shear-building FEM reference model based on
% frame_fem_definition.html. Column bending and shear flexibility are
% included. Floor responses are plotted as displacements relative to ground.

clear;
clc;
close all;

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

%% UNIT CONSTANTS AND INPUT CHECKS
% The analysis uses only kg, N, mm, and s. Acceleration is converted to
% mm/s^2 for the analysis and divided by g0 only when it is plotted.
g0 = 9806.65;                       % gravitational acceleration [mm/s^2]
ft_to_mm = 304.8;                   % [mm/ft]

validateattributes(earthquake_id, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 10}, mfilename, 'earthquake_id');
validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'earthquake_scale');
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1}, mfilename, 'damping_ratio');

%% FRAME GEOMETRY AND MATERIAL
n_story = 3;
n_bay = 3;
bay_width = 10.00 * ft_to_mm;       % [mm]
story_height = 6.67 * ft_to_mm;     % [mm]

E = 200000;                         % steel elastic modulus [N/mm^2]
nu = 0.30;                          % Poisson ratio [-]
G = E / (2 * (1 + nu));             % steel shear modulus [N/mm^2]

%% AISC W-SECTION PROPERTIES
% Metric properties from the AISC Shapes Database v16.0. Ix values in the
% database are reported in 10^6 mm^4. The web shear area is Av = d*tw.
% W8x24 is used for plotting the beams; beam stiffness is not included in
% this three-DOF shear-building idealization.
section.W8x24 = struct('d', 201, 'tw', 6.22, 'Ix', 34.4e6);  % [mm, mm, mm^4]
section.W8x28 = struct('d', 205, 'tw', 7.24, 'Ix', 40.8e6);  % [mm, mm, mm^4]
section.W8x35 = struct('d', 206, 'tw', 7.87, 'Ix', 52.9e6);  % [mm, mm, mm^4]

section.W8x28.Av = section.W8x28.d * section.W8x28.tw;       % [mm^2]
section.W8x35.Av = section.W8x35.d * section.W8x35.tw;       % [mm^2]

%% COLUMN AND STORY STIFFNESS INCLUDING SHEAR DEFORMATION
% For a fixed-fixed Timoshenko column:
%   phi = 12*E*Ix/(G*Av*L^2)
%   k    = 12*E*Ix/(L^3*(1 + phi))
% Each story contains two exterior W8x28 columns and two interior W8x35
% columns. Stiffness values are therefore entirely in N/mm.
[k_ext, k_ext_EB] = columnLateralStiffness( ...
    E, G, section.W8x28.Ix, section.W8x28.Av, story_height);
[k_int, k_int_EB] = columnLateralStiffness( ...
    E, G, section.W8x35.Ix, section.W8x35.Av, story_height);

k_story = 2 * k_ext + 2 * k_int;    % identical story stiffnesses [N/mm]
story_k = repmat(k_story, n_story, 1);

% Three-DOF shear-building stiffness matrix [N/mm].
K = [story_k(1) + story_k(2), -story_k(2),              0;
    -story_k(2),               story_k(2) + story_k(3), -story_k(3);
     0,                       -story_k(3),               story_k(3)];

%% LUMPED FLOOR MASS MATRIX
% The HTML level values are used numerically as physical lumped masses.
floor_mass_kg = [20121; 20121; 18426];                    % [kg]
M_kg = diag(floor_mass_kg);                               % physical mass [kg]

% In an N-mm-s equation, 1 kg = 0.001 N*s^2/mm. This conversion makes the
% dynamic mass matrix exactly consistent with K [N/mm], acceleration
% [mm/s^2], and generalized force [N].
M = M_kg / 1000;                                          % [N*s^2/mm]
influence = ones(n_story, 1);

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
assert(k_ext < k_ext_EB && k_int < k_int_EB, ...
    'Column shear flexibility must reduce the column stiffness.');

%% LOAD THE EARTHQUAKE
script_dir = fileparts(mfilename('fullpath'));
earthquake_file = fullfile(script_dir, '..', 'input_signals', 'earthquakes.mat');
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
fprintf('\nThree-story shear-building FEM reference model\n');
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
function [k_timoshenko, k_euler, phi] = columnLateralStiffness(E, G, Ix, Av, L)
% Return fixed-fixed column lateral stiffness with and without shear [N/mm].
phi = 12*E*Ix/(G*Av*L^2);
k_euler = 12*E*Ix/L^3;
k_timoshenko = k_euler/(1 + phi);
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
