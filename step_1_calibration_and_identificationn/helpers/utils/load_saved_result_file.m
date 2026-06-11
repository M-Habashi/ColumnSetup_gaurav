function [data, filePath, selectedFileName] = load_saved_result_file(projectFolder, resultSubfolder)

if nargin < 2 || isempty(resultSubfolder)
    resultSubfolder = 'tests';
end

resultSubfolder = normalizeSubfolder(resultSubfolder);
rootFolder = fullfile(projectFolder, 'saved_results', resultSubfolder);
files = dir(fullfile(rootFolder, '**', '*.mat'));
[~, order] = sort(string(fullfile({files.folder}, {files.name})));
files = files(order);

if evalin('caller', 'exist(''outputVerificationFile'', ''var'')')
    filePath = evalin('caller', 'outputVerificationFile');
else
    if isempty(files)
        error('No MAT files found under %s.', rootFolder);
    end

    fprintf('\nAvailable files:\n\n');
    printFileTree(resultSubfolder, rootFolder, files);
    selection = input('\nSelect file number to load: ');
    filePath = fullfile(files(selection).folder, files(selection).name);
end

[~, selectedName, selectedExt] = fileparts(filePath);
selectedFileName = [selectedName selectedExt];
data = load(filePath);

end

function printFileTree(rootLabel, rootFolder, files)
    currentFolder = "";
    fprintf('%s\n', rootLabel);
    for k = 1:numel(files)
        relFolder = getRelativeFolder(rootFolder, files(k).folder);
        if relFolder ~= currentFolder
            currentFolder = relFolder;
            if currentFolder ~= "."
                parts = split(currentFolder, filesep);
                for p = 1:numel(parts)
                    fprintf('%s%s\n', repmat('    ', 1, p), char(parts(p)));
                end
            end
        end
        if currentFolder == "."
            indentLevel = 1;
        else
            indentLevel = numel(split(currentFolder, filesep)) + 1;
        end
        fprintf('%s[%d] %s\n', repmat('    ', 1, indentLevel), k, files(k).name);
    end
end

function resultSubfolder = normalizeSubfolder(resultSubfolder)
    resultSubfolder = char(string(resultSubfolder));
    resultSubfolder = strrep(resultSubfolder, '/', filesep);
    resultSubfolder = strrep(resultSubfolder, '\', filesep);
end

function relFolder = getRelativeFolder(rootFolder, folder)
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
