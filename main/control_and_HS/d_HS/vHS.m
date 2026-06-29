%% VIRTUAL HYBRID SIMULATION
%% Units
% Input FEM: geometry/displacement [m], K [N/m], M [kg], C [N*s/m].
% Earthquake acceleration [m/s^2], force [N]; plotted displacement [m].
% The Hybrid Simulation path uses the same step_HS function as Simulink.

clearvars -except outputVerificationFile fem_file_override ...
    specimen_file_override exp_specimen_file_override ...
    h_dc_dm_model_file_override pid_gain_override ...
    delay_comp_file_override PID_scale; ...
    clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'utils_HS'));
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
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
    'intensity_factor', 0.025, ...
    'time_scale_factor', 1, ...
    'force_sign', 1.0);
PID_scale = 0.9;
validateattributes(PID_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite'}, mfilename, 'PID_scale');
k_exp_r =1;
hs_sample_dt = 1/2048;
if exist('exp_specimen_file_override', 'var') ...
        && ~isempty(exp_specimen_file_override)
    [specimen, specimen_file, specimen_name] = load_saved_result_file( ...
        project_root, 'specimens', false, exp_specimen_file_override);
elseif exist('specimen_file_override', 'var') ...
        && ~isempty(specimen_file_override)
    [specimen, specimen_file, specimen_name] = load_saved_result_file( ...
        project_root, 'specimens', false, specimen_file_override);
else
    [specimen, specimen_file, specimen_name] = load_saved_result_file( ...
        project_root, 'specimens');
end
assert(isfield(specimen, 'k'), ...
    'The selected specimen file must contain lateral stiffness k.');
specimen_si = specimen_params_si(specimen);
if exist('h_dc_dm_model_file_override', 'var') ...
        && ~isempty(h_dc_dm_model_file_override)
    h_dc_dm_model_file = h_dc_dm_model_file_override;
else
    [~, h_dc_dm_model_file, ~] = load_saved_result_file( ...
        project_root, 'exp_tf');
end
% Override the saved PID used to form PID_H_dc_dm = feedback(PID*H_dc_dm, 1).
% Leave [] to use pid_values saved by sys_id.m.
% Use struct('P', 0.6, 'I', 5, 'D', 0.0015, 'derivative_filter_N', 512)
% or [0.6 5 0.0015 512] to test a different controller.
% Command Window print after running vHS:
% fprintf('P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', pid_h_dc_dm_values.P, pid_h_dc_dm_values.I, pid_h_dc_dm_values.D, pid_h_dc_dm_values.derivative_filter_N)
if ~exist('pid_gain_override', 'var')
    pid_gain_override = [0.15 20 0.0015 512];
end
% Phase-lead compensator used on the Hybrid Simulation numerical dd command.
if exist('delay_comp_file_override', 'var') ...
        && ~isempty(delay_comp_file_override)
    [delay_comp_data, delay_comp_file, delay_comp_name] = ...
        load_saved_result_file(project_root, 'delay_comp', false, ...
        delay_comp_file_override);
else
    [delay_comp_data, delay_comp_file, delay_comp_name] = ...
        load_saved_result_file(project_root, 'delay_comp');
end
delay_comp_tf = delay_comp_data.delay_comp_tf;
delay_comp_tf_discrete = c2d(delay_comp_tf, hs_sample_dt, 'tustin');
phase_lead = [];
if isfield(delay_comp_data, 'phase_lead')
    phase_lead = normalizePhaseLeadConfig(delay_comp_data.phase_lead);
end
phase_lead_enabled = isempty(phase_lead) || phase_lead.enabled;

%% SAVED FEM AND HS SETUP
if exist('fem_file_override', 'var') && ~isempty(fem_file_override)
    [fem, fem_file, ~] = loadFemDefinition(project_root, false, ...
        fem_file_override);
else
    [fem, fem_file, ~] = loadFemDefinition(project_root, false);
end
hs.fem_file = fem_file;
hs.specimen_file = specimen_file;

fem_num = fem.num;
fem_ref = fem.ref;
frame = fem_num.frame;
n_story = frame.n_story;
k_experimental = k_exp_r*specimen_si.stiffness;

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
[hs.C, hs.damping] = femDampingMatrix(fem_ref, fem);
hs.damping_ratio = hs.damping.target_ratio;
building_mode_frequency_hz = hs.damping.frequency_hz;
earthquakes = load(fullfile(project_root, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);
[PID_H_dc_dm, pid_h_dc_dm_values, h_dc_dm_model_file, ...
    actuator_open_loop] = ...
    loadPidHdcDmModel(project_root, h_dc_dm_model_file, ...
    pid_gain_override, PID_scale, hs_sample_dt);

%% SAMPLE GRID AND EARTHQUAKE INPUT
model_time = hs.time;
real_time = model_time*hs.time_scale_factor;
ag = hs.ag;
n_hs_sample = ceil(real_time(end)/hs_sample_dt) + 1;
hs_real_time = (0:n_hs_sample-1)'*hs_sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(model_time, ag, hs_model_time, 'linear', 0);

%% REFERENCE RESPONSE
reference_load_sample = -(fem_ref.M*fem_ref.influence)*ag_sample';
u_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    fem_ref.M, hs.C, fem_ref.K, reference_load_sample);
u_control_reference_sample = referenceControlDisplacement( ...
    fem_ref, u_reference_sample);

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
[u_pid_floors_sample, dd_pid_sample, dd_lead_pid_sample, dm_pid_sample, ...
    dc_pid_sample, experimental_force_pid_sample, ...
    pid_cl_stability] = ...
    hybridResponseWithPidHdcDm(hs, PID_H_dc_dm, pid_h_dc_dm_values, ...
    k_experimental, hs_sample_dt, delay_comp_tf_discrete);

u_num_floors = interp1(hs_real_time, u_num_floors_sample, real_time, ...
    'linear');
u_pid_floors = interp1(hs_real_time, u_pid_floors_sample, real_time, ...
    'linear');
u_reference = interp1(hs_real_time, u_reference_sample, real_time, ...
    'linear');
u_hybrid_reference = interp1(hs_real_time, u_hybrid_reference_sample, ...
    real_time, 'linear');
interface_displacement = interp1(hs_real_time, ...
    interface_displacement_sample, real_time, 'linear');
experimental_force = interp1(hs_real_time, experimental_force_sample, ...
    real_time, 'linear');
dd_pid = interp1(hs_real_time, dd_pid_sample, real_time, 'linear');
dd_lead_pid = interp1(hs_real_time, dd_lead_pid_sample, real_time, ...
    'linear');
dm_pid = interp1(hs_real_time, dm_pid_sample, real_time, 'linear');
dc_pid = interp1(hs_real_time, dc_pid_sample, real_time, 'linear');
experimental_force_pid = interp1(hs_real_time, ...
    experimental_force_pid_sample, real_time, 'linear');
if abs(hs.time_scale_factor-1) < eps
    unit_scale_u_num_floors_sample = u_num_floors_sample;
else
    unit_scale_u_num_floors_sample = hybrid_response_at_time_scale( ...
        hs, fem_num, k_experimental, hs_sample_dt, 1);
end

step_error = max(abs(u_num_floors-u_hybrid_reference), [], 'all');
reference_error = max(abs(u_num_floors-u_reference), [], 'all');
reference_error_pid = max(abs(u_pid_floors-u_reference), [], 'all');
metric = validation_metrics();
J4 = metric.J4(u_num_floors(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_floors(:, 2), u_reference(:, 2));
J6 = metric.J6(u_num_floors(:, 3), u_reference(:, 3));
vhs_result = struct('t', hs_real_time, ...
    'dc', dc_pid_sample, 'dm', dm_pid_sample, ...
    'fm', experimental_force_pid_sample, ...
    'am', ag_sample/9.80665, 'fs', 1/hs_sample_dt, ...
    'dt', hs_sample_dt, ...
    'dd_pause_enable_log', zeros(size(hs_real_time)), ...
    'hs', hs, 'testname', 'vHS', 'test_type', 'vHS');
vhs_metric_table = compare_hs_response_to_reference(hs.fem, vhs_result, ...
    hs.earthquake_type, hs.intensity_factor, hs.time_scale_factor, ...
    hs.force_sign, struct('plot', false));
control_metric_values = vhs_metric_table.Value;
metric_names = vhs_metric_table.Properties.RowNames(:);
metric_descriptions = cellstr(vhs_metric_table.Description);
metric_units = cellstr(vhs_metric_table.Unit);
colors = getPlotColors();
if phase_lead_enabled
    control_path_label = 'num*G_T*PID*H_{dc,dm}*exp';
else
    control_path_label = 'num*PID*H_{dc,dm}*exp';
end

fprintf('\n%s Hybrid Simulation partition\n', hs.earthquake_type);
fprintf('FEM file: %s\n', fem_file);
fprintf('H_dc_dm model file: %s\n', h_dc_dm_model_file);
fprintf('PID_H_dc_dm gains: P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', ...
    pid_h_dc_dm_values.P, pid_h_dc_dm_values.I, pid_h_dc_dm_values.D, ...
    pid_h_dc_dm_values.derivative_filter_N);
fprintf('PID output scale: %.6g\n', pid_h_dc_dm_values.PID_scale);
fprintf('Phase-lead compensator loaded: %s\n', delay_comp_file);
if ~isempty(phase_lead) && phase_lead.enabled
    fprintf('Phase lead after numerical dd: %s\n', ...
        phaseLeadSummary(phase_lead));
elseif phase_lead_enabled
    fprintf('Phase lead after numerical dd: using loaded transfer function\n');
else
    fprintf('Phase lead after numerical dd: disabled\n');
end
fprintf('FEM schema version: %d\n', fem.schema_version);
fprintf('FEM specimen name: %s\n', fem.specimen_name);
fprintf('FEM specimen file: %s\n', fem.specimen_file);
fprintf('Experimental specimen name: %s\n', specimen_name);
fprintf('Experimental specimen file: %s\n', specimen_file);
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
fprintf(['Damping: %s, fit modes [%s], target %.6g%%; ' ...
    'alpha = %.12g 1/s, beta = %.12g s\n'], ...
    hs.damping.type, num2str(hs.damping.fit_modes), ...
    100*hs.damping.target_ratio, hs.damping.alpha, hs.damping.beta);
natural_frequency_table = table((1:numel(building_mode_frequency_hz))', ...
    building_mode_frequency_hz(:), 100*hs.damping.modal_damping_ratio(:), ...
    'VariableNames', {'Mode', 'Frequency_Hz', 'DampingPercent'});
disp('Natural frequencies')
disp(natural_frequency_table)
pid_stability_table = table( ...
    {'PID_H_dc_dm'; control_path_label}, ...
    [pid_cl_stability.actuator_max_abs_pole; ...
    pid_cl_stability.coupled_max_abs_pole], ...
    [pid_cl_stability.actuator_stable; pid_cl_stability.coupled_stable], ...
    'VariableNames', {'System', 'MaxAbsPole', 'Stable'});
disp('PID_H_dc_dm stability check')
disp(pid_stability_table)
if ~pid_cl_stability.coupled_stable
    fprintf(['num*PID_H_dc_dm*exp is analytically unstable: dominant pole ' ...
        'z = %.12g%+.12gi, |z| = %.12g, f = %.6g Hz, ' ...
        'growth time constant = %.6g s\n'], ...
        real(pid_cl_stability.dominant_pole), ...
        imag(pid_cl_stability.dominant_pole), ...
        pid_cl_stability.coupled_max_abs_pole, ...
        pid_cl_stability.dominant_frequency_hz, ...
        pid_cl_stability.growth_time_constant_s);
end
fprintf('Experimental column: %s, height %.12g m, E %.12g Pa, Ix %.12g m^4\n', ...
    fem_ref.experimental_column.shape, fem_ref.experimental_column.height, ...
    fem_ref.experimental_column.E, fem_ref.experimental_column.section.Ix);
fprintf('Interface height: %.12g m; DOFs floors [%s], interface %d\n', ...
    fem_num.interface.height, num2str(floor_dofs), interface_dof);
fprintf('Intensity factor: %.3g\n', hs.intensity_factor);
fprintf(['Time scale factor: %.3g; sample dt is unchanged and the ' ...
    'earthquake is stretched in real time\n'], hs.time_scale_factor);
fprintf('Hybrid sample rate: %.6g Hz; control-check samples: %d\n', ...
    1/hs_sample_dt, numel(hs_real_time));
fprintf('Experimental reduction factor: %.3f\n', k_exp_r);
fprintf('Reduced experimental stiffness k: %.6f N/m\n', k_experimental);
fprintf('Interface: horizontal force only; roller carries axial reaction\n');
fprintf('Maximum step_HS vs spring-reference floor difference: %.6e m\n', ...
    step_error);
fprintf('Maximum Hybrid Simulation vs full-reference floor difference: %.6e m\n', ...
    reference_error);
fprintf('Maximum %s vs full-reference floor difference: %.6e m\n', ...
    control_path_label, reference_error_pid);
fprintf('Peak interface displacement: %.6f m\n', ...
    max(abs(interface_displacement)));
fprintf('Peak experimental force: %.6f N\n\n', max(abs(experimental_force)));
validation_metric_table = table(metric_names, ...
    metric_descriptions, metric_units, ...
    [NaN; NaN; NaN; J4; J5; J6; NaN], ...
    control_metric_values, ...
    'VariableNames', {'Metric', 'Description', 'Unit', ...
        'NumExp', 'ControlPath'});
disp('Validation metrics')
fprintf('Control path: %s\n', control_path_label);
disp(validation_metric_table)

%% RESPONSE COMPARISON
figure('Color', 'w', 'Name', 'Reference and HS comparison');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    plot(ax, real_time, u_reference(:, floor_id), '--', ...
        'Color', colors.dark_green, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('x%d\\_r (full FEM)', floor_id));
    hold(ax, 'on');
    plot(ax, real_time, u_num_floors(:, floor_id), '-', ...
        'Color', colors.blue, 'LineWidth', 1.1, ...
        'DisplayName', sprintf('x%d\\_n (numerical sub)', floor_id));
    plot(ax, real_time, u_pid_floors(:, floor_id), '-', ...
        'Color', colors.copperwood, 'LineWidth', 1.1, ...
        'DisplayName', sprintf('x%d\\_n (%s)', floor_id, ...
        control_path_label));
    hold(ax, 'off'); grid(ax, 'on');
    ylabel(ax, sprintf('Floor %d (m)', floor_id));
    makeLegendToggle(ax);
end
xlabel(ax, 'Real time (s)');
title(layout, sprintf('%s: reference and Hybrid Simulation response', ...
    hs.earthquake_type));
subtitle(layout, sprintf(['Max floor error: num*exp = %.3e m, ' ...
    'num*PID*H_{dc,dm}*exp = %.3e m'], reference_error, ...
    reference_error_pid));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% CONTROL CHECK
figure('Color', 'w', 'Name', 'PID_H_dc_dm control check');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
plot(ax, hs_real_time, dd_pid_sample, 'k--', 'LineWidth', 2.2, ...
    'DisplayName', 'd\_n (numerical sub)');
hold(ax, 'on');
if phase_lead_enabled
    plot(ax, hs_real_time, dd_lead_pid_sample, '--', ...
        'Color', colors.green, 'LineWidth', 1.5, ...
        'DisplayName', 'phase-lead d\_n');
end
plot(ax, hs_real_time, 1000*u_control_reference_sample, '-', ...
    'Color', colors.red, 'LineWidth', 1.1, ...
    'DisplayName', 'd\_r (full FEM)');
plot(ax, hs_real_time, dc_pid_sample, '-', 'Color', colors.copperwood, ...
    'LineWidth', 1.0, 'DisplayName', 'dc (command)');
plot(ax, hs_real_time, dm_pid_sample, '-', 'Color', colors.blue, ...
    'LineWidth', 1.0, 'DisplayName', 'dm (measured)');
addPeakLines(ax, dm_pid_sample, 'dm', colors.blue, 'mm');
addPeakLines(ax, dc_pid_sample, 'dc', colors.copperwood, 'mm');
hold(ax, 'off'); grid(ax, 'on');
ylabel(ax, 'Displacement (mm)');
makeLegendToggle(ax);

ax = nexttile;
plot(ax, hs_real_time, experimental_force_pid_sample, '-', ...
    'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm (measured force)');
hold(ax, 'on');
addPeakLines(ax, experimental_force_pid_sample, 'fm', colors.purple, 'N');
hold(ax, 'off'); grid(ax, 'on');
ylabel(ax, 'Force (N)');
xlabel(ax, 'Real time (s)');
makeLegendToggle(ax);
title(layout, 'num*PID*H_{dc,dm}*exp control check');
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% RESPONSE FREQUENCY CONTENT
fft_fmax_hz = 100;
fft_fs_hz = 1/hs_sample_dt;
fft_test_duration_s = hs.time(end)*hs.time_scale_factor;
plot_hs_response_frequency_content(hs, u_num_floors_sample, ...
    unit_scale_u_num_floors_sample, fft_fs_hz, fft_fmax_hz, ...
    fft_test_duration_s, ag_sample);

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

%% STABILITY TABLE
hybrid_margin_frequency_hz = [0.1, 80];
vhs_stability_table = buildVhsStabilityTable(PID_H_dc_dm, ...
    actuator_open_loop, hs, k_experimental, hs_sample_dt, ...
    delay_comp_tf_discrete, hybrid_margin_frequency_hz);

disp('Stability table')
disp(vhs_stability_table)

function [PID_H_dc_dm, pid_values, model_file, actuator_open_loop] = ...
        loadPidHdcDmModel( ...
        project_root, model_file, pid_gain_override, PID_scale, sample_time)
% Units: H_dc_dm maps dc [mm] to dm [mm]; PID_H_dc_dm maps dd [mm] to dm [mm].
if isempty(model_file)
    [~, model_file, ~] = load_saved_result_file(project_root, 'exp_tf');
end

if ~any(strcmp({whos('-file', model_file).name}, 'H_dc_dm'))
    error('vHS:MissingHdcDmModel', ['No saved model file containing ' ...
        'H_dc_dm was found. Run control_and_HS\\b_system_id\\sys_id.m ' ...
        'first, or choose a different saved_results\\exp_tf file.'])
end

model = load(model_file, 'H_dc_dm', 'pid_values');
H_dc_dm = model.H_dc_dm;
if isfield(model, 'pid_values')
    pid_values = model.pid_values;
else
    pid_values = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
pid_values = applyPidGainOverride(pid_values, pid_gain_override);
pid_values.PID_scale = PID_scale;
if get(H_dc_dm, 'Ts') == 0
    H_dc_dm = c2d(H_dc_dm, sample_time, 'zoh');
elseif abs(get(H_dc_dm, 'Ts')-sample_time) > 10*eps(sample_time)
    H_dc_dm = d2d(H_dc_dm, sample_time, 'zoh');
end
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, sample_time, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
digital_controller = pid_values.PID_scale*digital_controller;
actuator_open_loop = digital_controller*H_dc_dm;
PID_H_dc_dm = feedback(actuator_open_loop, 1);
end

function stability_table = buildVhsStabilityTable(PID_H_dc_dm, ...
        actuator_open_loop, hs, k_experimental, sample_time, ...
        delay_comp_tf_discrete, freq_range_hz)
% Units: margins use dB, deg, s, and discrete z-plane pole magnitude.
num_model = numericalSubstructureDiscrete(hs, sample_time);
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, ...
    num_model.D_fm, sample_time);
k_mm = k_experimental/1000;
actuator = discreteSiso(PID_H_dc_dm, sample_time);
unity_filter = discreteSiso(tf(1), sample_time);
delay_filter = discreteSiso(delay_comp_tf_discrete, sample_time);
num_exp_stability = analyzeActuatorLoop(num_model, actuator, ...
    unity_filter, k_experimental, sample_time);
num_delay_comp_exp_stability = analyzeActuatorLoop(num_model, actuator, ...
    delay_filter, k_experimental, sample_time);

exp_metrics = stabilityMetrics(actuator_open_loop, ...
    maxAbsPole(PID_H_dc_dm), freq_range_hz);
num_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*PID_H_dc_dm), ...
    num_exp_stability.coupled_max_abs_pole, freq_range_hz);
