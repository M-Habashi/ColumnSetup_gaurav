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
    xlsxRelativePath = "downloads/" + regexprep(relativePath, ...
        '\.mat$', '.xlsx', 'ignorecase');
    xlsxPath = fullfile(reportFolder, strrep(xlsxRelativePath, '/', filesep));
    entry = struct('id', id, 'name', files(k).name, ...
        'path', char(relativePath), 'data', char("data/tests/" + outputName), ...
        'available', false, 'error', '', ...
        'xlsx', char(xlsxRelativePath), ...
        'xlsx_available', isfile(xlsxPath), 'xlsx_error', '');

    try
        loaded = load(filePath, 'result');
        result = loaded.result;
        if isfield(result, 'result') && isstruct(result.result)
            result = result.result;
        end

        dm = result.dm(:);
        fm = result.fm(:);
        fs = double(result.fs);
        assert(isfield(result, 'hs') && isfield(result.hs, 'time') && ...
            isfield(result.hs, 'time_scale_factor'), ...
            'No earthquake-time metadata is stored in this result.')
        timeScaleFactor = double(result.hs.time_scale_factor);
        intensityFactor = NaN;
        if isfield(result.hs, 'intensity_factor')
            intensityFactor = double(result.hs.intensity_factor);
        end
        testDate = getTestDate(result, files(k).name);
        earthquakeDuration = double(result.hs.time(end));
        dmFiltered = filtfiltDm(dm, fs, 30, 4);
        pauseEnable = getPauseEnable(result);
        sampleCount = min([numel(dmFiltered), numel(fm), ...
            numel(pauseEnable)]);
        pauseEnable = pauseEnable(1:sampleCount);
        effectiveTime = zeros(sampleCount, 1);
        effectiveTime(2:end) = cumsum(pauseEnable(2:end) == 0) / fs;
        earthquakeTime = effectiveTime / timeScaleFactor;
        earthquakeIndex = find(pauseEnable == 0 & ...
            earthquakeTime <= earthquakeDuration);
        assert(~isempty(earthquakeIndex), ...
            'No active earthquake samples are stored in this result.')
        plotStep = ceil(numel(earthquakeIndex) / 20000);
        plotIndex = unique([1:plotStep:numel(earthquakeIndex), ...
            numel(earthquakeIndex)]);
        plotIndex = earthquakeIndex(plotIndex);
        plotData = struct('id', id, 'name', files(k).name, ...
            'path', char(relativePath), 'x', dmFiltered(plotIndex).', ...
            'y', fm(plotIndex).', 't', earthquakeTime(plotIndex).', ...
            'sample_count', sampleCount, 'fs', fs, ...
            'intensity_factor', intensityFactor, ...
            'time_scale_factor', timeScaleFactor, ...
            'test_date', testDate, ...
            'earthquake_duration', earthquakeDuration, ...
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

function testDate = getTestDate(result, fileName)
testDate = '';
if isfield(result, 'runStartTime') && isdatetime(result.runStartTime) && ...
        ~isempty(result.runStartTime)
    runDate = result.runStartTime(1);
    runDate.Format = 'yyyy-MM-dd';
    testDate = char(runDate);
    return
end

dateToken = regexp(fileName, '^(\d{4})(\d{2})(\d{2})', ...
    'tokens', 'once');
if ~isempty(dateToken)
    testDate = strjoin(dateToken, '-');
end
end

function pauseEnable = getPauseEnable(result)
    if isfield(result, 'dd_pause_enable_log') && ...
            ~isempty(result.dd_pause_enable_log)
        pauseEnable = result.dd_pause_enable_log(:);
    elseif isfield(result, 'dd_pause_enable') && ...
            ~isempty(result.dd_pause_enable)
        pauseEnable = result.dd_pause_enable(:);
    elseif isfield(result, 'Results') && ~isempty(result.Results) && ...
            size(result.Results{1}, 2) >= 10
        pauseEnable = result.Results{1}(:, 10);
    else
        error('No HS pause/run log is stored in this result.')
    end
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
