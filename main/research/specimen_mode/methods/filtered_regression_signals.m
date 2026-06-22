function [x, v, a, F] = filtered_regression_signals(x, F, dt, cutoff)
% Causal common filtering; velocity and acceleration come from displacement.
x = x(:);
F = F(:);
[b, af] = butter(2, cutoff*2*dt);
x = filter(b, af, x - x(1)) + x(1);
F = filter(b, af, F - F(1)) + F(1);
v = [0; diff(x)]/dt;
a = [0; diff(v)]/dt;
end
