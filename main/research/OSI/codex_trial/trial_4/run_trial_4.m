%% Trial 4: Per-Window Stable Parametric TF Fit
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
poleCount = 2;
zeroCount = 1;

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
fitRmsMagDb = nan(nWindows, 1);
fitRmsPhaseDeg = nan(nWindows, 1);
maxRealPole = nan(nWindows, 1);
fitStable = false(nWindows, 1);
fitStatus = strings(nWindows, 1);

segmentSamples = round(segmentSeconds*fs);
nfft = 2^nextpow2(segmentSamples);
welchWindow = hann(segmentSamples, 'periodic');
overlap = floor(segmentSamples/2);
fitOptions = tfestOptions('Display', 'off', 'EnforceStability', true);
fitOptions.SearchOptions.MaxIterations = 25;

for k = 1:nWindows
    idx = windowStart(k):windowEnd(k);
    input = detrend(data.dc(idx));
    output = detrend(data.dm(idx));
    [H, freqHz, valid] = window_h1_frf(input, output, fs, welchWindow, ...
        overlap, nfft, freqRangeHz, coherenceMin, inputPowerRangeDb);
    pointCount(k) = nnz(valid);

    if pointCount(k) < 8
        fitStatus(k) = "not enough valid FRF points";
        continue
    end

    try
        fitData = idfrd(reshape(H(valid), [1 1 pointCount(k)]), ...
            2*pi*freqHz(valid), 0, 'FrequencyUnit', 'rad/s');
        fitSys = tf(tfest(fitData, poleCount, zeroCount, fitOptions));
        fitStable(k) = isstable(fitSys);
        maxRealPole(k) = max(real(pole(fitSys)));
        response = squeeze(freqresp(fitSys, 2*pi*freqHz(valid)));
        fitRmsMagDb(k) = rms(20*log10(abs(response) + eps) - ...
            20*log10(abs(H(valid)) + eps));
        fitRmsPhaseDeg(k) = rms(unwrap(angle(response))*180/pi - ...
            unwrap(angle(H(valid)))*180/pi);

        fitPlant = discretize_plant(fitSys, dt);
        [~, ~, ncfMargin(k)] = custom_stability_margins( ...
            controller*fitPlant, freqRangeHz);
        fitStatus(k) = "ok";
    catch ME
        fitStatus(k) = string(ME.message);
    end
end

results = table(windowTime, ncfMargin, pointCount, fitStable, ...
    maxRealPole, fitRmsMagDb, fitRmsPhaseDeg, fitStatus, ...
    repmat(baselineNcf, nWindows, 1), ...
    'VariableNames', {'Time_s', 'NCFMargin', 'PointCount', ...
    'FitStable', 'MaxRealPole', 'FitRMSMag_dB', 'FitRMSPhase_deg', ...
    'FitStatus', 'BaselineNCF'});

save(fullfile(trialDir, 'trial_4_results.mat'), 'results', ...
    'baselineNcf', 'timeRange', 'windowSeconds', 'freqRangeHz', ...
    'segmentSeconds', 'coherenceMin', 'inputPowerRangeDb', ...
    'poleCount', 'zeroCount')
writetable(results, fullfile(trialDir, 'trial_4_results.csv'))
plot_margin(trialDir, results, baselineNcf, ...
    'Trial 4: stable per-window tfest')

fprintf('Trial 4 saved %d window estimates to %s\n', height(results), ...
    fullfile(trialDir, 'trial_4_results.csv'))

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

function [H, freqHz, valid] = window_h1_frf(input, output, fs, ...
    welchWindow, overlap, nfft, freqRangeHz, coherenceMin, inputPowerRangeDb)
[Puu, freqHz] = pwelch(input, welchWindow, overlap, nfft, fs);
Puy = cpsd(input, output, welchWindow, overlap, nfft, fs);
coherence = mscohere(input, output, welchWindow, overlap, nfft, fs);
H = Puy./max(Puu, eps);
powerDb = 10*log10(Puu + eps);
band = freqHz >= freqRangeHz(1) & freqHz <= freqRangeHz(2);
valid = band & coherence >= coherenceMin & ...
    powerDb >= max(powerDb(band)) - inputPowerRangeDb & ...
    isfinite(real(H)) & isfinite(imag(H));
if nnz(valid) < 8
    valid = band & powerDb >= max(powerDb(band)) - inputPowerRangeDb & ...
        isfinite(real(H)) & isfinite(imag(H));
end
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
exportgraphics(fig, fullfile(trialDir, 'trial_4_margin.png'), ...
    'Resolution', 180)
close(fig)
end
