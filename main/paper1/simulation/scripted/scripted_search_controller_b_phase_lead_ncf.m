function result = scripted_search_controller_b_phase_lead_ncf(resumeSearch)
%SCRIPTED_SEARCH_CONTROLLER_B_PHASE_LEAD_NCF Logged, resumable joint search.
%   RESULT = SCRIPTED_SEARCH_CONTROLLER_B_PHASE_LEAD_NCF() searches one
%   shared phase lead and Controller-B PI tuning while keeping Controller A
%   fixed. The exact last completed run is the baseline. Every screening
%   and full nonlinear trial is checkpointed under
%   Results/controller_b_phase_lead_ncf_search.
%
%   Acceptance requirements are:
%     * effective damping of A and B is greater than 6 percent;
%     * A J4 is no more than 33 percent;
%     * B J4 is at least 5 percentage points greater than A and no more than 40 percent;
%     * B remains slower than the previously accepted B tuning;
%     * B NCF does not increase as stiffness degrades from alpha=1 to .001;
%     * the NCF has a net decrease of at least .001;
%     * both nonlinear runs are finite and remain below 8.9 kN.

arguments
    resumeSearch (1,1) logical = true
end

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir)

outputDir = fullfile(projectRoot, 'Results', ...
    'controller_b_phase_lead_ncf_search');
if ~isfolder(outputDir)
    mkdir(outputDir)
end
statePath = fullfile(outputDir, 'search_state.mat');
lockPath = fullfile(outputDir, 'search_running.lock');
if isfile(lockPath)
    error('scripted:SearchAlreadyRunning', ...
        ['The search lock already exists: %s\nRemove it only after ', ...
        'confirming that no MATLAB search is running.'], lockPath)
end
lockFile = fopen(lockPath, 'w');
if lockFile < 0
    error('scripted:SearchLock', 'Could not create %s.', lockPath)
end
fprintf(lockFile, 'Started %s\n', char(datetime('now')));
fclose(lockFile);
lockCleanup = onCleanup(@() releaseLock(lockPath));

[lastRun, snapshotPath] = scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    error('scripted:SearchNeedsSnapshot', ...
        ['Run scripted_main successfully first. The search deliberately ', ...
        'uses the exact last-run options and controllers.'])
end
options = lastRun.Options;
options.plot_on = 'n';
options.num_add = 0;
options.enable_indicator_plot = 0;
options.test_name = 'None';
options.start_c = 'B';
options.switch_on = 0;

config = searchConfiguration(options, snapshotPath);
signature = jsonencode(config);
if resumeSearch && isfile(statePath)
    loaded = load(statePath, 'state');
    state = loaded.state;
    if state.Version ~= 1 || ...
            ~strcmp(state.ConfigurationSignature, signature)
        error('scripted:SearchResumeMismatch', ...
            ['The saved search was made with a different last-run ', ...
            'configuration. Call the function with false to start over.'])
    end
    fprintf('Resuming NCF-constrained search from %s\n', statePath)
else
    state = initialState(config, signature);
    checkpoint(state, statePath, outputDir)
end

if state.Status == "complete"
    result = state;
    fprintf('Search is already complete. Selected candidate: %g\n', ...
        state.SelectedCandidateID)
    return
end
state.Status = "running";
state.UpdatedAt = datetime('now');
checkpoint(state, statePath, outputDir)

