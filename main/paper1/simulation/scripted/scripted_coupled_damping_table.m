function results = scripted_coupled_damping_table(p)
%SCRIPTED_COUPLED_DAMPING_TABLE Report robustness at alpha_start.
%   Coupled damping comes from a one-sample small-signal map of the exact
%   scripted scheduler. A/D and D/A nonlinearities, noise, and either
%   damage model are omitted. NCF follows the convention used by NCF.M.

controllerNames = {'A'; 'B'; 'C'};
ncfMargin = nan(3, 1);
coupledDamping = nan(3, 1);
integratorIndices = [12; 13; 14];

for controllerIndex = 1:3
    controllerName = controllerNames{controllerIndex};
    ncfMargin(controllerIndex) = ...
        ncfAtAlpha(p, controllerName, p.alpha_start);
    coupledDamping(controllerIndex) = ...
        firstCoupledMode(p, integratorIndices(controllerIndex), ...
        controllerName, p.alpha_start);
end

fprintf('\nNominal frozen-stiffness robustness estimate\n')
if p.options.modified ~= 1
    fprintf(['A/B/C are hypothetical here because modified=0 executes ', ...
        'the original tracking controller.\n'])
end
fprintf(['Damage is excluded; NCF and coupled damping are evaluated ', ...
    'at alpha_start = %.3g.\n'], p.alpha_start)

results = table(string(controllerNames), ncfMargin, ...
    100 * coupledDamping, ...
    'VariableNames', {'Controller', 'NCF_alpha_start', ...
    'Damping_alpha_start_pct'});
disp(results)
end

function margin = ncfAtAlpha(p, controllerName, alpha)
if controllerName == 'A'
    controller = p.controller_a;
    margin = blk_indicator_margin(alpha, 1, p);
elseif controllerName == 'B'
    controller = p.controller_b;
    margin = blk_indicator_margin(alpha, 0, p);
else
    controller = p.controller_c;
    margin = blk_indicator_margin(alpha, 1, p, true);
end

% Match ncf.m: its surrogate preserves z_e as stiffness changes. The
% executed specimen instead keeps its viscous damping coefficient fixed.
stiffness = alpha * p.k_e;
damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
alphaPlant = feedback(scripted_inner_open_loop(p.m_e, damping, ...
    stiffness), 1);
if ~isstable(feedback(controller * alphaPlant, 1))
    margin = 0;
end
end

function dampingRatio = firstCoupledMode( ...
        p, integratorIndex, controllerName, operatingAlpha)
analysisParameters = p;
analysisParameters.options.modified = 1;
analysisParameters.options.consider_damage = 0;
analysisParameters.start_c = controllerName;
analysisParameters.start_a = controllerName == 'A';
analysisParameters.use_c = controllerName == 'C';
analysisParameters.switch_on = false;

% Freeze the executed stiffness at the requested absolute alpha. The
% numerical partition and viscous damping remain unchanged, as at runtime.
analysisParameters.k_e = operatingAlpha * p.k_e;
analysisParameters.KE = operatingAlpha * p.KE;
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
continuousPoles = log(discretePoles) / p.dt_rths;
poleFrequencyHz = abs(imag(continuousPoles)) / (2 * pi);

referenceStiffness = p.KN + operatingAlpha * p.KE;
referenceEigenvalues = real(eig(referenceStiffness, p.M_r));
referenceEigenvalues = referenceEigenvalues( ...
    isfinite(referenceEigenvalues) & referenceEigenvalues > 0);
referenceFrequencies = sqrt(referenceEigenvalues) / (2 * pi);
if isempty(referenceFrequencies)
    dampingRatio = NaN;
    return
end
referenceFrequency = min(referenceFrequencies);

candidates = find(imag(continuousPoles) > 0 & ...
    poleFrequencyHz > 0.5 * referenceFrequency & ...
    poleFrequencyHz < 2 * referenceFrequency);
if isempty(candidates)
    dampingRatio = NaN;
    return
end

[~, nearestIndex] = min(abs( ...
    poleFrequencyHz(candidates) - referenceFrequency));
selectedPole = continuousPoles(candidates(nearestIndex));
dampingRatio = -real(selectedPole) / abs(selectedPole);
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

% Use the linear state-space phase-lead equations directly. Converter
% nonlinearities are intentionally excluded from this small-signal map.
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
