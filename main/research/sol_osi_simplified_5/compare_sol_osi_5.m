function comparison = compare_sol_osi_5()
%COMPARE_SOL_OSI_5 Fabby scorecards for sol_osi_simplified vs _5, side by side.
%
%   comparison = compare_sol_osi_5()
%
%   Runs the Fabby Benchmark twice with the same authority law and the same
%   defaults each estimator ships, and returns one table.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(fullfile(project, 'research', 'sol_osi_simplified'), '-begin');
addpath(here, '-begin');

runners = { ...
    'sol_osi_simplified',   @() run_sol_osi_simplified_benchmark(); ...
    'sol_osi_simplified_5', @() run_sol_osi_simplified_5_benchmark()};

n = size(runners, 1);
results = cell(n, 1);
for i = 1:n
    fprintf('\n===== %s =====\n', runners{i, 1});
    results{i} = runners{i, 2}();
end

names = string(runners(:, 1));
all_gates_pass = cellfun(@(r) r.all_gates_pass, results);
fabby_score_1 = cellfun(@(r) r.scores.fabby_score_1, results);
fabby_score_2 = cellfun(@(r) r.scores.fabby_score_2, results);
S3_detection = cellfun(@(r) r.scores.S3_detection, results);
S4_smoothness = cellfun(@(r) r.scores.S4_smoothness, results);
S5_gdb_recovery = cellfun(@(r) r.scores.S5_gdb_recovery, results);
composite = cellfun(@(r) r.composite, results);
tail_max_a = cellfun(@(r) r.emulation.tail_max_a, results);
unstable_s = cellfun(@(r) r.emulation.unstable_time_s, results);

comparison = table(names, all_gates_pass, fabby_score_1, fabby_score_2, ...
    S3_detection, S4_smoothness, S5_gdb_recovery, composite, ...
    tail_max_a, unstable_s);
disp(comparison)
end
