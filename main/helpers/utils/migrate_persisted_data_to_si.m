%% Migrate persisted experimental and model data to unit schema 2
%% Units
% Before migration: displacement [mm], force [N], acceleration [mm/s^2],
% mass [kg], damping [N*s/mm], stiffness [N/mm]. After migration:
% displacement remains [mm], force remains [N], acceleration is [g], mass
% remains [kg], damping is [N*s/m], and stiffness is [N/m]. Parametric
% transfer functions are dimensionless and rebuilt without refitting.

project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
migration = migrationMetadata();
raw_units = rawResultUnits();

test_files = dir(fullfile(project_root, 'saved_results', 'tests', '**', '*.mat'));
for i = 1:numel(test_files)
    file = fullfile(test_files(i).folder, test_files(i).name);
    S = load(file);
    if isfield(S, 'unit_migration') && S.unit_migration.schema_version >= 2
        continue
    end

    S.am = S.am/9810;
    S.Results{1}(:, 5) = S.Results{1}(:, 5)/9810;
    S.c_hat = S.c_hat*1000;
    S.k_hat = S.k_hat*1000;
    if size(S.Results{1}, 2) >= 8
        S.Results{1}(:, 7:8) = S.Results{1}(:, 7:8)*1000;
    end
    signal = S.logsout.FileLogSignals{1}.Values;
    signal.Data(:, 5) = signal.Data(:, 5)/9810;
    if size(signal.Data, 2) >= 8
        signal.Data(:, 7:8) = signal.Data(:, 7:8)*1000;
    end
    S.logsout.FileLogSignals{1}.Values = signal;
    S.units = raw_units;
    S.unit_migration = migration;
    save(file, '-struct', 'S', '-v7.3');
    fprintf('Migrated test: %s\n', file);
    clear S signal
end

specimen_files = dir(fullfile(project_root, 'saved_results', 'specimens', '*.mat'));
for i = 1:numel(specimen_files)
    file = fullfile(specimen_files(i).folder, specimen_files(i).name);
    S = load(file);
    if isfield(S, 'unit_migration') && S.unit_migration.schema_version >= 2
        continue
    end
    S.c = S.c*1000;
    S.k = S.k*1000;
    S.units = struct('m', 'kg', 'c', 'N*s/m', 'k', 'N/m');
    S.unit_migration = migration;
    save(file, '-struct', 'S');
    fprintf('Migrated specimen: %s\n', file);
end

play_files = dir(fullfile(project_root, 'research', ...
    'online_specimen_params', 'data', '*.mat'));
for i = 1:numel(play_files)
    file = fullfile(play_files(i).folder, play_files(i).name);
    S = load(file);
    if isfield(S, 'unit_migration') && S.unit_migration.schema_version >= 2
        continue
    end
    S.am = S.am/9810;
    S.units = raw_units;
    S.unit_migration = migration;
    save(file, '-struct', 'S');
    fprintf('Migrated research data: %s\n', file);
end

model_files = dir(fullfile(project_root, 'saved_results', ...
    'models', 'paarametric', '*.mat'));
for i = 1:numel(model_files)
    file = fullfile(model_files(i).folder, model_files(i).name);
    S = load(file);
    if isfield(S, 'unit_migration') && S.unit_migration.schema_version >= 2
        continue
    end

    S.specimen_params.c = S.specimen_params.c*1000;
    S.specimen_params.k = S.specimen_params.k*1000;
    S.specimen_params.units = struct( ...
        'm', 'kg', 'c', 'N*s/m', 'k', 'N/m');
    [S.tf_parametric, S.tf_parametric_open_loop] = rebuildParametricModel(S);
    [gain_margin, phase_margin] = margin(S.tf_parametric_open_loop);
    if isfield(S, 'margin_table') && height(S.margin_table) >= 2
        S.margin_table.GainMargin(2) = gain_margin;
        S.margin_table.GainMargin_dB(2) = 20*log10(gain_margin);
        S.margin_table.PhaseMargin_deg(2) = phase_margin;
    end
    S.id_units = modelUnits();
    S.unit_migration = migration;
    save(file, '-struct', 'S');
    fprintf('Rebuilt parametric model without refitting: %s\n', file);
end

function units = rawResultUnits()
% Units: output strings document stored experimental channels and estimates.
units = struct('t', 's', 'dt', 's', 'fs', 'Hz', ...
    'dd', 'mm', 'dc', 'mm', 'dm', 'mm', 'fm', 'N', 'am', 'g', ...
    'm_hat', 'kg', 'c_hat', 'N*s/m', 'k_hat', 'N/m', ...
    'tse_fallback', 'dimensionless');
end

function units = modelUnits()
% Units: output strings document the physical SI model convention.
units = struct('schema_version', 2, 'model_convention', 'N-m-s', ...
    'raw_displacement', 'mm', 'raw_acceleration', 'g', ...
    'mass', 'kg', 'damping', 'N*s/m', 'stiffness', 'N/m', ...
    'transfer_function', 'dimensionless');
end

function migration = migrationMetadata()
% Units: migration metadata is unitless provenance text and schema number.
migration = struct('schema_version', 2, ...
    'name', 'raw_mm_g_with_si_parameters', ...
    'acceleration_scale', 'old mm/s^2 divided by 9810 to g', ...
    'parameter_scale', 'old c and k multiplied by 1000', ...
    'parametric_refit', false, ...
    'date', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));
end

function [closed_loop, open_loop] = rebuildParametricModel(S)
% Units: specimen m [kg], c [N*s/m], k [N/m]; stored polynomial
% coefficients retain continuous-time SI powers; both outputs are dimensionless.
m = S.specimen_params.m;
c = S.specimen_params.c;
k = S.specimen_params.k;
num = [S.Kp*S.a1b0, S.Ki*S.a1b0];
den = [m, ...
    c + S.a3*m + S.beta1*m, ...
    S.a2 + k + S.a3*c + S.beta1*c + S.beta2*m + S.a3*S.beta1*m, ...
    S.a2*S.beta1 + S.beta2*c + S.a3*k + S.beta1*k + ...
        S.a3*S.beta1*c + S.a3*S.beta2*m, ...
    S.a2*S.beta2 + S.beta2*k + S.a3*S.beta2*c + S.a3*S.beta1*k, ...
    S.Kp*S.a1b0 + S.a3*S.beta2*k, ...
    S.Ki*S.a1b0];
closed_loop = minreal(tf(num, den), [], false);
open_loop = minreal(closed_loop/(1 - closed_loop), [], false);
end
