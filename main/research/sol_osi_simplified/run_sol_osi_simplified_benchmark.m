function result = run_sol_osi_simplified_benchmark(eta_A, override)
%RUN_SOL_OSI_SIMPLIFIED_BENCHMARK Run Fabby with frequency-dependent rho.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
benchmark_folder = fullfile(project, 'research', 'osi_benchmark');

if nargin < 1
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

sol_osi_simplified('set_eta', eta_A);
sol_osi_simplified('set_override', override);
cleanup = onCleanup(@() sol_osi_simplified('set_override', struct()));
result = run_osi_benchmark( ...
    @sol_osi_simplified, @gpt5_6_4_auth, 'sol_osi_simplified');
result.eta_A = eta_A;
result.override = override;

results_folder = fullfile(here, 'results');
if ~isfolder(results_folder), mkdir(results_folder); end
save(fullfile(results_folder, ...
    'sol_osi_simplified_benchmark.mat'), 'result', '-v7.3');

benchmark_result = fullfile(benchmark_folder, 'results', ...
    'sol_osi_simplified_benchmark.mat');
if isfile(benchmark_result), delete(benchmark_result); end
end
