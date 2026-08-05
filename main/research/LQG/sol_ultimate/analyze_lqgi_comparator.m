function result = analyze_lqgi_comparator
%ANALYZE_LQGI_COMPARATOR Quantify the classical integral-LQG benchmark.

studyFolder = fileparts(mfilename('fullpath'));
lqgFolder = fileparts(studyFolder);
modelsData = load(fullfile(lqgFolder, 'results', ...
    'lqr_state_space_models.mat'), 'result');
designData = load(fullfile(lqgFolder, 'results', ...
    'lqr_baseline_design.mat'), 'result');
models = modelsData.result;
design = designData.result;
dt = 1/2048;
scale = models.frequency_scale_rad_per_second;

continuous7k = ss(scale*models.system_7k.A, ...
    scale*models.system_7k.B, models.system_7k.C, 0);
continuous5k = ss(scale*models.system_5k.A, ...
    scale*models.system_5k.B, models.system_5k.C, 0);
plants = [ssdataStruct(c2d(continuous7k, dt, 'zoh')), ...
    ssdataStruct(c2d(continuous5k, dt, 'zoh'))];
nominal = plants(1);

% The estimator ratio is the best full endpoint-tangent margin found by
% analyze_endpoint_tangent_margin. Integral action is deliberately kept
% classical here so it remains a hard baseline, not the proposed novelty.
estimatorQOverR = 0.1778279410038923;
L = dlqe(nominal.A, nominal.B, nominal.C, estimatorQOverR, 1);
integralWeight = logspace(-6, 10, 129).';
count = numel(integralWeight);
stable = false(count, 2);
finalValue = nan(count, 2);
overshoot = nan(count, 2);
settlingTime = nan(count, 2);
peakCommand = nan(count, 2);
noiseToCommandH2 = nan(count, 2);
stateGain = nan(count, size(nominal.A, 1));
integralGain = nan(count, 1);
time = (0:dt:1).';

integratorA = [nominal.A, zeros(size(nominal.A, 1), 1); ...
    -dt*nominal.C, 1];
