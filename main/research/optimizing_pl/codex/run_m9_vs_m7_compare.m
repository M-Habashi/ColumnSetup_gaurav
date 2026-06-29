%% RUN_M9_VS_M7_COMPARE  Method 9 adaptive margin vs Method 7.
% Runs the same three healthy-to-damaged H_dc_dm jump cases used by Claude's M7
% comparison, then writes seed plots, a result MAT, Markdown, and HTML under this
% codex folder.

clearvars; clc; close all;
script_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(script_dir)));
addpath(script_dir);
addpath(fullfile(project_main, 'research', 'OSI', 'claude_trial', 'common'));
addpath(fullfile(project_main, 'control_and_HS', 'b_system_id', 'id_utils'));
sr = fullfile(project_main, 'saved_results');

cfg = localConfig();
[ctx0, cases, truth] = loadStudyContext(sr, cfg);
result = runStudy(ctx0, cases, truth, cfg);

result_file = fullfile(script_dir, 'm9_vs_m7_result.mat');
save(result_file, 'result');
plot_file = fullfile(script_dir, 'm9_vs_m7_summary.png');
plotSummary(plot_file, result);
md_file = fullfile(script_dir, 'm9_vs_m7_report.md');
writeMarkdown(md_file, result);
html_file = fullfile(script_dir, 'm9_vs_m7_report.html');
writeHtml(html_file, result, plot_file);

disp(result.summary)
fprintf('\nSaved %s\n', result_file)
fprintf('Saved %s\n', plot_file)
fprintf('Saved %s\n', md_file)
fprintf('Saved %s\n', html_file)

function cfg = localConfig()
cfg.n_seed = 10;
cfg.warm = 3;
cfg.switch_s = 10;
cfg.dur = 20;
cfg.t_start = 0;
cfg.t_end = cfg.dur;
cfg.ncf_threshold = 0.40;
cfg.rel_alarm_frac = 0.80;
cfg.input_power_range_db = 30;

cfg.m7_buf = 5;
cfg.m7_hop = 0.5;
cfg.m7_peak_band = [25 42];
cfg.m7_floor_band = [55 75];
cfg.m7_binding_band = [10 58];
cfg.m7_calib_s = 7.5;
cfg.m7_medfilt = 5;
cfg.m7_cap = 0.70;
cfg.m7_detect_consec = 4;

cfg.m9_band = [2 100];
cfg.m9_df = 1;
cfg.m9_buf = 3;
cfg.m9_hop = 0.5;
cfg.m9_Lsub = 512;
cfg.m9_hsub = 256;
cfg.m9_gamma_min = 0.45;
cfg.m9_min_bins = 3;
cfg.m9_nwarm = 5;
cfg.m9_medfilt = 3;
cfg.m9_detect_consec = 4;
cfg.m9_calib_s = 7.5;
cfg.m9_cap = 0.70;
cfg.m9_residual_floor = 0.03;
cfg.m9_res_prctile = 99;
cfg.m9_st_prctile = 95;
cfg.m9_freq_medfilt = 3;
cfg.m9_line_reject = [58 62];
cfg.m9_model_dist_factor = 1.05;
cfg.m9_min_peak_half_width_hz = 6;
cfg.m9_floor_gap_hz = 14;
cfg.m9_floor_width_hz = 20;
end

function [ctx0, cases, truth] = loadStudyContext(sr, cfg)
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'));
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
PL = load(fullfile(sr, 'delay_comp', 'pl_sp1_5000.mat'));
dt = 1/2048;
fs = 2048;
pv = H7.pid_values;
C = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = H7.models.H_dc_dm_d;
Hd = H5.models.H_dc_dm_d;
GT = c2d(PL.delay_comp_tf, dt, 'tustin');