num_delay_comp_exp_metrics = stabilityMetrics( ...
    -minreal(num_tf*k_mm*delay_comp_tf_discrete*PID_H_dc_dm), ...
    num_delay_comp_exp_stability.coupled_max_abs_pole, freq_range_hz);

stability_table = array2table([ ...
    metricColumn(exp_metrics), ...
    metricColumn(num_exp_metrics), ...
    metricColumn(num_delay_comp_exp_metrics)], ...
    'VariableNames', {'PID_H_dc_dm', 'num_exp', ...
    'num_delay_comp_exp'}, ...
    'RowNames', {'GM_dB', 'PM_deg', 't_cr_s', 'NCF_margin', ...
    'MaxAbsZPole'});
end

function metrics = stabilityMetrics(open_loop, max_abs_z_pole, freq_range_hz)
[metrics.gm_db, metrics.pm_deg, metrics.ncf_margin] = ...
    custom_stability_margins(open_loop, freq_range_hz);
margins = allmargin(open_loop);
metrics.t_cr_s = min([margins.DelayMargin(:); Inf]);
metrics.max_abs_z_pole = max_abs_z_pole;
end

function values = metricColumn(metrics)
values = [metrics.gm_db; metrics.pm_deg; metrics.t_cr_s; ...
    metrics.ncf_margin; metrics.max_abs_z_pole];
