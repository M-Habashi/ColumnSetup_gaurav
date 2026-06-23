%% System Identification and Digital Controller Dynamics
% Identify H_dc_dm and H_dd_dm, save the dc -> dm parametric model, compare
% the current PID loop, and provide interactive trial PID tuning.

%% Inputs
P = 0.15;
I = 20;
D = 0.0015;
derivative_filter_N = 512;
max_freq_hz = 80;

% controller optimization inputs
gm = 16;             % Minimum gain margin in dB; use 0 for no constraint.
pm = 70;             % Minimum phase margin in degrees; use 0 for no constraint.
overshooting = 0;    % Maximum step overshoot in percent; use 0 for no constraint.
d_gain = 0.0015;          % Maximum derivative gain D; use 0 for no constraint.
if ~exist('data_file', 'var'), data_file = ''; end
if ~exist('specimen_file', 'var'), specimen_file = ''; end
if ~exist('use_trim_selector', 'var'), use_trim_selector = true; end
if ~exist('candidate_poles', 'var'), candidate_poles = [4 5 6]; end
if ~exist('candidate_zeros', 'var'), candidate_zeros = [2 3]; end

%% Setup
clear functions
clc
close all
rng(0)

script_root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(script_root));
addpath(fullfile(step_root, 'helpers', 'utils'))
addpath(fullfile(script_root, 'id_utils'))

fit_config = struct( ...
    'f_lim', [0.1, max_freq_hz], ...
    'candidate_poles', candidate_poles, ...
    'candidate_zeros', candidate_zeros, ...
    'fit_phase_score_weight', 0.02, ...
    'iterations', 1000, ...
    'coherence_min', 0.8, ...
    'input_power_range_db', 30, ...
    'fft_length', 2^15, ...
    'overlap', 2^14);

%% Select and Trim Experimental Data
if isempty(data_file)
    [experimental_data, data_file, data_name] = ...
        load_saved_result_file(step_root, 'tests');
else
    [experimental_data, data_file, data_name] = ...
        load_saved_result_file(step_root, 'tests', false, data_file);
end

if isempty(specimen_file)
    [specimen, specimen_file, specimen_name] = ...
        load_saved_result_file(step_root, 'specimens');
else
    [specimen, specimen_file, specimen_name] = ...
        load_saved_result_file(step_root, 'specimens', false, specimen_file);
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
if isfield(experimental_data, 'test_type')
    test_type = char(string(experimental_data.test_type));
elseif isfield(experimental_data, 'testname')
    test_type = char(string(experimental_data.testname));
else
    test_type = 'unknown';
end
if isfield(experimental_data, 'trim_time_window')
    analysis_time_window = experimental_data.trim_time_window;
    time_window_source = 'selected trim window';
elseif isfield(experimental_data, 't') && numel(experimental_data.t) == numel(dm)
    analysis_time_window = [experimental_data.t(1), experimental_data.t(end)];
    time_window_source = 'loaded t vector';
elseif isfield(experimental_data, 'tt') && numel(experimental_data.tt) == numel(dm)
    analysis_time_window = [experimental_data.tt(1), experimental_data.tt(end)];
    time_window_source = 'loaded tt vector';
elseif exist('sig', 'var') && numel(sig.Time) == numel(dm)
    analysis_time_window = [sig.Time(1), sig.Time(end)];
    time_window_source = 'logsout time vector';
else
    analysis_time_window = [0, (numel(dm) - 1)/fs];
    time_window_source = 'sample count and fs';
end

fprintf('\nDigital-controller dynamics selections\n')
fprintf('Experimental data: %s\n', data_file)
fprintf('Specimen parameters: %s\n', specimen_file)
fprintf('Test type: %s\n', test_type)
fprintf('Analysis time window: [%.6g, %.6g] s (%s)\n', ...
    analysis_time_window(1), analysis_time_window(2), time_window_source)

%% Identify Both Experimental Systems
% H_dc_dm: response from the digital-controller output to measurement.
% H_dd_dm: measured final response from desired input to measurement.
[H_dc_dm, H_dc_dm_xfunc, H_dc_dm_fit_info] = ...
    identify_experimental_system(dc, dm, fs, fit_config);
