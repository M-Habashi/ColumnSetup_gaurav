% Uses the official windowed noise-whitened TLS + non-overlap KF method.
%% Units
% Input saved data: t [s], displacement [mm], force [N], acceleration [g].
% Output specimen: m [kg], c [N*s/m], k [N/m].
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
[~, data_file, selected_data_file] = load_saved_result_file(step_root, 'tests');

%% Estimate selected file
estimator_config = official_tls_config;
[D, noiseD] = prep_specimen_data(data_file, ...
    estimator_config.noise_duration, estimator_config.filter_hz);
noise_scale = std([noiseD.a noiseD.v noiseD.x noiseD.F], 0, 1);
noise_scale(noise_scale == 0) = 1;
D = trim_recording_time_window(D, @(window) specimen_preview( ...
    D, noise_scale, estimator_config, window));
trim_time_window = D.trim_time_window;
estimate = windowed_noise_whitened_tls(D.t, D.a, D.v, D.x, D.F, ...
    noise_scale, estimator_config);
last = find(all(isfinite(estimate.theta_kf), 2), 1, 'last');
theta = estimate.theta_kf(last, :)';

%% Convert selected estimate
m = theta(1);
c = theta(2);
k = theta(3);

%% Parameter units
units.m = 'kg';
units.c = 'N*s/m';
units.k = 'N/m';

%% Save specimen MAT file
source_method = 'Windowed noise-whitened TLS + non-overlap KF';
source_file = selected_data_file;
source_path = data_file;

if isfile(out_file)
    error('Specimen file already exists: %s', out_file)
end

save(out_file, ...
    'm', 'c', 'k', 'units', 'source_method', 'source_file', 'source_path', ...
    'specimen_id', 'estimator_config', 'noise_scale', 'trim_time_window')

%% Print summary
fprintf('Saved %s using the official noise-whitened TLS method.\n', out_file)
fprintf('m = %.6g kg\n', m)
fprintf('c = %.6g N*s/m\n', c)
fprintf('k = %.6g N/m (%.6g kip/in)\n', k, k*0.0254/4448.2216152605)

function text = specimen_preview(D, noise_scale, config, window)
keep = D.t >= window(1) & D.t <= window(2);
if nnz(keep) < 2 || window(2) - window(1) < config.window_s
    text = 'Preview unavailable: select a longer window';
    return
end
estimate = windowed_noise_whitened_tls(D.t(keep), D.a(keep), D.v(keep), ...
    D.x(keep), D.F(keep), noise_scale, config);
last = find(all(isfinite(estimate.theta_kf), 2), 1, 'last');
if isempty(last)
    text = 'Preview unavailable: select a longer or sufficiently excited window';
    return
end
theta = estimate.theta_kf(last, :);
text = sprintf(['Preview:  m = %.4g kg    c = %.4g N*s/m    ' ...
    'k = %.4g N/m (%.4g kip/in)'], theta(1), theta(2), theta(3), ...
    theta(3)*0.0254/4448.2216152605);
end
