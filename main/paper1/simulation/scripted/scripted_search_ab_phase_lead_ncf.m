function result = scripted_search_ab_phase_lead_ncf(resumeSearch)
%SCRIPTED_SEARCH_AB_PHASE_LEAD_NCF Joint A/B PI and shared-lead search.
%   RESULT = SCRIPTED_SEARCH_AB_PHASE_LEAD_NCF() reuses the established
%   controller-grid, sampled-map, and nonlinear-trial workflow. Controller
%   A must have NCF >= 0.25 at alpha=1. Both controllers and the shared
%   phase lead are retuned. In addition to the historical alpha=1 damping
%   and nonlinear-performance gates, the complete sampled loop is checked
%   over degraded alpha so an unstable high-frequency mode cannot be hidden
%   by a safe-looking local continuous-loop NCF.
%
%   The search is deterministic, checkpointed, and resumable. Outputs are
%   written under Results/ab_phase_lead_ncf_search. Call with false to
%   deliberately replace a checkpoint made from the same output folder.

arguments
    resumeSearch (1,1) logical = true
end

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir)
outputDir = fullfile(projectRoot, 'Results', ...
    'ab_phase_lead_ncf_search');
if ~isfolder(outputDir)
    mkdir(outputDir)
end
statePath = fullfile(outputDir, 'search_state.mat');
lockPath = fullfile(outputDir, 'search_running.lock');
if isfile(lockPath)
    error('scripted:ABSearchAlreadyRunning', ...
        ['The search lock already exists: %s\nRemove it only after ', ...
         'confirming that no MATLAB search is running.'], lockPath)
end
lockFile = fopen(lockPath, 'w');
if lockFile < 0
    error('scripted:ABSearchLock', 'Could not create %s.', lockPath)
end
fprintf(lockFile, 'Started %s\n', char(datetime('now')));
fclose(lockFile);
lockCleanup = onCleanup(@() releaseLock(lockPath));

[lastRun, snapshotPath] = scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    error('scripted:ABSearchNeedsSnapshot', ...
        'Run scripted_main successfully before starting the search.')
end
options = lastRun.Options;
options.plot_on = 'n';
options.num_add = 0;
options.enable_indicator_plot = 0;
options.test_name = 'None';
options.switch_on = 0;
config = searchConfiguration(options, snapshotPath);
signature = jsonencode(config);

if resumeSearch && isfile(statePath)
    loaded = load(statePath, 'state');
    state = loaded.state;
    if state.Version ~= 1 || ...
            ~strcmp(state.ConfigurationSignature, signature)
        error('scripted:ABSearchResumeMismatch', ...
            ['The checkpoint uses different options or constraints. ', ...
             'Call scripted_search_ab_phase_lead_ncf(false) to restart.'])
    end
    fprintf('Resuming joint A/B/lead search from %s\n', statePath)
else
    state = initialState(config, signature);
    checkpoint(state, statePath, outputDir)
end
if state.Status == "complete"
    result = state;
    fprintf('Search already complete. Selected candidate: %g\n', ...
        state.SelectedCandidateID)
    return
end

state.Status = "running";
state.UpdatedAt = datetime('now');
checkpoint(state, statePath, outputDir)