end

function value = maxAbsPole(system_model)
poles = pole(system_model);
value = max([abs(poles(:)); 0]);
end

function pid_values = applyPidGainOverride(pid_values, pid_gain_override)
% Units: PID gains use the same units as sys_id.m.
if isempty(pid_gain_override)
    return
end
if isnumeric(pid_gain_override)
    validateattributes(pid_gain_override, {'numeric'}, ...
        {'vector', 'numel', 4, 'real', 'finite'}, mfilename, ...
        'pid_gain_override');
    pid_values.P = pid_gain_override(1);
    pid_values.I = pid_gain_override(2);
    pid_values.D = pid_gain_override(3);
    pid_values.derivative_filter_N = pid_gain_override(4);
elseif isstruct(pid_gain_override)
    required_fields = {'P', 'I', 'D', 'derivative_filter_N'};
    for field_id = 1:numel(required_fields)
        field = required_fields{field_id};
        if isfield(pid_gain_override, field)
            pid_values.(field) = pid_gain_override.(field);
        end
    end
else
    error('vHS:InvalidPidOverride', ...
        'pid_gain_override must be [], a 1x4 numeric vector, or a struct.')
end
end

function [u_num_floors_sample, dd_sample, dd_lead_sample, dm_sample, dc_sample, ...
        force_sample, stability] = hybridResponseWithPidHdcDm(hs, PID_H_dc_dm, ...
        pid_values, k_experimental, hs_sample_dt, delay_comp_tf_discrete)
