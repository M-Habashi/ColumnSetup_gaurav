function report = make_saved_test_results_standalone(inputPath)
%MAKE_SAVED_TEST_RESULTS_STANDALONE Embed dependencies in saved tests.

projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if nargin < 1 || isempty(inputPath)
    inputPath = fullfile(projectFolder, 'saved_results', 'tests');
end
files = dir(fullfile(char(string(inputPath)), '**', '*.mat'));
report = table('Size', [numel(files) 3], ...
    'VariableTypes', {'string', 'logical', 'string'}, ...
    'VariableNames', {'File', 'Standalone', 'Missing'});

for fileId = 1:numel(files)
    file = fullfile(files(fileId).folder, files(fileId).name);
    data = load(file, 'result');
    if ~isfield(data, 'result') || ~isstruct(data.result)
        missing = "result struct";
        standalone = false;
    else
        [result, missing] = embed_saved_result_dependencies( ...
            data.result, projectFolder);
        standalone = isempty(missing);
        save(file, 'result', '-v7.3')
    end
    report.File(fileId) = string(file);
    report.Standalone(fileId) = standalone;
    report.Missing(fileId) = strjoin(missing, '; ');
    fprintf('[%d/%d] %s: %s\n', fileId, numel(files), files(fileId).name, ...
        char(stringStatus(standalone)))
end

fprintf('\nStandalone: %d/%d test file(s).\n', ...
    sum(report.Standalone), height(report))
if any(~report.Standalone)
    disp(report(~report.Standalone, :))
end
end

function status = stringStatus(standalone)
if standalone
    status = "standalone";
else
    status = "missing dependency";
end
end
