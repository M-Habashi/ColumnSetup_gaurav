function out = scripted_engine(p, groundInput)
%SCRIPTED_ENGINE Execute the block graph with a fixed-step RK4 scheduler.

if nargin < 2
    [t, groundMajor, groundHalf] = blk_ground_acceleration(p);
else
    requiredFields = {'t', 'major', 'half'};
    if ~isstruct(groundInput) || ~all(isfield(groundInput, requiredFields))
        error('scripted:GroundInput', ...
            'groundInput must contain t, major, and half fields.');
    end
    t = groundInput.t(:);
    groundMajor = groundInput.major(:);
    groundHalf = groundInput.half(:);
    if numel(t) < 2 || numel(groundMajor) ~= numel(t) || ...
            numel(groundHalf) ~= numel(t) - 1 || ...
            any(~isfinite(t)) || any(~isfinite(groundMajor)) || ...
            any(~isfinite(groundHalf)) || ...
            any(abs(diff(t) - p.dt_rths) > 10 * eps(p.dt_rths))
        error('scripted:GroundInput', ...
            ['Input samples must be finite and uniformly spaced at ', ...
             'p.dt_rths; half must have one fewer sample than t.']);
    end
end
sampleCount = numel(t);
noiseDisplacement = blk_sensor_noise(sampleCount, p.noise_seed, ...
    p.rms_noise_DT, p.dt_rths);
noiseForce = blk_sensor_noise(sampleCount, p.noise_seed, ...
    p.rms_noise_FT, p.dt_rths);

% Scheduler state: continuous numerical(6), servo output/rate(2), actuator
% force, experimental displacement/velocity(2), PI integrators(3), and
% reference(6), followed by major-sample-held Bouc-Wen z (2) and E (2).
state = zeros(24, 1);
phaseState = zeros(size(p.Apred, 1), 1);
trackingState = zeros(size(p.Acd, 1), 1);
forceDelay = 0;
previousX = 0;
previousReferenceX = 0;
previousDerivative = 0;
referenceDamageParameters = p;
referenceDamageParameters.delta_nu = p.reference_delta_nu;
referenceDamageParameters.delta_eta = p.reference_delta_eta;

numData = zeros(sampleCount, 9);
xMeasuredData = zeros(sampleCount, 1);
forceData = zeros(sampleCount, 1);
alphaData = zeros(sampleCount, 1);
indicatorData = zeros(sampleCount, 1);
indicatorAData = zeros(sampleCount, 1);
indicatorBData = zeros(sampleCount, 1);
betaData = zeros(sampleCount, 1);
activeAData = zeros(sampleCount, 1);
switchEventData = zeros(sampleCount, 1);
servoData = zeros(sampleCount, 1);
xInternalData = zeros(sampleCount, 1);
velocityData = zeros(sampleCount, 1);
piAData = zeros(sampleCount, 1);
piBData = zeros(sampleCount, 1);
piCData = zeros(sampleCount, 1);
selectedPIData = zeros(sampleCount, 1);
controlErrorData = zeros(sampleCount, 1);
phaseOutputData = zeros(sampleCount, 1);
referenceData = zeros(sampleCount, 3 * p.n);
boucWenData = zeros(sampleCount, 2);
boucWenEnergyData = zeros(sampleCount, 2);
restoringForceData = zeros(sampleCount, 2);
lseStiffnessData = nan(sampleCount, 1);

indicatorHeld = 0;
indicatorPending = 0;
indicatorAHeld = 0;
indicatorAPending = 0;
indicatorBHeld = 0;
indicatorBPending = 0;
previousIndicatorA = 0;
activeA = p.start_a;
switchTarget = -1;
eventTime = 0;
aboveReturnThresholdStart = NaN;
lseState = [];