% Units: dd/dd_lead/dm/dc [mm], force [N], floor displacement [m].
num_model = numericalSubstructureDiscrete(hs, hs_sample_dt);
actuator = discreteSiso(PID_H_dc_dm, hs_sample_dt);
lead_filter = discreteSiso(delay_comp_tf_discrete, hs_sample_dt);
digital_controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, hs_sample_dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
digital_controller = pid_values.PID_scale*digital_controller;
controller = discreteSiso(digital_controller, hs_sample_dt);
stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
    k_experimental, hs_sample_dt);

n_step = ceil(hs.time(end)*hs.time_scale_factor/hs_sample_dt) + 1;
hs_real_time = (0:n_step-1)'*hs_sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(hs.time, hs.ag, hs_model_time, 'linear', 0);
u_num_floors_sample = zeros(n_step, hs.n_floor);
dd_sample = zeros(n_step, 1);
dd_lead_sample = zeros(n_step, 1);
dm_sample = zeros(n_step, 1);
dc_sample = zeros(n_step, 1);
force_sample = zeros(n_step, 1);
x_num = zeros(size(num_model.A, 1), 1);
k_mm = k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;
for step = 2:n_step
    dd_sample(step) = (num_model.C*x_num ...
        + num_model.D_fm*k_mm*actuator.D*lead_filter.C*lead_filter.x ...
        + num_model.D_fm*k_mm*actuator.C*actuator.x ...
        + num_model.D_ag*ag_sample(step))/denominator;
    dd_lead_sample(step) = outputDiscreteSiso(lead_filter, dd_sample(step));
    dm_sample(step) = outputDiscreteSiso(actuator, dd_lead_sample(step));
    force_sample(step) = k_mm*dm_sample(step);
    dc_sample(step) = outputDiscreteSiso(controller, ...
        dd_lead_sample(step)-dm_sample(step));
    x_num = num_model.A*x_num + num_model.B_fm*force_sample(step) ...
        + num_model.B_ag*ag_sample(step);
    lead_filter = updateDiscreteSiso(lead_filter, dd_sample(step));
    actuator = updateDiscreteSiso(actuator, dd_lead_sample(step));
    controller = updateDiscreteSiso(controller, ...
        dd_lead_sample(step)-dm_sample(step));
    u_num_floors_sample(step, :) = x_num(1:hs.n_floor)';
