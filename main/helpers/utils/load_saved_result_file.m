function [data, filePath, selectedFileName] = load_saved_result_file( ...
        projectFolder, resultSubfolder, forcePrompt, preferredFile, unwrapResult)
% Units:
%   Input paths and options are unitless. Output data preserves every unit
%   exactly as stored in the selected MAT file; no conversion is performed.

if nargin < 2 || isempty(resultSubfolder)
    resultSubfolder = 'tests';
end
if nargin < 3 || isempty(forcePrompt)
    forcePrompt = false;
end
if nargin < 4
    preferredFile = '';
end
if nargin < 5 || isempty(unwrapResult)
    unwrapResult = true;
end
validateattributes(forcePrompt, {'logical'}, {'scalar'}, mfilename, ...
    'forcePrompt');

resultSubfolder = normalizeSubfolder(resultSubfolder);
rootFolder = fullfile(projectFolder, 'saved_results', resultSubfolder);
files = dir(fullfile(rootFolder, '**', '*.mat'));
[~, order] = sort(string(fullfile({files.folder}, {files.name})));
files = files(order);

if ~forcePrompt && ~isempty(preferredFile)
    filePath = char(string(preferredFile));
    assert(isfile(filePath), 'Preferred result file not found: %s', filePath);
    if ~isPathUnderRoot(filePath, rootFolder)
        error('load_saved_result_file:PreferredFileOutsideRoot', ...
            'Preferred result file must be under %s.', rootFolder);
    end
else
    if isempty(files)
        error('No MAT files found under %s.', rootFolder);
    end

    fprintf('\nAvailable files:\n\n');
    printFileTree(fullfile('saved_results', resultSubfolder), ...
        rootFolder, files);
    selection = input('\nSelect file number to load: ');
    filePath = fullfile(files(selection).folder, files(selection).name);
end

[~, selectedName, selectedExt] = fileparts(filePath);
selectedFileName = [selectedName selectedExt];
data = load(filePath);
if unwrapResult && isfield(data, 'result') && isstruct(data.result)
    data = data.result;
end

end

function printFileTree(rootLabel, rootFolder, files)
% Units: path labels and file indices are unitless.
    rootParts = strsplit(char(rootLabel), filesep);
    rootParts = rootParts(~cellfun('isempty', rootParts));
    fprintf('%s\n', rootParts{1});
    for rootDepth = 2:numel(rootParts)
        fprintf('%s|-- %s\n', repmat('  ', 1, rootDepth - 1), ...
            rootParts{rootDepth});
    end

    baseDepth = numel(rootParts) - 1;
    printedFolders = strings(0, 1);
    for k = 1:numel(files)
        relFolder = getRelativeFolder(rootFolder, files(k).folder);
        folderParts = strings(0, 1);
        if relFolder ~= "."
            folderParts = split(relFolder, filesep);
            for folderDepth = 1:numel(folderParts)
                folderKey = join(folderParts(1:folderDepth), filesep);
                if ~any(strcmpi(printedFolders, folderKey))
                    fprintf('%s|-- %s\n', repmat('  ', 1, ...
                        baseDepth + folderDepth), ...
                        folderParts(folderDepth));
                    printedFolders(end + 1, 1) = folderKey; %#ok<AGROW>
                end
            end
        end

        fileDepth = baseDepth + numel(folderParts) + 1;
        fprintf('%s|-- [%d] %s\n', repmat('  ', 1, fileDepth), ...
            k, files(k).name);
    end
end

function tf = isPathUnderRoot(filePath, rootFolder)
% Units: input paths and logical output are unitless.
    filePath = string(char(java.io.File(filePath).getCanonicalPath()));
    rootFolder = string(char(java.io.File(rootFolder).getCanonicalPath()));
    tf = startsWith(lower(filePath), lower(rootFolder+filesep));
end

function resultSubfolder = normalizeSubfolder(resultSubfolder)
% Units: input and output paths are unitless.
    resultSubfolder = char(string(resultSubfolder));
    resultSubfolder = strrep(resultSubfolder, '/', filesep);
    resultSubfolder = strrep(resultSubfolder, '\', filesep);
end

function relFolder = getRelativeFolder(rootFolder, folder)
% Units: input and output paths are unitless.
    rootFolder = string(rootFolder);
    folder = string(folder);
    rootWithSeparator = rootFolder + filesep;

    if strcmpi(folder, rootFolder)
        relFolder = ".";
    elseif startsWith(lower(folder), lower(rootWithSeparator))
        relFolder = extractAfter(folder, strlength(rootWithSeparator));
    else
        [~, relFolder] = fileparts(folder);
        relFolder = string(relFolder);
    end
end