try
    fprintf('Building frozen last-run model from %s\n', snapshotPath)
    pBase = scripted_build_trial(options, projectRoot, 1);
    pBase = restoreControllers(pBase, lastRun);
    groundInput = cachedGroundInput(pBase);

    if isempty(state.Baseline)
        fprintf('Running exact nonlinear baseline A and B ...\n')
        baseline = evaluatePair(pBase, groundInput);
        baseline.NCFPass = ncfAudit(pBase, pBase.controller_b, config).Pass;
        state.Baseline = struct2table(baseline);
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
    end

    controllerSpecs = controllerCandidateSpecs(config);
    completedControllerIDs = completedIDs(state.ControllerTrials);
    for rowIndex = 1:height(controllerSpecs)
        candidateID = controllerSpecs.CandidateID(rowIndex);
        if ismember(candidateID, completedControllerIDs)
            continue
        end
        fprintf('Controller screen %d/%d: BW %.3g, PM %.3g\n', ...
            rowIndex, height(controllerSpecs), ...
            controllerSpecs.BWTarget_rad_s(rowIndex), ...
            controllerSpecs.PMTarget_deg(rowIndex))
        try
            row = screenController(pBase, controllerSpecs(rowIndex, :), ...
                config);
        catch exception
            row = failedControllerRow(controllerSpecs(rowIndex, :), ...
                exception);
        end
        state.ControllerTrials = [state.ControllerTrials; row];
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
    end

    leadSpecs = leadCandidateSpecs(config);
    jointSpecs = jointCandidateSpecs(state.ControllerTrials, leadSpecs);
    completedScreenIDs = completedIDs(state.ScreenTrials);
    for rowIndex = 1:height(jointSpecs)
        candidateID = jointSpecs.CandidateID(rowIndex);
        if ismember(candidateID, completedScreenIDs)
            continue
        end
        try
            row = screenJointCandidate(pBase, jointSpecs(rowIndex, :), ...
                state.ControllerTrials, config);
        catch exception
            row = failedScreenRow(jointSpecs(rowIndex, :), exception);
        end
        state.ScreenTrials = [state.ScreenTrials; row];
        if mod(rowIndex, 20) == 0 || rowIndex == height(jointSpecs)
            fprintf('Joint screen %d/%d complete\n', ...
                rowIndex, height(jointSpecs))
            state.UpdatedAt = datetime('now');
            checkpoint(state, statePath, outputDir)
        end
    end
    state.UpdatedAt = datetime('now');
    checkpoint(state, statePath, outputDir)

    ranked = rankFullCandidates(state.ScreenTrials, config);
    completedFullIDs = completedIDs(state.FullTrials);
    if isempty(state.FullTrials)
        acceptedCount = 0;
    else
        acceptedCount = sum(state.FullTrials.Accepted);
    end
    fullCount = height(state.FullTrials);
    for rankIndex = 1:height(ranked)
        if fullCount >= config.MaxFullTrials || ...
                acceptedCount >= config.StopAfterAccepted
            break
        end
        candidateID = ranked.CandidateID(rankIndex);
        if ismember(candidateID, completedFullIDs)
            continue
        end
        fprintf(['Full nonlinear trial %d/%d: candidate %d, ', ...
            'B BW %.3g, PM %.3g\n'], fullCount + 1, ...
            config.MaxFullTrials, candidateID, ...
            ranked.BWTarget_rad_s(rankIndex), ...
            ranked.PMTarget_deg(rankIndex))
        state.ActiveCandidateID = candidateID;
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
        try
            row = evaluateFullCandidate(pBase, groundInput, ...
                ranked(rankIndex, :), state.Baseline, config);
        catch exception
            row = failedFullRow(ranked(rankIndex, :), exception);
        end
        state.FullTrials = [state.FullTrials; row];
        state.ActiveCandidateID = NaN;
        state.UpdatedAt = datetime('now');
        fullCount = height(state.FullTrials);
        acceptedCount = sum(state.FullTrials.Accepted);
        checkpoint(state, statePath, outputDir)
    end

    if isempty(state.FullTrials)
        accepted = table;
    else
        accepted = state.FullTrials(state.FullTrials.Accepted, :);
    end
    if isempty(accepted)
        state.Status = "exhausted";
        state.SelectedCandidateID = NaN;
        fprintf('No candidate passed every exact acceptance gate.\n')
    else
        accepted.SelectionScore = abs(accepted.J4_B_pct - 40) + ...
            0.25 * abs(accepted.J4_A_pct - ...
            state.Baseline.J4_A_pct(1)) + accepted.LeadDistance;
        accepted = sortrows(accepted, 'SelectionScore', 'ascend');
        state.SelectedCandidateID = accepted.CandidateID(1);
        state.Status = "complete";
        fprintf('Selected candidate %d.\n', state.SelectedCandidateID)
    end
    state.UpdatedAt = datetime('now');
    checkpoint(state, statePath, outputDir)
    writeReport(state, outputDir)
