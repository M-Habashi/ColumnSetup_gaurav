function output = blk_derivative_minor(input, t, held)
%BLK_DERIVATIVE_MINOR Derivative-block slope during ode4 minor stages.

elapsed = t - held.step_time;
if elapsed > 0
    output = (input - held.current_x) / elapsed;
elseif held.step_time > held.previous_time
    output = (held.current_x - held.previous_x) / ...
        (held.step_time - held.previous_time);
else
    output = 0;
end
end
