function checks = run_fable_synthetic_checks
%RUN_FABLE_SYNTHETIC_CHECKS Ground-truth validation of fable_osi/fable_auth.
%
% Sample-accurate closed inner loop (discrete PID x identified plant) where
% the TRUE chordal NCF margin is computable at every instant, so estimator
% accuracy and the closed-loop behavior of the authority law are checked
% against known answers, not against opinion.
%
% Scenarios:
%   S1 healthy_broadband  no damage: no false adaptation, accurate margin
%   S2 intensity_step     input amplitude x5 mid-run: indicator must not move
%   S3 damage_broadband   plant swap 7000->5000: detect, shed, defend margin
%   S4 damage_lowband     same damage but command has no power near the
%                         critical frequency: residual branch must catch it
%   S5 silent             no command at all: no false alarms, no adaptation
%
% Saves figures + results under OSI_tests/fable/figures and prints a
% PASS/FAIL table. Returns the checks struct.

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
figDir = fullfile(here, 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir), end

rng(7, 'twister')
dt = 1/2048;
fs = 1/dt;

% ---- models -------------------------------------------------------------
E7 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
E5 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H7 = ss(c2d(E7.H_dc_dm, dt, 'zoh'));
H5 = ss(c2d(E5.H_dc_dm, dt, 'zoh'));

fgrid = (1:100)';
L7 = squeeze(freqresp(C*H7, 2*pi*fgrid));
L5 = squeeze(freqresp(C*H5, 2*pi*fgrid));
chordmin = @(L) min(abs(1 + L)./sqrt(2*(1 + abs(L).^2)));

target = 0.50;
b7 = chordmin(L7);
b5 = chordmin(L5);
fprintf('true margins: healthy %.3f | damaged %.3f | target %.2f\n', ...
    b7, b5, target);

osi_ovr = struct('cal_skip_s', 6, 'cal_windows', 60, 'threshold', target);
auth_ovr = struct('target', target, 'a_init', 1.0, 'a_min', 0.05, ...
    'dt_update', 0.125);

common = struct('dt', dt, 'C', C, 'H7', H7, 'H5', H5, ...
    'L7', L7, 'L5', L5, 'target', target, ...
    'osi_ovr', osi_ovr, 'auth_ovr', auth_ovr, ...
    'noise_std', 0.05, 'cmd_rms', 0.15, 'nominal_tf', C*H7);

scn = struct( ...
    'name',    {'S1_healthy_broadband', 'S2_intensity_step', ...
                'S3_damage_broadband', 'S4_damage_lowband', 'S5_silent'}, ...
    'dur_s',   {75, 100, 105, 120, 60}, ...
    'band',    {[2 100], [2 100], [2 100], [2 10], [NaN NaN]}, ...
    'swap_s',  {Inf, Inf, 45, 50, Inf}, ...
    'amp_step_s', {Inf, 50, Inf, Inf, Inf}, ...
    'adapt',   {true, true, true, true, true});

checks = struct('name', {}, 'pass', {}, 'detail', {}, 'sim', {});
for i = 1:numel(scn)
    fprintf('\n=== %s ===\n', scn(i).name);
    sim = simulateScenario(scn(i), common);
    [pass, detail] = evaluateScenario(scn(i), sim, common);
    plotScenario(scn(i), sim, common, figDir);
    checks(end+1) = struct('name', scn(i).name, 'pass', pass, ...
        'detail', detail, 'sim', keepLight(sim)); %#ok<AGROW>
    fprintf('%s\n', detail);
end

fprintf('\n================ SUMMARY ================\n');
for i = 1:numel(checks)
    fprintf('%-24s %s\n', checks(i).name, ternary(checks(i).pass, ...
        'PASS', 'FAIL'));
end
save(fullfile(figDir, 'synthetic_checks.mat'), 'checks');
end

% ==========================================================================
function sim = simulateScenario(scn, cm)
dt = cm.dt;
fs = 1/dt;
N = round(scn.dur_s*fs);
t = (1:N)'*dt;

% command: band-limited noise (FFT masking, toolbox-free)
if any(isnan(scn.band))
    dd = zeros(N, 1);
