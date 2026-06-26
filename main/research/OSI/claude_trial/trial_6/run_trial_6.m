%% Trial 6 -- Method 6: Recursive frequency-point Kalman filter (fast, 0.5 s)
% Each discrete transfer-function point H(f_i) is a complex Kalman state,
% initialised from the known exp_tf model and updated every 0.5 s from a short
% sliding buffer, with measurement noise R adapted by the per-point coherence.
% The loop margin is a robust percentile of the normalized loop distance.
% See common/osi_method6_kf.m and method_6_explained.md for the full method.
% Output: a high-time-resolution (0.5 s) NCF-margin time series, 620-770.1 s.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

t0 = tic;
m6 = osi_method6_kf(ctx, cfg);
runtime = toc(t0);

% --- save in the common result format (plus M6 diagnostics) ---
result = struct('tag', 'trial_6', ...
    'method', sprintf('Method 6 - Recursive freq-point Kalman (%.1fs update)', cfg.m6_hop), ...
    'tc', m6.tc, 'ncf', m6.ncf, 'nominal', m6.nominal, 'threshold', m6.threshold, ...
    'runtime', runtime);
result.extra = struct('name', {'raw (per-snapshot)'}, 'data', {m6.ncf_raw});
result.detect_time = m6.detect_time;
save(fullfile(cfg.results_dir, 'trial_6_result.mat'), 'result');

% --- concise summary ---
stable = m6.tc <= 700;
fprintf('\n=== %s ===\n', result.method);
fprintf('grid: %d points over [%g %g] Hz | buffer %.1fs, %d sub-averages | %d snapshots @ %.1fs\n', ...
    numel(m6.f6), cfg.m6_band(1), cfg.m6_band(2), cfg.m6_buf, m6.n_d, numel(m6.tc), cfg.m6_hop);
fprintf('nominal=%.3f | stable mean=%.3f std=%.3f | min before 705 s=%.3f (no false alarm)\n', ...
    m6.nominal, mean(m6.ncf(stable)), std(m6.ncf(stable)), min(m6.ncf(m6.tc<705)));
fprintf('detection (%d consecutive < %.2f) at t = %.1f s ; final value = %.3f\n', ...
    cfg.m6_detect_consec, m6.threshold, m6.detect_time, m6.ncf(end));
fprintf('  t(s)   NCF (every ~5 s)\n');
for k = 1:10:numel(m6.tc), fprintf('  %6.1f  %.3f\n', m6.tc(k), m6.ncf(k)); end

% --- figure ---
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 880 480]);
plot(m6.tc, m6.ncf_raw, '-', 'Color', [0.7 0.78 0.9], 'LineWidth', 0.8, ...
    'DisplayName', 'raw (0.5 s)'); hold on
plot(m6.tc, m6.ncf, '-', 'Color', [0.10 0.20 0.55], 'LineWidth', 1.8, ...
    'DisplayName', 'indicator (median-filtered)');
yline(m6.nominal, '--', 'nominal', 'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
yline(m6.threshold, ':', 'threshold', 'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
if ~isnan(m6.detect_time)
    xline(m6.detect_time, '-.', sprintf('detect %.1f s', m6.detect_time), ...
        'Color', [0.6 0 0], 'HandleVisibility', 'off');
end
grid on; xlim([cfg.t_start cfg.t_end]); ylim([0 0.75]);
xlabel('time (s)'); ylabel('NCF stability margin');
title(result.method, 'Interpreter', 'none'); legend('Location', 'southwest');
saveas(fig, fullfile(cfg.results_dir, 'trial_6.png')); close(fig);
fprintf('saved trial_6_result.mat and trial_6.png\n');
