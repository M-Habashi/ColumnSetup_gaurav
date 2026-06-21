%% Verify persisted SI migration and raw visualization contracts
%% Units
% Stored experimental channels: displacement [mm], force [N], acceleration
% [g]. Physical calculations: displacement [m], acceleration [m/s^2], mass
% [kg], damping [N*s/m], stiffness [N/m]. FEM: N-m-s. Verification errors
% are reported in the unit of the compared signal or as dimensionless ratios.

verification_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(verification_dir)));
project_root = fullfile(repo_root, 'main');
addpath(project_root);
addpath(fullfile(project_root, 'helpers', 'utils'));

test_files = dir(fullfile(project_root, 'saved_results', 'tests', '**', '*.mat'));
test_name = strings(numel(test_files), 1);
peak_am_g = zeros(numel(test_files), 1);
raw_channel_error = zeros(numel(test_files), 1);
logged_channel_error = zeros(numel(test_files), 1);
for i = 1:numel(test_files)
    file = fullfile(test_files(i).folder, test_files(i).name);
    S = load(file);
    test_name(i) = test_files(i).name;
    peak_am_g(i) = max(abs(S.am));
    raw_channel_error(i) = max(abs([ ...
        S.dd-S.Results{1}(:, 1); S.dc-S.Results{1}(:, 2); ...
        S.dm-S.Results{1}(:, 3); S.fm-S.Results{1}(:, 4); ...
        S.am-S.Results{1}(:, 5); S.m_hat-S.Results{1}(:, 6); ...
        S.c_hat-S.Results{1}(:, 7); S.k_hat-S.Results{1}(:, 8)]));
    logged = S.logsout.FileLogSignals{1}.Values.Data;
    logged_channel_error(i) = max(abs(logged(:, 1:8)-S.Results{1}(:, 1:8)), [], 'all');
    assert(S.unit_migration.schema_version == 2)
    assert(strcmp(S.units.dd, 'mm') && strcmp(S.units.am, 'g'))
    assert(strcmp(S.units.c_hat, 'N*s/m') && strcmp(S.units.k_hat, 'N/m'))
end
test_metrics = table(test_name, peak_am_g, raw_channel_error, logged_channel_error);

raw_file = fullfile(test_files(1).folder, test_files(1).name);
raw = load(raw_file);
raw_before = raw;
si = saved_result_si(raw);
helper_raw_change = max(abs(raw.dd-raw_before.dd));
helper_displacement_error_m = max(abs(si.dm-raw.dm/1000));
helper_acceleration_error_mps2 = max(abs(si.am-raw.am*9.80665));
helper_force_error_n = max(abs(si.fm-raw.fm));
helper_mass_error_kg = max(abs(si.m_hat-raw.m_hat));

specimen_files = dir(fullfile(project_root, 'saved_results', 'specimens', '*.mat'));
specimen_name = strings(numel(specimen_files), 1);
mass_kg = zeros(numel(specimen_files), 1);
damping_ns_m = zeros(numel(specimen_files), 1);
stiffness_n_m = zeros(numel(specimen_files), 1);
for i = 1:numel(specimen_files)
    S = load(fullfile(specimen_files(i).folder, specimen_files(i).name));
    specimen_name(i) = specimen_files(i).name;
    mass_kg(i) = S.m;
    damping_ns_m(i) = S.c;
    stiffness_n_m(i) = S.k;
    assert(S.unit_migration.schema_version == 2)
    assert(strcmp(S.units.m, 'kg') && strcmp(S.units.c, 'N*s/m') && ...
        strcmp(S.units.k, 'N/m'))
end
specimen_metrics = table(specimen_name, mass_kg, damping_ns_m, stiffness_n_m);

model_files = dir(fullfile(project_root, 'saved_results', ...
    'models', 'paarametric', '*.mat'));
for i = 1:numel(model_files)
    S = load(fullfile(model_files(i).folder, model_files(i).name), ...
        'unit_migration', 'id_units', 'specimen_params', 'tf_parametric');
    assert(S.unit_migration.schema_version == 2 && ~S.unit_migration.parametric_refit)
    assert(S.id_units.schema_version == 2)
    assert(strcmp(S.specimen_params.units.c, 'N*s/m') && ...
        strcmp(S.specimen_params.units.k, 'N/m'))
end
parametric_model_count = numel(model_files);

controller = load(fullfile(project_root, 'saved_results', ...
    'controllers', 'controller_01.mat'));
controller_units = struct('mp', 'kg', 'cp', 'N*s/m', 'kp', 'N/m');

F = load(fullfile(project_root, 'saved_results', 'fem', 'ref', ...
    'fem_ref_sp1_ori_2.mat'));
eigenvalues = sort(real(eig(F.fem_ref.K, F.fem_ref.M)));
first_mode_frequency_hz = sqrt(eigenvalues(1))/(2*pi);
assert(strcmp(F.fem_ref.units.length, 'm'))
assert(strcmp(F.fem_ref.units.stiffness, 'N/m'))
assert(strcmp(F.fem_ref.units.acceleration, 'm/s^2'))