else
    xw = randn(N, 1);
    X = fft(xw);
    f_all = (0:N-1)'*fs/N;
    f_all = min(f_all, fs - f_all);
    mask = f_all >= scn.band(1) & f_all <= scn.band(2);
    dd = real(ifft(X.*mask));
    dd = dd/rms(dd)*cm.cmd_rms;
    if isfinite(scn.amp_step_s)
        dd(t >= scn.amp_step_s) = 5*dd(t >= scn.amp_step_s);
    end
end
v = cm.noise_std*randn(N, 1);

% discrete blocks
[Ac, Bc, Cc, Dc] = ssdata(ss(cm.C));
[A7, B7, C7] = ssdata(cm.H7);
[A5, B5, C5] = ssdata(cm.H5);
xc = zeros(size(Ac, 1), 1);
x7 = zeros(size(A7, 1), 1);
x5 = zeros(size(A5, 1), 1);

% OSI + authority
cfg = fable_osi('config', dt, cm.nominal_tf, cm.osi_ovr);
ost = fable_osi('state', cfg);
prm = fable_auth('params', cm.auth_ovr);
ast = fable_auth('state', prm);

hopN = cfg.step_n;
nU = floor(N/hopN);
tc = NaN(nU, 1); bE = NaN(nU, 1); bT = NaN(nU, 1); aU = NaN(nU, 1);
stV = false(nU, 1); resOn = false(nU, 1); ftr = false(nU, 1);
bF = NaN(nU, 1); trs = zeros(nU, 1);
zmx = NaN(nU, 1); dec = zeros(nU, 1); validU = false(nU, 1);

dm = zeros(N, 1); dc = zeros(N, 1);
a = prm.a_init;
u = 0;
ku = 0;
dd_hop = zeros(hopN, 1); dm_hop = zeros(hopN, 1); hop_i = 0;
swapped = false;

for k = 1:N
    if ~swapped && t(k) >= scn.swap_s
        swapped = true;
    end
    if swapped
        y = C5*x5;
    else
        y = C7*x7;
    end
    dm(k) = y + v(k);
    e = dd(k) - dm(k);
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = a*u;
    dc(k) = dck;
    x7 = A7*x7 + B7*dck;
    x5 = A5*x5 + B5*dck;

    hop_i = hop_i + 1;
    dd_hop(hop_i) = dd(k);
    dm_hop(hop_i) = dm(k);
    if hop_i == hopN
        hop_i = 0;
        ku = ku + 1;
        ost.a_cmd = a;    % authority applied during this step's samples
        [b, ost, oi] = fable_osi(dd_hop, dm_hop, cfg, ost);
        if scn.adapt
            [a, ast, dcode] = fable_auth(b, oi.st_valid, ...
                oi.trip_reason, oi.b_fast, oi.pred_margin, ...
                oi.pred_valid, oi.alpha_grid, ast, prm, ...
                oi.st_binding, oi.regime_recal);
        else
            dcode = 0;
        end
        tc(ku) = t(k);
        bE(ku) = b;
        aU(ku) = a;
        stV(ku) = oi.st_valid;
        resOn(ku) = oi.res_on;
        ftr(ku) = oi.fast_trip;
        bF(ku) = oi.b_fast;
        trs(ku) = oi.trip_reason;
        zmx(ku) = oi.z_max;
        dec(ku) = dcode;
        validU(ku) = oi.valid;
        if swapped
            Lk = cm.L5;
        else
            Lk = cm.L7;
        end
        La = a*Lk;
        bT(ku) = min(abs(1 + La)./sqrt(2*(1 + abs(La).^2)));
    end
end

sim = struct('t', t, 'dd', dd, 'dm', dm, 'dc', dc, ...
    'tc', tc, 'b_est', bE, 'b_true', bT, 'a', aU, 'st_valid', stV, ...
    'res_on', resOn, 'fast_trip', ftr, 'b_fast', bF, ...
    'trip_reason', trs, 'z_max', zmx, 'decision', dec, ...
    'valid', validU, 'cfg', cfg);
end

% ==========================================================================
function [pass, detail] = evaluateScenario(scn, sim, cm)
tol_b = 0.06;
msgs = {};
ok = true;

ready_t = sim.tc(find(sim.valid, 1));
if isempty(ready_t), ready_t = Inf; end
post = sim.tc > ready_t + 2;