for sample = 1:sampleCount
    tick = sample - 1;
    timeNow = t(sample);
    alphaNow = blk_damage_switch(timeNow, p.options.consider_damage, ...
        p.alpha_min, p.alpha_start);
    if sample > 1 && p.options.consider_damage == 2
        [state(21), state(23)] = blk_bouc_wen_update( ...
            state(10), previousX, state(21), state(23), p);
        [state(22), state(24)] = blk_bouc_wen_update( ...
            state(15), previousReferenceX, state(22), state(24), ...
            referenceDamageParameters);
    end
    xMeasured = blk_sensor_output(state(10), p.Gsnsr_DT, ...
        noiseDisplacement(sample));
    lseStiffness = NaN;
    if p.options.consider_damage == 2
        specimenRestoringForce = blk_bouc_wen_restoring_force( ...
            state(10), state(21), p.alpha_start * p.k_e, p);
        [alphaNow, lseStiffness, lseState] = ...
            blk_moving_lse_stiffness( ...
            xMeasured, specimenRestoringForce, lseState, p);
    end

    switchEventNow = 0;
    if tick > 0 && mod(tick, 100) == 0
        indicatorHeld = indicatorPending;
        indicatorAHeld = indicatorAPending;
        indicatorBHeld = indicatorBPending;
        [activeA, switchTarget, eventTime, aboveReturnThresholdStart, ...
            switched] = blk_controller_switch_update( ...
            activeA, switchTarget, eventTime, aboveReturnThresholdStart, ...
            previousIndicatorA, indicatorAHeld, timeNow, p.b_th, ...
            p.b_th_2, p.switch_back_hold, p.switch_on && ~p.use_c);
        if switched
            switchEventNow = 2 * double(activeA) - 1;
        end
        previousIndicatorA = indicatorAHeld;
    end
    betaNow = blk_beta_value(switchTarget, timeNow, eventTime, ...
        p.start_c, p.switch_on, p.switch_transition_duration);
    if mod(tick, 100) == 0
        indicatorPending = blk_indicator_margin(alphaNow, betaNow, p, ...
            p.use_c);
        indicatorAPending = blk_indicator_margin(alphaNow, 1, p);
        indicatorBPending = blk_indicator_margin(alphaNow, 0, p);
    end

    numericalInput = [groundMajor(sample); forceDelay; 0; 0];
    numericalOutput = blk_numerical_substructure(state(1:6), ...
        numericalInput, p);
    yNumerical = numericalOutput(1);

    [phaseOutput, nextPhaseState] = blk_phase_lead_controller( ...
        yNumerical, phaseState, p);
    trackingError = phaseOutput - xMeasured;
    [trackingOutput, nextTrackingState] = blk_tracking_controller( ...
        trackingError, trackingState, p);

    measuredDerivative = blk_derivative_major(state(10), previousX, ...
        p.dt_rths, tick);
    measuredSecondDerivative = blk_derivative_major(measuredDerivative, ...
        previousDerivative, p.dt_rths, tick);
    feedbackForce = blk_feedback_force(state(10), measuredDerivative, ...
        measuredSecondDerivative, alphaNow, p, state(21));
    measuredForce = blk_sensor_output(feedbackForce, p.Gsnsr_FT, ...
        noiseForce(sample));

    [referenceDerivative, referenceRestoringForce] = ...
        blk_reference_dynamics(state(15:20), groundMajor(sample), ...
        alphaNow, state(22), p);
    referenceData(sample, :) = [state(15:20).', ...
        referenceDerivative(p.n + 1:2 * p.n).'];
    if p.options.consider_damage ~= 2
        specimenRestoringForce = alphaNow * p.k_e * state(10);
    end

    numData(sample, :) = numericalOutput.';
    xMeasuredData(sample) = xMeasured;
    forceData(sample) = state(9);
    alphaData(sample) = alphaNow;
    indicatorData(sample) = indicatorHeld;
    indicatorAData(sample) = indicatorAHeld;
    indicatorBData(sample) = indicatorBHeld;
    betaData(sample) = betaNow;
    activeAData(sample) = double(activeA);
    switchEventData(sample) = switchEventNow;
    servoData(sample) = state(7);
    xInternalData(sample) = state(10);
    velocityData(sample) = measuredDerivative;
    phaseOutputData(sample) = phaseOutput;
    piAData(sample) = p.pi_a_kp * trackingError + state(12);
    piBData(sample) = p.pi_b_kp * trackingError + state(13);
    piCData(sample) = p.pi_c_kp * trackingError + state(14);
    if p.use_c
        selectedPIData(sample) = piCData(sample);
    else
        selectedPIData(sample) = betaNow * piAData(sample) + ...
            (1 - betaNow) * piBData(sample);
    end
    controlErrorData(sample) = trackingError;
    boucWenData(sample, :) = state(21:22).';
    boucWenEnergyData(sample, :) = 1e6 * state(23:24).';
    restoringForceData(sample, :) = ...
        [specimenRestoringForce, referenceRestoringForce];
    lseStiffnessData(sample) = lseStiffness;

    if sample < sampleCount
        state = blk_rk4_step(state, timeNow, p.dt_rths, ...
            groundMajor(sample), groundHalf(sample), ...
            groundMajor(sample + 1), phaseOutput, trackingOutput, ...
            noiseDisplacement(sample), forceDelay, switchTarget, ...
            eventTime, previousX, p);
    end

    phaseState = nextPhaseState;
    trackingState = nextTrackingState;
    forceDelay = blk_force_unit_delay(measuredForce);
    previousX = xInternalData(sample);
    previousReferenceX = referenceData(sample, 1);
    previousDerivative = measuredDerivative;
end

out.t = t;
out.EQ_input = groundMajor;
out.X_m = timeseries(xMeasuredData, t);
out.Num_resp = timeseries(numData, t);
out.Force_act = timeseries(forceData, t);
out.alpha = timeseries(alphaData, t);
out.indicator = timeseries(indicatorData, t);
out.indicator_a = timeseries(indicatorAData, t);
out.indicator_b = timeseries(indicatorBData, t);
out.beta = timeseries(betaData, t);
out.active_controller_a = timeseries(activeAData, t);
out.switch_event = timeseries(switchEventData, t);
out.PI_command = timeseries(selectedPIData, t);
if p.options.consider_damage == 0
    out.Ref_Resp = blk_reference_response(p.sys_r, groundMajor, t);
else
    out.Ref_Resp = referenceData;
end
out.BoucWen = timeseries(boucWenData, t);
out.BoucWen_energy = timeseries(boucWenEnergyData, t);
out.Restoring_force = timeseries(restoringForceData, t);
out.LSE_stiffness = timeseries(lseStiffnessData, t);
out.block_signals = struct('servo', servoData, 'x_internal', xInternalData, ...
    'velocity', velocityData, 'pi_a', piAData, 'pi_b', piBData, ...
    'pi_c', piCData, ...
    'phase_output', phaseOutputData, ...
    'control_error', controlErrorData, 'indicator_beta_1', indicatorAData, ...
    'indicator_beta_0', indicatorBData, ...
    'controller_beta', betaData, 'active_controller_a', activeAData, ...
    'switch_event', switchEventData, ...
    'bouc_wen_specimen', boucWenData(:, 1), ...
    'bouc_wen_reference', boucWenData(:, 2), ...
    'bouc_wen_energy_specimen_mm2', boucWenEnergyData(:, 1), ...
    'bouc_wen_energy_reference_mm2', boucWenEnergyData(:, 2), ...
    'specimen_restoring_force', restoringForceData(:, 1), ...
    'reference_restoring_force', restoringForceData(:, 2), ...
    'lse_stiffness_n_per_m', lseStiffnessData);
end
