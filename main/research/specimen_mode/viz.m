clear; clc; close all

%% Units
% Input and plotted output: t [s], dd/dc/dm [mm], fm [N].

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));
addpath(step_root)
addpaths();

[data, ~, selected_file] = load_saved_result_file(step_root, 'tests');

t = data.t;
dd = data.dd;
dc = data.dc;
dm = data.dm;
fm = data.fm;

figure('Name', selected_file)

subplot(2,1,1)
plot(t, dd, 'k--', 'LineWidth', 1.8)
hold on
plot(t, dc, 'Color', '#AC6420')
plot(t, dm, 'Color', '#007CA8')
grid on
ylabel('Displacement (mm)')
legend('d\_n / dd', 'dc', 'dm')
title(selected_file, 'Interpreter', 'none')

subplot(2,1,2)
plot(t, fm, 'Color', '#74058A')
grid on
xlabel('Time (s)')
ylabel('Force (N)')
