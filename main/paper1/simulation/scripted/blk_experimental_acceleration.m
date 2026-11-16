function acceleration = blk_experimental_acceleration( ...
        actuatorForce, displacement, velocity, alpha, hystereticState, p)
%BLK_EXPERIMENTAL_ACCELERATION Legacy or Bouc-Wen specimen dynamics.

if nargin == 5
    p = hystereticState;
    hystereticState = 0;
end
if p.options.consider_damage == 2
    restoringForce = blk_bouc_wen_restoring_force(displacement, ...
        hystereticState, p.alpha_start * p.k_e, p);
else
    restoringForce = alpha * p.k_e * displacement;
end
acceleration = (actuatorForce - p.c_e * velocity - restoringForce) / p.m_e;
end
