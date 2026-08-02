%% Fresh four-file force-displacement hysteresis plot
% Click a legend entry to show or hide its corresponding curve.

projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
dataFolder = fullfile(projectFolder, 'saved_results', 'tests', ...
    'successful nonLin tests');
fileNames = {
    'beautiful.mat'
    'beautiful2.mat'
    'beautiful3.mat'
    'beautiful4.mat'};
lineColors = {
    [0 0 0]
    [0 124 168] / 255
    [144 21 0] / 255
    [57 191 94] / 255};

figureHandle = figure('Color', 'w', ...
    'Name', 'Fresh Beautiful Hysteresis Plot');
axesHandle = axes('Parent', figureHandle);
hold(axesHandle, 'on')

lineHandles = gobjects(numel(fileNames), 1);
for fileNumber = 1:numel(fileNames)
    savedData = load(fullfile(dataFolder, fileNames{fileNumber}));
    result = savedData.result;
    displacement = result.dm(:);
    force = result.fm(:);
    sampleCount = min(numel(displacement), numel(force));

    lineHandles(fileNumber) = plot(axesHandle, ...
        displacement(1:sampleCount), force(1:sampleCount), ...
        'Color', lineColors{fileNumber}, 'LineWidth', 1.2, ...
        'DisplayName', fileNames{fileNumber}(1:end-4));
end

grid(axesHandle, 'on')
box(axesHandle, 'on')
xlabel(axesHandle, 'Measured displacement, dm (mm)')
ylabel(axesHandle, 'Measured force, fm (N)')
title(axesHandle, 'Force-Displacement Hysteresis')
legendHandle = legend(axesHandle, lineHandles, 'Location', 'best', ...
    'Interpreter', 'none');
legendHandle.ItemHitFcn = @toggleLegendCurve;
hold(axesHandle, 'off')

function toggleLegendCurve(~, event)
    event.Peer.Visible = ternaryVisibility(event.Peer.Visible);
end

function visibility = ternaryVisibility(currentVisibility)
    if strcmp(currentVisibility, 'on')
        visibility = 'off';
    else
        visibility = 'on';
    end
end
