function summary = visualize_saved_results(result)
%% Visualize Saved Column Setup Results
% Plots displacement tracking, measured force, measured acceleration, and
% force-displacement hysteresis from a saved result struct.

%% Units
% Input/stored: t [s], dd/dc/dm [mm], fm [N], am [g], m_hat [kg],
% c_hat [N*s/m], k_hat [N/m]. RTHS tracking evaluation uses d_n
% recomputed by stepping the numerical sub from logged fm.

summary = [];
scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);
addpath(fullfile(projectFolder, 'helpers', 'utils'))
addpath(fullfile(projectFolder, 'control_and_HS', 'd_HS', 'utils_HS'))
if nargin < 1 || isempty(result)
    [data, ~, selectedFileName] = load_saved_result_file( ...
        projectFolder, 'tests', false, '', false);
    if ~isfield(data, 'result') || ~isstruct(data.result)
        printConversionMessage(selectedFileName)
        return
    end
    result = data.result;
end
if isfield(result, 'result') && isstruct(result.result)
    result = result.result;
end
if ~isNewResultStruct(result)
    printConversionMessage(getResultName(result))
    return
end

t = result.t(:);
logged_dd = result.dd(:);
dc = result.dc(:);
dm = result.dm(:);
fm = result.fm(:);
am = result.am(:);
fs = result.fs;
dt = result.dt;
dm_filtfilt_cutoff_hz = 30;
dm_filtfilt_order = 4;
dm_filtfilt = filtfiltDm(dm, fs, dm_filtfilt_cutoff_hz, dm_filtfilt_order);
hasTseEstimate = isfield(result, 'm_hat') && isfield(result, 'c_hat') ...
    && isfield(result, 'k_hat') && ~isempty(result.m_hat);
useNumericalSub = hasNumericalSubEvaluation(result);
if useNumericalSub
    numerical_sub = recompute_numerical_sub_response(result);
else
    numerical_sub = [];
end

n = min([numel(t), numel(logged_dd), numel(dc), numel(dm), ...
    numel(fm), numel(am)]);
if useNumericalSub
    n = min([n, numel(numerical_sub.d_n_mm)]);
end
if hasTseEstimate
    n = min([n, numel(result.m_hat), numel(result.c_hat), ...
        numel(result.k_hat)]);
end
t = t(1:n);
logged_dd = logged_dd(1:n);
dc = dc(1:n);
dm = dm(1:n);
dm_filtfilt = dm_filtfilt(1:n);
fm = fm(1:n);
am = am(1:n);
adaptiveFactor = loggedAdaptiveFactor(result, n);
hasAdaptiveFactor = ~isempty(adaptiveFactor);
if hasTseEstimate
    m_hat = result.m_hat(1:n);
    c_hat = result.c_hat(1:n);
    k_hat = result.k_hat(1:n);
end

if useNumericalSub
    trackingSignal = numerical_sub.d_n_mm(1:n);
    trackingSignalName = 'd_n';
    trackingLegendName = 'd\_n (numerical sub)';
else
    trackingSignal = logged_dd;
    trackingSignalName = 'dd';
    trackingLegendName = 'dd (logged command)';
end

maxPlotPoints = 50000;
plotStep = max(1, ceil(n/maxPlotPoints));
plotIndex = 1:plotStep:n;
if plotIndex(end) ~= n
    plotIndex = [plotIndex n];
end

trackingError = trackingSignal - dm_filtfilt;
rmsError = sqrt(mean(trackingError.^2, 'omitnan'));
duration = t(end) - t(1);
test_type = getTestType(result);
resultName = getResultName(result);

summary = struct('name', resultName, 'test_type', test_type, ...
    'duration', duration, 'sample_count', n, 'fs', fs, 'dt', dt, ...
    'tracking_signal', trackingSignalName, ...
    'dm_filtfilt_cutoff_hz', dm_filtfilt_cutoff_hz, ...
    'dm_filtfilt_order', dm_filtfilt_order, ...
    'rms_tracking_error', rmsError);
if useNumericalSub
    summary.rms_d_n_dm_filtfilt = rmsError;
else
    summary.rms_dd_dm_filtfilt = rmsError;
end

fprintf('\n===============================================================\n');
fprintf('                    Saved Result Summary\n');
fprintf('===============================================================\n');
fprintf('Result:          %s\n', resultName);
fprintf('Test type:       %s\n', test_type);
fprintf('Duration:        %.3f s\n', duration);
fprintf('Sample count:    %d\n', n);
fprintf('fs:              %.6g Hz\n', fs);
fprintf('dt:              %.6g s\n', dt);
fprintf('RMS(%s - dm_filtfilt):   %.6g mm\n', trackingSignalName, rmsError);
fprintf('===============================================================\n\n');

