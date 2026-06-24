%% VIRTUAL HYBRID SIMULATION
%% Units
% Input FEM: geometry/displacement [m], K [N/m], M [kg], C [N*s/m].
% Earthquake acceleration [m/s^2], force [N]; plotted displacement [m].
% The Hybrid Simulation path uses the same step_HS function as Simulink.

clearvars -except outputVerificationFile fem_file_override ...
    h_dd_dm_model_file_override; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', ...
    'id_utils'));

%% INPUTS
% earthquake_type options: 'el_centro', 'imperial_valley', 'northridge',
% 'kobe', 'loma_prieta', 'san_fernando', 'tabas', 'chi_chi', 'landers',
% 'tohoku'.
hs = struct( ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 1.0, ...
    'time_scale_factor', 10, ...
    'force_sign', 1.0);
k_exp_r = 1.0;
h_dd_dm_model_file = '';  % Empty loads newest saved_results/models file.
if exist('h_dd_dm_model_file_override', 'var') ...
        && ~isempty(h_dd_dm_model_file_override)
    h_dd_dm_model_file = h_dd_dm_model_file_override;
end

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
building_mode_frequency_hz = omega/(2*pi);
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
[H_dd_dm, h_dd_dm_pid_values, h_dd_dm_model_file] = ...
    loadHddDmModel(project_root, h_dd_dm_model_file);

%% SAMPLE GRID AND EARTHQUAKE INPUT
model_time = hs.time;
real_time = model_time*hs.time_scale_factor;
ag = hs.ag;
hs_sample_dt = 1/2048;
n_hs_sample = ceil(real_time(end)/hs_sample_dt) + 1;
hs_real_time = (0:n_hs_sample-1)'*hs_sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(model_time, ag, hs_model_time, 'linear', 0);

%% REFERENCE RESPONSE
reference_load_sample = -(fem_ref.M*fem_ref.influence)*ag_sample';
u_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    fem_ref.M, hs.C, fem_ref.K, reference_load_sample);

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
numerical_load_sample = hs.ground_force_gain*ag_sample';
u_hybrid_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
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
[u_hdddm_floors_sample, dd_hdddm_sample, dm_hdddm_sample, ...
    dc_hdddm_sample, experimental_force_hdddm_sample] = ...
    hybridResponseWithHddDm(hs, H_dd_dm, h_dd_dm_pid_values, ...
    k_experimental, hs_sample_dt);

u_num_floors = interp1(hs_real_time, u_num_floors_sample, real_time, ...
    'linear');
u_hdddm_floors = interp1(hs_real_time, u_hdddm_floors_sample, real_time, ...
    'linear');
u_reference = interp1(hs_real_time, u_reference_sample, real_time, ...
    'linear');
u_hybrid_reference = interp1(hs_real_time, u_hybrid_reference_sample, ...
    real_time, 'linear');
interface_displacement = interp1(hs_real_time, ...
    interface_displacement_sample, real_time, 'linear');
experimental_force = interp1(hs_real_time, experimental_force_sample, ...
    real_time, 'linear');
dd_hdddm = interp1(hs_real_time, dd_hdddm_sample, real_time, 'linear');
dm_hdddm = interp1(hs_real_time, dm_hdddm_sample, real_time, 'linear');
dc_hdddm = interp1(hs_real_time, dc_hdddm_sample, real_time, 'linear');
experimental_force_hdddm = interp1(hs_real_time, ...
    experimental_force_hdddm_sample, real_time, 'linear');
if abs(hs.time_scale_factor-1) < eps
    unit_scale_u_num_floors_sample = u_num_floors_sample;
else
    unit_scale_u_num_floors_sample = hybridResponseAtTimeScale( ...
        hs, fem_num, k_experimental, hs_sample_dt, 1);
end

