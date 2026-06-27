function u = newmarkAverageAcceleration(time, M, C, K, force)
%NEWMARKAVERAGEACCELERATION Integrate M*u'' + C*u' + K*u = force.
% Units: time [s], force [N], u uses the units implied by M/C/K.

n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);
v = zeros(n_step, n_dof);
a = zeros(n_step, n_dof);
a(1, :) = (M\(force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    h = time(step)-time(step-1);
    a0 = 1/(beta*h^2);
    a1 = gamma/(beta*h);
    a2 = 1/(beta*h);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = h*(gamma/(2*beta)-1);

    effective_stiffness = K+a0*M+a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)'+a2*v(step-1, :)'+a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)'+a4*v(step-1, :)'+a5*a(step-1, :)');

    u(step, :) = (effective_stiffness\effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)'-a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)'+h*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end