[summary.validation_metrics, summary.stability_table] = ...
    printHsValidation(result, projectFolder);

figure('Name', resultName, 'WindowState', 'maximized');
colors = getPlotColors();
tPlot = t(plotIndex);
trackingPlot = trackingSignal(plotIndex);
dcPlot = dc(plotIndex);
dmPlot = dm(plotIndex);
dmFiltfiltPlot = dm_filtfilt(plotIndex);
fmPlot = fm(plotIndex);
amPlot = am(plotIndex);

ax(1) = subplot(3, 1, 1);
hDesired = plot(tPlot, trackingPlot, '--', 'Color', colors.black, ...
    'LineWidth', 1.8, 'DisplayName', trackingLegendName); hold on
plot(tPlot, dcPlot, '-', 'Color', colors.copperwood, 'LineWidth', 1.0, ...
    'DisplayName', 'dc');
hMeasuredRaw = plot(tPlot, dmPlot, '-', 'Color', colors.blue, ...
    'LineWidth', 1.0, 'DisplayName', 'dm');
hMeasured = plot(tPlot, dmFiltfiltPlot, '-', 'Color', colors.blue, ...
    'LineWidth', 1.4, 'DisplayName', 'dm\_filtfilt');
uistack(hDesired, 'top')
uistack(hMeasuredRaw, 'top')
uistack(hMeasured, 'top')
grid on
xlabel('Time (s)')
ylabel('Displacement (mm)')
title('Displacement Tracking')
setAxisLimitsFromSignals(gca, t, [trackingSignal dc dm dm_filtfilt])
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(2) = subplot(3, 1, 2);
plot(tPlot, fmPlot, '-', 'Color', colors.purple, 'LineWidth', 1.0, ...
    'DisplayName', 'fm');
grid on
xlabel('Time (s)')
ylabel('Force (N)')
title('Force History')
setAxisLimitsFromSignals(gca, t, fm)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

ax(3) = subplot(3, 1, 3);
plot(tPlot, amPlot, '-', 'Color', colors.green, 'LineWidth', 1.0, ...
    'DisplayName', 'am');
grid on
xlabel('Time (s)')
ylabel('Acceleration (g)')
title('Acceleration History')
setAxisLimitsFromSignals(gca, t, am)
lgd = legend('Location', 'best');
lgd.ItemHitFcn = @toggleSignalVisibility;

linkaxes(ax, 'x')

hHysteresisFigure = figure('Name', [resultName ' - Hysteresis']);
hHysteresisAxes = axes('Parent', hHysteresisFigure, ...
    'Position', [0.10 0.24 0.85 0.69]);
transitionStart = tPlot(1);
transitionEnd = tPlot(end);
transitionBlend = hysteresisTransitionBlend( ...
    tPlot, transitionStart, transitionEnd);
hHysteresis = surface(hHysteresisAxes, [dmPlot(:) dmPlot(:)], ...
    [fmPlot(:) fmPlot(:)], zeros(numel(dmPlot), 2), ...
    [transitionBlend transitionBlend], 'FaceColor', 'none', ...
    'EdgeColor', 'interp', 'LineWidth', 1.2);
colormap(hHysteresisAxes, linspace(0, 1, 256)'.*colors.purple)
caxis(hHysteresisAxes, [0 1])
grid on
xlabel('Measured displacement (mm)')
ylabel('Measured force (N)')
updateHysteresisTitle()

uicontrol(hHysteresisFigure, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.10 0.155 0.13 0.035], 'String', 'Transition start (s)', ...
    'HorizontalAlignment', 'left');
hStartSlider = uicontrol(hHysteresisFigure, 'Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.24 0.16 0.56 0.035], ...
    'Min', tPlot(1), 'Max', tPlot(end), 'Value', transitionStart, ...
    'Callback', @setTransitionStartFromSlider);
hStartEdit = uicontrol(hHysteresisFigure, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.82 0.155 0.13 0.045], ...
    'String', sprintf('%.3f', transitionStart), ...
    'Callback', @setTransitionStartFromEdit);

uicontrol(hHysteresisFigure, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.10 0.085 0.13 0.035], 'String', 'Transition end (s)', ...
    'HorizontalAlignment', 'left');
