function derivative = scripted_rhs(state, t, groundAcceleration, held, p)
%SCRIPTED_RHS Reference RHS with one explicit call per computational block.
% The fixed-step scheduler uses scripted_rhs_hot to avoid this tracing
% overhead; keep this implementation as the block-level equivalence path.

numericalState = state(1:6);
servoOutput = state(7);
servoRate = state(8);
actuatorForce = state(9);
displacement = state(10);
velocity = state(11);
integratorA = state(12);
integratorB = state(13);
integratorC = state(14);
referenceState = state(15:20);
specimenHystereticState = state(21);
referenceHystereticState = state(22);

alpha = blk_damage_switch(t, p.options.consider_damage, p.alpha_min, ...
    p.alpha_start);
measuredDisplacement = p.Gsnsr_DT * displacement + held.noise_displacement;
errorSignal = held.phase_output - measuredDisplacement;
[controllerA, integratorDerivativeA] = blk_pi_controller(errorSignal, ...
    integratorA, p.pi_a_kp, p.pi_a_ki);
[controllerB, integratorDerivativeB] = blk_pi_controller(errorSignal, ...
    integratorB, p.pi_b_kp, p.pi_b_ki);
[controllerC, integratorDerivativeC] = blk_pi_controller(errorSignal, ...
    integratorC, p.pi_c_kp, p.pi_c_ki);
beta = blk_beta_value(held.switch_target, t, held.event_time, ...
    p.start_c, p.switch_on, p.switch_transition_duration);
selectedController = blk_controller_select(controllerA, controllerB, ...
    controllerC, beta, p.start_c);
command = blk_control_switch(held.tracking_output, selectedController, ...
    p.options.modified);

servoInput = p.gain * command - displacement;
servoAcceleration = blk_servo_valve_dynamics(servoInput, servoOutput, ...
    servoRate, p);
estimatedVelocity = blk_derivative_minor(displacement, t, held);
actuatorDerivative = blk_actuator_dynamics(servoOutput, ...
    estimatedVelocity, actuatorForce, p);
structureAcceleration = blk_experimental_acceleration(actuatorForce, ...
    displacement, velocity, alpha, specimenHystereticState, p);

numericalInput = [groundAcceleration; held.force_delay; 0; 0];
numericalDerivative = blk_numerical_dynamics(numericalState, ...
    numericalInput, p);
referenceDerivative = blk_reference_dynamics(referenceState, ...
    groundAcceleration, alpha, referenceHystereticState, p);
% The scheduler updates z and E once per major sample using
% blk_bouc_wen_update; they remain held throughout the RK4 minor stages.
specimenHystereticDerivative = 0;
referenceHystereticDerivative = 0;
specimenEnergyDerivative = 0;
referenceEnergyDerivative = 0;

derivative = [numericalDerivative; servoRate; servoAcceleration; ...
    actuatorDerivative; velocity; structureAcceleration; ...
    integratorDerivativeA; integratorDerivativeB; integratorDerivativeC; ...
    referenceDerivative; specimenHystereticDerivative; ...
    referenceHystereticDerivative; specimenEnergyDerivative; ...
    referenceEnergyDerivative];
end
