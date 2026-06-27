function summary = visualize_saved_results(result)
%% Visualize Saved Column Setup Results
% Plots displacement tracking, measured force, measured acceleration, and
% force-displacement hysteresis from a saved result struct.

%% Units
% Input/stored: t [s], dd/dc/dm [mm], fm [N], am [g], m_hat [kg],
% c_hat [N*s/m], k_hat [N/m]. Plotted outputs preserve those stored units.

if nargin < 1 || isempty(result)
    scriptFolder = fileparts(mfilename('fullpath'));
    projectFolder = fileparts(scriptFolder);
    addpath(fullfile(projectFolder, 'helpers', 'utils'))
    result = load_saved_result_file(projectFolder, 'tests', false);
end
if isfield(result, 'result') && isstruct(result.result)
    result = result.result;
end

t = result.t(:);
dd = result.dd(:);
dc = result.dc(:);
dm = result.dm(:);
fm = result.fm(:);
am = result.am(:);
hasTseEstimate = isfield(result, 'm_hat') && isfield(result, 'c_hat') ...
    && isfield(result, 'k_hat') && ~isempty(result.m_hat);

n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm), numel(am)]);
if hasTseEstimate
    n = min([n, numel(result.m_hat), numel(result.c_hat), ...
        numel(result.k_hat)]);
end
t = t(1:n);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);
am = am(1:n);
if hasTseEstimate
    m_hat = result.m_hat(1:n);
    c_hat = result.c_hat(1:n);
    k_hat = result.k_hat(1:n);
end

maxPlotPoints = 50000;
plotStep = max(1, ceil(n/maxPlotPoints));
plotIndex = 1:plotStep:n;
if plotIndex(end) ~= n
    plotIndex = [plotIndex n];
end

trackingError = dd - dm;
rmsError = sqrt(mean(trackingError.^2, 'omitnan'));
duration = t(end) - t(1);
fs = result.fs;
dt = result.dt;
test_type = getTestType(result);
resultName = getResultName(result);

summary = struct('name', resultName, 'test_type', test_type, ...
    'duration', duration, 'sample_count', n, 'fs', fs, 'dt', dt, ...
    'rms_dd_dm', rmsError);

fprintf('\n===============================================================\n');
fprintf('                    Saved Result Summary\n');
fprintf('===============================================================\n');
fprintf('Result:          %s\n', resultName);
fprintf('Test type:       %s\n', test_type);
fprintf('Duration:        %.3f s\n', duration);
fprintf('Sample count:    %d\n', n);
fprintf('fs:              %.6g Hz\n', fs);
fprintf('dt:              %.6g s\n', dt);
fprintf('RMS(dd - dm):    %.6g mm\n', rmsError);
fprintf('===============================================================\n\n');

figure('Name', resultName, 'WindowState', 'maximized');
colors = getPlotColors();
tPlot = t(plotIndex);
ddPlot = dd(plotIndex);
dcPlot = dc(plotIndex);
dmPlot = dm(plotIndex);
fmPlot = fm(plotIndex);
amPlot = am(plotIndex);

ax(1) = subplot(3, 1, 1);
hDesired = plot(tPlot, ddPlot, '--', 'Color', colors.black, ...
    'LineWidth', 1.8, 'DisplayName', 'dd desired displacement'); hold on
plot(tPlot, dcPlot, '-', 'Color', colors.copperwood, 'LineWidth', 1.0, ...
    'DisplayName', 'dc command displacement');
hMeasured = plot(tPlot, dmPlot, '-', 'Color', colors.blue, ...
    'LineWidth', 1.2, 'DisplayName', 'dm measured displacement');
uistack(hDesired, 'top')
uistack(hMeasured, 'top')
grid on
xlabel('Time (s)')
ylabel('Displacement (mm)')
title('Displacement Tracking')
setAxisLimitsFromSignals(gca, t, [dd dc dm])
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(2) = subplot(3, 1, 2);
plot(tPlot, fmPlot, '-', 'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm measured force');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
setAxisLimitsFromSignals(gca, t, fm)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(3) = subplot(3, 1, 3);
plot(tPlot, amPlot, '-', 'Color', colors.green, 'LineWidth', 1.0, ...
    'DisplayName', 'am measured acceleration');
