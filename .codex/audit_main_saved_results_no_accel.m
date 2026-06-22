projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\main';
savedRoot = fullfile(projectFolder, 'saved_results');
oldPathTokens = {
    'step_1_calibration_and_identificationn'
    'C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main'
    'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\step_1_calibration_and_identificationn'
    };

testFiles = dir(fullfile(savedRoot, 'tests', '**', '*.mat'));
specimenFiles = dir(fullfile(savedRoot, 'specimens', '**', '*.mat'));
parametricFiles = dir(fullfile(savedRoot, 'models', 'paarametric', '**', '*.mat'));
fitFiles = dir(fullfile(savedRoot, 'models', 'fit', '**', '*.mat'));
controllerFiles = dir(fullfile(savedRoot, 'controllers', '**', '*.mat'));
allFiles = [testFiles; specimenFiles; parametricFiles; fitFiles; controllerFiles];

testMissingUnits = 0;
testBadCkUnits = 0;
testBadAccelFlag = 0;
testMissingMigration = 0;

for i = 1:numel(testFiles)
    filePath = fullfile(testFiles(i).folder, testFiles(i).name);
    S = load(filePath, 'units', 'unit_migration');
    if ~isfield(S, 'units')
        testMissingUnits = testMissingUnits + 1;
        continue
    end
    if ~isfield(S.units, 'c_hat') || ~strcmp(S.units.c_hat, 'N*s/m') || ...
            ~isfield(S.units, 'k_hat') || ~strcmp(S.units.k_hat, 'N/m')
        testBadCkUnits = testBadCkUnits + 1;
    end
    if ~isfield(S, 'unit_migration')
        testMissingMigration = testMissingMigration + 1;
    end
    if ~isfield(S.units, 'am') || ~strcmp(S.units.am, 'mm/s^2') || ...
            ~isfield(S, 'unit_migration') || ~isfield(S.unit_migration, 'acceleration_migrated') || ...
            S.unit_migration.acceleration_migrated
        testBadAccelFlag = testBadAccelFlag + 1;
    end
end

specimenBadUnits = 0;
for i = 1:numel(specimenFiles)
    filePath = fullfile(specimenFiles(i).folder, specimenFiles(i).name);
    S = load(filePath, 'units');
    if ~isfield(S, 'units') || ~isfield(S.units, 'c') || ~strcmp(S.units.c, 'N*s/m') || ...
            ~isfield(S.units, 'k') || ~strcmp(S.units.k, 'N/m')
        specimenBadUnits = specimenBadUnits + 1;
    end
end

parametricBadUnits = 0;
for i = 1:numel(parametricFiles)
    filePath = fullfile(parametricFiles(i).folder, parametricFiles(i).name);
    S = load(filePath, 'specimen_params', 'id_units');
    if ~isfield(S, 'specimen_params') || ~isfield(S.specimen_params, 'units') || ...
            ~isfield(S.specimen_params.units, 'c') || ~strcmp(S.specimen_params.units.c, 'N*s/m') || ...
            ~isfield(S.specimen_params.units, 'k') || ~strcmp(S.specimen_params.units.k, 'N/m') || ...
            ~isfield(S, 'id_units') || ~isfield(S.id_units, 'schema_version') || S.id_units.schema_version ~= 2
        parametricBadUnits = parametricBadUnits + 1;
    end
end

stalePathHits = {};
outsideMainHits = {};
for i = 1:numel(allFiles)
    filePath = fullfile(allFiles(i).folder, allFiles(i).name);
    S = load(filePath);
    [staleHits, outsideHits] = scanValueForPaths(S, oldPathTokens, projectFolder, allFiles(i).name);
    stalePathHits = [stalePathHits; staleHits(:)]; %#ok<AGROW>
    outsideMainHits = [outsideMainHits; outsideHits(:)]; %#ok<AGROW>
end

[~, order] = sort([testFiles.datenum], 'descend');
sampleFiles = testFiles(order(1:min(2, numel(order))));

fprintf('savedRoot=%s\n', savedRoot);
fprintf('counts tests=%d specimens=%d parametric=%d fit=%d controller=%d total=%d\n', ...
    numel(testFiles), numel(specimenFiles), numel(parametricFiles), numel(fitFiles), numel(controllerFiles), numel(allFiles));
fprintf('tests missing_units=%d bad_ck_units=%d bad_accel_flag=%d missing_migration=%d\n', ...
    testMissingUnits, testBadCkUnits, testBadAccelFlag, testMissingMigration);
fprintf('specimens bad_units=%d\n', specimenBadUnits);
fprintf('parametric bad_units=%d\n', parametricBadUnits);
fprintf('path_scan stale_hits=%d outside_main_hits=%d\n', numel(stalePathHits), numel(outsideMainHits));

if ~isempty(stalePathHits)
    fprintf('stale path examples:\n');
    for i = 1:min(10, numel(stalePathHits))
        fprintf('  %s\n', stalePathHits{i});
    end
