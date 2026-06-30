%% OSI7_ROBUSTNESS  Method 7 detection statistics over many disturbance seeds
% The deliverable record (make_damage_th.m) fixes one disturbance realisation
% (seed 7). This script re-runs the SAME closed-loop simulation and the SAME
% published Method 7 over many seeds to show the result is not seed-specific:
% the healthy/damaged margin separation is large and stable, the relative-drop
% alarm fires every time, and the absolute 0.40 alarm is marginal by design
% (the true degraded loop-only NCF, 0.344, sits right at the 0.40 line).

clearvars; clc; close all;

this_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(this_dir)));
addpath(fullfile(this_dir, '..', 'claude_trial', 'common'));
sr = fullfile(project_main, 'saved_results');

n_seed = 20;
rel_alarm_frac = 0.80;
abs_threshold  = 0.40;
detect_consec  = 4;

%% ---- models, controller, phase_lead, reference (as in make_damage_th.m) ------
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'));
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
PL = load(fullfile(sr, 'phase_lead', 'pl_sp1_5000.mat'));
dt = 1/2048; fs = 2048; pv = H7.pid_values;
C  = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = H7.models.H_dc_dm_d; Hd = H5.models.H_dc_dm_d;
GT = c2d(PL.phase_lead_tf, dt, 'tustin');
Th = feedback(C*Hh, 1); Sh = feedback(1, C*Hh);
Td = feedback(C*Hd, 1); Sd = feedback(1, C*Hd);
sigma = H7.source_noise_std;

R = load(fullfile(sr, 'tests', 'important', ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'));
warm = 3; N = round(23*fs) + 1;
i0 = find(R.result.t >= 100 - warm, 1);
dd = R.result.dd(i0:i0+N-1); dd = dd - mean(dd); t = (0:N-1).'/fs;
dd_lead = lsim(GT, dd, t);
keep = t >= warm - 1e-9; tk = t(keep) - warm;

%% ---- shared Method 7 context/config -----------------------------------------
ctx.fs = fs; ctx.C = C; ctx.H0d = Hh; ctx.t = tk;
cfg.t_start = 0; cfg.t_end = 20; cfg.ncf_threshold = abs_threshold;
cfg.m7_buf = 5; cfg.m7_hop = 0.5; cfg.m7_peak_band = [25 42];
cfg.m7_floor_band = [55 75]; cfg.m7_binding_band = [10 58];
cfg.m7_calib_s = 7.5; cfg.m7_medfilt = 5; cfg.m7_cap = 0.70;
cfg.m7_detect_consec = detect_consec;

%% ---- loop over seeds --------------------------------------------------------
hmean = zeros(n_seed,1); dmean = zeros(n_seed,1);
det_abs = false(n_seed,1); det_rel = false(n_seed,1); td_rel = nan(n_seed,1);
B = nan(numel(tk(1):0.5:20), 0);
for s = 1:n_seed
    rng(s); d = sigma*randn(N, 1);
    dmh = lsim(Th, dd_lead, t) + lsim(Sh, d, t);
    dmd = lsim(Td, dd_lead, t) + lsim(Sd, d, t);
    dh = dmh(keep); dd2 = dmd(keep);
    w = double(tk >= 10); ramp = abs(tk-10) <= 0.05;
    w(ramp) = 0.5*(1 + sin(pi*(tk(ramp)-10)/0.1));
    ctx.dm = (1-w).*dh + w.*dd2;

    m = osi_method7_resonance(ctx, cfg);
    if s == 1, B = nan(numel(m.tc), n_seed); tc = m.tc; end
    B(:, s) = m.ncf;
    hmean(s) = mean(m.ncf(m.tc <= 7.5), 'omitnan');
    dmean(s) = mean(m.ncf(m.tc >= 12.5), 'omitnan');
    det_abs(s) = ~isnan(m.detect_time);
    below = m.ncf < rel_alarm_frac*m.nominal;
    hit = find(movsum(below, [detect_consec-1, 0]) >= detect_consec, 1);
    if ~isempty(hit), det_rel(s) = true; td_rel(s) = m.tc(hit); end
end

fprintf('\n=== Method 7 robustness over %d disturbance seeds ===\n', n_seed);
fprintf('healthy-phase b : %.3f +/- %.3f\n', mean(hmean), std(hmean));
fprintf('damaged-phase b : %.3f +/- %.3f   (true loop-only NCF = 0.344)\n', mean(dmean), std(dmean));
fprintf('absolute alarm  (b<%.2f)         : %d/%d  (marginal: true margin ~ threshold)\n', ...
    abs_threshold, sum(det_abs), n_seed);
fprintf('relative alarm  (b<%.2f*bnom=%.2f) : %d/%d  | median %.1f s (%+.1f s after jump)\n', ...
    rel_alarm_frac, rel_alarm_frac*0.5879, sum(det_rel), n_seed, ...
    median(td_rel,'omitnan'), median(td_rel,'omitnan')-10);

%% ---- plot the ensemble ------------------------------------------------------
out_dir = fullfile(this_dir, 'results');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fig = figure('Color', 'w', 'Position', [80 80 900 480]);
plot(tc, B, '-', 'Color', [0.6 0.7 0.85 0.5]); hold on;
plot(tc, mean(B, 2), '-', 'Color', [0.20 0.30 0.55], 'LineWidth', 2.4, 'DisplayName', 'mean over seeds');
yline(0.5879, '--', 'nominal 0.59', 'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
yline(rel_alarm_frac*0.5879, '-', 'relative alarm 0.47', 'Color', [0.47 0.67 0.19], 'HandleVisibility', 'off');
yline(abs_threshold, ':', 'absolute 0.40', 'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
yline(0.344, '--', 'true damaged 0.34', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
xline(10, '-', 'damage jump', 'Color', [0.6 0 0], 'LineWidth', 1.3, 'HandleVisibility', 'off');
grid on; xlim([0 20]); ylim([0 0.75]);
xlabel('time (s)'); ylabel('NCF stability margin');
title(sprintf('OSI Method 7 over %d disturbance seeds (each grey = one realisation)', n_seed));
legend({'individual seeds', 'mean over seeds'}, 'Location', 'southwest');
saveas(fig, fullfile(out_dir, 'osi7_robustness.png'));
fprintf('Saved %s\n', fullfile(out_dir, 'osi7_robustness.png'));