try
    pBase = scripted_build_trial(options, projectRoot, 1);
    pBase = restoreControllers(pBase, lastRun);
    groundInput = cachedGroundInput(pBase);

    if isempty(state.ControllerGrid)
        fprintf('Generating the reusable PI bandwidth/phase-margin grid ...\n')
        state.ControllerGrid = ...
            scripted_search_ncf_tradeoff_controller_grid;
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
    end

    if isempty(state.PairCandidates)
        state.PairCandidates = controllerPairCandidates( ...
            state.ControllerGrid, config);
        if isempty(state.PairCandidates)
            error('scripted:ABSearchNoPairs', ...
                'No A/B controller pair passed the PI screening gates.')
        end
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
    end

    leadSpecs = leadCandidateSpecs(config);
    jointSpecs = jointCandidateSpecs(state.PairCandidates, leadSpecs);
    completedScreenIDs = completedIDs(state.ScreenTrials);
    for rowIndex = 1:height(jointSpecs)
        candidateID = jointSpecs.CandidateID(rowIndex);
        if ismember(candidateID, completedScreenIDs)
            continue
        end
        try
            row = screenJointCandidate(pBase, jointSpecs(rowIndex, :), ...
                config);
        catch exception
            row = failedScreenRow(jointSpecs(rowIndex, :), exception);
        end
        state.ScreenTrials = [state.ScreenTrials; row];
        if mod(rowIndex, 20) == 0 || rowIndex == height(jointSpecs)
            fprintf('Sampled joint screen %d/%d complete\n', ...
                rowIndex, height(jointSpecs))
            state.UpdatedAt = datetime('now');
            checkpoint(state, statePath, outputDir)
        end
    end

    ranked = rankFullCandidates(state.ScreenTrials, config);
    state.FullTrials = refreshAcceptance(state.FullTrials, config);
    completedFullIDs = completedIDs(state.FullTrials);
    acceptedCount = 0;
    if ~isempty(state.FullTrials)
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
        fprintf(['Full nonlinear trial %d/%d: A %.3g/%.3g, ', ...
            'B %.3g/%.3g\n'], fullCount + 1, config.MaxFullTrials, ...
            ranked.BW_A_rad_s(rankIndex), ranked.PM_A_deg(rankIndex), ...
            ranked.BW_B_rad_s(rankIndex), ranked.PM_B_deg(rankIndex))
        state.ActiveCandidateID = candidateID;
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
        try
            row = evaluateFullCandidate(pBase, groundInput, ...
                ranked(rankIndex, :), config);
        catch exception
            row = failedFullRow(ranked(rankIndex, :), exception);
        end
        state.FullTrials = [state.FullTrials; row];
        state.ActiveCandidateID = NaN;
        fullCount = height(state.FullTrials);
        acceptedCount = sum(state.FullTrials.Accepted);
        state.UpdatedAt = datetime('now');
        checkpoint(state, statePath, outputDir)
    end

    accepted = table;
    if ~isempty(state.FullTrials)
        accepted = state.FullTrials(state.FullTrials.Accepted, :);
    end
    if isempty(accepted)
        state.Status = "exhausted";
        state.SelectedCandidateID = NaN;
        fprintf('No candidate passed every acceptance gate.\n')
    else
        accepted.SelectionScore = accepted.J4_A_pct + ...
            0.35 * accepted.J4_B_pct + ...
            15 * max(0, accepted.NCF_A_alpha1 - ...
            config.MinimumNCFAAlpha1) + accepted.ScreenScore;
        accepted = sortrows(accepted, 'SelectionScore', 'ascend');
        state.SelectedCandidateID = accepted.CandidateID(1);
        state.Status = "complete";
        fprintf('Selected candidate %d.\n', state.SelectedCandidateID)
    end
    state.UpdatedAt = datetime('now');
    checkpoint(state, statePath, outputDir)
    writeReport(state, outputDir)
    writeSelectedSettings(state, outputDir)
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
config.MinimumNCFAAlpha1 = 0.25;
config.MinimumNCFBAlpha1 = 0.25;
% The selected structural pole must remain positively damped, while the
% exact sampled map supplies the stronger all-mode stability requirement.
% Requiring 6%% from this single-pole diagnostic excluded every controller
% that remained stable at the most degraded alpha.
config.MinimumNominalDamping_pct = 0.25;
config.MaximumSampledSpectralRadius = 0.999999;
config.SampledAlpha = [1 .95 .90 .85 .80 .70 .60 .50 .40 .30 .20 .10];
returnThreshold = options.b_th;
if isfield(options, 'b_th_2')
    returnThreshold = options.b_th_2;
end
config.AActiveNCFThreshold = min(options.b_th, returnThreshold);
config.MaximumJ4A_pct = 33;
config.MaximumJ4B_pct = 40;
config.MaximumJ4Switched_pct = 40;
config.MinimumJ4Difference_pp = 5;
config.MaximumForce_N = 8900;
config.MaxAControllers = 8;
config.MaxBControllers = 20;
config.MaxFullTrials = 24;
config.StopAfterAccepted = 1;
config.CurrentLead = [options.lead_gain options.lead_zero options.lead_pole];
config.LeadZero_rad_s = [30 50 70 90 110 140];
config.LeadPoleZeroRatio = [15 25 40];
config.LeadDCGain = [0.4 0.6 0.8 1.0];
end

