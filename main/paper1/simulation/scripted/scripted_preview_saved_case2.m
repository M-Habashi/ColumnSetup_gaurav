function fig = scripted_preview_saved_case2(resultPath)
%SCRIPTED_PREVIEW_SAVED_CASE2 Plot/export the newest saved Case II result.
%   This function performs no simulation.

if nargin < 1 || strlength(string(resultPath)) == 0
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    candidates = dir(fullfile(projectRoot, 'Results', ...
        'case_02_*_Nom_.mat'));
    assert(~isempty(candidates), 'No saved Case II result was found.');
    [~, newestIndex] = max([candidates.datenum]);
    resultPath = fullfile(candidates(newestIndex).folder, ...
        candidates(newestIndex).name);
end

saved = load(resultPath);
required = {'t', 'Ref_Resp', 'Num_resp', 'X_m', 'alpha', ...
    'indicator', 'Restoring_force', 'switch_event'};
assert(all(isfield(saved, required)), ...
    'The saved Case II result is missing required plotting data.');

trial = struct;
for fieldIndex = 1:numel(required)
    fieldName = required{fieldIndex};
    trial.(fieldName) = saved.(fieldName);
end

fig = blk_plot_indicator(trial, resultPath, false, true);
fprintf('Opened Case II Controller B result from %s\n', resultPath);
end
