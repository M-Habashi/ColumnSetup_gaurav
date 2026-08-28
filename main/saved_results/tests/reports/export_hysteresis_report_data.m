function export_hysteresis_report_data
%% Export saved RTHS force-displacement loops for the HTML explorer.

reportFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(reportFolder)));
testFolder = fullfile(projectFolder, 'saved_results', 'tests');
dataFolder = fullfile(reportFolder, 'data', 'tests');
if ~isfolder(dataFolder)
    mkdir(dataFolder)
end

files = dir(fullfile(testFolder, '**', '*.mat'));
files = files(~contains(string({files.folder}), filesep + "old", ...
    'IgnoreCase', true));
[~, order] = sort(string(fullfile({files.folder}, {files.name})));
files = files(order);
manifestFiles = cell(numel(files), 1);

for k = 1:numel(files)
    filePath = fullfile(files(k).folder, files(k).name);
    relativePath = strrep(extractAfter(string(filePath), ...
        strlength(string(testFolder)) + 1), '\', '/');
    id = sprintf('test-%03d', k);
    outputName = id + ".json";
    entry = struct('id', id, 'name', files(k).name, ...
        'path', char(relativePath), 'data', char("data/tests/" + outputName), ...
        'available', false, 'error', '');

    try
        loaded = load(filePath, 'result');
        result = loaded.result;
        if isfield(result, 'result') && isstruct(result.result)
            result = result.result;
        end

        dm = result.dm(:);
        fm = result.fm(:);
        fs = double(result.fs);
        dmFiltered = filtfiltDm(dm, fs, 30, 4);
        sampleCount = min(numel(dmFiltered), numel(fm));
        plotIndex = unique([1:ceil(sampleCount / 20000):sampleCount, ...
            sampleCount]);
        plotData = struct('id', id, 'name', files(k).name, ...
            'path', char(relativePath), 'x', dmFiltered(plotIndex).', ...
            'y', fm(plotIndex).', 'sample_count', sampleCount, 'fs', fs, ...
            'filter_cutoff_hz', 30, 'filter_order', 4);
        writeJson(fullfile(dataFolder, outputName), plotData)
        entry.available = true;
        fprintf('[%d/%d] %s\n', k, numel(files), relativePath)
    catch exception
        entry.error = exception.message;
        fprintf('[%d/%d] skipped %s: %s\n', k, numel(files), ...
            relativePath, exception.message)
    end
    manifestFiles{k} = entry;
end

manifest = struct('root', 'saved_results/tests', ...
    'generated_at', char(datetime('now', 'Format', ...
    'yyyy-MM-dd''T''HH:mm:ssXXX')), 'files', {manifestFiles});
writeJson(fullfile(reportFolder, 'data', 'test-manifest.json'), manifest)
fprintf('Wrote %d test entries to the hysteresis explorer.\n', numel(files))
end

function y = filtfiltDm(dm, fs, cutoffHz, order)
% Units: dm/y [mm], fs/cutoffHz [Hz].
    [b, a] = butter(order, cutoffHz / (fs / 2), 'low');
    y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function writeJson(filePath, value)
    fileId = fopen(filePath, 'w');
    cleanup = onCleanup(@() fclose(fileId));
    fwrite(fileId, jsonencode(value), 'char');
end
