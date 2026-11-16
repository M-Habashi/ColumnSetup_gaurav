function result = lyap(controllerOne, controllerTwo, options)
%LYAP Find a common quadratic Lyapunov function for two scripted controllers.
%   RESULT = LYAP('A','C') tests controllers A and C. Any distinct pair from
%   A, B, and C is accepted. Frozen specimen stiffness is swept from alpha =
%   1 to 0 in increments of 0.05. At each alpha the reduced continuous
%   tracking loops are formed and the common Lyapunov inequalities are solved:
%       P > 0,  A_1' P + P A_1 < 0,  A_2' P + P A_2 < 0.
%   RESULT.P_at_minimum is the trace-normalized common matrix at the lowest
%   feasible alpha. This standalone command does not run a time simulation.
%
%   RESULT = LYAP(CONTROLLER1,CONTROLLER2,OPTIONS) accepts a complete
%   scripted_run-compatible options structure. Controller labels are
%   case-insensitive character vectors or strings.
%
%   This Habashi command intentionally shadows Control System Toolbox LYAP
%   while the scripted folder is the current folder or first on the path.

narginchk(2, 3)
controllerOne = validatestring(controllerOne, {'A', 'B', 'C'}, ...
    mfilename, 'controllerOne', 1);
controllerTwo = validatestring(controllerTwo, {'A', 'B', 'C'}, ...
    mfilename, 'controllerTwo', 2);
if controllerOne == controllerTwo
    error('scripted:LyapunovControllerPair', ...
        'Select two different controllers from A, B, and C.')
end
if nargin < 3
    [lastRun, ~] = scripted_last_run_configuration( ...
        fileparts(fileparts(mfilename('fullpath'))));
    if isempty(lastRun)
        options = defaultOptions;
        controllerSnapshot = [];
    else
        options = lastRun.Options;
        controllerSnapshot = lastRun;
    end
else
    controllerSnapshot = [];
end

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);
scripted_validate_options(options);
parameters = scripted_build_trial(options, projectRoot, 1);
if ~isempty(controllerSnapshot)
    parameters = restoreControllers(parameters, controllerSnapshot);
end

