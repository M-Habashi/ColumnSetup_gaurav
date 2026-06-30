%% Compare Saved Transfer Functions
% Compare two or three saved exp_tf files or saved phase_lead files.
% Units: frequencies are Hz in plots and rad/s inside transfer functions.

clear; clc

projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if isempty(projectFolder), projectFolder = pwd; end
addpath(fullfile(projectFolder, 'control_and_HS', 'b_system_id', ...
    'id_utils'))

comparisonType = selectComparisonType();
modelCount = selectModelCount();
[data, files, names] = loadComparisonFiles(projectFolder, comparisonType, ...
    modelCount);

switch comparisonType
    case 'exp_tf'
        models = cell(1, modelCount);
        for k = 1:modelCount
            models{k} = expTfModel(data{k}, names{k});
        end
        titleText = 'PID + H_{dc,dm} comparison';
        createExpTfFigure(models, titleText)
    case 'phase_lead'
        models = cell(1, modelCount);
        for k = 1:modelCount
            models{k} = phaseLeadModel(data{k}, names{k});
        end
        titleText = 'phase_lead comparison';
        createPhaseLeadFigure(models, titleText)
end

for k = 1:modelCount
    fprintf('Loaded %s\n', files{k})
end

function [data, files, names] = loadComparisonFiles(projectFolder, ...
        comparisonType, modelCount)
data = cell(1, modelCount);
files = cell(1, modelCount);
names = cell(1, modelCount);
for k = 1:modelCount
    fprintf('\nSelect transfer function %d of %d.\n', k, modelCount)
    [data{k}, files{k}, names{k}] = load_saved_result_file( ...
        projectFolder, comparisonType, true, '', false);
end
end

function modelCount = selectModelCount()
modelCount = input('\nHow many transfer functions to compare [2 or 3]: ');
if ~ismember(modelCount, [2 3])
    error('compare:InvalidModelCount', ...
        'Select 2 or 3 transfer functions to compare.')
end
end

function comparisonType = selectComparisonType()
fprintf('\nCompare saved transfer functions:\n')
fprintf('  [1] saved_results\\exp_tf\n')
fprintf('  [2] saved_results\\phase_lead\n')
selection = input('\nSelect file type to compare: ');
if selection == 1
    comparisonType = 'exp_tf';
elseif selection == 2
    comparisonType = 'phase_lead';
else
    error('compare:InvalidSelection', ...
        'Select 1 for exp_tf or 2 for phase_lead.')
end
end

function model = expTfModel(data, fileName)
if ~isfield(data, 'H_dc_dm')
    error('compare:MissingHdcDm', ...
        '%s does not contain H_dc_dm.', fileName)
end

model.name = fileName;
model.plant = data.H_dc_dm;
if isfield(data, 'pid_values')
    model.pid = data.pid_values;
else
    model.pid = struct('P', 0.15, 'I', 20, 'D', 0.0015, ...
        'derivative_filter_N', 512);
end
if ~isfield(model.pid, 'dt') || isempty(model.pid.dt)
    model.pid.dt = getSampleTime(model.plant);
end
if ~isfield(model.pid, 'derivative_filter_N') ...
        || isempty(model.pid.derivative_filter_N)
    model.pid.derivative_filter_N = 512;
end
model.marginLoop = buildPidHdcDmLoop(model.plant, model.pid);
model.system = feedback(model.marginLoop, 1);
model.frequencyLimitHz = [0.1 80];
if isfield(data, 'model_metadata') ...
        && isfield(data.model_metadata, 'fit_config') ...
        && isfield(data.model_metadata.fit_config, 'f_lim')
    model.frequencyLimitHz = data.model_metadata.fit_config.f_lim;
end
end

function model = phaseLeadModel(data, fileName)
if ~isfield(data, 'phase_lead_tf')
    error('compare:MissingPhaseLeadTf', ...
        '%s does not contain phase_lead_tf.', fileName)
end

model.name = fileName;
model.system = data.phase_lead_tf;
model.marginLoop = model.system;
if isfield(data, 'phase_lead')
    model.phaseLead = normalizePhaseLead(data.phase_lead);
