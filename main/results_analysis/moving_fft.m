function moving_fft
%% Moving FFT for Saved Column Setup Results
% Pick a saved result MAT file, select dd/dc/dm/fm, and inspect the FFT
% inside an interactive moving time window.

%% Units
% t/window [s], frequency [Hz], dd/dc/dm [mm], fm [N].

clc
close all

fmax = 100; % Hz
defaultWindowSeconds = 1; % s

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);
addpath(scriptFolder)
addpath(fullfile(projectFolder, 'helpers', 'utils'))

preferredFile = '';
if evalin('base', 'exist(''outputVerificationFile'', ''var'')')
    preferredFile = evalin('base', 'outputVerificationFile');
end

[data, ~, fileName] = load_saved_result_file( ...
    projectFolder, 'tests', false, preferredFile);
[t, fs, signals] = getResultSignals(data);
colors = getPlotColors();

channelNames = fieldnames(signals);
windowSeconds = min(defaultWindowSeconds, t(end) - t(1));
selectedWindow = [t(1), t(1) + windowSeconds];
if selectedWindow(1) == selectedWindow(2)
    selectedWindow = [t(1), t(end)];
end

fig = figure('Name', ['Moving FFT - ' fileName], 'NumberTitle', 'off', ...
    'Color', 'w', 'WindowState', 'maximized');

controlPanel = uipanel(fig, 'Units', 'normalized', ...
    'Position', [0 0.93 1 0.07], 'BorderType', 'none', ...
    'BackgroundColor', 'w');
