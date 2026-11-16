 function metrics = scripted_phase_lead_metrics(p, controllerName, alpha)
%SCRIPTED_PHASE_LEAD_METRICS Exact sampled coupled-mode metrics for one PI.
%   This is the quiet tuning counterpart of SCRIPTED_COUPLED_DAMPING_TABLE.

if nargin < 3
    alpha = p.alpha_start;
end
controllerName = upper(char(controllerName));
switch controllerName
    case 'A'
        controller = p.controller_a;
        integratorIndex = 12;
        ncfMargin = blk_indicator_margin(alpha, 1, p);
    case 'B'
        controller = p.controller_b;
        integratorIndex = 13;
        ncfMargin = blk_indicator_margin(alpha, 0, p);
    case 'C'
        controller = p.controller_c;
        integratorIndex = 14;
        ncfMargin = blk_indicator_margin(alpha, 1, p, true);
    otherwise
        error('scripted:PhaseLeadController', ...
            'controllerName must be A, B, or C.')
end

stiffness = alpha * p.k_e;
damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
alphaPlant = feedback(scripted_inner_open_loop( ...
    p.m_e, damping, stiffness), 1);
if ~isstable(feedback(controller * alphaPlant, 1))
    ncfMargin = 0;
end

analysisParameters = p;
analysisParameters.options.modified = 1;
analysisParameters.options.consider_damage = 0;
analysisParameters.start_c = controllerName;
analysisParameters.start_a = controllerName == 'A';
analysisParameters.use_c = controllerName == 'C';
analysisParameters.switch_on = false;
analysisParameters.k_e = alpha * p.k_e;
analysisParameters.KE = alpha * p.KE;
analysisParameters.alpha_start = 1;

phaseStateCount = size(p.Apred, 1);
mapOrder = 12 + phaseStateCount + 3;
sampleMap = zeros(mapOrder);
for stateIndex = 1:mapOrder
    basisState = zeros(mapOrder, 1);
    basisState(stateIndex) = 1;
    sampleMap(:, stateIndex) = oneSample(basisState, ...
        analysisParameters, integratorIndex, phaseStateCount);
end

discretePoles = eig(sampleMap);
spectralRadius = max(abs(discretePoles));
continuousPoles = log(complex(discretePoles)) / p.dt_rths;
poleFrequencyHz = abs(imag(continuousPoles)) / (2 * pi);

referenceStiffness = p.KN + alpha * p.KE;
referenceEigenvalues = real(eig(referenceStiffness, p.M_r));
referenceEigenvalues = referenceEigenvalues( ...
    isfinite(referenceEigenvalues) & referenceEigenvalues > 0);
referenceFrequencies = sqrt(referenceEigenvalues) / (2 * pi);
selectedPole = NaN;
selectedFrequencyHz = NaN;
dampingRatio = NaN;
if ~isempty(referenceFrequencies)
    referenceFrequency = min(referenceFrequencies);
    candidates = find(imag(continuousPoles) > 0 & ...
        poleFrequencyHz > 0.5 * referenceFrequency & ...
        poleFrequencyHz < 2 * referenceFrequency);
    if ~isempty(candidates)
        [~, nearestIndex] = min(abs( ...
            poleFrequencyHz(candidates) - referenceFrequency));
        selectedIndex = candidates(nearestIndex);
        selectedPole = continuousPoles(selectedIndex);
        selectedFrequencyHz = poleFrequencyHz(selectedIndex);
        dampingRatio = -real(selectedPole) / abs(selectedPole);
    end
end

metrics = struct( ...
    'Controller', string(controllerName), ...
    'Alpha', alpha, ...
    'NCF', ncfMargin, ...
    'DampingRatio', dampingRatio, ...
    'DampingPercent', 100 * dampingRatio, ...
    'SelectedPole', selectedPole, ...
    'SelectedFrequencyHz', selectedFrequencyHz, ...
    'DiscretePoles', discretePoles, ...
    'SpectralRadius', spectralRadius, ...
    'Stable', isfinite(spectralRadius) && ...
        spectralRadius < 1 - 1e-9 && isfinite(dampingRatio));
end

function nextState = oneSample(state, p, integratorIndex, phaseStateCount)
continuousState = zeros(24, 1);
continuousState(1:11) = state(1:11);
continuousState(integratorIndex) = state(12);

phaseStart = 13;
phaseEnd = phaseStart + phaseStateCount - 1;
phaseState = state(phaseStart:phaseEnd);
forceDelay = state(phaseEnd + 1);
previousX = state(phaseEnd + 2);
previousDerivative = state(phaseEnd + 3);

numericalInput = [0; forceDelay; 0; 0];
numericalOutput = p.C_ns * continuousState(1:6) + ...
    p.D_ns * numericalInput;
yNumerical = numericalOutput(1);
phaseOutput = p.Cpred * phaseState + p.Dpred * yNumerical;
nextPhaseState = p.Apred * phaseState + p.Bpred * yNumerical;

measuredDerivative = (continuousState(10) - previousX) / p.dt_rths;
measuredSecondDerivative = ...
    (measuredDerivative - previousDerivative) / p.dt_rths;
measuredForce = blk_feedback_force(continuousState(10), ...
    measuredDerivative, measuredSecondDerivative, 1, p);

nextContinuousState = blk_rk4_step(continuousState, p.dt_rths, ...
    p.dt_rths, 0, 0, 0, phaseOutput, 0, 0, forceDelay, -1, 0, ...
    previousX, p);

nextState = zeros(size(state));
nextState(1:11) = nextContinuousState(1:11);
nextState(12) = nextContinuousState(integratorIndex);
nextState(phaseStart:phaseEnd) = nextPhaseState;
nextState(phaseEnd + 1) = blk_force_unit_delay(measuredForce);
nextState(phaseEnd + 2) = continuousState(10);
nextState(phaseEnd + 3) = measuredDerivative;
end
