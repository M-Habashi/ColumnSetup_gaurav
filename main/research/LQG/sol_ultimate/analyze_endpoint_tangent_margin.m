function result = analyze_endpoint_tangent_margin
%ANALYZE_ENDPOINT_TANGENT_MARGIN Exact mean-square margins for LQG filters.

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
discrete7k = ssdataStruct(c2d(continuous7k, dt, 'zoh'));
discrete5k = ssdataStruct(c2d(continuous5k, dt, 'zoh'));

meanPlant = midpoint(discrete7k, discrete5k);
tangent = halfDifference(discrete7k, discrete5k);
K = design.K;
qOverR = logspace(-8, 3, 45).';
count = numel(qOverR);
deterministicRadius = nan(count, 2);
meanSquareRadiusFull = nan(count, 1);
meanSquareRadiusDynamicsOnly = nan(count, 1);
kalmanGainNorm = nan(count, 1);

for i = 1:count
    L = dlqe(discrete7k.A, discrete7k.B, discrete7k.C, ...
        qOverR(i), 1);
    kalmanGainNorm(i) = norm(L);
    endpoint7k = augmentedMatrix(discrete7k, discrete7k, K, L);
    endpoint5k = augmentedMatrix(discrete5k, discrete7k, K, L);
    deterministicRadius(i, :) = [max(abs(eig(endpoint7k))), ...
        max(abs(eig(endpoint5k)))];

    meanMatrix = augmentedMatrix(meanPlant, discrete7k, K, L);
    fullTangent = augmentedTangent(tangent, K, L, true);
    dynamicsTangent = augmentedTangent(tangent, K, L, false);
    meanSquareRadiusFull(i) = msRadius(meanMatrix, fullTangent);
    meanSquareRadiusDynamicsOnly(i) = msRadius(meanMatrix, ...
        dynamicsTangent);
end

stableEndpoints = all(deterministicRadius < 1, 2);
eligible = find(stableEndpoints);
[~, fullLocal] = max(meanSquareRadiusFull(eligible));
[~, dynamicsLocal] = max(meanSquareRadiusDynamicsOnly(eligible));
bestFull = eligible(fullLocal);
bestDynamicsOnly = eligible(dynamicsLocal);

result = struct;
result.definition = struct( ...
    'sample_time_s', dt, ...
    'mean_model', 'Arithmetic midpoint of discrete 7k and 5k models', ...
    'tangent_model', 'Half of discrete 7k-minus-5k endpoint difference', ...
    'uncertainty', ['One shared zero-mean scalar multiplies DeltaA, ' ...
        'DeltaB, and DeltaC'], ...
    'certificate', ['rho(kron(M0,M0) + sigma^2 ' ...
        'kron(Mdelta,Mdelta)) < 1']);
result.q_over_r = qOverR;
result.kalman_gain_norm = kalmanGainNorm;
result.deterministic_endpoint_radius = deterministicRadius;
result.mean_square_radius_full_tangent = meanSquareRadiusFull;
result.mean_square_radius_dynamics_only = ...
    meanSquareRadiusDynamicsOnly;
result.best_full_tangent = summaryRow(bestFull, qOverR, ...
    kalmanGainNorm, deterministicRadius, meanSquareRadiusFull, ...
    meanSquareRadiusDynamicsOnly);
result.best_dynamics_only = summaryRow(bestDynamicsOnly, qOverR, ...
    kalmanGainNorm, deterministicRadius, meanSquareRadiusFull, ...
    meanSquareRadiusDynamicsOnly);
bestL = dlqe(discrete7k.A, discrete7k.B, discrete7k.C, ...
    qOverR(bestFull), 1);
bestMeanMatrix = augmentedMatrix(meanPlant, discrete7k, K, bestL);
bestTangent = augmentedTangent(tangent, K, bestL, true);
[leftVectors, singularValuesMatrix, rightVectors] = svd(bestTangent, 'econ');
singularValues = diag(singularValuesMatrix);
approximationRank = (1:3).';
capturedEnergy = nan(3, 1);
relativeTangentError = nan(3, 1);
approximateMargin = nan(3, 1);
relativeMarginError = nan(3, 1);
for i = 1:3
    approximateTangent = leftVectors(:, 1:i) * ...
        singularValuesMatrix(1:i, 1:i) * rightVectors(:, 1:i).';
    capturedEnergy(i) = sum(singularValues(1:i).^2) / ...
        sum(singularValues.^2);
    relativeTangentError(i) = norm(bestTangent - approximateTangent, ...
        'fro') / norm(bestTangent, 'fro');
    approximateMargin(i) = msRadius(bestMeanMatrix, approximateTangent);
    relativeMarginError(i) = abs(approximateMargin(i) - ...
        meanSquareRadiusFull(bestFull)) / meanSquareRadiusFull(bestFull);
end
result.best_tangent_singular_values = singularValues;
result.low_rank_diagnostic = table(approximationRank, capturedEnergy, ...
    relativeTangentError, approximateMargin, relativeMarginError);
[reducedMargin, tangentRank, reducedOrder] = reducedMsRadius( ...
    bestMeanMatrix, bestTangent);
result.reduced_certificate = table(tangentRank, reducedOrder, ...
    reducedMargin, abs(reducedMargin - meanSquareRadiusFull(bestFull)) / ...
    meanSquareRadiusFull(bestFull), ...
    'VariableNames', {'TangentRank', 'ReducedOperatorOrder', ...
        'ReducedMeanSquareRadius', 'RelativeMarginError'});

save(fullfile(studyFolder, 'endpoint_tangent_margin.mat'), 'result')
disp('Best full endpoint-tangent margin')
disp(result.best_full_tangent)
disp('Best dynamics-only margin')
disp(result.best_dynamics_only)
disp('Low-rank endpoint-tangent diagnostic')
disp(result.low_rank_diagnostic)
disp('Reduced exact certificate')
disp(result.reduced_certificate)
fprintf('Full tangent reduces the best certified radius by %.2f%%.\n', ...
    100*(1 - result.best_full_tangent.MeanSquareRadius / ...
    result.best_dynamics_only.MeanSquareRadiusDynamicsOnly))
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

function matrix = augmentedMatrix(plant, observer, K, L)
matrix = [plant.A, -plant.B*K; ...
    L*plant.C, observer.A - observer.B*K - L*observer.C];
end

function matrix = augmentedTangent(tangent, K, L, includeOutput)
stateCount = size(tangent.A, 1);
if includeOutput
    measurementBlock = L*tangent.C;
else
    measurementBlock = zeros(stateCount);
end
matrix = [tangent.A, -tangent.B*K; ...
    measurementBlock, zeros(stateCount)];
end

function radius = msRadius(meanMatrix, tangentMatrix)
baseOperator = kron(meanMatrix, meanMatrix);
tangentOperator = kron(tangentMatrix, tangentMatrix);
if max(abs(eig(baseOperator))) >= 1
    radius = 0;
    return
end
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

function row = summaryRow(index, qOverR, gainNorm, endpointRadius, ...
        fullRadius, dynamicsRadius)
row = table(qOverR(index), gainNorm(index), endpointRadius(index, 1), ...
    endpointRadius(index, 2), fullRadius(index), dynamicsRadius(index), ...
    'VariableNames', {'QOverR', 'KalmanGainNorm', ...
        'DeterministicRadius7k', 'DeterministicRadius5k', ...
        'MeanSquareRadius', 'MeanSquareRadiusDynamicsOnly'});
end