hEndSlider = uicontrol(hHysteresisFigure, 'Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.24 0.09 0.56 0.035], ...
    'Min', tPlot(1), 'Max', tPlot(end), 'Value', transitionEnd, ...
    'Callback', @setTransitionEndFromSlider);
hEndEdit = uicontrol(hHysteresisFigure, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.82 0.085 0.13 0.045], ...
    'String', sprintf('%.3f', transitionEnd), ...
    'Callback', @setTransitionEndFromEdit);

if hasAdaptiveFactor
    adaptivePlot = adaptiveFactor(plotIndex);
    factorMin = min(adaptivePlot);
    factorMax = max(adaptivePlot);
    factorControlMin = min(0, factorMin);
    factorControlMax = max(1, factorMax);
    factorTransitionStart = factorMin;
    factorTransitionEnd = factorMax;
    factorBlend = hysteresisTransitionBlend(adaptivePlot, ...
        factorTransitionStart, factorTransitionEnd);

    hFactorFigure = figure('Name', ...
        [resultName ' - Hysteresis by Adaptive Factor']);
    hFactorAxes = axes('Parent', hFactorFigure, ...
        'Position', [0.10 0.24 0.85 0.69]);
    hFactorHysteresis = surface(hFactorAxes, ...
        [dmPlot(:) dmPlot(:)], [fmPlot(:) fmPlot(:)], ...
        zeros(numel(dmPlot), 2), [factorBlend factorBlend], ...
        'FaceColor', 'none', 'EdgeColor', 'interp', 'LineWidth', 1.2);
    colormap(hFactorAxes, linspace(0, 1, 256)'.*colors.red)
    caxis(hFactorAxes, [0 1])
    grid on
    xlabel('Measured displacement (mm)')
    ylabel('Measured force (N)')
    updateFactorHysteresisTitle()

    uicontrol(hFactorFigure, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.10 0.155 0.13 0.035], ...
        'String', 'Transition start', 'HorizontalAlignment', 'left');
    hFactorStartSlider = uicontrol(hFactorFigure, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.24 0.16 0.56 0.035], ...
        'Min', factorControlMin, 'Max', factorControlMax, ...
        'Value', factorTransitionStart, ...
        'Callback', @setFactorStartFromSlider);
    hFactorStartEdit = uicontrol(hFactorFigure, 'Style', 'edit', ...
        'Units', 'normalized', 'Position', [0.82 0.155 0.13 0.045], ...
        'String', sprintf('%.3f', factorTransitionStart), ...
        'Callback', @setFactorStartFromEdit);

    uicontrol(hFactorFigure, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.10 0.085 0.13 0.035], ...
        'String', 'Transition end', 'HorizontalAlignment', 'left');
    hFactorEndSlider = uicontrol(hFactorFigure, 'Style', 'slider', ...
        'Units', 'normalized', 'Position', [0.24 0.09 0.56 0.035], ...
        'Min', factorControlMin, 'Max', factorControlMax, ...
        'Value', factorTransitionEnd, ...
        'Callback', @setFactorEndFromSlider);
    hFactorEndEdit = uicontrol(hFactorFigure, 'Style', 'edit', ...
        'Units', 'normalized', 'Position', [0.82 0.085 0.13 0.045], ...
        'String', sprintf('%.3f', factorTransitionEnd), ...
        'Callback', @setFactorEndFromEdit);
end

if hasTseEstimate
    figure('Name', [resultName ' - Online TSE'], 'WindowState', 'maximized');
    mHatPlot = m_hat(plotIndex);
    cHatPlot = c_hat(plotIndex);
    kHatPlot = k_hat(plotIndex);

    ax_tse(1) = subplot(3, 1, 1);
    plot(tPlot, kHatPlot, 'Color', colors.blue, 'LineWidth', 1.0, ...
        'DisplayName', 'k hat');
    grid on
    ylabel('k (N/m)')
    title('Online TSE Stiffness')

    ax_tse(2) = subplot(3, 1, 2);
    plot(tPlot, mHatPlot, 'Color', colors.purple, 'LineWidth', 1.0, ...
        'DisplayName', 'm hat');
    grid on
    ylabel('m (kg)')
    title('Online TSE Mass')

    ax_tse(3) = subplot(3, 1, 3);
    plot(tPlot, cHatPlot, 'Color', colors.copperwood, 'LineWidth', 1.0, ...
        'DisplayName', 'c hat');
    grid on
    xlabel('Time (s)')
    ylabel('c (N s/m)')
    title('Online TSE Damping')
    linkaxes(ax_tse, 'x')
