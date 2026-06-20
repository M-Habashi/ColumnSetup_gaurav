%% Visualize Saved Column Setup FFT
% Lists saved result MAT files, prompts for one file, and plots each channel
% FFT in a separate subplot.

%% User inputs
fmax = 100; % Hz

clc; close all

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fullfile(scriptFolder, '..');
addpath(fullfile(projectFolder, 'helpers', 'utils'))

[data, ~, selectedFileName] = load_saved_result_file(projectFolder, 'tests');
t = data.t(:);
fs = data.fs;
dd = data.dd(:);
dc = data.dc(:);
dm = data.dm(:);
fm = data.fm(:);
am = data.am(:);

n = min([numel(t), numel(dd), numel(dc), numel(dm), numel(fm), numel(am)]);
dd = dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
fm = fm(1:n);
am = am(1:n);

colors = getPlotColors();

figure('Name', ['FFT - ' selectedFileName], 'WindowState', 'maximized');

ax(1) = subplot(5, 1, 1);
[Y, freq] = fft_c(dd, fs, fmax);
plot(freq, abs(Y), '--', 'Color', colors.black, 'LineWidth', 1.8)
grid on
ylabel('|dd(f)|')
title('dd desired displacement')

ax(2) = subplot(5, 1, 2);
[Y, freq] = fft_c(dc, fs, fmax);
plot(freq, abs(Y), '-', 'Color', colors.copperwood, 'LineWidth', 1.0)
grid on
ylabel('|dc(f)|')
title('dc command displacement')

ax(3) = subplot(5, 1, 3);
[Y, freq] = fft_c(dm, fs, fmax);
plot(freq, abs(Y), '-', 'Color', colors.blue, 'LineWidth', 1.0)
grid on
ylabel('|dm(f)|')
title('dm measured displacement')

ax(4) = subplot(5, 1, 4);
[Y, freq] = fft_c(fm, fs, fmax);
plot(freq, abs(Y), '-', 'Color', colors.purple, 'LineWidth', 1.0)
grid on
ylabel('|fm(f)|')
title('fm measured force')

ax(5) = subplot(5, 1, 5);
[Y, freq] = fft_c(am, fs, fmax);
plot(freq, abs(Y), '-', 'Color', colors.green, 'LineWidth', 1.0)
grid on
xlabel('Frequency (Hz)')
ylabel('|am(f)|')
title('am measured acceleration')

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
