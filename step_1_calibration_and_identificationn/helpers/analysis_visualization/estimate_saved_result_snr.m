%% Estimate Saved Result Signal-to-Noise Ratio
% Lists saved result MAT files, prompts for one file, and estimates SNR for
% measured displacement, force, and acceleration channels.

clc

noiseWindowSeconds = 0.05;

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fullfile(scriptFolder, '..', '..');
addpath(fullfile(projectFolder, 'helpers', 'utils'))

[data, filePath, selectedFileName] = load_saved_result_file(projectFolder);
channels = {'dm', 'fm', 'am'};

fs = data.fs;
noiseWindowSamples = max(3, round(noiseWindowSeconds*fs));
if mod(noiseWindowSamples, 2) == 0
    noiseWindowSamples = noiseWindowSamples + 1;
end

snrDb = zeros(numel(channels), 1);
signalRms = zeros(numel(channels), 1);
noiseRms = zeros(numel(channels), 1);

for k = 1:numel(channels)
    x = data.(channels{k})(:);
    signalEstimate = smoothdata(x, 'movmedian', noiseWindowSamples, 'omitnan');
    noiseEstimate = x - signalEstimate;

    signalRms(k) = sqrt(mean(signalEstimate.^2, 'omitnan'));
    noiseRms(k) = sqrt(mean(noiseEstimate.^2, 'omitnan'));
    snrDb(k) = 20*log10(signalRms(k)/noiseRms(k));
end

results = table(channels(:), signalRms, noiseRms, snrDb, ...
    'VariableNames', {'Channel', 'Signal_RMS', 'Noise_RMS', 'SNR_dB'});

fprintf('\n===============================================================\n');
fprintf('                  Saved Result SNR Estimate\n');
fprintf('===============================================================\n');
fprintf('File name:             %s\n', selectedFileName);
fprintf('Full path:             %s\n', filePath);
fprintf('fs:                    %.6g Hz\n', fs);
fprintf('Noise window:          %.6g s (%d samples)\n', noiseWindowSeconds, noiseWindowSamples);
fprintf('Recommended SNR:       > 20 dB usable, > 40 dB good\n');
fprintf('===============================================================\n\n');
disp(results)
