function tests = test_online_tse_estimator_runtime
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(projectRoot, 'control_and_HS', 'a_specimen_id'))
addpath(fullfile(projectRoot, 'research', 'specimen_mode', 'methods'))
testCase.TestData.projectRoot = projectRoot;
end

function testMatchesOfficialWindowedEstimator(testCase)
rng(12)
dt = 1/2048;
t = (0:dt:8)';
n = numel(t);
excited = t > 2;
x = 2e-7*randn(n, 1);
x(excited) = x(excited) + 8e-4*sin(2*pi*2.1*t(excited)) ...
    + 3e-4*sin(2*pi*5.3*t(excited) + 0.4);
v = [0; diff(x)]/dt;
a = [0; diff(v)]/dt;
force = 52*a + 6100*v + 5.94e6*x + 0.5*randn(n, 1);

clear online_tse_estimator_runtime
online = nan(n, 3);
status = zeros(n, 1);
for i = 1:n
    [online(i, 1), online(i, 2), online(i, 3), status(i)] = ...
        online_tse_estimator_runtime(x(i), force(i));
end

[xf, vf, af, ff] = filtered_regression_signals(x, force, dt, 30);
noise = t <= 2;
scale = std([af(noise), vf(noise), xf(noise), ff(noise)], 0, 1);
scale(scale == 0) = 1;
config = official_tls_config;
estimate = windowed_noise_whitened_tls(t(~noise), af(~noise), vf(~noise), ...
    xf(~noise), ff(~noise), scale, config);

endpoint = nnz(noise) + round(config.window_s/dt) ...
    + (0:numel(estimate.t) - 1)'*config.plot_stride;
verifyEqual(testCase, online(endpoint, :), estimate.theta_kf, 'RelTol', 1e-10)
verifyEqual(testCase, status(endpoint) == 3, estimate.accepted)
end
