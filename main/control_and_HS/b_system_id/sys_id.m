%% End to End System Identification for Analog Closed-Loop Transfer Function
 % 1- Estimate the discrete frequency-response transfer function with xfunc
 % 2- Identify the physical parametric transfer function
 % 3- Fit a continuous rational transfer function with regularized LS
 % 4- Compare the three transfer-function models

%% Units
% Loaded dd and dm are stored in mm; their ratio and all transfer functions
% are dimensionless. Time is s, frequency is Hz or rad/s, mass is kg,
% damping is N*s/m, and stiffness is N/m.

%% Startup
clear
clc
close all
rng(0);

%% Notes
% YOU MUST REVISE fit_config INPUTS FIRST 

%% Inputs
max_freq_hz = 80;

%% Setup
project_root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(project_root));
addpath(step_root);
addpaths();

output_root = fullfile(step_root, 'saved_results', 'models');
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
[experimental_data, data_file, data_name] = load_saved_result_file(step_root, 'tests');
[~, params_file_name] = fileparts(data_file);
plot_data_name = strrep(params_file_name, '_', '\_');

%% Select Specimen Parameters
[specimen, specimen_file, specimen_name] = load_saved_result_file(step_root, 'specimens');

%% Configure Transfer-Function Estimate and Identification
specimen_si = specimen_params_si(specimen);
tf_estimate_config = struct( ...
    'data_file', data_file, ...                                         % selected measured data MAT file
    'desc', sprintf('%s Analog Closed Loop', plot_data_name), ...        % plot title/description text
    'f_lim', [0.1, max_freq_hz], ...                                     % frequency range used for xfunc output
    'fit_num_order', 1, ...                                              % numerator order for raw TF fit
    'fit_den_order', 4, ...                                              % denominator order for raw TF fit
    'fit_regularization', 0, ...                                         % regularization strength for TF fit
    'fit_iterations', 25, ...                                            % maximum iterations for TF fit
    'fit_coherence_min', 0.8, ...                                        % minimum coherence for fit data selection
    'fit_input_power_range_db', 40, ...                                  % input-power window below peak for fit data selection
    'fft_length', 2^15, ...                                              % FFT segment length for xfunc
    'overlap', 2^14);                                                    % FFT segment overlap for xfunc

parametric_identification_config = struct( ...
    'mass', specimen_si.mass, ...                                                    % kg
    'damping', specimen_si.damping, ...                                              % N*s/m
    'stiffness', specimen_si.stiffness, ...                                          % N/m
    'specimen_file', specimen_file, ...                                            % selected specimen parameter MAT file
    'fit_band_hz', [0.5, max_freq_hz], ...                                          % frequency band emphasized in parametric fit
    'magnitude_weight', 3, ...                                                      % magnitude-error weight inside fit band
    'phase_weight', 0.35, ...                                                       % phase-error weight relative to magnitude
    'frequency_weight_exponent', 1, ...  % the higher → gives more weight to lower freq. [KEEP THIS COMMENT]
    'frequency_weight_floor_hz', 0, ...                                             % lowest frequency used when computing frequency weights
    'num_random_starts', 5, ...                                                     % number of random starts for MultiStart
    'max_time', 60);                                                                % maximum MultiStart solve time in seconds

%% Get Discrete Transfer Function from xfunc
experimental_data = trim_recording_time_window(experimental_data);
trim_time_window = experimental_data.trim_time_window;
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
    if isfield(experimental_data, 't') && numel(experimental_data.t) == numel(dd)
        t = experimental_data.t(:);
    elseif isfield(experimental_data, 'tt') && numel(experimental_data.tt) == numel(dd)
        t = experimental_data.tt(:);
    else
        t = (0:numel(dd)-1).' / fs;
    end
else
    sig = experimental_data.logsout.FileLogSignals{1}.Values;
    signal_names = string({sig.DataInfo.Units});
    dd = sig.Data(:, strcmpi(signal_names, 'dd'));
    dm = sig.Data(:, strcmpi(signal_names, 'dm'));
    fs = 1 / mean(diff(sig.Time(:)));
    t = sig.Time(:);
end
dd = dd(:);
dm = dm(:);
t = t(:) - t(1);

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
tf_fit_points = tf_points_all(fit_idx);
tf_fit_freq_hz = freq_hz_all(fit_idx);
tf_fit_freq_rad = 2 * pi * tf_fit_freq_hz;
tf_fit_weight = ones(size(tf_fit_freq_hz));

