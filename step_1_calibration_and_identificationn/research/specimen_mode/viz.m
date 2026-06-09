clear; clc; close all

data_folder = 'data';
files = dir(fullfile(data_folder, '*.mat'));
for i = 1:numel(files)
    fprintf('%d) %s\n', i, files(i).name);
end

k = input('Select file number: ');
load(fullfile(files(k).folder, files(k).name))

figure('Name', files(k).name)

subplot(2,1,1)
plot(t, dd, 'k--', 'LineWidth', 1.8)
hold on
plot(t, dc, 'Color', '#AC6420')
plot(t, dm, 'Color', '#007CA8')
grid on
ylabel('Displacement')
legend('desired', 'command', 'measured')
title(files(k).name, 'Interpreter', 'none')

subplot(2,1,2)
plot(t, fm, 'Color', '#74058A')
grid on
xlabel('Time (s)')
ylabel('Force')
