function pid_values = apply_pid_authority(pid_values, a)
%APPLY_PID_AUTHORITY Scale the PID gains by the authority factor a (PID*a).
% Multiplies P, I, and D by a while leaving the derivative-filter N unchanged, so
% the controller becomes a*C_pid (uniform gain scaling, same shape). Because the
% integrator keeps the inner closed-loop DC gain at 1 for any a>0, lowering a
% reduces loop gain and raises the inner gain margin WITHOUT under-driving the
% specimen displacement (it costs bandwidth, not amplitude).
%
% Accepts the [P I D N] vector used by the optimizer, or a pid_values struct.

if isnumeric(pid_values)
    pid_values(1:3) = a*pid_values(1:3);
else
    pid_values.P = a*pid_values.P;
    pid_values.I = a*pid_values.I;
    pid_values.D = a*pid_values.D;
end
end
