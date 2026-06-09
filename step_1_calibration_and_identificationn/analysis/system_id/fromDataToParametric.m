%% End to End System Identification for Analog Closed-Loop Transfer Function
 % 1- Estimate the discrete frequency-response transfer function with xfunc
 % 2- Identify the physical parametric transfer function
 % 3- Fit a continuous rational transfer function with regularized LS
 % 4- Compare the three transfer-function models

%% Startup
clear
clc
close all
rng(0);

%% Notes
% YOU MUST REVISE fit_config INPUTS FIRST 

%% Inputs
model_name = "";
max_freq_hz = 80;

%% Setup
project_root = fileparts(mfilename('fullpath'));
addpath(project_root);
addpath(fullfile(project_root, 'utils'));

output_root = fullfile(project_root, 'models');
param_output_dir = fullfile(output_root, 'paarametric');
fit_output_dir = fullfile(output_root, 'fit');

if ~exist(output_root, 'dir')
    mkdir(output_root);
end
if ~exist(param_output_dir, 'dir')
    mkdir(param_output_dir);
end
if ~exist(fit_output_dir, 'dir')
    mkdir(fit_output_dir);
end

%% Select Experimental Data
data_dir = fullfile(project_root, 'datafiles');
data_files = dir(fullfile(data_dir, '*.mat'));
[~, order] = sort(string({data_files.name}));
data_files = data_files(order);

fprintf('Available data files:\n');
for i = 1:numel(data_files)
    fprintf('  [%d] %s\n', i, data_files(i).name);
end

data_idx = input('Select data file index: ');
data_name = data_files(data_idx).name;
params_file_name = erase(data_name, '.mat');
if strlength(strtrim(model_name)) > 0
    params_file_name = strtrim(model_name);
end
plot_data_name = strrep(params_file_name, '_', '\_');

%% Select Specimen Parameters
specimen_dir = fullfile(project_root, 'data_speciment');
specimen_files = dir(fullfile(specimen_dir, '*.mat'));
[~, order] = sort(string({specimen_files.name}));
specimen_files = specimen_files(order);

fprintf('Available specimen files:\n');
for i = 1:numel(specimen_files)
    fprintf('  [%d] %s\n', i, specimen_files(i).name);
end

specimen_idx = input('Select specimen file index: ');
specimen_name = specimen_files(specimen_idx).name;
specimen = load(fullfile(specimen_files(specimen_idx).folder, specimen_name));

%% Configure Transfer-Function Estimate and Identification
tf_estimate_config = struct( ...
    'data_file', fullfile(data_files(data_idx).folder, data_name), ...
    'desc', sprintf('%s Analog Closed Loop', plot_data_name), ...
    'f_lim', [0.1, max_freq_hz], ...
    'fit_max_num_order', 1, ...
    'fit_den_orders', [4, 5, 6], ...
    'fit_regularization', 1e-5, ...
    'fit_iterations', 25, ...
    'fit_coherence_min', 0.8, ...
    'fit_input_power_range_db', 40, ...
    'fft_length', 2^15, ...
    'overlap', 2^14);

parametric_identification_config = struct( ...
    'mass', specimen.m, ...
    'damping', specimen.c, ...
    'stiffness', specimen.k, ...
    'specimen_file', fullfile(specimen_files(specimen_idx).folder, specimen_name), ...
    'fit_band_hz', [0.5, max_freq_hz], ...
    'magnitude_weight', 3, ...
    'phase_weight', 0.35, ...
    'num_random_starts', 5, ...
    'max_time', Inf);

%% Get Discrete Transfer Function from xfunc
experimental_data = load(tf_estimate_config.data_file);
if isfield(experimental_data, 'test_type')
    test_type = char(string(experimental_data.test_type));
elseif isfield(experimental_data, 'testname')
    test_type = char(string(experimental_data.testname));
else
    test_type = 'unknown';
end
tf_estimate_config.test_type = test_type;

if all(isfield(experimental_data, {'dd', 'dm', 'fs'}))
    dd = experimental_data.dd;
    dm = experimental_data.dm;
    fs = experimental_data.fs;
else
    sig = experimental_data.logsout.FileLogSignals{1}.Values;
    signal_names = string({sig.DataInfo.Units});
    dd = sig.Data(:, strcmpi(signal_names, 'dd'));
    dm = sig.Data(:, strcmpi(signal_names, 'dm'));
    fs = 1 / mean(diff(sig.Time(:)));
end

controller_gains = struct('Kp', NaN, 'Ki', NaN, 'Estimated', true);

