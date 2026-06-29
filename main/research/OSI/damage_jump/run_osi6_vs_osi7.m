%% RUN_OSI6_VS_OSI7  Method 6 (FRF Kalman) vs Method 7 (output resonance)
% Compares the two published methods, UNCHANGED, on the healthy -> damaged
% H_dc_dm jump (7000 -> 5000 at t = 10 s) under THREE input excitations:
%
%   high-band : broadband reference (1731), median ~40 Hz -- excites the 35 Hz
%               binding mode, so the FRF is identifiable there.
%   low-band  : low-frequency reference (1749), median ~3 Hz, ~0% energy > 10 Hz
%               -- the 35 Hz mode is excited only from inside the loop.
%   mixed     : high-band + low-band summed -- both bands present.
%
% For each case it overlays Method 6 (binding band [10 58], mean over seeds) and
% Method 7 (output resonance) shown as the per-seed ENSEMBLE plus the seed mean,
% so the spread of M7 is visible the way osi7_robustness.m shows it.
%
% Expected story: when the input excites 35 Hz (high / mixed) BOTH methods see the
% margin collapse and agree (M6 cross-validates M7). Under the low-band input the
% feedback lock (dc = -C*dm at 35 Hz) fakes coherence ~1 and pins the FRF at -1/C,
% so M6 FALSE-COLLAPSES; only M7, reading the resonance in dm alone, stays correct.
% See ../claude_trial/M7.md.

clearvars; clc; close all;
this_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(this_dir)));
addpath(fullfile(this_dir, '..', 'claude_trial', 'common'));
sr = fullfile(project_main, 'saved_results');

n_seed   = 10;       % disturbance realisations (M7 ensemble + both-method means)
warm     = 3;        % s, discarded loop warm-up
switch_s = 10;       % s, healthy -> damaged jump
dur      = 20;       % s, record length

%% ---- models, controller, phase lead (identical in all cases / both halves) ---
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'));
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
PL = load(fullfile(sr, 'delay_comp', 'pl_sp1_5000.mat'));
dt = 1/2048; fs = 2048; pv = H7.pid_values;
C  = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = H7.models.H_dc_dm_d; Hd = H5.models.H_dc_dm_d;
GT = c2d(PL.delay_comp_tf, dt, 'tustin');
Th = feedback(C*Hh,1); Sh = feedback(1,C*Hh);
Td = feedback(C*Hd,1); Sd = feedback(1,C*Hd);
sigma = H7.source_noise_std;
inner_ncf = @(H) min_ncf(C, H);
ncf_h = inner_ncf(Hh); ncf_d = inner_ncf(Hd);

%% ---- input references (each 23 s = warm + 20), then phase lead ---------------
N = round((dur+warm)*fs) + 1; t = (0:N-1).'/fs;
ddh = grab(fullfile(sr,'tests','important', ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), 620-warm, N);  % high band
ddl = grab(fullfile(sr,'tests','important', ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), 100-warm, N);  % low band
cases = struct( ...
    'name', {'high-band (broadband 1731)', 'low-band (1749)', 'mixed (high + low)'}, ...
    'dd',   {ddh, ddl, ddh + ddl});

%% ---- shared config ----------------------------------------------------------
cfg.t_start = 0; cfg.t_end = dur; cfg.ncf_threshold = 0.40; cfg.input_power_range_db = 30;
cfg.m6_band = [10 58]; cfg.m6_df = 1; cfg.m6_hop = 0.5; cfg.m6_buf = 1.5;
cfg.m6_Lsub = 512; cfg.m6_hsub = 256; cfg.m6_q_rel = 0.02; cfg.m6_R_floor_rel = 2e-3;
cfg.m6_gamma_min = 0.5; cfg.m6_P0_rel = 0.05; cfg.m6_nwarm = 6; cfg.m6_prctile = 5;
cfg.m6_medfilt = 3; cfg.m6_detect_consec = 5;
cfg.m7_buf = 5; cfg.m7_hop = 0.5; cfg.m7_peak_band = [25 42]; cfg.m7_floor_band = [55 75];
cfg.m7_binding_band = [10 58]; cfg.m7_calib_s = 7.5; cfg.m7_medfilt = 5; cfg.m7_cap = 0.70;
cfg.m7_detect_consec = 4; cfg.rel_alarm_frac = 0.80;

ctx.fs = fs; ctx.dt = dt; ctx.C = C; ctx.H0d = Hh;        % nominal = healthy ("correct at start")
keep = t >= warm - 1e-9; tk = t(keep) - warm; ctx.t = tk;
ksw = find(tk >= switch_s, 1);
w = double(tk >= switch_s); ramp = abs(tk-switch_s) <= 0.05;
w(ramp) = 0.5*(1 + sin(pi*(tk(ramp)-switch_s)/0.1));      % crossfade weight (state continuity)

%% ---- run every case ---------------------------------------------------------
fig = figure('Color','w','Position',[60 60 980 860]);
tl = tiledlayout(numel(cases), 1, 'TileSpacing','compact','Padding','compact');
fprintf('\n=== Method 6 vs Method 7 | true loop-only NCF 0.588 -> 0.344 ===\n');

