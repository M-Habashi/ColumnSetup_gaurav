function outputs = scripted_replot_saved_cases
%SCRIPTED_REPLOT_SAVED_CASES Regenerate paper Cases I--IV from saved data.
%   This function performs no simulation. It loads the newest saved nominal
%   trajectory for each case and sends it through the current plotter.

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
resultsDir = fullfile(projectRoot, 'Results');
outputs = strings(4, 1);

for caseNumber = 1:4
    pattern = sprintf('case_%02d_*_Nom_.mat', caseNumber);
    candidates = dir(fullfile(resultsDir, pattern));
    assert(~isempty(candidates), ...
        'No saved nominal trajectory was found for case %d.', caseNumber);
    [~, newestIndex] = max([candidates.datenum]);
    resultPath = fullfile(candidates(newestIndex).folder, ...
        candidates(newestIndex).name);
    saved = load(resultPath);

    required = {'t', 'Ref_Resp', 'Num_resp', 'X_m', 'alpha', ...
        'indicator', 'Restoring_force', 'switch_event'};
    assert(all(isfield(saved, required)), ...
        'Saved case %d is missing data required by the plotter.', caseNumber);

    trial = struct;
    for fieldIndex = 1:numel(required)
        fieldName = required{fieldIndex};
        trial.(fieldName) = saved.(fieldName);
    end

    exportHysteresis = caseNumber == 4;
    if exportHysteresis
        hysteresisRequired = {'BoucWen', 'options'};
        assert(all(isfield(saved, hysteresisRequired)), ...
            'Saved Case IV data cannot reconstruct specimen displacement.');
        elasticStiffness = 1190e3;
        postYieldRatio = saved.options.post_yield_ratio;
        alphaStart = saved.options.alpha_start;
        kx = postYieldRatio * alphaStart * elasticStiffness;
        kw = (1 - postYieldRatio) * alphaStart * elasticStiffness;
        forceN = saved.Restoring_force.Data(:, 1);
        hystereticState = saved.BoucWen.Data(:, 1);
        trial.block_signals = struct('x_internal', ...
            (forceN - kw * hystereticState) / kx);
    end

    blk_plot_indicator(trial, resultPath, exportHysteresis);
    outputs(caseNumber) = string(resultPath);
    fprintf('Regenerated Case %d from %s\n', caseNumber, resultPath);
end
end
