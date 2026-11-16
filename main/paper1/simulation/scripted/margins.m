function result = margins(exportFigures)
%MARGINS Regenerate manuscript Figures 4 and 8 from scripted parameters.
%   MARGINS uses the latest completed SCRIPTED_MAIN controller snapshot and
%   the executed physical damping ratio. It plots normalized numerical-loop
%   critical delay, physical-loop critical delay, physical-loop gain margin,
%   and (for Figure 8) the NCF margin b_g.
%
%   MARGINS(false) opens both figures without exporting them.

if nargin < 1
    exportFigures = true;
end

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);

[lastRun, configurationPath] = ...
    scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    error('scripted:NoLastRunConfiguration', ...
        ['Run scripted_main before margins so the figures use a saved ', ...
        'controller and configuration snapshot.']);
end

p = scripted_build_trial(lastRun.Options, projectRoot, 1);
p.controller_a = controller_from_record(lastRun.ControllerA);
p.controller_b = controller_from_record(lastRun.ControllerB);
p.controller_c = controller_from_record(lastRun.ControllerC);
p.pi_a_kp = p.controller_a.Kp;
p.pi_a_ki = p.controller_a.Ki;
p.pi_b_kp = p.controller_b.Kp;
p.pi_b_ki = p.controller_b.Ki;
p.pi_c_kp = p.controller_c.Kp;
p.pi_c_ki = p.controller_c.Ki;

alpha = 1:-0.01:0;
sampleCount = numel(alpha);
delayNumerical = zeros(1, sampleCount);
delayPhysical = zeros(1, sampleCount);
gainPhysicalDb = zeros(1, sampleCount);
ncfMargin = zeros(1, sampleCount);

numericalOutputCount = size(p.C_ns, 1);
physicalA = zeros(numericalOutputCount);
physicalB = eye(numericalOutputCount);
physicalC = zeros(1, numericalOutputCount);

for sample = 1:sampleCount
    alphaNow = alpha(sample);
    stiffness = alphaNow * p.k_e;
    damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
    trackingPlant = feedback(scripted_inner_open_loop( ...
        p.m_e, damping, stiffness), 1);
    physicalOpenLoop = p.controller_a * trackingPlant;
    physicalMargins = allmargin(physicalOpenLoop);

    delayPhysical(sample) = stable_minimum( ...
        physicalMargins.DelayMargin, physicalMargins.Stable, false);
    gainPhysicalDb(sample) = stable_minimum( ...
        physicalMargins.GainMargin, physicalMargins.Stable, true);
    ncfMargin(sample) = blk_indicator_margin(alphaNow, 1, p) * ...
        double(isstable(feedback(physicalOpenLoop, 1)));

    physicalD = [stiffness, zeros(1, 2), damping, zeros(1, 2), ...
        p.m_e, zeros(1, 2)];
    physicalModel = ss(physicalA, physicalB, physicalC, physicalD);
    combinedModel = series(p.sys_num, -physicalModel);
    numericalLoop = minreal(combinedModel(:, 2), 1e-8);
    numericalMargins = allmargin(numericalLoop);
    delayNumerical(sample) = stable_minimum( ...
        numericalMargins.DelayMargin, numericalMargins.Stable, false);
end

normalizedDelayNumerical = normalize_margin(delayNumerical);
normalizedDelayPhysical = normalize_margin(delayPhysical);
normalizedGainPhysical = normalize_margin(gainPhysicalDb);
normalizedNcf = normalize_margin(ncfMargin);

theoreticalResult = theoretical;
alphaCritical = theoreticalResult.alpha_cr;

figureFour = plot_margin_figure(alpha, normalizedDelayNumerical, ...
    normalizedDelayPhysical, normalizedGainPhysical, normalizedNcf, ...
    alphaCritical, false, 'Normalized stability indicators');
figureEight = plot_margin_figure(alpha, normalizedDelayNumerical, ...
    normalizedDelayPhysical, normalizedGainPhysical, normalizedNcf, ...
    alphaCritical, true, 'NCF indicator comparison');

figureFourPath = fullfile(projectRoot, 'Results', ...
    'scripted_normalized_stability_indicators.png');
figureEightPath = fullfile(projectRoot, 'Results', ...
    'scripted_ncf_indicator_comparison.png');
if exportFigures
    export_tight_800_dpi(figureFour, figureFourPath);
    export_tight_800_dpi(figureEight, figureEightPath);
    fprintf('Figure 4 PNG: %s\n', figureFourPath);
    fprintf('Figure 8 PNG: %s\n', figureEightPath);
end

