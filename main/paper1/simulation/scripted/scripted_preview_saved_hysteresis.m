function fig = scripted_preview_saved_hysteresis(resultPath)
%SCRIPTED_PREVIEW_SAVED_HYSTERESIS Open Case IV hysteresis without simulation.
if nargin < 1 || strlength(string(resultPath)) == 0
    resultFiles = dir(fullfile('Results', 'case_04_*_Nom_.mat'));
    assert(~isempty(resultFiles), 'No saved Case IV nominal result was found.');
    [~, newestIndex] = max([resultFiles.datenum]);
    resultPath = fullfile(resultFiles(newestIndex).folder, ...
        resultFiles(newestIndex).name);
end

saved = load(resultPath, 't', 'BoucWen', 'Restoring_force', 'options');
required = {'t', 'BoucWen', 'Restoring_force', 'options'};
assert(all(isfield(saved, required)), ...
    'The saved result does not contain the required hysteresis data.');

time = saved.t(:);
forceN = saved.Restoring_force.Data(:, 1);
hystereticState = saved.BoucWen.Data(:, 1);
sampleCount = min([numel(time), numel(forceN), numel(hystereticState)]);
time = time(1:sampleCount);
forceN = forceN(1:sampleCount);
hystereticState = hystereticState(1:sampleCount);

elasticStiffness = 1190e3;
postYieldRatio = saved.options.post_yield_ratio;
alphaStart = saved.options.alpha_start;
kx = postYieldRatio * alphaStart * elasticStiffness;
kw = (1 - postYieldRatio) * alphaStart * elasticStiffness;
displacementMm = 1e3 * (forceN - kw * hystereticState) / kx;
forceKn = 1e-3 * forceN;

fig = figure('Name', 'Case IV hysteresis transparency preview', ...
    'NumberTitle', 'off', 'Color', 'w', 'Units', 'inches', ...
    'Position', [1 1 6.27 5.00]);
ax = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.11 0.14 0.85 0.78]);
hold(ax, 'on');
grid(ax, 'on');

xExtent = max(abs(displacementMm), [], 'omitnan');
yExtent = max(abs(forceKn), [], 'omitnan');
xLimit = 1.05 * xExtent;
yLimit = 1.05 * yExtent;
xlim(ax, [-xLimit, xLimit]);
ylim(ax, [-yLimit, yLimit]);
xticks(ax, linspace(-xLimit, xLimit, 5));
yticks(ax, linspace(-yLimit, yLimit, 5));
ax.XAxis.TickLabelFormat = '%.1f';
ax.YAxis.TickLabelFormat = '%.1f';

xlabel(ax, '$d$ (mm)', 'Interpreter', 'latex');
ylabel(ax, '$F$ (kN)', 'Interpreter', 'latex');
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
ax.LabelFontSizeMultiplier = 1;
ax.TickLabelInterpreter = 'latex';
ax.Box = 'on';
ax.LineWidth = 0.5;
ax.GridColor = [0.75 0.75 0.75];
ax.GridAlpha = 0.35;

zeroColor = [0.35 0.35 0.35];
plot(ax, [0 0], ylim(ax), '-', 'Color', zeroColor, ...
    'LineWidth', 0.75, 'HandleVisibility', 'off');
plot(ax, xlim(ax), [0 0], '-', 'Color', zeroColor, ...
    'LineWidth', 0.75, 'HandleVisibility', 'off');
scripted_plot_hysteresis_cycles(ax, time, displacementMm, forceKn, ...
    [0.20 0.48 0.70], 1.00, 0.75);
drawnow;
fprintf('Opened Case IV hysteresis from saved data: %s\n', resultPath);
end
