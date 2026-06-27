function [result, outputFile] = convert_saved_result_to_struct(inputFile, outputFile)
%CONVERT_SAVED_RESULT_TO_STRUCT Convert old saved test MAT files to result.
% Units: stored numeric fields keep their existing units unchanged.

if nargin < 1 || isempty(inputFile)
    projectFolder = fileparts(fileparts(mfilename('fullpath')));
    [result, inputFile] = load_saved_result_file(projectFolder, 'tests', true);
else
    inputFile = char(string(inputFile));
    S = load(inputFile);
    if isfield(S, 'result') && isstruct(S.result)
        result = S.result;
    else
        result = S;
    end
end

if nargin < 2 || isempty(outputFile)
    [folder, baseName, ext] = fileparts(inputFile);
    outputFile = fullfile(folder, [baseName '_struct' ext]);
else
    outputFile = char(string(outputFile));
end

if ~isfield(result, 'file')
    [~, baseName, ext] = fileparts(inputFile);
    result.file = [baseName ext];
end

save(outputFile, 'result', '-v7.3')
fprintf('Saved struct result: %s\n', outputFile)
end
