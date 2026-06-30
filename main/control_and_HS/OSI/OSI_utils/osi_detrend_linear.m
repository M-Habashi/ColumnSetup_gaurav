function y = osi_detrend_linear(x)
%OSI_DETREND_LINEAR Remove the least-squares line from a vector.
% Useful before FFT-based OSI estimates when DC and ramp leakage should not
% bias nearby frequency bins.

x = x(:);
n = numel(x);
t = (0:n-1).';
sum_t = sum(t);
sum_t2 = sum(t.^2);
sum_x = sum(x);
slope = (n*sum(t.*x) - sum_t*sum_x)/(n*sum_t2 - sum_t^2);
offset = (sum_x - slope*sum_t)/n;
y = x - offset - slope*t;
end
