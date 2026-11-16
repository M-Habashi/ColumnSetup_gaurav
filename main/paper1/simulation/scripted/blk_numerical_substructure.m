function output = blk_numerical_substructure(state, input, p)
%BLK_NUMERICAL_SUBSTRUCTURE Continuous state-space output block.

output = p.C_ns * state + p.D_ns * input;
end