else
    model.phaseLead = phaseLeadFromTransferFunction(model.system);
end
model.frequencyLimitHz = [0.1 80];
end

function createExpTfFigure(models, titleText)
[frequencyHz, response] = frequencyResponses(models);
fig = figure('Color', 'w', 'Name', titleText, ...
    'Position', [100 100 1000 780]);
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact');

magAx = nexttile(layout, 1);
hold(magAx, 'on')
grid(magAx, 'on')
ylabel(magAx, 'Magnitude (dB)')
title(magAx, titleText)

phaseAx = nexttile(layout, 2);
hold(phaseAx, 'on')
grid(phaseAx, 'on')
xlabel(phaseAx, 'Frequency (Hz)')
ylabel(phaseAx, 'Phase (deg)')

colors = modelColors(numel(models));
lineHandles = cell(numel(models), 2);
for k = 1:numel(models)
    lineHandles{k, 1} = semilogx(magAx, frequencyHz, ...
        magnitudeDb(response{k}), 'LineWidth', 1.7, ...
        'Color', colors{k}, 'DisplayName', models{k}.name);
    lineHandles{k, 2} = semilogx(phaseAx, frequencyHz, ...
        unwrap(angle(response{k}))*180/pi, 'LineWidth', 1.7, ...
        'Color', colors{k}, 'DisplayName', models{k}.name);
end
legend(magAx, 'Location', 'best', 'Interpreter', 'none')
legend(phaseAx, 'Location', 'best', 'Interpreter', 'none')

controlPanel = nexttile(layout, 3);
axis(controlPanel, 'off')
createPidControls(fig, controlPanel, models, lineHandles, frequencyHz)
end

function createPhaseLeadFigure(models, titleText)
[frequencyHz, response] = frequencyResponses(models);
fig = figure('Color', 'w', 'Name', titleText, ...
    'Position', [100 100 1000 780]);
layout = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact');

magAx = nexttile(layout, 1);
hold(magAx, 'on')
grid(magAx, 'on')
ylabel(magAx, 'Magnitude (dB)')
title(magAx, titleText)

phaseAx = nexttile(layout, 2);
hold(phaseAx, 'on')
grid(phaseAx, 'on')
xlabel(phaseAx, 'Frequency (Hz)')
ylabel(phaseAx, 'Phase (deg)')

colors = modelColors(numel(models));
lineHandles = cell(numel(models), 2);
for k = 1:numel(models)
    lineHandles{k, 1} = semilogx(magAx, frequencyHz, ...
        magnitudeDb(response{k}), 'LineWidth', 1.7, ...
        'Color', colors{k}, 'DisplayName', models{k}.name);
    lineHandles{k, 2} = semilogx(phaseAx, frequencyHz, ...
        unwrap(angle(response{k}))*180/pi, 'LineWidth', 1.7, ...
        'Color', colors{k}, 'DisplayName', models{k}.name);
end
legend(magAx, 'Location', 'best', 'Interpreter', 'none')
legend(phaseAx, 'Location', 'best', 'Interpreter', 'none')

controlPanel = nexttile(layout, 3);
axis(controlPanel, 'off')
createPhaseLeadControls(fig, controlPanel, models, lineHandles, frequencyHz)
end

function createPidControls(fig, ax, models, lineHandles, frequencyHz)
panelPosition = getpixelposition(ax, true);
delete(ax)
labels = {'P', 'I', 'D'};
fields = {'P', 'I', 'D'};
modelCount = numel(models);
editBoxes = cell(modelCount, 3);
marginText = cell(modelCount, 1);

for k = 1:modelCount
    y = panelPosition(2) + panelPosition(4) - 35 - (k - 1)*75;
    uicontrol(fig, 'Style', 'text', 'String', models{k}.name, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [panelPosition(1), y + 30, panelPosition(3), 20]);
    for j = 1:3
        x = panelPosition(1) + (j - 1)*135;
        uicontrol(fig, 'Style', 'text', 'String', labels{j}, ...
            'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
            'Position', [x, y + 5, 20, 20]);
        editBoxes{k, j} = uicontrol(fig, 'Style', 'edit', ...
            'String', sprintf('%.6g', models{k}.pid.(fields{j})), ...
            'Position', [x + 25, y, 90, 26], ...
            'Callback', @(~, ~) updatePlot());
    end
    marginText{k} = createMarginText(fig, panelPosition, y);
    updateMarginText(marginText{k}, models{k})
