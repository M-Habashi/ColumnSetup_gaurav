function force = blk_feedback_force( ...
        displacement, velocity, acceleration, alpha, p, hystereticState)
%BLK_FEEDBACK_FORCE Experimental mass, damping, and stiffness products.

if nargin < 6
    hystereticState = 0;
end
if p.options.consider_damage == 2
    stiffnessForce = blk_bouc_wen_restoring_force(displacement, ...
        hystereticState, p.alpha_start * p.KE(1, 1), p);
else
    stiffnessForce = alpha * p.KE(1, 1) * displacement;
end
dampingForce = p.CE(1, 1) * velocity;
inertiaForce = p.ME(1, 1) * acceleration;
force = stiffnessForce + dampingForce + inertiaForce;
end
