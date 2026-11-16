function comparison = scripted_compare_paper_case_batch(settingsPath)
%SCRIPTED_COMPARE_PAPER_CASE_BATCH Compare paper/code J1--J9 for four cases.

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
if nargin < 1 || strlength(string(settingsPath)) == 0
    candidates = dir(fullfile(projectRoot, 'Results', ...
        'paper_rerun_*_settings.mat'));
    assert(~isempty(candidates), 'No paper-case settings manifest was found.');
    [~, newestIndex] = max([candidates.datenum]);
    settingsPath = fullfile(candidates(newestIndex).folder, ...
        candidates(newestIndex).name);
else
    settingsPath = char(settingsPath);
end

saved = load(settingsPath, 'batch');
batch = saved.batch;
comparison = table();
for caseIndex = 1:height(batch.Results)
    resultPath = char(batch.Results.SignalFile(caseIndex));
    [resultFolder, resultName] = fileparts(resultPath);
    individualPath = fullfile(resultFolder, ...
        sprintf('%s_paper_vs_code_evaluations.csv', resultName));
    caseTable = scripted_compare_evaluation_definitions( ...
        resultPath, individualPath);
    caseColumn = repmat(batch.Results.CaseTitle(caseIndex), ...
        height(caseTable), 1);
    caseTable = addvars(caseTable, caseColumn, 'Before', 1, ...
        'NewVariableNames', 'Case');
    comparison = [comparison; caseTable]; %#ok<AGROW>
end

outputPath = fullfile(projectRoot, 'Results', ...
    sprintf('paper_rerun_%s_J_paper_vs_code.csv', batch.BatchId));
writetable(comparison, outputPath);
fprintf('Wrote combined comparison: %s\n', outputPath);
end