grid on
xlabel('Time (s)')
ylabel('Acceleration (g)')
title('Acceleration History')
setAxisLimitsFromSignals(gca, t, am)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

linkaxes(ax, 'x')

figure('Name', [resultName ' - Hysteresis']);
patch(dmPlot, fmPlot, zeros(size(dmPlot)), 'FaceColor', 'none', ...
    'EdgeColor', colors.purple, 'EdgeAlpha', 0.3, 'LineWidth', 1.0);
grid on
xlabel('Measured displacement (mm)')
ylabel('Measured force (N)')
title('Force-Displacement Hysteresis')

if hasTseEstimate
    figure('Name', [resultName ' - Online TSE'], 'WindowState', 'maximized');
    mHatPlot = m_hat(plotIndex);
    cHatPlot = c_hat(plotIndex);
    kHatPlot = k_hat(plotIndex);

    ax_tse(1) = subplot(3, 1, 1);
    plot(tPlot, kHatPlot, 'Color', colors.blue, 'LineWidth', 1.0, ...
        'DisplayName', 'k hat');
    grid on
    ylabel('k (N/m)')
    title('Online TSE Stiffness')

    ax_tse(2) = subplot(3, 1, 2);
    plot(tPlot, mHatPlot, 'Color', colors.purple, 'LineWidth', 1.0, ...
        'DisplayName', 'm hat');
    grid on
    ylabel('m (kg)')
    title('Online TSE Mass')

    ax_tse(3) = subplot(3, 1, 3);
    plot(tPlot, cHatPlot, 'Color', colors.copperwood, 'LineWidth', 1.0, ...
        'DisplayName', 'c hat');
    grid on
    xlabel('Time (s)')
    ylabel('c (N s/m)')
    title('Online TSE Damping')
    linkaxes(ax_tse, 'x')
end
end

function colors = getPlotColors()
% Units: RGB outputs are dimensionless.
    colors.green = hexToRgb('39BF5E');
    colors.black = [0 0 0];
    colors.blue = hexToRgb('007CA8');
    colors.red = hexToRgb('901500');
    colors.purple = hexToRgb('74058A');
    colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hexColor)
% Units: hexadecimal input and RGB output are dimensionless.
    rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end

function toggleSignalVisibility(~, event)
% Units: plotted data and axis limits pass through unchanged.
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

function setAxisLimitsFromSignals(ax, time, signals)
% Units: time [s]; signals use the plotted channel units.
    finiteTime = time(isfinite(time));
    finiteSignals = signals(isfinite(signals));

    if isempty(finiteTime)
        xlim(ax, [0 1])
    else
        xMin = min(finiteTime);
        xMax = max(finiteTime);
        if xMin == xMax
            xPad = max(1, 0.05*abs(xMin));
            xlim(ax, [xMin - xPad, xMax + xPad])
        else
            xlim(ax, [xMin xMax])
        end
    end

    if isempty(finiteSignals)
        ylim(ax, [0 1])
    else
        yMin = min(finiteSignals);
        yMax = max(finiteSignals);
        yRange = yMax - yMin;
        if yRange == 0
            yPad = max(1, 0.05*abs(yMin));
        else
            yPad = 0.05*yRange;
        end
        ylim(ax, [yMin - yPad, yMax + yPad])
    end
end

function test_type = getTestType(result)
% Units: metadata input and text output are unitless.
    if isfield(result, 'test_type')
        test_type = char(string(result.test_type));
    elseif isfield(result, 'testname')
        test_type = char(string(result.testname));
    else
        test_type = 'unknown';
    end
end

function resultName = getResultName(result)
% Units: metadata input and text output are unitless.
    if isfield(result, 'file')
        resultName = pathLeaf(result.file);
    elseif isfield(result, 'file_name')
        resultName = pathLeaf(result.file_name);
    elseif isfield(result, 'testname')
        resultName = char(string(result.testname));
    else
        resultName = getTestType(result);
    end
end

function name = pathLeaf(value)
% Units: path or label input and label output are unitless.
    value = char(string(value));
    [~, baseName, ext] = fileparts(value);
    if isempty(baseName)
        name = value;
    else
        name = [baseName ext];
    end
end
