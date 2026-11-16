function acceleration = blk_servo_valve_dynamics(input, output, rate, p)
%BLK_SERVO_VALVE_DYNAMICS Second-order servo-valve Transfer Fcn block.

acceleration = p.a1_beta0 * input - p.beta1 * rate - p.beta2 * output;
end
