%% 7k transfer-function PID P/I NCF colormap
% Sweeps P on the horizontal axis and I on the vertical axis for the
% tf_sp1_7000 H_dc_dm model. D and N are held at the saved 7k PID values.

clear; clc

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);

tfFile = fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat');
data = load(tfFile);

pidValues = data.pid_values;
plant = data.H_dc_dm;
pidValues = fillMissingPidFields(pidValues, plant);
plant = matchPlantSampleTime(plant, pidValues.dt);

frequencyLimitHz = [0.1 80];
if isfield(data, 'model_metadata') ...
        && isfield(data.model_metadata, 'fit_config') ...
        && isfield(data.model_metadata.fit_config, 'f_lim')
    frequencyLimitHz = data.model_metadata.fit_config.f_lim;
end

frequencyHz = logspace(log10(frequencyLimitHz(1)), ...
    log10(frequencyLimitHz(2)), 3000).';

pScale = linspace(0.05, 4.0, 121);
iScale = linspace(0.05, 4.0, 121);
pAxis = pidValues.P*pScale;
iAxis = pidValues.I*iScale;

[plantResponse, pResponse, iResponse, dResponse] = ...
    loopBasisResponses(plant, pidValues, frequencyHz);

ncfMap = nan(numel(iAxis), numel(pAxis));
bindingHz = nan(size(ncfMap));

for iIndex = 1:numel(iAxis)
    for pIndex = 1:numel(pAxis)
        controllerResponse = pAxis(pIndex)*pResponse ...
            + iAxis(iIndex)*iResponse ...
            + pidValues.D*dResponse;
        loopResponse = controllerResponse.*plantResponse;
        [ncfMap(iIndex, pIndex), bindingHz(iIndex, pIndex)] = ...
            ncfOfLoopResponse(loopResponse, frequencyHz);
    end
end

nominalLoop = (pidValues.P*pResponse + pidValues.I*iResponse ...
    + pidValues.D*dResponse).*plantResponse;
[nominalNcf, nominalBindingHz] = ncfOfLoopResponse(nominalLoop, ...
    frequencyHz);

[bestNcf, bestLinearIndex] = max(ncfMap(:));
[bestIIndex, bestPIndex] = ind2sub(size(ncfMap), bestLinearIndex);

authorityFactor = linspace(min([pScale iScale]), max([pScale iScale]), 250);
authorityP = pidValues.P*authorityFactor;
authorityI = pidValues.I*authorityFactor;
authorityNcf = nan(size(authorityFactor));
for factorIndex = 1:numel(authorityFactor)
    loopResponse = authorityFactor(factorIndex)*nominalLoop;
    authorityNcf(factorIndex) = ncfOfLoopResponse(loopResponse, ...
        frequencyHz);
end

fig = figure('Color', 'w', 'Name', '7k PID P/I NCF colormap', ...
    'NumberTitle', 'off', 'Position', [120 80 1050 760]);
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

mapAx = nexttile(layout, 1);
imagesc(mapAx, pAxis, iAxis, ncfMap)
set(mapAx, 'YDir', 'normal')
hold(mapAx, 'on')
levels = [0.20 0.25 0.30 0.35 0.40 0.45 0.50];
contour(mapAx, pAxis, iAxis, ncfMap, levels, 'k', ...
    'ShowText', 'on', 'LineWidth', 0.8)
plot(mapAx, pidValues.P, pidValues.I, 'wo', 'MarkerSize', 8, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'saved 7k PID')
plot(mapAx, pAxis(bestPIndex), iAxis(bestIIndex), 'wp', ...
    'MarkerSize', 12, 'MarkerFaceColor', [0.2235 0.7490 0.3686], ...
    'DisplayName', 'best NCF in grid')
plot(mapAx, authorityP, authorityI, 'w--', 'LineWidth', 1.7, ...
    'DisplayName', 'authority P/I projection')
hold(mapAx, 'off')
grid(mapAx, 'on')
xlabel(mapAx, 'P gain')
ylabel(mapAx, 'I gain')
title(mapAx, sprintf(['7k H_{dc,dm}: NCF margin over P/I gains ' ...
    '(D = %.4g, N = %.4g)'], pidValues.D, ...
    pidValues.derivative_filter_N))
