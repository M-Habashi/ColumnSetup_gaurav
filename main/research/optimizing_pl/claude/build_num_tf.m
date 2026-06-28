function num_tf = build_num_tf(fem, dt)
%BUILD_NUM_TF Discrete numerical-substructure transfer function force -> dd.
% Mirrors the local numericalSubstructureDiscrete used by vHS.m and
% optimize_vHS_phase_lead.m so this research folder is self-contained.
% Units: input measured force [N], output interface command dd [mm].
% Damping is the Rayleigh matrix from femDampingMatrix(fem.ref, fem).

fem_num = fem.num;
fem_ref = fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K = fem_num.K;
K_ff = K(floor_dofs, floor_dofs);
K_fi = K(floor_dofs, interface_dof);
K_if = K(interface_dof, floor_dofs);
K_ii = K(interface_dof, interface_dof);

hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.force_sign = 1.0;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
hs.C = femDampingMatrix(fem_ref, fem);

n = hs.n_floor; h = dt; beta = 1/4; gamma = 1/2;
a0 = 1/(beta*h^2); a1 = gamma/(beta*h); a2 = 1/(beta*h);
a3 = 1/(2*beta)-1; a4 = gamma/beta-1; a5 = h*(gamma/(2*beta)-1);
effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
solver = effective_stiffness\eye(n);
Su = solver*[a0*hs.M+a1*hs.C, a2*hs.M+a4*hs.C, a3*hs.M+a5*hs.C];
Sf = solver*(hs.force_to_floor*hs.force_sign);
A = zeros(3*n); Bf = zeros(3*n, 1);
A(1:n, :) = Su; Bf(1:n) = Sf;
A(2*n+1:3*n, :) = a0*(Su-[eye(n), zeros(n), zeros(n)]) ...
    - a2*[zeros(n), eye(n), zeros(n)] - a3*[zeros(n), zeros(n), eye(n)];
Bf(2*n+1:3*n) = a0*Sf;
A(n+1:2*n, :) = [zeros(n), eye(n), zeros(n)] ...
    + h*((1-gamma)*[zeros(n), zeros(n), eye(n)] + gamma*A(2*n+1:3*n, :));
Bf(n+1:2*n) = h*gamma*Bf(2*n+1:3*n);
C = 1000*(hs.interface_from_floor*Su);
Df = 1000*(hs.interface_from_floor*Sf + hs.interface_from_force*hs.force_sign);
num_tf = ss(A, Bf, C, Df, dt);
end
