function u_control = referenceControlDisplacement(fem_ref, floor_response)
%REFERENCECONTROLDISPLACEMENT Reconstruct full-FEM control-point displacement.
% Units: floor_response/u_control [m].

assembly = fem_ref.assembly;
retained = assembly.retained_dofs(:);
internal = assembly.internal_dofs(:);
K_full = assembly.K_full;
q_internal = -(K_full(internal, internal) ...
    \(K_full(internal, retained)*floor_response'))';

n = size(floor_response, 1);
q = zeros(n, size(K_full, 1));
q(:, retained) = floor_response;
q(:, internal) = q_internal;

height = fem_ref.experimental_column.height;
story_height = fem_ref.frame.story_height;
xi = height/story_height;
N1 = 1 - 3*xi^2 + 2*xi^3;
N2 = story_height*(xi - 2*xi^2 + xi^3);
N3 = 3*xi^2 - 2*xi^3;
N4 = story_height*(-xi^2 + xi^3);

joint_rotation = assembly.joint_rotation_dofs;
theta_base = getDofSignal(q, joint_rotation(1, 1));
theta_floor = getDofSignal(q, joint_rotation(1, 2));
u_control = N1*zeros(n, 1) - N2*theta_base ...
    + N3*floor_response(:, 1) - N4*theta_floor;
end

function value = getDofSignal(q, dof)
if dof > 0
    value = q(:, dof);
else
    value = zeros(size(q, 1), 1);
end
end
