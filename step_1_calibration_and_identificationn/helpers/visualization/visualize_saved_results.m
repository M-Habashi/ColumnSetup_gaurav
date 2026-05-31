%% Visualize Saved Column Setup Results
% Lists saved result MAT files, prompts for one file, prints a compact
% report, and plots displacement tracking plus measured force.

if exist('outputVerificationFile', 'var')
    requestedFilePath = outputVerificationFile;
else
    requestedFilePath = '';
end
clc; close all

scriptFolder = fileparts(mfilename('fullpath'));
rootFolder = fullfile(scriptFolder, '..', '..', 'saved_results');
if ~exist(rootFolder, 'dir')
    error('Saved results folder was not found: %s', rootFolder);
end
[~, rootAttributes] = fileattrib(rootFolder);
rootFolder = rootAttributes.Name;

files = dir(fullfile(rootFolder, '**', '*.mat'));
if isempty(files)
    error('No MAT files were found under: %s', rootFolder);
end
[~, order] = sort(string(fullfile({files.folder}, {files.name})));
files = files(order);

if isempty(requestedFilePath)
    fprintf('\nAvailable saved result files:\n\n');
    printFileTree(rootFolder, files);

    selection = input('\nSelect file number to load: ');
    while ~isValidSelection(selection, numel(files))
        fprintf('Please enter a number from 1 to %d.\n', numel(files));
        selection = input('Select file number to load: ');
    end

    filePath = fullfile(files(selection).folder, files(selection).name);
    selectedFileName = files(selection).name;
else
    filePath = requestedFilePath;
    [~, selectedName, selectedExt] = fileparts(filePath);
    selectedFileName = [selectedName selectedExt];
end

data = load(filePath);
requiredSignals = {'t', 'dd', 'dc', 'dm', 'fm'};
for k = 1:numel(requiredSignals)
    if ~isfield(data, requiredSignals{k})
        error('The selected file is missing required signal "%s".', requiredSignals{k});
    end
end

t = data.t(:);
dd = data.dd(:);
dc = data.dc(:);
dm = data.dm(:);
fm = data.fm(:);

n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm)]);
t = t(1:n);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);

trackingError = dd - dm;
rmsError = sqrt(mean(trackingError.^2, 'omitnan'));

metadata = getResultMetadata(data, selectedFileName);
duration = t(end) - t(1);
fs = getScalarField(data, 'fs', NaN);
dt = getScalarField(data, 'dt', NaN);

fprintf('\n===============================================================\n');
fprintf('                    Saved Result Summary\n');
fprintf('===============================================================\n');
fprintf('File name:       %s\n', selectedFileName);
fprintf('Full path:       %s\n', filePath);
fprintf('Date/time:       %s\n', metadata.dateTime);
fprintf('Test type:       %s\n', metadata.testType);
fprintf('Specimen:        %s\n', metadata.specimen);
fprintf('Duration:        %.3f s\n', duration);
fprintf('Sample count:    %d\n', n);
fprintf('fs:              %.6g Hz\n', fs);
fprintf('dt:              %.6g s\n', dt);
fprintf('RMS(dd - dm):    %.6g mm\n', rmsError);
fprintf('===============================================================\n\n');

figure('Name', selectedFileName, 'WindowState', 'maximized');
colors = getPlotColors();

