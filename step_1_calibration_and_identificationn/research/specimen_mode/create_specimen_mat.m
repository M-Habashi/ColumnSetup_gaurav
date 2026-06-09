clear; clc

%% Specimen setup
% Edit this name to choose the output MAT file name.
specimen_name = 'sp1';

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'methods'))

specimen_id = 'sp_1';

%% Select data files
% Pick the data files used for the unscaled TSE estimate.
files = dir(fullfile(root, 'data', '*.mat'));
for i = 1:numel(files)
    fprintf('%d) %s\n', i, files(i).name)
end

idx = input('Select data file number: ');

%% Estimate selected file with TSE
D = prep_specimen_data(fullfile(files(idx).folder, files(idx).name));
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
source_file = files(idx).name;
out_file = fullfile(root, [specimen_name '.mat']);

save(out_file, ...
    'm', 'c', 'k', 'units')

%% Print summary
fprintf('Saved %s using unscaled TSE.\n', out_file)
fprintf('m = %.6g kg\n', m)
fprintf('c = %.6g N*s/mm\n', c)
fprintf('k = %.6g N/mm\n', k)
