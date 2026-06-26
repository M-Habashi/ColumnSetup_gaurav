%% Trial 1: Raw Single-Window H1 FRF NCF Margin
clear
clc
close all

trialDir = fileparts(mfilename('fullpath'));
projectDir = fileparts(fileparts(fileparts(fileparts(trialDir))));
addpath(fullfile(projectDir, 'control_and_HS', 'b_system_id', 'id_utils'))

testFile = fullfile(projectDir, 'saved_results', 'tests', 'important', ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');
modelFile = fullfile(projectDir, 'saved_results', 'exp_tf', ...
    '20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat');

timeRange = [620 770.1];
windowSeconds = 0.5;
freqRangeHz = [0.1 80];
inputPowerRangeDb = 45;

data = load(testFile, 't', 'dt', 'fs', 'dc', 'dm');
model = load(modelFile, 'H_dc_dm', 'pid_values');
dt = data.dt;
fs = data.fs;
controller = build_pid(model.pid_values, dt);
nominalPlant = discretize_plant(model.H_dc_dm, dt);
[~, ~, baselineNcf] = custom_stability_margins( ...
    controller*nominalPlant, freqRangeHz);

[windowStart, windowEnd, windowTime] = nonoverlap_windows( ...
    data.t, timeRange, windowSeconds, fs);
windowSamples = windowEnd(1) - windowStart(1) + 1;
nfft = windowSamples;
fftWindow = hann(windowSamples, 'periodic');
freqHz = (0:floor(nfft/2))' * fs / nfft;
positiveIdx = 1:numel(freqHz);

nWindows = numel(windowTime);
ncfMargin = nan(nWindows, 1);
pointCount = zeros(nWindows, 1);
minFreqHz = nan(nWindows, 1);

for k = 1:nWindows
    idx = windowStart(k):windowEnd(k);
    input = detrend(data.dc(idx));
    output = detrend(data.dm(idx));

    U = fft(fftWindow.*input, nfft);
    Y = fft(fftWindow.*output, nfft);
    U = U(positiveIdx);
    Y = Y(positiveIdx);
    Puu = abs(U).^2;
    H = Y.*conj(U)./max(Puu, eps);

    powerDb = 10*log10(Puu + eps);
    band = freqHz >= freqRangeHz(1) & freqHz <= freqRangeHz(2);
    valid = band & isfinite(real(H)) & isfinite(imag(H)) & ...
        powerDb >= max(powerDb(band)) - inputPowerRangeDb;

    [ncfMargin(k), minFreqHz(k)] = measured_ncf_margin( ...
        controller, H(valid), freqHz(valid));
    pointCount(k) = nnz(valid);
end

results = table(windowTime, ncfMargin, pointCount, minFreqHz, ...
    repmat(baselineNcf, nWindows, 1), ...
    'VariableNames', {'Time_s', 'NCFMargin', 'PointCount', ...
    'MinFreq_Hz', 'BaselineNCF'});

save(fullfile(trialDir, 'trial_1_results.mat'), 'results', ...
    'baselineNcf', 'timeRange', 'windowSeconds', 'freqRangeHz', ...
    'inputPowerRangeDb')
writetable(results, fullfile(trialDir, 'trial_1_results.csv'))
plot_margin(trialDir, results, baselineNcf, ...
    'Trial 1: raw single-window H1 FRF')

fprintf('Trial 1 saved %d window estimates to %s\n', height(results), ...
    fullfile(trialDir, 'trial_1_results.csv'))

function controller = build_pid(pidValues, dt)
controller = pid(pidValues.P, pidValues.I, pidValues.D, ...
    1/pidValues.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
end

function plant = discretize_plant(plantIn, dt)
if get(plantIn, 'Ts') == 0
    plant = c2d(plantIn, dt, 'zoh');
else
    plant = d2d(plantIn, dt, 'zoh');
end
end

function [windowStart, windowEnd, windowTime] = nonoverlap_windows( ...
    t, timeRange, windowSeconds, fs)
first = find(t >= timeRange(1), 1, 'first');
last = find(t <= timeRange(2), 1, 'last');
windowSamples = round(windowSeconds*fs);
nWindows = floor((last - first + 1)/windowSamples);
windowStart = first + (0:nWindows - 1)'*windowSamples;
windowEnd = windowStart + windowSamples - 1;
windowTime = 0.5*(t(windowStart) + t(windowEnd));
end

function [margin, minFreqHz] = measured_ncf_margin(controller, plantFrf, freqHz)
if isempty(freqHz)
    margin = NaN;
    minFreqHz = NaN;
    return
end
controllerFrf = squeeze(freqresp(controller, 2*pi*freqHz));
loopFrf = controllerFrf(:).*plantFrf(:);
distance = abs(1 + loopFrf)./sqrt(2*(1 + abs(loopFrf).^2));
[margin, idx] = min(distance);
minFreqHz = freqHz(idx);
end

function plot_margin(trialDir, results, baselineNcf, plotTitle)
fig = figure('Visible', 'off', 'Color', 'w');
plot(results.Time_s, results.NCFMargin, '-o', 'LineWidth', 1.4, ...
    'Color', [0 0.486 0.659], 'MarkerFaceColor', [0 0.486 0.659])
hold on
yline(baselineNcf, 'k--', 'LineWidth', 1.2)
grid on
xlabel('Time (s)')
ylabel('Estimated NCF margin')
title(plotTitle)
legend({'Window estimate', 'Nominal baseline'}, 'Location', 'best')
exportgraphics(fig, fullfile(trialDir, 'trial_1_margin.png'), ...
    'Resolution', 180)
close(fig)
end