end

    function updatePlot()
        for modelId = 1:modelCount
            pidValues = models{modelId}.pid;
            for fieldId = 1:3
                value = str2double(get(editBoxes{modelId, fieldId}, ...
                    'String'));
                if ~isfinite(value)
                    set(editBoxes{modelId, fieldId}, 'String', ...
                        sprintf('%.6g', ...
                        models{modelId}.pid.(fields{fieldId})))
                    return
                end
                pidValues.(fields{fieldId}) = value;
            end
            models{modelId}.pid = pidValues;
            models{modelId}.marginLoop = buildPidHdcDmLoop( ...
                models{modelId}.plant, pidValues);
            models{modelId}.system = feedback(models{modelId}.marginLoop, 1);
            response = squeeze(freqresp(models{modelId}.system, ...
                2*pi*frequencyHz));
            set(lineHandles{modelId, 1}, 'YData', magnitudeDb(response))
            set(lineHandles{modelId, 2}, 'YData', ...
                unwrap(angle(response))*180/pi)
            updateMarginText(marginText{modelId}, models{modelId})
        end
        drawnow
    end
end

function createPhaseLeadControls(fig, ax, models, lineHandles, frequencyHz)
panelPosition = getpixelposition(ax, true);
delete(ax)
labels = {'Gain', 'Zeros rad/s', 'Poles rad/s'};
fields = {'gain', 'zero_rad_s', 'pole_rad_s'};
modelCount = numel(models);
editBoxes = cell(modelCount, 3);
marginText = cell(modelCount, 1);

for k = 1:modelCount
    y = panelPosition(2) + panelPosition(4) - 35 - (k - 1)*75;
    uicontrol(fig, 'Style', 'text', 'String', models{k}.name, ...
        'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
        'Position', [panelPosition(1), y + 30, panelPosition(3), 20]);
    for j = 1:3
        x = panelPosition(1) + (j - 1)*170;
        uicontrol(fig, 'Style', 'text', 'String', labels{j}, ...
            'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
            'Position', [x, y + 5, 80, 20]);
        editBoxes{k, j} = uicontrol(fig, 'Style', 'edit', ...
            'String', mat2str(models{k}.phaseLead.(fields{j}), 6), ...
            'Position', [x + 85, y, 75, 26], ...
            'Callback', @(~, ~) updatePlot());
    end
    marginText{k} = createMarginText(fig, panelPosition, y);
    updateMarginText(marginText{k}, models{k})
end

    function updatePlot()
        for modelId = 1:modelCount
            phaseLead = models{modelId}.phaseLead;
            for fieldId = 1:3
                value = parseNumericVector(get(editBoxes{modelId, ...
                    fieldId}, 'String'));
                if isempty(value) || any(~isfinite(value))
                    set(editBoxes{modelId, fieldId}, 'String', ...
                        mat2str(models{modelId}.phaseLead.( ...
                        fields{fieldId}), 6))
                    return
                end
                phaseLead.(fields{fieldId}) = value(:).';
            end
            models{modelId}.phaseLead = phaseLead;
            models{modelId}.system = phaseLeadTransferFunction(phaseLead);
            models{modelId}.marginLoop = models{modelId}.system;
            response = squeeze(freqresp(models{modelId}.system, ...
                2*pi*frequencyHz));
            set(lineHandles{modelId, 1}, 'YData', magnitudeDb(response))
            set(lineHandles{modelId, 2}, 'YData', ...
                unwrap(angle(response))*180/pi)
            updateMarginText(marginText{modelId}, models{modelId})
        end
        drawnow
    end
end

