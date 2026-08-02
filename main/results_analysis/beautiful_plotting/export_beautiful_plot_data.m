function export_beautiful_plot_data
%% Export the beautiful.mat signals used by the HTML interactive plot.

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(scriptFolder));
filePath = fullfile(projectFolder, 'saved_results', 'tests', ...
    'successful nonLin tests', 'beautiful.mat');

data = load(filePath, 'result');
result = data.result;
if isfield(result, 'result') && isstruct(result.result)
    result = result.result;
end

t = result.t(:);
dm = result.dm(:);
fm = result.fm(:);
fs = result.fs;
dm_filt_filt = filtfiltDm(dm, fs, 30, 4);

n = min([numel(t), numel(dm_filt_filt), numel(fm)]);
t = t(1:n);
dm_filt_filt = dm_filt_filt(1:n);
fm = fm(1:n);

maxPlotPoints = 50000;
plotIndex = unique([1:ceil(n/maxPlotPoints):n, n]);
plotData = struct( ...
    'time', t(plotIndex), ...
    'dm', dm(plotIndex), ...
    'dm_filt_filt', dm_filt_filt(plotIndex), ...
    'fm', fm(plotIndex), ...
    'source', 'beautiful.mat', ...
    'sample_count', n, ...
    'fs', fs, ...
    'filter_cutoff_hz', 30, ...
    'filter_order', 4);

jsonText = jsonencode(plotData);
outputFile = fullfile(scriptFolder, 'beautiful_plot_data.js');
fileId = fopen(outputFile, 'w');
fwrite(fileId, ['window.beautifulPlotData = ' jsonText ';'], 'char');
fclose(fileId);
fprintf('Wrote %d plotted samples to %s\n', numel(plotData.time), outputFile)
end

function y = filtfiltDm(dm, fs, cutoffHz, order)
% Units: dm/y [mm], fs/cutoffHz [Hz].
    [b, a] = butter(order, cutoffHz/(fs/2), 'low');
    y = filtfilt(b, a, dm - dm(1)) + dm(1);
end