legend(mapAx, 'Location', 'northeast')
cb = colorbar(mapAx);
cb.Label.String = 'NCF margin';
applyNcfColormap(fig)

curveAx = nexttile(layout, 2);
plot(curveAx, authorityFactor, authorityNcf, '-', 'LineWidth', 2, ...
    'Color', [0.6745 0.3922 0.1255])
hold(curveAx, 'on')
yline(curveAx, nominalNcf, 'k--', 'nominal NCF', ...
    'HandleVisibility', 'off')
xline(curveAx, 1, 'k:', 'saved PID', 'HandleVisibility', 'off')
hold(curveAx, 'off')
grid(curveAx, 'on')
xlabel(curveAx, 'authority factor multiplying the saved PID')
ylabel(curveAx, 'NCF margin')
title(curveAx, sprintf(['Authority path: nominal NCF %.4g at %.3g Hz; ' ...
    'best grid NCF %.4g at P %.4g, I %.4g'], nominalNcf, ...
    nominalBindingHz, bestNcf, pAxis(bestPIndex), iAxis(bestIIndex)))

exportPath = fullfile(scriptFolder, 'tf7k_pid_pi_ncf_colormap.png');
exportgraphics(fig, exportPath, 'Resolution', 200)

fprintf('\n7k PID P/I NCF colormap\n')
fprintf('TF file: %s\n', tfFile)
fprintf('Frequency band: %.4g to %.4g Hz\n', frequencyLimitHz)
fprintf('Saved PID: P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', ...
    pidValues.P, pidValues.I, pidValues.D, ...
    pidValues.derivative_filter_N)
fprintf('Saved PID NCF = %.6g at %.6g Hz\n', nominalNcf, ...
    nominalBindingHz)
fprintf('Best grid NCF = %.6g at P = %.6g, I = %.6g, binding %.6g Hz\n', ...
    bestNcf, pAxis(bestPIndex), iAxis(bestIIndex), ...
    bindingHz(bestIIndex, bestPIndex))
fprintf('Saved figure: %s\n\n', exportPath)

function pidValues = fillMissingPidFields(pidValues, plant)
if ~isfield(pidValues, 'dt') || isempty(pidValues.dt)
    pidValues.dt = get(plant, 'Ts');
    if pidValues.dt == 0
        pidValues.dt = 1/2048;
    end
end
if ~isfield(pidValues, 'derivative_filter_N') ...
        || isempty(pidValues.derivative_filter_N)
    pidValues.derivative_filter_N = 512;
end
end

function plant = matchPlantSampleTime(plant, sampleTime)
if get(plant, 'Ts') == 0
    plant = c2d(plant, sampleTime, 'zoh');
elseif abs(get(plant, 'Ts') - sampleTime) > 10*eps(sampleTime)
    plant = d2d(plant, sampleTime, 'zoh');
end
end

function [plantResponse, pResponse, iResponse, dResponse] = ...
    loopBasisResponses(plant, pidValues, frequencyHz)
tfilt = 1/pidValues.derivative_filter_N;
sampleTime = pidValues.dt;
controllers = {
    pid(1, 0, 0, tfilt, sampleTime, ...
        'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler')
    pid(0, 1, 0, tfilt, sampleTime, ...
        'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler')
    pid(0, 0, 1, tfilt, sampleTime, ...
        'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler')};

omega = 2*pi*frequencyHz;
plantResponse = squeeze(freqresp(plant, omega)).';
pResponse = squeeze(freqresp(controllers{1}, omega)).';
iResponse = squeeze(freqresp(controllers{2}, omega)).';
dResponse = squeeze(freqresp(controllers{3}, omega)).';
end

function [ncfMargin, bindingFrequencyHz] = ncfOfLoopResponse( ...
    loopResponse, frequencyHz)
normalizedDistance = abs(1 + loopResponse) ...
    ./sqrt(2*(1 + abs(loopResponse).^2));
[ncfMargin, index] = min(normalizedDistance);
bindingFrequencyHz = frequencyHz(index);
end

function applyNcfColormap(fig)
if exist('turbo', 'file') == 2 || exist('turbo', 'builtin') == 5
    colormap(fig, turbo(256))
else
    colormap(fig, parula(256))
end
end
