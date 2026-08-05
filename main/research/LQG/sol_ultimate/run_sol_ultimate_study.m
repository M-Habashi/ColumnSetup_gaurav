function result = run_sol_ultimate_study
%RUN_SOL_ULTIMATE_STUDY Reproduce the baseline and comparator evidence.

studyFolder = fileparts(mfilename('fullpath'));
result = struct;
result.source_evidence = analyze_source_evidence;
result.baseline_lqg = analyze_lqg_baseline;
result.endpoint_tangent_margin = analyze_endpoint_tangent_margin;
result.lqgi_comparator = analyze_lqgi_comparator;
save(fullfile(studyFolder, 'sol_ultimate_study.mat'), 'result')
fprintf('Saved combined study to %s\n', ...
    fullfile(studyFolder, 'sol_ultimate_study.mat'))
end
