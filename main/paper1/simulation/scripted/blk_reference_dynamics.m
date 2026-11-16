function [derivative, restoringForce] = blk_reference_dynamics( ...
        state, groundAcceleration, alpha, hystereticState, p)
%BLK_REFERENCE_DYNAMICS Reference response used during time simulation.

if nargin == 3
    p = alpha;
    alpha = p.alpha_start;
    hystereticState = 0;
end
displacement = state(1:p.n);
velocity = state(p.n + 1:2 * p.n);

if p.options.consider_damage == 0
    restoringForce = p.alpha_start * p.KE(1, 1) * displacement(1);
    derivative = p.AA_R * state + p.BB_R * groundAcceleration;
    return
elseif p.options.consider_damage == 2
    restoringForce = blk_bouc_wen_restoring_force(displacement(1), ...
        hystereticState, p.alpha_start * p.KE(1, 1), p);
    internalForce = p.KN * displacement + p.C_r * velocity;
    internalForce(1) = internalForce(1) + restoringForce;
    acceleration = -(p.M_r \ internalForce) - ...
        ones(p.n, 1) * groundAcceleration;
else
    stiffness = p.KN + alpha * p.KE;
    restoringForce = alpha * p.KE(1, 1) * displacement(1);
    acceleration = -(p.M_r \ (stiffness * displacement + ...
        p.C_r * velocity)) - ones(p.n, 1) * groundAcceleration;
end

derivative = [velocity; acceleration];
end