N = round((cfg.dur + cfg.warm)*fs) + 1;
t = (0:N-1).'/fs;
ddh = grab(fullfile(sr, 'tests', 'important', ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    620 - cfg.warm, N);
ddl = grab(fullfile(sr, 'tests', 'important', ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    100 - cfg.warm, N);
cases = struct('name', {'high-band', 'low-band', 'mixed'}, ...
    'label', {'high-band broadband 1731', 'low-band 1749', 'mixed high + low'}, ...
    'dd', {ddh, ddl, ddh + ddl});

truth.healthy_ncf = minNcf(C, Hh, [2 100]);
truth.damaged_ncf = minNcf(C, Hd, [2 100]);
truth.switch_s = cfg.switch_s;

keep = t >= cfg.warm - 1e-9;
tk = t(keep) - cfg.warm;
w = double(tk >= cfg.switch_s);
ramp = abs(tk - cfg.switch_s) <= 0.05;
w(ramp) = 0.5*(1 + sin(pi*(tk(ramp) - cfg.switch_s)/0.1));

ctx0 = struct('fs', fs, 'dt', dt, 'C', C, 'H0d', Hh, 'Hd', Hd, ...
    'GT', GT, 'Th', feedback(C*Hh, 1), 'Sh', feedback(1, C*Hh), ...
    'Td', feedback(C*Hd, 1), 'Sd', feedback(1, C*Hd), ...
    'sigma', H7.source_noise_std, 'N', N, 't', t, 'keep', keep, ...
    'tk', tk, 'jump_weight', w);
end

function result = runStudy(ctx0, cases, truth, cfg)
n_case = numel(cases);
case_result = repmat(struct(), n_case, 1);
rows = cell(n_case, 1);

fprintf('\n=== M9 adaptive margin vs M7 | true loop-only NCF %.3f -> %.3f ===\n', ...
    truth.healthy_ncf, truth.damaged_ncf)

for ci = 1:n_case
    dd_lead = lsim(ctx0.GT, cases(ci).dd, ctx0.t);
    trk_h = lsim(ctx0.Th, dd_lead, ctx0.t);
    trk_d = lsim(ctx0.Td, dd_lead, ctx0.t);
    ddlk = dd_lead(ctx0.keep);
    ctx = rmfield(ctx0, {'GT', 'Th', 'Sh', 'Td', 'Sd', 'sigma', 'N', 't', 'keep', 'jump_weight'});
    ctx.t = ctx0.tk;
    ctx.dd_lead = ddlk;

    tc7 = ((cfg.t_start + cfg.m7_buf):cfg.m7_hop:cfg.t_end).' - cfg.m7_buf/2;
    tc9 = ((cfg.t_start + cfg.m9_buf):cfg.m9_hop:cfg.t_end).' - cfg.m9_buf/2;
    B7 = nan(numel(tc7), cfg.n_seed);
    B9 = nan(numel(tc9), cfg.n_seed);
    F9 = nan(numel(tc9), cfg.n_seed);
    td7 = nan(cfg.n_seed,1);
    td9 = nan(cfg.n_seed,1);
    for s = 1:cfg.n_seed
        rng(s);
        d = ctx0.sigma*randn(ctx0.N, 1);
        dmh = trk_h + lsim(ctx0.Sh, d, ctx0.t);
        dmd = trk_d + lsim(ctx0.Sd, d, ctx0.t);
        dm = (1 - ctx0.jump_weight).*dmh(ctx0.keep) + ctx0.jump_weight.*dmd(ctx0.keep);
        ctx.dm = dm;
        ctx.dc = lsim(ctx.C, ddlk - dm, ctx.t);

        m7 = osi_method7_resonance(ctx, cfg);
        m9 = osi_method9_adaptive_margin(ctx, cfg);
        B7(:,s) = m7.ncf;
        B9(:,s) = m9.ncf;
        F9(:,s) = minFreq(m9);
        td7(s) = relhit(m7.ncf, m7.tc, cfg.rel_alarm_frac*m7.nominal, cfg.m7_detect_consec);
        td9(s) = relhit(m9.ncf, m9.tc, cfg.rel_alarm_frac*m9.nominal, cfg.m9_detect_consec);
    end

    m7mean = mean(B7, 2, 'omitnan');
    m9mean = mean(B9, 2, 'omitnan');
    h7 = tc7 <= cfg.switch_s - cfg.m7_buf/2;
    d7 = tc7 >= cfg.switch_s + cfg.m7_buf/2;
    h9 = tc9 <= cfg.switch_s - cfg.m9_buf/2;
    d9 = tc9 >= cfg.switch_s + cfg.m9_buf/2;
    m7_h = mean(m7mean(h7), 'omitnan');
    m7_d = mean(m7mean(d7), 'omitnan');
    m9_h = mean(m9mean(h9), 'omitnan');
    m9_d = mean(m9mean(d9), 'omitnan');

    row = table(string(cases(ci).name), ...
        m7_h, m7_d, abs(m7_d - truth.damaged_ncf), ...
        sum(~isnan(td7)), median(td7, 'omitnan'), ...
        m9_h, m9_d, abs(m9_d - truth.damaged_ncf), ...
        sum(~isnan(td9)), median(td9, 'omitnan'), ...
        median(F9(tc9 >= cfg.switch_s, :), 'all', 'omitnan'), ...
        'VariableNames', {'Case', 'M7Healthy', 'M7Damaged', 'M7DamageAbsError', ...
        'M7DetectSeeds', 'M7MedianDetect_s', 'M9Healthy', 'M9Damaged', ...
        'M9DamageAbsError', 'M9DetectSeeds', 'M9MedianDetect_s', 'M9MedianFreqHz'});
    rows{ci} = row;

    fprintf('\n[%s]\n', cases(ci).label)
    fprintf('  M7: healthy %.3f, damaged %.3f, error %.3f, rel-alarm %d/%d, median %.1f s\n', ...
        row.M7Healthy, row.M7Damaged, row.M7DamageAbsError, ...
        row.M7DetectSeeds, cfg.n_seed, row.M7MedianDetect_s)
    fprintf('  M9: healthy %.3f, damaged %.3f, error %.3f, rel-alarm %d/%d, median %.1f s, f~%.1f Hz\n', ...
        row.M9Healthy, row.M9Damaged, row.M9DamageAbsError, ...
        row.M9DetectSeeds, cfg.n_seed, row.M9MedianDetect_s, row.M9MedianFreqHz)

    case_result(ci).name = cases(ci).name;
    case_result(ci).label = cases(ci).label;
    case_result(ci).tc7 = tc7;
    case_result(ci).tc9 = tc9;
    case_result(ci).B7 = B7;
    case_result(ci).B9 = B9;
    case_result(ci).F9 = F9;
    case_result(ci).m7mean = m7mean;
    case_result(ci).m9mean = m9mean;
    case_result(ci).td7 = td7;
    case_result(ci).td9 = td9;
end

summary = vertcat(rows{:});
result = struct('summary', summary, 'cases', case_result, ...
    'truth', truth, 'config', cfg, 'created', datetime('now'));
end

function f = minFreq(m9)
use_st = m9.ncf_st <= m9.ncf_residual;
f = m9.f_residual;
f(use_st) = m9.f_st(use_st);
end

function plotSummary(plot_file, result)
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [80 80 1050 820]);
tl = tiledlayout(numel(result.cases), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
m7c = [0.00 0.486 0.659];
m9c = [0.224 0.749 0.369];
seed7 = [0.00 0.486 0.659 0.18];
seed9 = [0.224 0.749 0.369 0.22];
for ci = 1:numel(result.cases)
    c = result.cases(ci);
    nexttile; hold on
    plot(c.tc7, c.B7, '-', 'Color', seed7, 'LineWidth', 0.75)
    plot(c.tc9, c.B9, '-', 'Color', seed9, 'LineWidth', 0.75)
    h7 = plot(c.tc7, c.m7mean, '-o', 'Color', m7c, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.7, 'MarkerSize', 4);
    h9 = plot(c.tc9, c.m9mean, '-d', 'Color', m9c, 'MarkerFaceColor', 'w', ...
        'LineWidth', 2.0, 'MarkerSize', 4);
    yline(result.truth.healthy_ncf, '--', 'healthy true', 'Color', [0.35 0.35 0.35], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    yline(result.config.ncf_threshold, ':', '0.40 alarm', 'Color', [0.55 0.35 0.10], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    yline(result.truth.damaged_ncf, '--', 'damaged true', 'Color', [0.45 0.45 0.45], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    xline(result.truth.switch_s, '-', 'damage', 'Color', [0.56 0.08 0], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    grid on
    xlim([0 result.config.dur])
    ylim([0 0.75])
    ylabel('NCF margin')
    title(result.cases(ci).label, 'FontSize', 10)
    if ci == 1
        legend([h7 h9], {'M7 seed mean', 'M9 seed mean'}, 'Location', 'southwest')
    end
    if ci == numel(result.cases)
        xlabel('time (s)')
    end
end
title(tl, 'Method 9 adaptive margin vs Method 7, same three damage-jump cases')
exportgraphics(fig, plot_file, 'Resolution', 160)
close(fig)
end

function writeMarkdown(md_file, result)
fid = fopen(md_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Method 9 adaptive margin report\n\n');
fprintf(fid, 'Generated by `run_m9_vs_m7_compare.m`.\n\n');
fprintf(fid, 'M9 combines direct closed-loop `S,T` NCF where `dd_lead` excites a frequency with a wide residual-output spectrum where it does not. The search band is %.0f-%.0f Hz, with only the 60 Hz line rejected.\n\n', ...
    result.config.m9_band(1), result.config.m9_band(2));
fprintf(fid, 'True loop-only NCF: healthy `%.4f`, damaged `%.4f`.\n\n', ...
    result.truth.healthy_ncf, result.truth.damaged_ncf);
fprintf(fid, '## M7 vs M9 summary\n\n');
writeSummaryTable(fid, result.summary);
fprintf(fid, '\n![M9 vs M7 summary](m9_vs_m7_summary.png)\n\n');
fprintf(fid, '## Why M9 addresses the M7 issues\n\n');
fprintf(fid, '- M7 hard-codes a peak band. M9 searches %.0f-%.0f Hz point by point and reports the frequency that bound the estimate.\n', result.config.m9_band(1), result.config.m9_band(2));
fprintf(fid, '- M7 is relative to `b_nom` and `S_pk,ref`. M9 has an absolute phase-aware branch from `S=1-T`, `T=dm/dd_lead` whenever the band is excited; the model anchor is only the fallback scale for unexcited output-only evidence.\n');
fprintf(fid, '- If the instability is caused by phase delay instead of gain amplification, the `S,T` branch still sees the Nyquist distance shrink because it uses the complex transfer function, not only output amplitude.\n');
fprintf(fid, '- If the dangerous region is actually excited, M9 uses the measured complex FRF instead of waiting for a resonance peak to grow.\n');
fprintf(fid, '- If the dangerous region is not excited, M9 falls back to residual output noise after removing command-correlated output by coherence.\n');
end

function writeHtml(html_file, result, plot_file)
[~, plot_name, plot_ext] = fileparts(plot_file);
img = [plot_name plot_ext];
fid = fopen(html_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '<!doctype html>\n<html lang="en">\n<head>\n');
fprintf(fid, '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n');
fprintf(fid, '<title>Method 9 adaptive margin</title>\n');
fprintf(fid, '<style>\n');
fprintf(fid, 'body{margin:0;background:#f6f6f3;color:#1f2328;font:15px/1.55 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}.page{max-width:1120px;margin:0 auto;padding:28px}.top{border-bottom:1px solid #d8d8d2;padding-bottom:18px;margin-bottom:24px}h1{font-size:30px;line-height:1.15;margin:0 0 10px}h2{font-size:20px;margin:28px 0 10px}.lead{max-width:760px;color:#4d535a}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.box{border:1px solid #d8d8d2;background:#fff;padding:16px;border-radius:6px}.formula{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;background:#f1f1ed;border:1px solid #ddd;padding:10px;border-radius:4px;overflow:auto}table{border-collapse:collapse;width:100%%;background:#fff;border:1px solid #d8d8d2}th,td{padding:8px 10px;border-bottom:1px solid #e4e4df;text-align:left}th{font-size:12px;color:#5b6168;background:#f1f1ed}img{display:block;max-width:100%%;border:1px solid #d8d8d2;background:#fff}.good{color:#24733f;font-weight:650}.bad{color:#901500;font-weight:650}@media(max-width:760px){.grid{grid-template-columns:1fr}.page{padding:18px}table{font-size:13px}}\n');
fprintf(fid, '</style>\n</head>\n<body>\n<main class="page">\n');
fprintf(fid, '<section class="top"><h1>Method 9 adaptive margin</h1>');
fprintf(fid, '<p class="lead">M9 keeps the useful part of M7, but removes the fixed 35 Hz assumption. It uses a phase-aware closed-loop estimate when the command excites a frequency and a residual output-only estimate when it does not.</p></section>\n');
fprintf(fid, '<div class="grid"><div class="box"><h2>Estimator</h2><div class="formula">T = dm/dd_lead, S = 1 - T<br>NCF = 1/(sqrt(2)*max sqrt(|S|^2 + |T|^2))</div></div>');
fprintf(fid, '<div class="box"><h2>Fallback</h2><div class="formula">residual PSD = Pyy*(1 - coherence)<br>b = b0*sqrt(q_ref/q_now), searched over %.0f-%.0f Hz</div></div></div>\n', result.config.m9_band(1), result.config.m9_band(2));
fprintf(fid, '<h2>Branch logic</h2>\n');
fprintf(fid, '<p>Branch 2 and branch 3 deliberately look at different parts of the same closed-loop response. With command input <code>u = dd_lead</code>, measured output <code>y = dm</code>, loop transfer <code>L = C H</code>, sensitivity <code>S = 1/(1 + L)</code>, and complementary sensitivity <code>T = L/(1 + L)</code>, the measured response can be written as:</p>\n');
fprintf(fid, '<div class="formula">y(&omega;,t) = T(&omega;,t) u(&omega;,t) + S(&omega;,t) d(&omega;,t)</div>\n');
fprintf(fid, '<div class="grid">\n');
fprintf(fid, '<div class="box"><h2>Branch 2: excited bins</h2><p>This branch is used where the command has enough power. It estimates the command-correlated closed-loop transfer point by point:</p><div class="formula">T_hat(&omega;,t) = Phi_yu(&omega;,t) / Phi_uu(&omega;,t)<br>S_hat(&omega;,t) = 1 - T_hat(&omega;,t)<br>b_ST(t) = 1/(sqrt(2) max sqrt(|S_hat|^2 + |T_hat|^2))</div><p>If the dangerous frequency is externally excited, this branch sees both magnitude and phase. It can therefore detect a margin loss caused by phase delay even before a large output resonance appears.</p></div>\n');
fprintf(fid, '<div class="box"><h2>Branch 3: unexcited bins</h2><p>This branch is used as a wide-band output-only guard. It subtracts the output part explained by the command and tracks residual growth:</p><div class="formula">gamma^2 = |Phi_yu|^2/(Phi_uu Phi_yy)<br>Phi_res(&omega;,t) = Phi_yy(&omega;,t)(1 - gamma^2(&omega;,t))<br>q(t) = max Phi_res(&omega;,t)/Phi_res,ref(&omega;)<br>b_wide(t) = b0 sqrt(q_ref/q(t))</div><p>If an uncommanded mode grows from internal disturbance, branch 2 may not see it because the growth is not correlated with <code>u</code>. Branch 3 can still see the residual output energy.</p></div>\n');
fprintf(fid, '</div>\n');
fprintf(fid, '<p>Branch 3 can replace branch 1 in theory because both can detect unexcited output growth. The cost is interpretation. Branch 1 is a targeted known-mode proxy: it assumes the binding resonance is in a known peak band and maps its peak/floor ratio to margin. Branch 3 is broader and safer against shifted or unknown modes, but its baseline-normalized residual growth is a less direct NCF estimate.</p>\n');
fprintf(fid, '<div class="formula">Branch 1: known resonance, calibrated peak/floor margin proxy<br>Branch 3: unknown or shifted unexcited mode, wide residual-energy guard</div>\n');
fprintf(fid, '<h2>Table comparison</h2>\n');
writeHtmlTable(fid, result.summary);
fprintf(fid, '<h2>Seed plots</h2><img src="%s" alt="M7 and M9 seed plots across high-band, low-band, and mixed cases">\n', img);
fprintf(fid, '<h2>Interpretation</h2><p>M9 improves the three-case comparison by adding the wide residual branch for low-band operation and the complex S,T branch for excited operation. The same estimator also handles phase-delay failures because the S,T distance uses phase and magnitude together.</p>\n');
fprintf(fid, '</main>\n</body>\n</html>\n');
end

function writeSummaryTable(fid, summary)
fprintf(fid, '| Case | M7 healthy | M7 damaged | M7 abs error | M7 seeds | M7 median s | M9 healthy | M9 damaged | M9 abs error | M9 seeds | M9 median s | M9 freq Hz |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary)
    fprintf(fid, '| %s | %.3f | %.3f | %.3f | %d | %.1f | %.3f | %.3f | %.3f | %d | %.1f | %.1f |\n', ...
        summary.Case(i), summary.M7Healthy(i), summary.M7Damaged(i), ...
        summary.M7DamageAbsError(i), summary.M7DetectSeeds(i), summary.M7MedianDetect_s(i), ...
        summary.M9Healthy(i), summary.M9Damaged(i), summary.M9DamageAbsError(i), ...
        summary.M9DetectSeeds(i), summary.M9MedianDetect_s(i), summary.M9MedianFreqHz(i));
end
end

function writeHtmlTable(fid, summary)
fprintf(fid, '<table><thead><tr><th>Case</th><th>M7 damaged</th><th>M7 err</th><th>M7 seeds</th><th>M9 damaged</th><th>M9 err</th><th>M9 seeds</th><th>M9 freq</th></tr></thead><tbody>\n');
for i = 1:height(summary)
    cls = "good";
    if summary.M9DamageAbsError(i) > summary.M7DamageAbsError(i)
        cls = "bad";
    end
    fprintf(fid, '<tr><td>%s</td><td>%.3f</td><td>%.3f</td><td>%d/10</td><td class="%s">%.3f</td><td class="%s">%.3f</td><td class="%s">%d/10</td><td>%.1f Hz</td></tr>\n', ...
        summary.Case(i), summary.M7Damaged(i), summary.M7DamageAbsError(i), ...
        summary.M7DetectSeeds(i), cls, summary.M9Damaged(i), cls, ...
        summary.M9DamageAbsError(i), cls, summary.M9DetectSeeds(i), summary.M9MedianFreqHz(i));
end
fprintf(fid, '</tbody></table>\n');
end

function dd = grab(file, t0, N)
R = load(file);
i0 = find(R.result.t >= t0, 1);
dd = R.result.dd(i0:i0+N-1);
dd = dd - mean(dd);
end

function b = minNcf(C, H, band)
f = logspace(log10(band(1)), log10(band(2)), 4000).';
L = squeeze(freqresp(C*H, 2*pi*f));
b = min(abs(1 + L)./sqrt(2*(1 + abs(L).^2)));
end

function td = relhit(ncf, tc, thr, consec)
below = ncf < thr;
below(isnan(ncf)) = false;
hit = find(movsum(below, [consec-1, 0]) >= consec, 1);
td = NaN;
if ~isempty(hit)
    td = tc(hit);
end
end
