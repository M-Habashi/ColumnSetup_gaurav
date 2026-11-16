function output = blk_derivative_major(input, previousInput, dt, tick)
%BLK_DERIVATIVE_MAJOR Major-step output of a Simulink Derivative block.

if tick == 0
    output = 0;
else
    output = (input - previousInput) / dt;
end
end
