%% Digital Controller Dynamics
% Compare the experimentally identified inner system dc -> dm, the final
% experimental system dd -> dm, and the inner system closed around the
% actual discrete PID controller.

%% Inputs
P = 0.15;
I = 20;
D = 0.0015;
derivative_filter_N = 512;
max_freq_hz = 80;
if ~exist('data_file', 'var'), data_file = ''; end
if ~exist('use_trim_selector', 'var'), use_trim_selector = true; end

%% Setup
clear functions
clc
close all
rng(0)

script_root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(script_root));
addpath(fullfile(step_root, 'helpers', 'utils'))
addpath(fullfile(step_root, 'control_and_HS', 'b_system_id', 'utils'))
addpath(fullfile(script_root, 'stability_utils'))

fit_config = struct( ...
    'f_lim', [0.1, max_freq_hz], ...
    'num_order', 4, ...
    'den_order', 7, ...
    'regularization', 1e-5, ...
    'iterations', 100, ...
    'coherence_min', 0.8, ...
    'input_power_range_db', 40, ...
    'fft_length', 2^15, ...
    'overlap', 2^14);

%% Select and Trim Experimental Data
if isempty(data_file)
    [experimental_data, data_file] = load_saved_result_file(step_root, 'tests');
else
    experimental_data = load(data_file);
end
if use_trim_selector
    experimental_data = trim_recording_time_window(experimental_data);
end

if all(isfield(experimental_data, {'dd', 'dc', 'dm', 'fs'}))
    dd = experimental_data.dd(:);
    dc = experimental_data.dc(:);
    dm = experimental_data.dm(:);
    fs = experimental_data.fs;
else
    sig = experimental_data.logsout.FileLogSignals{1}.Values;
    signal_names = string({sig.DataInfo.Units});
    dd = sig.Data(:, strcmpi(signal_names, 'dd'));
    dc = sig.Data(:, strcmpi(signal_names, 'dc'));
    dm = sig.Data(:, strcmpi(signal_names, 'dm'));
    fs = 1 / mean(diff(sig.Time(:)));
end
dt = 1 / fs;

%% Identify Both Experimental Systems
% exp_in_sys: response from the digital-controller output to measurement.
% exp_out_sys: measured final response from desired input to measurement.
[exp_in_sys, exp_in_xfunc] = identify_experimental_system(dc, dm, fs, fit_config);
[exp_out_sys, exp_out_xfunc] = identify_experimental_system(dd, dm, fs, fit_config);