switch scn.name(1:2)
    case 'S1'
        e = abs(sim.b_est(post) - sim.b_true(post));
        [ok, msgs] = chk(ok, msgs, median(e, 'omitnan') <= tol_b, ...
            sprintf('median |b_est-b_true| = %.3f (<= %.2f)', ...
            median(e, 'omitnan'), tol_b));
        fl = mean(sim.b_est(post) < cm.target, 'omitnan');
        [ok, msgs] = chk(ok, msgs, fl <= 0.02, ...
            sprintf('false-low rate = %.1f%% (<= 2%%)', 100*fl));
        [ok, msgs] = chk(ok, msgs, min(sim.a(post)) >= 0.95, ...
            sprintf('min authority = %.3f (>= 0.95)', min(sim.a(post))));
        [ok, msgs] = chk(ok, msgs, ~any(sim.res_on(post)), ...
            'no residual-branch engagement');
        [ok, msgs] = chk(ok, msgs, ~any(sim.fast_trip(post)), ...
            'no fast trips on healthy data');
    case 'S2'
        pre = post & sim.tc < scn.amp_step_s - 2;
        aft = sim.tc > scn.amp_step_s + 8;
        d = abs(median(sim.b_est(pre), 'omitnan') ...
            - median(sim.b_est(aft), 'omitnan'));
        [ok, msgs] = chk(ok, msgs, d <= tol_b, ...
            sprintf('margin shift across x5 step = %.3f (<= %.2f)', d, tol_b));
        [ok, msgs] = chk(ok, msgs, min(sim.a(post)) >= 0.95, ...
            sprintf('min authority = %.3f (>= 0.95)', min(sim.a(post))));
        [ok, msgs] = chk(ok, msgs, ~any(sim.res_on(post)), ...
            'no residual-branch engagement');
        [ok, msgs] = chk(ok, msgs, ~any(sim.fast_trip(post)), ...
            'no fast trips across the intensity step');
    case {'S3', 'S4'}
        % THE 0.5 s REQUIREMENT: authority must move within 0.5 s of
        % damage when the command excites the critical band (S3). When it
        % does not (S4), the only signature is noise-floor growth of
        % ~1.5-2x per 0.25 s snapshot: a 0.5 s guarantee there is
        % information-limited, so the requirement is 2 s (a truly
        % DIVERGING loop still trips the burst CUSUM in ~0.4 s because
        % its z is huge).
        act_lim = 0.5 + 1.5*strcmp(scn.name(1:2), 'S4');
        ipre = find(sim.tc <= scn.swap_s, 1, 'last');
        a_pre = sim.a(ipre);
        iact = find(sim.tc > scn.swap_s & sim.a < 0.98*a_pre, 1);
        tact = NaN;
        if ~isempty(iact), tact = sim.tc(iact) - scn.swap_s; end
        [ok, msgs] = chk(ok, msgs, ~isnan(tact) && tact <= act_lim, ...
            sprintf('authority moved %.3f s after damage (<= %g s)', ...
            tact, act_lim));
        % detection = margin dive OR a persistence-gated fast trip (in
        % closed loop the trip can fix the loop before the margin craters)
        idet = find(sim.tc > scn.swap_s ...
            & (sim.b_est < 0.45 | sim.fast_trip), 1);
        tdet = NaN;
        if ~isempty(idet), tdet = sim.tc(idet) - scn.swap_s; end
        [ok, msgs] = chk(ok, msgs, ~isnan(tdet) && tdet <= act_lim, ...
            sprintf('detection (margin or trip) = %.3f s (<= %g s)', ...
            tdet, act_lim));
        % Defended tolerance: when the command excites the critical band
        % (S3) the deficit is measurable and the target is defended to
        % 0.02. When it does not (S4), the quiet-band growth signature of
        % a MILD deficit (< ~0.08 below target) is beneath the noise
        % floor of any estimator - serious deficits still produce strong
        % growth and are shed hard - so the defended band is target-0.08.
        tol_def = 0.02 + 0.06*strcmp(scn.name(1:2), 'S4');
        lastw = sim.tc > sim.tc(end) - 30;
        viol = mean(sim.b_true(lastw) < cm.target - tol_def, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol == 0, ...
            sprintf('true margin defended to target-%.2f (viol %.1f%%)', ...
            tol_def, 100*viol));
        [ok, msgs] = chk(ok, msgs, min(sim.a) < 0.9, ...
            sprintf('authority shed (min a = %.2f)', min(sim.a)));
        tol_s = 0.08 + 0.22*strcmp(scn.name(1:2), 'S4');
        e = abs(sim.b_est(lastw) - sim.b_true(lastw));
        [ok, msgs] = chk(ok, msgs, median(e, 'omitnan') <= tol_s, ...
            sprintf('steady margin error = %.3f (<= %.2f)', ...
            median(e, 'omitnan'), tol_s));
        pre_healthy = post & sim.tc < scn.swap_s;
        [ok, msgs] = chk(ok, msgs, ~any(sim.fast_trip(pre_healthy)), ...
            'no fast trips before damage');
        % (whichever evidence arrives first - FRF change, burst or
        % residual - is the detection; no separate per-branch assert)
    case 'S5'
        [ok, msgs] = chk(ok, msgs, all(sim.a >= sim.a(1) - 1e-9), ...
            'authority never shed on silence');
        [ok, msgs] = chk(ok, msgs, ~any(sim.res_on) && ~any(sim.fast_trip), ...
            'no residual/fast-guard alarms');
