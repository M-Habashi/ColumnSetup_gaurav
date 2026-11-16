function [output, nextState] = blk_tracking_controller(input, state, p)
%BLK_TRACKING_CONTROLLER Original discrete PI controller chain.

sampledInput = blk_ad_converter(input, p);
discreteOutput = p.Ccd * state + p.Dcd * sampledInput;
nextState = p.Acd * state + p.Bcd * sampledInput;
output = blk_da_converter(discreteOutput, p);
end
