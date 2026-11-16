function nextState = blk_rk4_step(state, t, dt, ground0, groundHalf, ...
        ground1, phaseOutput, trackingOutput, noiseDisplacement, ...
        forceDelay, switchTarget, eventTime, previousX, p)
%BLK_RK4_STEP Classical fixed-step ode4 block scheduler.

currentX = state(10);
previousTime = max(0, t - dt);
if t > previousTime
    estimatedVelocity1 = (currentX - previousX) / (t - previousTime);
else
    estimatedVelocity1 = 0;
end

k1 = scripted_rhs_hot(state, t, ground0, phaseOutput, trackingOutput, ...
    noiseDisplacement, forceDelay, switchTarget, eventTime, ...
    estimatedVelocity1, p);

halfTime = t + dt / 2;
halfElapsed = halfTime - t;
stageState = state + dt * k1 / 2;
estimatedVelocity2 = (stageState(10) - currentX) / halfElapsed;
k2 = scripted_rhs_hot(stageState, halfTime, groundHalf, phaseOutput, ...
    trackingOutput, noiseDisplacement, forceDelay, switchTarget, ...
    eventTime, estimatedVelocity2, p);

stageState = state + dt * k2 / 2;
estimatedVelocity3 = (stageState(10) - currentX) / halfElapsed;
k3 = scripted_rhs_hot(stageState, halfTime, groundHalf, phaseOutput, ...
    trackingOutput, noiseDisplacement, forceDelay, switchTarget, ...
    eventTime, estimatedVelocity3, p);

endTime = t + dt;
endElapsed = endTime - t;
stageState = state + dt * k3;
estimatedVelocity4 = (stageState(10) - currentX) / endElapsed;
k4 = scripted_rhs_hot(stageState, endTime, ground1, phaseOutput, ...
    trackingOutput, noiseDisplacement, forceDelay, switchTarget, ...
    eventTime, estimatedVelocity4, p);

nextState = state + dt * (k1 + 2 * k2 + 2 * k3 + k4) / 6;
end