function [frequencyHz, response] = frequencyResponses(models)
frequencyLimitHz = [inf -inf];
for k = 1:numel(models)
    frequencyLimitHz(1) = min(frequencyLimitHz(1), ...
        models{k}.frequencyLimitHz(1));
    frequencyLimitHz(2) = max(frequencyLimitHz(2), ...
        models{k}.frequencyLimitHz(2));
end
frequencyHz = logspace(log10(frequencyLimitHz(1)), ...
    log10(frequencyLimitHz(2)), 900);

response = cell(size(models));
for k = 1:numel(models)
    response{k} = squeeze(freqresp(models{k}.system, 2*pi*frequencyHz));
end
end

function openLoop = buildPidHdcDmLoop(plant, pidValues)
sampleTime = pidValues.dt;
if get(plant, 'Ts') == 0
    plant = c2d(plant, sampleTime, 'zoh');
elseif abs(get(plant, 'Ts') - sampleTime) > 10*eps(sampleTime)
    plant = d2d(plant, sampleTime, 'zoh');
end
controller = pid(pidValues.P, pidValues.I, pidValues.D, ...
    1/pidValues.derivative_filter_N, sampleTime, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
openLoop = controller*plant;
end

function sampleTime = getSampleTime(system)
sampleTime = get(system, 'Ts');
if sampleTime == 0
    sampleTime = 1/2048;
end
end

function phaseLead = normalizePhaseLead(phaseLead)
if ~isfield(phaseLead, 'gain') || isempty(phaseLead.gain)
    phaseLead.gain = 1;
end
if ~isfield(phaseLead, 'zero_rad_s') || isempty(phaseLead.zero_rad_s)
    phaseLead.zero_rad_s = 1;
end
if ~isfield(phaseLead, 'pole_rad_s') || isempty(phaseLead.pole_rad_s)
    phaseLead.pole_rad_s = 1;
end
phaseLead.gain = phaseLead.gain(1);
phaseLead.zero_rad_s = phaseLead.zero_rad_s(:).';
phaseLead.pole_rad_s = phaseLead.pole_rad_s(:).';
end

function phaseLead = phaseLeadFromTransferFunction(system)
[zeroValues, poleValues, gainValue] = zpkdata(system, 'v');
phaseLead = struct( ...
    'gain', gainValue, ...
    'zero_rad_s', -zeroValues(:).', ...
    'pole_rad_s', -poleValues(:).');
end

function system = phaseLeadTransferFunction(phaseLead)
system = phaseLead.gain ...
    * tf(poly(-phaseLead.zero_rad_s), poly(-phaseLead.pole_rad_s));
end

function value = parseNumericVector(text)
text = strrep(text, '[', ' ');
text = strrep(text, ']', ' ');
text = strrep(text, ',', ' ');
text = strrep(text, ';', ' ');
value = sscanf(text, '%f').';
end

function value = magnitudeDb(response)
value = 20*log10(max(abs(response), realmin));
end

function colors = modelColors(modelCount)
palette = {
    [0 0.486 0.659]
    [0.6745 0.3922 0.1255]
    [0.2235 0.7490 0.3686]
    [0.5647 0.0824 0]
    [0.4549 0.0196 0.5412]};
colors = palette(1:modelCount);
end

function handle = createMarginText(fig, panelPosition, y)
x = panelPosition(1) + 520;
width = max(220, panelPosition(3) - 520);
handle = uicontrol(fig, 'Style', 'text', 'String', '', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [x, y - 3, width, 48]);
end

function updateMarginText(handle, model)
try
    [gmDb, pmDeg, ncfMargin] = custom_stability_margins( ...
        model.marginLoop, model.frequencyLimitHz);
    text = sprintf('GM = %s dB    PM = %s deg\nNCF = %.4g', ...
        formatMargin(gmDb), formatMargin(pmDeg), ncfMargin);
catch err
    text = sprintf('Margins unavailable: %s', err.message);
end
set(handle, 'String', text)
end

function text = formatMargin(value)
if isinf(value)
    text = 'Inf';
elseif isnan(value)
    text = 'NaN';
else
    text = sprintf('%.4g', value);
end
end
