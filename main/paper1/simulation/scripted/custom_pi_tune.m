function [result, report] = custom_pi_tune( ...
        targetNCF, alpha, specimen, rthsParams)
%CUSTOM_PI_TUNE Match an NCF target and maximize coupled modal damping.
%   [RESULT, REPORT] = CUSTOM_PI_TUNE(TARGETNCF, ALPHA, SPECIMEN,
%   RTHSPARAMS) tunes a continuous PI controller at one frozen stiffness.
%
%   Inputs
%     TARGETNCF  Desired legacy continuous local-loop NCF margin (0 to 1).
%     ALPHA      Stiffness ratio used for both NCF and damping evaluation.
%     SPECIMEN   Struct with positive scalar fields mass, stiffness, and
%                damping. Stiffness is the alpha=1 value; damping is held
%                constant in the sampled coupled-loop model.
%     RTHSPARAMS Struct containing sampleTime, innerClosedLoop,
%                innerClosedLoopNCF, phaseLead, numericalSubstructure,
%                forceInputIndex, and displacementOutputIndex.
%                innerClosedLoop is the continuous SISO servo/actuator/
%                specimen loop at ALPHA. innerClosedLoopNCF is the legacy
%                continuous NCF plant at ALPHA. phaseLead is discrete at
%                sampleTime; numericalSubstructure is continuous.
%
%   Outputs
%     RESULT     Continuous-time PID object with PI gains Kp and Ki.
%     REPORT     Gains, achieved NCF/error and tracking bandwidth, coupled
%                damping/pole, sampled poles, stability, feasibility, and
%                optimizer diagnostics.
%
%   Fixed assumptions: absolute NCF tolerance is 0.01 and the minimum local
%   tracking bandwidth is 20 rad/s; PI gains are positive and optimized in
%   log coordinates; force feedback has one sample of delay; derivative
%   histories are generated internally; command gain is unity; calibration,
%   artificial noise, quantization, and saturation are omitted. The
%   automatically selected coupled mode is the lowest-frequency oscillatory
%   sampled mode.
%
%   Current nominal example (modified Case 1):
%     specimen = struct('mass', 37.869, 'stiffness', 1.19e6, ...
%         'damping', 130.232);
%     % rthsParams is assembled in scripted_build_trial at Ts = 1/4096 s.
%     [controllerC, report] = custom_pi_tune(0.21, 0.1, ...
%         specimen, rthsParams);

validateInputs(targetNCF, alpha, specimen, rthsParams)
rthsParams.innerClosedLoop = ss(rthsParams.innerClosedLoop);
rthsParams.innerClosedLoopNCF = ss(rthsParams.innerClosedLoopNCF);
rthsParams.phaseLead = ss(rthsParams.phaseLead);
rthsParams.numericalSubstructure = ss( ...
    rthsParams.numericalSubstructure);

tolerance = 0.01;
searchTolerance = tolerance - 1e-4;
minimumBandwidth = 20;
searchMinimumBandwidth = minimumBandwidth + 0.05;
gainLower = [1e-4, 1e-3];
gainUpper = [1e2, 1e4];
frequency = logspace(-1, 4, 10000);
s = 1i * frequency;
ncfPlantResponse = reshape(freqresp( ...
    rthsParams.innerClosedLoopNCF, frequency), 1, []);

% A small logarithmic survey supplies a scale-independent starting point.
kpSurvey = logspace(-3, 1, 11);
kiSurvey = logspace(-1, 3, 11);
surveyBest = emptyCandidate('survey');
for kpIndex = 1:numel(kpSurvey)
    for kiIndex = 1:numel(kiSurvey)
        candidate = evaluateCandidate(kpSurvey(kpIndex), ...
            kiSurvey(kiIndex), 'survey');
        surveyBest = selectBetter(surveyBest, candidate);
    end
end
initialGains = [surveyBest.Kp, surveyBest.Ki];

searchOptions = optimset('Display', 'off', 'MaxIter', 160, ...
    'MaxFunEvals', 300, 'TolX', 1e-7, 'TolFun', 1e-8);

logStart = tic;
[logGains, ~, logExitFlag, logOutput] = fminsearch( ...
    @logObjective, log(initialGains), searchOptions);
logTime = toc(logStart);
logGains = exp(logGains);
logCandidate = evaluateCandidate(logGains(1), logGains(2), 'log');
logCandidate.ExitFlag = logExitFlag;
logCandidate.FunctionCount = logOutput.funcCount;
logCandidate.ElapsedSeconds = logTime;

bestCandidate = selectBetter(surveyBest, logCandidate);
result = pid(bestCandidate.Kp, bestCandidate.Ki, 0);