function state = initialState(config, signature)
state = struct('Version', 1, 'Configuration', config, ...
    'ConfigurationSignature', signature, 'CreatedAt', datetime('now'), ...
    'UpdatedAt', datetime('now'), 'Status', "pending", ...
    'ActiveCandidateID', NaN, 'SelectedCandidateID', NaN, ...
    'LastError', "", 'ControllerGrid', table, ...
    'PairCandidates', table, 'ScreenTrials', table, ...
    'FullTrials', table);
end

function pairs = controllerPairCandidates(grid, config)
finiteRows = isfinite(grid.Kp) & grid.Kp > 1e-6 & ...
    isfinite(grid.Ki) & ...
    isfinite(grid.Bandwidth_rad_s) & isfinite(grid.PhaseMargin_deg) & ...
    grid.StableCurrentLead;
a = grid(finiteRows & grid.MonotonicDecrease & ...
    grid.NCFAlpha1 >= config.MinimumNCFAAlpha1, :);
b = grid(finiteRows & ...
    grid.NCFAlpha1 >= config.MinimumNCFBAlpha1 & ...
    grid.NCFAlphaPointOne > 0, :);

% A is ranked toward high tracking bandwidth with minimum excess NCF;
% B is ranked toward low bandwidth and retained low-alpha NCF.
a.RankScore = 20 * abs(a.NCFAlpha1 - config.MinimumNCFAAlpha1) - ...
    0.02 * a.Bandwidth_rad_s - 0.01 * a.DampingCurrentLead_pct;
b.RankScore = 0.02 * b.Bandwidth_rad_s - ...
    14 * b.NCFAlphaPointOne - 0.01 * b.DampingCurrentLead_pct + ...
    0.5 * double(~b.MonotonicDecrease);
a = sortrows(a, 'RankScore', 'ascend');
b = sortrows(b, 'RankScore', 'ascend');
a = a(1:min(config.MaxAControllers, height(a)), :);
b = b(1:min(config.MaxBControllers, height(b)), :);

[aRow, bRow] = ndgrid(1:height(a), 1:height(b));
aRow = aRow(:);
bRow = bRow(:);
fasterA = a.Bandwidth_rad_s(aRow) > b.Bandwidth_rad_s(bRow);
aRow = aRow(fasterA);
bRow = bRow(fasterA);
pairID = (1:numel(aRow)).';
pairs = table(pairID, a.CandidateID(aRow), b.CandidateID(bRow), ...
    a.TargetBandwidth_rad_s(aRow), a.TargetPhaseMargin_deg(aRow), ...
    a.Kp(aRow), a.Ki(aRow), a.Bandwidth_rad_s(aRow), ...
    a.PhaseMargin_deg(aRow), a.NCFAlpha1(aRow), ...
    b.TargetBandwidth_rad_s(bRow), b.TargetPhaseMargin_deg(bRow), ...
    b.Kp(bRow), b.Ki(bRow), b.Bandwidth_rad_s(bRow), ...
    b.PhaseMargin_deg(bRow), b.NCFAlpha1(bRow), ...
    b.NCFAlphaPointOne(bRow), a.RankScore(aRow) + b.RankScore(bRow), ...
    'VariableNames', {'PairID', 'AControllerID', 'BControllerID', ...
    'BW_A_rad_s', 'PM_A_deg', 'KpA', 'KiA', 'ActualBW_A_rad_s', ...
    'ActualPM_A_deg', 'NCF_A_alpha1', 'BW_B_rad_s', 'PM_B_deg', ...
    'KpB', 'KiB', 'ActualBW_B_rad_s', 'ActualPM_B_deg', ...
    'NCF_B_alpha1', 'NCF_B_alpha_point_one', 'ControllerScore'});
end

function specs = leadCandidateSpecs(config)
[zeroGrid, ratioGrid, dcGrid] = ndgrid(config.LeadZero_rad_s, ...
    config.LeadPoleZeroRatio, config.LeadDCGain);