catch exception
    state.Status = "error";
    state.LastError = string(getReport(exception, 'extended', ...
        'hyperlinks', 'off'));
    state.UpdatedAt = datetime('now');
    checkpoint(state, statePath, outputDir)
    rethrow(exception)
end

result = state;
end

function config = searchConfiguration(options, snapshotPath)
config = struct;
config.SnapshotPath = snapshotPath;
config.SnapshotOptions = options;
config.BandwidthB_rad_s = 48;
config.PhaseMarginB_deg = 58;
config.AlphaDescending = [1:-0.01:0.01 0.005 0.001];
config.PhysicalAlphaMinimum = 0.3;
config.NCFTolerance = 2e-5;
config.NCFMinimumNetDecrease = 0.001;
config.MinimumDamping_pct = 6;
config.ScreenDamping_pct = 6.001;
config.MaximumJ4A_pct = 33;
config.MinimumJ4Difference_pp = 5;
config.MaximumJ4B_pct = 40;
config.MaximumForce_N = 8900;
config.MaximumBandwidthB_rad_s = options.bw_b + 0.05;
config.MaxFullTrials = 12;
config.StopAfterAccepted = 3;
config.CurrentLead = [options.lead_gain options.lead_zero options.lead_pole];
config.CurrentB = [options.bw_b options.pm_b];
config.TargetLeadMultipliers = [0.81 0.85 0.9]; % gain, zero, ratio
end

function state = initialState(config, signature)
state = struct;
state.Version = 1;
state.Configuration = config;
state.ConfigurationSignature = signature;
state.CreatedAt = datetime('now');
state.UpdatedAt = state.CreatedAt;
state.Status = "pending";
state.ActiveCandidateID = NaN;
state.SelectedCandidateID = NaN;
state.LastError = "";
state.Baseline = table;
state.ControllerTrials = table;
state.ScreenTrials = table;
state.FullTrials = table;
end

function p = restoreControllers(p, lastRun)
p.controller_a = recordToController(lastRun.ControllerA);
p.controller_b = recordToController(lastRun.ControllerB);
p.controller_c = recordToController(lastRun.ControllerC);
p.pi_a_kp = p.controller_a.Kp;
p.pi_a_ki = p.controller_a.Ki;
p.pi_b_kp = p.controller_b.Kp;
p.pi_b_ki = p.controller_b.Ki;
p.pi_c_kp = p.controller_c.Kp;
p.pi_c_ki = p.controller_c.Ki;
end