report = struct;
report.TargetNCF = targetNCF;
report.NCFTolerance = tolerance;
report.Alpha = alpha;
report.Controller = result;
report.Kp = bestCandidate.Kp;
report.Ki = bestCandidate.Ki;
report.AchievedNCF = bestCandidate.NCF;
report.NCFError = abs(bestCandidate.NCF - targetNCF);
report.Bandwidth = bestCandidate.Bandwidth;
report.MinimumBandwidth = minimumBandwidth;
report.CoupledDampingRatio = bestCandidate.DampingRatio;
report.CoupledDampingPercent = 100 * bestCandidate.DampingRatio;
report.CoupledPole = bestCandidate.CoupledPole;
report.DiscretePoles = bestCandidate.DiscretePoles;
report.SpectralRadius = bestCandidate.SpectralRadius;
report.Stable = bestCandidate.Stable;
report.Feasible = bestCandidate.Feasible;
report.SearchMethod = bestCandidate.Method;
report.ExitFlag = bestCandidate.ExitFlag;
report.FunctionCount = bestCandidate.FunctionCount;
report.ElapsedSeconds = bestCandidate.ElapsedSeconds;
report.SampleTime = rthsParams.sampleTime;
report.GainBounds = table(gainLower(:), gainUpper(:), ...
    'RowNames', {'Kp', 'Ki'}, 'VariableNames', {'Lower', 'Upper'});
report.Assumptions = struct( ...
    'ControllerType', "PI", ...
    'ForceDelaySamples', 1, ...
    'CalibrationGain', 1, ...
    'NoiseIncluded', false, ...
    'ModeSelection', "lowest-frequency oscillatory sampled mode", ...
    'NCFConvention', "legacy continuous local-loop margin", ...
    'CoupledDampingConvention', ...
    "frozen sampled loop with constant specimen damping");
fprintf(['Custom PI tune at alpha = %.3g: target NCF = %.4f, ', ...
    'achieved NCF = %.4f, bandwidth = %.4g rad/s, Kp = %.6g, ', ...
    'Ki = %.6g, coupled damping = %.2f%% (%s search)\n'], ...
    alpha, report.TargetNCF, report.AchievedNCF, report.Bandwidth, ...
    report.Kp, report.Ki, report.CoupledDampingPercent, ...
    char(report.SearchMethod))
if ~report.Feasible
    warning('scripted:CustomPITuneInfeasible', ...
        ['No stable candidate met the requested NCF tolerance and ', ...
        'minimum bandwidth. ', ...
        'Returning the closest stable candidate found.'])