%% Apply the Actual Digital PID Form to the Experimental Inner System
% The Simulink controller is parallel, discrete-time, Forward Euler for
% both the integrator and derivative filter, with filter coefficient N.
digital_cntrlr = pid(P, I, D, 1/derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
exp_in_sys_d = c2d(exp_in_sys, dt, 'zoh');
exp_out_sys_d = c2d(exp_out_sys, dt, 'zoh');
dg_cntrlr_sys = feedback(digital_cntrlr * exp_in_sys_d, 1);

fprintf('\nDigital-controller dynamics comparison\n')
fprintf('Experimental data: %s\n', data_file)
fprintf('PID: P = %.6g, I = %.6g, D = %.6g, N = %.6g, dt = %.6g s\n', ...
    P, I, D, derivative_filter_N, dt)
fprintf('exp_in_sys: dc -> dm\n')
fprintf('exp_out_sys: dd -> dm\n')
fprintf('dg_cntrlr_sys: feedback(digital_cntrlr * exp_in_sys, 1)\n')

%% Stability Margins
exp_in_open_loop = minreal(exp_in_sys_d/(1 - exp_in_sys_d));
% The digital-controller open loop is known directly as
% exp_in_sys_d*digital_cntrlr; it does not need to be reconstructed.
digital_loop = digital_cntrlr * exp_in_sys_d;
margin_loops = {exp_in_open_loop, digital_loop};
closed_loop_systems = {exp_in_sys_d, dg_cntrlr_sys};
margin_names = {'exp_in_sys (reconstructed open loop)'; ...
    'outer loop'};
gain_margin_db = zeros(2, 1);
phase_margin_deg = zeros(2, 1);
ncf_margin = zeros(2, 1);
closed_loop_stable = false(2, 1);
for i = 1:2
    [gain_margin_db(i), phase_margin_deg(i), ncf_margin(i)] = ...
        custom_stability_margins(margin_loops{i}, fit_config.f_lim);
    closed_loop_stable(i) = isstable(closed_loop_systems{i});
end
margin_table = table(gain_margin_db, phase_margin_deg, ncf_margin, closed_loop_stable, ...
    'RowNames', margin_names, ...
    'VariableNames', {'GainMargin_dB', 'PhaseMargin_deg', 'NCFMargin', ...
        'ClosedLoopStable'});
fprintf('\nDiscrete-system stability margins\n')
disp(margin_table)

%% Pole-Zero Comparison
pole_zero_systems = {exp_in_sys_d, exp_out_sys_d, dg_cntrlr_sys};
labels = {'exp\_in\_sys: dc to dm', 'exp\_out\_sys: dd to dm', ...
    'dg\_cntrlr\_sys: PID with exp\_in\_sys'};
colors = {[0.675 0.392 0.125], [0 0.486 0.659], [0.224 0.749 0.369]};

figure('Name', 'Digital Controller Pole-Zero Comparison', 'Color', 'w')
hold on
for i = 1:numel(pole_zero_systems)
    poles = pole(pole_zero_systems{i});
    zeros_ = zero(pole_zero_systems{i});
    plot(real(poles), imag(poles), 'x', 'Color', colors{i}, ...
        'LineWidth', 1.6, 'MarkerSize', 9, 'DisplayName', [labels{i} ' poles'])
    plot(real(zeros_), imag(zeros_), 'o', 'Color', colors{i}, ...
        'LineWidth', 1.4, 'MarkerSize', 7, 'DisplayName', [labels{i} ' zeros'])
end
theta = linspace(0, 2*pi, 400);
plot(cos(theta), sin(theta), 'k:', 'HandleVisibility', 'off')
xline(0, 'k:')
yline(0, 'k:')
grid on
axis equal
xlabel('Real Axis (z)')
ylabel('Imaginary Axis (z)')
title('Discrete Pole-Zero Comparison')
legend('Location', 'best')

%% Bode Comparison
freq_hz = logspace(log10(fit_config.f_lim(1)), ...
    log10(fit_config.f_lim(2)), 800);
freq_rad = 2*pi*freq_hz;
systems = {exp_in_sys, exp_out_sys, dg_cntrlr_sys};

figure('Name', 'Digital Controller Bode Comparison', 'Color', 'w')
tiledlayout(2, 1)
ax_mag = nexttile;
hold(ax_mag, 'on')
ax_phase = nexttile;
hold(ax_phase, 'on')
for i = 1:numel(systems)
    response = squeeze(freqresp(systems{i}, freq_rad));
    semilogx(ax_mag, freq_hz, 20*log10(abs(response)), ...
        'Color', colors{i}, 'LineWidth', 1.4, 'DisplayName', labels{i})
    semilogx(ax_phase, freq_hz, unwrap(angle(response))*180/pi, ...
        'Color', colors{i}, 'LineWidth', 1.4, 'DisplayName', labels{i})
end
grid(ax_mag, 'on')
grid(ax_phase, 'on')
ylabel(ax_mag, 'Magnitude (dB)')
ylabel(ax_phase, 'Phase (deg)')
xlabel(ax_phase, 'Frequency (Hz)')
title(ax_mag, 'Experimental and Digital-Controller System Comparison')
legend(ax_mag, 'Location', 'best')

scatter(ax_mag, exp_in_xfunc.freq_hz, 20*log10(abs(exp_in_xfunc.points)), ...
    10, colors{1}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_mag, exp_out_xfunc.freq_hz, 20*log10(abs(exp_out_xfunc.points)), ...
    10, colors{2}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_phase, exp_in_xfunc.freq_hz, unwrap(angle(exp_in_xfunc.points))*180/pi, ...
    10, colors{1}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_phase, exp_out_xfunc.freq_hz, unwrap(angle(exp_out_xfunc.points))*180/pi, ...
    10, colors{2}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')

function [fitted_sys, xfunc_data] = identify_experimental_system(input_signal, output_signal, fs, config)
% Use the same xfunc and regularized rational-fit settings as sys_id.m.
    [tf_points, freq_hz, spectra] = xfunc(input_signal, output_signal, fs, ...
        config.fft_length, config.overlap);

    coherence = abs(spectra(:,3)).^2 ./ max(spectra(:,1).*spectra(:,2), eps);
    input_power_db = 10*log10(spectra(:,1) + eps);
    finite_idx = isfinite(freq_hz) & isfinite(real(tf_points)) & ...
        isfinite(imag(tf_points)) & isfinite(coherence) & isfinite(input_power_db);
    band_idx = freq_hz >= config.f_lim(1) & freq_hz <= config.f_lim(2);
    fit_idx = band_idx & finite_idx & coherence >= config.coherence_min & ...
        input_power_db >= max(input_power_db(band_idx & finite_idx)) - ...
        config.input_power_range_db;

    fit_points = tf_points(fit_idx);
    fit_freq_hz = freq_hz(fit_idx);
    fit_freq_rad = 2*pi*fit_freq_hz;
    [num, den] = regularized_rational_fit(fit_points, fit_freq_rad, ...
        config.num_order, config.den_order, config.regularization, ...
        ones(size(fit_freq_rad)), ...
        struct('max_iterations', config.iterations, 'phase_weight', 1));
    fitted_sys = tf(num, den);
    xfunc_data = struct('freq_hz', fit_freq_hz(:), 'points', fit_points(:));
end
