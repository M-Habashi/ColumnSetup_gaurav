%% RUN_OSI7  OSI Method 7 on the synthetic healthy -> damaged record
% Runs the published Method 7 (common/osi_method7_resonance.m, unchanged) on the
% record built by make_damage_th.m. Method 7 reads the closed-loop resonance
% amplification in dm alone (Spk ~ ||S||_inf) and maps it to the loop-only NCF,
% calibrated to the healthy model's nominal margin over the first calib_s. The
% expected outcome: a flat margin ~0.588 in the healthy half, dropping to ~0.34
% (below the 0.40 threshold) after the t = 10 s damage jump.
%
% Bands differ from the field defaults for this synthetic record: under damage the
% binding resonance shifts 35 -> 39 Hz and contaminates the default floor [42 58];
% the synthetic disturbance has no 60 Hz line, so a cleaner high-frequency floor
% [55 75] is used and the peak band is widened to [25 42] to keep the shifted peak.

clearvars; clc; close all;

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'claude_trial', 'common'));   % osi_method7_resonance, osi_ncf_looponly

rec_file = fullfile(this_dir, 'data', 'damage_th.mat');
if ~exist(rec_file, 'file')
    error('run_osi7:NoRecord', 'Run make_damage_th.m first to create %s', rec_file);
end
R = load(rec_file);

%% ---- context: nominal (healthy) model + the synthetic response --------------
dt = R.dt;
pv = R.meta.pid_values;
ctx.fs  = R.fs;
ctx.t   = R.t;
ctx.dm  = R.dm;
ctx.C   = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = load(R.meta.healthy_tf_file, 'models');
ctx.H0d = Hh.models.H_dc_dm_d;                          % healthy plant = "model correct at the start"

%% ---- Method 7 configuration for the 20 s record -----------------------------
cfg.t_start = 0;
cfg.t_end   = R.t(end);
cfg.ncf_threshold    = 0.40;
cfg.m7_buf           = 5;        % s, analysis buffer (>=10 s per phase allows this)
cfg.m7_hop           = 0.5;      % s, update period
cfg.m7_peak_band     = [25 42];  % Hz, captures the 35 Hz (healthy) and 39 Hz (damaged) peak
cfg.m7_floor_band    = [55 75];  % Hz, clean off-resonance floor (no line tones in synthetic data)
cfg.m7_binding_band  = [10 58];  % Hz, model NCF band giving b_nom (~0.588)
cfg.m7_calib_s       = 7.5;      % s, calibration over the pure-healthy windows
cfg.m7_medfilt       = 5;        % median taps on Spk
cfg.m7_cap           = 0.70;     % upper clamp on reported margin
cfg.m7_detect_consec = 4;        % 4 x 0.5 s = 2 s sustained below threshold -> detect
cfg.rel_alarm_frac   = 0.80;     % relative-drop alarm: b < frac * b_nom (robust, see README)

%% ---- run --------------------------------------------------------------------
t0 = tic;
m7 = osi_method7_resonance(ctx, cfg);                   % published Method 7, unchanged
runtime = toc(t0);

tc = m7.tc;  b = m7.ncf;
switch_s = R.switch_time;
healthy_win = tc <= switch_s - cfg.m7_buf/2;            % buffer entirely before the jump
damaged_win = tc >= switch_s + cfg.m7_buf/2;            % buffer entirely after the jump

% Relative-drop alarm. Method 7 returns a START-CALIBRATED, RELATIVE margin
% (see M7.md s.5), so the sound decision is a drop from the calibrated nominal
% rather than the absolute 0.40 design line -- which, for this mild degradation,
% sits right at the true degraded margin and so is only marginally crossed.
rel_thresh = cfg.rel_alarm_frac*m7.nominal;
below_rel  = b < rel_thresh;
hit_rel    = find(movsum(below_rel, [cfg.m7_detect_consec-1, 0]) >= cfg.m7_detect_consec, 1);
detect_rel = NaN; if ~isempty(hit_rel), detect_rel = tc(hit_rel); end