end
if ~isempty(outsideMainHits)
    fprintf('outside-main absolute path examples:\n');
    for i = 1:min(10, numel(outsideMainHits))
        fprintf('  %s\n', outsideMainHits{i});
    end
end

for i = 1:numel(sampleFiles)
    filePath = fullfile(sampleFiles(i).folder, sampleFiles(i).name);
    fileVars = who('-file', filePath);
    S = load(filePath, 'units', 'unit_migration', 'Results', 'am', 'fs', 'dt');
    fprintf('sample%d=%s\n', i, filePath);
    if ismember('c_hat', fileVars)
        S2 = load(filePath, 'c_hat');
        S.c_hat = S2.c_hat;
        fprintf('  c_hat_range=[%.6g %.6g] %s\n', min(S.c_hat(:)), max(S.c_hat(:)), S.units.c_hat);
    elseif isfield(S, 'Results') && size(S.Results, 2) >= 7
        fprintf('  Results_col7_range=[%.6g %.6g] %s\n', min(S.Results(:, 7)), max(S.Results(:, 7)), S.units.c_hat);
    end
    if ismember('k_hat', fileVars)
        S2 = load(filePath, 'k_hat');
        S.k_hat = S2.k_hat;
        fprintf('  k_hat_range=[%.6g %.6g] %s\n', min(S.k_hat(:)), max(S.k_hat(:)), S.units.k_hat);
    elseif isfield(S, 'Results') && size(S.Results, 2) >= 8
        fprintf('  Results_col8_range=[%.6g %.6g] %s\n', min(S.Results(:, 8)), max(S.Results(:, 8)), S.units.k_hat);
    end
    if isfield(S, 'am')
        fprintf('  am_range=[%.6g %.6g] %s accel_migrated=%d\n', ...
            min(S.am(:)), max(S.am(:)), S.units.am, S.unit_migration.acceleration_migrated);
    end
    if isfield(S, 'fs') && isfield(S, 'dt')
        fprintf('  fs=%.6g dt=%.6g\n', S.fs, S.dt);
    end
end

for i = 1:numel(specimenFiles)
    filePath = fullfile(specimenFiles(i).folder, specimenFiles(i).name);
    S = load(filePath, 'm', 'c', 'k', 'units');
    fprintf('specimen=%s m=%.6g %s c=%.6g %s k=%.6g %s\n', ...
        filePath, S.m, S.units.m, S.c, S.units.c, S.k, S.units.k);
end

function [staleHits, outsideHits] = scanValueForPaths(value, oldPathTokens, projectFolder, label)
staleHits = {};
outsideHits = {};

if ischar(value) || isstring(value)
    [staleHits, outsideHits] = scanTextForPaths(value, oldPathTokens, projectFolder, label);
elseif isstruct(value)
    fields = fieldnames(value);
    for idx = 1:numel(value)
        for j = 1:numel(fields)
            [newStale, newOutside] = scanValueForPaths(value(idx).(fields{j}), oldPathTokens, projectFolder, [label '.' fields{j}]);
            staleHits = [staleHits; newStale(:)]; %#ok<AGROW>
            outsideHits = [outsideHits; newOutside(:)]; %#ok<AGROW>
        end
    end
elseif iscell(value)
    for idx = 1:numel(value)
        [newStale, newOutside] = scanValueForPaths(value{idx}, oldPathTokens, projectFolder, sprintf('%s{%d}', label, idx));
        staleHits = [staleHits; newStale(:)]; %#ok<AGROW>
        outsideHits = [outsideHits; newOutside(:)]; %#ok<AGROW>
    end
elseif istable(value)
    for j = 1:width(value)
        column = value{:, j};
        if ischar(column) || isstring(column) || iscell(column) || isstruct(column)
            [newStale, newOutside] = scanValueForPaths(column, oldPathTokens, projectFolder, [label '.' value.Properties.VariableNames{j}]);
            staleHits = [staleHits; newStale(:)]; %#ok<AGROW>
            outsideHits = [outsideHits; newOutside(:)]; %#ok<AGROW>
        end
    end
end
end

function [staleHits, outsideHits] = scanTextForPaths(value, oldPathTokens, projectFolder, label)
staleHits = {};
outsideHits = {};
texts = cellstr(value);
for i = 1:numel(texts)
    textValue = strrep(texts{i}, '/', '\');
    for j = 1:numel(oldPathTokens)
        if contains(textValue, strrep(oldPathTokens{j}, '/', '\'), 'IgnoreCase', true)
            staleHits{end + 1, 1} = sprintf('%s: %s', label, shortenText(textValue)); %#ok<AGROW>
        end
    end
    if contains(textValue, ':\') && ~contains(textValue, strrep(projectFolder, '/', '\'), 'IgnoreCase', true)
        outsideHits{end + 1, 1} = sprintf('%s: %s', label, shortenText(textValue)); %#ok<AGROW>
    end
end
end

function textValue = shortenText(textValue)
if numel(textValue) > 180
    textValue = [textValue(1:177) '...'];
end
end