end

    function objective = logObjective(logarithmicGains)
        gains = exp(logarithmicGains);
        candidate = evaluateCandidate(gains(1), gains(2), 'log');
        objective = candidate.Objective;
    end

    function candidate = evaluateCandidate(kpValue, kiValue, methodName)
        candidate = emptyCandidate(methodName);
        candidate.Kp = kpValue;
        candidate.Ki = kiValue;
        if ~isfinite(kpValue) || ~isfinite(kiValue) || ...
                kpValue < gainLower(1) || kpValue > gainUpper(1) || ...
                kiValue < gainLower(2) || kiValue > gainUpper(2)
            candidate.Objective = 1e6 + gainBoundPenalty( ...
                [kpValue, kiValue], gainLower, gainUpper);
            return
        end

        controllerResponse = kpValue + kiValue ./ s;
        sigma = (sqrt(abs(ncfPlantResponse).^2 + 1) .* ...
            sqrt(abs(controllerResponse).^2 + 1)) ./ ...
            abs(1 + ncfPlantResponse .* controllerResponse);
        localController = pid(kpValue, kiValue, 0);
        localClosedLoop = feedback( ...
            localController * rthsParams.innerClosedLoopNCF, 1);
        if isstable(localClosedLoop)
            candidate.NCF = 1 / max(sigma);
        else
            candidate.NCF = 0;
        end
        candidate.Bandwidth = trackingBandwidth(localController);

        [candidate.DampingRatio, candidate.CoupledPole, ...
            candidate.DiscretePoles, candidate.SpectralRadius] = ...
            coupledDamping(kpValue, kiValue);
        candidate.Stable = isfinite(candidate.SpectralRadius) && ...
            candidate.SpectralRadius < 1 - 1e-9 && ...
            isfinite(candidate.DampingRatio);
        ncfError = abs(candidate.NCF - targetNCF);
        ncfViolation = max(ncfError - searchTolerance, 0);
        if isfinite(candidate.Bandwidth)
            bandwidthViolation = max(searchMinimumBandwidth - ...
                candidate.Bandwidth, 0) / minimumBandwidth;
        else
            bandwidthViolation = 1e3;
        end
        candidate.Feasible = candidate.Stable && ...
            ncfError <= tolerance && isfinite(candidate.Bandwidth) && ...
            candidate.Bandwidth >= minimumBandwidth;
        if candidate.Stable
            candidate.Objective = -candidate.DampingRatio + ...
                1e4 * ncfViolation.^2 + ...
                1e4 * bandwidthViolation.^2;
        else
            if isfinite(candidate.SpectralRadius)
                stabilityPenalty = ...
                    1e3 * max(candidate.SpectralRadius - 1, 0).^2;
            else
                stabilityPenalty = 1e6;
            end
            candidate.Objective = 1e3 + stabilityPenalty + ...
                1e4 * ncfViolation.^2 + ...
                1e4 * bandwidthViolation.^2;
        end
    end

    function bandwidth = trackingBandwidth(localController)
        allMargins = allmargin( ...
            localController * rthsParams.innerClosedLoop);
        crossoverFrequencies = allMargins.PMFrequency(:);
        phaseMargins = allMargins.PhaseMargin(:);
        validCrossovers = isfinite(crossoverFrequencies) & ...
            crossoverFrequencies > 0 & isfinite(phaseMargins);
        if any(validCrossovers)
            bandwidth = min(crossoverFrequencies(validCrossovers));
        else
            bandwidth = NaN;
        end
    end

    function [dampingRatio, selectedPole, discretePoles, spectralRadius] = ...
            coupledDamping(kpValue, kiValue)
        sampleMap = buildSampleMap(kpValue, kiValue);
        discretePoles = eig(sampleMap);
        spectralRadius = max(abs(discretePoles));
        continuousPoles = log(complex(discretePoles)) / ...
            rthsParams.sampleTime;
        frequencyHz = abs(imag(continuousPoles)) / (2 * pi);
        candidates = find(imag(continuousPoles) > 0 & ...
            isfinite(continuousPoles) & ...
            frequencyHz > 0.1 & ...
            frequencyHz < 0.45 / rthsParams.sampleTime);
        if isempty(candidates)
            dampingRatio = NaN;
            selectedPole = NaN;
            return
        end
        [~, firstModeIndex] = min(frequencyHz(candidates));
        selectedPole = continuousPoles(candidates(firstModeIndex));
        dampingRatio = -real(selectedPole) / abs(selectedPole);
    end

    function sampleMap = buildSampleMap(kpValue, kiValue)
        numericalOrder = size(rthsParams.numericalSubstructure.A, 1);
        innerOrder = size(rthsParams.innerClosedLoop.A, 1);
        phaseOrder = size(rthsParams.phaseLead.A, 1);
        mapOrder = numericalOrder + innerOrder + 1 + phaseOrder + 3;
        sampleMap = zeros(mapOrder);
        for stateIndex = 1:mapOrder
            basisState = zeros(mapOrder, 1);
            basisState(stateIndex) = 1;
            sampleMap(:, stateIndex) = oneSample( ...
                basisState, kpValue, kiValue, numericalOrder, ...
                innerOrder, phaseOrder);
        end
    end

    function nextState = oneSample(state, kpValue, kiValue, ...
            numericalOrder, innerOrder, phaseOrder)
        numericalEnd = numericalOrder;
        innerStart = numericalEnd + 1;
        innerEnd = innerStart + innerOrder - 1;
        integratorIndex = innerEnd + 1;
        phaseStart = integratorIndex + 1;
        phaseEnd = phaseStart + phaseOrder - 1;
        forceDelayIndex = phaseEnd + 1;
        previousXIndex = phaseEnd + 2;
        previousVelocityIndex = phaseEnd + 3;

        numericalState = state(1:numericalEnd);
        innerState = state(innerStart:innerEnd);
        integratorState = state(integratorIndex);
        phaseState = state(phaseStart:phaseEnd);
        forceDelay = state(forceDelayIndex);
        previousX = state(previousXIndex);
        previousVelocity = state(previousVelocityIndex);

        numericalSystem = rthsParams.numericalSubstructure;
        numericalInput = zeros(size(numericalSystem.B, 2), 1);
        numericalInput(rthsParams.forceInputIndex) = forceDelay;
        numericalOutput = numericalSystem.C * numericalState + ...
            numericalSystem.D * numericalInput;
        phaseInput = numericalOutput(rthsParams.displacementOutputIndex);
        phaseSystem = rthsParams.phaseLead;
        phaseOutput = phaseSystem.C * phaseState + ...
            phaseSystem.D * phaseInput;
        nextPhaseState = phaseSystem.A * phaseState + ...
            phaseSystem.B * phaseInput;

        currentX = innerOutput(innerState, integratorState, ...
            phaseOutput, kpValue);
        estimatedVelocity = (currentX - previousX) / ...
            rthsParams.sampleTime;
        estimatedAcceleration = (estimatedVelocity - previousVelocity) / ...
            rthsParams.sampleTime;
        measuredForce = alpha * specimen.stiffness * currentX + ...
            specimen.damping * estimatedVelocity + ...
            specimen.mass * estimatedAcceleration;

        continuousState = [numericalState; innerState; integratorState];
        nextContinuousState = rk4Step(continuousState, phaseOutput, ...
            forceDelay, kpValue, kiValue, numericalOrder, innerOrder);

        nextState = zeros(size(state));
        nextState(1:numericalEnd) = ...
            nextContinuousState(1:numericalEnd);
        nextState(innerStart:innerEnd) = ...
            nextContinuousState(innerStart:innerEnd);
        nextState(integratorIndex) = nextContinuousState(integratorIndex);
        nextState(phaseStart:phaseEnd) = nextPhaseState;
        nextState(forceDelayIndex) = measuredForce;
        nextState(previousXIndex) = currentX;
        nextState(previousVelocityIndex) = estimatedVelocity;
    end

    function nextState = rk4Step(state, phaseOutput, forceDelay, ...
            kpValue, kiValue, numericalOrder, innerOrder)
        dt = rthsParams.sampleTime;
        k1 = continuousDerivative(state, phaseOutput, forceDelay, ...
            kpValue, kiValue, numericalOrder, innerOrder);
        k2 = continuousDerivative(state + dt * k1 / 2, phaseOutput, ...
            forceDelay, kpValue, kiValue, numericalOrder, innerOrder);
        k3 = continuousDerivative(state + dt * k2 / 2, phaseOutput, ...
            forceDelay, kpValue, kiValue, numericalOrder, innerOrder);
        k4 = continuousDerivative(state + dt * k3, phaseOutput, ...
            forceDelay, kpValue, kiValue, numericalOrder, innerOrder);
        nextState = state + dt * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
    end

    function derivative = continuousDerivative(state, phaseOutput, ...
            forceDelay, kpValue, kiValue, numericalOrder, innerOrder)
        numericalState = state(1:numericalOrder);
        innerStart = numericalOrder + 1;
        innerEnd = innerStart + innerOrder - 1;
        innerState = state(innerStart:innerEnd);
        integratorState = state(innerEnd + 1);

        numericalSystem = rthsParams.numericalSubstructure;
        numericalInput = zeros(size(numericalSystem.B, 2), 1);
        numericalInput(rthsParams.forceInputIndex) = forceDelay;
        numericalDerivative = numericalSystem.A * numericalState + ...
            numericalSystem.B * numericalInput;

        [displacement, command] = innerOutput(innerState, ...
            integratorState, phaseOutput, kpValue);
        errorSignal = phaseOutput - displacement;
        innerSystem = rthsParams.innerClosedLoop;
        innerDerivative = innerSystem.A * innerState + ...
            innerSystem.B * command;
        derivative = [numericalDerivative; innerDerivative; ...
            kiValue * errorSignal];
    end

    function [displacement, command] = innerOutput( ...
            innerState, integratorState, phaseOutput, kpValue)
        innerSystem = rthsParams.innerClosedLoop;
        directTerm = innerSystem.D;
        numerator = innerSystem.C * innerState + ...
            directTerm * (kpValue * phaseOutput + integratorState);
        displacement = numerator / (1 + directTerm * kpValue);
        command = kpValue * (phaseOutput - displacement) + integratorState;
    end
