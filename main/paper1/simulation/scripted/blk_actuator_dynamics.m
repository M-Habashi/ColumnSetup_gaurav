function derivative = blk_actuator_dynamics( ...
        servoOutput, estimatedVelocity, actuatorForce, p)
%BLK_ACTUATOR_DYNAMICS CSI feedback and first-order actuator block.

derivative = servoOutput - p.a2 * estimatedVelocity - p.a3 * actuatorForce;
end
