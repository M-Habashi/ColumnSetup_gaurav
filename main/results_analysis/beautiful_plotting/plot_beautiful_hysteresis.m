function plot_beautiful_hysteresis
%% Plot beautiful.mat with a time-controlled colored trace.
% The complete record remains visible in gray. Moving the slider overlays
% the portion reached so far in the established blue/red signal colors.

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
tPlot = t(plotIndex);
dmFiltPlot = dm_filt_filt(plotIndex);
fmPlot = fm(plotIndex);

colors.blue = hexToRgb('007CA8');
colors.red = hexToRgb('901500');
gray = [0.70 0.70 0.70];

figureHandle = figure('Name', 'beautiful.mat - Interactive Plot', ...
    'NumberTitle', 'off', 'Color', 'w');
topAxes = axes('Parent', figureHandle, 'Position', [0.10 0.57 0.86 0.34]);
bottomAxes = axes('Parent', figureHandle, 'Position', [0.10 0.16 0.86 0.34]);

plot(topAxes, tPlot, dmFiltPlot, '-', 'Color', gray, ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');
hold(topAxes, 'on')
topColor = plot(topAxes, tPlot(1), dmFiltPlot(1), '-', ...
    'Color', colors.blue, 'LineWidth', 1.4, ...
    'DisplayName', 'dm\_filt\_filt');
hold(topAxes, 'off')
grid(topAxes, 'on')
box(topAxes, 'on')
xlim(topAxes, [tPlot(1) tPlot(end)])
xlabel(topAxes, 'Time (s)')
ylabel(topAxes, 'Displacement (mm)')
title(topAxes, 'Filtered measured displacement, dm\_filt\_filt')
legend(topAxes, topColor, 'Location', 'best', 'Interpreter', 'none')

plot(bottomAxes, dmFiltPlot, fmPlot, '-', 'Color', gray, ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');
hold(bottomAxes, 'on')
hysteresisColor = plot(bottomAxes, dmFiltPlot(1), fmPlot(1), '-', ...
    'Color', colors.red, 'LineWidth', 1.4, ...
    'DisplayName', 'Hysteresis');
hold(bottomAxes, 'off')
grid(bottomAxes, 'on')
box(bottomAxes, 'on')
xlabel(bottomAxes, 'Filtered measured displacement (mm)')
ylabel(bottomAxes, 'Measured force, fm (N)')
title(bottomAxes, 'Force-displacement hysteresis')
legend(bottomAxes, hysteresisColor, 'Location', 'best', ...
    'Interpreter', 'none')

uicontrol(figureHandle, 'Style', 'slider', 'Units', 'normalized', ...
    'Position', [0.10 0.06 0.86 0.04], 'Min', tPlot(1), ...
    'Max', tPlot(end), 'Value', tPlot(1), ...
    'SliderStep', [1/max(1, numel(tPlot)-1), 0.05], ...
    'Callback', @updateColorProgress);
uicontrol(figureHandle, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.02 0.06 0.07 0.04], 'String', 'Time', ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'right');
timeLabel = uicontrol(figureHandle, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.10 0.01 0.86 0.035], 'String', ...
    sprintf('t = %.3f s', tPlot(1)), 'BackgroundColor', 'w');

    function updateColorProgress(source, ~)
        lastPoint = find(tPlot <= source.Value, 1, 'last');
        if isempty(lastPoint)
            lastPoint = 1;
        end
        set(topColor, 'XData', tPlot(1:lastPoint), ...
            'YData', dmFiltPlot(1:lastPoint));
        set(hysteresisColor, 'XData', dmFiltPlot(1:lastPoint), ...
            'YData', fmPlot(1:lastPoint));
        set(timeLabel, 'String', sprintf('t = %.3f s', tPlot(lastPoint)));
    end
end

function y = filtfiltDm(dm, fs, cutoffHz, order)
% Units: dm/y [mm], fs/cutoffHz [Hz].
    [b, a] = butter(order, cutoffHz/(fs/2), 'low');
    y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function rgb = hexToRgb(hexColor)
    rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end
