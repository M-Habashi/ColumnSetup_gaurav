function result = run_sol_osi_benchmark
%RUN_SOL_OSI_BENCHMARK Run the historical Fabby Benchmark for SOL-OSI V1.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(fileparts(here)));
benchmark_folder = fullfile(project, 'research', 'osi_benchmark');
addpath(here, '-begin')
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin')
addpath(benchmark_folder)
cd(benchmark_folder)
clear functions
rehash
result = run_osi_benchmark(@sol_osi_v1, @gpt5_6_4_auth, 'sol_osi_v1');
end
