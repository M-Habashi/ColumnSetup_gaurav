%% RUN_ADAPTIVE_PID_STUDY
% Adaptive PID authority-gain study using the production OSI M9.1 estimator.

clearvars; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_main = fileparts(fileparts(fileparts(script_dir)));
addpath(script_dir);
addpath(fullfile(script_dir, 'params'));
addpath(fullfile(project_main, 'control_and_HS', 'OSI'));
addpath(fullfile(project_main, 'control_and_HS', 'OSI', 'OSI_utils'));
addpath(fullfile(project_main, 'research', 'optimizing_pl', 'claude'));

cfg = adaptive_pid_config();
context = loadStudyContext(project_main, cfg);
result = runStudy(context, cfg);

result_file = fullfile(script_dir, 'results', 'adaptive_pid_result.mat');
save(result_file, 'result');

plot_files = plotStudy(script_dir, result);
report_file = fullfile(script_dir, 'adaptive_pid_report.md');
writeReport(report_file, result, plot_files);
html_file = fullfile(script_dir, 'adaptive_pid_case_comparison.html');
writeHtmlReport(html_file, result, plot_files);

disp(result.summary)
fprintf('\nSaved result: %s\n', result_file)
fprintf('Saved report: %s\n', report_file)
fprintf('Saved HTML:   %s\n', html_file)
for i = 1:numel(plot_files)
    fprintf('Saved plot:   %s\n', plot_files{i})
end

function context = loadStudyContext(project_main, cfg)
sr = fullfile(project_main, 'saved_results');
H7 = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'), ...
    'pid_values', 'models', 'source_noise_std');
if isfield(H7.models, 'H_dc_dm_d')
    Hh = H7.models.H_dc_dm_d;
else
    Hh = c2d(H7.H_dc_dm, cfg.dt, 'zoh');
end
pid_nominal = H7.pid_values;
C0 = pidFromValues(pid_nominal, cfg.dt);
[cases, osi_ctx] = osi_test_cases(struct('dt', cfg.dt, ...
    'sigma', H7.source_noise_std, 'C0', C0, 'Hh', Hh, ...
    'Hd', loadDamagedPlant(sr, cfg.dt)));

N = round(cfg.duration_s*cfg.fs) + 1;
excitations = loadExcitations(project_main, N);
disturbance = cfg.disturbance_scale*H7.source_noise_std*fixedNoise(N, 501);
context = struct('project_main', project_main, 'cases', cases, ...
    'excitations', excitations, 'osi_ctx', osi_ctx, ...
    'pid_nominal', pid_nominal, 'C0', C0, 'Hh', Hh, ...
    'disturbance', disturbance, 'L0', C0*Hh, ...
    'freq_hz', logspace(log10(cfg.margin_band_hz(1)), ...
    log10(cfg.margin_band_hz(2)), cfg.margin_grid_count).');
end

function Hd = loadDamagedPlant(sr, dt)
H5 = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'models', 'H_dc_dm');
if isfield(H5.models, 'H_dc_dm_d')
    Hd = H5.models.H_dc_dm_d;
else
    Hd = c2d(H5.H_dc_dm, dt, 'zoh');
end
end

