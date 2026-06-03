%% End to End System Identification for Analog Closed-Loop Transfer Function
 % 1- Estimate the discrete frequency-response transfer function with xfunc
 % 2- Fit a continuous rational transfer function with invfreqs
 % 3- Identify the physical parametric transfer function
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

%% Configure Transfer-Function Estimate and Identification
tf_estimate_config = struct( ...
    'data_file', fullfile(data_files(data_idx).folder, data_name), ...
    'desc', sprintf('%s Analog Closed Loop', plot_data_name), ...
    'f_lim', [0.1, max_freq_hz], ...
    'nn', 1, ...
    'nm', 6, ...
    'fft_length', 2^14, ...
    'overlap', 2^13);

parametric_identification_config = struct( ...
    'mass', 38, ...
    'damping', 416, ...
    'stiffness', 0, ...
    'fit_band_hz', [0.5, max_freq_hz], ...
    'magnitude_weight', 3, ...
    'phase_weight', 0.35, ...
    'num_random_starts', 5, ...
    'max_time', Inf);

%% Get Discrete Transfer Function from xfunc
experimental_data = load(tf_estimate_config.data_file);
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

if isfield(experimental_data, 'kp'), kp = experimental_data.kp; else, kp = 1; end
if isfield(experimental_data, 'ki'), ki = experimental_data.ki; else, ki = 0; end

[tf_points, freq_hz] = xfunc( ...
    dd, ...
    dm, ...
    fs, ...
    tf_estimate_config.fft_length, ...
    tf_estimate_config.overlap);

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
    'tf_discrete', tf_discrete, ...
    'controller', pid(kp, ki), ...
    'controller_gains', struct('Kp', kp, 'Ki', ki));

%% Get Continuous Transfer-Function Fit from invfreqs
[tf_fit_num, tf_fit_den] = invfreqs( ...
    discrete_tf_estimate.tf_points, ...
    discrete_tf_estimate.freq_rad, ...
    tf_estimate_config.nn, ...
    tf_estimate_config.nm, ...
    [], ...
    [], ...
    1e-5);

tf_fit = tf(tf_fit_num, tf_fit_den);

%% Parametric Physical Model Identification
parametric_identification = identify_analog_closed_loop_params( ...
    discrete_tf_estimate, parametric_identification_config);
identified_params = parametric_identification.identified_params;
tf_parametric = parametric_identification.parametric_cl;

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

save(fit_path, 'tf_fit');
save(params_path, ...
    'a1b0', ...
    'a2', ...
    'a3', ...
    'beta1', ...
    'beta2', ...
    'Kp', ...
    'Ki', ...
    'tf_parametric');

%% Conclusion: Three Transfer-Function Models
fprintf('\nIdentified analog closed-loop parameters\n');
fprintf('a1b0 = %.12g\n', identified_params.a1b0);
fprintf('a2 = %.12g\n', identified_params.a2);
fprintf('a3 = %.12g\n', identified_params.a3);
fprintf('beta1 = %.12g\n', identified_params.beta1);
fprintf('beta2 = %.12g\n', identified_params.beta2);
fprintf('Kp = %.12g\n', identified_params.Kp);
fprintf('Ki = %.12g\n', identified_params.Ki);
fprintf('RMS magnitude error = %.4f dB\n', parametric_identification.rms_mag_db);
fprintf('RMS phase error = %.4f deg\n', parametric_identification.rms_phase_deg);

fprintf('\nThree transfer-function models used in the comparison\n');
fprintf('tf_discrete (xfunc): experimental transfer-function estimate from xfunc\n');
fprintf('tf_fit (invfreq): rational fitted transfer function from invfreqs\n');
fprintf('tf_parametric: physical parametric model from the identification\n');

plot_transfer_function_model_comparison( ...
    tf_discrete, ...
    tf_fit, ...
    tf_parametric, ...
    discrete_tf_estimate.freq_hz, ...
    discrete_tf_estimate.freq_rad, ...
    tf_estimate_config);
