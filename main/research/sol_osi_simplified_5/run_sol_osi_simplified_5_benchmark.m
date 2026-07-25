function result = run_sol_osi_simplified_5_benchmark(eta_A, override)
%RUN_SOL_OSI_SIMPLIFIED_5_BENCHMARK Run Fabby with per-frequency fusion.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
benchmark_folder = fullfile(project, 'research', 'osi_benchmark');

if nargin < 1 || isempty(eta_A)
    eta_A = 0.0575;
end
if nargin < 2
    override = struct();
end

addpath(here, '-begin');
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin');
addpath(benchmark_folder);
cd(benchmark_folder);
rehash;

sol_osi_simplified_5('set_eta', eta_A);
sol_osi_simplified_5('set_override', override);
cleanup = onCleanup(@() sol_osi_simplified_5('set_override', struct())); %#ok<NASGU>
result = run_osi_benchmark( ...
    @sol_osi_simplified_5, @gpt5_6_4_auth, 'sol_osi_simplified_5');
result.eta_A = eta_A;
result.override = override;

results_folder = fullfile(here, 'results');
if ~isfolder(results_folder), mkdir(results_folder); end
save(fullfile(results_folder, ...
    'sol_osi_simplified_5_benchmark.mat'), 'result', '-v7.3');

benchmark_result = fullfile(benchmark_folder, 'results', ...
    'sol_osi_simplified_5_benchmark.mat');
if isfile(benchmark_result), delete(benchmark_result); end
end