[H_dd_dm, H_dd_dm_xfunc, H_dd_dm_fit_info] = ...
    identify_experimental_system(dd, dm, fs, fit_config);

fit_name = {'H_dc_dm'; 'H_dd_dm'};
fit_method = [H_dc_dm_fit_info.selected_method; H_dd_dm_fit_info.selected_method];
fit_stable = [H_dc_dm_fit_info.is_stable; H_dd_dm_fit_info.is_stable];
fit_max_real_pole = [H_dc_dm_fit_info.max_real_pole; H_dd_dm_fit_info.max_real_pole];
fit_rms_mag_db = [H_dc_dm_fit_info.rms_mag_db; H_dd_dm_fit_info.rms_mag_db];
fit_rms_phase_deg = [H_dc_dm_fit_info.rms_phase_deg; H_dd_dm_fit_info.rms_phase_deg];
fit_table = table(fit_method, fit_stable, fit_max_real_pole, ...
    fit_rms_mag_db, fit_rms_phase_deg, ...
    'RowNames', fit_name, ...
    'VariableNames', {'Method', 'Stable', 'MaxRealPole', ...
        'RMSMagDb', 'RMSPhaseDeg'});
fprintf('\nSelected experimental transfer-function fits\n')
disp(fit_table)

%% Parametric Physical Model Identification for dc -> dm
[H_dc_dm_param, ~, ~] = ...
    identify_and_save_dc_dm_parametric_model(dc, dm, fs, step_root, ...
        data_file, data_name, specimen, specimen_file, specimen_name, ...
        test_type, fit_config);