end
end

function model = numericalSubstructureDiscrete(hs, sample_time)
% Units: force input [N], acceleration input [m/s^2], output dd [mm].
n = hs.n_floor;
h = sample_time;
beta = 1/4;
gamma = 1/2;
a0 = 1/(beta*h^2);
a1 = gamma/(beta*h);
a2 = 1/(beta*h);
a3 = 1/(2*beta)-1;
a4 = gamma/beta-1;
a5 = h*(gamma/(2*beta)-1);

effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
solver = effective_stiffness\eye(n);
state_to_displacement = solver * [a0*hs.M + a1*hs.C, ...
    a2*hs.M + a4*hs.C, a3*hs.M + a5*hs.C];
force_to_displacement = solver*(hs.force_to_floor*hs.force_sign);
ag_to_displacement = solver*hs.ground_force_gain;

model.A = zeros(3*n);
model.B_fm = zeros(3*n, 1);
model.B_ag = zeros(3*n, 1);
model.A(1:n, :) = state_to_displacement;
model.B_fm(1:n) = force_to_displacement;
model.B_ag(1:n) = ag_to_displacement;
model.A(2*n+1:3*n, :) = a0*(state_to_displacement ...
    - [eye(n), zeros(n), zeros(n)]) ...
    - a2*[zeros(n), eye(n), zeros(n)] ...
    - a3*[zeros(n), zeros(n), eye(n)];