[tf_points, freq_hz, spectra] = xfunc( ...
    dd, ...
    dm, ...
    fs, ...
    tf_estimate_config.fft_length, ...
    tf_estimate_config.overlap);

tf_points_all = tf_points(:);
freq_hz_all = freq_hz(:);
coherence_all = abs(spectra(:,3)).^2 ./ max(spectra(:,1).*spectra(:,2), eps);
input_power_db_all = 10 * log10(spectra(:,1) + eps);

keep_idx = freq_hz >= tf_estimate_config.f_lim(1) & freq_hz <= tf_estimate_config.f_lim(2);
freq_hz = freq_hz(keep_idx);
tf_points = tf_points(keep_idx);
freq_rad = 2 * pi * freq_hz;

% FRD means frequency-response data: measured complex TF samples plus frequency.
tf_discrete = frd(tf_points(:), freq_rad(:));

discrete_tf_estimate = struct( ...
    'config', tf_estimate_config, ...
    'dd', dd, ...
    'dm', dm, ...
    'fs', fs, ...
    'tf_points', tf_points(:), ...
    'freq_hz', freq_hz(:), ...
    'freq_rad', freq_rad(:), ...
    'coherence', coherence_all(keep_idx), ...
    'tf_discrete', tf_discrete, ...
    'controller', [], ...
    'controller_gains', controller_gains);

%% Parametric Physical Model Identification
parametric_identification = identify_analog_closed_loop_params( ...
    discrete_tf_estimate, parametric_identification_config);
identified_params = parametric_identification.identified_params;
tf_parametric = parametric_identification.parametric_cl;

%% Get Continuous Transfer-Function Fit
band_fit_idx = freq_hz_all >= tf_estimate_config.f_lim(1) & ...
    freq_hz_all <= tf_estimate_config.f_lim(2);
fit_idx = band_fit_idx & ...
    coherence_all >= tf_estimate_config.fit_coherence_min & ...
    input_power_db_all >= max(input_power_db_all(band_fit_idx)) - tf_estimate_config.fit_input_power_range_db;
tf_fit_points = [1; tf_points_all(fit_idx)];
tf_fit_freq_hz = [0; freq_hz_all(fit_idx)];
tf_fit_freq_rad = 2 * pi * tf_fit_freq_hz;
tf_fit_weight = ones(size(tf_fit_freq_hz));

best_fit_score = Inf;
best_any_score = Inf;
tf_fit = [];
for denominator_order = tf_estimate_config.fit_den_orders
    numerator_order = min(tf_estimate_config.fit_max_num_order, denominator_order - 1);
    [candidate_num, candidate_den, candidate_info] = regularized_rational_fit( ...
        tf_fit_points, ...
        tf_fit_freq_rad, ...
        numerator_order, ...
        denominator_order, ...
        tf_estimate_config.fit_regularization, ...
        tf_fit_weight, ...
        struct('max_iterations', tf_estimate_config.fit_iterations, ...
            'phase_weight', parametric_identification_config.phase_weight));
    candidate_tf = tf(candidate_num, candidate_den);
    candidate_poles = pole(candidate_tf);
    candidate_resp = squeeze(freqresp(candidate_tf, tf_fit_freq_rad(2:end)));
    candidate_mag_error = rms(20 * log10(abs(candidate_resp) + eps) - ...
        20 * log10(abs(tf_fit_points(2:end)) + eps));
    candidate_phase_error = rms(unwrap(angle(candidate_resp)) * 180 / pi - ...
        unwrap(angle(tf_fit_points(2:end))) * 180 / pi);
    candidate_score = candidate_mag_error + 0.02 * candidate_phase_error;
    candidate_info.numerator_order = numerator_order;
    candidate_info.denominator_order = denominator_order;
    candidate_info.fit_score = candidate_score;
    candidate_info.rms_mag_db = candidate_mag_error;
    candidate_info.rms_phase_deg = candidate_phase_error;
    candidate_info.is_stable = all(real(candidate_poles) < 0);
    if candidate_score < best_any_score
        best_any_score = candidate_score;
        best_any_tf = candidate_tf;
        best_any_num = candidate_num;
        best_any_den = candidate_den;
        best_any_info = candidate_info;
    end
    if all(real(candidate_poles) < 0) && candidate_score < best_fit_score
        best_fit_score = candidate_score;
        tf_fit = candidate_tf;
        tf_fit_num = candidate_num;
        tf_fit_den = candidate_den;
        tf_fit_info = candidate_info;
    end