end

function validateInputs(targetNCF, alpha, specimen, rthsParams)
if ~isnumeric(targetNCF) || ~isreal(targetNCF) || ...
        ~isscalar(targetNCF) || ~isfinite(targetNCF) || ...
        targetNCF <= 0 || targetNCF >= 1
    error('scripted:CustomPITarget', ...
        'targetNCF must be a finite scalar strictly between 0 and 1.')
end
if ~isnumeric(alpha) || ~isreal(alpha) || ~isscalar(alpha) || ...
        ~isfinite(alpha) || alpha < 0 || alpha > 1
    error('scripted:CustomPIAlpha', ...
        'alpha must be a finite scalar from 0 to 1.')
end
requiredSpecimen = {'mass', 'stiffness', 'damping'};
if ~isstruct(specimen) || ~all(isfield(specimen, requiredSpecimen)) || ...
        any(~isfinite([specimen.mass, specimen.stiffness, ...
        specimen.damping])) || any([specimen.mass, specimen.stiffness, ...
        specimen.damping] <= 0)
    error('scripted:CustomPISpecimen', ...
        'specimen must contain positive finite mass, stiffness, and damping.')
end
requiredRths = {'sampleTime', 'innerClosedLoop', ...
    'innerClosedLoopNCF', 'phaseLead', 'numericalSubstructure', ...
    'forceInputIndex', 'displacementOutputIndex'};
