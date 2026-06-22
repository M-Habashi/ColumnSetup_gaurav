function tests = test_identify_analog_closed_loop_params
tests = functiontests(localfunctions);
end

function testFixedScaleParameterization(testCase)
m = 38;
d = 416;
k = 2e5;
w = logspace(-1, 2, 300).' * 2*pi;
p = struct('a1b0', 2.1283e13, 'a2', 4.2297e6, 'a3', 3.3, ...
    'beta1', 425, 'beta2', 9.9976e4, 'Kp', 1.5, 'Ki', 0.03);

[num, den] = modelPolynomial(p, m, d, k);
scaled = p;
scaled.a1b0 = 10*p.a1b0;
scaled.Kp = p.Kp/10;
scaled.Ki = p.Ki/10;
[scaled_num, scaled_den] = modelPolynomial(scaled, m, d, k);
verifyEqual(testCase, scaled_num, num, 'RelTol', 1e-14);
verifyEqual(testCase, scaled_den, den, 'RelTol', 1e-14);

data = struct('tf_points', freqs(num, den, w), 'freq_rad', w, ...
    'freq_hz', w/(2*pi));
config = struct('mass', m, 'damping', d, 'stiffness', k, ...
    'num_random_starts', 0, 'max_time', 20, ...
    'initial_params', p, ...
    'a1b0_bounds', [1e12, 1e14], 'a2_bounds', [1e6, 1e7], ...
    'a3_bounds', [1, 10], 'beta1_bounds', [1e2, 1e3], ...
    'beta2_bounds', [1e4, 1e6], 'Kp_bounds', [0.1, 10], ...
    'Ki_bounds', [0.001, 0.1]);
out = identify_analog_closed_loop_params(data, config);

verifyEqual(testCase, out.identified_params.a1b0, 1);
verifyEqual(testCase, out.identified_params.Kp, p.Kp*p.a1b0, 'RelTol', 1e-6);
verifyEqual(testCase, out.identified_params.Ki, p.Ki*p.a1b0, 'RelTol', 1e-6);
verifyLessThan(testCase, norm(out.fit_resp-data.tf_points)/norm(data.tf_points), 1e-8);
end

function [num, den] = modelPolynomial(p, m, d, k)
num = [p.Kp*p.a1b0, p.Ki*p.a1b0];
den = [m, ...
    d + p.a3*m + p.beta1*m, ...
    p.a2 + k + p.a3*d + p.beta1*d + p.beta2*m + p.a3*p.beta1*m, ...
    p.a2*p.beta1 + p.beta2*d + p.a3*k + p.beta1*k + p.a3*p.beta1*d + p.a3*p.beta2*m, ...
    p.a2*p.beta2 + p.beta2*k + p.a3*p.beta2*d + p.a3*p.beta1*k, ...
    p.Kp*p.a1b0 + p.a3*p.beta2*k, ...
    p.Ki*p.a1b0];
end