for ci = 1:numel(cases)
    dd_lead = lsim(GT, cases(ci).dd, t);                  % phase lead (same all cases/halves)
    trk_h = lsim(Th, dd_lead, t); trk_d = lsim(Td, dd_lead, t);   % seed-independent tracking
    ddlk = dd_lead(keep);

    B7 = nan(numel((cfg.t_start+cfg.m7_buf):cfg.m7_hop:cfg.t_end), n_seed);  % M7 window grid
    B6 = nan(numel((cfg.t_start+cfg.m6_buf):cfg.m6_hop:cfg.t_end), n_seed);  % M6 window grid
    td7r = nan(n_seed,1); det6 = nan(n_seed,1); tc7 = []; tc6 = [];
    for s = 1:n_seed
        rng(s); d = sigma*randn(N,1);
        dmh = trk_h + lsim(Sh,d,t); dmd = trk_d + lsim(Sd,d,t);
        dmh = dmh(keep); dmd = dmd(keep);
        dm = (1-w).*dmh + w.*dmd;
        ctx.dm = dm; ctx.dc = lsim(C, ddlk - dm, tk);
        m7 = osi_method7_resonance(ctx, cfg); tc7 = m7.tc; B7(:,s) = m7.ncf;
        m6 = osi_method6_kf(ctx, cfg);        tc6 = m6.tc; B6(:,s) = m6.ncf;
        td7r(s) = relhit(m7.ncf, m7.tc, cfg.rel_alarm_frac*m7.nominal, cfg.m7_detect_consec);
        det6(s) = m6.detect_time;
    end
    m7mean = mean(B7,2,'omitnan'); m6mean = mean(B6,2,'omitnan');
    dwin7 = tc7 >= switch_s + cfg.m7_buf/2; dwin6 = tc6 >= switch_s + cfg.m6_buf/2;
    hwin7 = tc7 <= switch_s - cfg.m7_buf/2; hwin6 = tc6 <= switch_s - cfg.m6_buf/2;
    m6_h = mean(m6mean(hwin6),'omitnan'); m6_d = mean(m6mean(dwin6),'omitnan');
    if m6_h < cfg.ncf_threshold
        m6_verdict = 'FALSE COLLAPSE (alarms in healthy phase)';
    elseif m6_d < cfg.ncf_threshold
        m6_verdict = 'detects (agrees with M7)';
    else
        m6_verdict = 'blind';
    end
    fprintf('\n[%s]\n', cases(ci).name);
    fprintf('  M6 (FRF, binding band): healthy b=%.3f  damaged b=%.3f  -> %s\n', m6_h, m6_d, m6_verdict);
    fprintf('  M7 (output resonance) : healthy b=%.3f  damaged b=%.3f  -> detects, rel-alarm %d/%d seeds (~%.1f s after jump)\n', ...
        mean(m7mean(hwin7),'omitnan'), mean(m7mean(dwin7),'omitnan'), sum(~isnan(td7r)), n_seed, median(td7r,'omitnan')-switch_s);

    nexttile; hold on;
    h_seed = plot(tc7, B7, '-', 'Color', [0.6 0.7 0.85 0.45]);
    h7 = plot(tc7, m7mean, '-o', 'Color', [0.20 0.30 0.55], 'MarkerFaceColor','w', 'LineWidth', 2.0, 'MarkerSize', 4);
    h6 = plot(tc6, m6mean, '-s', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor','w', 'LineWidth', 1.8, 'MarkerSize', 4);
    la = {'LabelHorizontalAlignment','left','HandleVisibility','off','FontSize',7};
    yline(0.588,'--','nominal',  'Color',[0 0.45 0.74], la{:});
    yline(cfg.ncf_threshold,':','0.40', 'Color',[0.5 0.4 0.3], la{:});
    yline(ncf_d,'--','true dmg', 'Color',[0.4 0.4 0.4], la{:});
    xline(switch_s,'-','damage', 'Color',[0.6 0 0], 'LineWidth',1.2,'HandleVisibility','off','FontSize',7);
    grid on; xlim([0 dur]); ylim([0 0.75]); ylabel('NCF margin');
    title(sprintf('%s', cases(ci).name), 'FontSize', 10);
    if ci == 1
        legend([h6 h7 h_seed(1)], {'Method 6 (FRF Kalman), mean', ...
            'Method 7 (output resonance), seed mean', 'Method 7, individual seeds'}, ...
            'Location','southwest','FontSize',8);
    end
    if ci == numel(cases), xlabel('time (s)'); end
end
title(tl, 'Method 6 vs Method 7: healthy \rightarrow damaged H_{dc,dm} jump, 3 input bands', 'FontWeight','bold');

out_dir = fullfile(this_dir, 'results'); if ~exist(out_dir,'dir'), mkdir(out_dir); end
saveas(fig, fullfile(out_dir, 'osi6_vs_osi7_all_cases.png'));
fprintf('\nSaved %s\n', fullfile(out_dir, 'osi6_vs_osi7_all_cases.png'));
fprintf('\n>> To regenerate these plots, run:  run_osi6_vs_osi7\n');

%% ---- local helpers ----------------------------------------------------------
function dd = grab(file, t0, N)
    R = load(file); i0 = find(R.result.t >= t0, 1);
    dd = R.result.dd(i0:i0+N-1); dd = dd - mean(dd);
end
function b = min_ncf(C, H)
    f = logspace(0, log10(58), 3000).'; L = squeeze(freqresp(C*H, 2*pi*f));
    b = min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
end
function td = relhit(ncf, tc, thr, consec)
    below = ncf < thr; hit = find(movsum(below,[consec-1,0]) >= consec, 1);
    td = NaN; if ~isempty(hit), td = tc(hit); end
end