model.B_fm(2*n+1:3*n) = a0*force_to_displacement;
model.B_ag(2*n+1:3*n) = a0*ag_to_displacement;
model.A(n+1:2*n, :) = [zeros(n), eye(n), zeros(n)] ...
    + h*((1-gamma)*[zeros(n), zeros(n), eye(n)] ...
    + gamma*model.A(2*n+1:3*n, :));
model.B_fm(n+1:2*n) = h*gamma*model.B_fm(2*n+1:3*n);
model.B_ag(n+1:2*n) = h*gamma*model.B_ag(2*n+1:3*n);
model.C = 1000*(hs.interface_from_floor*state_to_displacement);
model.D_fm = 1000*(hs.interface_from_floor*force_to_displacement ...
    + hs.interface_from_force*hs.force_sign);
model.D_ag = 1000*(hs.interface_from_floor*ag_to_displacement);
end

function stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
        k_experimental, sample_time)
% Units: poles are discrete z-plane poles.
k_mm = k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;
dd_from_num = num_model.C/denominator;
dd_from_lead = num_model.D_fm*k_mm*actuator.D*lead_filter.C ...
    /denominator;
dd_from_actuator = num_model.D_fm*k_mm*actuator.C/denominator;
dd_lead_from_num = lead_filter.D*dd_from_num;
dd_lead_from_lead = lead_filter.C + lead_filter.D*dd_from_lead;
dd_lead_from_actuator = lead_filter.D*dd_from_actuator;
force_from_num = k_mm*actuator.D*dd_lead_from_num;
force_from_lead = k_mm*actuator.D*dd_lead_from_lead;
force_from_actuator = k_mm*(actuator.C ...
    + actuator.D*dd_lead_from_actuator);
