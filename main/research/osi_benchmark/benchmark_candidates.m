%% BENCHMARK_CANDIDATES Reference scorecards for the committed candidates.
% Run from anywhere; results land in research/osi_benchmark/results/.

clear
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
cd(here)
warning('off', 'MATLAB:rmpath:DirNotFound')

% gpt5_6_2 (this folder must be first on the path for its gpt_osi/gpt_auth)
try, rmpath(fullfile(project, 'research', 'gpt5_6')); end %#ok<TRYNC>
addpath(fullfile(project, 'research', 'gpt5_6_2', 'fable'))
clear functions %#ok<CLFUNC>
r2 = run_osi_benchmark(@gpt_osi, @gpt_auth, 'gpt5_6_2');
rmpath(fullfile(project, 'research', 'gpt5_6_2', 'fable'))

% gpt5_6_4 (uniquely named functions, no path shadowing)
addpath(fullfile(project, 'research', 'gpt5_6_4', 'codex'))
clear functions %#ok<CLFUNC>
r4 = run_osi_benchmark(@gpt5_6_4_osi, @gpt5_6_4_auth, 'gpt5_6_4');

% original gpt5_6 baseline, for context
addpath(fullfile(project, 'research', 'gpt5_6'))
clear functions %#ok<CLFUNC>
r0 = run_osi_benchmark(@gpt_osi, @gpt_auth, 'gpt5_6_baseline');
rmpath(fullfile(project, 'research', 'gpt5_6'))
