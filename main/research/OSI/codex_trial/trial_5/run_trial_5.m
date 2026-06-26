%% Trial 5: Nominal-Model-Corrected FRF NCF Margin
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
segmentSeconds = 0.25;
coherenceMin = 0.55;
inputPowerRangeDb = 35;

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
nWindows = numel(windowTime);
ncfMargin = nan(nWindows, 1);
pointCount = zeros(nWindows, 1);
meanCoherence = nan(nWindows, 1);
correctionMag = nan(nWindows, 1);
correctionPhaseDeg = nan(nWindows, 1);
minFreqHz = nan(nWindows, 1);
rawCorrection = ones(nWindows, 1);

segmentSamples = round(segmentSeconds*fs);
nfft = 2^nextpow2(segmentSamples);
welchWindow = hann(segmentSamples, 'periodic');
overlap = floor(segmentSamples/2);
freqGridHz = (0:(nfft/2))' * fs / nfft;
nominalPlantFrfGrid = squeeze(freqresp(nominalPlant, 2*pi*freqGridHz));
marginBand = freqGridHz >= freqRangeHz(1) & freqGridHz <= freqRangeHz(2);

for k = 1:nWindows
    idx = windowStart(k):windowEnd(k);
    input = detrend(data.dc(idx));
    output = detrend(data.dm(idx));

    [Puu, freqHz] = pwelch(input, welchWindow, overlap, nfft, fs);
    Puy = cpsd(input, output, welchWindow, overlap, nfft, fs);
    coherence = mscohere(input, output, welchWindow, overlap, nfft, fs);
    measuredPlant = Puy./max(Puu, eps);
    nominalPlantFrf = nominalPlantFrfGrid;

    powerDb = 10*log10(Puu + eps);
    band = freqHz >= freqRangeHz(1) & freqHz <= freqRangeHz(2);
    valid = band & coherence >= coherenceMin & ...
        powerDb >= max(powerDb(band)) - inputPowerRangeDb & ...
        isfinite(real(measuredPlant)) & isfinite(imag(measuredPlant)) & ...
        abs(nominalPlantFrf(:)) > eps;
    if nnz(valid) < 15
        valid = band & powerDb >= max(powerDb(band)) - inputPowerRangeDb & ...
            isfinite(real(measuredPlant)) & isfinite(imag(measuredPlant)) & ...
            abs(nominalPlantFrf(:)) > eps;
    end

    correction = 1;
    if nnz(valid) >= 5
        ratio = measuredPlant(valid)./nominalPlantFrf(valid);
        weights = coherence(valid).*Puu(valid);
        weights = weights./max(sum(weights), eps);
        logMag = log(abs(ratio) + eps);
        phase = unwrap(angle(ratio));
        correction = exp(sum(weights.*logMag) + 1i*sum(weights.*phase));
    end

    rawCorrection(k) = correction;
    pointCount(k) = nnz(valid);
    meanCoherence(k) = mean(coherence(valid), 'omitnan');
end

referenceIdx = find(isfinite(real(rawCorrection)) & ...
    isfinite(imag(rawCorrection)), 1, 'first');
referenceCorrection = rawCorrection(referenceIdx);
for k = 1:nWindows
    correction = rawCorrection(k)/referenceCorrection;
    correctedPlant = correction*nominalPlantFrfGrid(:);
    [ncfMargin(k), minFreqHz(k)] = measured_ncf_margin( ...
        controller, correctedPlant(marginBand), freqGridHz(marginBand));
    correctionMag(k) = abs(correction);
    correctionPhaseDeg(k) = angle(correction)*180/pi;
end

rawNcfMargin = ncfMargin;
[ncfMargin, smoothGain] = confidence_smooth_margin( ...
    rawNcfMargin, meanCoherence, pointCount, baselineNcf);

results = table(windowTime, ncfMargin, rawNcfMargin, smoothGain, ...
    pointCount, meanCoherence, ...
    correctionMag, correctionPhaseDeg, minFreqHz, ...
    repmat(baselineNcf, nWindows, 1), ...
    'VariableNames', {'Time_s', 'NCFMargin', 'RawNCFMargin', ...
    'SmoothGain', 'PointCount', ...
    'MeanCoherence', 'CorrectionMag', 'CorrectionPhase_deg', ...
    'MinFreq_Hz', 'BaselineNCF'});

save(fullfile(trialDir, 'trial_5_results.mat'), 'results', ...
    'baselineNcf', 'timeRange', 'windowSeconds', 'freqRangeHz', ...
    'segmentSeconds', 'coherenceMin', 'inputPowerRangeDb', ...
    'rawCorrection', 'referenceCorrection', 'rawNcfMargin', 'smoothGain')
writetable(results, fullfile(trialDir, 'trial_5_results.csv'))
plot_margin(trialDir, results, baselineNcf, ...
    'Trial 5: nominal-model-corrected FRF')

fprintf('Trial 5 saved %d window estimates to %s\n', height(results), ...
    fullfile(trialDir, 'trial_5_results.csv'))

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
legend({'Raw 0.5 s estimate', 'Smoothed indicator', ...
    'Nominal baseline'}, 'Location', 'best')
exportgraphics(fig, fullfile(trialDir, 'trial_5_margin.png'), ...
    'Resolution', 180)
close(fig)
end