%% Apply the Actual Digital PID Form to the Experimental Inner System
% The Simulink controller is parallel, discrete-time, Forward Euler for
% both the integrator and derivative filter, with filter coefficient N.
digital_cntrlr = pid(P, I, D, 1/derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H_dc_dm_d = c2d(H_dc_dm, dt, 'zoh');
H_dd_dm_d = c2d(H_dd_dm, dt, 'zoh');
PID_H_dc_dm = feedback(digital_cntrlr * H_dc_dm_d, 1);

fprintf('\nDigital-controller dynamics comparison\n')
fprintf('Experimental data: %s\n', data_file)
fprintf('PID: P = %.6g, I = %.6g, D = %.6g, N = %.6g, dt = %.6g s\n', ...
    P, I, D, derivative_filter_N, dt)
fprintf('H_dc_dm: dc -> dm\n')
fprintf('H_dd_dm: dd -> dm\n')
fprintf('PID_H_dc_dm: feedback(digital_cntrlr * H_dc_dm_d, 1)\n')

%% Stability Margins
H_dc_dm_reconstructed_loop = minreal(H_dc_dm_d/(1 - H_dc_dm_d));
% The digital-controller open loop is known directly as
% digital_cntrlr*H_dc_dm_d; it does not need to be reconstructed.
PID_H_dc_dm_loop = digital_cntrlr * H_dc_dm_d;
margin_loops = {H_dc_dm_reconstructed_loop, PID_H_dc_dm_loop};
closed_loop_systems = {H_dc_dm_d, PID_H_dc_dm};
margin_names = {'H_dc_dm (reconstructed open loop)'; ...
    'PID_H_dc_dm'};
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
pole_zero_systems = {H_dc_dm_d, H_dd_dm_d, PID_H_dc_dm};
labels = {'H_{dc to dm}', 'H_{dd to dm}', 'PID + H_{dc to dm}'};
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
systems = {H_dc_dm, H_dd_dm, PID_H_dc_dm, H_dc_dm_param};
bode_labels = [labels, {'H\_dc\_dm\_param'}];
bode_colors = [colors, {[0.565 0.082 0]}];

figure('Name', 'Digital Controller Bode Comparison', 'Color', 'w')
tiledlayout(2, 1)
ax_mag = nexttile;
hold(ax_mag, 'on')
ax_phase = nexttile;
hold(ax_phase, 'on')
for i = 1:numel(systems)
    response = squeeze(freqresp(systems{i}, freq_rad));
    semilogx(ax_mag, freq_hz, 20*log10(abs(response)), ...
        'Color', bode_colors{i}, 'LineWidth', 1.4, ...
        'DisplayName', bode_labels{i})
    semilogx(ax_phase, freq_hz, unwrap(angle(response))*180/pi, ...
        'Color', bode_colors{i}, 'LineWidth', 1.4, ...
        'DisplayName', bode_labels{i})
end
grid(ax_mag, 'on')
grid(ax_phase, 'on')
ylabel(ax_mag, 'Magnitude (dB)')
ylabel(ax_phase, 'Phase (deg)')
xlabel(ax_phase, 'Frequency (Hz)')
title(ax_mag, 'Experimental and Digital-Controller System Comparison')
legend(ax_mag, 'Location', 'best')

scatter(ax_mag, H_dc_dm_xfunc.freq_hz, 20*log10(abs(H_dc_dm_xfunc.points)), ...
    10, colors{1}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_mag, H_dd_dm_xfunc.freq_hz, 20*log10(abs(H_dd_dm_xfunc.points)), ...
    10, colors{2}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_phase, H_dc_dm_xfunc.freq_hz, unwrap(angle(H_dc_dm_xfunc.points))*180/pi, ...
    10, colors{1}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')
scatter(ax_phase, H_dd_dm_xfunc.freq_hz, unwrap(angle(H_dd_dm_xfunc.points))*180/pi, ...
    10, colors{2}, 'filled', 'MarkerFaceAlpha', 0.2, ...
    'HandleVisibility', 'off')

%% Design a New Digital PID Controller
pid_constraints = struct('gm_db', gm, 'pm_deg', pm, ...
    'overshoot_percent', overshooting, 'max_d_gain', d_gain);
initial_pid_gains = [P, I, D];
[optimized_digital_cntrlr, optimized_PID_H_dc_dm_loop, ...
        optimized_PID_H_dc_dm, new_pid_results] = ...
    optimize_digital_pid(H_dc_dm_d, dt, derivative_filter_N, ...
        fit_config.f_lim, initial_pid_gains, pid_constraints);

old_step_info = stepinfo(PID_H_dc_dm);
new_step_info = stepinfo(optimized_PID_H_dc_dm);
pid_name = {'PID_H_dc_dm'; 'optimized_PID_H_dc_dm'};
pid_P = [P; new_pid_results.gains(1)];
pid_I = [I; new_pid_results.gains(2)];
pid_D = [D; new_pid_results.gains(3)];
pid_gm_db = [gain_margin_db(2); new_pid_results.gm_db];
pid_pm_deg = [phase_margin_deg(2); new_pid_results.pm_deg];
pid_ncf_margin = [ncf_margin(2); new_pid_results.ncf_margin];
pid_settling_time = [old_step_info.SettlingTime; new_step_info.SettlingTime];
pid_overshoot = [old_step_info.Overshoot; new_step_info.Overshoot];
pid_table = table(pid_P, pid_I, pid_D, pid_gm_db, pid_pm_deg, ...
    pid_ncf_margin, pid_settling_time, pid_overshoot, ...
    'RowNames', pid_name, ...
    'VariableNames', {'P', 'I', 'D', 'GainMargin_dB', 'PhaseMargin_deg', ...
        'NCFMargin', 'SettlingTime_s', 'Overshoot_percent'});
fprintf('\nPID_H_dc_dm and optimized_PID_H_dc_dm\n')
disp(pid_table)

create_interactive_pid_step_figure(H_dd_dm, optimized_PID_H_dc_dm, ...
    H_dc_dm_d, dt, derivative_filter_N, fit_config.f_lim, ...
    [P I D], new_pid_results.gains)

function [fitted_sys, xfunc_data, fit_info] = identify_experimental_system(input_signal, output_signal, fs, config)
% Fit the measured FRF, preferring accurate models with safely stable poles.
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
    [fitted_sys, fit_info] = select_stable_transfer_fit( ...
        fit_points, fit_freq_rad, config);
    xfunc_data = struct('freq_hz', fit_freq_hz(:), 'points', fit_points(:), ...
        'fit_info', fit_info);
end

function [selected_sys, fit_info] = select_stable_transfer_fit(h, w, config)
    candidates = struct('method', {}, 'system', {}, 'score', {}, ...
        'is_stable', {}, 'max_real_pole', {}, 'rms_mag_db', {}, ...
        'rms_phase_deg', {});

    fit_data = idfrd(reshape(h(:), [1 1 numel(h)]), w(:), 0, ...
        'FrequencyUnit', 'rad/s');
    candidate_orders = build_candidate_orders( ...
        config.candidate_poles, config.candidate_zeros);
    for i = 1:size(candidate_orders, 1)
        pole_count = candidate_orders(i, 1);
        zero_count = candidate_orders(i, 2);
        options = tfestOptions('Display', 'off', 'EnforceStability', true);
        options.SearchOptions.MaxIterations = config.iterations;
        identified_sys = tf(tfest(fit_data, pole_count, zero_count, options));
        candidates(end+1) = score_fit_candidate( ...
            sprintf('tfest stable %dp/%dz', pole_count, zero_count), ...
            identified_sys, h, w, config);
    end

    [~, selected_idx] = min([candidates.score]);
    selected = candidates(selected_idx);
    selected_sys = selected.system;
    fit_info = rmfield(selected, 'system');
    fit_info.selected_method = string(selected.method);
end

function candidate = score_fit_candidate(method, sys, h, w, config)
    response = squeeze(freqresp(sys, w(:)));
    rms_mag_db = rms(20*log10(abs(response) + eps) - ...
        20*log10(abs(h(:)) + eps));
    rms_phase_deg = rms(unwrap(angle(response))*180/pi - ...
        unwrap(angle(h(:)))*180/pi);
    poles = pole(sys);
    max_real_pole = max(real(poles));
    is_stable_sys = isstable(sys);

    score = rms_mag_db + config.fit_phase_score_weight*rms_phase_deg;
    candidate = struct('method', method, 'system', sys, 'score', score, ...
        'is_stable', is_stable_sys, 'max_real_pole', max_real_pole, ...
        'rms_mag_db', rms_mag_db, 'rms_phase_deg', rms_phase_deg);
end

function candidate_orders = build_candidate_orders(candidate_poles, candidate_zeros)
    candidate_orders = [];
    for pole_count = candidate_poles(:).'
        for zero_count = candidate_zeros(:).'
            if zero_count < pole_count
                candidate_orders(end+1, :) = [pole_count zero_count];
            end
        end
    end
    candidate_orders = unique(candidate_orders, 'rows', 'stable');
end

function create_interactive_pid_step_figure(H_dd_dm, optimized_PID_H_dc_dm, plant, ...
    dt, derivative_filter_N, freq_range_hz, old_gains, optimized_gains)
    trial_gains = old_gains;
    trial_PID_H_dc_dm = build_discrete_pid_closed_loop( ...
        plant, dt, derivative_filter_N, trial_gains);
    [H_dd_dm_response, H_dd_dm_time] = step(H_dd_dm);
    [optimized_response, optimized_time] = step(optimized_PID_H_dc_dm);
    [trial_response, trial_time] = step(trial_PID_H_dc_dm);

    fig = figure('Name', 'Interactive Outer-Loop Step Responses', ...
        'Color', 'w');
    ax = axes(fig, 'Position', [0.08 0.18 0.66 0.74]);
    plot(ax, H_dd_dm_time, squeeze(H_dd_dm_response), '-', ...
        'Color', [0 0.486 0.659], 'LineWidth', 1.4, ...
        'DisplayName', 'H_{dd to dm}')
    hold(ax, 'on')
    plot(ax, optimized_time, squeeze(optimized_response), '-', ...
        'Color', [0.675 0.392 0.125], 'LineWidth', 1.4, ...
        'DisplayName', 'Optimized PID + H_{dc to dm}')
    trial_line = plot(ax, trial_time, squeeze(trial_response), '--', ...
        'Color', [0.224 0.749 0.369], 'LineWidth', 1.6, ...
        'DisplayName', 'Trial PID + H_{dc to dm}');
    yline(ax, 1, 'k:', 'HandleVisibility', 'off')
    grid(ax, 'on')
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'Response')
    title(ax, 'Interactive Outer-Loop Step Responses')
    legend(ax, 'Location', 'best')

    uicontrol(fig, 'Style', 'text', 'String', 'Trial PID', ...
        'Units', 'normalized', 'Position', [0.78 0.82 0.16 0.04], ...
        'BackgroundColor', 'w', 'FontWeight', 'bold');
    p_edit = add_gain_control(fig, 'P', old_gains(1), 0.76);
    i_edit = add_gain_control(fig, 'I', old_gains(2), 0.68);
    d_edit = add_gain_control(fig, 'D', old_gains(3), 0.60);
    status_text = uicontrol(fig, 'Style', 'text', 'String', '', ...
        'Units', 'normalized', 'Position', [0.76 0.24 0.20 0.26], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Update', ...
        'Units', 'normalized', 'Position', [0.76 0.52 0.09 0.045], ...
        'Callback', @update_trial_response);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset Old', ...
        'Units', 'normalized', 'Position', [0.87 0.52 0.09 0.045], ...
        'Callback', @reset_to_old);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Use Optimized', ...
        'Units', 'normalized', 'Position', [0.76 0.46 0.20 0.045], ...
        'Callback', @use_optimized);

    update_status(trial_PID_H_dc_dm, trial_gains)

    function edit_box = add_gain_control(parent, label, value, y_position)
        uicontrol(parent, 'Style', 'text', 'String', label, ...
            'Units', 'normalized', 'Position', [0.76 y_position 0.03 0.035], ...
            'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
        edit_box = uicontrol(parent, 'Style', 'edit', ...
            'String', sprintf('%.6g', value), ...
            'Units', 'normalized', 'Position', [0.80 y_position 0.16 0.04], ...
            'Callback', @update_trial_response);
    end

    function update_trial_response(varargin)
        trial_gains = [str2double(get(p_edit, 'String')), ...
            str2double(get(i_edit, 'String')), ...
            str2double(get(d_edit, 'String'))];
        trial_PID_H_dc_dm = build_discrete_pid_closed_loop( ...
            plant, dt, derivative_filter_N, trial_gains);
        [trial_response, trial_time] = step(trial_PID_H_dc_dm);
        set(trial_line, 'XData', trial_time, 'YData', squeeze(trial_response))
        update_status(trial_PID_H_dc_dm, trial_gains)
    end

    function reset_to_old(varargin)
        set_gain_edits(old_gains)
        update_trial_response()
    end

    function use_optimized(varargin)
        set_gain_edits(optimized_gains)
        update_trial_response()
    end

    function set_gain_edits(gains)
        set(p_edit, 'String', sprintf('%.6g', gains(1)))
        set(i_edit, 'String', sprintf('%.6g', gains(2)))
        set(d_edit, 'String', sprintf('%.6g', gains(3)))
    end

    function update_status(system_current, gains)
        info = stepinfo(system_current);
        loop_current = build_discrete_pid_open_loop( ...
            plant, dt, derivative_filter_N, gains);
        [gm_current, pm_current, ncf_current] = ...
            custom_stability_margins(loop_current, freq_range_hz);
        set(status_text, 'String', sprintf(['P = %.6g\nI = %.6g\nD = %.6g\n' ...
            'Stable = %d\nSettling = %.4g s\nOvershoot = %.4g %%\n' ...
            'GM = %.4g dB\nPM = %.4g deg\nNCF = %.4g'], ...
            gains(1), gains(2), gains(3), isstable(system_current), ...
            info.SettlingTime, info.Overshoot, gm_current, pm_current, ...
            ncf_current))
    end
end

function closed_loop = build_discrete_pid_closed_loop(plant, dt, ...
    derivative_filter_N, gains)
    open_loop = build_discrete_pid_open_loop( ...
        plant, dt, derivative_filter_N, gains);
    closed_loop = feedback(open_loop, 1);
end

function open_loop = build_discrete_pid_open_loop(plant, dt, ...
    derivative_filter_N, gains)
    controller = pid(gains(1), gains(2), gains(3), ...
        1/derivative_filter_N, dt, 'IFormula', 'ForwardEuler', ...
        'DFormula', 'ForwardEuler');
    open_loop = controller*plant;
end