result = struct( ...
    'ConfigurationSource', configurationPath, ...
    'PhysicalDampingRatio', p.z_e, ...
    'PhysicalDampingPercent', 100 * p.z_e, ...
    'ControllerA', lastRun.ControllerA, ...
    'Alpha', alpha, ...
    'CriticalAlpha', alphaCritical, ...
    'NormalizedDelayNumerical', normalizedDelayNumerical, ...
    'NormalizedDelayPhysical', normalizedDelayPhysical, ...
    'NormalizedGainPhysical', normalizedGainPhysical, ...
    'NormalizedNcfMargin', normalizedNcf, ...
    'FigureFour', figureFour, ...
    'FigureEight', figureEight, ...
    'FigureFourPath', string(figureFourPath), ...
    'FigureEightPath', string(figureEightPath));

fprintf(['Margin figures use Controller A Kp = %.8g, Ki = %.8g, ', ...
    'zeta_e = %.4f (%.2f%%), alpha_cr = %.6f.\n'], ...
    p.controller_a.Kp, p.controller_a.Ki, p.z_e, 100 * p.z_e, ...
    alphaCritical);
end

function value = stable_minimum(candidates, stable, convertToDb)
if ~stable
    value = 0;
    return
end
candidates = candidates(isfinite(candidates) & candidates > 0);
if isempty(candidates)
    value = Inf;
else
    value = min(candidates);
    if convertToDb
        value = mag2db(value);
    end
end
end

function normalized = normalize_margin(values)
reference = values(1);
if ~isfinite(reference) || reference == 0
    error('scripted:MarginNormalization', ...
        'The nominal margin must be finite and nonzero.');
end
normalized = values / reference;
normalized(~isfinite(normalized)) = NaN;
end

function fig = plot_margin_figure(alpha, delayNumerical, delayPhysical, ...
        gainPhysical, ncfMargin, alphaCritical, includeNcf, figureName)
figWidth = 6.27;
figHeight = 3.35;
fontName = 'Times New Roman';
fontSize = 9;
lineWidth = 1.25;

fig = figure('Name', figureName, 'Units', 'inches', ...
    'Position', [1 1 figWidth figHeight], 'Color', 'w');
ax = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.105 0.14 0.865 0.82], ...
    'XDir', 'reverse', 'XLim', [0 1], 'YLim', [0 2], ...
    'XTick', 0:0.1:1, 'YTick', 0:0.2:2, ...
    'TickLabelInterpreter', 'latex', 'FontName', fontName, ...
    'FontSize', fontSize, 'GridColor', [0.7 0.7 0.7], ...
    'GridLineStyle', '--', 'GridAlpha', 1, 'LineWidth', 0.5, ...
    'Box', 'on', 'Layer', 'bottom');
grid(ax, 'on');
hold(ax, 'on');

hDelayNumerical = plot(ax, alpha, delayNumerical, '-', ...
    'Color', '#555555', 'LineWidth', lineWidth);
hDelayPhysical = plot(ax, alpha, delayPhysical, '-', ...
    'Color', '#0c558e', 'LineWidth', lineWidth);
hGainPhysical = plot(ax, alpha, gainPhysical, '-', ...
    'Color', '#a5347b', 'LineWidth', lineWidth);
legendHandles = [hDelayNumerical, hDelayPhysical, hGainPhysical];
legendLabels = {'${\tau_{cr,N}}$', '${\tau_{cr,P}}$', '${GM_P}$'};
if includeNcf
    hNcf = plot(ax, alpha, ncfMargin, '-', ...
        'Color', '#318C12', 'LineWidth', lineWidth);
    legendHandles(end + 1) = hNcf;
    legendLabels{end + 1} = '${b_g}$';
end

xlabel(ax, '$\alpha$', 'Interpreter', 'latex', 'FontSize', fontSize);
ylabel(ax, ...
    'Normalized Stability Indicator ($SI_{\alpha}/SI_{\alpha=1}$)', ...
    'Interpreter', 'latex', 'FontSize', fontSize);
lgd = legend(ax, legendHandles, legendLabels, ...
    'Interpreter', 'latex', 'FontName', fontName, ...
    'FontSize', fontSize, 'Location', 'northeast');
try
    lgd.ItemTokenSize = [18 15];
catch
end

xline(ax, alphaCritical, '--', 'Color', 'k', ...
    'LineWidth', 1.25, 'HandleVisibility', 'off');
annotationX = min(alphaCritical + 0.018, 0.98);
text(ax, annotationX, 1.08, ...
    sprintf('Instability at $\\alpha = %.3f$', alphaCritical), ...
    'Rotation', 90, 'Color', 'k', 'FontName', fontName, ...
    'FontSize', fontSize, 'Interpreter', 'latex');
hold(ax, 'off');
end

function export_tight_800_dpi(fig, outputPath)
drawnow;
figureWidth = fig.Position(3);
exportgraphics(fig, outputPath, 'Resolution', 800, ...
    'Units', 'inches', 'Width', figureWidth, 'Padding', 0, ...
    'PreserveAspectRatio', 'on');
end

function controller = controller_from_record(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end
