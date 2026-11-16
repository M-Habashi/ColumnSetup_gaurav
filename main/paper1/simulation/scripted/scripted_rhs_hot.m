function derivative = scripted_rhs_hot(state, t, groundAcceleration, ...
        phaseOutput, trackingOutput, noiseDisplacement, forceDelay, ...
        switchTarget, eventTime, estimatedVelocity, p)
%SCRIPTED_RHS_HOT Allocation-light RHS used by the fixed-step scheduler.
% The standalone blk_*.m functions remain the readable reference mapping.
% This hot path evaluates the same block equations inline to avoid repeated
% function dispatch and held-structure field access at every RK4 stage.

servoOutput = state(7);
servoRate = state(8);
actuatorForce = state(9);
displacement = state(10);
velocity = state(11);
integratorA = state(12);
integratorB = state(13);
integratorC = state(14);
specimenHystereticState = state(21);
referenceHystereticState = state(22);
% The major-sample scheduler updates and holds z/E around every RK4 step.
specimenHystereticDerivative = 0;
referenceHystereticDerivative = 0;
specimenEnergyDerivative = 0;
referenceEnergyDerivative = 0;

% blk_damage_switch / blk_alpha_profile
if p.options.consider_damage == 1
    time = max(t, 0);
    intermediateAlpha = min(0.75, p.alpha_start);
    term1 = (p.alpha_start - intermediateAlpha) ./ ...
        (1 + exp(-2 .* (time - 8)));
    term2 = (intermediateAlpha - p.alpha_min) ./ ...
        (1 + exp(-(time - 16)));
    alpha = p.alpha_start - term1 - term2;
else
    alpha = p.alpha_start;
end

% blk_sensor_output and all three blk_pi_controller instances
measuredDisplacement = p.Gsnsr_DT * displacement + noiseDisplacement;
errorSignal = phaseOutput - measuredDisplacement;
controllerA = p.pi_a_kp * errorSignal + integratorA;
integratorDerivativeA = p.pi_a_ki * errorSignal;
controllerB = p.pi_b_kp * errorSignal + integratorB;
integratorDerivativeB = p.pi_b_ki * errorSignal;
controllerC = p.pi_c_kp * errorSignal + integratorC;
integratorDerivativeC = p.pi_c_ki * errorSignal;

% blk_beta_value, blk_controller_blend, and blk_control_switch. start_a and
% switch_on are cached by scripted_build_trial to keep this hot path scalar.
if p.use_c
    beta = NaN;
elseif p.start_a
    beta = 1;
else
    beta = 0;
end
if ~p.use_c && p.switch_on && switchTarget >= 0
    blend = min(max((t - eventTime) / ...
        p.switch_transition_duration, 0), 1);
    if switchTarget == 1
        beta = blend;
    else
        beta = 1 - blend;
    end
end
if p.use_c
    selectedController = controllerC;
else
    selectedController = beta * controllerA + (1 - beta) * controllerB;
end
if -p.options.modified >= 0
    command = trackingOutput;
else
    command = selectedController;
end

% blk_servo_valve_dynamics, blk_derivative_minor,
% blk_actuator_dynamics, and blk_experimental_acceleration
servoInput = p.gain * command - displacement;
servoAcceleration = p.a1_beta0 * servoInput - ...
    p.beta1 * servoRate - p.beta2 * servoOutput;
actuatorDerivative = servoOutput - p.a2 * estimatedVelocity - ...
    p.a3 * actuatorForce;
if p.options.consider_damage == 2
    specimenRestoringForce = p.k_x_specimen * displacement + ...
        p.k_w_specimen * specimenHystereticState;
else
    specimenRestoringForce = alpha * p.k_e * displacement;
end
structureAcceleration = (actuatorForce - p.c_e * velocity - ...
    specimenRestoringForce) / p.m_e;

% blk_numerical_dynamics and blk_reference_dynamics. Retain the original
% four-element input multiplication so its floating-point summation order
% stays aligned with the reference implementation.
numericalInput = [groundAcceleration; forceDelay; 0; 0];
numericalDerivative = p.A_ns * state(1:6) + p.B_ns * numericalInput;
if p.options.consider_damage == 0
    referenceDerivative = p.AA_R * state(15:20) + ...
        p.BB_R * groundAcceleration;
else
    referenceDisplacement = state(15:17);
    referenceVelocity = state(18:20);
    if p.options.consider_damage == 2
        referenceRestoringForce = ...
            p.k_x_reference * referenceDisplacement(1) + ...
            p.k_w_reference * referenceHystereticState;
        referenceInternalForce = p.KN * referenceDisplacement + ...
            p.C_r * referenceVelocity;
        referenceInternalForce(1) = referenceInternalForce(1) + ...
            referenceRestoringForce;
    else
        referenceInternalForce = (p.KN + alpha * p.KE) * ...
            referenceDisplacement + p.C_r * referenceVelocity;
    end
    referenceAcceleration = -(p.M_r \ referenceInternalForce) - ...
        ones(p.n, 1) * groundAcceleration;
    referenceDerivative = [referenceVelocity; referenceAcceleration];
end

derivative = zeros(size(state));
derivative(1:6) = numericalDerivative;
derivative(7) = servoRate;
derivative(8) = servoAcceleration;
derivative(9) = actuatorDerivative;
derivative(10) = velocity;
derivative(11) = structureAcceleration;
derivative(12) = integratorDerivativeA;
derivative(13) = integratorDerivativeB;
derivative(14) = integratorDerivativeC;
derivative(15:20) = referenceDerivative;
derivative(21) = specimenHystereticDerivative;
derivative(22) = referenceHystereticDerivative;
derivative(23) = specimenEnergyDerivative;
derivative(24) = referenceEnergyDerivative;
end
