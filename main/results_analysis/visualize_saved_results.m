%% Visualize Saved Column Setup Results
% Lists saved result MAT files, prompts for one file, prints a compact
% report, displacement tracking, measured force, and force-displacement
% hysteresis.

%% Units
% Input/stored: t [s], dd/dc/dm [mm], fm [N], am [g], m_hat [kg],
% c_hat [N*s/m], k_hat [N/m]. Plotted outputs preserve those stored units.

clc; close all

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);
addpath(fullfile(projectFolder, 'helpers', 'utils'))

preferredFile = '';
if exist('outputVerificationFile', 'var')
    preferredFile = outputVerificationFile;
end
[data, filePath, selectedFileName] = load_saved_result_file( ...
    projectFolder, 'tests', false, preferredFile);

t = data.t(:);
dd = data.dd(:);
dc = data.dc(:);
dm = data.dm(:);
fm = data.fm(:);
am = data.am(:);
hasTseEstimate = isfield(data, 'm_hat') && isfield(data, 'c_hat') ...
    && isfield(data, 'k_hat') && ~isempty(data.m_hat);

n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm), numel(am)]);
if hasTseEstimate
    n = min([n, numel(data.m_hat), numel(data.c_hat), numel(data.k_hat)]);
end
t = t(1:n);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);
am = am(1:n);
if hasTseEstimate
    m_hat = data.m_hat(1:n);
    c_hat = data.c_hat(1:n);
    k_hat = data.k_hat(1:n);
end

trackingError = dd - dm;
rmsError = sqrt(mean(trackingError.^2, 'omitnan'));

duration = t(end) - t(1);
fs = data.fs;
dt = data.dt;
test_type = getTestType(data);

fprintf('\n===============================================================\n');
fprintf('                    Saved Result Summary\n');
fprintf('===============================================================\n');
fprintf('File name:       %s\n', selectedFileName);
fprintf('Test type:       %s\n', test_type);
fprintf('Full path:       %s\n', filePath);
fprintf('Duration:        %.3f s\n', duration);
fprintf('Sample count:    %d\n', n);
fprintf('fs:              %.6g Hz\n', fs);
fprintf('dt:              %.6g s\n', dt);
fprintf('RMS(dd - dm):    %.6g mm\n', rmsError);
fprintf('===============================================================\n\n');

figure('Name', selectedFileName, 'WindowState', 'maximized');
colors = getPlotColors();

ax(1) = subplot(3, 1, 1);
hDesired = plot(t, dd, '--', 'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'dd desired displacement'); hold on
plot(t, dc, '-', 'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'dc command displacement');
hMeasured = plot(t, dm, '-', 'Color', colors.blue, 'LineWidth', 1.2, 'DisplayName', 'dm measured displacement');
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
plot(t, fm, '-', 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'fm measured force');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
setAxisLimitsFromSignals(gca, t, fm)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(3) = subplot(3, 1, 3);
plot(t, am, '-', 'Color', colors.green, 'LineWidth', 1.0, 'DisplayName', 'am measured acceleration');
grid on
xlabel('Time (s)')
ylabel('Acceleration (g)')
title('Acceleration History')
setAxisLimitsFromSignals(gca, t, am)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

linkaxes(ax, 'x')

% Hysteresis shows the measured restoring force versus measured displacement.
figure('Name', [selectedFileName ' - Hysteresis']);
patch(dm, fm, zeros(size(dm)), 'FaceColor', 'none', ...
    'EdgeColor', colors.purple, 'EdgeAlpha', 0.3, 'LineWidth', 1.0);
grid on
xlabel('Measured displacement (mm)')
ylabel('Measured force (N)')
title('Force-Displacement Hysteresis')

if hasTseEstimate
    figure('Name', [selectedFileName ' - Online TSE'], 'WindowState', 'maximized');
    ax_tse(1) = subplot(3, 1, 1);
    plot(t, k_hat, 'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'k hat');
    grid on
    ylabel('k (N/m)')
    title('Online TSE Stiffness')

    ax_tse(2) = subplot(3, 1, 2);
    plot(t, m_hat, 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'm hat');
    grid on
    ylabel('m (kg)')
    title('Online TSE Mass')

    ax_tse(3) = subplot(3, 1, 3);
    plot(t, c_hat, 'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'c hat');
    grid on
    xlabel('Time (s)')
    ylabel('c (N s/m)')
    title('Online TSE Damping')
    linkaxes(ax_tse, 'x')
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

function test_type = getTestType(data)
% Units: metadata input and text output are unitless.
    if isfield(data, 'test_type')
        test_type = char(string(data.test_type));
    elseif isfield(data, 'testname')
        test_type = char(string(data.testname));
    else
        test_type = 'unknown';
    end
end