end

    function setTransitionStartFromSlider(~, ~)
        transitionStart = min(hStartSlider.Value, transitionEnd);
        updateHysteresisControls()
    end

    function setTransitionEndFromSlider(~, ~)
        transitionEnd = max(hEndSlider.Value, transitionStart);
        updateHysteresisControls()
    end

    function setTransitionStartFromEdit(~, ~)
        value = str2double(hStartEdit.String);
        if isfinite(value)
            transitionStart = min(max(value, tPlot(1)), transitionEnd);
        end
        updateHysteresisControls()
    end

    function setTransitionEndFromEdit(~, ~)
        value = str2double(hEndEdit.String);
        if isfinite(value)
            transitionEnd = max(min(value, tPlot(end)), transitionStart);
        end
        updateHysteresisControls()
    end

    function updateHysteresisControls()
        hStartSlider.Value = transitionStart;
        hEndSlider.Value = transitionEnd;
        hStartEdit.String = sprintf('%.3f', transitionStart);
        hEndEdit.String = sprintf('%.3f', transitionEnd);
        transitionBlend = hysteresisTransitionBlend( ...
            tPlot, transitionStart, transitionEnd);
        hHysteresis.CData = [transitionBlend transitionBlend];
        updateHysteresisTitle()
    end

    function updateHysteresisTitle()
        title(hHysteresisAxes, sprintf( ...
            'Force-Displacement Hysteresis (color transition: %.3f-%.3f s)', ...
            transitionStart, transitionEnd))
    end

    function setFactorStartFromSlider(~, ~)
        factorTransitionStart = min( ...
            hFactorStartSlider.Value, factorTransitionEnd);
        updateFactorHysteresisControls()
    end

    function setFactorEndFromSlider(~, ~)
        factorTransitionEnd = max( ...
            hFactorEndSlider.Value, factorTransitionStart);
        updateFactorHysteresisControls()
    end

    function setFactorStartFromEdit(~, ~)
        value = str2double(hFactorStartEdit.String);
        if isfinite(value)
            factorTransitionStart = min(max(value, factorControlMin), ...
                factorTransitionEnd);
        end
        updateFactorHysteresisControls()
    end

    function setFactorEndFromEdit(~, ~)
        value = str2double(hFactorEndEdit.String);
        if isfinite(value)
            factorTransitionEnd = max(min(value, factorControlMax), ...
                factorTransitionStart);
        end
        updateFactorHysteresisControls()
    end

    function updateFactorHysteresisControls()
        hFactorStartSlider.Value = factorTransitionStart;
        hFactorEndSlider.Value = factorTransitionEnd;
        hFactorStartEdit.String = sprintf('%.3f', factorTransitionStart);
        hFactorEndEdit.String = sprintf('%.3f', factorTransitionEnd);
        factorBlend = hysteresisTransitionBlend(adaptivePlot, ...
            factorTransitionStart, factorTransitionEnd);
        hFactorHysteresis.CData = [factorBlend factorBlend];
        updateFactorHysteresisTitle()
    end

    function updateFactorHysteresisTitle()
        title(hFactorAxes, sprintf([ ...
            'Force-Displacement Hysteresis ' ...
            '(adaptive factor transition: %.3f-%.3f)'], ...
            factorTransitionStart, factorTransitionEnd))
    end
end

function blend = hysteresisTransitionBlend(values, transitionStart, ...
        transitionEnd)
if transitionStart == transitionEnd
    blend = double(values >= transitionEnd);
else
    blend = (values - transitionStart)/(transitionEnd - transitionStart);
    blend = min(max(blend, 0), 1);
end
blend = blend(:);
end

function factor = loggedAdaptiveFactor(result, n)
factor = [];
for name = {'auth', 'osi_gain', 'auth_factor'}
    if isfield(result, name{1}) && numel(result.(name{1})) >= n
        values = result.(name{1});
        factor = values(1:n);
        factor = factor(:);
        return
    end
end
end

function [validation_table, stability_table] = printHsValidation( ...
        result, projectFolder)
validation_table = [];
stability_table = [];
if ~isfield(result, 'hs') || ~isstruct(result.hs)
    return
end
phase_lead_data = dependencyData(result, 'phase_lead', 'phase_lead_file');
exp_tf_data = dependencyData(result, 'exp_tf', 'exp_tf_file');
specimen_data = dependencyData(result, 'specimen', '');
earthquake_data = dependencyData(result, 'earthquake', '');
if isfield(result.hs, 'fem')
    fem_data = result.hs.fem;
