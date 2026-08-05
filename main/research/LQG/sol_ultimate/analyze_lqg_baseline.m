function result = analyze_lqg_baseline
%ANALYZE_LQG_BASELINE Audit a realizable nominal-observer LQG baseline.

studyFolder = fileparts(mfilename('fullpath'));
lqgFolder = fileparts(studyFolder);
modelsData = load(fullfile(lqgFolder, 'results', ...
    'lqr_state_space_models.mat'), 'result');
designData = load(fullfile(lqgFolder, 'results', ...
    'lqr_baseline_design.mat'), 'result');
models = modelsData.result;
design = designData.result;

scale = models.frequency_scale_rad_per_second;
nominal = physicalModel(models.system_7k, scale);
plants = [nominal, physicalModel(models.system_5k, scale)];
plantNames = {'7k', '5k'};
K = design.K;
nbar = design.nbar;

% Only the ratio of input-channel process noise to measurement noise
% affects the steady Kalman gain. Sweep it rather than assuming a noise
% covariance that the current baseline never identifies.
qOverR = logspace(-8, 12, 161).';
plantCount = numel(plants);
sweepCount = numel(qOverR);
stable = false(sweepCount, plantCount);
spectralAbscissa = nan(sweepCount, plantCount);
finalValue = nan(sweepCount, plantCount);
peakValue = nan(sweepCount, plantCount);
settlingTime = nan(sweepCount, plantCount);
peakCommand = nan(sweepCount, plantCount);
noiseToCommandH2 = nan(sweepCount, plantCount);
noiseToOutputH2 = nan(sweepCount, plantCount);
kalmanGain = nan(sweepCount, size(nominal.A, 1));
time = linspace(0, 0.5, 5001).';

for j = 1:sweepCount
    L = lqe(nominal.A, nominal.B, nominal.C, qOverR(j), 1);
    kalmanGain(j, :) = L.';
    for i = 1:plantCount
        loops = observerLoop(plants(i), nominal, K, nbar, L);
        poles = eig(loops.reference.A);
        spectralAbscissa(j, i) = max(real(poles));
        stable(j, i) = all(real(poles) < 0);
        if ~stable(j, i)
            continue
        end
        y = step(loops.reference, time);
        u = step(loops.command, time);
        finalValue(j, i) = dcgain(loops.reference);
        peakValue(j, i) = max(y);
        peakCommand(j, i) = max(abs(u));
        tolerance = 0.02 * max(abs(finalValue(j, i)), eps);
        lastOutside = find(abs(y - finalValue(j, i)) > tolerance, ...
            1, 'last');
        if isempty(lastOutside)
            settlingTime(j, i) = 0;
        elseif lastOutside < numel(time)
            settlingTime(j, i) = time(lastOutside + 1);
        else
            settlingTime(j, i) = Inf;
        end
        noiseToCommandH2(j, i) = norm(loops.noiseToCommand, 2);
        noiseToOutputH2(j, i) = norm(loops.noiseToOutput, 2);
    end
end

trackingError5k = abs(finalValue(:, 2) - 1);
finiteCandidates = stable(:, 2) & isfinite(trackingError5k) & ...
    isfinite(noiseToCommandH2(:, 2));
candidateIndices = find(finiteCandidates);
[~, localBest] = min(trackingError5k(finiteCandidates));
bestTrackingIndex = candidateIndices(localBest);

result = struct;
result.provenance = struct( ...
    'models', fullfile(lqgFolder, 'results', ...
        'lqr_state_space_models.mat'), ...
    'design', fullfile(lqgFolder, 'results', ...
        'lqr_baseline_design.mat'), ...
    'interpretation', ['The saved controller is full-state LQR. This ' ...
        'audit adds a nominal 7k Kalman observer and applies the resulting ' ...
        'dynamic output-feedback controller to both measured plant fits.']);
