function report = scripted_benchmark_common_lyapunov(repetitions)
%SCRIPTED_BENCHMARK_COMMON_LYAPUNOV Time the single-start fmincon sweep.
%   This benchmark matches the manuscript pseudocode: P is optimized
%   directly, trace(P)=1 removes scale ambiguity, and the objective is the
%   worst of the two Lyapunov-residual maximum eigenvalues.

if nargin < 1
    repetitions = 3;
end

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
[lastRun, configurationPath] = scripted_last_run_configuration(projectRoot);
assert(~isempty(lastRun), 'No saved scripted configuration was found.');
p = scripted_build_trial(lastRun.Options, projectRoot, 1);
p.controller_a = controllerFromRecord(lastRun.ControllerA);
p.controller_b = controllerFromRecord(lastRun.ControllerB);

alphaValues = (1:-0.05:0).';
alphaCount = numel(alphaValues);
solverOptions = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'Display', 'off', ...
    'FiniteDifferenceType', 'central', ...
    'MaxIterations', 1000, ...
    'MaxFunctionEvaluations', 1e5, ...
    'ConstraintTolerance', 1e-7);

% Warm up model construction and the optimizer outside the timed section.
[warmA, warmB] = closedLoopPair(p, alphaValues(1));
n = size(warmA, 1);
x0 = packSymmetric(eye(n) / n);
fmincon(@(x) worstResidual(x, warmA, warmB, n), x0, ...
    [], [], [], [], [], [], @(x) matrixConstraints(x, n), solverOptions);

elapsedSeconds = zeros(repetitions, 1);
functionEvaluations = zeros(repetitions, 1);
iterations = zeros(repetitions, 1);
feasibleCounts = zeros(repetitions, 1);
minimumAlpha = nan(repetitions, 1);

for repetition = 1:repetitions
    feasible = false(alphaCount, 1);
    runEvaluations = 0;
    runIterations = 0;
    startTime = tic;
    for alphaIndex = 1:alphaCount
        [matrixOne, matrixTwo] = closedLoopPair(p, alphaValues(alphaIndex));
        n = size(matrixOne, 1);
        x0 = packSymmetric(eye(n) / n);
        [x, residual, ~, output] = fmincon( ...
            @(candidate) worstResidual(candidate, matrixOne, matrixTwo, n), ...
            x0, [], [], [], [], [], [], ...
            @(candidate) matrixConstraints(candidate, n), solverOptions);
        candidateP = unpackSymmetric(x, n);
        feasible(alphaIndex) = min(eig(candidateP)) > 1e-8 && ...
            residual < -1e-8;
        runEvaluations = runEvaluations + output.funcCount;
        runIterations = runIterations + output.iterations;
    end
    elapsedSeconds(repetition) = toc(startTime);
    functionEvaluations(repetition) = runEvaluations;
    iterations(repetition) = runIterations;
    feasibleCounts(repetition) = nnz(feasible);
    if any(feasible)
        minimumAlpha(repetition) = min(alphaValues(feasible));
    end
end

report = struct;
report.Configuration = configurationPath;
report.Repetitions = repetitions;
report.AlphaValues = alphaValues;
report.AlphaCount = alphaCount;
report.StartsPerAlpha = 1;
report.ClosedLoopOrder = n;
report.DecisionVariableCount = n * (n + 1) / 2;
report.ElapsedSeconds = elapsedSeconds;
report.MedianElapsedSeconds = median(elapsedSeconds);
report.MinimumElapsedSeconds = min(elapsedSeconds);
report.MaximumElapsedSeconds = max(elapsedSeconds);
report.FunctionEvaluations = functionEvaluations;
report.Iterations = iterations;
report.FeasibleCounts = feasibleCounts;
report.MinimumAlpha = minimumAlpha;

fprintf('\nSingle-start common-Lyapunov fmincon benchmark\n');
fprintf('Closed-loop order: %d; decision variables: %d\n', ...
    report.ClosedLoopOrder, report.DecisionVariableCount);
fprintf('Alpha levels: %d; starts per alpha: 1; repetitions: %d\n', ...
    alphaCount, repetitions);
fprintf('Elapsed seconds: ');
fprintf('%.6f ', elapsedSeconds);
fprintf('\nMedian: %.6f s; range: %.6f--%.6f s\n', ...
    report.MedianElapsedSeconds, report.MinimumElapsedSeconds, ...
    report.MaximumElapsedSeconds);
fprintf('Function evaluations per sweep: ');
fprintf('%d ', functionEvaluations);
fprintf('\nIterations per sweep: ');
fprintf('%d ', iterations);
fprintf('\nMinimum feasible alpha: ');
fprintf('%.2f ', minimumAlpha);
fprintf('\n');
end

function [matrixOne, matrixTwo] = closedLoopPair(p, alpha)
plant = ss(feedback(scripted_inner_open_loop( ...
    p.m_e, p.c_e, alpha * p.k_e), 1));
[plantA, plantB, plantC, plantD] = ssdata(plant);
assert(all(abs(plantD(:)) < 1e-10), ...
    'The reduced tracking plant must be strictly proper.');
matrixOne = closeLoop(plantA, plantB, plantC, p.controller_a);
matrixTwo = closeLoop(plantA, plantB, plantC, p.controller_b);
end

function matrix = closeLoop(plantA, plantB, plantC, controller)
[controllerA, controllerB, controllerC, controllerD] = ...
    ssdata(ss(controller));
matrix = [plantA - plantB * controllerD * plantC, ...
          plantB * controllerC; ...
          -controllerB * plantC, controllerA];
end

function controller = controllerFromRecord(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end

function residual = worstResidual(x, matrixOne, matrixTwo, n)
p = unpackSymmetric(x, n);
first = matrixOne' * p + p * matrixOne;
second = matrixTwo' * p + p * matrixTwo;
residual = max([max(real(eig(0.5 * (first + first')))), ...
    max(real(eig(0.5 * (second + second'))))]);
end

function [c, ceq] = matrixConstraints(x, n)
p = unpackSymmetric(x, n);
c = 1e-8 - min(real(eig(p)));
ceq = trace(p) - 1;
end

function x = packSymmetric(matrix)
n = size(matrix, 1);
x = zeros(n * (n + 1) / 2, 1);
index = 1;
for row = 1:n
    for column = 1:row
        x(index) = matrix(row, column);
        index = index + 1;
    end
end
end

function matrix = unpackSymmetric(x, n)
matrix = zeros(n);
index = 1;
for row = 1:n
    for column = 1:row
        matrix(row, column) = x(index);
        matrix(column, row) = x(index);
        index = index + 1;
    end
end
end
