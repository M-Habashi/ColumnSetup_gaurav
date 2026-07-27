function comparison = compare_fabby_bench_2()
%COMPARE_FABBY_BENCH_2 Compare SOL-OSI V1 with the current implementation.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(here, '-begin');
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin');
addpath(fullfile(project, 'research', 'osi_benchmark'));
rehash;

estimators = { ...
    "sol_osi_v1",   @sol_osi_v1; ...
    "sol_osi",      @sol_osi};

results = cell(size(estimators, 1), 1);
for i = 1:size(estimators, 1)
    label = "fabby_bench_2_" + estimators{i, 1};
    fprintf('\n===== %s =====\n', label);
    results{i} = run_osi_benchmark( ...
        estimators{i, 2}, @gpt5_6_4_auth, char(label), 0.30);
end

names = string(estimators(:, 1));
all_gates_pass = cellfun(@(r) r.all_gates_pass, results);
fabby_score_1 = cellfun(@(r) r.scores.fabby_score_1, results);
fabby_score_2 = cellfun(@(r) r.scores.fabby_score_2, results);
S3_detection = cellfun(@(r) r.scores.S3_detection, results);
S4_smoothness = cellfun(@(r) r.scores.S4_smoothness, results);
S5_gdb_recovery = cellfun(@(r) r.scores.S5_gdb_recovery, results);
composite = cellfun(@(r) r.composite, results);
roughness = cellfun(@(r) r.roughness, results);
tail_max_a = cellfun(@(r) r.emulation.tail_max_a, results);
unstable_s = cellfun(@(r) r.emulation.unstable_time_s, results);

comparison = table(names, all_gates_pass, fabby_score_1, fabby_score_2, ...
    S3_detection, S4_smoothness, S5_gdb_recovery, composite, ...
    roughness, tail_max_a, unstable_s);
disp(comparison);

results_folder = fullfile(here, 'results');
if ~isfolder(results_folder), mkdir(results_folder); end
result = struct('synthetic_target', 0.55, 'experimental_target', 0.30, ...
    'comparison', comparison, ...
    'implementations', {results});
save(fullfile(results_folder, 'fabby_bench_2_comparison.mat'), ...
    'result', '-v7.3');
end
