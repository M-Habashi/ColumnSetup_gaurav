function freq_num
%FREQ_NUM Estimate full-RTHS frequency response using an exact chirp run.
%   With the "scripted" folder on the MATLAB path, run this figure with:
%       freq_num
%   The plotted FRF is ground acceleration to experimental displacement.
%   It is estimated from the fixed-alpha sampled-data simulation rather
%   than from a transfer-function cascade, retaining the force delay,
%   discrete phase lead, actuator, and numerical-substructure coupling.

fs = 4096;                 % RTHS sampling frequency [Hz]
chirpAmplitude = 0.1;      % Ground-acceleration amplitude [m/s^2]
startFrequency = 0.5;      % Chirp start frequency [Hz]
endFrequency = 80;         % Chirp end frequency [Hz]
chirpDuration = 60;        % Chirp duration [s]
cyclesPerEstimate = 5;     % Local cycles used by each FRF estimate
bw_a = 70; pm_a = 70;      % Controller A: bandwidth [rad/s], PM [deg]
bw_b = 55; pm_b = 55;      % Controller B: bandwidth [rad/s], PM [deg]
bw_c = 40; pm_c = 60;      % Not used by custom C; compatibility only
[target_ncf_c, target_ncf_c_alpha] = ...
    scripted_controller_c_settings;

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);
dt = 1 / fs;
t = (0:dt:chirpDuration).';
halfTime = t(1:end-1) + dt / 2;
logFrequencyRatio = log(endFrequency / startFrequency);
phase = logarithmic_chirp_phase(t, startFrequency, chirpDuration, ...
    logFrequencyRatio);
halfPhase = logarithmic_chirp_phase(halfTime, startFrequency, ...
    chirpDuration, logFrequencyRatio);
groundInput = struct( ...
    't', t, ...
    'major', chirpAmplitude * sin(phase), ...
    'half', chirpAmplitude * sin(halfPhase));

controllerNames = {'A', 'B', 'C'};
controllerColors = {'#0a50a1', '#a9003c', '#01746F'};
responses = cell(1, numel(controllerNames));
for index = 1:numel(controllerNames)
    options = struct( ...
        'Building_c', 1, ...
        'plot_on', 'n', ...
        'modified', 1, ...
        'consider_damage', 0, ...
        'alpha_start', 1, ...
        'alpha_min', 0.5, ...
        'b_th', 0.13, ...
        'num_add', 0, ...
        'enable_indicator_plot', 0, ...
        'test_name', 'None', ...
        'fs', fs, ...
        'bw_a', bw_a, 'pm_a', pm_a, ...
        'bw_b', bw_b, 'pm_b', pm_b, ...
        'bw_c', bw_c, 'pm_c', pm_c, ...
        'target_ncf_c', target_ncf_c, ...
        'target_ncf_c_alpha', target_ncf_c_alpha, ...
        'start_c', controllerNames{index}, ...
        'switch_on', 0);
    p = scripted_build_trial(options, projectRoot, 1);
    responses{index} = scripted_engine(p, groundInput);
end

frequencyHz = logspace(log10(startFrequency * 1.25), ...
    log10(endFrequency / 1.25), 80);
frf = complex(nan(numel(frequencyHz), numel(controllerNames)));
for index = 1:numel(controllerNames)
    experimentalDisplacement = responses{index}.X_m.Data;
    frf(:, index) = estimate_chirp_frf(t, phase, experimentalDisplacement, ...
        chirpAmplitude, frequencyHz, startFrequency, chirpDuration, ...
        logFrequencyRatio, cyclesPerEstimate);
end

figure('Name', 'Exact full-RTHS frequency response', 'Color', 'w');
subplot(2, 1, 1); hold on; grid on; box on;
for index = 1:numel(controllerNames)
    semilogx(frequencyHz, 20 * log10(abs(frf(:, index))), ...
        'LineWidth', 2, 'Color', controllerColors{index});
end
ylabel('|X_e / a_g| [dB re m/(m/s^2)]');
title('Empirical full-RTHS frequency response from exact chirp simulation');
legend({'Controller A', 'Controller B', 'Controller C'}, 'Location', 'best');

subplot(2, 1, 2); hold on; grid on; box on;
for index = 1:numel(controllerNames)
    semilogx(frequencyHz, unwrap(angle(frf(:, index))) * 180 / pi, ...
        'LineWidth', 2, 'Color', controllerColors{index});
end
xlabel('Frequency [Hz]');
ylabel('Phase [deg]');
end

function phase = logarithmic_chirp_phase(time, startFrequency, duration, ...
        logFrequencyRatio)
phase = 2 * pi * startFrequency * duration / logFrequencyRatio * ...
    (exp(logFrequencyRatio * time / duration) - 1);
end

function response = estimate_chirp_frf(time, phase, output, amplitude, ...
        frequencyHz, startFrequency, duration, logFrequencyRatio, cycles)
response = complex(nan(size(frequencyHz)));
for index = 1:numel(frequencyHz)
    frequency = frequencyHz(index);
    centerTime = duration / logFrequencyRatio * ...
        log(frequency / startFrequency);
    halfWindow = cycles / (2 * frequency);
    sample = abs(time - centerTime) <= halfWindow;
    if nnz(sample) < 20 || centerTime - halfWindow < 0 || ...
            centerTime + halfWindow > duration
        continue
    end
    regression = [sin(phase(sample)), cos(phase(sample)), ...
        ones(nnz(sample), 1)];
    coefficients = regression \ output(sample);
    response(index) = (coefficients(1) + 1i * coefficients(2)) / amplitude;
end
end