fprintf('\n=== OSI Method 7 on synthetic healthy->damaged record ===\n');
fprintf('b_nom (healthy model NCF) = %.3f | Spk_ref = %.2f | runtime = %.2f s\n', ...
    m7.nominal, m7.Sref, runtime);
fprintf('healthy-phase b : mean=%.3f  std=%.3f\n', ...
    mean(b(healthy_win), 'omitnan'), std(b(healthy_win), 'omitnan'));
fprintf('damaged-phase b : mean=%.3f  std=%.3f   (true loop-only NCF = %.3f)\n', ...
    mean(b(damaged_win), 'omitnan'), std(b(damaged_win), 'omitnan'), R.meta.inner_ncf_damaged);
if isnan(m7.detect_time)
    fprintf('absolute  alarm (b<%.2f)        : none\n', cfg.ncf_threshold);
else
    fprintf('absolute  alarm (b<%.2f)        : %.1f s (%+.1f s vs jump)  [marginal: true margin ~ threshold]\n', ...
        cfg.ncf_threshold, m7.detect_time, m7.detect_time - switch_s);
end
if isnan(detect_rel)
    fprintf('relative  alarm (b<%.2f*bnom)   : none\n', cfg.rel_alarm_frac);
else
    fprintf('relative  alarm (b<%.2f*bnom=%.2f): %.1f s (%+.1f s vs jump)  [robust criterion]\n', ...
        cfg.rel_alarm_frac, rel_thresh, detect_rel, detect_rel - switch_s);
end

%% ---- save + plot ------------------------------------------------------------
out_dir = fullfile(this_dir, 'results');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
result = struct('method', 'OSI Method 7 - output resonance / sensitivity-peak', ...
    'tc', tc, 'ncf', b, 'nominal', m7.nominal, 'threshold', cfg.ncf_threshold, ...
    'rel_alarm_frac', cfg.rel_alarm_frac, 'rel_threshold', rel_thresh, ...
    'Spk', m7.Spk, 'Sref', m7.Sref, 'detect_time_abs', m7.detect_time, ...
    'detect_time_rel', detect_rel, 'switch_time', switch_s, ...
    'true_ncf_damaged', R.meta.inner_ncf_damaged, ...
    'true_ncf_healthy', R.meta.inner_ncf_healthy, 'cfg', cfg);
save(fullfile(out_dir, 'osi7_damage_result.mat'), 'result');

fig = figure('Color', 'w', 'Position', [80 80 900 480]);
plot(tc, b, '-o', 'MarkerFaceColor', 'w', 'Color', [0.20 0.30 0.55], ...
    'LineWidth', 1.8, 'DisplayName', 'Method 7 NCF estimate'); hold on;
yline(m7.nominal, '--', sprintf('nominal %.2f', m7.nominal), 'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
yline(rel_thresh, '-', sprintf('relative alarm %.2f', rel_thresh), 'Color', [0.47 0.67 0.19], 'HandleVisibility', 'off');
yline(cfg.ncf_threshold, ':', sprintf('absolute %.2f', cfg.ncf_threshold), 'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
yline(R.meta.inner_ncf_damaged, '--', sprintf('true damaged %.2f', R.meta.inner_ncf_damaged), ...
    'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
xline(switch_s, '-', 'damage jump', 'Color', [0.6 0 0], 'LineWidth', 1.3, 'HandleVisibility', 'off');
if ~isnan(detect_rel)
    xline(detect_rel, '-.', sprintf('detect %.1f s', detect_rel), 'Color', [0.6 0 0], 'HandleVisibility', 'off');
end
grid on; xlim([cfg.t_start cfg.t_end]); ylim([0 0.75]);
xlabel('time (s)'); ylabel('NCF stability margin');
title('OSI Method 7: healthy \rightarrow damaged H_{dc,dm} jump (low-band input)');
legend('Location', 'southwest');
saveas(fig, fullfile(out_dir, 'osi7_damage.png'));
fprintf('Saved %s and osi7_damage_result.mat\n', fullfile(out_dir, 'osi7_damage.png'));
