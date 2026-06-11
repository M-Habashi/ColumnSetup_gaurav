clear; clc

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));
addpath(fullfile(root, 'methods'))
addpath(fullfile(step_root, 'helpers', 'utils'))
setup_project_paths(step_root);

fprintf('Select chirp data file.\n')
[~, chirp_file] = load_saved_result_file(step_root, 'tests');
fprintf('Select BLWN data file.\n')
[~, blwn_file] = load_saved_result_file(step_root, 'tests');
fprintf('Select noise data file.\n')
[~, noise_file] = load_saved_result_file(step_root, 'tests');
fprintf('Select slow sine data file.\n')
[~, slow_file] = load_saved_result_file(step_root, 'tests');

chirp = prep_specimen_data(chirp_file);
blwn = prep_specimen_data(blwn_file);
noise = prep_specimen_data(noise_file);
slow = prep_specimen_data(slow_file);

slow_k = estimate_slow_k(slow);

methods = {
    @estimate_lse
    @estimate_tse
    @estimate_scaled_tse
    @estimate_frf_h1
    @estimate_frf_h2
    @estimate_frf_hv
    @estimate_frf_coh
    @estimate_twice_integrated
    @estimate_iv
    @estimate_mcmc
    @estimate_mcmc2
};

n = numel(methods);
method_name = cell(n, 1);
chirp_m = zeros(n, 1);
chirp_c = zeros(n, 1);
chirp_k = zeros(n, 1);
chirp_accuracy = zeros(n, 1);
blwn_m = zeros(n, 1);
blwn_c = zeros(n, 1);
blwn_k = zeros(n, 1);
blwn_accuracy = zeros(n, 1);

for i = 1:n
    chirp_fit = methods{i}(chirp, noise);
    blwn_fit = methods{i}(blwn, noise);

    method_name{i} = chirp_fit.method;
    chirp_m(i) = chirp_fit.m;
    chirp_c(i) = chirp_fit.c;
    chirp_k(i) = chirp_fit.k;
    chirp_accuracy(i) = 100 * (1 - abs(chirp_fit.k - slow_k) / abs(slow_k));

    blwn_m(i) = blwn_fit.m;
    blwn_c(i) = blwn_fit.c;
    blwn_k(i) = blwn_fit.k;
    blwn_accuracy(i) = 100 * (1 - abs(blwn_fit.k - slow_k) / abs(slow_k));
end

T = table(method_name, ...
    chirp_m, chirp_c, chirp_k, chirp_accuracy, ...
    blwn_m, blwn_c, blwn_k, blwn_accuracy);
T.Properties.VariableNames = {'method', ...
    'chirp_m (kg)', 'chirp_c (N*s/mm)', 'chirp_k (N/mm)', 'chirp_accuracy (%)', ...
    'BLWN_m (kg)', 'BLWN_c (N*s/mm)', 'BLWN_k (N/mm)', 'BLWN_accuracy (%)'};

fprintf('Slow sine validation k = %.6g N/mm\n\n', slow_k)
disp(T)

[~, best_chirp] = max(chirp_accuracy);
[~, best_blwn] = max(blwn_accuracy);
fprintf('\nBest chirp k validation: %s (%.2f%%)\n', method_name{best_chirp}, chirp_accuracy(best_chirp))
fprintf('Best BLWN k validation:  %s (%.2f%%)\n', method_name{best_blwn}, blwn_accuracy(best_blwn))