else
    fem_data = dependencyData(result, 'fem', '');
end
if isempty(phase_lead_data) || isempty(exp_tf_data) ...
        || isempty(specimen_data) || isempty(fem_data) ...
        || isempty(earthquake_data)
    fprintf(['HS validation skipped: this result does not contain every ' ...
        'embedded validation dependency.\n'])
    return
end
helpers = optimize_vHS_phase_lead_v2('helpers');
config = helpers.default_config();
config.earthquake_type = result.hs.earthquake_type;
config.intensity_factor = result.hs.intensity_factor;
config.time_scale_factor = result.hs.time_scale_factor;
config.force_sign = result.hs.force_sign;
config.sample_dt = result.dt;
config.h_dc_dm_model_data = exp_tf_data;
config.fem_data = fem_data;
config.specimen_data = specimen_data;
config.earthquake_data = earthquake_data;
if isfield(result, 'pid_values')
    config.pid_gain_override = result.pid_values;
else
    config.pid_gain_override = phaseLeadPidValues(phase_lead_data);
end
phase_lead = normalizePhaseLeadConfig(phase_lead_data.phase_lead);
config.phase_lead_section_count = phase_lead.section_count;
config.save_results = false;
config = helpers.normalize_config(config);
problem = helpers.prepare(projectFolder, config, 1);

baseline = helpers.evaluate(problem, []);
baseline_data = struct('t', problem.time, ...
    'dm', baseline.signals.dm_sample, ...
    'fm', baseline.signals.force_sample, ...
    'fs', 1/problem.sample_dt, 'dt', problem.sample_dt, ...
    'hs', problem.hs);
[baseline_metrics, ~] = compare_hs_response_to_reference( ...
    problem.fem, baseline_data, [], [], [], [], struct('plot', false));
[control_metrics, ~] = compare_hs_response_to_reference( ...
    problem.fem, result, [], [], [], [], struct('plot', false));

validation_table = table(control_metrics.Properties.RowNames(:), ...
    cellstr(control_metrics.Description), cellstr(control_metrics.Unit), ...
    [NaN; NaN; NaN; baseline_metrics.Value(4:6); NaN], ...
    control_metrics.Value, 'VariableNames', {'Metric', 'Description', ...
    'Unit', 'SimulatedNumExp', 'MeasuredForceReplay'});
if phase_lead.enabled
    control_path_label = 'num*G_T*PID*H_{dc,dm}*exp';
else
    control_path_label = 'num*PID*H_{dc,dm}*exp';
end
fprintf('Control path: %s\n', control_path_label)
disp(validation_table)
printMeasuredDataMetrics(validation_table)

phase_lead_tf_discrete = c2d(phase_lead_data.phase_lead_tf, ...
    problem.sample_dt, 'tustin');
stability_table = helpers.build_stability_table(problem, ...
    phase_lead_tf_discrete, [0.1 80]);
disp('Stability table')
disp(stability_table)
end

function data = dependencyData(result, dependencyName, pathField)
data = [];
if isfield(result, 'dependencies') ...
        && isfield(result.dependencies, dependencyName)
    data = result.dependencies.(dependencyName);
    return
end
if ~isempty(pathField) && isfield(result, pathField) ...
        && isfile(result.(pathField))
    data = load(result.(pathField));
end
end

function printMeasuredDataMetrics(metrics)
fprintf('\nMeasured-data RTHS metrics (this test)\n')
fprintf('  J1 tracking delay (dm vs d_n): %.3g ms\n', ...
    metrics.MeasuredForceReplay(1))
fprintf('  J2 tracking RMS (dm vs d_n):   %.3g %%\n', ...
    metrics.MeasuredForceReplay(2))
fprintf('  J3 tracking peak (dm vs d_n):  %.3g %%\n', ...
    metrics.MeasuredForceReplay(3))
fprintf(['  J4 floor 1 (logged fm -> x1_n vs x1_r): %.3g %%\n'], ...
    metrics.MeasuredForceReplay(4))
fprintf('  J5 floor 2 (logged fm -> x2_n vs x2_r): %.3g %%\n', ...
    metrics.MeasuredForceReplay(5))
fprintf('  J6 floor 3 (logged fm -> x3_n vs x3_r): %.3g %%\n', ...
    metrics.MeasuredForceReplay(6))
fprintf('  J7 interface NMSE (dm vs d_r): %.3g %%\n\n', ...
    metrics.MeasuredForceReplay(7))
