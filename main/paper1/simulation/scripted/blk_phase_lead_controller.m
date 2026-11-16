function [output, nextState] = blk_phase_lead_controller(input, state, p)
%BLK_PHASE_LEAD_CONTROLLER A/D, discrete state-space, and D/A blocks.

sampledInput = blk_ad_converter(input, p);
discreteOutput = p.Cpred * state + p.Dpred * sampledInput;
nextState = p.Apred * state + p.Bpred * sampledInput;
output = blk_da_converter(discreteOutput, p);
end