function excitations = loadExcitations(project_main, N)
important = fullfile(project_main, 'saved_results', 'tests', 'important');
high = grabCommand(fullfile(important, ...
    '20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    620, N);
low = grabCommand(fullfile(important, ...
    '20260617_1749_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat'), ...
    100, N);

excitations = repmat(struct('id', "", 'name', "", 'command', []), 3, 1);
excitations(1) = makeExcitation("high", "high-band 1731", high);
excitations(2) = makeExcitation("low", "low-band 1749", low);
excitations(3) = makeExcitation("mixed", "mixed high + low", high + 0.75*low);
end

function excitation = makeExcitation(id, name, command)
command = command(:) - mean(command(:));
command = command/max(std(command), eps);
excitation = struct('id', string(id), 'name', string(name), ...
    'command', command);
end

function command = grabCommand(file, t0, N)
R = load(file, 'result');
i0 = find(R.result.t >= t0, 1);
command = R.result.dd(i0:i0+N-1);
command = command(:) - mean(command(:));
end

function x = fixedNoise(N, seed)
rng(seed);
x = randn(N, 1);
end

function result = runStudy(context, cfg)
win = windowInfo(numel(context.excitations(1).command), cfg);
n_run = numel(context.excitations)*numel(context.cases);
baseline = repmat(emptySimulation(), n_run, 1);
adaptive = repmat(emptySimulation(), n_run, 1);
rows = cell(n_run, 1);
run_id = 0;

fprintf('\nAdaptive PID authority-gain study using OSI m91_adaptive_margin.m\n')
fprintf('Target NCF margin: %.3f\n', cfg.target_margin)

for ei = 1:numel(context.excitations)
    excitation = context.excitations(ei);
    for ci = 1:numel(context.cases)
        run_id = run_id + 1;
        case_info = caseInfo(context.cases(ci), context, cfg);
        baseline(run_id) = simulateCase(case_info, excitation, context, ...
            cfg, win, false);
        adaptive(run_id) = simulateCase(case_info, excitation, context, ...
            cfg, win, true);
        rows{run_id} = scoreCase(excitation, case_info, ...
            baseline(run_id), adaptive(run_id), cfg);
    end
end

summary = sortrows(vertcat(rows{:}), {'ExcitationId', 'CaseId'});
overall = table(mean(summary.AdaptiveBelowArea), ...
    max(summary.AdaptivePeakShortfall), ...
    min(summary.AdaptiveMinTrueNCF), ...
    min(summary.AdaptiveSettledMinTrueNCF), ...
    mean(summary.MethodScore), ...
    'VariableNames', {'MeanBelowArea', 'WorstPeakShortfall', ...
    'WorstMinTrueNCF', 'WorstSettledMinTrueNCF', 'MeanScore'});
result = struct('config', cfg, 'cases', {context.cases}, ...
    'excitations', context.excitations, 'tc', win.tc, ...
    'baseline', baseline, 'adaptive', adaptive, ...
    'summary', summary, 'overall', overall, 'created', datetime('now'));
end

function sim = emptySimulation()
sim = struct('excitation_id', "", 'excitation_name', "", ...
    'case_id', "", 'case_name', "", 'method_label', "", 'tc', [], ...
    'ncf_true', [], 'ncf_m91', [], 'ncf_m91_guarded', [], ...
    'P_scale', [], 'I_scale', [], 'D_scale', [], 'authority', [], ...
    'binding_hz', [], 'm91_binding_hz', [], 'margin_filtered', []);
end

function win = windowInfo(N, cfg)
window_n = round(cfg.m91_override.window_s*cfg.fs);
hop_n = round(cfg.m91_override.update_interval_s*cfg.fs);
n_window = floor((N - window_n)/hop_n) + 1;
tc = ((0:n_window-1)'*hop_n + window_n)*cfg.dt;
win = struct('window_n', window_n, 'hop_n', hop_n, ...
    'n_window', n_window, 'tc', tc, ...
    't_window', (0:window_n-1)'*cfg.dt);
end

function info = caseInfo(raw_case, context, cfg)
target_H = raw_case.H;
if raw_case.delay_samples > 0
    target_H = target_H*tf(1, [1 zeros(1, raw_case.delay_samples)], cfg.dt);
end
target_pid = context.pid_nominal;
if strcmp(raw_case.id, 'C4')
    target_pid = cfg.c4_pid;
end
info = struct('id', string(raw_case.id), 'name', string(raw_case.name), ...
    'mechanism', string(raw_case.mechanism), ...
    'nominal_C', context.C0, 'nominal_H', context.Hh, ...
    'nominal_pid', context.pid_nominal, ...
    'target_C', raw_case.C, 'target_H', target_H, ...
    'target_pid', target_pid);
end

function sim = simulateCase(case_info, excitation, context, cfg, win, ...
        is_adaptive)
m91_cfg = m91_adaptive_margin('config', cfg.dt, context.L0, ...
    cfg.m91_override);
m91_state = m91_adaptive_margin('state', m91_cfg);
authority = 1;
authority_state = initialAuthorityState(cfg);

n = win.n_window;
ncf_true = NaN(n, 1);
ncf_m91 = NaN(n, 1);
ncf_m91_guarded = NaN(n, 1);
authority_history = ones(n, 1);
margin_filtered = cfg.target_margin*ones(n, 1);
binding_hz = NaN(n, 1);
m91_binding_hz = NaN(n, 1);

for k = 1:n
    idx = (k-1)*win.hop_n + (1:win.window_n);
    use_target = win.tc(k) >= cfg.event_time_s;
    [base_pid, base_C, H] = loopBase(case_info, use_target);
    if is_adaptive
        C = authorityController(base_pid, authority, cfg);
    else
        C = base_C;
    end

    ncf_true(k) = trueNcf(C, H, context.freq_hz);
    binding_hz(k) = bindingFrequency(C, H, context.freq_hz);
    dm = simulateWindow(C, H, excitation.command(idx), ...
        context.disturbance(idx), win.t_window, cfg);
    [ncf_m91(k), m91_state, m91_info] = m91_adaptive_margin( ...
        excitation.command(idx), dm, m91_cfg, m91_state);
    m91_binding_hz(k) = estimatedM91BindingHz(m91_info);
    authority_history(k) = authority;

    if is_adaptive
        [authority, authority_state] = updateAuthority(authority, ...
            authority_state, ncf_m91(k), cfg);
        ncf_m91_guarded(k) = authority_state.margin_guarded;
        margin_filtered(k) = authority_state.margin_filtered;
    else
        ncf_m91_guarded(k) = ncf_m91(k);
        margin_filtered(k) = ncf_m91(k);
    end
end

label = "fixed PID";
if is_adaptive
    label = "authority gain, fast-down slow-up";
end
sim = struct('excitation_id', excitation.id, ...
    'excitation_name', excitation.name, ...
    'case_id', case_info.id, 'case_name', case_info.name, ...
    'method_label', label, 'tc', win.tc, 'ncf_true', ncf_true, ...
    'ncf_m91', ncf_m91, 'ncf_m91_guarded', ncf_m91_guarded, ...
    'P_scale', authority_history, 'I_scale', authority_history, ...
    'D_scale', authority_history, 'authority', authority_history, ...
    'binding_hz', binding_hz, 'm91_binding_hz', m91_binding_hz, ...
    'margin_filtered', margin_filtered);
end

function [base_pid, base_C, H] = loopBase(case_info, use_target)
if use_target
    base_pid = case_info.target_pid;
    base_C = case_info.target_C;
    H = case_info.target_H;
else
    base_pid = case_info.nominal_pid;
    base_C = case_info.nominal_C;
    H = case_info.nominal_H;
end
end

function C = authorityController(base_pid, authority, cfg)
C = pidFromValues(struct('P', authority*base_pid.P, ...
    'I', authority*base_pid.I, 'D', authority*base_pid.D, ...
    'derivative_filter_N', base_pid.derivative_filter_N), cfg.dt);
end

function state = initialAuthorityState(cfg)
state = struct('margin_filtered', cfg.target_margin, ...
    'margin_guarded', cfg.target_margin, 'above_count', 0, ...
    'below_count', 0);
end

function [authority, state] = updateAuthority(authority, state, margin, cfg)
p = cfg.authority_gain;
[authority, state.margin_filtered, state.margin_guarded, ...
    state.above_count, state.below_count] = adaptive_pid_authority_step( ...
    margin, authority, state.margin_filtered, state.margin_guarded, ...
    state.above_count, state.below_count, cfg.target_margin, ...
    cfg.m91_override.update_interval_s, p.a_min, p.a_max, ...
    p.down_deadband, p.down_rate, p.down_immediate_margin, ...
    p.down_confirm_n, p.up_deadband, p.power, p.smooth_down, ...
    p.up_rate, p.up_hold_s, p.margin_guard_up_rate, ...
    p.margin_guard_down_rate, p.margin_filter_alpha);
end

function f = estimatedM91BindingHz(info)
f = NaN;
if ~isstruct(info)
    return
end
use_st = isfield(info, 'ncf_st') && isfield(info, 'ncf_residual') ...
    && info.ncf_st <= info.ncf_residual;
if use_st && isfield(info, 'f_st_hz')
    f = info.f_st_hz;
elseif isfield(info, 'f_residual_hz')
    f = info.f_residual_hz;
end
end

function dm = simulateWindow(C, H, command, disturbance, t, cfg)
T = feedback(C*H, 1);
S = feedback(1, C*H);
dm = lsim(T, command(:), t) + lsim(S, disturbance(:), t);
noise_scale = cfg.measurement_noise_fraction*max(std(dm), eps);
dm = dm + noise_scale*fixedNoise(numel(dm), 3000 + numel(dm));
dm = dm(:);
end

function C = pidFromValues(pid_values, dt)
C = tf(pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler'));
end

function b = trueNcf(C, H, freq_hz)
L = squeeze(freqresp(C*H, 2*pi*freq_hz));
dist = abs(1 + L(:))./sqrt(2*(1 + abs(L(:)).^2));
b = min(dist);
end

function f = bindingFrequency(C, H, freq_hz)
L = squeeze(freqresp(C*H, 2*pi*freq_hz));
dist = abs(1 + L(:))./sqrt(2*(1 + abs(L(:)).^2));
[~, idx] = min(dist);
f = freq_hz(idx);
end

function row = scoreCase(excitation, case_info, base, adapt, cfg)
short_base = max(0, cfg.target_margin - base.ncf_true);
short_adapt = max(0, cfg.target_margin - adapt.ncf_true);
dt = median(diff(base.tc));
base_area = sum(short_base)*dt;
adapt_area = sum(short_adapt)*dt;
peak_short = max(short_adapt);
authority_motion = mean(abs(diff(adapt.authority)));
score = cfg.penalty_below*adapt_area ...
    + cfg.penalty_peak_shortfall*peak_short ...
    + cfg.penalty_authority_motion*authority_motion;
row = table(excitation.id, excitation.name, case_info.id, ...
    case_info.name, min(base.ncf_true), min(adapt.ncf_true), ...
    settledMin(base, cfg), settledMin(adapt, cfg), ...
    base_area, adapt_area, max(short_base), peak_short, ...
    mean(adapt.ncf_true), mean(adapt.ncf_m91), min(adapt.authority), ...
    max(adapt.authority), score, ...
    'VariableNames', {'ExcitationId', 'ExcitationName', 'CaseId', ...
    'CaseName', 'FixedMinTrueNCF', 'AdaptiveMinTrueNCF', ...
    'FixedSettledMinTrueNCF', 'AdaptiveSettledMinTrueNCF', ...
    'FixedBelowArea', 'AdaptiveBelowArea', 'FixedPeakShortfall', ...
    'AdaptivePeakShortfall', 'AdaptiveMeanTrueNCF', ...
    'AdaptiveMeanM91NCF', 'MinAuthority', 'MaxAuthority', ...
    'MethodScore'});
end

function value = settledMin(sim, cfg)
mask = sim.tc >= cfg.event_time_s + cfg.settled_eval_delay_s;
if ~any(mask)
    mask = true(size(sim.tc));
end
value = min(sim.ncf_true(mask));
end

function plot_files = plotStudy(script_dir, result)
plot_dir = fullfile(script_dir, 'plots');
plot_files = cell(numel(result.excitations) + 1, 1);
plot_files{1} = fullfile(plot_dir, 'adaptive_pid_authority_summary.png');
plotSummary(plot_files{1}, result);
for ei = 1:numel(result.excitations)
    plot_files{ei + 1} = fullfile(plot_dir, sprintf( ...
        'adaptive_pid_authority_%s.png', result.excitations(ei).id));
    plotCaseGrid(plot_files{ei + 1}, result, ei);
end
end

function plotSummary(file, result)
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [80 80 1100 520]);
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile;
bar(ax, [mean(result.summary.FixedBelowArea), ...
    mean(result.summary.AdaptiveBelowArea)])
set(ax, 'XTickLabel', {'fixed PID', 'adaptive authority'})
grid(ax, 'on')
ylabel(ax, 'mean below-target area')
title(ax, 'Penalty exposure')

ax = nexttile;
bar(ax, [min(result.summary.FixedSettledMinTrueNCF), ...
    min(result.summary.AdaptiveSettledMinTrueNCF)])
yline(ax, result.config.target_margin, '--', 'target')
set(ax, 'XTickLabel', {'fixed PID', 'adaptive authority'})
grid(ax, 'on')
ylim(ax, [0 0.72])
ylabel(ax, 'worst settled true NCF')
title(ax, 'Post-adaptation margin')

exportgraphics(fig, file, 'Resolution', 170)
close(fig)
end

function plotCaseGrid(file, result, excitation_index)
excitation = result.excitations(excitation_index);
mask = result.summary.ExcitationId == excitation.id;
idx_run = find(mask);
n_case = numel(idx_run);
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [80 60 1250 280*n_case]);
tiledlayout(fig, n_case, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

blue = [0.000 0.486 0.659];
copper = [0.675 0.392 0.125];
purple = [0.455 0.020 0.541];
gray = [0.45 0.45 0.45];
green = [0.224 0.749 0.369];
red = [0.565 0.082 0.000];

for j = 1:n_case
    ri = idx_run(j);
    base = result.baseline(ri);
    adapt = result.adaptive(ri);
    ax = nexttile; hold(ax, 'on')
    plot(ax, base.tc, base.ncf_true, '--', 'Color', [0 0 0], ...
        'LineWidth', 1.3, 'DisplayName', 'fixed true')
    plot(ax, base.tc, base.ncf_m91, ':', 'Color', gray, ...
        'LineWidth', 1.1, 'DisplayName', 'fixed M9.1')
    plot(ax, adapt.tc, adapt.ncf_true, '-', 'Color', blue, ...
        'LineWidth', 1.8, 'DisplayName', 'adaptive true')
    plot(ax, adapt.tc, adapt.ncf_m91, '-', 'Color', copper, ...
        'LineWidth', 1.3, 'DisplayName', 'adaptive M9.1 raw')
    yline(ax, result.config.target_margin, ':', 'target', ...
        'Color', red, 'HandleVisibility', 'off')
    xline(ax, result.config.event_time_s, '-', 'case switch', ...
        'Color', [0.25 0.25 0.25], 'HandleVisibility', 'off')
    grid(ax, 'on')
    ylim(ax, [0 0.75])
    ylabel(ax, 'NCF margin')
    title(ax, sprintf('%s: %s', base.case_id, base.case_name))
    if j == 1
        legend(ax, 'Location', 'southwest')
    end
    if j == n_case
        xlabel(ax, 'time (s), causal window end')
    end

    ax = nexttile; hold(ax, 'on')
    plot(ax, adapt.tc, adapt.P_scale, '-', 'Color', blue, ...
        'LineWidth', 1.4, 'DisplayName', 'P scale')
    plot(ax, adapt.tc, adapt.I_scale, '-', 'Color', purple, ...
        'LineWidth', 1.4, 'DisplayName', 'I scale')
    plot(ax, adapt.tc, adapt.D_scale, '-', 'Color', green, ...
        'LineWidth', 1.4, 'DisplayName', 'D scale')
    plot(ax, adapt.tc, adapt.authority, '--', 'Color', copper, ...
        'LineWidth', 1.3, 'DisplayName', 'authority')
    xline(ax, result.config.event_time_s, '-', 'case switch', ...
        'Color', [0.25 0.25 0.25], 'HandleVisibility', 'off')
    grid(ax, 'on')
    ylim(ax, [0 1.05])
    ylabel(ax, 'gain multiplier')
    title(ax, 'authority gain, fast down and slow up')
    if j == 1
        legend(ax, 'Location', 'northeast')
    end
    if j == n_case
        xlabel(ax, 'time (s), causal window end')
    end
end

sgtitle(fig, sprintf('Adaptive PID authority, %s excitation', ...
    excitation.name))
exportgraphics(fig, file, 'Resolution', 170)
close(fig)
end

function writeReport(report_file, result, plot_files)
fid = fopen(report_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Adaptive PID authority gain with M9.1 margin feedback\n\n');
fprintf(fid, 'Generated by `run_adaptive_pid_study.m`.\n\n');
fprintf(fid, 'The OSI estimator used here is `main/control_and_HS/OSI/m91_adaptive_margin.m`. The earlier research implementation is not called.\n\n');
fprintf(fid, 'Target NCF margin: `%.3f`. Change it in `params/adaptive_pid_config.m` using `cfg.target_margin`.\n\n', ...
    result.config.target_margin);
fprintf(fid, 'The adaptive law is uniform PID authority scaling: `P`, `I`, and `D` are multiplied by the same authority factor `a` while derivative-filter `N` is unchanged.\n\n');
fprintf(fid, 'The Simulink/Speedgoat-compatible authority update is encapsulated in `adaptive_pid_authority_step.m`; the study calls that same function.\n\n');
fprintf(fid, 'Excitations are now explicit: high-band, low-band, and mixed high + low.\n\n');

fprintf(fid, '## Authority law\n\n');
fprintf(fid, 'When M9.1 estimates margin below target, authority drops quickly from the raw margin ratio, with a bounded per-update downward slew to avoid injecting authority-step transients:\n\n');
fprintf(fid, '`a_desired = a * (max(m91_margin, 0.05) / target_margin)^power`\n\n');
fprintf(fid, 'Raw M9.1 is preserved in `ncf_m91` and is always the M9.1 trace shown in the plots. The adaptive law also forms an internal guarded margin. Severe dips below `down_immediate_margin` pass immediately, moderate dips must persist for `down_confirm_n` updates, and non-severe guarded-margin movement is rate-limited; this keeps the adaptation from chasing estimator spikes without changing or hiding the raw M9.1 estimate.\n\n');
fprintf(fid, 'When guarded margin is above target, authority only recovers after it stays above the upper deadband for the configured hold time, then rises by a small rate limit. Configure this in `cfg.authority_gain`.\n\n');

fprintf(fid, '## Summary\n\n');
fprintf(fid, '| mean fixed below area | mean adaptive below area | reduction | worst fixed settled true NCF | worst adaptive settled true NCF | mean score |\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|\n');
fixed_area = mean(result.summary.FixedBelowArea);
adaptive_area = mean(result.summary.AdaptiveBelowArea);
reduction = 100*(fixed_area - adaptive_area)/max(fixed_area, eps);
fprintf(fid, '| %.3f | %.3f | %.1f %% | %.3f | %.3f | %.3f |\n\n', ...
    fixed_area, adaptive_area, reduction, ...
    min(result.summary.FixedSettledMinTrueNCF), ...
    result.overall.WorstSettledMinTrueNCF, result.overall.MeanScore);
fprintf(fid, '![authority summary](plots/%s)\n\n', fileName(plot_files{1}));

fprintf(fid, '## Case details\n\n');
fprintf(fid, '| Excitation | Case | fixed min true NCF | adaptive settled min true NCF | fixed below area | adaptive below area | min authority | max authority |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(result.summary)
    r = result.summary(i, :);
    fprintf(fid, '| %s | %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n', ...
        char(r.ExcitationId), char(r.CaseId), r.FixedMinTrueNCF, ...
        r.AdaptiveSettledMinTrueNCF, r.FixedBelowArea, ...
        r.AdaptiveBelowArea, r.MinAuthority, r.MaxAuthority);
end

fprintf(fid, '\n## Plots\n\n');
for i = 2:numel(plot_files)
    suffix = [newline newline];
    if i == numel(plot_files)
        suffix = newline;
    end
    fprintf(fid, '![%s](plots/%s)%s', ...
        char(result.excitations(i-1).name), fileName(plot_files{i}), suffix);
end
end

function writeHtmlReport(html_file, result, plot_files)
fid = fopen(html_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fixed_area = mean(result.summary.FixedBelowArea);
adaptive_area = mean(result.summary.AdaptiveBelowArea);
reduction = 100*(fixed_area - adaptive_area)/max(fixed_area, eps);

fprintf(fid, '<!doctype html>\n<html lang="en">\n<head>\n');
fprintf(fid, '<meta charset="utf-8">\n');
fprintf(fid, '<meta name="viewport" content="width=device-width, initial-scale=1">\n');
fprintf(fid, '<title>Adaptive PID Authority Case Comparison</title>\n');
fprintf(fid, '<style>\n');
fprintf(fid, ':root{color-scheme:dark;--bg:#09090b;--panel:#18181b;--line:#3f3f46;--soft:#27272a;--text:#f4f4f5;--muted:#a1a1aa;--blue:#007ca8;--copper:#ac6420;--red:#901500;--green:#39bf5e}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 Arial,Helvetica,sans-serif}.wrap{max-width:1180px;margin:0 auto;padding:28px 20px 36px}header{border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:22px}h1{font-size:28px;line-height:1.15;margin:0 0 10px}h2{font-size:18px;margin:24px 0 10px}.lead{max-width:850px;color:var(--muted);margin:0}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:18px 0 8px}.metric{background:var(--panel);border:1px solid var(--line);border-radius:4px;padding:12px}.metric b{display:block;font-size:20px;margin-bottom:2px}.metric span{color:var(--muted);font-size:12px}.figure{border:1px solid var(--line);background:#fff;border-radius:4px;padding:8px;margin:12px 0 24px}.figure img{display:block;width:100%%;height:auto}.table-wrap{overflow:auto;border:1px solid var(--line);border-radius:4px;background:var(--panel)}table{border-collapse:collapse;width:100%%;min-width:1040px}th,td{border-bottom:1px solid var(--soft);padding:9px 10px;text-align:right;white-space:nowrap}th:first-child,td:first-child,th:nth-child(2),td:nth-child(2),th:nth-child(3),td:nth-child(3){text-align:left}th{color:var(--muted);font-weight:600;background:#111113}.good{color:var(--green);font-weight:700}.bad{color:#ffb4a8;font-weight:700}.note{border-left:3px solid var(--blue);padding:9px 12px;background:var(--panel);color:var(--muted)}code{font-family:Consolas,monospace;color:#e4e4e7}@media(max-width:780px){.metrics{grid-template-columns:1fr 1fr}.wrap{padding:20px 14px}h1{font-size:23px}}@media(max-width:520px){.metrics{grid-template-columns:1fr}}\n');
fprintf(fid, '</style>\n</head>\n<body>\n<main class="wrap">\n');
fprintf(fid, '<header>\n<h1>Adaptive PID Authority Case Comparison</h1>\n');
fprintf(fid, '<p class="lead">Authority-only adaptive PID study using production OSI M9.1 at a %.3f s update interval. Plots show raw M9.1. An internal guarded post-estimator margin and fast bounded authority slew keep adaptation from chasing spikes without delaying safety drops.</p>\n', result.config.m91_override.update_interval_s);
fprintf(fid, '</header>\n');

fprintf(fid, '<section class="metrics">\n');
fprintf(fid, '<div class="metric"><b>%.3f s</b><span>M9.1 update interval</span></div>\n', result.config.m91_override.update_interval_s);
fprintf(fid, '<div class="metric"><b>%.3f</b><span>target NCF margin</span></div>\n', result.config.target_margin);
fprintf(fid, '<div class="metric"><b>%.1f%%</b><span>below-target area reduction</span></div>\n', reduction);
fprintf(fid, '<div class="metric"><b>%.3f</b><span>worst adaptive settled true NCF</span></div>\n', result.overall.WorstSettledMinTrueNCF);
fprintf(fid, '</section>\n');

fprintf(fid, '<p class="note">Excitations are explicit: high-band, low-band, and mixed high + low. The immediate post-switch minimum is shared by causal adaptive runs before enough M9.1 window data is available; the settled metric starts after the configured reaction delay.</p>\n');
fprintf(fid, '<p class="note">The authority update used here is the standalone code-generation-friendly function <code>adaptive_pid_authority_step.m</code>, intended for a Simulink MATLAB Function block with scalar state feedback.</p>\n');
fprintf(fid, '<h2>Summary Plot</h2>\n<div class="figure"><img src="plots/%s" alt="Summary of fixed PID versus adaptive authority penalty exposure and settled NCF margin"></div>\n', fileName(plot_files{1}));
fprintf(fid, '<h2>Case Comparison</h2>\n<div class="table-wrap">\n<table>\n<thead><tr><th>Excitation</th><th>Case</th><th>Name</th><th>Fixed min true NCF</th><th>Adaptive settled true NCF</th><th>Fixed below area</th><th>Adaptive below area</th><th>Reduction</th><th>Min authority</th><th>Max authority</th></tr></thead>\n<tbody>\n');
for i = 1:height(result.summary)
    r = result.summary(i, :);
    case_reduction = 100*(r.FixedBelowArea - r.AdaptiveBelowArea) ...
        /max(r.FixedBelowArea, eps);
    cls = 'good';
    if r.AdaptiveSettledMinTrueNCF < result.config.target_margin
        cls = 'bad';
    end
    fprintf(fid, '<tr><td>%s</td><td>%s</td><td>%s</td><td>%.3f</td><td class="%s">%.3f</td><td>%.3f</td><td>%.3f</td><td>%.1f%%</td><td>%.3f</td><td>%.3f</td></tr>\n', ...
        char(r.ExcitationId), char(r.CaseId), htmlEscape(char(r.CaseName)), ...
        r.FixedMinTrueNCF, cls, r.AdaptiveSettledMinTrueNCF, ...
        r.FixedBelowArea, r.AdaptiveBelowArea, case_reduction, ...
        r.MinAuthority, r.MaxAuthority);
end
fprintf(fid, '</tbody>\n</table>\n</div>\n');

fprintf(fid, '<h2>Margins And Authority Over Time</h2>\n');
for i = 2:numel(plot_files)
    fprintf(fid, '<h2>%s excitation</h2>\n<div class="figure"><img src="plots/%s" alt="Per-case NCF margin and authority traces for %s excitation"></div>\n', ...
        htmlEscape(char(result.excitations(i-1).name)), ...
        fileName(plot_files{i}), htmlEscape(char(result.excitations(i-1).name)));
end
fprintf(fid, '<h2>Authority Law</h2>\n');
fprintf(fid, '<p class="note"><code>a_desired = a * (max(m91_margin, 0.05) / target_margin)^power</code>. The plot shows raw adaptive M9.1. Internally, severe M9.1 dips below <code>down_immediate_margin</code> still reduce authority immediately; moderate dips must persist for <code>down_confirm_n</code> updates. Authority then applies <code>down_rate</code> to avoid step transients. Upward authority recovery waits on a guarded margin with bounded non-severe movement through <code>margin_guard_up_rate</code> and <code>margin_guard_down_rate</code>, plus an upper deadband, hold time, and small rate limit.</p>\n');
fprintf(fid, '</main>\n</body>\n</html>\n');
end

function name = fileName(path)
[~, n, e] = fileparts(path);
name = [n e];
end

function text = htmlEscape(text)
text = strrep(text, '&', '&amp;');
text = strrep(text, '<', '&lt;');
text = strrep(text, '>', '&gt;');
text = strrep(text, '"', '&quot;');
end