end
if isempty(tf_fit)
    tf_fit = best_any_tf;
    tf_fit_num = best_any_num;
    tf_fit_den = best_any_den;
    tf_fit_info = best_any_info;
    fprintf('No stable standalone fit found; using the lowest-error candidate.\n');
end
tf_fit_info.fit_point_count = nnz(fit_idx);
tf_fit_info.fit_band_hz = [min(freq_hz_all(fit_idx)), max(freq_hz_all(fit_idx))];
tf_fit_info.coherence_min = tf_estimate_config.fit_coherence_min;
tf_fit_info.input_power_range_db = tf_estimate_config.fit_input_power_range_db;
tf_fit_info.test_type = test_type;

%% Save Identified Parameters and Models
params_path = fullfile(param_output_dir, sprintf('%s.mat', params_file_name));
fit_path = fullfile(fit_output_dir, sprintf('%s_fit.mat', params_file_name));
a1b0 = identified_params.a1b0;
a2 = identified_params.a2;
a3 = identified_params.a3;
beta1 = identified_params.beta1;
beta2 = identified_params.beta2;
Kp = identified_params.Kp;
Ki = identified_params.Ki;

save(fit_path, 'tf_fit', 'tf_fit_info', 'test_type');
save(params_path, ...
    'a1b0', ...
    'a2', ...
    'a3', ...
    'beta1', ...
    'beta2', ...
    'Kp', ...
    'Ki', ...
    'test_type', ...
    'tf_parametric');

%% Conclusion: Three Transfer-Function Models
fprintf('\nIdentified analog closed-loop parameters\n');
fprintf('Data file = %s\n', data_name);
fprintf('Test type = %s\n', test_type);
fprintf('a1b0 = %.12g\n', identified_params.a1b0);
fprintf('a2 = %.12g\n', identified_params.a2);
fprintf('a3 = %.12g\n', identified_params.a3);
fprintf('beta1 = %.12g\n', identified_params.beta1);
fprintf('beta2 = %.12g\n', identified_params.beta2);
fprintf('Kp = %.12g\n', identified_params.Kp);
fprintf('Ki = %.12g\n', identified_params.Ki);
fprintf('RMS magnitude error = %.4f dB\n', parametric_identification.rms_mag_db);
fprintf('RMS phase error = %.4f deg\n', parametric_identification.rms_phase_deg);

tf_fit_resp = squeeze(freqresp(tf_fit, 2 * pi * freq_hz_all(fit_idx)));
tf_parametric_resp = squeeze(freqresp(tf_parametric, 2 * pi * freq_hz_all(fit_idx)));
mag_fit_db = 20 * log10(abs(tf_fit_resp) + eps);
mag_discrete_db = 20 * log10(abs(tf_points_all(fit_idx)) + eps);
mag_parametric_db = 20 * log10(abs(tf_parametric_resp) + eps);
phase_fit_deg = unwrap(angle(tf_fit_resp)) * 180 / pi;
phase_discrete_deg = unwrap(angle(tf_points_all(fit_idx))) * 180 / pi;
phase_parametric_deg = unwrap(angle(tf_parametric_resp)) * 180 / pi;

fprintf('\nStandalone fit RMS comparison over reliable %.3g-%.3g Hz bins\n', ...
    tf_fit_info.fit_band_hz);
fprintf('vs xfunc: %.4f dB, %.4f deg\n', ...
    rms(mag_fit_db - mag_discrete_db), rms(phase_fit_deg - phase_discrete_deg));
fprintf('vs parametric ID: %.4f dB, %.4f deg\n', ...
    rms(mag_fit_db - mag_parametric_db), rms(phase_fit_deg - phase_parametric_deg));
fprintf('standalone fit points = %d, order = %d/%d, iterations = %d, lambda = %.3g\n', ...
    tf_fit_info.fit_point_count, tf_fit_info.numerator_order, ...
    tf_fit_info.denominator_order, tf_fit_info.iterations, tf_fit_info.lambda);

fprintf('\nThree transfer-function models used in the comparison\n');
fprintf('tf_discrete (xfunc): experimental transfer-function estimate from xfunc\n');
fprintf('tf_fit (regularized): rational fitted transfer function from regularized LS\n');
fprintf('tf_parametric: physical parametric model from the identification\n');

plot_transfer_function_model_comparison( ...
    tf_discrete, ...
    tf_fit, ...
    tf_parametric, ...
    discrete_tf_estimate.freq_hz, ...
    discrete_tf_estimate.freq_rad, ...
    tf_estimate_config);
