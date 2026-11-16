function derivative = blk_numerical_dynamics(state, input, p)
%BLK_NUMERICAL_DYNAMICS Numerical-substructure StateSpace derivative.

derivative = p.A_ns * state + p.B_ns * input;
end
