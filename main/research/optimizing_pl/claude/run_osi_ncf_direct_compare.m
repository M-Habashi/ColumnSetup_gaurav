%% RUN_OSI_NCF_DIRECT_COMPARE  New OSI Method 8 (direct S,T NCF) vs M6 and M7
% Adds the direct-NCF indicator (estimate_ncf_direct / osi_method8_ncf_direct) to
% the OSI comparison and runs it, UNCHANGED alongside the published Method 6 (FRF
% Kalman) and Method 7 (output resonance), on the healthy -> damaged H_dc_dm jump
% (7000 -> 5000 at t = 10 s) under THREE input excitations -- the same 3 cases and
% the same per-seed disturbance ensemble used by
%   research/OSI/damage_jump/run_osi6_vs_osi7.m :
%
%   high-band : broadband reference (1731), excites the ~35 Hz binding mode
%   low-band  : low-frequency reference (1749), ~0% energy > 10 Hz
%   mixed     : high-band + low-band summed
%
% M8 is the direct NCF from the closed-loop S,T (no GM step, no dither, unity
% feedback): T = dm/dd_lead, S = 1 - T, NCF = 1/(sqrt(2) max sqrt(|S|^2+|T|^2)).
% Expected: high/mixed -> M6, M7, M8 agree on the collapse; low-band -> M7 detects
% (output-only), M6 FALSE-collapses, M8 is well-conditioned (no false alarm) but
% blind there because the command never excites 35 Hz (the cost of "no dither").
%
% Read-only w.r.t. the OSI folders: it calls osi_method6_kf / osi_method7_resonance
% / osi_ncf_looponly from claude_trial/common via addpath. Saves its figure under
% this folder's results/.

clearvars; clc; close all;
this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);
project_main = fileparts(fileparts(fileparts(this_dir)));     % claude->optimizing_pl->research->main
addpath(fullfile(project_main, 'research', 'OSI', 'claude_trial', 'common'));
addpath(fullfile(project_main, 'control_and_HS', 'b_system_id', 'id_utils'));
sr = fullfile(project_main, 'saved_results');

n_seed   = 10;       % disturbance realisations (M7/M8 ensemble + all-method means)
warm     = 3;        % s, discarded loop warm-up
switch_s = 10;       % s, healthy -> damaged jump
dur      = 20;       % s, record length

%% ---- models, controller, phase_lead (identical in all cases / both halves) ----
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'));
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
PL = load(fullfile(sr, 'phase_lead', 'pl_sp1_5000.mat'));
dt = 1/2048; fs = 2048; pv = H7.pid_values;
C  = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = H7.models.H_dc_dm_d;  Hd = H5.models.H_dc_dm_d;
GT = c2d(PL.phase_lead_tf, dt, 'tustin');
Th = feedback(C*Hh,1);  Sh = feedback(1,C*Hh);
Td = feedback(C*Hd,1);  Sd = feedback(1,C*Hd);
sigma = H7.source_noise_std;
ncf_h = min_ncf(C, Hh);  ncf_d = min_ncf(C, Hd);   % true loop-only NCF: 0.588 -> 0.344

%% ---- input references (each warm+dur s), then phase_lead -----------------------
N = round((dur+warm)*fs) + 1;  t = (0:N-1).'/fs;
ddh = grab(fullfile(sr,'tests','important', ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), 620-warm, N);  % high band
ddl = grab(fullfile(sr,'tests','important', ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), 100-warm, N);  % low band
cases = struct( ...
    'name', {'high-band (broadband 1731)', 'low-band (1749)', 'mixed (high + low)'}, ...
    'dd',   {ddh, ddl, ddh + ddl});

%% ---- shared config (M6, M7 as published; M8 added) ----------------------------
cfg.t_start = 0; cfg.t_end = dur; cfg.ncf_threshold = 0.40; cfg.input_power_range_db = 30;
cfg.m6_band = [10 58]; cfg.m6_df = 1; cfg.m6_hop = 0.5; cfg.m6_buf = 1.5;
cfg.m6_Lsub = 512; cfg.m6_hsub = 256; cfg.m6_q_rel = 0.02; cfg.m6_R_floor_rel = 2e-3;
cfg.m6_gamma_min = 0.5; cfg.m6_P0_rel = 0.05; cfg.m6_nwarm = 6; cfg.m6_prctile = 5;
cfg.m6_medfilt = 3; cfg.m6_detect_consec = 5;
cfg.m7_buf = 5; cfg.m7_hop = 0.5; cfg.m7_peak_band = [25 42]; cfg.m7_floor_band = [55 75];
cfg.m7_binding_band = [10 58]; cfg.m7_calib_s = 7.5; cfg.m7_medfilt = 5; cfg.m7_cap = 0.70;
cfg.m7_detect_consec = 4; cfg.rel_alarm_frac = 0.80;
% Method 8 (direct S,T NCF) -- same window cadence as M6 for a fair comparison
cfg.m8_band = [10 58]; cfg.m8_df = 1; cfg.m8_hop = 0.5; cfg.m8_buf = 1.5;
cfg.m8_Lsub = 512; cfg.m8_hsub = 256; cfg.m8_gamma_min = 0.5; cfg.m8_prctile_hi = 95;
cfg.m8_medfilt = 3; cfg.m8_nwarm = 6; cfg.m8_detect_consec = 5;

