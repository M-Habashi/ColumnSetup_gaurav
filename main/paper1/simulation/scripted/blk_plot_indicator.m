function fig = blk_plot_indicator( ...
        trial, resultPath, exportHysteresis, exportIndicator)
%BLK_PLOT_INDICATOR Plot the current result in the main indicator style.

if nargin < 3
    exportHysteresis = true;
end
if nargin < 4
    exportIndicator = true;
end

ylimX1 = [-4.9 4.9];
ylimX2 = [-7.9 7.9];
ylimX3 = [-9.9 9.9];
yTickStep = 3;
tZoom = [];
tTickStep = [];
jErrorTicks = linspace(0, 2.4, 5);
jLimitMargin = 0.10;

cGrey = '#555555';
cBlue = '#0c558e';
cPurple = '#a5347b';
cError = '#ad1005';
figWidth = 6.27;
figHeight = 5;
fontName = 'Times New Roman';
fontSize = 9;
lineWidth = 1.0;
errorAreaAlpha = 0.57;
errorEnvelopeWindow = 0.20;
hysteresisAlpha = 1.00;
caseTwoInstabilityAlpha = 0.23;
topOn = 'vrths';
% Keep about 300 vertices per printed inch.  At 6.27 in this is 1881
% points/trace: several vertices per SVG display point, while avoiding
% multi-million-vertex exports.  The decimator below retains endpoints,
% local min/max envelope points, and plateau edges used by alpha/indicator.
displayPointBudget = max(1200, round(300 * figWidth));

time = trial.t(:);
xVrths = [trial.X_m.Data(:, 1), trial.Num_resp.Data(:, 2:3)];
xRef = trial.Ref_Resp(:, 1:3);
rawErrorMm = abs(1e3 * (xVrths - xRef));
errorEnvelopeMm = peak_error_envelope(time, rawErrorMm, ...
    errorEnvelopeWindow);

fig = figure('Units', 'inches', 'Position', [1 1 figWidth figHeight], ...
    'Color', 'w', 'Name', 'Pure MATLAB v-RTHS indicator');

left = 0.12;
right = 0.9;
width = right - left;
top = 0.96;
bottom = 0.07;
gap = 0.04;
rows = 4;
height = (top - bottom - (rows - 1) * gap) / rows;

ax1 = axes('Units', 'normalized', ...
    'Position', [left, top - height, width, height]);
plot_signal_pair(ax1, time, 1e3 * xVrths(:, 1), 1e3 * xRef(:, 1), ...
    errorEnvelopeMm(:, 1), '$x_1$ (mm)', '$|J_4|$ (mm)', ...
    '$|J_4|$', ...
    cBlue, cError, topOn, lineWidth, errorAreaAlpha, ...
    jErrorTicks, jLimitMargin, displayPointBudget);

ax2 = axes('Units', 'normalized', ...
    'Position', [left, top - 2 * height - gap, width, height]);
plot_signal_pair(ax2, time, 1e3 * xVrths(:, 2), 1e3 * xRef(:, 2), ...
    errorEnvelopeMm(:, 2), '$x_2$ (mm)', '$|J_5|$ (mm)', ...
    '$|J_5|$', ...
    cBlue, cError, topOn, lineWidth, errorAreaAlpha, ...
    jErrorTicks, jLimitMargin, displayPointBudget);

ax3 = axes('Units', 'normalized', ...
    'Position', [left, top - 3 * height - 2 * gap, width, height]);
plot_signal_pair(ax3, time, 1e3 * xVrths(:, 3), 1e3 * xRef(:, 3), ...
    errorEnvelopeMm(:, 3), '$x_3$ (mm)', '$|J_6|$ (mm)', ...
    '$|J_6|$', ...
    cBlue, cError, topOn, lineWidth, errorAreaAlpha, ...
    jErrorTicks, jLimitMargin, displayPointBudget);

ax4 = axes('Units', 'normalized', ...
    'Position', [left, bottom, width, height]);
