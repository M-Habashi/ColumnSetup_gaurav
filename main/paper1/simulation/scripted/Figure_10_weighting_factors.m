% FIGURE_10_WEIGHTING_FACTORS Linear controller-blending profile.
% Adapted from Stability Analysis/Figure_9_weighting_factors.m.

t_star = 0;
transition_duration = 0.25;
t = linspace(t_star, t_star + 0.5, 1001);
elapsed_time = t - t_star;

gamma = min(max((t - t_star) / transition_duration, 0), 1);
gamma_comp = 1 - gamma;

fig_width = 6.27;
fig_height = 2.40;
font_name = 'Times New Roman';
font_size = 9;
line_width = 1.25;

fig = figure('Name', 'Linear controller-blending profile', ...
    'Units', 'inches', 'Position', [2 2 fig_width fig_height], ...
    'Color', 'w');
ax = axes('Parent', fig, 'Box', 'on', 'XLim', [0 0.5], ...
    'YLim', [-0.05 1.05], 'XTick', 0:0.05:0.5, 'YTick', 0:0.2:1, ...
    'FontName', font_name, 'FontSize', font_size, ...
    'TickLabelInterpreter', 'latex', 'GridColor', [0.7 0.7 0.7], ...
    'GridLineStyle', '--', 'GridAlpha', 1, 'LineWidth', 0.5, ...
    'Layer', 'bottom');
ax.Toolbar.Visible = 'off';
grid(ax, 'on');
hold(ax, 'on');

p1 = plot(ax, elapsed_time, gamma, 'Color', '#0c558e', ...
    'LineWidth', line_width);
p2 = plot(ax, elapsed_time, gamma_comp, 'Color', '#555555', ...
    'LineWidth', line_width);

xlabel(ax, '$t-t^*$ (sec)', 'Interpreter', 'latex', ...
    'FontName', font_name, 'FontSize', font_size);
ylabel(ax, 'Weighting Factors', 'Interpreter', 'latex', ...
    'FontName', font_name, 'FontSize', font_size);
lgd = legend(ax, [p1 p2], {'$\gamma(t)$', '$1-\gamma(t)$'}, ...
    'Location', 'northeast', 'Interpreter', 'latex', ...
    'FontName', font_name, 'FontSize', font_size);
lgd.ItemTokenSize = [18 15];
hold(ax, 'off');

scripted_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(scripted_dir);
output_file = fullfile(project_root, 'Results', ...
    'scripted_controller_ramp_profile.png');
drawnow;
exportgraphics(fig, output_file, 'Resolution', 800, ...
    'Units', 'inches', 'Width', fig_width, 'Padding', 0, ...
    'PreserveAspectRatio', 'on');
fprintf('Controller ramp profile saved to %s\n', output_file);