zero = zeroGrid(:);
ratio = ratioGrid(:);
dcGain = dcGrid(:);
pole = zero .* ratio;
gain = dcGain .* ratio;
triples = [config.CurrentLead; gain zero pole];
valid = triples(:, 1) > 0 & triples(:, 2) > 0 & ...
    triples(:, 3) > triples(:, 2) & triples(:, 3) <= 1e4;
triples = unique(round(triples(valid, :), 10, 'significant'), ...
    'rows', 'stable');
leadID = (1:size(triples, 1)).';
ratio = triples(:, 3) ./ triples(:, 2);
dcGain = triples(:, 1) ./ ratio;
distance = sqrt(sum(log(triples ./ config.CurrentLead).^2, 2));
specs = table(leadID, triples(:, 1), triples(:, 2), triples(:, 3), ...
    dcGain, ratio, distance, 'VariableNames', {'LeadID', 'LeadGain', ...
    'LeadZero_rad_s', 'LeadPole_rad_s', 'DCGain', 'PoleZeroRatio', ...
    'LeadDistance'});
end

function specs = jointCandidateSpecs(pairs, leads)
pairRows = repelem((1:height(pairs)).', height(leads));
leadRows = repmat((1:height(leads)).', height(pairs), 1);
candidateID = (1:numel(pairRows)).';
specs = [table(candidateID, 'VariableNames', {'CandidateID'}) ...
    pairs(pairRows, :) leads(leadRows, :)];
end

function row = screenJointCandidate(pBase, spec, config)
p = setControllers(pBase, spec.KpA, spec.KiA, spec.KpB, spec.KiB);
p = setLead(p, spec.LeadGain, spec.LeadZero_rad_s, spec.LeadPole_rad_s);

nominalA = cachedPhaseMetrics(p, 'A', 1);
nominalB = cachedPhaseMetrics(p, 'B', 1);
nominalPass = nominalA.Stable && nominalB.Stable && ...
    nominalA.DampingPercent >= config.MinimumNominalDamping_pct && ...
    nominalB.DampingPercent >= config.MinimumNominalDamping_pct;

worstRadiusA = 0;
worstRadiusB = 0;
worstAlphaA = NaN;
worstAlphaB = NaN;
sweepPass = nominalPass;
for alpha = config.SampledAlpha
    metricsB = cachedPhaseMetrics(p, 'B', alpha);
    if metricsB.SpectralRadius > worstRadiusB
        worstRadiusB = metricsB.SpectralRadius;
        worstAlphaB = alpha;
    end
    sweepPass = sweepPass && metricsB.Stable && ...
        metricsB.SpectralRadius <= config.MaximumSampledSpectralRadius;

    metricsA = cachedPhaseMetrics(p, 'A', alpha);
    if metricsA.NCF >= config.AActiveNCFThreshold
        if metricsA.SpectralRadius > worstRadiusA
            worstRadiusA = metricsA.SpectralRadius;
            worstAlphaA = alpha;
        end
        sweepPass = sweepPass && metricsA.Stable && ...
            metricsA.SpectralRadius <= ...
            config.MaximumSampledSpectralRadius;
    end
end

screenPass = spec.NCF_A_alpha1 >= config.MinimumNCFAAlpha1 && ...
    spec.NCF_B_alpha1 >= config.MinimumNCFBAlpha1 && sweepPass;
screenScore = spec.ControllerScore + 0.05 * spec.LeadDistance - ...
    0.2 * min(nominalA.DampingPercent, nominalB.DampingPercent) + ...
    100 * max(0, worstRadiusA - 0.9995) + ...
    100 * max(0, worstRadiusB - 0.9995);
tail = table(nominalA.DampingPercent, nominalB.DampingPercent, ...
    nominalA.SpectralRadius, nominalB.SpectralRadius, worstRadiusA, ...
    worstAlphaA, worstRadiusB, worstAlphaB, sweepPass, screenPass, ...
    screenScore, "", 'VariableNames', {'DampingA_alpha1_pct', ...
    'DampingB_alpha1_pct', 'SpectralRadiusA_alpha1', ...
    'SpectralRadiusB_alpha1', 'WorstActiveSpectralRadiusA', ...
    'WorstActiveAlphaA', 'WorstSpectralRadiusB', 'WorstAlphaB', ...
    'DegradedSweepPass', 'ScreenPass', 'ScreenScore', 'ScreenError'});
row = [spec tail];
end

function metrics = cachedPhaseMetrics(p, controllerName, alpha)
% The joint Cartesian search repeats each controller/lead/alpha result for
% every controller paired with it. Cache that exact result so the sampled
% map is assembled only once per unique combination.
persistent metricCache
if isempty(metricCache)
    metricCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
controllerName = upper(char(controllerName));
if controllerName == 'A'
    controller = p.controller_a;
else
    controller = p.controller_b;
end
key = sprintf(['%c|%.16g|%.16g|%.16g|%.16g|%.16g|%.16g|', ...
    '%.16g|%.16g'], controllerName, controller.Kp, controller.Ki, ...
    p.lead_gain, p.lead_zero, p.lead_pole, alpha, p.dt_rths, p.k_e);
if isKey(metricCache, key)
    metrics = metricCache(key);
    return
end
metrics = scripted_phase_lead_metrics(p, controllerName, alpha);
metricCache(key) = metrics;
end

function row = failedScreenRow(spec, exception)
tail = table(NaN, NaN, NaN, NaN, Inf, NaN, Inf, NaN, false, ...
    false, Inf, string(exception.message), 'VariableNames', ...
    {'DampingA_alpha1_pct', 'DampingB_alpha1_pct', ...
    'SpectralRadiusA_alpha1', 'SpectralRadiusB_alpha1', ...
    'WorstActiveSpectralRadiusA', 'WorstActiveAlphaA', ...
    'WorstSpectralRadiusB', 'WorstAlphaB', 'DegradedSweepPass', ...
    'ScreenPass', 'ScreenScore', 'ScreenError'});
row = [spec tail];
end

function ranked = rankFullCandidates(screenTrials, config)
ranked = screenTrials(screenTrials.ScreenPass, :);
if isempty(ranked)
    return
end
options = config.SnapshotOptions;
ranked.FullPriority = 3 * ranked.LeadDistance + ...
    abs(ranked.BW_A_rad_s - options.bw_a) / 20 + ...
    abs(ranked.PM_A_deg - options.pm_a) / 20 + ...
    0.25 * abs(ranked.BW_B_rad_s - options.bw_b) / 20 + ...
    0.25 * abs(ranked.PM_B_deg - options.pm_b) / 20 + ...
    0.02 * ranked.ScreenScore;
ranked = sortrows(ranked, {'FullPriority', 'ScreenScore', ...
    'LeadID', 'PairID'}, {'ascend', 'ascend', 'ascend', 'ascend'});

% Round-robin over A designs. This prevents the expensive nonlinear stage
% from spending its full budget on one aggressive A controller before the
% candidates nearest the previously validated response are exercised.
aIDs = unique(ranked.AControllerID, 'stable');
orderedRows = zeros(height(ranked), 1);
writeIndex = 0;
roundIndex = 1;
while writeIndex < height(ranked)
    added = false;
    for aID = reshape(aIDs, 1, [])
        rows = find(ranked.AControllerID == aID);
        if roundIndex <= numel(rows)
            writeIndex = writeIndex + 1;
            orderedRows(writeIndex) = rows(roundIndex);
            added = true;
        end
    end
    if ~added
        break
    end
    roundIndex = roundIndex + 1;
end
ranked = ranked(orderedRows(1:writeIndex), :);
ranked.FullPriority = [];
end

function row = evaluateFullCandidate(pBase, groundInput, spec, config)
p = setControllers(pBase, spec.KpA, spec.KiA, spec.KpB, spec.KiB);
p = setLead(p, spec.LeadGain, spec.LeadZero_rad_s, spec.LeadPole_rad_s);
metricsA = runOne(p, 'A', false, groundInput);
metricsB = runOne(p, 'B', false, groundInput);
metricsSwitched = runOne(p, 'A', true, groundInput);
[~, ~, riseTimeA, ~] = localCharacteristics(p, p.controller_a);
[~, ~, riseTimeB, ~] = localCharacteristics(p, p.controller_b);
% The PI designs are parameterized directly by closed-loop bandwidth.
% Rise time is also strongly affected by their deliberately different
% phase margins, so it is reported but is not a consistent speed ordering.
slowerB = spec.ActualBW_B_rad_s < spec.ActualBW_A_rad_s;
accepted = metricsA.Finite && metricsB.Finite && ...
    metricsSwitched.Finite && spec.DegradedSweepPass && slowerB && ...
    spec.NCF_A_alpha1 >= config.MinimumNCFAAlpha1 && ...
    metricsA.J4_pct <= config.MaximumJ4A_pct && ...
    metricsB.J4_pct >= metricsA.J4_pct + ...
        config.MinimumJ4Difference_pp && ...
    metricsB.J4_pct <= config.MaximumJ4B_pct && ...
    metricsSwitched.J4_pct <= config.MaximumJ4Switched_pct && ...
    max([metricsA.MaxForce_N metricsB.MaxForce_N ...
        metricsSwitched.MaxForce_N]) < config.MaximumForce_N;
tail = table(metricsA.Finite, metricsB.Finite, metricsSwitched.Finite, ...
    metricsA.J4_pct, metricsB.J4_pct, metricsSwitched.J4_pct, ...
    metricsA.MaxForce_N, metricsB.MaxForce_N, ...
    metricsSwitched.MaxForce_N, metricsA.MaxCommand_mm, ...
    metricsB.MaxCommand_mm, metricsSwitched.MaxCommand_mm, ...
    riseTimeA, riseTimeB, slowerB, accepted, "", ...
    'VariableNames', {'FiniteA', 'FiniteB', 'FiniteSwitched', ...
    'J4_A_pct', 'J4_B_pct', 'J4_Switched_pct', 'MaxForce_A_N', ...
    'MaxForce_B_N', 'MaxForce_Switched_N', 'MaxCommand_A_mm', ...
    'MaxCommand_B_mm', 'MaxCommand_Switched_mm', 'RiseTimeA_s', ...
    'RiseTimeB_s', 'SlowerB', 'Accepted', 'FullError'});
row = [spec tail];
end

function trials = refreshAcceptance(trials, config)
if isempty(trials)
    return
end
trials.SlowerB = trials.ActualBW_B_rad_s < trials.ActualBW_A_rad_s;
trials.Accepted = trials.FiniteA & trials.FiniteB & ...
    trials.FiniteSwitched & trials.DegradedSweepPass & trials.SlowerB & ...
    trials.NCF_A_alpha1 >= config.MinimumNCFAAlpha1 & ...
    trials.J4_A_pct <= config.MaximumJ4A_pct & ...
    trials.J4_B_pct >= trials.J4_A_pct + ...
        config.MinimumJ4Difference_pp & ...
    trials.J4_B_pct <= config.MaximumJ4B_pct & ...
    trials.J4_Switched_pct <= config.MaximumJ4Switched_pct & ...
    max([trials.MaxForce_A_N trials.MaxForce_B_N ...
        trials.MaxForce_Switched_N], [], 2) < config.MaximumForce_N;
end

function row = failedFullRow(spec, exception)
tail = table(false, false, false, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, false, false, ...
    string(exception.message), 'VariableNames', {'FiniteA', 'FiniteB', ...
    'FiniteSwitched', 'J4_A_pct', 'J4_B_pct', 'J4_Switched_pct', ...
    'MaxForce_A_N', 'MaxForce_B_N', 'MaxForce_Switched_N', ...
    'MaxCommand_A_mm', 'MaxCommand_B_mm', 'MaxCommand_Switched_mm', ...
    'RiseTimeA_s', 'RiseTimeB_s', 'SlowerB', 'Accepted', 'FullError'});
row = [spec tail];
end

function metrics = runOne(p, controllerName, switchOn, groundInput)
p.start_c = controllerName;
p.start_a = controllerName == 'A';
p.use_c = false;
p.switch_on = switchOn;
p.options.start_c = controllerName;
p.options.switch_on = double(switchOn);
trial = scripted_engine(p, groundInput);
evaluation = blk_evaluation(trial, p.dt_rths);
finite = all(isfinite(evaluation)) && ...
    all(isfinite(trial.X_m.Data), 'all') && ...
    all(isfinite(trial.Force_act.Data), 'all') && ...
    all(isfinite(trial.PI_command.Data), 'all');
metrics = struct('Finite', finite, 'J4_pct', evaluation(4), ...
    'MaxForce_N', max(abs(trial.Force_act.Data), [], 'all'), ...
    'MaxCommand_mm', 1000 * max(abs(trial.PI_command.Data), [], 'all'));
end

function p = setControllers(p, kpA, kiA, kpB, kiB)
p.controller_a = pid(kpA, kiA);
p.controller_b = pid(kpB, kiB);
p.pi_a_kp = kpA;
p.pi_a_ki = kiA;
p.pi_b_kp = kpB;
p.pi_b_ki = kiB;
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

function checkpoint(state, statePath, outputDir)
temporaryPath = [statePath '.tmp'];
save(temporaryPath, 'state')
movefile(temporaryPath, statePath, 'f')
writeTableIfPresent(state.ControllerGrid, ...
    fullfile(outputDir, 'controller_grid.csv'))
writeTableIfPresent(state.PairCandidates, ...
    fullfile(outputDir, 'controller_pairs.csv'))
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
path = fullfile(outputDir, 'comparison.txt');
file = fopen(path, 'w');
if file < 0
    warning('scripted:ABSearchReport', 'Could not write %s.', path)
    return
end
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'Joint Controller-A / Controller-B / phase-lead search\n');
fprintf(file, 'Status: %s\n', state.Status);
fprintf(file, 'Minimum A NCF at alpha=1: %.6g\n', ...
    state.Configuration.MinimumNCFAAlpha1);
fprintf(file, 'Selected candidate: %g\n', state.SelectedCandidateID);
if isfinite(state.SelectedCandidateID)
    selected = state.FullTrials(state.FullTrials.CandidateID == ...
        state.SelectedCandidateID, :);
    fprintf(file, 'A BW/PM: %.10g / %.10g\n', ...
        selected.BW_A_rad_s, selected.PM_A_deg);
    fprintf(file, 'B BW/PM: %.10g / %.10g\n', ...
        selected.BW_B_rad_s, selected.PM_B_deg);
    fprintf(file, 'A Kp/Ki: %.12g / %.12g\n', ...
        selected.KpA, selected.KiA);
    fprintf(file, 'B Kp/Ki: %.12g / %.12g\n', ...
        selected.KpB, selected.KiB);
    fprintf(file, 'Lead gain/zero/pole: %.12g / %.12g / %.12g\n', ...
        selected.LeadGain, selected.LeadZero_rad_s, ...
        selected.LeadPole_rad_s);
    fprintf(file, 'A/B NCF at alpha=1: %.8g / %.8g\n', ...
        selected.NCF_A_alpha1, selected.NCF_B_alpha1);
    fprintf(file, 'A/B/switched J4: %.6g / %.6g / %.6g %%\n', ...
        selected.J4_A_pct, selected.J4_B_pct, ...
        selected.J4_Switched_pct);
end
end

function writeSelectedSettings(state, outputDir)
if ~isfinite(state.SelectedCandidateID)
    return
end
selected = state.FullTrials(state.FullTrials.CandidateID == ...
    state.SelectedCandidateID, :);
path = fullfile(outputDir, 'selected_settings.m');
file = fopen(path, 'w');
if file < 0
    warning('scripted:ABSearchSettings', 'Could not write %s.', path)
    return
end
cleanup = onCleanup(@() fclose(file));
fprintf(file, '%% Selected by scripted_search_ab_phase_lead_ncf.\n');
fprintf(file, 'bw_a = %.16g; pm_a = %.16g;\n', ...
    selected.BW_A_rad_s, selected.PM_A_deg);
fprintf(file, 'bw_b = %.16g; pm_b = %.16g;\n', ...
    selected.BW_B_rad_s, selected.PM_B_deg);
fprintf(file, 'lead_gain = %.16g;\n', selected.LeadGain);
fprintf(file, 'lead_zero = %.16g;\n', selected.LeadZero_rad_s);
fprintf(file, 'lead_pole = %.16g;\n', selected.LeadPole_rad_s);
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
