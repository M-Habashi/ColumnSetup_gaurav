function [dd, state] = step_HS(fm, pause_enable, dt, hs, state)
%STEP_HS Advance one Hybrid Simulation sample and return dd [mm].
%
% WARNING - SAFETY CRITICAL:
% This function controls live hybrid-simulation command displacement.
% Do not edit force sign, interface equations, units, or stepping behavior
% unless vHS.m is updated at the same time and offline checks are rerun.
%
% Units: fm [N], dt [s], state displacement [m], velocity [m/s],
% acceleration [m/s^2], earthquake record time [s], dd [mm].
% Simulink sample time and structural integration advance by dt. The
% earthquake record clock advances by dt/hs.time_scale_factor, so factors
% greater than 1 stretch the earthquake input in real time.

n = hs.n_floor;
if isempty(state)
    state = zeros(3*n + 3, 1);
end

dd_index = 3*n + 2;
if pause_enable ~= 0
    dd = state(dd_index);
    return
end

u = state(1:n);
v = state(n+1:2*n);
a = state(2*n+1:3*n);
tau = state(3*n+1);
record_index = max(1, round(state(3*n+3)));

h = dt;
tau_next = tau + dt/hs.time_scale_factor;
[ag, record_index] = groundAcceleration(hs.time, hs.ag, tau_next, ...
    record_index);

signed_fm = hs.force_sign*fm;
force = hs.ground_force_gain*ag + hs.force_to_floor*signed_fm;

beta = 1/4;
gamma = 1/2;
a0 = 1/(beta*h^2);
a1 = gamma/(beta*h);
a2 = 1/(beta*h);
a3 = 1/(2*beta) - 1;
a4 = gamma/beta - 1;
a5 = h*(gamma/(2*beta) - 1);

effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
effective_rhs = force ...
    + hs.M*(a0*u + a2*v + a3*a) ...
    + hs.C*(a1*u + a4*v + a5*a);

u_next = effective_stiffness\effective_rhs;
a_next = a0*(u_next - u) - a2*v - a3*a;
v_next = v + h*((1 - gamma)*a + gamma*a_next);

u_interface = hs.interface_from_floor*u_next ...
    + hs.interface_from_force*signed_fm;
dd = 1000*u_interface;

state(1:n) = u_next;
state(n+1:2*n) = v_next;
state(2*n+1:3*n) = a_next;
state(3*n+1) = tau_next;
state(dd_index) = dd;
state(3*n+3) = record_index;
end

function [ag, record_index] = groundAcceleration(time, acceleration, ...
        tau, record_index)
% Units: time/tau [s], acceleration/ag [m/s^2].
last_index = numel(time);
if tau > time(last_index)
    ag = 0.0;
    record_index = last_index;
    return
end

while record_index < last_index && time(record_index + 1) < tau
    record_index = record_index + 1;
end

if record_index >= last_index
    ag = acceleration(last_index);
else
    t0 = time(record_index);
    t1 = time(record_index + 1);
    if t1 > t0
        fraction = (tau - t0)/(t1 - t0);
    else
        fraction = 0.0;
    end
    ag = acceleration(record_index) ...
        + fraction*(acceleration(record_index + 1) - acceleration(record_index));
end
end
