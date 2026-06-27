function convertedFiles = convert_saved_result_to_struct(inputPath, outputFile)
%CONVERT_SAVED_RESULT_TO_STRUCT Convert saved test MAT files to result.
% Units: stored numeric fields keep their existing units unchanged.

if nargin < 1 || isempty(inputPath)
    projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    inputPath = fullfile(projectFolder, 'saved_results', 'tests');
end

inputPath = char(string(inputPath));
if isfolder(inputPath)
    files = dir(fullfile(inputPath, '**', '*.mat'));
    convertedFiles = strings(0, 1);
    for iFile = 1:numel(files)
        file = fullfile(files(iFile).folder, files(iFile).name);
        if convertOneFile(file, file)
            convertedFiles(end + 1, 1) = string(file); %#ok<AGROW>
        end
    end
    fprintf('Converted %d saved result file(s).\n', numel(convertedFiles))
    return
end

if nargin < 2 || isempty(outputFile)
    outputFile = inputPath;
else
    outputFile = char(string(outputFile));
end
convertedFiles = strings(0, 1);
if convertOneFile(inputPath, outputFile)
    convertedFiles = string(outputFile);
end
end

function didConvert = convertOneFile(inputFile, outputFile)
vars = whos('-file', inputFile);
varNames = {vars.name};
if ismember('result', varNames)
    fprintf('Already converted: %s\n', inputFile)
    didConvert = false;
    return
end

S = load(inputFile);
result = S;

if ~isfield(result, 'file')
    [~, baseName, ext] = fileparts(inputFile);
    result.file = [baseName ext];
end

save(outputFile, 'result', '-v7.3')
fprintf('Converted: %s\n', outputFile)
didConvert = true;
end