if ~isstruct(rthsParams) || ~all(isfield(rthsParams, requiredRths))
    error('scripted:CustomPIRTHS', ...
        'rthsParams is missing one or more required fields.')
end
if ~isscalar(rthsParams.sampleTime) || ...
        ~isfinite(rthsParams.sampleTime) || rthsParams.sampleTime <= 0
    error('scripted:CustomPISampleTime', ...
        'rthsParams.sampleTime must be positive and finite.')
end
if size(rthsParams.innerClosedLoop, 1) ~= 1 || ...
        size(rthsParams.innerClosedLoop, 2) ~= 1 || ...
        size(rthsParams.innerClosedLoopNCF, 1) ~= 1 || ...
        size(rthsParams.innerClosedLoopNCF, 2) ~= 1 || ...
        size(rthsParams.phaseLead, 1) ~= 1 || ...
        size(rthsParams.phaseLead, 2) ~= 1
    error('scripted:CustomPISISO', ...
        'The inner-loop and phase-lead systems must be SISO.')
end
if rthsParams.innerClosedLoop.Ts ~= 0 || ...
        rthsParams.innerClosedLoopNCF.Ts ~= 0 || ...
        rthsParams.numericalSubstructure.Ts ~= 0
    error('scripted:CustomPIContinuousPlants', ...
        'The inner-loop and numerical systems must be continuous-time.')
end
if rthsParams.phaseLead.Ts <= 0 || ...
        abs(rthsParams.phaseLead.Ts - rthsParams.sampleTime) > ...
        10 * eps(rthsParams.sampleTime)
    error('scripted:CustomPIPhaseLeadSampleTime', ...
        'The phase lead must be discrete at rthsParams.sampleTime.')
end
if ~isscalar(rthsParams.forceInputIndex) || ...
        rthsParams.forceInputIndex < 1 || ...
        rthsParams.forceInputIndex > size( ...
        rthsParams.numericalSubstructure, 2) || ...
        rthsParams.forceInputIndex ~= floor(rthsParams.forceInputIndex) || ...
        ~isscalar(rthsParams.displacementOutputIndex) || ...
        rthsParams.displacementOutputIndex < 1 || ...
        rthsParams.displacementOutputIndex > size( ...
        rthsParams.numericalSubstructure, 1) || ...
        rthsParams.displacementOutputIndex ~= ...
        floor(rthsParams.displacementOutputIndex)
    error('scripted:CustomPINumericalChannels', ...
        'The numerical input/output channel indices are invalid.')
end
end

function penalty = gainBoundPenalty(gains, lower, upper)
if any(~isfinite(gains))
    penalty = 1e6;
    return
end
lowViolation = max(lower - gains, 0) ./ lower;
highViolation = max(gains - upper, 0) ./ upper;
penalty = sum(lowViolation.^2 + highViolation.^2);
end

function candidate = emptyCandidate(method)
candidate = struct('Method', string(method), 'Kp', NaN, 'Ki', NaN, ...
    'NCF', NaN, 'Bandwidth', NaN, 'DampingRatio', -Inf, 'CoupledPole', NaN, ...
    'DiscretePoles', [], 'SpectralRadius', Inf, 'Stable', false, ...
    'Feasible', false, 'Objective', Inf, 'ExitFlag', NaN, ...
    'FunctionCount', NaN, 'ElapsedSeconds', NaN);
end

function selected = selectBetter(first, second)
if ~isfinite(first.Kp)
    selected = second;
    return
end
if ~isfinite(second.Kp)
    selected = first;
    return
end
if first.Feasible ~= second.Feasible
    if second.Feasible
        selected = second;
    else
        selected = first;
    end
    return
end
if first.Feasible
    if second.DampingRatio > first.DampingRatio
        selected = second;
    else
        selected = first;
    end
else
    firstViolation = first.Objective;
    secondViolation = second.Objective;
    if secondViolation < firstViolation
        selected = second;
    else
        selected = first;
    end
end
end