hold(ax4, 'on');

yyaxis(ax4, 'left');
[alphaPlotTime, alphaPlotData] = stop_case_three_at_instability( ...
    trial.alpha.Time(:), trial.alpha.Data(:), resultPath, ...
    caseTwoInstabilityAlpha);
[alphaTime, alphaData] = downsample_for_display( ...
    alphaPlotTime, alphaPlotData, displayPointBudget, true);
hAlpha = plot(ax4, alphaTime, alphaData, ...
    'Color', cGrey, 'LineWidth', lineWidth, 'LineStyle', '-');
ylabel(ax4, '$\alpha$', 'Interpreter', 'latex');

yyaxis(ax4, 'right');
[indicatorPlotTime, indicatorPlotData] = stop_case_three_at_instability( ...
    trial.indicator.Time(:), trial.indicator.Data(:), resultPath, ...
    caseTwoInstabilityAlpha, trial.alpha.Time(:), trial.alpha.Data(:));
[indicatorTime, indicatorData] = downsample_for_display( ...
    indicatorPlotTime, indicatorPlotData, displayPointBudget, true);
hIndicator = plot(ax4, indicatorTime, indicatorData, ...
    'Color', cPurple, 'LineWidth', lineWidth, 'LineStyle', '-');
ylabel(ax4, '$b_g$', 'Interpreter', 'latex');

ax4.YAxis(1).Limits = [-0.02 1.06];
ax4.YAxis(1).TickValues = 0:0.2:1;
ax4.YAxis(2).Limits = [-0.01 0.53];
ax4.YAxis(2).TickValues = 0:0.1:0.5;
ax4.YAxis(1).Color = hex2rgb(cGrey);
ax4.YAxis(2).Color = hex2rgb(cPurple);
xlabel(ax4, 'Time (sec)', 'Interpreter', 'latex');
grid(ax4, 'on');
legend(ax4, [hAlpha hIndicator], {'$\alpha$', '$b_g$'}, ...
    'Location', 'southeast', 'Interpreter', 'latex', 'Box', 'on', ...
    'FontName', fontName, 'FontSize', fontSize);

% Mark the first actual controller transition from A to B. The event
% signal is -1 for A -> B and +1 for B -> A.
switchAToBTime = first_switch_time(trial, -1);
if ~isempty(switchAToBTime)
    yyaxis(ax4, 'left');
    hSwitch = xline(ax4, switchAToBTime, '--', 'Color', cError, ...
        'LineWidth', lineWidth);
    legend(ax4, [hAlpha hIndicator hSwitch], ...
        {'$\alpha$', '$b_g$', '$\mathrm{Switch\ A \rightarrow B}$'}, ...
        'Location', 'southeast', 'Interpreter', 'latex', 'Box', 'on', ...
        'FontName', fontName, 'FontSize', fontSize);
end

allAxes = [ax1 ax2 ax3 ax4];
linkaxes(allAxes, 'x');

tMin = min(time);
tMax = max(time);
if isempty(tZoom)
    tStart = tMin;
    tEnd = tMax;
