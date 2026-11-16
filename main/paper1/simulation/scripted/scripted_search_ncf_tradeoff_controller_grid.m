function trials = scripted_search_ncf_tradeoff_controller_grid
%SCRIPTED_SEARCH_NCF_TRADEOFF_CONTROLLER_GRID Search PI NCF curve shapes.
%   This inexpensive first stage tunes both controller roles independently
%   and logs their full NCF-versus-alpha curves before any phase-lead or
%   nonlinear time-history search is attempted.

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir)
outputDir = fullfile(projectRoot, 'Results', ...
    'ncf_performance_tradeoff_search');
if ~isfolder(outputDir)
    mkdir(outputDir)
end

[lastRun, snapshotPath] = scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    error('scripted:TradeoffNeedsSnapshot', ...
        'Run scripted_main successfully before starting the search.')
end
options = lastRun.Options;
options.plot_on = 'n';
options.num_add = 0;
options.enable_indicator_plot = 0;
options.test_name = 'None';
p = scripted_build_trial(options, projectRoot, 1);

alpha = 1:-0.01:0;
bandwidthValues = 20:5:100;
phaseMarginValues = 45:5:80;
[bandwidthGrid, phaseMarginGrid] = ndgrid( ...
    bandwidthValues, phaseMarginValues);
candidateCount = numel(bandwidthGrid);

candidateID = (1:candidateCount).';
targetBandwidth = bandwidthGrid(:);
targetPhaseMargin = phaseMarginGrid(:);
kp = nan(candidateCount, 1);
ki = nan(candidateCount, 1);
actualBandwidth = nan(candidateCount, 1);
actualPhaseMargin = nan(candidateCount, 1);
ncfAlpha1 = nan(candidateCount, 1);
ncfAlphaPointOne = nan(candidateCount, 1);
ncfAlphaZero = nan(candidateCount, 1);
rawNCFAlphaZero = nan(candidateCount, 1);
collapseAlpha = nan(candidateCount, 1);
maximumIncrease = nan(candidateCount, 1);
monotonicDecrease = false(candidateCount, 1);
dampingCurrentLead = nan(candidateCount, 1);
spectralRadiusCurrentLead = nan(candidateCount, 1);
stableCurrentLead = false(candidateCount, 1);
curves = repmat(struct('Alpha', [], 'RawNCF', [], ...
    'PlottedNCF', [], 'Stable', []), candidateCount, 1);

innerPlant = scripted_inner_open_loop( ...
    p.m_e, p.c_e, p.alpha_start * p.k_e);
trackingPlant = feedback(innerPlant, 1);
for index = 1:candidateCount
    fprintf('NCF controller %d/%d: BW %.3g, PM %.3g\n', ...
        index, candidateCount, targetBandwidth(index), ...
        targetPhaseMargin(index))
    controller = pidtune(trackingPlant, 'PI', targetBandwidth(index), ...
        pidtuneOptions('PhaseMargin', targetPhaseMargin(index)));
    kp(index) = controller.Kp;
    ki(index) = controller.Ki;
    [actualBandwidth(index), actualPhaseMargin(index)] = ...
        controllerCharacteristics(trackingPlant, controller);
    curve = scripted_ncf_curve_metrics(p, controller, alpha);
    ncfAlpha1(index) = curve.NCFAlpha1;
    ncfAlphaPointOne(index) = curve.NCFAlphaPointOne;
    ncfAlphaZero(index) = curve.NCFAlphaZero;
    rawNCFAlphaZero(index) = curve.RawNCFAlphaZero;
    collapseAlpha(index) = curve.CollapseAlpha;
    maximumIncrease(index) = curve.MaximumIncreaseWithDegradation;
    monotonicDecrease(index) = curve.MonotonicDecrease;
    pCandidate = p;
    pCandidate.controller_b = controller;
    pCandidate.pi_b_kp = controller.Kp;
    pCandidate.pi_b_ki = controller.Ki;
    damping = scripted_phase_lead_metrics( ...
        pCandidate, 'B', pCandidate.alpha_start);
    dampingCurrentLead(index) = damping.DampingPercent;
    spectralRadiusCurrentLead(index) = damping.SpectralRadius;
    stableCurrentLead(index) = damping.Stable;
    curves(index).Alpha = curve.Alpha;
    curves(index).RawNCF = curve.RawNCF;
    curves(index).PlottedNCF = curve.PlottedNCF;
    curves(index).Stable = curve.Stable;
end

aCurveMatch = monotonicDecrease & collapseAlpha >= 0.15 & ...
    collapseAlpha <= 0.30 & ncfAlpha1 > 0.1;
bCurveMatch = monotonicDecrease & ncfAlphaPointOne > 0 & ...
    (isnan(collapseAlpha) | collapseAlpha <= 0.10);
trials = table(candidateID, targetBandwidth, targetPhaseMargin, kp, ki, ...
    actualBandwidth, actualPhaseMargin, ncfAlpha1, ncfAlphaPointOne, ...
    ncfAlphaZero, rawNCFAlphaZero, collapseAlpha, maximumIncrease, ...
    monotonicDecrease, dampingCurrentLead, spectralRadiusCurrentLead, ...
    stableCurrentLead, aCurveMatch, bCurveMatch, ...
    'VariableNames', {'CandidateID', 'TargetBandwidth_rad_s', ...
    'TargetPhaseMargin_deg', 'Kp', 'Ki', 'Bandwidth_rad_s', ...
    'PhaseMargin_deg', 'NCFAlpha1', 'NCFAlphaPointOne', ...
    'NCFAlphaZero', 'RawNCFAlphaZero', 'CollapseAlpha', ...
    'MaximumIncreaseWithDegradation', 'MonotonicDecrease', ...
    'DampingCurrentLead_pct', 'SpectralRadiusCurrentLead', ...
    'StableCurrentLead', ...
    'ACurveMatch', 'BCurveMatch'});
writetable(trials, fullfile(outputDir, 'controller_grid.csv'))
save(fullfile(outputDir, 'controller_curves.mat'), 'trials', 'curves', ...
    'alpha', 'snapshotPath')

fprintf('\nA-curve matches: %d; B-curve matches: %d\n', ...
    sum(aCurveMatch), sum(bCurveMatch))
end

function [bandwidth, phaseMargin] = ...
        controllerCharacteristics(trackingPlant, controller)
margins = allmargin(controller * trackingPlant);
frequencies = margins.PMFrequency(:);
phaseMargins = margins.PhaseMargin(:);
valid = isfinite(frequencies) & frequencies > 0 & isfinite(phaseMargins);
if any(valid)
    frequencies = frequencies(valid);
    phaseMargins = phaseMargins(valid);
    [bandwidth, selected] = min(frequencies);
    phaseMargin = phaseMargins(selected);
else
    bandwidth = NaN;
    phaseMargin = NaN;
end
end
