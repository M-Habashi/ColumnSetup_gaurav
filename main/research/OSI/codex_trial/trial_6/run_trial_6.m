%% Trial 6: Coherence-Adaptive Complex FRF State Filter
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
trackedFreqHz = (4:4:80).';
spectralAlpha = 0.12;
initialRelSigma = 0.04;
processRelSigma = 0.01;
measurementRelFloor = 0.06;
coherenceNoiseScale = 0.32;
powerNoiseScale = 0.04;
inputPowerFloor = 0.03;

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
fftFreqHz = (0:floor(nfft/2))' * fs / nfft;
[trackedFreqHz, fftIdx] = intersect_fft_grid(trackedFreqHz, fftFreqHz);
nFreq = numel(trackedFreqHz);
nWindows = numel(windowTime);

nominalFrf = squeeze(freqresp(nominalPlant, 2*pi*trackedFreqHz));
controllerFrf = squeeze(freqresp(controller, 2*pi*trackedFreqHz));
stateFrf = nominalFrf(:);
stateVariance = (initialRelSigma*max(abs(stateFrf), eps)).^2;
processVariance = (processRelSigma*max(abs(nominalFrf(:)), eps)).^2;
suu = zeros(nFreq, 1);
syy = zeros(nFreq, 1);
syu = zeros(nFreq, 1);

ncfMargin = nan(nWindows, 1);
pointCount = zeros(nWindows, 1);
meanCoherence = nan(nWindows, 1);
meanKalmanGain = nan(nWindows, 1);
meanRelUncertainty = nan(nWindows, 1);
minFreqHz = nan(nWindows, 1);

for k = 1:nWindows
    idx = windowStart(k):windowEnd(k);
    input = detrend(data.dc(idx));
    output = detrend(data.dm(idx));
    inputFft = fft(fftWindow.*input, nfft);
    outputFft = fft(fftWindow.*output, nfft);
    u = inputFft(fftIdx);
    y = outputFft(fftIdx);
    currentSuu = abs(u).^2;
    currentSyy = abs(y).^2;
    currentSyu = y.*conj(u);

    if k == 1
        suu = currentSuu;
        syy = currentSyy;
        syu = currentSyu;
    else
        suu = (1 - spectralAlpha)*suu + spectralAlpha*currentSuu;
        syy = (1 - spectralAlpha)*syy + spectralAlpha*currentSyy;
        syu = (1 - spectralAlpha)*syu + spectralAlpha*currentSyu;
    end

    coherence = abs(syu).^2./max(suu.*syy, eps);
    coherence = min(max(real(coherence), 0), 1);
    powerRatio = currentSuu./max(currentSuu);
    measurement = y./u;
    valid = abs(u) > eps & isfinite(real(measurement)) & ...
        isfinite(imag(measurement));

    predictedVariance = stateVariance + processVariance;
    scale = max(abs(stateFrf), abs(nominalFrf(:))).^2 + eps;
    relativeVariance = measurementRelFloor^2 + ...
        coherenceNoiseScale^2*(1 - coherence)./(coherence + 0.02) + ...
        powerNoiseScale^2./max(powerRatio, inputPowerFloor);
    measurementVariance = scale.*relativeVariance;
    gain = predictedVariance./(predictedVariance + measurementVariance);
    gain(~valid) = 0;

    stateFrf = stateFrf + gain.*(measurement - stateFrf);
    stateVariance = (1 - gain).*predictedVariance;

    loopFrf = controllerFrf(:).*stateFrf;
    distance = abs(1 + loopFrf)./sqrt(2*(1 + abs(loopFrf).^2));
    [ncfMargin(k), minIdx] = min(distance);
    minFreqHz(k) = trackedFreqHz(minIdx);
    pointCount(k) = nnz(valid);
    meanCoherence(k) = mean(coherence(valid), 'omitnan');
    meanKalmanGain(k) = mean(gain(valid), 'omitnan');
    meanRelUncertainty(k) = mean(sqrt(stateVariance(valid))./ ...
        max(abs(stateFrf(valid)), eps), 'omitnan');
