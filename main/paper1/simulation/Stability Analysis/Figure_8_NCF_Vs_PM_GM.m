%% === 0) Data Generation ===
b_s = 0:0.001:0.6;

% Guaranteed Gain Margin [dB]
GM_linear = (1 + b_s) ./ (1 - b_s);
GM_db = 20 * log10(GM_linear);

% Guaranteed Phase Margin [deg]
PM_deg = 2 * rad2deg(asin(b_s));

% Colors
c_blue   = '#0c558e';
c_purple = '#a5347b';

%% === 1) Figure & Axes Setup ===
fig_width  = 6.27; 
fig_height = 3;

fig = figure('Units','inches','Position',[5 5 fig_width fig_height],'Color','w');
ax  = axes('Parent',fig, ...
    'FontName', 'Times New Roman', 'FontSize', 10, ...
    'Box','on', 'Layer','bottom');
grid(ax,'on'); hold(ax,'on');

ls = {'LineStyle','-', 'LineWidth', 1.5}; 

%% === 2) Plotting with Dual Axes ===

% --- Left Axis: Gain Margin (Blue) ---
yyaxis left
plot(ax, b_s, GM_db, ls{:}, 'Color', c_blue);
set(ax, 'YColor', c_blue, ... % Ticks are blue
        'YLim', [0 14], ...
        'YTick', 0:2:14, ...
        'TickLabelInterpreter','latex', ...
        'FontName','Times New Roman', 'FontSize',10);
ylabel(ax, 'Guaranteed GM (dB)', ...
    'Interpreter','latex', 'FontName','Times New Roman', 'FontSize',10);

% --- Right Axis: Phase Margin (Purple) ---
yyaxis right
plot(ax, b_s, PM_deg, ls{:}, 'Color', c_purple);
set(ax, 'YColor', c_purple, ... % Ticks are purple
        'YLim', [0 90], ...
        'YTick', 0:15:90, ...
        'TickLabelInterpreter','latex', ...
        'FontName','Times New Roman', 'FontSize',10);
ylabel(ax, 'Guaranteed PM (deg)', ...
    'Interpreter','latex', 'FontName','Times New Roman', 'FontSize',10);

%% === 3) Force Axis Titles to Black ===
% yyaxis normally colors labels to match the axis. We explicitly turn them black here.
ax.YAxis(1).Label.Color = [0 0 0]; 
ax.YAxis(2).Label.Color = [0 0 0];

%% === 4) Labels & Legend ===
xlabel(ax, 'Scaled NCF margin ($b_s$)', 'Interpreter','latex', ...
    'FontName','Times New Roman', 'FontSize',10);
xlim(ax, [0 0.6]);
ax.XAxis.TickLabelInterpreter = 'latex';

% Legend with text descriptions instead of equations
lgd = legend(ax, {'Guaranteed GM', 'Guaranteed PM'}, ...
       'Interpreter','latex', ...
       'FontName','Times New Roman', 'FontSize',10, ...
       'Location','northwest');
lgd.ItemTokenSize = [20, 18];

hold(ax,'off');

%% === 5) Export ===
script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);
drawnow;
output_file = fullfile(script_dir, [script_name '.svg']);
exportgraphics(fig, output_file, 'ContentType', 'vector');
disp(['Figure exported to ', output_file, '.']);
