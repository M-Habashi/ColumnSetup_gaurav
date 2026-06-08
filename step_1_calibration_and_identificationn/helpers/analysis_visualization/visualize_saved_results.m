%% Visualize Saved Column Setup Results
% Lists saved result MAT files, prompts for one file, prints a compact
% report, and plots displacement tracking plus measured force.

clc; close all

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fullfile(scriptFolder, '..', '..');
addpath(fullfile(projectFolder, 'helpers', 'utils'))

[data, filePath, selectedFileName] = load_saved_result_file(projectFolder);

t = data.t(:);
dd = data.dd(:);
dc = data.dc(:);
dm = data.dm(:);
fm = data.fm(:);
am = data.am(:);

n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm), numel(am)]);
t = t(1:n);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);
am = am(1:n);

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
plot(t, dm, '-', 'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'dm measured displacement');
uistack(hDesired, 'top')
grid on
xlabel('Time (s)')
ylabel('Displacement (mm)')
title('Displacement Tracking')
set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual')
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(2) = subplot(3, 1, 2);
plot(t, fm, '-', 'Color', colors.purple, 'LineWidth', 1.0, 'DisplayName', 'fm measured force');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual')
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(3) = subplot(3, 1, 3);
plot(t, am, '-', 'Color', colors.green, 'LineWidth', 1.0, 'DisplayName', 'am measured acceleration');
grid on
xlabel('Time (s)')
ylabel('Acceleration')
title('Acceleration History')
set(gca, 'XLimMode', 'manual', 'YLimMode', 'manual')
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

linkaxes(ax, 'x')

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

function test_type = getTestType(data)
    if isfield(data, 'test_type')
        test_type = char(string(data.test_type));
    elseif isfield(data, 'testname')
        test_type = char(string(data.testname));
    else
        test_type = 'unknown';
    end
end