end

function pid_values = phaseLeadPidValues(phase_lead_data)
if isfield(phase_lead_data, 'pid_values')
    pid_values = phase_lead_data.pid_values;
elseif isfield(phase_lead_data, 'config') ...
        && ~isempty(phase_lead_data.config.pid_gain_override)
    pid_values = phase_lead_data.config.pid_gain_override;
else
    pid_values = [];
end
end

function colors = getPlotColors()
% Units: RGB outputs are dimensionless.
    colors.green = hexToRgb('39BF5E');
    colors.black = [0 0 0];
    colors.blue = hexToRgb('007CA8');
    colors.red = hexToRgb('901500');
    colors.purple = hexToRgb('74058A');
    colors.copperwood = hexToRgb('AC6420');
end

function rgb = hexToRgb(hexColor)
% Units: hexadecimal input and RGB output are dimensionless.
    rgb = sscanf(hexColor, '%2x%2x%2x', [1 3]) / 255;
end

function y = filtfiltDm(dm, fs, cutoff_hz, order)
% Units: dm/y [mm], fs/cutoff_hz [Hz].
    [b, a] = butter(order, cutoff_hz/(fs/2), 'low');
    y = filtfilt(b, a, dm - dm(1)) + dm(1);
end

function toggleSignalVisibility(~, event)
% Units: plotted data and axis limits pass through unchanged.
    ax = ancestor(event.Peer, 'axes');
    xLimits = xlim(ax);
    yLimits = ylim(ax);
    if strcmp(event.Peer.Visible, 'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
    xlim(ax, xLimits);
    ylim(ax, yLimits);
    set(ax, 'XLimMode', 'manual', 'YLimMode', 'manual')
end

function setAxisLimitsFromSignals(ax, time, signals)
% Units: time [s]; signals use the plotted channel units.
    finiteTime = time(isfinite(time));
    finiteSignals = signals(isfinite(signals));

    if isempty(finiteTime)
        xlim(ax, [0 1])
    else
        xMin = min(finiteTime);
        xMax = max(finiteTime);
        if xMin == xMax
            xPad = max(1, 0.05*abs(xMin));
            xlim(ax, [xMin - xPad, xMax + xPad])
        else
            xlim(ax, [xMin xMax])
        end
    end

    if isempty(finiteSignals)
        ylim(ax, [0 1])
    else
        yMin = min(finiteSignals);
        yMax = max(finiteSignals);
        yRange = yMax - yMin;
        if yRange == 0
            yPad = max(1, 0.05*abs(yMin));
        else
            yPad = 0.05*yRange;
        end
        ylim(ax, [yMin - yPad, yMax + yPad])
    end
end

function test_type = getTestType(result)
% Units: metadata input and text output are unitless.
    if isfield(result, 'test_type')
        test_type = char(string(result.test_type));
    elseif isfield(result, 'testname')
        test_type = char(string(result.testname));
    else
        test_type = 'unknown';
    end
end

function tf = isNewResultStruct(result)
% Units: metadata check is unitless.
    requiredFields = {'file', 't', 'dd', 'dc', 'dm', 'fm', 'am', 'fs', 'dt'};
    tf = isstruct(result) && all(isfield(result, requiredFields));
end

function tf = hasNumericalSubEvaluation(result)
% Units: metadata check is unitless.
    tf = isfield(result, 'hs') && isstruct(result.hs) ...
        && isfield(result.hs, 'fem') && isfield(result, 'fm');
end

function printConversionMessage(resultName)
% Units: text output is unitless.
    if nargin < 1 || isempty(resultName)
        resultName = 'selected MAT file';
    end
    fprintf('\n%s uses the old saved-result format.\n', resultName)
    fprintf('Convert saved test MAT files from the main folder with:\n')
    fprintf('  convert_saved_result_to_struct\n\n')
end

function resultName = getResultName(result)
% Units: metadata input and text output are unitless.
    if isfield(result, 'file')
        resultName = pathLeaf(result.file);
    elseif isfield(result, 'file_name')
        resultName = pathLeaf(result.file_name);
    elseif isfield(result, 'testname')
        resultName = char(string(result.testname));
    else
        resultName = getTestType(result);
    end
end

function name = pathLeaf(value)
% Units: path or label input and label output are unitless.
    value = char(string(value));
    [~, baseName, ext] = fileparts(value);
    if isempty(baseName)
        name = value;
    else
        name = [baseName ext];
    end
end
