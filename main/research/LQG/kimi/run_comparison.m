function result = run_comparison
%RUN_COMPARISON Broadband RTHS-like scenarios for all LQG candidates.
%
% Mirrors lqg_test_cases: healthy_broadband (7k throughout) and
% sudden_drop (7k to 5k at 45 s). Reference: 2-100 Hz band-limited white
% noise at the measured record's dd RMS (0.1475). Measurement noise:
% white, sigma = 0.005 (the record's high-frequency floor scaled to the
% reference level). Sampling 2048 Hz, matching the physical loop.

assets = kimi_assets;
fs = 2048;
dt = 1/fs;
rng(0)
durationTotal = 105;
t = (0:dt:durationTotal-dt).';
white = randn(size(t));
[bPass, aPass] = butter(4, [2 100]/(fs/2));
reference = filtfilt(bPass, aPass, white);
reference = reference/rms(reference)*0.1475;
noise = 0.005*randn(size(t));

switchTime = 45;
fprintf('Running sudden_drop scenario (%.0f s, switch at %.0f s)...\n', ...
    durationTotal, switchTime)
drop = simulate_controllers(reference, noise, dt, switchTime);
disp(drop.metrics)

durationHealthy = 75;
keep = t <= durationHealthy;
fprintf('Running healthy_broadband scenario (%.0f s)...\n', durationHealthy)
healthy = simulate_controllers(reference(keep), noise(keep), dt, Inf);
disp(healthy.metrics)

result = struct;
result.drop = drop;
result.healthy = healthy;
result.setup = struct('fs', fs, 'reference_rms', rms(reference), ...
    'noise_sigma', 0.005, 'band_hz', [2 100], 'seed', 0);

outputFile = fullfile(assets.results, 'comparison.mat');
save(outputFile, 'result')
fprintf('Saved comparison to %s\n', outputFile)
end
