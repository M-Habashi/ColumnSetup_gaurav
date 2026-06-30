%% RUN_M9_VS_M7_COMPARE  Method 9.1 adaptive margin vs Method 7.
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
cfg.m9_buf = cfg.m7_buf;
cfg.m9_hop = 0.5;
cfg.m9_Lsub = 512;
cfg.m9_hsub = 256;
cfg.m9_bootstrap_strength = 1.0;
cfg.m9_gamma_min = 0.47;
cfg.m9_min_bins = 3;
cfg.m9_nwarm = 5;
cfg.m9_medfilt = 3;
cfg.m9_detect_consec = 1;
cfg.m9_calib_s = 7.5;
cfg.m9_cap = 0.70;
cfg.m9_residual_floor = 0.03;
cfg.m9_res_prctile = 99;
cfg.m9_residual_early_all_bins = true;
cfg.m9_res_early_match_hz = 4;
cfg.m9_res_early_st_floor_frac = 0.80;
cfg.m9_res_early_st_gate_frac = cfg.rel_alarm_frac;
cfg.m9_st_prctile = 100;
cfg.m9_st_power = 1.15;
cfg.m9_freq_medfilt = 3;
cfg.m9_line_reject = [58 62];
end

function [ctx0, cases, truth] = loadStudyContext(sr, cfg)
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'));
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
PL = load(fullfile(sr, 'phase_lead', 'pl_sp1_5000.mat'));
dt = 1/2048;
fs = 2048;
pv = H7.pid_values;
C = tf(pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
Hh = H7.models.H_dc_dm_d;
Hd = H5.models.H_dc_dm_d;
GT = c2d(PL.phase_lead_tf, dt, 'tustin');

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

fprintf('\n=== M9.1 adaptive margin vs M7 | true loop-only NCF %.3f -> %.3f ===\n', ...
    truth.healthy_ncf, truth.damaged_ncf)

for ci = 1:n_case
    dd_lead = lsim(ctx0.GT, cases(ci).dd, ctx0.t);
    trk_h = lsim(ctx0.Th, dd_lead, ctx0.t);
    trk_d = lsim(ctx0.Td, dd_lead, ctx0.t);
    ddlk = dd_lead(ctx0.keep);
    ctx = rmfield(ctx0, {'GT', 'Th', 'Sh', 'Td', 'Sd', 'sigma', 'N', 't', 'keep', 'jump_weight'});
    ctx.t = ctx0.tk;
    ctx.dd_lead = ddlk;

    tc7 = ((cfg.t_start + cfg.m7_buf):cfg.m7_hop:cfg.t_end).';
    tc9 = ((cfg.t_start + cfg.m9_buf):cfg.m9_hop:cfg.t_end).';
    B7 = nan(numel(tc7), cfg.n_seed);
    B9 = nan(numel(tc9), cfg.n_seed);
    F9 = nan(numel(tc9), cfg.n_seed);
    R7 = nan(cfg.n_seed, 1);
    R9 = nan(cfg.n_seed, 1);
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

        t7 = tic;
        m7 = osi_method7_resonance(ctx, cfg);
        R7(s) = toc(t7);
        t9 = tic;
        m9 = osi_method9_adaptive_margin(ctx, cfg);
        R9(s) = toc(t9);
        B7(:,s) = m7.ncf;
        B9(:,s) = m9.ncf;
        F9(:,s) = minFreq(m9);
        td7(s) = relhit(m7.ncf, m7.tc, cfg.rel_alarm_frac*m7.nominal, cfg.m7_detect_consec);
        td9(s) = relhit(m9.ncf, m9.tc, cfg.rel_alarm_frac*m9.nominal, cfg.m9_detect_consec);
    end

    m7mean = mean(B7, 2, 'omitnan');
    m9mean = mean(B9, 2, 'omitnan');
    h7 = tc7 <= cfg.switch_s;
    d7 = tc7 >= cfg.switch_s + cfg.m7_buf;
    h9 = tc9 <= cfg.switch_s;
    d9 = tc9 >= cfg.switch_s + cfg.m9_buf;
    m7_h = mean(m7mean(h7), 'omitnan');
    m7_d = mean(m7mean(d7), 'omitnan');
    m9_h = mean(m9mean(h9), 'omitnan');
    m9_d = mean(m9mean(d9), 'omitnan');

    row = table(string(cases(ci).name), ...
        m7_h, m7_d, abs(m7_d - truth.damaged_ncf), ...
        sum(~isnan(td7)), median(td7, 'omitnan'), ...
        m9_h, m9_d, abs(m9_d - truth.damaged_ncf), ...
        sum(~isnan(td9)), median(td9, 'omitnan'), ...
        median(F9(tc9 >= cfg.switch_s + cfg.m9_buf, :), 'all', 'omitnan'), ...
        1000*median(R7, 'omitnan'), 1000*median(R9, 'omitnan'), ...
        median(R9, 'omitnan')/median(R7, 'omitnan'), ...
        'VariableNames', {'Case', 'M7Healthy', 'M7Damaged', 'M7DamageAbsError', ...
        'M7DetectSeeds', 'M7MedianDetect_s', 'M9Healthy', 'M9Damaged', ...
        'M9DamageAbsError', 'M9DetectSeeds', 'M9MedianDetect_s', 'M9MedianFreqHz', ...
        'M7RuntimeMs', 'M9RuntimeMs', 'M9RuntimeRatio'});
    rows{ci} = row;

    fprintf('\n[%s]\n', cases(ci).label)
    fprintf('  M7: healthy %.3f, damaged %.3f, error %.3f, rel-alarm %d/%d, median %.1f s, %.0f ms/run\n', ...
        row.M7Healthy, row.M7Damaged, row.M7DamageAbsError, ...
        row.M7DetectSeeds, cfg.n_seed, row.M7MedianDetect_s, row.M7RuntimeMs)
    fprintf('  M9.1: healthy %.3f, damaged %.3f, error %.3f, rel-alarm %d/%d, median %.1f s, f~%.1f Hz, %.0f ms/run (%.2fx M7)\n', ...
        row.M9Healthy, row.M9Damaged, row.M9DamageAbsError, ...
        row.M9DetectSeeds, cfg.n_seed, row.M9MedianDetect_s, row.M9MedianFreqHz, ...
        row.M9RuntimeMs, row.M9RuntimeRatio)

    case_result(ci).name = cases(ci).name;
    case_result(ci).label = cases(ci).label;
    case_result(ci).tc7 = tc7;
    case_result(ci).tc9 = tc9;
    case_result(ci).B7 = B7;
    case_result(ci).B9 = B9;
    case_result(ci).F9 = F9;
    case_result(ci).R7 = R7;
    case_result(ci).R9 = R9;
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
seed7 = [0.00 0.486 0.659 0.24];
seed9 = [0.224 0.749 0.369 0.34];
for ci = 1:numel(result.cases)
    c = result.cases(ci);
    nexttile; hold on
    plot(c.tc7, c.B7, '-', 'Color', seed7, 'LineWidth', 0.75, ...
        'HandleVisibility', 'off')
    plot(c.tc9, c.B9, '-', 'Color', seed9, 'LineWidth', 0.95, ...
        'HandleVisibility', 'off')
    h7 = plot(c.tc7, c.m7mean, '-o', 'Color', m7c, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.7, 'MarkerSize', 4);
    h9 = plot(c.tc9, c.m9mean, '-d', 'Color', m9c, 'MarkerFaceColor', 'w', ...
        'LineWidth', 2.0, 'MarkerSize', 4);
    htrueh = yline(result.truth.healthy_ncf, '--', ...
        sprintf('true healthy NCF %.3f', result.truth.healthy_ncf), ...
        'Color', [0.22 0.22 0.22], 'LineWidth', 1.2, 'FontSize', 7);
    yline(result.config.ncf_threshold, ':', '0.40 alarm', 'Color', [0.55 0.35 0.10], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    htrued = yline(result.truth.damaged_ncf, '--', ...
        sprintf('true damaged NCF %.3f', result.truth.damaged_ncf), ...
        'Color', [0.48 0.48 0.48], 'LineWidth', 1.2, 'FontSize', 7);
    xline(result.truth.switch_s, '-', 'damage', 'Color', [0.56 0.08 0], ...
        'HandleVisibility', 'off', 'FontSize', 7);
    grid on
    xlim([0 result.config.dur])
    ylim([0 0.75])
    ylabel('NCF margin')
    title(result.cases(ci).label, 'FontSize', 10)
    text(0.995, 0.045, 'M9.1 seeds: noise + spectral bootstrap', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 7, 'Color', [0.30 0.30 0.30])
    if ci == 1
        legend([h7 h9 htrueh htrued], {'M7 seed mean', 'M9.1 seed mean', ...
            'true healthy NCF', 'true damaged NCF'}, 'Location', 'southwest')
    end
    if ci == numel(result.cases)
        xlabel('time (s), causal window end')
    end
end
title(tl, 'Method 9.1 adaptive margin vs Method 7, causal window-end timestamps')
exportgraphics(fig, plot_file, 'Resolution', 160)
close(fig)
end

function writeMarkdown(md_file, result)
fid = fopen(md_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Method 9.1 adaptive margin report\n\n');
fprintf(fid, 'Generated by `run_m9_vs_m7_compare.m`.\n\n');
fprintf(fid, 'All plotted and reported times are causal window-end times: each point uses only samples at or before that timestamp.\n\n');
fprintf(fid, 'M9.1 combines direct closed-loop `S,T` NCF where `dd_lead` excites a frequency with an input-quiet residual-output fallback. A frequency-matched full-band residual early-warning path is enabled, but it is bounded by the direct `S,T` branch when both bind at the same frequency. Branch 1 is not used. The search band is %.0f-%.0f Hz, with only the 60 Hz line rejected.\n\n', ...
    result.config.m9_band(1), result.config.m9_band(2));
fprintf(fid, 'True loop-only NCF: healthy `%.4f`, damaged `%.4f`.\n\n', ...
    result.truth.healthy_ncf, result.truth.damaged_ncf);
fprintf(fid, '**Seed-spread note.** M9.1 seed spread includes the injected noise/disturbance seed plus a bootstrap perturbation of the spectral subsegments. It is still not a full model-uncertainty interval, but it avoids plotting a deterministic averaged estimator as if it had no finite-window estimation uncertainty.\n\n');
fprintf(fid, '## M7 vs M9.1 summary\n\n');
writeSummaryTable(fid, result.summary);
fprintf(fid, '\n![M9.1 vs M7 summary](m9_vs_m7_summary.png)\n\n');
fprintf(fid, '## Why M9.1 addresses the M7 issues\n\n');
fprintf(fid, '- M7 hard-codes a peak band. M9.1 searches %.0f-%.0f Hz point by point and reports the frequency that bound the estimate.\n', result.config.m9_band(1), result.config.m9_band(2));
fprintf(fid, '- M7 is relative to `b_nom` and `S_pk,ref`. M9.1 uses the absolute phase-aware branch from `S=1-T`, `T=dm/dd_lead` on excited/coherent bins, and uses the residual branch for output-only evidence.\n');
fprintf(fid, '- If the instability is caused by phase delay instead of gain amplification, the `S,T` branch still sees the Nyquist distance shrink because it uses the complex transfer function, not only output amplitude.\n');
fprintf(fid, '- If the dangerous region is actually excited, M9.1 uses the measured complex FRF instead of waiting for a resonance peak to grow.\n');
fprintf(fid, '- If the dangerous region is not excited, M9.1 falls back to input-quiet residual output noise after removing command-correlated output by coherence.\n');
fprintf(fid, '- If residual growth appears at the same frequency as the direct `S,T` branch before `S,T` crosses the relative alarm level, M9.1 allows that residual evidence to pull the margin down early, but not below %.0f%% of the direct `S,T` estimate.\n', 100*result.config.m9_res_early_st_floor_frac);
end

function writeHtml(html_file, result, plot_file)
[~, plot_name, plot_ext] = fileparts(plot_file);
img = [plot_name plot_ext];
fid = fopen(html_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '<!doctype html>\n<html lang="en">\n<head>\n');
fprintf(fid, '<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n');
fprintf(fid, '<title>Method 9.1 adaptive margin</title>\n');
fprintf(fid, '<style>\n');
fprintf(fid, 'body{margin:0;background:#f6f6f3;color:#1f2328;font:15px/1.55 ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}.page{max-width:1120px;margin:0 auto;padding:28px}.top{border-bottom:1px solid #d8d8d2;padding-bottom:18px;margin-bottom:24px}h1{font-size:30px;line-height:1.15;margin:0 0 10px}h2{font-size:20px;margin:28px 0 10px}h3{font-size:16px;margin:0 0 8px}.lead{max-width:820px;color:#4d535a}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.box{border:1px solid #d8d8d2;background:#fff;padding:16px;border-radius:6px}.box p{margin:8px 0}.formula{background:#f1f1ed;border:1px solid #ddd;padding:12px;border-radius:4px;overflow:auto;margin:10px 0}.note{border-left:3px solid #007ca8;padding:8px 12px;background:#eef6f8}.compact{margin-top:6px}.muted{color:#5b6168}.step{border-top:1px solid #e4e4df;padding-top:12px;margin-top:12px}.truth{display:flex;gap:14px;flex-wrap:wrap}.pill{border:1px solid #d8d8d2;background:#fff;padding:10px 12px;border-radius:6px}.pill b{display:block;font-size:20px}code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.94em}table{border-collapse:collapse;width:100%%;background:#fff;border:1px solid #d8d8d2}th,td{padding:8px 10px;border-bottom:1px solid #e4e4df;text-align:left}th{font-size:12px;color:#5b6168;background:#f1f1ed}img{display:block;max-width:100%%;border:1px solid #d8d8d2;background:#fff}.good{color:#24733f;font-weight:650}.bad{color:#901500;font-weight:650}@media(max-width:760px){.grid{grid-template-columns:1fr}.page{padding:18px}table{font-size:13px}}\n');
fprintf(fid, '</style>\n<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>\n');
fprintf(fid, '</head>\n<body>\n<main class="page">\n');
fprintf(fid, '<section class="top"><h1>Method 9.1 adaptive margin</h1>');
fprintf(fid, '<p class="lead">M9.1 uses only branch 2 and branch 3: a complex closed-loop FRF where the command excites the loop, plus residual output growth for output-only evidence. All plotted and reported times are causal window-end times. Branch 1 is ignored.</p></section>\n');
writeHtmlTheory(fid, result.config);
fprintf(fid, '<h2>True NCF references</h2><div class="truth">');
fprintf(fid, '<div class="pill"><span class="muted">Healthy true NCF</span><b>%.3f</b></div>', ...
    result.truth.healthy_ncf);
fprintf(fid, '<div class="pill"><span class="muted">Damaged true NCF</span><b>%.3f</b></div>', ...
    result.truth.damaged_ncf);
fprintf(fid, '<div class="pill"><span class="muted">Damage time</span><b>%.1f s</b></div>', ...
    result.truth.switch_s);
fprintf(fid, '</div><p class="compact muted">The dashed horizontal lines in the seed plot are these true loop-only NCF values, not seed-dependent estimates.</p>\n');
fprintf(fid, '<h2>Seed spread</h2><p class="note">M9.1 seed spread includes injected noise/disturbance variability plus a bootstrap perturbation of the spectral subsegments. It is still not a full model-uncertainty interval, but it avoids plotting a deterministic averaged estimator as if finite-window spectral uncertainty were zero.</p>\n');
fprintf(fid, '<p>Between seeds, the plant, controller, damage timing, and command profile are fixed. What changes is the disturbance/noise realization, and for M9.1 the spectral-bootstrap perturbation used inside each finite-window estimate. The differences below are therefore estimator/data-window variability around the same true NCF values.</p>\n');
writeHtmlSeedSpread(fid, result);
fprintf(fid, '<h2>Table comparison</h2>\n');
writeHtmlTable(fid, result.summary);
fprintf(fid, '<h2>Seed plots</h2><img src="%s" alt="M7 and M9.1 seed plots across high-band, low-band, and mixed cases">\n', img);
fprintf(fid, '<h2>Interpretation</h2><p>M9.1 improves the three-case comparison by matching M7''s damage-reduction timing while preserving the direct phase-aware branch. The residual branch is normally input-quiet, with a frequency-matched early-warning path bounded by the direct S,T estimate; branch 1 is no longer computed or selected.</p>\n');
fprintf(fid, '</main>\n</body>\n</html>\n');
end

function writeHtmlTheory(fid, cfg)
fprintf(fid, '<div class="grid">\n');
fprintf(fid, '<div class="box"><h2>Input-excited band</h2><p>Use branch 2 when \\(dd_{\\mathrm{lead}}\\) has enough power and coherence is acceptable. The estimator reads the command-correlated transfer and converts the complex \\(S,T\\) pair into an NCF distance.</p><div class="formula">\\[\n');
fprintf(fid, '\\widehat T(\\omega,t)=\\frac{\\Phi_{yu}(\\omega,t)}{\\Phi_{uu}(\\omega,t)},\\qquad\n');
fprintf(fid, '\\widehat S(\\omega,t)=1-\\widehat T(\\omega,t)\n');
fprintf(fid, '\\]</div></div>\n');
fprintf(fid, '<div class="box"><h2>Residual branch</h2><p>Use branch 3 for output-only evidence. The normal path searches input-quiet bins; a frequency-matched early-warning path may scan the full band when the direct S,T branch is already moving at the same frequency.</p><div class="formula">\\[\n');
fprintf(fid, '\\Phi_{\\mathrm{res}}(\\omega,t)\\approx\n');
fprintf(fid, '\\Phi_{yy}(\\omega,t)\\left(1-\\gamma^2(\\omega,t)\\right)\n');
fprintf(fid, '\\]</div></div>\n</div>\n');

fprintf(fid, '<h2>Notation</h2>\n<div class="box">\n');
fprintf(fid, '<p class="compact">Let \\(u=dd_{\\mathrm{lead}}\\), \\(y=dm\\), \\(d\\) be internal disturbance or noise, \\(H\\) be the plant path from command force/displacement action to measured displacement, and \\(C\\) be the controller.</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'L(\\omega,t)=C(\\omega)H(\\omega,t),\\qquad\n');
fprintf(fid, 'S(\\omega,t)=\\frac{1}{1+L(\\omega,t)},\\qquad\n');
fprintf(fid, 'T(\\omega,t)=\\frac{L(\\omega,t)}{1+L(\\omega,t)}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p class="compact">The measured output is the sum of a command-correlated part and an internally excited part:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'y(\\omega,t)=T(\\omega,t)u(\\omega,t)+S(\\omega,t)d(\\omega,t)\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p class="compact">Here \\(\\Phi_{ab}\\) means the cross-spectrum between signals \\(a\\) and \\(b\\), and \\(\\Phi_{aa}\\) is the autospectrum of \\(a\\).</p>\n');
fprintf(fid, '</div>\n');

fprintf(fid, '<h2>Branch 2: input-excited band</h2>\n<div class="box">\n');
fprintf(fid, '<h3>Step 1: require identifiable input power</h3><p>M9.1 only trusts branch 2 on bins where the input has enough power and the estimated input-output relation is coherent:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Omega_{\\mathrm{exc}}(t)=\n');
fprintf(fid, '\\left\\{\\omega:\n');
fprintf(fid, '\\Phi_{uu}(\\omega,t)\\ \\text{is large enough},\\quad\n');
fprintf(fid, '\\gamma^2(\\omega,t)\\ge \\gamma_{\\min}\n');
fprintf(fid, '\\right\\}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<div class="step"><h3>Step 2: estimate the command-correlated transfer</h3><p>Using the output equation, the cross-spectrum with the command is:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Phi_{yu}(\\omega,t)=\n');
fprintf(fid, 'T(\\omega,t)\\Phi_{uu}(\\omega,t)\n');
fprintf(fid, '+S(\\omega,t)\\Phi_{du}(\\omega,t)\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>If the internal disturbance is not correlated with the command, \\(\\Phi_{du}\\approx0\\). Then:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\widehat T(\\omega,t)=\n');
fprintf(fid, '\\frac{\\Phi_{yu}(\\omega,t)}{\\Phi_{uu}(\\omega,t)}\n');
fprintf(fid, '\\approx T(\\omega,t)\n');
fprintf(fid, '\\]</div></div>\n');
fprintf(fid, '<div class="step"><h3>Step 3: convert \\(S,T\\) into margin</h3><p>For unity feedback, \\(S=1-T\\). The NCF loop distance at one frequency can be written directly from \\(S,T\\):</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'b(\\omega,t)=\n');
fprintf(fid, '\\frac{1}{\\sqrt{2}\\sqrt{|S(\\omega,t)|^2+|T(\\omega,t)|^2}}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>M9.1 uses the largest distance over qualified excited/coherent bins:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\tilde b_{ST}(t)=\n');
fprintf(fid, '\\frac{1}{\\sqrt{2}\\,\n');
fprintf(fid, '\\max_{\\omega\\in\\Omega_{\\mathrm{exc}}(t)}\n');
fprintf(fid, '\\left(\\sqrt{|\\widehat S(\\omega,t)|^2+|\\widehat T(\\omega,t)|^2}\\right)}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>A small finite-window correction sharpens sub-nominal branch-2 margins while leaving the healthy nominal point anchored:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'b_{ST}(t)=\n');
fprintf(fid, 'b_0\\left(\\frac{\\tilde b_{ST}(t)}{b_0}\\right)^{%.2f},\\qquad \\tilde b_{ST}(t)<b_0\n', cfg.m9_st_power);
fprintf(fid, '\\]</div></div>\n');
fprintf(fid, '<p class="note">This branch is the phase-aware branch. If the dangerous frequency is externally excited, it can detect margin loss caused by phase delay even before a large output-only resonance is visible.</p>\n');
fprintf(fid, '</div>\n');

fprintf(fid, '<h2>Branch 3: residual output evidence</h2>\n<div class="box">\n');
fprintf(fid, '<h3>Step 1: decompose the output spectrum</h3><p>When \\(u\\) and \\(d\\) are approximately uncorrelated, the total output spectrum is:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Phi_{yy}(\\omega,t)=\n');
fprintf(fid, '\\underbrace{|T(\\omega,t)|^2\\Phi_{uu}(\\omega,t)}_{\\text{command-correlated output}}\n');
fprintf(fid, '+\n');
fprintf(fid, '\\underbrace{|S(\\omega,t)|^2\\Phi_{dd}(\\omega)}_{\\text{residual/internal output}}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<div class="step"><h3>Step 2: use coherence to remove the command-correlated part</h3>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\gamma^2(\\omega,t)=\n');
fprintf(fid, '\\frac{|\\Phi_{yu}(\\omega,t)|^2}\n');
fprintf(fid, '{\\Phi_{uu}(\\omega,t)\\Phi_{yy}(\\omega,t)}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>The residual output spectrum is approximated as:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Phi_{\\mathrm{res}}(\\omega,t)\\approx\n');
fprintf(fid, '\\Phi_{yy}(\\omega,t)\\left(1-\\gamma^2(\\omega,t)\\right)\n');
fprintf(fid, '\\]</div></div>\n');
fprintf(fid, '<div class="step"><h3>Step 3: search residual growth</h3><p>Branch 3 compares the current residual spectrum with the healthy reference spectrum. The normal fallback searches outside the branch-2 excited/coherent bins:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Omega_{\\mathrm{quiet}}(t)=\\Omega_{\\mathrm{wide}}\\setminus\\Omega_{\\mathrm{exc}}(t),\\qquad\n');
fprintf(fid, 'q(t)=\n');
fprintf(fid, '\\max_{\\omega\\in\\Omega_{\\mathrm{quiet}}(t)}\n');
fprintf(fid, '\\frac{\\Phi_{\\mathrm{res}}(\\omega,t)}\n');
fprintf(fid, '{\\Phi_{\\mathrm{res,ref}}(\\omega)}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>Then it maps the residual growth to a conservative margin proxy:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'b_{\\mathrm{wide}}(t)=\n');
fprintf(fid, 'b_0\\sqrt{\\frac{q_{\\mathrm{ref}}}{q(t)}}\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>For faster damage-reduction detection, M9.1 also checks a full-band residual candidate. It is accepted only when it binds within %.1f Hz of the direct S,T branch and S,T has already moved below nominal but not below the relative alarm level. In that case the residual candidate is bounded below by %.0f%% of the direct S,T margin.</p></div>\n', cfg.m9_res_early_match_hz, 100*cfg.m9_res_early_st_floor_frac);
fprintf(fid, '<div class="step"><h3>Why this sees what branch 2 can miss</h3><p>If a mode grows from internal disturbance or noise, then the residual spectrum contains:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Phi_{\\mathrm{res}}(\\omega,t)\\approx\n');
fprintf(fid, '|S(\\omega,t)|^2\\Phi_{dd}(\\omega)\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p>So branch 3 can catch output-only resonance growth when the command has almost no power at that frequency, and the bounded early-warning path can also catch the first residual growth at an already-observed S,T frequency:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, '\\Phi_{uu}(\\omega)\\approx0\n');
fprintf(fid, '\\]</div></div>\n</div>\n');

fprintf(fid, '<h2>Final branch selection</h2>\n<div class="box">\n');
fprintf(fid, '<p>M9.1 computes no known-mode peak/floor branch. Each window keeps only the lower margin from branch 2 and branch 3:</p>\n');
fprintf(fid, '<div class="formula">\\[\n');
fprintf(fid, 'b_{M9.1}(t)=\\min\\left(b_{ST}(t), b_{\\mathrm{wide}}(t)\\right)\n');
fprintf(fid, '\\]</div>\n');
fprintf(fid, '<p class="note">This makes branch 3 the only output-only fallback. There is no branch-1 peak mask, no branch-1 calibrated proxy, and no final minimum against a branch-1 estimate.</p>\n');
fprintf(fid, '</div>\n');
end

function writeSummaryTable(fid, summary)
fprintf(fid, '| Case | M7 healthy | M7 damaged | M7 abs error | M7 seeds | M7 median s | M9.1 healthy | M9.1 damaged | M9.1 abs error | M9.1 seeds | M9.1 median s | M9.1 freq Hz | M7 ms | M9.1 ms | M9.1/M7 |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(summary)
    fprintf(fid, '| %s | %.3f | %.3f | %.3f | %d | %.1f | %.3f | %.3f | %.3f | %d | %.1f | %.1f | %.0f | %.0f | %.2f |\n', ...
        summary.Case(i), summary.M7Healthy(i), summary.M7Damaged(i), ...
        summary.M7DamageAbsError(i), summary.M7DetectSeeds(i), summary.M7MedianDetect_s(i), ...
        summary.M9Healthy(i), summary.M9Damaged(i), summary.M9DamageAbsError(i), ...
        summary.M9DetectSeeds(i), summary.M9MedianDetect_s(i), summary.M9MedianFreqHz(i), ...
        summary.M7RuntimeMs(i), summary.M9RuntimeMs(i), summary.M9RuntimeRatio(i));
end
end

function writeHtmlTable(fid, summary)
fprintf(fid, '<table><thead><tr><th>Case</th><th>M7 damaged</th><th>M7 err</th><th>M7 seeds</th><th>M9.1 damaged</th><th>M9.1 err</th><th>M9.1 seeds</th><th>M9.1 freq</th><th>M7 ms</th><th>M9.1 ms</th><th>M9.1/M7</th></tr></thead><tbody>\n');
for i = 1:height(summary)
    cls = "good";
    if summary.M9DamageAbsError(i) > summary.M7DamageAbsError(i)
        cls = "bad";
    end
    speed_cls = "good";
    if summary.M9RuntimeRatio(i) > 1.20
        speed_cls = "bad";
    end
    fprintf(fid, '<tr><td>%s</td><td>%.3f</td><td>%.3f</td><td>%d/10</td><td class="%s">%.3f</td><td class="%s">%.3f</td><td class="%s">%d/10</td><td>%.1f Hz</td><td>%.0f</td><td class="%s">%.0f</td><td class="%s">%.2fx</td></tr>\n', ...
        summary.Case(i), summary.M7Damaged(i), summary.M7DamageAbsError(i), ...
        summary.M7DetectSeeds(i), cls, summary.M9Damaged(i), cls, ...
        summary.M9DamageAbsError(i), cls, summary.M9DetectSeeds(i), summary.M9MedianFreqHz(i), ...
        summary.M7RuntimeMs(i), speed_cls, summary.M9RuntimeMs(i), speed_cls, summary.M9RuntimeRatio(i));
end
fprintf(fid, '</tbody></table>\n');
end

function writeHtmlSeedSpread(fid, result)
fprintf(fid, '<table><thead><tr><th>Case</th><th>What differs</th><th>M9.1 damaged seed range</th><th>M9.1 max seed spread</th><th>M9.1 detection range</th><th>M7 damaged seed range</th><th>M7 detection range</th></tr></thead><tbody>\n');
for i = 1:numel(result.cases)
    c = result.cases(i);
    d9 = c.tc9 >= result.config.switch_s + result.config.m9_buf;
    d7 = c.tc7 >= result.config.switch_s + result.config.m7_buf;
    m9_seed_damaged = mean(c.B9(d9, :), 1, 'omitnan');
    m7_seed_damaged = mean(c.B7(d7, :), 1, 'omitnan');
    m9_window_spread = max(c.B9, [], 2, 'omitnan') ...
        - min(c.B9, [], 2, 'omitnan');
    m9_detect = formatRange(c.td9);
    m7_detect = formatRange(c.td7);
    fprintf(fid, '<tr><td>%s</td><td>noise realization + M9.1 spectral bootstrap</td><td>%.3f-%.3f</td><td>%.3f</td><td>%s</td><td>%.3f-%.3f</td><td>%s</td></tr>\n', ...
        c.name, min(m9_seed_damaged, [], 'omitnan'), ...
        max(m9_seed_damaged, [], 'omitnan'), ...
        max(m9_window_spread, [], 'omitnan'), m9_detect, ...
        min(m7_seed_damaged, [], 'omitnan'), ...
        max(m7_seed_damaged, [], 'omitnan'), m7_detect);
end
fprintf(fid, '</tbody></table>\n');
fprintf(fid, '<p class="compact muted">Damaged seed range is the per-seed mean after the estimator buffer has cleared the damage step. Max seed spread is the largest vertical separation between M9.1 seed traces at any plotted timestamp.</p>\n');
end

function text = formatRange(values)
values = values(~isnan(values));
if isempty(values)
    text = 'none';
elseif min(values) == max(values)
    text = sprintf('%.1f s', min(values));
else
    text = sprintf('%.1f-%.1f s', min(values), max(values));
end
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
