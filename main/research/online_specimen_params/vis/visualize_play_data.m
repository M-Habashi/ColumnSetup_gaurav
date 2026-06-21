function visualize_play_data(data_file)
% Units: input/plotted t [s], dm [mm], fm [N].
if nargin < 1 || isempty(data_file)
    root = fileparts(fileparts(mfilename('fullpath')));
    data_file = fullfile(root, 'data', 'sp_1_ori_P30_I0_t430_590.mat');
end

S = load(data_file);

figure('Name', data_file, 'NumberTitle', 'off')

subplot(2, 1, 1)
plot(S.t, S.dm, 'Color', '#007CA8', 'DisplayName', 'measured')
grid on
ylabel('Displacement (mm)')
legend('Location', 'best')
title(data_file, 'Interpreter', 'none')

subplot(2, 1, 2)
plot(S.t, S.fm, 'Color', '#74058A', 'DisplayName', 'force')
grid on
xlabel('Time (s)')
ylabel('Force (N)')
end
