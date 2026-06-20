% Uses the unscaled TSE method implemented in research/specimen_mode/methods/estimate_tse.m.
clear; clc

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));
addpath(fullfile(step_root, 'research', 'specimen_mode', 'methods'))
addpath(step_root)
addpaths();

%% Specimen setup
out_dir = fullfile(step_root, 'saved_results', 'specimens');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

specimen_name = input('Enter specimen name (without .mat): ', 's');
out_file = fullfile(out_dir, [specimen_name '.mat']);
if isfile(out_file)
    error('Specimen file already exists: %s', out_file)
end

specimen_id = 'sp_1_test';

%% Select data file
% Pick the data file used for the unscaled TSE estimate.
[~, data_file, selected_data_file] = load_saved_result_file(step_root, 'tests');

%% Estimate selected file with TSE
D = prep_specimen_data(data_file);
D = trim_recording_time_window(D);
trim_time_window = D.trim_time_window;
fit = estimate_tse(D, []);

%% Convert selected estimate
% Method functions return m in kg.
m = fit.m;
c = fit.c;
k = fit.k;

%% Parameter units
units.m = 'kg';
units.c = 'N*s/mm';
units.k = 'N/mm';

%% Save specimen MAT file
source_method = 'TSE';
source_file = selected_data_file;
source_path = data_file;

if isfile(out_file)
    error('Specimen file already exists: %s', out_file)
end

save(out_file, ...
    'm', 'c', 'k', 'units', 'source_method', 'source_file', 'source_path', ...
    'specimen_id', 'trim_time_window')

%% Print summary
fprintf('Saved %s using unscaled TSE.\n', out_file)
fprintf('m = %.6g kg\n', m)
fprintf('c = %.6g N*s/mm\n', c)
fprintf('k = %.6g N/mm\n', k)
