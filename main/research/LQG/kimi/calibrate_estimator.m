function result = calibrate_estimator
%CALIBRATE_ESTIMATOR Gamma sweep for the path-LQG online estimator.
%
% Uses the sudden_drop scenario (identical reference/noise as
% run_comparison) and reports, per gamma: pre-switch wander of theta_hat,
% time to theta_hat = 0.9 after the drop, theta_hat at the end, and the
% post-switch RMS tracking error.

fs = 2048;
dt = 1/fs;
rng(0)
t = (0:dt:105-dt).';
white = randn(size(t));
[bPass, aPass] = butter(4, [2 100]/(fs/2));
reference = filtfilt(bPass, aPass, white);
reference = reference/rms(reference)*0.1475;
noise = 0.005*randn(size(t));
switchTime = 45;

gammas = [1, 3, 10, 30, 60].';
rows = {};
series = {};
for i = 1:numel(gammas)
    sim = simulate_controllers(reference, noise, dt, switchTime, ...
        struct('gamma', gammas(i)));
    adaptive = sim.outputs{end};
    theta = adaptive.theta;
    wander = max(abs(theta(t >= 30 & t < switchTime)));
    hit = find(t >= switchTime & theta >= 0.9, 1, 'first');
    if isempty(hit)
        timeTo09 = Inf;
    else
        timeTo09 = t(hit) - switchTime;
    end
    thetaEnd = theta(end);
    err = reference - adaptive.dm;
    postRms = rms(err(t >= t(end) - 20));
    rows(end+1, :) = {gammas(i), wander, timeTo09, thetaEnd, postRms};
    series{end+1} = struct('gamma', gammas(i), 'theta', theta);
    fprintf('gamma %.6g done: wander %.4g, t90 %.4g, end %.4g, post %.6g\n', ...
        gammas(i), wander, timeTo09, thetaEnd, postRms)
end
result = struct;
result.table = cell2table(rows, 'VariableNames', {'gamma', ...
    'pre_switch_wander', 'time_to_theta_09_s', 'theta_final', ...
    'rms_error_post'});
result.series = series;
disp(result.table)

assets = kimi_assets;
outputFile = fullfile(assets.results, 'estimator_calibration.mat');
save(outputFile, 'result')
fprintf('Saved estimator calibration to %s\n', outputFile)
end