subplot(2, 1, 1)
hDesired = plot(t, dd, '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'dd desired displacement'); hold on
plot(t, dc, '-', 'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'dc command displacement');
plot(t, dm, '-', 'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'dm measured displacement');
uistack(hDesired, 'top')
grid on
xlabel('Time (s)')
ylabel('Displacement (mm)')
title('Displacement Tracking')
set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual')
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

subplot(2, 1, 2)
plot(t, fm, '-', 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'fm measured force');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual')
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

function printFileTree(rootFolder, files)
    currentFolder = "";
    fprintf('saved_results\n');
    for k = 1:numel(files)
        relFolder = getRelativeFolder(rootFolder, files(k).folder);
        if relFolder ~= currentFolder
            currentFolder = relFolder;
            if currentFolder ~= "."
                parts = split(currentFolder, filesep);
                for p = 1:numel(parts)
                    fprintf('%s%s\n', repmat('    ', 1, p), char(parts(p)));
                end
            end
        end
        if currentFolder == "."
            indentLevel = 1;
        else
            indentLevel = numel(split(currentFolder, filesep)) + 1;
        end
        fprintf('%s[%d] %s\n', repmat('    ', 1, indentLevel), k, files(k).name);
    end
end

function colors = getPlotColors()
    colors.green = hexToRgb('39BF5E');
    colors.black = [0 0 0];
    colors.blue = hexToRgb('007CA8');
    colors.red = hexToRgb('901500');
    colors.purple = hexToRgb('74058A');
    colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hexColor)
    rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end

function relFolder = getRelativeFolder(rootFolder, folder)
    rootFolder = string(rootFolder);
    folder = string(folder);
    rootWithSeparator = rootFolder + filesep;

    if strcmpi(folder, rootFolder)
        relFolder = ".";
    elseif startsWith(lower(folder), lower(rootWithSeparator))
        relFolder = extractAfter(folder, strlength(rootWithSeparator));
    else
        [~, relFolder] = fileparts(folder);
        relFolder = string(relFolder);
    end
end

function isValid = isValidSelection(selection, fileCount)
    isValid = isnumeric(selection) && isscalar(selection) && isfinite(selection) && ...
        selection >= 1 && selection <= fileCount && isequal(selection, floor(selection));
end

function metadata = getResultMetadata(data, fileName)
    metadata.dateTime = 'unknown';
    metadata.testType = 'unknown';
    metadata.specimen = 'unknown';

    if isfield(data, 'datename') && isfield(data, 'nametime')
        metadata.dateTime = formatDateTime(data.datename, data.nametime);
    else
        tokens = regexp(fileName, 'Test_(\d{8})_(\d{6})_', 'tokens', 'once');
        if ~isempty(tokens)
            metadata.dateTime = formatDateTime(tokens{1}, tokens{2});
        end
    end

    if isfield(data, 'test_signal')
        metadata.testType = testSignalName(data.test_signal);
    end

    if isfield(data, 'feat4') && ~isempty(strtrim(data.feat4))
        metadata.specimen = strtrim(data.feat4);
    else
        tokens = regexp(fileName, 'Signal_[^_]+_[^_]+_[^_]+_([^\.]+)\.mat$', 'tokens', 'once');
        if ~isempty(tokens)
            metadata.specimen = tokens{1};
        end
    end
end

function value = getScalarField(data, fieldName, defaultValue)
    if isfield(data, fieldName) && isscalar(data.(fieldName))
        value = data.(fieldName);
    else
        value = defaultValue;
    end
end

function label = testSignalName(testSignal)
    switch testSignal
        case 1
            label = '1 - Stair signal / time history';
        case 2
            label = '2 - Sine wave';
        case 3
            label = '3 - BLWN';
        case 4
            label = '4 - Chirp';
        case 5
            label = '5 - Constant';
        otherwise
            label = sprintf('%g - Unknown', testSignal);
    end
end

function label = formatDateTime(dateText, timeText)
    dateText = regexprep(char(dateText), '[^\d]', '');
    timeText = regexprep(char(timeText), '[^\d]', '');
    if numel(dateText) == 8 && numel(timeText) == 6
        label = sprintf('%s/%s/%s %s:%s:%s', dateText(1:2), dateText(3:4), dateText(5:8), timeText(1:2), timeText(3:4), timeText(5:6));
    else
        label = strtrim(sprintf('%s %s', dateText, timeText));
    end
end

function toggleSignalVisibility(~, event)
    ax = ancestor(event.Peer, 'axes');
    xLimits = xlim(ax);
    yLimits = ylim(ax);
    if strcmp(event.Peer.Visible, 'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
    xlim(ax, xLimits);
    ylim(ax, yLimits);
    set(ax, 'XLimMode', 'manual', 'YLimMode', 'manual')
end