result.plant_names = plantNames;
result.q_over_r = qOverR;
result.kalman_gain = kalmanGain;
result.stable = stable;
result.spectral_abscissa = spectralAbscissa;
result.final_value = finalValue;
result.peak_value = peakValue;
result.settling_time_s = settlingTime;
result.peak_command = peakCommand;
result.noise_to_command_h2 = noiseToCommandH2;
result.noise_to_output_h2 = noiseToOutputH2;
result.best_5k_tracking_index = bestTrackingIndex;
result.best_5k_tracking = table(qOverR(bestTrackingIndex), ...
    finalValue(bestTrackingIndex, 1), finalValue(bestTrackingIndex, 2), ...
    peakCommand(bestTrackingIndex, 1), ...
    peakCommand(bestTrackingIndex, 2), ...
    noiseToCommandH2(bestTrackingIndex, 1), ...
    noiseToCommandH2(bestTrackingIndex, 2), ...
    'VariableNames', {'QOverR', 'Final7k', 'Final5k', ...
        'PeakCommand7k', 'PeakCommand5k', 'NoiseCommandH2_7k', ...
        'NoiseCommandH2_5k'});
result.saved_full_state_lqr = table( ...
    [design.metrics_7k.final_value; design.metrics_5k.final_value], ...
    [design.metrics_7k.overshoot_percent; ...
    design.metrics_5k.overshoot_percent], ...
    [design.metrics_7k.settling_time_s; ...
    design.metrics_5k.settling_time_s], ...
    [design.metrics_7k.peak_command; design.metrics_5k.peak_command], ...
    'VariableNames', {'FinalValue', 'OvershootPercent', ...
        'SettlingTimeSeconds', 'PeakCommand'}, ...
    'RowNames', plantNames);
requiredNbar = nan(plantCount, 1);
for i = 1:plantCount
    requiredNbar(i) = -1/(plants(i).C * ...
        ((plants(i).A - plants(i).B*K) \ plants(i).B));
end
result.required_precompensator = table(requiredNbar, ...
    'VariableNames', {'RequiredNbar'}, 'RowNames', plantNames);
interpolationCoordinate = linspace(0, 1, 201).';
interpolationSpectralAbscissa = nan(size(interpolationCoordinate));
for i = 1:numel(interpolationCoordinate)
    rho = interpolationCoordinate(i);
    A = (1-rho)*plants(1).A + rho*plants(2).A;
    B = (1-rho)*plants(1).B + rho*plants(2).B;
    interpolationSpectralAbscissa(i) = max(real(eig(A - B*K)));
end
result.full_state_affine_interpolation = table( ...
    interpolationCoordinate, interpolationSpectralAbscissa);

save(fullfile(studyFolder, 'baseline_lqg_audit.mat'), 'result')
disp(result.best_5k_tracking)
fprintf('Stable 5k observer loops: %d/%d\n', sum(stable(:, 2)), sweepCount)
fprintf('5k LQG final-value range: [%.6g, %.6g]\n', ...
    min(finalValue(stable(:, 2), 2)), max(finalValue(stable(:, 2), 2)))
end

function model = physicalModel(source, scale)
model = struct('A', scale*source.A, 'B', scale*source.B, ...
    'C', source.C, 'D', source.D);
end

function loops = observerLoop(plant, nominal, K, nbar, L)
plantStates = size(plant.A, 1);
observerStates = size(nominal.A, 1);
A = [plant.A, -plant.B*K; ...
    L*plant.C, nominal.A - nominal.B*K - L*nominal.C];
Br = [plant.B*nbar; nominal.B*nbar];
Bv = [zeros(plantStates, 1); L];
Cy = [plant.C, zeros(1, observerStates)];
Cu = [zeros(1, plantStates), -K];
loops = struct( ...
    'reference', ss(A, Br, Cy, 0), ...
    'command', ss(A, Br, Cu, nbar), ...
    'noiseToOutput', ss(A, Bv, Cy, 0), ...
    'noiseToCommand', ss(A, Bv, Cu, 0));
end