else
    tZoom = sort(tZoom(:).');
    tStart = max(tMin, tZoom(1));
    tEnd = min(tMax, tZoom(2));
end
xlim(ax1, [tStart tEnd]);

if isempty(tTickStep)
    span = tEnd - tStart;
    if span <= 2
        tickStep = 0.2;
    elseif span <= 5
        tickStep = 0.5;
    elseif span <= 15
        tickStep = 1;
    elseif span <= 40
        tickStep = 2;
    elseif span <= 120
        tickStep = 5;
    else
        tickStep = 10;
    end
else
    tickStep = tTickStep;
end

tickVector = tStart:tickStep:tEnd;
for ax = allAxes
    xticks(ax, tickVector);
end

apply_displacement_limits(ax1, ylimX1, yTickStep);
apply_displacement_limits(ax2, ylimX2, yTickStep);
apply_displacement_limits(ax3, ylimX3, yTickStep);

for ax = allAxes
    ax.FontName = fontName;
    ax.FontSize = fontSize;
    ax.TickLabelInterpreter = 'latex';
    ax.XTickLabelRotation = 0;
    ax.Box = 'on';
    ax.Toolbar.Visible = 'off';
end

drawnow;
[resultFolder, resultBase] = fileparts(resultPath);
if exportIndicator
    indicatorPath = fullfile(resultFolder, ...
        [resultBase '_scripted_indicator.svg']);
    exportgraphics(fig, indicatorPath, 'ContentType', 'vector', ...
        'Units', 'inches', 'Width', figWidth, 'Padding', 0, ...
        'PreserveAspectRatio', 'on');
    fprintf('Indicator figure saved to %s\n', indicatorPath);

    indicatorPngPath = fullfile(resultFolder, ...
        [resultBase '_scripted_indicator.png']);
    exportgraphics(fig, indicatorPngPath, 'Resolution', 800, ...
        'Units', 'inches', 'Width', figWidth, 'Padding', 0, ...
        'PreserveAspectRatio', 'on');

    % MATLAB's direct raster renderer can omit a vertical band in the
    % long, linear Case II record even though every plotted sample is
    % finite and continuous.  Re-rasterize the exportgraphics vector PDF
    % with Ghostscript to avoid that renderer defect at the same 800 dpi.
    if contains(lower(resultBase), 'case_02')
        export_case_two_vector_png(fig, indicatorPngPath, figWidth);
    end
    fprintf('Indicator PNG saved to %s\n', indicatorPngPath);
end

if exportHysteresis
    plot_specimen_hysteresis(trial, resultFolder, resultBase, ...
        figWidth, figHeight, left, width, fontName, fontSize, lineWidth, ...
        cBlue, hysteresisAlpha);
end
end

function plot_specimen_hysteresis(trial, resultFolder, resultBase, ...
        figWidth, figHeight, left, width, fontName, fontSize, lineWidth, ...
        traceColor, traceAlpha)
% Match the Bouc-Wen branch's standalone force-displacement figure.
if ~isfield(trial, 'block_signals') || ...
        ~isfield(trial.block_signals, 'x_internal') || ...
        ~isfield(trial, 'Restoring_force') || ...
        isempty(trial.Restoring_force)
    warning('scripted:HysteresisDataMissing', ...
        ['Skipping hysteresis figure: specimen displacement or ', ...
        'restoring-force data are unavailable.']);
    return
end

displacementMm = 1e3 * trial.block_signals.x_internal(:);
restoringForceKn = 1e-3 * trial.Restoring_force.Data(:, 1);
sampleCount = min([numel(trial.t), numel(displacementMm), ...
    numel(restoringForceKn)]);
plotTime = trial.t(1:sampleCount);
displacementMm = displacementMm(1:sampleCount);
restoringForceKn = restoringForceKn(1:sampleCount);

finiteSamples = isfinite(plotTime) & isfinite(displacementMm) & ...
    isfinite(restoringForceKn);
plotTime = plotTime(finiteSamples);
displacementMm = displacementMm(finiteSamples);
restoringForceKn = restoringForceKn(finiteSamples);
if numel(plotTime) < 2
    warning('scripted:HysteresisDataMissing', ...
        'Skipping hysteresis figure: fewer than two finite paired samples.');
    return
end

% Keep the complete 4096 Hz trajectory.  Unlike the compact time-history
% panels, the hysteresis figure must not be display-decimated.

tickCount = 5;
[xLimits, xTicks] = symmetric_zero_ticks(displacementMm, 0.05, tickCount);
[forceLimits, forceTicks] = symmetric_zero_ticks( ...
    restoringForceKn, 0.05, tickCount);

hysteresisFig = figure('Name', 'Specimen hysteresis', ...
    'Units', 'inches', 'Position', [1 1 figWidth figHeight], 'Color', 'w');
ax = axes('Parent', hysteresisFig, 'Units', 'normalized', ...
    'Position', [left, 0.14, width, 0.78]);
hold(ax, 'on');
grid(ax, 'on');
xlim(ax, xLimits);
ylim(ax, forceLimits);
xticks(ax, xTicks);
yticks(ax, forceTicks);
ax.XAxis.TickLabelFormat = '%.1f';
ax.YAxis.TickLabelFormat = '%.1f';

xlabel(ax, '$d$ (mm)', 'Interpreter', 'latex', 'FontSize', fontSize);
ylabel(ax, '$F$ (kN)', ...
    'Interpreter', 'latex', 'FontSize', fontSize);
ax.FontName = fontName;
ax.FontSize = fontSize;
ax.LabelFontSizeMultiplier = 1;
ax.TitleFontSizeMultiplier = 1;
ax.LineWidth = 0.5;
ax.TickLabelInterpreter = 'latex';
ax.Box = 'on';
ax.Toolbar.Visible = 'off';
ax.YAxis.Color = [0 0 0];
ax.GridColor = [0.75 0.75 0.75];
ax.GridAlpha = 0.35;

zeroGridColor = [0.35 0.35 0.35];
zeroGridWidth = max(1.5 * ax.LineWidth, 0.75);
plot(ax, [0 0], forceLimits, '-', 'Color', zeroGridColor, ...
    'LineWidth', zeroGridWidth, 'HandleVisibility', 'off');
plot(ax, xLimits, [0 0], '-', 'Color', zeroGridColor, ...
    'LineWidth', zeroGridWidth, 'HandleVisibility', 'off');
% Draw each cycle as an independent transparent object.  Alpha blending is
% then applied at every overlap, instead of once to the complete trajectory.
scripted_plot_hysteresis_cycles(ax, plotTime, displacementMm, ...
    restoringForceKn, traceColor, traceAlpha, lineWidth);

drawnow;
hysteresisPath = fullfile(resultFolder, ...
    [resultBase '_scripted_hysteresis.svg']);
exportgraphics(hysteresisFig, hysteresisPath, 'ContentType', 'vector', ...
    'Units', 'inches', 'Width', figWidth, 'Padding', 0, ...
    'PreserveAspectRatio', 'on');
fprintf('Hysteresis figure saved to %s\n', hysteresisPath);

hysteresisPngPath = fullfile(resultFolder, ...
    [resultBase '_scripted_hysteresis.png']);
exportgraphics(hysteresisFig, hysteresisPngPath, 'Resolution', 800, ...
    'Units', 'inches', 'Width', figWidth, 'Padding', 0, ...
    'PreserveAspectRatio', 'on');
fprintf('Hysteresis PNG saved to %s\n', hysteresisPngPath);
end

function switchTime = first_switch_time(trial, eventValue)
switchTime = [];
if ~isfield(trial, 'switch_event') || isempty(trial.switch_event) || ...
        ~isprop(trial.switch_event, 'Time') || ...
        ~isprop(trial.switch_event, 'Data')
    return
end

eventTime = trial.switch_event.Time(:);
eventData = trial.switch_event.Data(:);
eventIndex = find(eventData == eventValue, 1, 'first');
if ~isempty(eventIndex) && isfinite(eventTime(eventIndex))
    switchTime = eventTime(eventIndex);
end
end

function [plotTime, plotData] = stop_case_three_at_instability( ...
        signalTime, signalData, resultPath, instabilityAlpha, ...
        alphaTime, alphaData)
% Case III is physically meaningful only until alpha reaches its theoretical
% instability boundary.  Leave the upper response panels intact, but stop
% the alpha and indicator traces at that instant.
plotTime = signalTime(:);
plotData = signalData(:);
if ~contains(lower(string(resultPath)), 'case_03')
    return
end
if nargin < 5
    alphaTime = plotTime;
    alphaData = plotData;
else
    alphaTime = alphaTime(:);
    alphaData = alphaData(:);
end

finiteAlpha = isfinite(alphaTime) & isfinite(alphaData);
alphaTime = alphaTime(finiteAlpha);
alphaData = alphaData(finiteAlpha);
instabilityIndex = find(alphaData <= instabilityAlpha, 1, 'first');
if isempty(instabilityIndex)
    return
end

instabilityTime = alphaTime(instabilityIndex);
keep = plotTime <= instabilityTime;
plotTime = plotTime(keep);
plotData = plotData(keep);
end

function envelope = peak_error_envelope(time, rawError, windowSeconds)
% Fill across rapid zero crossings while retaining the local peak error.
sampleInterval = median(diff(time), 'omitnan');
if ~isfinite(sampleInterval) || sampleInterval <= 0
    envelope = rawError;
    return
end

windowSamples = max(1, round(windowSeconds / sampleInterval));
envelope = movmax(rawError, windowSamples, 1, 'omitnan');
end

function plot_signal_pair(ax, time, yVrths, yRef, rawError, yLabel, ...
        errorLabel, legendError, cVrths, cError, topOn, lineWidth, ...
        errorAreaAlpha, errorTicks, errorMargin, displayPointBudget)
% Match the main plot styling with lightweight line objects.
yyaxis(ax, 'left');
hold(ax, 'on');
[displayTime, displaySignals] = downsample_for_display( ...
    time, [yVrths(:), yRef(:), rawError(:)], ...
    displayPointBudget, false);
hRef = plot(ax, displayTime, displaySignals(:, 2), ...
    'Color', 'k', 'LineWidth', 1.5, ...
    'LineStyle', ':');
hVrths = plot(ax, displayTime, displaySignals(:, 1), 'Color', cVrths, ...
    'LineWidth', lineWidth, 'LineStyle', '-');

if lower(string(topOn)) == "vrths"
    uistack(hRef, 'bottom');
    uistack(hVrths, 'top');
else
    uistack(hVrths, 'bottom');
    uistack(hRef, 'top');
end

ylabel(ax, yLabel, 'Interpreter', 'latex');
grid(ax, 'on');
ax.XTickLabel = [];

yyaxis(ax, 'right');
hold(ax, 'on');
hError = area(ax, displayTime, displaySignals(:, 3), 'BaseValue', 0, ...
    'FaceColor', cError, 'FaceAlpha', errorAreaAlpha, 'EdgeColor', 'none');
ylabel(ax, errorLabel, 'Interpreter', 'latex');
configure_error_axis(ax, errorTicks, errorMargin, cError);
legend(ax, [hRef hVrths hError], ...
    {'Reference Model', 'vRTHS', legendError}, ...
    'Location', 'northeast', 'Interpreter', 'latex', 'Box', 'on', ...
    'Orientation', 'horizontal');
end

function [displayTime, displayValues] = downsample_for_display( ...
        time, values, pointBudget, preservePlateauEdges)
% DOWNSAMPLE_FOR_DISPLAY Reduce only copied plot vectors; never trial data.
% Bucket extrema preserve narrow peaks.  For the alpha/indicator panel,
% both samples around each edge of a constant plateau are mandatory so a
% transition remains at its original time.  If there are more such edges
% than the nominal budget, they take precedence over the budget.
time = time(:);
if isvector(values)
    values = values(:);
end

sampleCount = numel(time);
if sampleCount <= pointBudget
    displayTime = time;
    displayValues = values;
    return
end

keep = [1; sampleCount];
if preservePlateauEdges
    for column = 1:size(values, 2)
        signal = values(:, column);
        tolerance = 32 * eps(max(1, max(abs(signal), [], 'omitnan')));
        changed = abs(diff(signal)) > tolerance;
        % An isolated start/end of a run of changes identifies a transition
        % from or to a held value without treating smooth profiles as steps.
        edgeChange = changed & (~[false; changed(1:end-1)] | ...
            ~[changed(2:end); false]);
        transition = find(edgeChange);
        keep = [keep; transition; transition + 1]; %#ok<AGROW>
    end
end
keep = unique(keep);

remainingBudget = pointBudget - numel(keep);
if remainingBudget > 0
    % Each time bucket contributes at most min/max for every plotted trace.
    bucketCount = max(1, floor(remainingBudget / (2 * size(values, 2))));
    bucketEdges = round(linspace(1, sampleCount + 1, bucketCount + 1));
    for bucket = 1:bucketCount
        sampleRange = bucketEdges(bucket):(bucketEdges(bucket + 1) - 1);
        for column = 1:size(values, 2)
            [~, localMin] = min(values(sampleRange, column));
            [~, localMax] = max(values(sampleRange, column));
            keep = [keep; sampleRange(localMin); sampleRange(localMax)]; %#ok<AGROW>
        end
    end
end

keep = unique(keep);
displayTime = time(keep);
displayValues = values(keep, :);
end

function export_case_two_vector_png(fig, pngPath, figWidth)
resultFolder = fileparts(pngPath);
temporaryPdf = [tempname(resultFolder) '.pdf'];
cleanupPdf = onCleanup(@() delete_if_file(temporaryPdf));

exportgraphics(fig, temporaryPdf, 'ContentType', 'vector', ...
    'Units', 'inches', 'Width', figWidth, 'Padding', 0, ...
    'PreserveAspectRatio', 'on');

ghostscript = fullfile(getenv('LOCALAPPDATA'), ...
    'Ghostscript', 'bin', 'gswin64c.exe');
assert(isfile(ghostscript), 'scripted:GhostscriptNotFound', ...
    ['Ghostscript is required for the artifact-free Case II PNG: %s'], ...
    ghostscript);

command = sprintf(['"%s" -dSAFER -dBATCH -dNOPAUSE ', ...
    '-sDEVICE=png16m -r800 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 ', ...
    '"-sOutputFile=%s" "%s"'], ghostscript, pngPath, temporaryPdf);
[status, message] = system(command);
assert(status == 0, 'scripted:GhostscriptExportFailed', ...
    'Ghostscript failed to rasterize the Case II figure:\n%s', message);
clear cleanupPdf
end

function delete_if_file(path)
if isfile(path)
    delete(path);
end
end

function apply_displacement_limits(ax, limits, tickStep)
yyaxis(ax, 'left');
ylim(ax, limits);
tickValues = unique([0:tickStep:limits(2), 0:-tickStep:limits(1)]);
yticks(ax, tickValues(tickValues >= limits(1) & tickValues <= limits(2)));
end

function configure_error_axis(ax, tickValues, marginFraction, color)
yyaxis(ax, 'right');
tickValues = sort(tickValues(:).');
span = tickValues(end) - tickValues(1);
margin = max(eps, marginFraction * span);
ax.YAxis(2).TickValues = tickValues;
ax.YAxis(2).Limits = [tickValues(1) - margin, tickValues(end) + margin];
ax.YAxis(2).TickLabelFormat = '%.1f';
ax.YAxis(2).Color = hex2rgb(color);
end

function [limits, ticks] = symmetric_zero_ticks(values, marginFraction, ...
        tickCount)
values = values(isfinite(values));
halfRange = max(abs(values));
if isempty(halfRange) || halfRange <= eps
    halfRange = 1;
end
limits = (1 + marginFraction) * [-halfRange, halfRange];
ticks = linspace(-halfRange, halfRange, tickCount);
if mod(tickCount, 2) == 1
    ticks((tickCount + 1) / 2) = 0;
else
    ticks = sort([ticks, 0]);
end
end

function rgb = hex2rgb(hexString)
hexString = char(hexString);
if hexString(1) == '#'
    hexString = hexString(2:end);
end
rgb = reshape(sscanf(hexString, '%2x') / 255, 1, 3);
end
