function [fem, filePath, selectedFileName] = loadFemDefinition( ...
        projectFolder, forcePrompt, preferredFile)
%LOADFEMDEFINITION Load the combined FEM definition file.
% Units: stored FEM data use SI units documented in fem.units.

if nargin < 2 || isempty(forcePrompt)
    forcePrompt = false;
end
if nargin < 3
    preferredFile = '';
end

femFolder = fullfile(projectFolder, 'saved_results', 'fem');
if ~forcePrompt && ~isempty(preferredFile)
    filePath = char(string(preferredFile));
    assert(isfile(filePath), 'Preferred FEM file not found: %s', filePath);
else
    files = dir(fullfile(femFolder, 'fem_*.mat'));
    [~, order] = sort(string({files.name}));
    files = files(order);

    assert(~isempty(files), ...
        ['No combined FEM files found under %s. Run build_fem_3.m to ' ...
         'create saved_results/fem/fem_<specimen>_3.mat.'], femFolder);

    fprintf('\nAvailable FEM files:\n\n');
    fprintf('saved_results\n  |-- fem\n');
    for file_id = 1:numel(files)
        fprintf('      |-- [%d] %s\n', file_id, files(file_id).name);
    end
    selection = input('\nSelect file number to load: ');
    filePath = fullfile(files(selection).folder, files(selection).name);
end

[fem, selectedFileName] = unpackFemFile(filePath);
end

function [fem, selectedFileName] = unpackFemFile(filePath)
data = load(filePath);
if isfield(data, 'fem')
    fem = data.fem;
else
    error('The selected file must contain the combined fem struct.');
end

assert(isfield(fem, 'ref') && isfield(fem, 'num'), ...
    'The FEM definition must contain fem.ref and fem.num.');
[~, name, ext] = fileparts(filePath);
selectedFileName = [name ext];
end