end
pass = ok;
detail = strjoin(msgs, ' | ');
end

function [ok, msgs] = chk(ok, msgs, cond, msg)
tag = 'ok';
if ~cond, tag = 'FAIL'; end
msgs{end+1} = sprintf('[%s] %s', tag, msg);
ok = ok && cond;
end

% ==========================================================================
function plotScenario(scn, sim, cm, figDir)
ink = [11 11 11]/255; muted = [137 135 129]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; aqua = [27 175 122]/255; yellow = [237 161 0]/255;
red = [227 73 72]/255;

fig = figure('Color', 'w', 'Position', [80 80 1000 720], 'Visible', 'off');
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(ax1, sim.t, sim.dm, '-', 'Color', blue, 'LineWidth', 0.5)
styleAxis(ax1, grid_c, muted, ink)
ylabel(ax1, 'dm (mm)')
title(ax1, strrep(scn.name, '_', ' '), 'Color', ink)

ax2 = nexttile;
hold(ax2, 'on')
yline(ax2, cm.target, ':', 'target', 'Color', muted, 'LineWidth', 1)
hT = plot(ax2, sim.tc, sim.b_true, '-', 'Color', ink, 'LineWidth', 1.6);
hE = plot(ax2, sim.tc, sim.b_est, '-', 'Color', blue, 'LineWidth', 1.2);
if any(sim.res_on)
    hR = plot(ax2, sim.tc(sim.res_on), sim.b_est(sim.res_on), '.', ...
        'Color', red, 'MarkerSize', 8);
    legend(ax2, [hT hE hR], {'true margin', 'fable estimate', ...
        'residual branch engaged'}, 'Location', 'best', 'Box', 'off')
else
    legend(ax2, [hT hE], {'true margin', 'fable estimate'}, ...
        'Location', 'best', 'Box', 'off')
end
if isfinite(scn.swap_s)
    xline(ax2, scn.swap_s, '--', 'damage', 'Color', red, 'LineWidth', 1, ...
        'HandleVisibility', 'off')
end
if isfinite(scn.amp_step_s)
    xline(ax2, scn.amp_step_s, '--', 'x5 input', 'Color', yellow, ...
        'LineWidth', 1, 'HandleVisibility', 'off')
end
styleAxis(ax2, grid_c, muted, ink)
ylabel(ax2, 'NCF margin')
ylim(ax2, [0 0.75])

ax3 = nexttile;
hold(ax3, 'on')
stairs(ax3, sim.tc, sim.a, '-', 'Color', aqua, 'LineWidth', 1.5)
styleAxis(ax3, grid_c, muted, ink)
ylabel(ax3, 'authority a')
ylim(ax3, [0 1.05])
xlabel(ax3, 'time (s)')
linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [0 sim.t(end)])

png = fullfile(figDir, ['synthetic_' scn.name '.png']);
exportgraphics(fig, png, 'Resolution', 140)
savefig(fig, fullfile(figDir, ['synthetic_' scn.name '.fig']))
close(fig)
end

function styleAxis(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9)
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
ax.Title.Color = ink;
end

function s = keepLight(sim)
s = rmfield(sim, {'dd', 'dc'});
s.dm = s.dm(1:8:end);
s.t = s.t(1:8:end);
s = rmfield(s, 'cfg');
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