[tf_fit_num, tf_fit_den, tf_fit_info] = regularized_rational_fit( ...
    tf_fit_points, ...
    tf_fit_freq_rad, ...
    tf_estimate_config.fit_num_order, ...
    tf_estimate_config.fit_den_order, ...
    tf_estimate_config.fit_regularization, ...
    tf_fit_weight, ...
    struct('max_iterations', tf_estimate_config.fit_iterations, ...
        'phase_weight', parametric_identification_config.phase_weight));
tf_fit = tf(tf_fit_num, tf_fit_den);
tf_fit_resp = squeeze(freqresp(tf_fit, tf_fit_freq_rad));
tf_fit_info.numerator_order = tf_estimate_config.fit_num_order;
tf_fit_info.denominator_order = tf_estimate_config.fit_den_order;
tf_fit_info.rms_mag_db = rms(20 * log10(abs(tf_fit_resp) + eps) - ...
    20 * log10(abs(tf_fit_points) + eps));
tf_fit_info.rms_phase_deg = rms(unwrap(angle(tf_fit_resp)) * 180 / pi - ...
    unwrap(angle(tf_fit_points)) * 180 / pi);
tf_fit_info.is_stable = isstable(tf_fit);
tf_fit_info.was_stabilized = false;
tf_fit_info.fit_point_count = numel(tf_fit_freq_hz);
tf_fit_info.fit_band_hz = [min(tf_fit_freq_hz), max(tf_fit_freq_hz)];
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
specimen_params = specimen;
specimen_params.name = specimen_name;
specimen_params.file = parametric_identification_config.specimen_file;
specimen_params.m = specimen.m;
specimen_params.c = specimen.c;
specimen_params.k = specimen.k;
id_units = specimen_si.units;

save(fit_path, 'tf_fit', 'tf_fit_info', 'test_type');
save(params_path, ...
    'a1b0', ...
    'a2', ...
    'a3', ...
    'beta1', ...
    'beta2', ...
    'Kp', ...
    'Ki', ...
    'specimen_params', ...
    'id_units', ...
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

tf_comparison_freq_hz = tf_fit_freq_hz;
tf_comparison_points = tf_fit_points;
tf_fit_resp = squeeze(freqresp(tf_fit, 2 * pi * tf_comparison_freq_hz));
tf_parametric_resp = squeeze(freqresp(tf_parametric, 2 * pi * tf_comparison_freq_hz));
mag_fit_db = 20 * log10(abs(tf_fit_resp) + eps);
mag_discrete_db = 20 * log10(abs(tf_comparison_points) + eps);
mag_parametric_db = 20 * log10(abs(tf_parametric_resp) + eps);
phase_fit_deg = unwrap(angle(tf_fit_resp)) * 180 / pi;
phase_discrete_deg = unwrap(angle(tf_comparison_points)) * 180 / pi;
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
fprintf('Saved fit model = %s\n', fit_path);
fprintf('Saved parametric model = %s\n', params_path);

plot_transfer_function_model_comparison( ...
    tf_discrete, ...
    tf_fit, ...
    tf_parametric, ...
    discrete_tf_estimate.freq_hz, ...
    discrete_tf_estimate.freq_rad, ...
    tf_estimate_config);

%% Time-Domain Measured and Identified Response
fit_color = [144 21 0] / 255;        % #901500
parametric_color = [46 158 78] / 255; % darker #39BF5E
dm_fit = lsim(tf_fit, dd, t);
dm_parametric = lsim(tf_parametric, dd, t);

figure('Name', 'Time-Domain Transfer-Function Identification', 'Color', 'w');
plot(t, dd, '--', 'Color', [0 0 0], 'LineWidth', 1.8, ...
    'DisplayName', 'Input displacement d_d');
hold on
plot(t, dm, '-', 'Color', [0 0.486 0.659], 'LineWidth', 1.2, ...
    'DisplayName', 'Measured displacement d_m');
plot(t, dm_fit, '-', 'Color', fit_color, 'LineWidth', 1.4, ...
    'DisplayName', 'tf_{fit} d_m from lsim');
plot(t, dm_parametric, '--', 'Color', parametric_color, 'LineWidth', 1.6, ...
    'DisplayName', 'tf_{parametric} d_m from lsim');
grid on
xlabel('Time (s)');
ylabel('Displacement (mm)');
title(sprintf('%s Time-Domain Identification', plot_data_name));
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggle_legend_item;

fprintf('\nDebug data selection\n');
fprintf('Data file = %s\n', tf_estimate_config.data_file);
fprintf('Time window = [%.6g, %.6g] s\n', trim_time_window(1), trim_time_window(2));

function toggle_legend_item(~, event)
% Units: graphics handles and visibility state are unitless.
    if strcmp(event.Peer.Visible, 'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
end
