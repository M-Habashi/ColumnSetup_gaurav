function handles = scripted_plot_hysteresis_cycles(ax, time, displacement, ...
        force, traceColor, traceAlpha, lineWidth)
%SCRIPTED_PLOT_HYSTERESIS_CYCLES Plot independently blended hysteresis cycles.
% Each positive-going zero-crossing starts a new graphics object.  Separate
% objects are essential because self-intersections within one transparent
% patch are composited only once by MATLAB's renderer.

time = time(:);
displacement = displacement(:);
force = force(:);
sampleCount = min([numel(time), numel(displacement), numel(force)]);
time = time(1:sampleCount);
displacement = displacement(1:sampleCount);
force = force(1:sampleCount);

finiteSamples = isfinite(time) & isfinite(displacement) & isfinite(force);
time = time(finiteSamples);
displacement = displacement(finiteSamples);
force = force(finiteSamples);
if numel(time) < 2
    handles = gobjects(0);
    return
end

positiveCrossings = find(displacement(1:end-1) <= 0 & ...
    displacement(2:end) > 0) + 1;

% Suppress near-zero chatter while retaining all physically meaningful
% cycles.  The 40 ms separation is comfortably below the response periods.
if ~isempty(positiveCrossings)
    keptCrossings = positiveCrossings(1);
    for crossingIndex = positiveCrossings(2:end).'
        if time(crossingIndex) - time(keptCrossings(end)) >= 0.040
            keptCrossings(end + 1, 1) = crossingIndex; %#ok<AGROW>
        end
    end
    positiveCrossings = keptCrossings;
end

segmentEdges = unique([1; positiveCrossings(:); numel(time)]);
segmentCount = max(0, numel(segmentEdges) - 1);
handles = gobjects(segmentCount, 1);
for segmentIndex = 1:segmentCount
    indices = segmentEdges(segmentIndex):segmentEdges(segmentIndex + 1);
    handles(segmentIndex) = patch(ax, ...
        'XData', [displacement(indices); NaN], ...
        'YData', [force(indices); NaN], ...
        'FaceColor', 'none', 'EdgeColor', traceColor, ...
        'EdgeAlpha', traceAlpha, 'LineStyle', '-', ...
        'LineWidth', lineWidth, 'HandleVisibility', 'off');
end
end