end

rawNcfMargin = ncfMargin;
[ncfMargin, smoothGain] = confidence_smooth_margin( ...
    rawNcfMargin, meanCoherence, pointCount, baselineNcf);

results = table(windowTime, ncfMargin, rawNcfMargin, smoothGain, ...
    pointCount, meanCoherence, ...
    meanKalmanGain, meanRelUncertainty, minFreqHz, ...
    repmat(baselineNcf, nWindows, 1), ...
    'VariableNames', {'Time_s', 'NCFMargin', 'RawNCFMargin', ...
    'SmoothGain', 'PointCount', ...
    'MeanCoherence', 'MeanKalmanGain', 'MeanRelUncertainty', ...
    'MinFreq_Hz', 'BaselineNCF'});

save(fullfile(trialDir, 'trial_6_results.mat'), 'results', ...
    'baselineNcf', 'timeRange', 'windowSeconds', 'freqRangeHz', ...
    'trackedFreqHz', 'spectralAlpha', 'initialRelSigma', ...
    'processRelSigma', 'measurementRelFloor', ...
    'coherenceNoiseScale', 'powerNoiseScale', 'inputPowerFloor', ...
    'rawNcfMargin', 'smoothGain')
writetable(results, fullfile(trialDir, 'trial_6_results.csv'))
plot_margin(trialDir, results, baselineNcf, ...
    'Trial 6: coherence-adaptive FRF state filter')

fprintf('Trial 6 saved %d window estimates to %s\n', height(results), ...
    fullfile(trialDir, 'trial_6_results.csv'))

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

function [freqHz, fftIdx] = intersect_fft_grid(requestedFreqHz, fftFreqHz)
freqHz = zeros(size(requestedFreqHz));
fftIdx = zeros(size(requestedFreqHz));
for i = 1:numel(requestedFreqHz)
    [~, fftIdx(i)] = min(abs(fftFreqHz - requestedFreqHz(i)));
    freqHz(i) = fftFreqHz(fftIdx(i));
end
[freqHz, uniqueIdx] = unique(freqHz, 'stable');
fftIdx = fftIdx(uniqueIdx);
end

function [smoothMargin, smoothGain] = confidence_smooth_margin( ...
    rawMargin, meanCoherence, pointCount, initialMargin)
smoothMargin = nan(size(rawMargin));
smoothGain = nan(size(rawMargin));
state = initialMargin;
baseGain = 0.08;
for k = 1:numel(rawMargin)
    if ~isfinite(rawMargin(k))
        smoothMargin(k) = state;
        smoothGain(k) = 0;
        continue
    end
    confidence = min(1, max(0.05, meanCoherence(k))) * ...
        min(1, pointCount(k)/20);
    gain = baseGain*confidence;
    state = state + gain*(rawMargin(k) - state);
    smoothMargin(k) = state;
    smoothGain(k) = gain;
end
end

function plot_margin(trialDir, results, baselineNcf, plotTitle)
fig = figure('Visible', 'off', 'Color', 'w');
plot(results.Time_s, results.RawNCFMargin, '-', 'LineWidth', 0.7, ...
    'Color', [0.72 0.78 0.82])
hold on
plot(results.Time_s, results.NCFMargin, '-', 'LineWidth', 1.6, ...
    'Color', [0 0.486 0.659])
hold on
yline(baselineNcf, 'k--', 'LineWidth', 1.2)
grid on
xlabel('Time (s)')
ylabel('Estimated NCF margin')
title(plotTitle)
legend({'Raw state estimate', 'Smoothed indicator', ...
    'Nominal baseline'}, 'Location', 'best')
exportgraphics(fig, fullfile(trialDir, 'trial_6_margin.png'), ...
    'Resolution', 180)
close(fig)
end