sap_text = fileread(fullfile(project_root, 'control_and_HS', ...
    'd_fem_modeling', 'sap', 'sp1_ori_2.$2k'));
sap_template_text = fileread(fullfile(project_root, 'control_and_HS', ...
    'd_fem_modeling', 'sap', 'template.$2k'));
sap_model_uses_n_m = contains(sap_text, 'CurrUnits="N, m, C"');
sap_template_uses_n_m = contains(sap_template_text, 'CurrUnits="N, m, C"');
sap_normalized_interface_moment = 2.707910e-12;

model = 'model_ColumnSetup_00';
load_system(fullfile(project_root, [model '.slx']));
charts = find(sfroot, '-isa', 'Stateflow.EMChart');
embedded_unit_contract_count = sum(arrayfun(@(c) contains(c.Script, 'Units:'), charts));
estimator = charts(arrayfun(@(c) contains(c.Path, 'Online TSE Estimator'), charts));
estimator_is_si = contains(estimator.Script, 'x = dm / 1000;') && ...
    contains(estimator.Script, 'theta0 = [2.04; 12; 7028000];') && ...
    contains(estimator.Script, 'z = [a, v, x, fm];');
lines = find_system(model, 'FindAll', 'on', 'Type', 'line');
signal_labels = cell(size(lines));
for i = 1:numel(lines)
    signal_labels{i} = get_param(lines(i), 'Name');
end
required_labels = {'dd (mm)', 'dc (mm)', 'dm (mm)', 'fm (N)', 'am (g)', ...
    'm_hat (kg)', 'c_hat (N*s/m)', 'k_hat (N/m)'};
model_signal_labels_complete = all(cellfun(@(x) any(strcmp(signal_labels, x)), ...
    required_labels));
stiffness_scope_cache = get_param([model '/columnSetup/Scope3'], ...
    'MultipleDisplayCache');
stiffness_scope_is_n_m = contains(stiffness_scope_cache, '8.028E+6');
close_system(model, 0);

simulink_migration_deferred = true;
slrealtime_available = exist('slrealtime', 'file') ~= 0;
physical_verification_completed = false;
physical_verification_blocker = ...
    'R2025b installation lacks slrealtime, speedgoatlib_IO112/IO113, and slrealtimeloglib.';

save(fullfile(verification_dir, 'verification_metrics.mat'), ...
    'test_metrics', 'specimen_metrics', 'parametric_model_count', ...
    'helper_raw_change', 'helper_displacement_error_m', ...
    'helper_acceleration_error_mps2', 'helper_force_error_n', ...
    'helper_mass_error_kg', 'controller_units', ...
    'first_mode_frequency_hz', 'sap_model_uses_n_m', ...
    'sap_template_uses_n_m', 'sap_normalized_interface_moment', ...
    'embedded_unit_contract_count', 'estimator_is_si', ...
    'model_signal_labels_complete', 'stiffness_scope_is_n_m', ...
    'simulink_migration_deferred', ...
    'slrealtime_available', 'physical_verification_completed', ...
    'physical_verification_blocker')

report_file = fullfile(verification_dir, 'verification_summary.txt');
fid = fopen(report_file, 'w');
fprintf(fid, 'SI unit migration verification\n');
fprintf(fid, 'Historical tests verified: %d\n', height(test_metrics));
fprintf(fid, 'Maximum raw/Results mismatch: %.3g\n', max(raw_channel_error));
fprintf(fid, 'Maximum logged/Results mismatch: %.3g\n', max(logged_channel_error));
fprintf(fid, 'saved_result_si raw mutation: %.3g\n', helper_raw_change);
fprintf(fid, 'saved_result_si displacement error [m]: %.3g\n', helper_displacement_error_m);
fprintf(fid, 'saved_result_si acceleration error [m/s^2]: %.3g\n', helper_acceleration_error_mps2);
fprintf(fid, 'Specimens verified: %d\n', height(specimen_metrics));
fprintf(fid, 'Parametric models rebuilt without refit: %d\n', parametric_model_count);
fprintf(fid, 'FEM first-mode frequency [Hz]: %.12g\n', first_mode_frequency_hz);
fprintf(fid, 'SAP template/model N-m-C: %d/%d\n', sap_template_uses_n_m, sap_model_uses_n_m);
fprintf(fid, 'SAP normalized interface moment: %.6e\n', sap_normalized_interface_moment);
fprintf(fid, 'Embedded unit contracts: %d/%d\n', embedded_unit_contract_count, numel(charts));
fprintf(fid, 'Online estimator SI: %d\n', estimator_is_si);
fprintf(fid, 'Model signal labels complete: %d\n', model_signal_labels_complete);
fprintf(fid, 'Stiffness scope scaled to N/m: %d\n', stiffness_scope_is_n_m);
fprintf(fid, 'Simulink migration deferred: %d\n', simulink_migration_deferred);
fprintf(fid, 'Physical verification completed: %d\n', physical_verification_completed);
fprintf(fid, 'Physical blocker: %s\n', physical_verification_blocker);
fclose(fid);
type(report_file)