function controller = recordToController(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end

function input = cachedGroundInput(p)
[input.t, input.major, input.half] = blk_ground_acceleration(p);
end

function specs = controllerCandidateSpecs(config)
[bandwidth, phaseMargin] = ndgrid(config.BandwidthB_rad_s, ...
    config.PhaseMarginB_deg);
candidateID = (1:numel(bandwidth)).';
specs = table(candidateID, bandwidth(:), phaseMargin(:), ...
    'VariableNames', {'CandidateID', 'BWTarget_rad_s', 'PMTarget_deg'});
end

function row = screenController(pBase, spec, config)
controller = tuneControllerB(pBase, spec.BWTarget_rad_s, ...
    spec.PMTarget_deg);
[bandwidth, phaseMargin, riseTime, settlingTime] = ...
    localCharacteristics(pBase, controller);
audit = ncfAudit(pBase, controller, config);
p = setControllerB(pBase, controller);
metrics = scripted_phase_lead_metrics(p, 'B', p.alpha_start);
row = table(spec.CandidateID, spec.BWTarget_rad_s, spec.PMTarget_deg, ...
    controller.Kp, controller.Ki, bandwidth, phaseMargin, riseTime, ...
    settlingTime, audit.NCFAlpha1, audit.NCFAlphaMinimum, ...
    audit.NetDecrease, audit.MaximumIncrease, audit.Pass, ...
    audit.PhysicalPass, audit.StablePhysical, metrics.DampingPercent, ...
    metrics.SpectralRadius, metrics.Stable, "", ...
    'VariableNames', controllerVariableNames);
end

function row = failedControllerRow(spec, exception)
row = table(spec.CandidateID, spec.BWTarget_rad_s, spec.PMTarget_deg, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, false, ...
    false, false, NaN, NaN, false, string(exception.message), ...
    'VariableNames', controllerVariableNames);
end

function names = controllerVariableNames
names = {'CandidateID', 'BWTarget_rad_s', 'PMTarget_deg', 'Kp', 'Ki', ...
    'Bandwidth_rad_s', 'PhaseMargin_deg', 'RiseTime_s', ...
    'SettlingTime_s', 'NCFAlpha1', 'NCFAlphaMinimum', ...
    'NCFNetDecrease', 'NCFMaximumIncrease', 'NCFPass', ...
    'NCFPhysicalPass', 'StablePhysical', 'DampingCurrentLead_pct', ...
    'SpectralRadiusCurrentLead', 'StableCurrentLead', 'Error'};
end

function controller = tuneControllerB(p, bandwidth, phaseMargin)
plant = scripted_inner_open_loop(p.m_e, p.c_e, p.alpha_start * p.k_e);
trackingPlant = feedback(plant, 1);
controller = pidtune(trackingPlant, 'PI', bandwidth, ...
    pidtuneOptions('PhaseMargin', phaseMargin));
end

function [bandwidth, phaseMargin, riseTime, settlingTime] = ...
        localCharacteristics(p, controller)
plant = scripted_inner_open_loop(p.m_e, p.c_e, p.alpha_start * p.k_e);
trackingPlant = feedback(plant, 1);
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
stepMetrics = stepinfo(feedback(controller * trackingPlant, 1));
riseTime = stepMetrics.RiseTime;
settlingTime = stepMetrics.SettlingTime;
end

function audit = ncfAudit(pBase, controller, config)
p = setControllerB(pBase, controller);
alpha = config.AlphaDescending;
ncf = zeros(size(alpha));
stable = false(size(alpha));
for index = 1:numel(alpha)
    stiffness = alpha(index) * p.k_e;
    damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
    plant = feedback(scripted_inner_open_loop(p.m_e, damping, ...
        stiffness), 1);
    stable(index) = isstable(feedback(controller * plant, 1));
    ncf(index) = blk_indicator_margin(alpha(index), 0, p) * stable(index);
end
increments = diff(ncf);
physical = alpha >= config.PhysicalAlphaMinimum;
physicalValues = ncf(physical);
audit = struct;
audit.NCFAlpha1 = ncf(1);
audit.NCFAlphaMinimum = ncf(end);
audit.NetDecrease = ncf(1) - ncf(end);
audit.MaximumIncrease = max([0 increments]);
audit.StablePhysical = all(stable(physical));
audit.PhysicalPass = all(diff(physicalValues) <= ...
    config.NCFTolerance) && audit.StablePhysical;
audit.Pass = all(increments <= config.NCFTolerance) && ...
    audit.NetDecrease >= config.NCFMinimumNetDecrease && ...
    audit.PhysicalPass;
end

function p = setControllerB(p, controller)
p.controller_b = controller;
p.pi_b_kp = controller.Kp;
p.pi_b_ki = controller.Ki;
end

function specs = leadCandidateSpecs(config)
currentGain = config.CurrentLead(1);
currentZero = config.CurrentLead(2);
currentPole = config.CurrentLead(3);
currentRatio = currentPole / currentZero;
gainValues = currentGain * (0.65:0.05:1);
zeroValues = currentZero * (0.8:0.025:0.9);
ratioValues = currentRatio * (0.85:0.05:1.15);
[zeroGrid, ratioGrid, gainGrid] = ndgrid( ...
    zeroValues, ratioValues, gainValues);
pole = zeroGrid(:) .* ratioGrid(:);
gain = gainGrid(:);
triples = [currentGain currentZero currentPole; ...
    gain zeroGrid(:) pole];
triples = unique(round(triples, 10, 'significant'), 'rows', 'stable');
leadID = (1:size(triples, 1)).';
dcGain = triples(:, 1) .* triples(:, 2) ./ triples(:, 3);
ratio = triples(:, 3) ./ triples(:, 2);
distance = sqrt(sum(log(triples ./ config.CurrentLead).^2, 2));
specs = table(leadID, triples(:, 1), triples(:, 2), triples(:, 3), ...
    dcGain, ratio, distance, 'VariableNames', {'LeadID', 'LeadGain', ...
    'LeadZero_rad_s', 'LeadPole_rad_s', 'DCGain', 'PoleZeroRatio', ...
    'LeadDistance'});
end

function specs = jointCandidateSpecs(controllerTrials, leadSpecs)
if isempty(controllerTrials)
    specs = table;
    return
end
validController = controllerTrials.NCFPass & ...
    controllerTrials.StableCurrentLead & ...
    isfinite(controllerTrials.Bandwidth_rad_s);
controllers = controllerTrials(validController, ...
    {'CandidateID', 'BWTarget_rad_s', 'PMTarget_deg'});
if isempty(controllers)
    specs = table;
    return
end
controllerRows = repelem((1:height(controllers)).', height(leadSpecs));
controllerRows = controllerRows(:);
leadRows = repmat((1:height(leadSpecs)).', height(controllers), 1);
candidateID = (1:numel(controllerRows)).';
specs = table(candidateID, ...
    controllers.CandidateID(controllerRows), leadSpecs.LeadID(leadRows), ...
    controllers.BWTarget_rad_s(controllerRows), ...
    controllers.PMTarget_deg(controllerRows), ...
    leadSpecs.LeadGain(leadRows), leadSpecs.LeadZero_rad_s(leadRows), ...
    leadSpecs.LeadPole_rad_s(leadRows), leadSpecs.DCGain(leadRows), ...
    leadSpecs.PoleZeroRatio(leadRows), leadSpecs.LeadDistance(leadRows), ...
    'VariableNames', {'CandidateID', 'ControllerCandidateID', 'LeadID', ...
    'BWTarget_rad_s', 'PMTarget_deg', 'LeadGain', 'LeadZero_rad_s', ...
    'LeadPole_rad_s', 'DCGain', 'PoleZeroRatio', 'LeadDistance'});
end

function row = screenJointCandidate(pBase, spec, controllerTrials, config)
controllerRow = controllerTrials( ...
    controllerTrials.CandidateID == spec.ControllerCandidateID, :);
controller = pid(controllerRow.Kp, controllerRow.Ki);
p = setControllerB(pBase, controller);
p = setLead(p, spec.LeadGain, spec.LeadZero_rad_s, spec.LeadPole_rad_s);
metricsA = scripted_phase_lead_metrics(p, 'A', p.alpha_start);
metricsB = scripted_phase_lead_metrics(p, 'B', p.alpha_start);
screenPass = metricsA.Stable && metricsB.Stable && ...
    metricsA.DampingPercent >= config.ScreenDamping_pct && ...
    metricsB.DampingPercent >= config.ScreenDamping_pct && ...
    controllerRow.NCFPass && controllerRow.StablePhysical && ...
    controllerRow.Bandwidth_rad_s <= config.MaximumBandwidthB_rad_s;
currentRatio = config.CurrentLead(3) / config.CurrentLead(2);
score = abs(spec.LeadGain / config.CurrentLead(1) - ...
    config.TargetLeadMultipliers(1)) + ...
    abs(spec.LeadZero_rad_s / config.CurrentLead(2) - ...
    config.TargetLeadMultipliers(2)) + ...
    abs(spec.PoleZeroRatio / currentRatio - ...
    config.TargetLeadMultipliers(3)) + ...
    0.1 * spec.LeadDistance + ...
    0.1 * max(0, 6.5 - min(metricsA.DampingPercent, ...
    metricsB.DampingPercent)) + ...
    0.01 * abs(controllerRow.Bandwidth_rad_s - ...
    min(config.BandwidthB_rad_s));
row = [spec table(controllerRow.Kp, controllerRow.Ki, ...
    controllerRow.Bandwidth_rad_s, controllerRow.PhaseMargin_deg, ...
    controllerRow.RiseTime_s, controllerRow.SettlingTime_s, ...
    controllerRow.NCFAlpha1, controllerRow.NCFAlphaMinimum, ...
    controllerRow.NCFNetDecrease, controllerRow.NCFMaximumIncrease, ...
    metricsA.DampingPercent, metricsB.DampingPercent, ...
    metricsA.SpectralRadius, metricsB.SpectralRadius, screenPass, ...
    score, "", 'VariableNames', {'KpB', 'KiB', 'BandwidthB_rad_s', ...
    'PhaseMarginB_deg', 'RiseTimeB_s', 'SettlingTimeB_s', ...
    'NCFAlpha1', 'NCFAlphaMinimum', 'NCFNetDecrease', ...
    'NCFMaximumIncrease', 'DampingA_pct', 'DampingB_pct', ...
    'SpectralRadiusA', 'SpectralRadiusB', 'ScreenPass', ...
    'ScreenScore', 'ScreenError'})];
end

function row = failedScreenRow(spec, exception)
tail = table(NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, false, Inf, string(exception.message), ...
    'VariableNames', {'KpB', 'KiB', 'BandwidthB_rad_s', ...
    'PhaseMarginB_deg', 'RiseTimeB_s', 'SettlingTimeB_s', ...
    'NCFAlpha1', 'NCFAlphaMinimum', 'NCFNetDecrease', ...
    'NCFMaximumIncrease', 'DampingA_pct', 'DampingB_pct', ...
    'SpectralRadiusA', 'SpectralRadiusB', 'ScreenPass', ...
    'ScreenScore', 'ScreenError'});
row = [spec tail];
end

function p = setLead(p, gain, zero, pole)
p.lead_gain = gain;
p.lead_zero = zero;
p.lead_pole = pole;
p.options.lead_gain = gain;
p.options.lead_zero = zero;
p.options.lead_pole = pole;
lead = ss(tf(gain * [1 zero], [1 pole]));
[p.Apred, p.Bpred, p.Cpred, p.Dpred] = c2dm(lead.A, lead.B, ...
    lead.C, lead.D, p.dt_rths, 'tustin');
end

function ranked = rankFullCandidates(screenTrials, config)
if isempty(screenTrials)
    ranked = table;
    return
end
ranked = screenTrials(screenTrials.ScreenPass & ...
    screenTrials.BandwidthB_rad_s <= config.MaximumBandwidthB_rad_s, :);
% Explore distinct leads before spending another nonlinear run on the same
% A response. This makes the expensive stage informative even when a lead
% passes the linear damping screen but misses A's nonlinear J4 gate.
% Within each lead, test the lowest feasible B bandwidth first because the
% user's separation requirement explicitly asks for the slower controller.
ranked = sortrows(ranked, {'LeadID', 'BandwidthB_rad_s', 'ScreenScore'}, ...
    {'ascend', 'ascend', 'ascend'});
[~, firstForLead] = unique(ranked.LeadID, 'stable');
primary = ranked(firstForLead, :);
primary = sortrows(primary, 'ScreenScore', 'ascend');
remaining = ranked;
remaining(firstForLead, :) = [];
remaining = sortrows(remaining, {'ScreenScore', 'BandwidthB_rad_s'}, ...
    {'ascend', 'ascend'});
ranked = [primary; remaining];
end

function row = evaluateFullCandidate(pBase, groundInput, spec, baseline, config)
controller = pid(spec.KpB, spec.KiB);
p = setControllerB(pBase, controller);
p = setLead(p, spec.LeadGain, spec.LeadZero_rad_s, spec.LeadPole_rad_s);
metricsA = runOne(p, 'A', groundInput);
runB = metricsA.Finite && metricsA.J4_pct <= config.MaximumJ4A_pct && ...
    metricsA.MaxForce_N < config.MaximumForce_N;
if runB
    metricsB = runOne(p, 'B', groundInput);
else
    metricsB = emptyRunMetrics;
end
pair = combineRunMetrics(metricsA, metricsB, p);
[~, ~, riseTimeA, settlingTimeA] = ...
    localCharacteristics(p, p.controller_a);
slower = spec.BandwidthB_rad_s <= config.MaximumBandwidthB_rad_s && ...
    spec.RiseTimeB_s > riseTimeA;
accepted = pair.FiniteA && pair.FiniteB && ...
    spec.DampingA_pct > config.MinimumDamping_pct && ...
    spec.DampingB_pct > config.MinimumDamping_pct && ...
    pair.J4_A_pct <= config.MaximumJ4A_pct && ...
    pair.J4_B_pct >= pair.J4_A_pct + config.MinimumJ4Difference_pp && ...
    pair.J4_B_pct <= config.MaximumJ4B_pct && ...
    pair.MaxForce_A_N < config.MaximumForce_N && ...
    pair.MaxForce_B_N < config.MaximumForce_N && slower;
row = [spec table(pair.FiniteA, pair.FiniteB, pair.J1_A_ms, ...
    pair.J1_B_ms, pair.J4_A_pct, pair.J4_B_pct, pair.RawJ4_A_pct, ...
    pair.RawJ4_B_pct, pair.MaxForce_A_N, pair.MaxForce_B_N, ...
    pair.MaxCommand_A_mm, pair.MaxCommand_B_mm, riseTimeA, ...
    settlingTimeA, slower, pair.J4_B_pct / pair.J4_A_pct, ...
    pair.J4_A_pct - baseline.J4_A_pct(1), ...
    pair.J4_B_pct - baseline.J4_B_pct(1), accepted, "", ...
    'VariableNames', {'FiniteA', 'FiniteB', 'J1_A_ms', 'J1_B_ms', ...
    'J4_A_pct', 'J4_B_pct', 'RawJ4_A_pct', 'RawJ4_B_pct', ...
    'MaxForce_A_N', 'MaxForce_B_N', 'MaxCommand_A_mm', ...
    'MaxCommand_B_mm', 'RiseTimeA_s', 'SettlingTimeA_s', ...
    'SlowerB', 'J4Ratio_B_over_A', 'DeltaJ4AFromBaseline_pct', ...
    'DeltaJ4BFromBaseline_pct', 'Accepted', 'FullError'})];
end

function row = failedFullRow(spec, exception)
tail = table(false, false, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, false, NaN, NaN, NaN, false, ...
    string(exception.message), 'VariableNames', {'FiniteA', 'FiniteB', ...
    'J1_A_ms', 'J1_B_ms', 'J4_A_pct', 'J4_B_pct', 'RawJ4_A_pct', ...
    'RawJ4_B_pct', 'MaxForce_A_N', 'MaxForce_B_N', ...
    'MaxCommand_A_mm', 'MaxCommand_B_mm', 'RiseTimeA_s', ...
    'SettlingTimeA_s', 'SlowerB', 'J4Ratio_B_over_A', ...
    'DeltaJ4AFromBaseline_pct', 'DeltaJ4BFromBaseline_pct', ...
    'Accepted', 'FullError'});
row = [spec tail];
end

function pair = evaluatePair(p, groundInput)
metricsA = runOne(p, 'A', groundInput);
metricsB = runOne(p, 'B', groundInput);
pair = combineRunMetrics(metricsA, metricsB, p);
end

function pair = combineRunMetrics(metricsA, metricsB, p)
pair = struct( ...
    'FiniteA', metricsA.Finite, ...
    'FiniteB', metricsB.Finite, ...
    'J1_A_ms', metricsA.J1_ms, ...
    'J1_B_ms', metricsB.J1_ms, ...
    'J4_A_pct', metricsA.J4_pct, ...
    'J4_B_pct', metricsB.J4_pct, ...
    'RawJ4_A_pct', metricsA.RawJ4_pct, ...
    'RawJ4_B_pct', metricsB.RawJ4_pct, ...
    'MaxForce_A_N', metricsA.MaxForce_N, ...
    'MaxForce_B_N', metricsB.MaxForce_N, ...
    'MaxCommand_A_mm', metricsA.MaxCommand_mm, ...
    'MaxCommand_B_mm', metricsB.MaxCommand_mm);
pair.LeadGain = p.lead_gain;
pair.LeadZero_rad_s = p.lead_zero;
pair.LeadPole_rad_s = p.lead_pole;
pair.BWTarget_rad_s = p.options.bw_b;
pair.PMTarget_deg = p.options.pm_b;
end

function metrics = emptyRunMetrics
metrics = struct('Finite', false, 'J1_ms', NaN, 'J4_pct', NaN, ...
    'RawJ4_pct', NaN, 'MaxForce_N', NaN, 'MaxCommand_mm', NaN);
end

function metrics = runOne(p, controllerName, groundInput)
p.start_c = controllerName;
p.start_a = controllerName == 'A';
p.use_c = false;
p.switch_on = false;
trial = scripted_engine(p, groundInput);
evaluation = blk_evaluation(trial, p.dt_rths);
finite = all(isfinite(evaluation)) && ...
    all(isfinite(trial.X_m.Data), 'all') && ...
    all(isfinite(trial.Force_act.Data), 'all') && ...
    all(isfinite(trial.PI_command.Data), 'all');
rawJ4 = 100 * std(trial.X_m.Data(:, 1) - trial.Ref_Resp(:, 1)) / ...
    std(trial.Ref_Resp(:, 1));
metrics = struct('Finite', finite, 'J1_ms', evaluation(1), ...
    'J4_pct', evaluation(4), 'RawJ4_pct', rawJ4, ...
    'MaxForce_N', max(abs(trial.Force_act.Data), [], 'all'), ...
    'MaxCommand_mm', 1000 * max(abs(trial.PI_command.Data), [], 'all'));
end

function checkpoint(state, statePath, outputDir)
temporaryPath = [statePath '.tmp'];
save(temporaryPath, 'state')
movefile(temporaryPath, statePath, 'f')
writeTableIfPresent(state.Baseline, fullfile(outputDir, 'baseline.csv'))
writeTableIfPresent(state.ControllerTrials, ...
    fullfile(outputDir, 'controller_trials.csv'))
writeTableIfPresent(state.ScreenTrials, ...
    fullfile(outputDir, 'screen_trials.csv'))
writeTableIfPresent(state.FullTrials, ...
    fullfile(outputDir, 'full_trials.csv'))
end

function writeTableIfPresent(value, path)
if istable(value) && ~isempty(value)
    writetable(value, path)
end
end

function writeReport(state, outputDir)
reportPath = fullfile(outputDir, 'comparison.txt');
file = fopen(reportPath, 'w');
if file < 0
    warning('scripted:SearchReport', 'Could not write %s.', reportPath)
    return
end
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'Controller-B / shared phase-lead NCF search\n');
fprintf(file, 'Status: %s\n', state.Status);
fprintf(file, 'Updated: %s\n\n', char(state.UpdatedAt));
if ~isempty(state.Baseline)
    fprintf(file, 'Baseline J4 A/B: %.4g / %.4g %%\n', ...
        state.Baseline.J4_A_pct(1), state.Baseline.J4_B_pct(1));
    fprintf(file, 'Baseline lead gain/zero/pole: %.10g / %.10g / %.10g\n', ...
        state.Baseline.LeadGain(1), state.Baseline.LeadZero_rad_s(1), ...
        state.Baseline.LeadPole_rad_s(1));
end
fprintf(file, 'Selected candidate: %g\n', state.SelectedCandidateID);
if isfinite(state.SelectedCandidateID)
    selected = state.FullTrials( ...
        state.FullTrials.CandidateID == state.SelectedCandidateID, :);
    fprintf(file, 'New B target BW/PM: %.10g / %.10g\n', ...
        selected.BWTarget_rad_s(1), selected.PMTarget_deg(1));
    fprintf(file, 'New lead gain/zero/pole: %.10g / %.10g / %.10g\n', ...
        selected.LeadGain(1), selected.LeadZero_rad_s(1), ...
        selected.LeadPole_rad_s(1));
    fprintf(file, 'New damping A/B: %.6g / %.6g %%\n', ...
        selected.DampingA_pct(1), selected.DampingB_pct(1));
    fprintf(file, 'New J4 A/B: %.6g / %.6g %%\n', ...
        selected.J4_A_pct(1), selected.J4_B_pct(1));
    fprintf(file, 'B/A J4 ratio: %.6g\n', selected.J4Ratio_B_over_A(1));
    fprintf(file, 'B NCF alpha=1 / alpha=.001: %.8g / %.8g\n', ...
        selected.NCFAlpha1(1), selected.NCFAlphaMinimum(1));
end
end

function releaseLock(lockPath)
if isfile(lockPath)
    delete(lockPath)
end
end

function ids = completedIDs(value)
if isempty(value)
    ids = zeros(0, 1);
else
    ids = value.CandidateID;
end
end