alphaValues = round((1:-0.05:0)' * 100) / 100;
alphaCount = numel(alphaValues);
maxRealPoleOne = nan(alphaCount, 1);
maxRealPoleTwo = nan(alphaCount, 1);
commonFound = false(alphaCount, 1);
worstVDotRatio = nan(alphaCount, 1);
solverTmin = nan(alphaCount, 1);
commonMatrices = cell(alphaCount, 1);
scaledMatrices = cell(alphaCount, 1);
stateScalings = cell(alphaCount, 1);
closedLoopMatricesOne = cell(alphaCount, 1);
closedLoopMatricesTwo = cell(alphaCount, 1);

fprintf('\n%s/%s common quadratic Lyapunov sweep\n', ...
    controllerOne, controllerTwo)
fprintf(['Reduced continuous tracking loop, alpha = 1 down to 0 in ', ...
    'increments of 0.05.\n'])
fprintf('No time simulation is run. Specimen damping is held at %.6g N s/m.\n', ...
    parameters.c_e)

for alphaIndex = 1:alphaCount
    alpha = alphaValues(alphaIndex);
    [matrixOne, matrixTwo] = localClosedLoopMatrices(parameters, alpha, ...
        controllerOne, controllerTwo);
    closedLoopMatricesOne{alphaIndex} = matrixOne;
    closedLoopMatricesTwo{alphaIndex} = matrixTwo;
    maxRealPoleOne(alphaIndex) = max(real(eig(matrixOne)));
    maxRealPoleTwo(alphaIndex) = max(real(eig(matrixTwo)));

    if maxRealPoleOne(alphaIndex) >= 0 || maxRealPoleTwo(alphaIndex) >= 0
        continue
    end

    [commonFound(alphaIndex), commonMatrices{alphaIndex}, ...
        scaledMatrices{alphaIndex}, stateScalings{alphaIndex}, ...
        solverTmin(alphaIndex), worstVDotRatio(alphaIndex)] = ...
        commonContinuousLyapunov(matrixOne, matrixTwo);
end

sweep = table(alphaValues, maxRealPoleOne, maxRealPoleTwo, commonFound, ...
    worstVDotRatio, solverTmin, ...
    'VariableNames', {'Alpha', 'MaxRealPole_Controller1', ...
    'MaxRealPole_Controller2', 'CommonLyapunov', ...
    'Worst_Vdot_over_V_per_s', 'Solver_tmin'});
disp(sweep)

feasibleIndices = find(commonFound);
if isempty(feasibleIndices)
    minimumAlpha = NaN;
    minimumIndex = [];
    minimumMatrix = [];
    fprintf('No common quadratic Lyapunov function was found on the grid.\n')
else
    [minimumAlpha, localIndex] = min(alphaValues(feasibleIndices));
    minimumIndex = feasibleIndices(localIndex);
    minimumMatrix = commonMatrices{minimumIndex};
    fprintf(['Minimum grid alpha with a common quadratic Lyapunov ', ...
        'function for %s/%s: %.2f\n'], ...
        controllerOne, controllerTwo, minimumAlpha)
    fprintf(['The trace-normalized matrix is returned in ', ...
        'result.P_at_minimum.\n'])
    fprintf('\nP at alpha = %.2f:\n', minimumAlpha)
    disp(minimumMatrix)
    fprintf('\nA_cl1 at alpha = %.2f (%s):\n', minimumAlpha, controllerOne)
    disp(closedLoopMatricesOne{minimumIndex})
    fprintf('A_cl2 at alpha = %.2f (%s):\n', minimumAlpha, controllerTwo)
    disp(closedLoopMatricesTwo{minimumIndex})
end

result = struct;
result.Controller1Name = controllerOne;
result.Controller2Name = controllerTwo;
result.Controller1 = controllerFromName(parameters, controllerOne);
result.Controller2 = controllerFromName(parameters, controllerTwo);
result.Sweep = sweep;
result.MinimumAlpha = minimumAlpha;
result.P_at_minimum = minimumMatrix;
result.P_by_alpha = commonMatrices;
result.ScaledP_by_alpha = scaledMatrices;
result.StateScaling_by_alpha = stateScalings;
result.Acl1_by_alpha = closedLoopMatricesOne;
result.Acl2_by_alpha = closedLoopMatricesTwo;
result.AlphaStep = 0.05;
result.ControllerCTune = parameters.controller_c_report;
result.Options = options;
if ~isempty(minimumIndex)
    result.ScaledP_at_minimum = scaledMatrices{minimumIndex};
    result.StateScaling_at_minimum = stateScalings{minimumIndex};
    result.Acl1_at_minimum = closedLoopMatricesOne{minimumIndex};
    result.Acl2_at_minimum = closedLoopMatricesTwo{minimumIndex};
    result.WorstVDotRatioAtMinimum = worstVDotRatio(minimumIndex);
else
    result.ScaledP_at_minimum = [];
    result.StateScaling_at_minimum = [];
    result.Acl1_at_minimum = [];
    result.Acl2_at_minimum = [];
    result.WorstVDotRatioAtMinimum = NaN;
end
end

function options = defaultOptions
[targetNCFC, targetNCFCAlpha] = scripted_controller_c_settings;
options = struct( ...
    'Building_c', baseValueOrDefault('Building_c', 1), ...
    'plot_on', 'n', ...
    'modified', 1, ...
    'consider_damage', 0, ...
    'alpha_start', 1, ...
    'alpha_min', 0, ...
    'b_th', 0.13, ...
    'num_add', 0, ...
    'enable_indicator_plot', 0, ...
    'test_name', 'None', ...
    'fs', baseValueOrDefault('fs', 4096), ...
    'bw_a', baseValueOrDefault('bw_a', 80), ...
    'pm_a', baseValueOrDefault('pm_a', 60), ...
    'bw_b', baseValueOrDefault('bw_b', 60), ...
    'pm_b', baseValueOrDefault('pm_b', 60), ...
    'bw_c', baseValueOrDefault('bw_c', 40), ...
    'pm_c', baseValueOrDefault('pm_c', 60), ...
    'target_ncf_c', targetNCFC, ...
    'target_ncf_c_alpha', targetNCFCAlpha, ...
    'start_c', 'C', ...
    'switch_on', 0);
end

function value = baseValueOrDefault(variableName, defaultValue)
existsInBase = evalin('base', sprintf( ...
    'exist(''%s'', ''var'') == 1', variableName));
if existsInBase
    value = evalin('base', variableName);
else
    value = defaultValue;
end
end

function [matrixOne, matrixTwo] = localClosedLoopMatrices( ...
        p, alpha, controllerOne, controllerTwo)
% Alpha changes stiffness only; degradation keeps p.c_e constant at runtime.
innerPlant = scripted_inner_open_loop(p.m_e, p.c_e, alpha * p.k_e);
trackingPlant = ss(feedback(innerPlant, 1));
[plantA, plantB, plantC, plantD] = ssdata(trackingPlant);
if any(abs(plantD(:)) > 1e-10)
    error('scripted:LyapunovPlantFeedthrough', ...
        'The reduced tracking plant must be strictly proper.')
end

matrixOne = closeLoop(plantA, plantB, plantC, ...
    controllerFromName(p, controllerOne));
matrixTwo = closeLoop(plantA, plantB, plantC, ...
    controllerFromName(p, controllerTwo));
if ~isequal(size(matrixOne), size(matrixTwo))
    error('scripted:LyapunovControllerOrder', ...
        'The selected controllers must have the same dynamic order.')
end
end

function controller = controllerFromName(p, controllerName)
controller = p.(sprintf('controller_%s', lower(controllerName)));
end

function parameters = restoreControllers(parameters, configuration)
parameters.controller_a = controllerFromRecord(configuration.ControllerA);
parameters.controller_b = controllerFromRecord(configuration.ControllerB);
parameters.controller_c = controllerFromRecord(configuration.ControllerC);
parameters.pi_a_kp = parameters.controller_a.Kp;
parameters.pi_a_ki = parameters.controller_a.Ki;
parameters.pi_b_kp = parameters.controller_b.Kp;
parameters.pi_b_ki = parameters.controller_b.Ki;
parameters.pi_c_kp = parameters.controller_c.Kp;
parameters.pi_c_ki = parameters.controller_c.Ki;
end

function controller = controllerFromRecord(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end

function closedMatrix = closeLoop(plantA, plantB, plantC, controller)
[controllerA, controllerB, controllerC, controllerD] = ...
    ssdata(ss(controller));
closedMatrix = [ ...
    plantA - plantB * controllerD * plantC, plantB * controllerC; ...
    -controllerB * plantC, controllerA];
end

function [found, originalP, scaledP, stateScaling, tmin, worstRatio] = ...
        commonContinuousLyapunov(matrixOne, matrixTwo)
% A shared similarity scaling makes the LMI numerically well conditioned.
[stateScaling, ~] = balance(max(abs(matrixOne), abs(matrixTwo)), 'noperm');
scaledOne = stateScaling \ matrixOne * stateScaling;
scaledTwo = stateScaling \ matrixTwo * stateScaling;

stateCount = size(scaledOne, 1);
identity = eye(stateCount);
setlmis([])
[pVariable, ~, ~] = lmivar(1, [stateCount, 1]);

% I - P < 0.
lmiterm([1, 1, 1, pVariable], -1, 1)
lmiterm([1, 1, 1, 0], identity)

% A'P + PA + I < 0 for both selected controllers.
lmiterm([2, 1, 1, pVariable], scaledOne', 1, 's')
lmiterm([2, 1, 1, 0], identity)
lmiterm([3, 1, 1, pVariable], scaledTwo', 1, 's')
lmiterm([3, 1, 1, 0], identity)

lmiSystem = getlmis;
solverOptions = [1e-8, 500, 1e20, 10, 1];
[tmin, feasiblePoint] = feasp(lmiSystem, solverOptions);

originalP = [];
scaledP = [];
worstRatio = NaN;
found = isfinite(tmin) && tmin < 0 && ~isempty(feasiblePoint);
if ~found
    return
end

scaledP = dec2mat(lmiSystem, feasiblePoint, pVariable);
scaledP = 0.5 * (scaledP + scaledP');
scaledP = scaledP / trace(scaledP);
ratioOne = max(real(eig( ...
    scaledOne' * scaledP + scaledP * scaledOne, scaledP)));
ratioTwo = max(real(eig( ...
    scaledTwo' * scaledP + scaledP * scaledTwo, scaledP)));
worstRatio = max(ratioOne, ratioTwo);
found = min(eig(scaledP)) > 0 && worstRatio < -1e-8;
if ~found
    originalP = [];
    scaledP = [];
    worstRatio = NaN;
    return
end

originalP = stateScaling' \ scaledP / stateScaling;
originalP = 0.5 * (originalP + originalP');
originalP = originalP / trace(originalP);
end