uicontrol(controlPanel, 'Style', 'text', 'String', 'Signal', ...
    'Units', 'normalized', 'Position', [0.02 0.18 0.06 0.48], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
signalMenu = uicontrol(controlPanel, 'Style', 'popupmenu', ...
    'String', channelNames, 'Units', 'normalized', ...
    'Position', [0.08 0.18 0.10 0.55], ...
    'Callback', @(~, ~)updatePlots(true));
uicontrol(controlPanel, 'Style', 'text', 'String', 'Window (s)', ...
    'Units', 'normalized', 'Position', [0.21 0.18 0.08 0.48], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
windowEdit = uicontrol(controlPanel, 'Style', 'edit', ...
    'String', sprintf('%.6g', diff(selectedWindow)), ...
    'Units', 'normalized', 'Position', [0.29 0.18 0.08 0.55], ...
    'Callback', @(~, ~)updateWindowLength());
uicontrol(controlPanel, 'Style', 'text', 'String', 'Window start', ...
    'Units', 'normalized', 'Position', [0.40 0.18 0.09 0.48], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
windowSlider = uicontrol(controlPanel, 'Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.49 0.25 0.34 0.35], ...
    'Callback', @(~, ~)moveWindowFromSlider());
statusText = uicontrol(controlPanel, 'Style', 'text', 'String', '', ...
    'Units', 'normalized', 'Position', [0.85 0.18 0.13 0.48], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

axSignal = subplot(2, 1, 1, 'Parent', fig);
axFft = subplot(2, 1, 2, 'Parent', fig);
set(axSignal, 'Position', [0.08 0.53 0.88 0.34])
set(axFft, 'Position', [0.08 0.10 0.88 0.34])

signalLine = plot(axSignal, nan, nan, 'LineWidth', 1.2);
grid(axSignal, 'on')
xlabel(axSignal, 'Time (s)')
hold(axSignal, 'on')
windowPatch = patch(axSignal, nan, nan, [1 0.85 0], ...
    'FaceAlpha', 0.20, 'EdgeColor', 'none');
leftLine = plot(axSignal, nan, nan, 'Color', [0.85 0.55 0], ...
    'LineWidth', 2.5, 'ButtonDownFcn', @(~, ~)startDrag(1));
rightLine = plot(axSignal, nan, nan, 'Color', [0.85 0.55 0], ...
    'LineWidth', 2.5, 'ButtonDownFcn', @(~, ~)startDrag(2));
uistack(windowPatch, 'bottom')

fftLine = plot(axFft, nan, nan, 'LineWidth', 1.2);
grid(axFft, 'on')
xlabel(axFft, 'Frequency (Hz)')
xlim(axFft, [0 fmax])

draggingSide = 0;
set(fig, 'WindowButtonMotionFcn', @dragWindowHandle, ...
    'WindowButtonUpFcn', @(~, ~)stopDrag());

updateSliderLimits()
updatePlots(true)

function updatePlots(resetSignalAxes)
    % Units: selected signal keeps its stored unit; FFT amplitude matches it.
    if nargin < 1
        resetSignalAxes = false;
    end
    channel = channelNames{signalMenu.Value};
    y = signals.(channel)(:);
    xLimits = xlim(axSignal);
    yLimits = ylim(axSignal);
    set(signalLine, 'XData', t, 'YData', y, ...
        'Color', channelColor(channel, colors))
    ylabel(axSignal, signalLabel(channel))
    title(axSignal, sprintf('%s: %s', fileName, signalName(channel)), ...
        'Interpreter', 'none')
    if resetSignalAxes
        setAxisLimitsFromSignals(axSignal, t, y)
    else
        xlim(axSignal, xLimits)
        ylim(axSignal, yLimits)
        set(axSignal, 'XLimMode', 'manual', 'YLimMode', 'manual')
    end
    updateWindowGraphics()

    keep = t >= selectedWindow(1) & t <= selectedWindow(2);
    if nnz(keep) < 2
        set(fftLine, 'XData', nan, 'YData', nan)
    else
        yWindow = y(keep);
        yWindow = yWindow - mean(yWindow, 'omitnan');
        [Y, freq] = fft_c(yWindow, fs, fmax);
        set(fftLine, 'XData', freq, 'YData', abs(Y), ...
            'Color', channelColor(channel, colors))
    end

    ylabel(axFft, ['|' channel '(f)|'])
    title(axFft, sprintf('FFT in %.6g to %.6g s window', ...
        selectedWindow(1), selectedWindow(2)))
    xlim(axFft, [0 fmax])
    updateFftYLimits()
    statusText.String = sprintf('%.4g to %.4g s', ...
        selectedWindow(1), selectedWindow(2));
    drawnow limitrate
end

function updateWindowLength()
    % Units: window edit value and selected window are s.
    newLength = str2double(windowEdit.String);
    if ~isfinite(newLength) || newLength <= 0
        windowEdit.String = sprintf('%.6g', diff(selectedWindow));
        return
    end
    newLength = min(newLength, t(end) - t(1));
    selectedWindow(2) = selectedWindow(1) + newLength;
    if selectedWindow(2) > t(end)
        selectedWindow = [t(end) - newLength, t(end)];
    end
    windowEdit.String = sprintf('%.6g', diff(selectedWindow));
    updateSliderLimits()
    updatePlots(false)
end

function moveWindowFromSlider()
    % Units: slider value and selected window are s.
    width = diff(selectedWindow);
    selectedWindow = [windowSlider.Value, windowSlider.Value + width];
    updatePlots(false)
end

function startDrag(side)
    % Units: side is a unitless index.
    draggingSide = side;
end

function stopDrag()
    % Units: callback state is unitless.
    if draggingSide ~= 0
        selectedWindow = sort(selectedWindow);
        if selectedWindow(1) == selectedWindow(2)
            selectedWindow(2) = min(t(end), selectedWindow(1) + 1/fs);
        end
        windowEdit.String = sprintf('%.6g', diff(selectedWindow));
        updateSliderLimits()
        updatePlots(false)
    end
    draggingSide = 0;
end

function dragWindowHandle(~, ~)
    % Units: pointer x-coordinate and selected window are s.
    if draggingSide == 0
        return
    end
    cp = get(axSignal, 'CurrentPoint');
    selectedWindow(draggingSide) = min(max(cp(1, 1), t(1)), t(end));
    selectedWindow = sort(selectedWindow);
    windowEdit.String = sprintf('%.6g', diff(selectedWindow));
    updateSliderLimits()
    updatePlots(false)
end

function updateSliderLimits()
    % Units: slider value is the window start time in s.
    width = diff(selectedWindow);
    maxStart = max(t(1), t(end) - width);
    windowSlider.Min = t(1);
    windowSlider.Max = maxStart + eps(max(abs(maxStart), 1));
    windowSlider.Value = min(max(selectedWindow(1), t(1)), maxStart);
    if maxStart == t(1)
        windowSlider.Enable = 'off';
    else
        windowSlider.Enable = 'on';
        windowSlider.SliderStep = [min(0.01, 1/max(numel(t) - 1, 1)), 0.10];
    end
end

function updateWindowGraphics()
    % Units: selected window is s; y-axis limits preserve y units.
    yl = ylim(axSignal);
    set(windowPatch, 'XData', selectedWindow([1 2 2 1]), ...
        'YData', yl([1 1 2 2]))
    set(leftLine, 'XData', selectedWindow([1 1]), 'YData', yl)
    set(rightLine, 'XData', selectedWindow([2 2]), 'YData', yl)
end

function updateFftYLimits()
    % Units: FFT amplitude limits match the selected signal unit.
    yData = fftLine.YData;
    yData = yData(isfinite(yData));
    if isempty(yData)
        ylim(axFft, [0 1])
        return
    end
    yMax = max(yData);
    if yMax <= 0
        ylim(axFft, [0 1])
    else
        ylim(axFft, [0 1.05*yMax])
    end
end
end

function [t, fs, signals] = getResultSignals(data)
% Units: t [s], fs [Hz], dd/dc/dm [mm], fm [N].
    required = {'dd', 'dc', 'dm', 'fm'};
    for i = 1:numel(required)
        assert(isfield(data, required{i}), ...
            'Selected MAT file does not contain %s.', required{i})
        signals.(required{i}) = data.(required{i})(:);
    end

    n = min(structfun(@numel, signals));
    for i = 1:numel(required)
        signals.(required{i}) = signals.(required{i})(1:n);
    end

    if isfield(data, 't') && numel(data.t) >= n
        t = data.t(1:n);
        t = t(:);
    elseif isfield(data, 'tt') && numel(data.tt) >= n
        t = data.tt(1:n);
        t = t(:);
    elseif isfield(data, 'fs')
        t = (0:n - 1).' / data.fs;
    elseif isfield(data, 'dt')
        t = (0:n - 1).' * data.dt;
    else
        error('Selected MAT file must contain t, tt, fs, or dt.')
    end

    if isfield(data, 'fs')
        fs = data.fs;
    else
        fs = 1/mean(diff(t));
    end
end

function setAxisLimitsFromSignals(ax, time, signal)
% Units: time [s]; signal preserves channel units.
    finiteTime = time(isfinite(time));
    finiteSignal = signal(isfinite(signal));
    if isempty(finiteTime)
        xlim(ax, [0 1])
    else
        xlim(ax, [finiteTime(1) finiteTime(end)])
    end

    if isempty(finiteSignal)
        ylim(ax, [0 1])
    else
        yMin = min(finiteSignal);
        yMax = max(finiteSignal);
        yRange = yMax - yMin;
        if yRange == 0
            yPad = max(1, 0.05*abs(yMin));
        else
            yPad = 0.05*yRange;
        end
        ylim(ax, [yMin - yPad, yMax + yPad])
    end
end

function label = signalLabel(channel)
% Units: label text is unitless.
    switch channel
        case {'dd', 'dc', 'dm'}
            label = [channel ' (mm)'];
        case 'fm'
            label = 'fm (N)';
    end
end

function name = signalName(channel)
% Units: name text is unitless.
    switch channel
        case 'dd'
            name = 'desired displacement';
        case 'dc'
            name = 'command displacement';
        case 'dm'
            name = 'measured displacement';
        case 'fm'
            name = 'measured force';
    end
end

function color = channelColor(channel, colors)
% Units: RGB output is dimensionless.
    switch channel
        case 'dd'
            color = colors.black;
        case 'dc'
            color = colors.copperwood;
        case 'dm'
            color = colors.blue;
        case 'fm'
            color = colors.purple;
    end
end

function colors = getPlotColors()
% Units: RGB outputs are dimensionless.
    colors.black = [0 0 0];
    colors.blue = hexToRgb('007CA8');
    colors.purple = hexToRgb('74058A');
    colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hexColor)
% Units: hexadecimal input and RGB output are dimensionless.
    rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end
