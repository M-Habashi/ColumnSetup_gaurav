% Parameter definition
n = 20;
t_star = 0;
t = linspace(0, 1, 1000);

% Define Gamma
gamma = zeros(size(t));
mask = t >= t_star;
gamma(mask) = 1 ./ (1 + exp(-n .* (t(mask) - 5/n)));

% Define Complementary
gamma_comp = 1 - gamma;

% 1. Figure Specs
fig = figure('Units', 'inches', 'Position', [2, 2, 8.27, 3]);

% 2. Plotting
hold on;
% Plot Gamma (Blue - #0c558e)
p1 = plot(t, gamma, 'Color', '#0c558e', 'LineWidth', 1.5);

% Plot Complementary (Grey - #555555)
p2 = plot(t, gamma_comp, 'Color', '#555555', 'LineWidth', 1.5);

% 3. Axes Configuration
grid on; box on;
xlim([0, 1]);
ylim([-0.05, 1.05]);

% Typography
set(gca, 'FontName', 'Times New Roman', 'FontSize', 9, ...
    'TickLabelInterpreter', 'latex');

% Labels
xlabel('$t$ (sec)', 'Interpreter', 'latex');
ylabel('Weighting Factors', 'Interpreter', 'latex');

% Legend
lgd = legend([p1, p2], {'$\gamma(t)$', '$1 - \gamma(t)$'}, ...
    'Location', 'northeast', ...
    'Interpreter', 'latex');
lgd.ItemTokenSize = [20, 18];

% 5. Output
script_path = mfilename('fullpath');
[script_dir, script_name] = fileparts(script_path);
output_file = fullfile(script_dir, [script_name '.png']);
drawnow;
exportgraphics(fig, output_file, 'Resolution', 800);