step_error = max(abs(u_num_floors-u_hybrid_reference), [], 'all');
reference_error = max(abs(u_num_floors-u_reference), [], 'all');
reference_error_hdddm = max(abs(u_hdddm_floors-u_reference), [], 'all');
metric = validation_metrics();
J4 = metric.J4(u_num_floors(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_floors(:, 1), u_reference(:, 1));
J6 = metric.J6(u_num_floors(:, 2), u_reference(:, 2));
J7 = metric.J7(u_num_floors(:, 3), u_reference(:, 3));
J4_hdddm = metric.J4(u_hdddm_floors(:, 1), u_reference(:, 1));
J5_hdddm = metric.J5(u_hdddm_floors(:, 1), u_reference(:, 1));
J6_hdddm = metric.J6(u_hdddm_floors(:, 2), u_reference(:, 2));
J7_hdddm = metric.J7(u_hdddm_floors(:, 3), u_reference(:, 3));
colors = getPlotColors();

fprintf('\n%s Hybrid Simulation partition\n', hs.earthquake_type);
fprintf('FEM file: %s\n', fem_file);
fprintf('H_dd_dm model file: %s\n', h_dd_dm_model_file);
fprintf('FEM schema version: %d\n', fem.schema_version);
fprintf('Specimen name: %s\n', fem.specimen_name);
fprintf('Specimen file: %s\n', fem.specimen_file);
fprintf('Frame: %d stories, %d bays, bay width %.12g m, story height %.12g m\n', ...
    frame.n_story, frame.n_bay, frame.bay_width, frame.story_height);
fprintf('Frame E: %.12g Pa; beam connection k: %.12g N*m/rad\n', ...
    frame.E, frame.beam_connection_k);
fprintf('Base rotational stiffness: %.12g N*m/rad\n', ...
    frame.base_rotation_k);
fprintf('Section Ix [m^4]: W8x24 %.12g, W8x28 %.12g, W8x35 %.12g\n', ...
    frame.section.W8x24.Ix, frame.section.W8x28.Ix, ...
    frame.section.W8x35.Ix);
fprintf('Floor masses [kg]: %.12g, %.12g, %.12g\n', fem.floor_mass_kg);
fprintf('Damping ratio: %.6g\n', fem.damping_ratio);
natural_frequency_table = table((1:numel(building_mode_frequency_hz))', ...
    building_mode_frequency_hz(:), 'VariableNames', {'Mode', 'Frequency_Hz'});
disp('Natural frequencies')
disp(natural_frequency_table)
fprintf('Experimental column: %s, height %.12g m, E %.12g Pa, Ix %.12g m^4\n', ...
    fem_ref.experimental_column.shape, fem_ref.experimental_column.height, ...
    fem_ref.experimental_column.E, fem_ref.experimental_column.section.Ix);
fprintf('Interface height: %.12g m; DOFs floors [%s], interface %d\n', ...
    fem_num.interface.height, num2str(floor_dofs), interface_dof);
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
fprintf(['Maximum num*H_dd_dm*exp vs full-reference floor ' ...
    'difference: %.6e m\n'], reference_error_hdddm);
fprintf('Peak interface displacement: %.6f m\n', ...
    max(abs(interface_displacement)));
fprintf('Peak experimental force: %.6f N\n\n', max(abs(experimental_force)));
validation_metric_table = table({'J4'; 'J5'; 'J6'; 'J7'}, ...
    [J4; J5; J6; J7], ...
    [J4_hdddm; J5_hdddm; J6_hdddm; J7_hdddm], ...
    {'First-floor normalized RMS error'; ...
    'First-floor peak error'; ...
    'Second-floor normalized RMS error'; ...
    'Third-floor normalized RMS error'}, ...
    'VariableNames', {'Metric', 'NumExpPercent', ...
    'NumHddDmExpPercent', 'Description'});
disp('Validation metrics')
disp(validation_metric_table)
fprintf('num*exp: J4 = %.2f%%, J5 = %.2f%%, J6 = %.2f%%, J7 = %.2f%%\n', ...
    J4, J5, J6, J7);
fprintf(['num*H_dd_dm*exp: J4 = %.2f%%, J5 = %.2f%%, ' ...
    'J6 = %.2f%%, J7 = %.2f%%\n\n'], ...
    J4_hdddm, J5_hdddm, J6_hdddm, J7_hdddm);

%% RESPONSE COMPARISON
figure('Color', 'w', 'Name', 'Reference and HS comparison');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    plot(ax, real_time, u_reference(:, floor_id), 'k--', 'LineWidth', 2.2, ...
        'DisplayName', 'Reference');
    hold(ax, 'on');
    plot(ax, real_time, u_num_floors(:, floor_id), '-', ...
        'Color', colors.blue, 'LineWidth', 1.1, ...
        'DisplayName', 'num*exp');
    plot(ax, real_time, u_hdddm_floors(:, floor_id), '-', ...
        'Color', colors.copperwood, 'LineWidth', 1.1, ...
        'DisplayName', 'num*H_{dd,dm}*exp');
    hold(ax, 'off'); grid(ax, 'on');
    ylabel(ax, sprintf('Floor %d (m)', floor_id));
    if floor_id == 1, makeLegendToggle(ax); end
end
xlabel(ax, 'Real time (s)');
title(layout, sprintf('%s: reference and Hybrid Simulation response', ...
    hs.earthquake_type));
subtitle(layout, sprintf(['Max floor error: num*exp = %.3e m, ' ...
    'num*H_{dd,dm}*exp = %.3e m'], reference_error, ...
    reference_error_hdddm));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% CONTROL CHECK
figure('Color', 'w', 'Name', 'H_dd_dm control check');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
plot(ax, real_time, dd_hdddm, 'k--', 'LineWidth', 2.2, ...
    'DisplayName', 'dd desired displacement');
hold(ax, 'on');
plot(ax, real_time, dc_hdddm, '-', 'Color', colors.copperwood, ...
    'LineWidth', 1.0, 'DisplayName', 'dc command displacement');
plot(ax, real_time, dm_hdddm, '-', 'Color', colors.blue, ...
    'LineWidth', 1.0, 'DisplayName', 'dm measured displacement');
addPeakLines(ax, dm_hdddm, 'dm', colors.blue, 'mm');
addPeakLines(ax, dc_hdddm, 'dc', colors.copperwood, 'mm');
hold(ax, 'off'); grid(ax, 'on');
ylabel(ax, 'Displacement (mm)');
makeLegendToggle(ax);

ax = nexttile;
plot(ax, real_time, experimental_force_hdddm, '-', ...
    'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm measured force');
hold(ax, 'on');
addPeakLines(ax, experimental_force_hdddm, 'fm', colors.purple, 'N');
hold(ax, 'off'); grid(ax, 'on');
ylabel(ax, 'Force (N)');
xlabel(ax, 'Real time (s)');
makeLegendToggle(ax);
title(layout, 'num*H_{dd,dm}*exp control check');
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% RESPONSE FREQUENCY CONTENT
fft_fmax_hz = 100;
fft_fs_hz = 1/hs_sample_dt;
fft_test_duration_s = hs.time(end)*hs.time_scale_factor;
fft_mode_frequency_hz = building_mode_frequency_hz;
fft_mode_frequency_hz = fft_mode_frequency_hz( ...
    fft_mode_frequency_hz <= fft_fmax_hz);
[Y_ag_selected, freq_ag_selected] = fft_c(ag_sample, fft_fs_hz, ...
    fft_fmax_hz);
figure('Color', 'w', 'Name', 'HS response frequency content');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    yyaxis(ax, 'left');
    [Y_unit, freq_unit] = fft_c(unit_scale_u_num_floors_sample(:, floor_id), ...
        fft_fs_hz, fft_fmax_hz);
    [Y_selected, freq_selected] = fft_c(u_num_floors_sample(:, floor_id), ...
        fft_fs_hz, fft_fmax_hz);
    plot(ax, freq_unit, abs(Y_unit), '-', 'Color', [0.55 0.55 0.55], ...
        'LineWidth', 1.0, 'DisplayName', 'Time scale = 1');
    hold(ax, 'on');
    plot(ax, freq_selected, abs(Y_selected), '-', 'Color', [0 0.486 0.659], ...
        'LineWidth', 1.2, 'DisplayName', sprintf('Selected = %.3g', ...
        hs.time_scale_factor));
    for mode_id = 1:numel(fft_mode_frequency_hz)
        xline(ax, fft_mode_frequency_hz(mode_id), 'k--', ...
            'HandleVisibility', 'off', 'LineWidth', 0.8);
    end
    ylabel(ax, sprintf('|Floor %d| (m)', floor_id));

    yyaxis(ax, 'right');
    area(ax, freq_ag_selected, abs(Y_ag_selected), ...
        'FaceColor', [0.9 0.1 0.1], 'FaceAlpha', 0.18, ...
        'EdgeColor', 'none', 'DisplayName', 'Selected earthquake');
    ylabel(ax, '|ag(f)| (m/s^2)');
    ax.YAxis(1).Color = [0 0 0];
    ax.YAxis(2).Color = [0.7 0 0];
    hold(ax, 'off'); grid(ax, 'on');
    xlim(ax, [0 fft_fmax_hz]);
    if floor_id == 1, makeLegendToggle(ax); end
end
xlabel(ax, 'Frequency (Hz)');
title(layout, sprintf(['%s: response frequency content; test duration = ' ...
    '%.2f s'], hs.earthquake_type, fft_test_duration_s));
subtitle(layout, ['Hybrid Simulation floor response, one-sided FFT ' ...
    'amplitude; dashed lines = modal frequencies']);
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

%% IDEAL-SPECIMEN HYBRID STABILITY
hybrid_margin_frequency_hz = [0.1, 80];
A_num = [zeros(hs.n_floor), eye(hs.n_floor); -hs.M\hs.K, -hs.M\hs.C];
B_num = [zeros(hs.n_floor, 1); ...
    hs.M\(hs.force_to_floor*hs.force_sign)];
C_num = [hs.interface_from_floor, zeros(1, hs.n_floor)];
D_num = hs.interface_from_force*hs.force_sign;
H_num = ss(A_num, B_num, C_num, D_num);
H_exp = k_experimental;
hybrid_open_loop = -minreal(H_num*H_exp);
[~, ~, hybrid_ncf_margin] = custom_stability_margins( ...
    hybrid_open_loop, hybrid_margin_frequency_hz);
hybrid_margins = allmargin(hybrid_open_loop);
hybrid_delay_margin = min([hybrid_margins.DelayMargin(:); Inf]);

fprintf('Ideal-specimen hybrid stability margins\n');
fprintf('Open loop: -H_num*H_exp, H_exp = %.6f N/m\n', H_exp);
fprintf('Margin frequency range: %.6g to %.6g Hz\n', ...
    hybrid_margin_frequency_hz);
fprintf('Delay margin: %.6f s\n', hybrid_delay_margin);
fprintf('NCF margin: %.6f\n\n', hybrid_ncf_margin);

function [H_dd_dm, pid_values, model_file] = loadHddDmModel(project_root, ...
    model_file)
% Units: transfer functions map dd [mm] to dm [mm].
if isempty(model_file)
    model_dir = fullfile(project_root, 'saved_results', 'models');
    files = dir(fullfile(model_dir, '*.mat'));
    if isempty(files)
        error('vHS:MissingHddDmModel', ['No saved H_dd_dm model was ' ...
            'found in %s. Run control_and_HS\\b_system_id\\sys_id.m ' ...
            'first, or set h_dd_dm_model_file in vHS.m.'], model_dir)
    end
    [~, order] = sort([files.datenum], 'descend');
    files = files(order);
    for file_id = 1:numel(files)
        candidate = fullfile(files(file_id).folder, files(file_id).name);
        names = {whos('-file', candidate).name};
        if any(strcmp(names, 'H_dd_dm'))
            model_file = candidate;
            break
        end
    end
end

if isempty(model_file)
    error('vHS:MissingHddDmModel', ['No saved model file containing ' ...
        'H_dd_dm was found. Run control_and_HS\\b_system_id\\sys_id.m ' ...
        'first, or set h_dd_dm_model_file in vHS.m.'])
end

model = load(model_file, 'H_dd_dm', 'pid_values');
H_dd_dm = model.H_dd_dm;
if isfield(model, 'pid_values')
    pid_values = model.pid_values;
else
    pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
end

function [u_num_floors_sample, dd_sample, dm_sample, dc_sample, ...
        force_sample] = hybridResponseWithHddDm(hs, H_dd_dm, pid_values, ...
        k_experimental, hs_sample_dt)
% Units: dd/dm/dc [mm], force [N], floor displacement [m].
hdddm = discreteSiso(H_dd_dm, hs_sample_dt);
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, hs_sample_dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
controller = discreteSiso(digital_controller, hs_sample_dt);

n_step = ceil(hs.time(end)*hs.time_scale_factor/hs_sample_dt) + 1;
u_num_floors_sample = zeros(n_step, hs.n_floor);
dd_sample = zeros(n_step, 1);
dm_sample = zeros(n_step, 1);
dc_sample = zeros(n_step, 1);
force_sample = zeros(n_step, 1);
num_state = [];
for step = 2:n_step
    dm_sample(step) = outputDiscreteSiso(hdddm);
    force_sample(step) = k_experimental*dm_sample(step)/1000;
    [dd_sample(step), num_state] = step_HS(force_sample(step), 0, ...
        hs_sample_dt, hs, num_state);
    dc_sample(step) = outputDiscreteSiso(controller, ...
        dd_sample(step)-dm_sample(step));
    hdddm = updateDiscreteSiso(hdddm, dd_sample(step));
    controller = updateDiscreteSiso(controller, dd_sample(step)-dm_sample(step));
    u_num_floors_sample(step, :) = num_state(1:hs.n_floor)';
end
end

function u_num_floors_sample = hybridResponseAtTimeScale( ...
    hs, fem_num, k_experimental, hs_sample_dt, time_scale_factor)
% Units: time [s], displacement [m], stiffness [N/m].
fem_file_info = dir(hs.fem_file);
fem_file_stamp = 0;
if ~isempty(fem_file_info)
    fem_file_stamp = fem_file_info.datenum;
end
cache_key = sprintf('%s|%.17g|%.17g|%.17g|%.17g|%.17g|%s', ...
    hs.earthquake_type, hs.intensity_factor, time_scale_factor, ...
    k_experimental, hs_sample_dt, fem_file_stamp, hs.fem_file);
persistent cache
if ~isempty(cache)
    hit = find(strcmp({cache.key}, cache_key), 1);
    if ~isempty(hit)
        u_num_floors_sample = cache(hit).u_num_floors_sample;
        return
    end
end

hs.time_scale_factor = time_scale_factor;
model_time = hs.time;
real_time = model_time*hs.time_scale_factor;
ag = hs.ag;
n_hs_sample = ceil(real_time(end)/hs_sample_dt) + 1;
hs_real_time = (0:n_hs_sample-1)'*hs_sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(model_time, ag, hs_model_time, 'linear', 0);

floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
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

numerical_load_sample = hs.ground_force_gain*ag_sample';
u_hybrid_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    hs.M, hs.C, K_hybrid_reference, numerical_load_sample);
interface_displacement_reference_sample = ...
    (interface_from_floors*u_hybrid_reference_sample')';
measured_force_sample = k_experimental*interface_displacement_reference_sample;

state = [];
u_num_floors_sample = zeros(numel(hs_real_time), hs.n_floor);
for step = 2:numel(hs_real_time)
    [~, state] = step_HS(measured_force_sample(step), 0, hs_sample_dt, ...
        hs, state);
    u_num_floors_sample(step, :) = state(1:hs.n_floor)';
end

entry.key = cache_key;
entry.u_num_floors_sample = u_num_floors_sample;
cache = [cache, entry];
end

function system = discreteSiso(system_model, sample_time)
% Units: sample_time [s].
if get(system_model, 'Ts') == 0
    system_model = c2d(system_model, sample_time, 'zoh');
elseif abs(get(system_model, 'Ts')-sample_time) > 10*eps(sample_time)
    system_model = d2d(system_model, sample_time, 'zoh');
end
system_model = ss(system_model);
[system.A, system.B, system.C, system.D] = ssdata(system_model);
system.x = zeros(size(system.A, 1), 1);
system.u = 0;
end

function y = outputDiscreteSiso(system, u)
% Units: scalar input/output use the system model units.
if nargin < 2
    u = system.u;
end
y = system.C*system.x + system.D*u;
y = y(1);
end

function system = updateDiscreteSiso(system, u)
% Units: scalar input uses the system model input units.
system.x = system.A*system.x + system.B*u;
system.u = u;
end

function addPeakLines(ax, signal, label, color, unit_name)
% Units: signal units are shown by unit_name.
max_value = max(signal);
min_value = min(signal);
yline(ax, max_value, '--', sprintf('%s max = %.6g %s', ...
    label, max_value, unit_name), 'Color', color, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
yline(ax, min_value, '--', sprintf('%s min = %.6g %s', ...
    label, min_value, unit_name), 'Color', color, ...
    'HandleVisibility', 'off', 'LabelHorizontalAlignment', 'left');
end

function makeLegendToggle(ax)
legend_handle = legend(ax, 'Location', 'best');
legend_handle.ItemHitFcn = @toggleLegendItem;
end

function toggleLegendItem(~, event)
target = event.Peer;
if strcmp(target.Visible, 'on')
    target.Visible = 'off';
else
    target.Visible = 'on';
end
end

function colors = getPlotColors()
% Units: RGB outputs are dimensionless.
colors.green = hexToRgb('39BF5E');
colors.black = [0 0 0];
colors.blue = hexToRgb('007CA8');
colors.red = hexToRgb('901500');
colors.purple = hexToRgb('74058A');
colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hex_color)
% Units: hexadecimal input and RGB output are dimensionless.
rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end

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