ctx.fs = fs; ctx.dt = dt; ctx.C = C; ctx.H0d = Hh;        % nominal = healthy ("correct at start")
keep = t >= warm - 1e-9; tk = t(keep) - warm; ctx.t = tk;
w = double(tk >= switch_s); ramp = abs(tk-switch_s) <= 0.05;
w(ramp) = 0.5*(1 + sin(pi*(tk(ramp)-switch_s)/0.1));      % crossfade weight (state continuity)

%% ---- run every case -----------------------------------------------------------
fig = figure('Color','w','Position',[60 60 1000 880]);
tl = tiledlayout(numel(cases), 1, 'TileSpacing','compact','Padding','compact');
fprintf('\n=== OSI Method 8 (direct S,T NCF) vs M6, M7 | true loop-only NCF %.3f -> %.3f ===\n', ncf_h, ncf_d);

for ci = 1:numel(cases)
    dd_lead = lsim(GT, cases(ci).dd, t);                  % phase_lead (same all cases/halves)
    trk_h = lsim(Th, dd_lead, t);  trk_d = lsim(Td, dd_lead, t);   % seed-independent tracking
    ddlk = dd_lead(keep);  ctx.dd_lead = ddlk;            % M8 needs the inner-loop command

    g7 = (cfg.t_start+cfg.m7_buf):cfg.m7_hop:cfg.t_end;
    g6 = (cfg.t_start+cfg.m6_buf):cfg.m6_hop:cfg.t_end;
    g8 = (cfg.t_start+cfg.m8_buf):cfg.m8_hop:cfg.t_end;
    B7 = nan(numel(g7), n_seed);  B6 = nan(numel(g6), n_seed);  B8 = nan(numel(g8), n_seed);
    td7 = nan(n_seed,1); td6 = nan(n_seed,1); td8 = nan(n_seed,1);
    tc7=[]; tc6=[]; tc8=[];
    for s = 1:n_seed
        rng(s);  d = sigma*randn(N,1);                    % same per-seed disturbance for all methods
        dmh = trk_h + lsim(Sh,d,t);  dmd = trk_d + lsim(Sd,d,t);
        dmh = dmh(keep);  dmd = dmd(keep);
        ctx.dm = (1-w).*dmh + w.*dmd;
        ctx.dc = lsim(C, ddlk - ctx.dm, tk);
        m7 = osi_method7_resonance(ctx, cfg);  tc7 = m7.tc;  B7(:,s) = m7.ncf;
        m6 = osi_method6_kf(ctx, cfg);          tc6 = m6.tc;  B6(:,s) = m6.ncf;
        m8 = osi_method8_ncf_direct(ctx, cfg);  tc8 = m8.tc;  B8(:,s) = m8.ncf;
        td7(s) = relhit(m7.ncf, m7.tc, cfg.rel_alarm_frac*m7.nominal, cfg.m7_detect_consec);
        td6(s) = m6.detect_time;
        td8(s) = relhit(m8.ncf, m8.tc, cfg.rel_alarm_frac*m8.nominal, cfg.m8_detect_consec);
    end
    m7m = mean(B7,2,'omitnan'); m6m = mean(B6,2,'omitnan'); m8m = mean(B8,2,'omitnan');
    hw8 = tc8 <= switch_s - cfg.m8_buf/2;  dw8 = tc8 >= switch_s + cfg.m8_buf/2;
    hw6 = tc6 <= switch_s - cfg.m6_buf/2;  dw6 = tc6 >= switch_s + cfg.m6_buf/2;
    hw7 = tc7 <= switch_s - cfg.m7_buf/2;  dw7 = tc7 >= switch_s + cfg.m7_buf/2;

    fprintf('\n[%s]\n', cases(ci).name);
    fprintf('  M6 (open-loop FRF) : healthy %.3f  damaged %.3f  -> %s\n', ...
        mean(m6m(hw6),'omitnan'), mean(m6m(dw6),'omitnan'), ...
        verdict6(mean(m6m(hw6),'omitnan'), mean(m6m(dw6),'omitnan'), cfg.ncf_threshold));
    fprintf('  M7 (output reson.) : healthy %.3f  damaged %.3f  -> rel-alarm %d/%d seeds\n', ...
        mean(m7m(hw7),'omitnan'), mean(m7m(dw7),'omitnan'), sum(~isnan(td7)), n_seed);
    fprintf('  M8 (direct S,T NCF): healthy %.3f  damaged %.3f  -> rel-alarm %d/%d seeds  %s\n', ...
        mean(m8m(hw8),'omitnan'), mean(m8m(dw8),'omitnan'), sum(~isnan(td8)), n_seed, ...
        verdict8(mean(m8m(hw8),'omitnan'), mean(m8m(dw8),'omitnan'), cfg.ncf_threshold));

    nexttile; hold on;
    h_seed = plot(tc8, B8, '-', 'Color', [0.55 0.75 0.60 0.45]);          % M8 individual seeds
    h6 = plot(tc6, m6m, '-s', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor','w', 'LineWidth', 1.6, 'MarkerSize', 4);
    h7 = plot(tc7, m7m, '-o', 'Color', [0.20 0.30 0.55], 'MarkerFaceColor','w', 'LineWidth', 1.8, 'MarkerSize', 4);
    h8 = plot(tc8, m8m, '-d', 'Color', [0.10 0.50 0.20], 'MarkerFaceColor','w', 'LineWidth', 2.2, 'MarkerSize', 4);
    la = {'LabelHorizontalAlignment','left','HandleVisibility','off','FontSize',7};
    yline(ncf_h,'--','nominal 0.588','Color',[0 0.45 0.74], la{:});
    yline(cfg.ncf_threshold,':','0.40','Color',[0.5 0.4 0.3], la{:});
    yline(ncf_d,'--','true dmg 0.344','Color',[0.4 0.4 0.4], la{:});
    xline(switch_s,'-','damage','Color',[0.6 0 0],'LineWidth',1.2,'HandleVisibility','off','FontSize',7);
    grid on; xlim([0 dur]); ylim([0 0.75]); ylabel('NCF margin');
    title(cases(ci).name, 'FontSize', 10);
    if ci == 1
        legend([h6 h7 h8 h_seed(1)], {'M6 (open-loop FRF Kalman), mean', ...
            'M7 (output resonance), seed mean', 'M8 (direct S,T NCF), seed mean', ...
            'M8 individual seeds'}, 'Location','southwest','FontSize',8);
    end
    if ci == numel(cases), xlabel('time (s)'); end
end
title(tl, 'New OSI Method 8 (direct S,T NCF) vs M6 and M7: healthy \rightarrow damaged jump, 3 input bands', ...
    'FontWeight','bold');

out_dir = fullfile(this_dir, 'results');  if ~exist(out_dir,'dir'), mkdir(out_dir); end
saveas(fig, fullfile(out_dir, 'osi_method8_vs_m6_m7.png'));
fprintf('\nSaved %s\n', fullfile(out_dir, 'osi_method8_vs_m6_m7.png'));

%% ---- local helpers ------------------------------------------------------------
function dd = grab(file, t0, N)
    R = load(file);  i0 = find(R.result.t >= t0, 1);
    dd = R.result.dd(i0:i0+N-1);  dd = dd - mean(dd);
end
function b = min_ncf(C, H)
    f = logspace(0, log10(58), 3000).';  L = squeeze(freqresp(C*H, 2*pi*f));
    b = min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
end
function td = relhit(ncf, tc, thr, consec)
    below = ncf < thr;  below(isnan(ncf)) = false;
    hit = find(movsum(below,[consec-1,0]) >= consec, 1);
    td = NaN;  if ~isempty(hit), td = tc(hit); end
end
function v = verdict6(h, d, thr)
    if h < thr
        v = 'FALSE COLLAPSE (alarms when healthy)';
    elseif d < thr
        v = 'detects';
    else
        v = 'blind';
    end
end
function v = verdict8(h, d, thr)
    if h < thr
        v = '(false alarm)';
    elseif d < thr
        v = '-> detects';
    else
        v = '-> blind-but-safe (no 35 Hz excitation)';
    end
end