integratorB = [nominal.B; 0];
statePenalty = design.qy*(nominal.C.'*nominal.C);

for j = 1:count
    gain = dlqr(integratorA, integratorB, ...
        blkdiag(statePenalty, integralWeight(j)), design.ru);
    K = gain(1:end-1);
    Ki = gain(end);
    stateGain(j, :) = K;
    integralGain(j) = Ki;
    for i = 1:2
        loops = integralObserverLoop(plants(i), nominal, K, Ki, L, dt);
        stable(j, i) = isstable(loops.reference);
        if ~stable(j, i)
            continue
        end
        y = step(loops.reference, time);
        u = step(loops.command, time);
        finalValue(j, i) = dcgain(loops.reference);
        overshoot(j, i) = max(0, (max(y) - 1)*100);
        lastOutside = find(abs(y - 1) > 0.02, 1, 'last');
        if isempty(lastOutside)
            settlingTime(j, i) = 0;
        elseif lastOutside < numel(time)
            settlingTime(j, i) = time(lastOutside + 1);
        else
            settlingTime(j, i) = Inf;
        end
        peakCommand(j, i) = max(abs(u));
        noiseToCommandH2(j, i) = norm(loops.noiseToCommand, 2);
    end
end

feasible = all(stable, 2) & all(overshoot <= 10, 2) & ...
    all(peakCommand <= design.nbar, 2) & ...
    all(isfinite(settlingTime), 2);
indices = find(feasible);
if isempty(indices)
    selected = NaN;
    selectedDesign = table;
else
    [~, localIndex] = min(max(settlingTime(indices, :), [], 2));
    selected = indices(localIndex);
    selectedDesign = table(integralWeight(selected), ...
        integralGain(selected), finalValue(selected, 1), ...
        finalValue(selected, 2), overshoot(selected, 1), ...
        overshoot(selected, 2), settlingTime(selected, 1), ...
        settlingTime(selected, 2), peakCommand(selected, 1), ...
        peakCommand(selected, 2), noiseToCommandH2(selected, 1), ...
        noiseToCommandH2(selected, 2), ...
        'VariableNames', {'IntegralWeight', 'IntegralGain', ...
            'Final7k', 'Final5k', 'Overshoot7kPercent', ...
            'Overshoot5kPercent', 'Settling7kSeconds', ...
            'Settling5kSeconds', 'PeakCommand7k', 'PeakCommand5k', ...
            'NoiseCommandH2_7k', 'NoiseCommandH2_5k'});
end

result = struct;
result.definition = struct( ...
    'sample_time_s', dt, ...
    'estimator_q_over_r', estimatorQOverR, ...
    'selection_rule', ['Fastest worst-endpoint 2% settling among designs ' ...
        'with <=10% overshoot and peak command no larger than the saved ' ...
        'LQR direct command jump.']);
result.integral_weight = integralWeight;
result.state_gain = stateGain;
result.integral_gain = integralGain;
result.stable = stable;
result.final_value = finalValue;
result.overshoot_percent = overshoot;
result.settling_time_s = settlingTime;
result.peak_command = peakCommand;
result.noise_to_command_h2 = noiseToCommandH2;
result.feasible = feasible;
result.selected_index = selected;
result.selected_design = selectedDesign;
if isnan(selected)
    result.selected_robustness = table;
    result.selected_frequency_tracking = table;
else
    K = stateGain(selected, :);
    Ki = integralGain(selected);
    endpoint7k = integralObserverLoop(plants(1), nominal, K, Ki, L, dt);
    endpoint5k = integralObserverLoop(plants(2), nominal, K, Ki, L, dt);
    meanPlant = midpoint(plants(1), plants(2));
    tangent = halfDifference(plants(1), plants(2));
    meanLoop = integralObserverLoop(meanPlant, nominal, K, Ki, L, dt);
    tangentMatrix = integralTangent(tangent, K, Ki, L, dt);
    result.selected_robustness = table( ...
        max(abs(eig(endpoint7k.reference.A))), ...
        max(abs(eig(endpoint5k.reference.A))), ...
        msRadius(meanLoop.reference.A, tangentMatrix), ...
        'VariableNames', {'DeterministicRadius7k', ...
            'DeterministicRadius5k', 'MeanSquareRadius'});
    frequencyHz = linspace(2, 80, 2000).';
    response7k = squeeze(freqresp(endpoint7k.reference, 2*pi*frequencyHz));
    response5k = squeeze(freqresp(endpoint5k.reference, 2*pi*frequencyHz));
    error7k = abs(1 - response7k(:));
    error5k = abs(1 - response5k(:));
    result.selected_frequency_tracking = table( ...
        rms(error7k), rms(error5k), max(error7k), max(error5k), ...
        'VariableNames', {'RMSTrackingError7k', 'RMSTrackingError5k', ...
            'MaxTrackingError7k', 'MaxTrackingError5k'});
    [leftVectors, singularValuesMatrix, rightVectors] = svd( ...
        tangentMatrix, 'econ');
    singularValues = diag(singularValuesMatrix);
    approximationRank = (1:3).';
    capturedEnergy = nan(3, 1);
    relativeTangentError = nan(3, 1);
    approximateMargin = nan(3, 1);
    exactMargin = result.selected_robustness.MeanSquareRadius;
    for i = 1:3
        approximateTangent = leftVectors(:, 1:i) * ...
            singularValuesMatrix(1:i, 1:i) * rightVectors(:, 1:i).';
        capturedEnergy(i) = sum(singularValues(1:i).^2) / ...
            sum(singularValues.^2);
        relativeTangentError(i) = norm(tangentMatrix - ...
            approximateTangent, 'fro') / norm(tangentMatrix, 'fro');
        approximateMargin(i) = msRadius(meanLoop.reference.A, ...
            approximateTangent);
    end
    result.selected_tangent_low_rank = table(approximationRank, ...
        capturedEnergy, relativeTangentError, approximateMargin, ...
        abs(approximateMargin - exactMargin)/exactMargin, ...
        'VariableNames', {'ApproximationRank', 'CapturedEnergy', ...
            'RelativeTangentError', 'ApproximateMargin', ...
            'RelativeMarginError'});
    [reducedMargin, tangentRank, reducedOrder] = reducedMsRadius( ...
        meanLoop.reference.A, tangentMatrix);
    result.selected_reduced_certificate = table(tangentRank, ...
        reducedOrder, reducedMargin, ...
        abs(reducedMargin - exactMargin)/exactMargin, ...
        'VariableNames', {'TangentRank', 'ReducedOperatorOrder', ...
            'ReducedMeanSquareRadius', 'RelativeMarginError'});
end

save(fullfile(studyFolder, 'lqgi_comparator.mat'), 'result')
if isempty(indices)
    disp('No LQGI design met all comparator constraints.')
else
    disp(result.selected_design)
end
end

function output = ssdataStruct(system)
[A, B, C, D] = ssdata(system);
output = struct('A', A, 'B', B, 'C', C, 'D', D);
end

function output = midpoint(first, second)
output = struct('A', (first.A + second.A)/2, ...
    'B', (first.B + second.B)/2, ...
    'C', (first.C + second.C)/2, ...
    'D', (first.D + second.D)/2);
end

function output = halfDifference(first, second)
output = struct('A', (first.A - second.A)/2, ...
    'B', (first.B - second.B)/2, ...
    'C', (first.C - second.C)/2, ...
    'D', (first.D - second.D)/2);
end

function loops = integralObserverLoop(plant, nominal, K, Ki, L, dt)
plantStates = size(plant.A, 1);
observerStates = size(nominal.A, 1);
A = [plant.A, -plant.B*K, -plant.B*Ki; ...
    L*plant.C, nominal.A - nominal.B*K - L*nominal.C, ...
    -nominal.B*Ki; ...
    -dt*plant.C, zeros(1, observerStates), 1];
Br = [zeros(plantStates + observerStates, 1); dt];
Bv = [zeros(plantStates, 1); L; -dt];
Cy = [plant.C, zeros(1, observerStates + 1)];
Cu = [zeros(1, plantStates), -K, -Ki];
loops = struct( ...
    'reference', ss(A, Br, Cy, 0, dt), ...
    'command', ss(A, Br, Cu, 0, dt), ...
    'noiseToCommand', ss(A, Bv, Cu, 0, dt));
end

function matrix = integralTangent(tangent, K, Ki, L, dt)
stateCount = size(tangent.A, 1);
matrix = [tangent.A, -tangent.B*K, -tangent.B*Ki; ...
    L*tangent.C, zeros(stateCount), zeros(stateCount, 1); ...
    -dt*tangent.C, zeros(1, stateCount + 1)];
end

function radius = msRadius(meanMatrix, tangentMatrix)
baseOperator = kron(meanMatrix, meanMatrix);
tangentOperator = kron(tangentMatrix, tangentMatrix);
lower = 0;
upper = 1;
while max(abs(eig(baseOperator + upper^2*tangentOperator))) < 1 && ...
        upper < 128
    upper = 2*upper;
end
for i = 1:35
    trial = (lower + upper)/2;
    if max(abs(eig(baseOperator + trial^2*tangentOperator))) < 1
        lower = trial;
    else
        upper = trial;
    end
end
radius = lower;
end

function [radius, tangentRank, reducedOrder] = reducedMsRadius( ...
        meanMatrix, tangentMatrix)
[leftVectors, singularValues, rightVectors] = svd(tangentMatrix, 'econ');
tangentRank = rank(tangentMatrix);
rootSingularValues = sqrt(singularValues(1:tangentRank, 1:tangentRank));
leftFactor = leftVectors(:, 1:tangentRank)*rootSingularValues;
rightFactor = rightVectors(:, 1:tangentRank)*rootSingularValues;
leftKronecker = kron(leftFactor, leftFactor);
rightKronecker = kron(rightFactor, rightFactor);
resolvent = eye(size(meanMatrix, 1)^2) - kron(meanMatrix, meanMatrix);
reducedOperator = rightKronecker.'*(resolvent \ leftKronecker);
reducedOrder = size(reducedOperator, 1);
radius = 1/sqrt(max(abs(eig(reducedOperator))));
end
