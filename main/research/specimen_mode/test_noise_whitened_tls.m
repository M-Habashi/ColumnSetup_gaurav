function tests = test_noise_whitened_tls
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
methods = fullfile(fileparts(mfilename('fullpath')), 'methods');
addpath(methods)
testCase.TestData.methods = methods;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.methods)
end

function testOfficialConfiguration(testCase)
config = official_tls_config;
verifyEqual(testCase, [config.window_s config.filter_hz config.plot_stride ...
    config.f_min config.q_rel config.r_rel], [0.1 30 64 20 1 1])
end

function testUnitInvariance(testCase)
rng(1)
[a, v, x, F, scale, truth] = syntheticData();
thetaSI = noise_whitened_tls(a, v, x, F, scale);

kinematicScale = 1000; % m to mm
forceScale = 0.001;    % N to kN
thetaConverted = noise_whitened_tls(a*kinematicScale, v*kinematicScale, ...
    x*kinematicScale, F*forceScale, scale.*[kinematicScale kinematicScale kinematicScale forceScale]);
thetaConverted = thetaConverted*kinematicScale/forceScale;

verifyEqual(testCase, thetaConverted, thetaSI, 'RelTol', 1e-10)
end

function testWindowedEstimatorInitializesFromTLS(testCase)
rng(3)
[a, v, x, F, scale] = syntheticData();
dt = 1/512;
t = (0:dt:8)';
config = official_tls_config;
config.f_min = 0;
result = windowed_noise_whitened_tls(t, a, v, x, F, scale, config);
first = find(result.accepted, 1, 'first');
verifyEqual(testCase, result.theta_kf(first, :), result.theta_raw(first, :))
end

function testSyntheticRecoveryAndCoverage(testCase)
rng(2)
nGroups = 20;
nPerGroup = 20;
covered = false(nGroups, 3);
groupMean = zeros(nGroups, 3);

for g = 1:nGroups
    estimates = zeros(nPerGroup, 3);
    for i = 1:nPerGroup
        [a, v, x, F, scale, truth] = syntheticData();
        estimates(i, :) = noise_whitened_tls(a, v, x, F, scale)';
    end
    groupMean(g, :) = mean(estimates, 1);
    halfWidth = 2.093*std(estimates, 0, 1)/sqrt(nPerGroup);
    covered(g, :) = abs(groupMean(g, :) - truth') <= halfWidth;
end

verifyLessThan(testCase, abs(mean(groupMean, 1)' - truth)./truth, 0.05)
verifyGreaterThanOrEqual(testCase, mean(covered, 1), [0.90 0.90 0.90])
end

function [a, v, x, F, scale, truth] = syntheticData
dt = 1/512;
t = (0:dt:8)';
truth = [2.04; 12; 7.028e6];
x = 8e-4*sin(2*pi*2.1*t) + 3e-4*sin(2*pi*5.3*t + 0.4);
v = 8e-4*(2*pi*2.1)*cos(2*pi*2.1*t) + 3e-4*(2*pi*5.3)*cos(2*pi*5.3*t + 0.4);
a = -8e-4*(2*pi*2.1)^2*sin(2*pi*2.1*t) - 3e-4*(2*pi*5.3)^2*sin(2*pi*5.3*t + 0.4);
F = truth(1)*a + truth(2)*v + truth(3)*x;
scale = [0.002 2e-5 2e-7 0.5];
a = a + scale(1)*randn(size(a));
v = v + scale(2)*randn(size(v));
x = x + scale(3)*randn(size(x));
F = F + scale(4)*randn(size(F));
end
