%% Migrate copied saved_results in main, leaving acceleration unchanged.
clear; clc

repoRoot = fileparts(fileparts(mfilename('fullpath')));
mainRoot = fullfile(repoRoot, 'main');
savedRoot = fullfile(mainRoot, 'saved_results');
oldStepRoot = fullfile(repoRoot, 'step_1_calibration_and_identificationn');
oldVictusMain = ['C:\Users\Victus\Desktop\folder_working\a purdue\' ...
    'aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main'];

pathFrom = {oldStepRoot, oldVictusMain, strrep(oldStepRoot, '\', '/'), ...
    strrep(oldVictusMain, '\', '/')};
pathTo = {mainRoot, mainRoot, strrep(mainRoot, '\', '/'), ...
    strrep(mainRoot, '\', '/')};

rawUnits = struct('t', 's', 'dt', 's', 'fs', 'Hz', ...
    'dd', 'mm', 'dc', 'mm', 'dm', 'mm', 'fm', 'N', ...
    'am', 'mm/s^2', 'm_hat', 'kg', 'c_hat', 'N*s/m', ...
    'k_hat', 'N/m', 'tse_fallback', 'dimensionless');
migration = struct('schema_version', 2, ...
    'name', 'raw_mm_legacy_accel_with_si_parameters', ...
    'parameter_scale', 'old c and k multiplied by 1000', ...
    'acceleration_migrated', false, ...
    'acceleration_scale', 'not applied; legacy acceleration values preserved', ...
    'path_root', mainRoot, ...
    'date', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));

fprintf('Migrating copied saved_results under %s\n', savedRoot)

testFiles = dir(fullfile(savedRoot, 'tests', '**', '*.mat'));
for i = 1:numel(testFiles)
    file = fullfile(testFiles(i).folder, testFiles(i).name);
    S = load(file);
    alreadyScaled = isfield(S, 'unit_migration') && ...
        isfield(S.unit_migration, 'parameter_scaled') && ...
        S.unit_migration.parameter_scaled;
    if ~alreadyScaled
        if isfield(S, 'c_hat') && ~isempty(S.c_hat)
            S.c_hat = S.c_hat*1000;
        end
        if isfield(S, 'k_hat') && ~isempty(S.k_hat)
            S.k_hat = S.k_hat*1000;
        end
        if isfield(S, 'Results') && iscell(S.Results)
            for k = 1:numel(S.Results)
                if isnumeric(S.Results{k}) && size(S.Results{k}, 2) >= 8
                    S.Results{k}(:, 7:8) = S.Results{k}(:, 7:8)*1000;
                end
            end
        end
        if isfield(S, 'logsout')
            try
                signal = S.logsout.FileLogSignals{1}.Values;
                if size(signal.Data, 2) >= 8
                    signal.Data(:, 7:8) = signal.Data(:, 7:8)*1000;
                    S.logsout.FileLogSignals{1}.Values = signal;
                end
            catch
            end
        end
    end
    S.units = rawUnits;
    S.unit_migration = migration;
    S.unit_migration.parameter_scaled = true;
    S = replacePaths(S, pathFrom, pathTo);
    save(file, '-struct', 'S', '-v7.3');
    fprintf('Migrated test %d/%d: %s\n', i, numel(testFiles), file)
    clear S signal
end

specimenFiles = dir(fullfile(savedRoot, 'specimens', '*.mat'));
for i = 1:numel(specimenFiles)
    file = fullfile(specimenFiles(i).folder, specimenFiles(i).name);
    S = load(file);
    alreadyScaled = isfield(S, 'unit_migration') && ...
        isfield(S.unit_migration, 'parameter_scaled') && ...
        S.unit_migration.parameter_scaled;
    if ~alreadyScaled
        if isfield(S, 'c'), S.c = S.c*1000; end
        if isfield(S, 'k'), S.k = S.k*1000; end
    end
    S.units = struct('m', 'kg', 'c', 'N*s/m', 'k', 'N/m');
    S.unit_migration = migration;
    S.unit_migration.parameter_scaled = true;
    S = replacePaths(S, pathFrom, pathTo);
    save(file, '-struct', 'S');
    fprintf('Migrated specimen %d/%d: %s\n', i, numel(specimenFiles), file)
end

modelFiles = dir(fullfile(savedRoot, 'models', 'paarametric', '*.mat'));
for i = 1:numel(modelFiles)
    file = fullfile(modelFiles(i).folder, modelFiles(i).name);
    S = load(file);
    alreadyScaled = isfield(S, 'unit_migration') && ...
        isfield(S.unit_migration, 'parameter_scaled') && ...
        S.unit_migration.parameter_scaled;
    if isfield(S, 'specimen_params')
        if ~alreadyScaled
            if isfield(S.specimen_params, 'c')
                S.specimen_params.c = S.specimen_params.c*1000;
            end
            if isfield(S.specimen_params, 'k')
                S.specimen_params.k = S.specimen_params.k*1000;
            end
        end
        S.specimen_params.units = struct('m', 'kg', 'c', 'N*s/m', ...
            'k', 'N/m');
    end
    if all(isfield(S, {'Kp', 'Ki', 'a1b0', 'a2', 'a3', 'beta1', ...
            'beta2', 'specimen_params'}))
        [S.tf_parametric, S.tf_parametric_open_loop] = ...
            rebuildParametricModel(S);
        [gainMargin, phaseMargin] = margin(S.tf_parametric_open_loop);
        if isfield(S, 'margin_table') && height(S.margin_table) >= 2
            S.margin_table.GainMargin(2) = gainMargin;
            S.margin_table.GainMargin_dB(2) = 20*log10(gainMargin);
            S.margin_table.PhaseMargin_deg(2) = phaseMargin;
        end
    end
    S.id_units = modelUnits();
    S.unit_migration = migration;
    S.unit_migration.parameter_scaled = true;
    S = replacePaths(S, pathFrom, pathTo);
    save(file, '-struct', 'S');
    fprintf('Migrated parametric model %d/%d: %s\n', i, numel(modelFiles), file)
end

otherFiles = [ ...
    dir(fullfile(savedRoot, 'models', 'fit', '*.mat')); ...
    dir(fullfile(savedRoot, 'controllers', '*.mat'))];
for i = 1:numel(otherFiles)
    file = fullfile(otherFiles(i).folder, otherFiles(i).name);
    S = load(file);
    S = replacePaths(S, pathFrom, pathTo);
    save(file, '-struct', 'S');
    fprintf('Updated paths %d/%d: %s\n', i, numel(otherFiles), file)
end

fprintf('Done.\n')

function S = replacePaths(S, fromValues, toValues)
fields = fieldnames(S);
for i = 1:numel(fields)
    S.(fields{i}) = replaceValue(S.(fields{i}), fromValues, toValues);
end
end

function value = replaceValue(value, fromValues, toValues)
if ischar(value)
    value = replaceText(value, fromValues, toValues);
elseif isstring(value)
    value = string(replaceText(char(value), fromValues, toValues));
elseif iscell(value)
    for i = 1:numel(value)
        value{i} = replaceValue(value{i}, fromValues, toValues);
    end
elseif isstruct(value)
    names = fieldnames(value);
    for j = 1:numel(value)
        for i = 1:numel(names)
            value(j).(names{i}) = replaceValue(value(j).(names{i}), ...
                fromValues, toValues);
        end
    end
end
end

function text = replaceText(text, fromValues, toValues)
for i = 1:numel(fromValues)
    text = strrep(text, fromValues{i}, toValues{i});
end
end

function units = modelUnits()
units = struct('schema_version', 2, 'model_convention', 'N-m-s', ...
    'raw_displacement', 'mm', 'raw_acceleration', 'legacy mm/s^2', ...
    'mass', 'kg', 'damping', 'N*s/m', 'stiffness', 'N/m', ...
    'transfer_function', 'dimensionless');
end

function [closedLoop, openLoop] = rebuildParametricModel(S)
m = S.specimen_params.m;
c = S.specimen_params.c;
k = S.specimen_params.k;
num = [S.Kp*S.a1b0, S.Ki*S.a1b0];
den = [m, ...
    c + S.a3*m + S.beta1*m, ...
    S.a2 + k + S.a3*c + S.beta1*c + S.beta2*m + S.a3*S.beta1*m, ...
    S.a2*S.beta1 + S.beta2*c + S.a3*k + S.beta1*k + ...
        S.a3*S.beta1*c + S.a3*S.beta2*m, ...
    S.a2*S.beta2 + S.beta2*k + S.a3*S.beta2*c + ...
        S.a3*S.beta1*k, ...
    S.Kp*S.a1b0 + S.a3*S.beta2*k, ...
    S.Ki*S.a1b0];
closedLoop = minreal(tf(num, den), [], false);
openLoop = minreal(closedLoop/(1 - closedLoop), [], false);
end
