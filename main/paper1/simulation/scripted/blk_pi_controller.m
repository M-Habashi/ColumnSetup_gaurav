function [output, stateDerivative] = blk_pi_controller( ...
        input, integratorState, proportionalGain, integralGain)
%BLK_PI_CONTROLLER Continuous PI Transfer Fcn block.

output = proportionalGain * input + integratorState;
stateDerivative = integralGain * input;
end