closed_loop_A = [ ...
    num_model.A + num_model.B_fm*force_from_num, ...
    num_model.B_fm*force_from_lead, ...
    num_model.B_fm*force_from_actuator; ...
    lead_filter.B*dd_from_num, ...
    lead_filter.A + lead_filter.B*dd_from_lead, ...
    lead_filter.B*dd_from_actuator; ...
    actuator.B*dd_lead_from_num, ...
    actuator.B*dd_lead_from_lead, ...
    actuator.A + actuator.B*dd_lead_from_actuator];
closed_loop_poles = eig(closed_loop_A);
actuator_poles = eig(actuator.A);
lead_poles = eig(lead_filter.A);
[coupled_max_abs_pole, dominant_index] = max(abs(closed_loop_poles));
dominant_pole = closed_loop_poles(dominant_index);
stability.actuator_max_abs_pole = max([abs(actuator_poles); 0]);
stability.lead_max_abs_pole = max([abs(lead_poles); 0]);
stability.coupled_max_abs_pole = coupled_max_abs_pole;
stability.actuator_stable = stability.actuator_max_abs_pole < 1 ...
    && stability.lead_max_abs_pole < 1;
stability.coupled_stable = stability.coupled_max_abs_pole < 1;
stability.dominant_pole = dominant_pole;
stability.dominant_frequency_hz = abs(angle(dominant_pole)) ...
    /(2*pi*sample_time);
if coupled_max_abs_pole > 1
    stability.growth_time_constant_s = sample_time/log(coupled_max_abs_pole);
else
    stability.growth_time_constant_s = Inf;
end
stability.closed_loop_poles = closed_loop_poles;
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

function text = phaseLeadSummary(phase_lead)
text = sprintf(['k_T = %.6g, z_hz = %s, p_hz = %s, DC gain = %.6g, ' ...
    'max lead = %.6g deg at %.6g Hz'], ...
    phase_lead.gain, matlabVectorLiteral(phase_lead.zero_hz), ...
    matlabVectorLiteral(phase_lead.pole_hz), phase_lead.dc_gain, ...
    phase_lead.max_phase_lead_deg, ...
    phase_lead.max_phase_lead_frequency_hz);
end

function text = matlabVectorLiteral(values)
values = values(:).';
parts = arrayfun(@(value) sprintf('%.6g', value), values, ...
    'UniformOutput', false);
if isscalar(values)
    text = parts{1};
else
    text = ['[' strjoin(parts, ' ') ']'];
end
end

function colors = getPlotColors()
% Units: RGB outputs are dimensionless.
colors.green = hexToRgb('39BF5E');
colors.dark_green = hexToRgb('006B2E');
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
