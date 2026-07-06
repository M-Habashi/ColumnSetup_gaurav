function out = rths_echo_diagnosis(which_records, opt_in)
%RTHS_ECHO_DIAGNOSIS Diagnose + fix the OSI collapse when the numerical loop closes.
%
%   out = rths_echo_diagnosis            % all records
%   out = rths_echo_diagnosis([1 3])     % subset
%
% ROOT CAUSE (established on important/20260625_1740_RTHS_02.mat):
%   The 3-DOF FEM numerical substructure has a DIRECT FEEDTHROUGH from the
%   measured interface force to the interface displacement:
%       dd_fem = C*x + interface_from_force * fm        (D-term, zero lag)
%   and dd is logged/tapped AFTER the fem3_ncf3 phase lead (HF gain 8).
%   So the command the OSI sees contains
%       echo = G_lead( interface_from_force * fm ),  |echo path| ~ 0.3-2.3
%   an INSTANTANEOUS, COHERENT copy of the measured response (fm ~ dm plus
%   load-cell noise) at ALL frequencies. Wherever the exogenous (EQ-driven)
%   content of dd is small - everything above the ~18.5 Hz top FEM mode -
%   the dd<->dm cross-spectrum measures the INVERSE OUTER FEEDBACK PATH
%   (M -> 1/c ~ -3..-4.4, chordal margin ~0.10), not the inner-loop T.
%   Those bins pass the coherence gate (g2 up to 1.0: the echo IS coherent)
%   and the input-power gate (the echo has more power than the genuine
%   2-10 Hz EQ bins, so no power threshold separates them). This is classic
%   closed-loop identification bias; no estimator gate parameter can remove
%   it because the information genuinely is not in (dd, dm) at those bins.
%
% THE FIX (one gain + one sum block in Simulink, estimator untouched):
%   Give the OSI's command tap the FEM's strictly-proper output only:
%       u_osi = dd - G_lead( interface_from_force * fm )
%   i.e. subtract iff*fm right at the FEM output (before the phase lead),
%   or equivalently tap C*x. The actuator command keeps the full dd - only
%   the OSI tap changes. Offline this script reconstructs the echo from the
%   recorded fm with the saved fem3_ncf3 lead plus a single fitted scale
%   (the rig applies an extra filter/scaling on fm that the record does not
%   resolve; on-target wiring needs no fit because the subtraction is
%   structural).
%
% For each record this produces baseline vs fixed replays of the UNCHANGED
% fable_osi + fable_auth (target 0.55, the operational default), an echo
% detector verdict (doubles as the open/closed-loop classifier), metrics,
% figures under figures/, and results/rths_echo_diagnosis.mat.

here = fileparts(mfilename('fullpath'));
proj = fileparts(fileparts(fileparts(here)));   % .../main
addpath(fullfile(proj, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(proj, 'helpers')))

figDir = fullfile(here, 'figures');
resDir = fullfile(here, 'results');
if ~exist(figDir, 'dir'), mkdir(figDir), end
if ~exist(resDir, 'dir'), mkdir(resDir), end

opt = struct('target', 0.55, 'hp_hz', 25, 'corr_detect', 0.45, ...
    'corr_apply', 0.70, 'lag_max', 2, 'save_png', true);
if nargin >= 2
    fn = fieldnames(opt_in);
    for i = 1:numel(fn), opt.(fn{i}) = opt_in.(fn{i}); end
end

recs = recordList(proj);
if nargin < 1 || isempty(which_records)
    which_records = 1:numel(recs);
end

% prior loop model - same file every fable runner uses
E = load(fullfile(proj, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
dt0 = 1/2048;
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt0, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H = E.H_dc_dm;
if get(H, 'Ts') == 0, H = c2d(H, dt0, 'zoh'); end
L0 = C*H;

% the phase lead the RTHS runs used (RTHS_02: delay_comp_name fem3_ncf3)
PL = load(fullfile(proj, 'saved_results', 'phase_lead', 'fem3_ncf3.mat'));
G_lead = PL.phase_lead_tf;

out = struct('name', {}, 'det', {}, 'base', {}, 'fixed', {}, ...
    'metrics', {}, 'meta', {});
for k = which_records(:)'
    rec = recs(k);
    fprintf('\n===== [%d] %s =====\n', k, rec.name);
    L = load(rec.file);
    if isfield(L, 'result'), data = L.result; else, data = L; end
    clear L
    dd = data.dd(:); dm = data.dm(:); dt = data.dt;
    if isfield(data, 't'), t = data.t(:); else, t = (1:numel(dd))'*dt; end
    fm = []; if isfield(data, 'fm'), fm = data.fm(:); end
    iff = NaN;
    if isfield(data, 'hs') && isstruct(data.hs) ...
            && isfield(data.hs, 'interface_from_force')
        iff = data.hs.interface_from_force;
    end

    % ---- echo detection + reconstruction --------------------------------
    det = detectEcho(dd, dm, fm, t, dt, iff, G_lead, opt);
    verdict = 'no zero-lag echo (open loop)';
    if det.apply
        verdict = 'CLOSED numerical loop, echo dominant';
    elseif det.detected
        verdict = 'CLOSED loop, echo present but exogenous-dominated';
    end
    fprintf('  echo detector: %s\n    (corr %.3f @ lag %+d, scale %.3f, engaged %.0f-%.0f s)\n', ...
        verdict, det.corr, det.lag, det.scale, det.t_on, det.t_off);

    % ---- replays ---------------------------------------------------------
    fprintf('  baseline replay ...\n');
    base = replayFable(dd, dm, dt, L0, opt.target);
    if det.apply
        fprintf('  fixed replay (echo-subtracted OSI tap) ...\n');
        fixed = replayFable(det.dd_clean, dm, dt, L0, opt.target);
    else
        fixed = base;
    end

    % metrics over the ENGAGED span (skip the estimator warm-up after
    % engagement and the disengagement edge: the rig enables the OSI with
    % the test, replaying the whole record from t=0 puts the engagement
    % step inside an already-warm analysis window)
    if isfinite(det.t_on)
        win = [det.t_on + 8, det.t_off - 2];
    else
        win = [-Inf Inf];
    end
    mb = metricsOf(base, opt.target, win);
    mf = metricsOf(fixed, opt.target, win);
    printMetrics(mb, mf, det);
    if opt.save_png
        makeFigure(figDir, rec.name, t, dm, base, fixed, det, opt.target);
    end

    % keep storage light: drop bulky prediction matrices before saving
    out(end+1) = struct('name', rec.name, 'det', slimDet(det), ...
        'base', slim(base), 'fixed', slim(fixed), ...
        'metrics', struct('base', mb, 'fixed', mf, 'win', win), ...
        'meta', struct('dur', t(end), 'dt', dt, ...
            't_dec', t(1:32:end), 'dm_dec', dm(1:32:end))); %#ok<AGROW>
    clear data dd dm fm t
end

save(fullfile(resDir, 'rths_echo_diagnosis.mat'), 'out', 'opt', '-v7.3');
fprintf('\nsaved %s\n', fullfile(resDir, 'rths_echo_diagnosis.mat'));
end

% ==========================================================================
function recs = recordList(proj)
imp = fullfile(proj, 'saved_results', 'tests', 'important');
tst = fullfile(proj, 'saved_results', 'tests', 'tsting_osi');
names = { ...
    fullfile(imp, '20260625_1740_RTHS_02.mat')
    fullfile(tst, 'RTHS_5k.mat')
    fullfile(tst, '20260704_1129_testing_OSI.mat')
    fullfile(tst, 'RHTS_no_inst_butindicators_jump.mat')
    fullfile(tst, 'RTHS_instability_at_the_end.mat')
    fullfile(tst, 'RTHS_instability_during_eq.mat')
    fullfile(tst, 'RTHS_osi_rising_emergency.mat')
    fullfile(tst, 'osi_highband.mat')
    fullfile(tst, 'osi_lowband.mat')
    fullfile(imp, '20260630_1930_testing_OSI.mat')};
recs = struct('file', {}, 'name', {});
for i = 1:numel(names)
    [~, nm] = fileparts(names{i});
    recs(end+1) = struct('file', names{i}, 'name', nm); %#ok<AGROW>
end
end

% ==========================================================================
function det = detectEcho(dd, dm, fm, t, dt, iff, G_lead, opt)
% Reconstruct echo = G_lead(iff*fm) [mm], fit a single scale on the
% >hp_hz band of the ENGAGED span, decide, and build the cleaned tap.
fs = 1/dt;
det = struct('detected', false, 'apply', false, 'corr', NaN, ...
    'scale', NaN, 'corr_dm', NaN, 'supp_db', NaN, 't_on', NaN, ...
    't_off', NaN, 'lag', NaN, 'dd_clean', dd, 'echo', [], 'gate', []);
if isempty(fm) || ~isfinite(iff)
    return
end

% engagement mask: the numerical loop only writes dd while the test runs
w = round(1.0*fs);
mrms = sqrt(movmean(dd.^2, w));
thr = 0.05*prctile(mrms(mrms > 0), 95);
gate = mrms > max(thr, 1e-6);
% erode edges by half a window so ramp-in/out does not skew the fit
gate = movmin(gate, w);
if nnz(gate) < 10*fs
    return
end
det.t_on = t(find(gate, 1, 'first'));
det.t_off = t(find(gate, 1, 'last'));

Gd = c2d(G_lead, dt, 'tustin');
[nb, na] = tfdata(Gd, 'v');
echo = filter(nb, na, 1000*iff*fm);           % mm

[bh, ah] = butter(4, opt.hp_hz/(fs/2), 'high');
ddh = filtfilt(bh, ah, dd);
ech = filtfilt(bh, ah, echo);
dmh = filtfilt(bh, ah, dm);
g = gate;
s = ech(g)\ddh(g);
cc = corrcoef(ech(g), ddh(g));
det.corr = cc(1, 2);
det.scale = s;
cc2 = corrcoef(dmh(g), ddh(g));
det.corr_dm = cc2(1, 2);
% lag discrimination: the FEM D-term echo is INSTANTANEOUS (peak within a
% couple of samples); forward-path correlation (exogenous dd driving
% dm -> fm through the actuator loop) peaks at the ~15-25 ms loop delay
% and must NOT trigger the subtraction.
[cx, lg] = xcorr(ddh(g), ech(g), 60, 'coeff');
[~, im] = max(abs(cx));
det.lag = lg(im);
det.detected = det.corr > opt.corr_detect ...
    && abs(det.lag) <= opt.lag_max && s > 0.2 && s < 3;
% only SUBTRACT when the echo dominates the HF content (corr^2 = echo
% power fraction): with strong broadband exogenous excitation the bias is
% already diluted and a weak single-scale fit would inject junk. The
% Simulink structural subtraction has no such limit - it is exact.
det.apply = det.detected && det.corr >= opt.corr_apply;
if det.apply
    det.echo = s*echo.*gate;
    det.dd_clean = dd - det.echo;
    resid = ddh(g) - s*ech(g);
    det.supp_db = 20*log10(rms(ddh(g))/rms(resid));
end
det.gate = gate;
end

% ==========================================================================
function fab = replayFable(dd, dm, dt, L0, target)
% batch OSI replay + sequential authority-law replay (same wiring as
% run_fable_osi_tests/fableReplay; target = operational default 0.55)
ovr = struct('threshold', target, 'cal_skip_s', 12);
run = fable_osi('run', dd, dm, dt, L0, ovr);

prm = fable_auth('params', struct('target', target, 'a_init', 1.0, ...
    'a_min', 0.08, 'dt_update', run.cfg.step_s));
ast = fable_auth('state', prm);
nU = numel(run.tc);
a = NaN(nU, 1);
dec = zeros(nU, 1);
for k = 1:nU
    st_binding = run.st_valid(k) && ...
        (isnan(run.b_res(k)) || run.b_st(k) <= run.b_res(k));
    [ak, ast, dk] = fable_auth(run.b(k), run.st_valid(k), ...
        run.trip_reason(k), run.b_fast(k), run.pred_margin(:, k), ...
        run.pred_valid(k), run.alpha_grid, ast, prm, st_binding, ...
        run.regime_recal(k));
    a(k) = ak;
    dec(k) = dk;
end
fab = struct('tc', run.tc, 'b', run.b, 'valid', run.valid, ...
    'b_st', run.b_st, 'b_res', run.b_res, 'b_fast', run.b_fast, ...
    'f_st', run.f_st, 'f_res', run.f_res, 'z_max', run.z_max, ...
    'st_valid', run.st_valid, 'res_on', run.res_on, ...
    'fast_trip', run.fast_trip, 'trip_reason', run.trip_reason, ...
    'n_excited', run.n_excited, 'a', a, 'decision', dec, ...
    'cap', run.cfg.cap);
end

% ==========================================================================
function printMetrics(mb, mf, det)
fprintf(['  baseline: b med %.3f  min %.3f  below-tg %4.1f%%  ' ...
    'a min %.2f  full-a %4.1f%%  trips %d\n'], mb.b_med, mb.b_min, ...
    mb.below, mb.a_min, mb.full_a, mb.trips);
if det.apply
    fprintf(['  fixed   : b med %.3f  min %.3f  below-tg %4.1f%%  ' ...
        'a min %.2f  full-a %4.1f%%  trips %d\n'], mf.b_med, mf.b_min, ...
        mf.below, mf.a_min, mf.full_a, mf.trips);
end
end

function mm = metricsOf(f, target, win)
inw = f.tc >= win(1) & f.tc <= win(2);
v = f.valid & isfinite(f.b) & inw;
mm = struct('b_med', median(f.b(v)), 'b_min', min([f.b(v); NaN]), ...
    'below', 100*mean(f.b(v) < target), 'a_min', min([f.a(inw); NaN]), ...
    'full_a', 100*mean(f.a(inw) >= 0.95), 'trips', nnz(f.fast_trip(inw)));
end

% ==========================================================================
function makeFigure(figDir, name, t, dm, base, fixed, det, target)
ink = [11 11 11]/255; muted = [120 118 112]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; red = [204 74 59]/255; aqua = [27 175 122]/255;

fig = figure('Color', 'w', 'Position', [40 40 1150 760], 'Visible', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(ax1, t(1:8:end), dm(1:8:end), '-', 'Color', [blue 0.8], ...
    'LineWidth', 0.4)
ylabel(ax1, 'dm (mm)')
ttl = sprintf('%s - fable replay, target %.2f', name, target);
if det.apply
    ttl = sprintf(['%s | echo: corr %.2f scale %.2f supp %.1f dB ' ...
        '(CLOSED loop)'], ttl, det.corr, det.scale, det.supp_db);
elseif det.detected
    ttl = sprintf('%s | closed loop, echo minor (corr %.2f)', ...
        ttl, det.corr);
else
    ttl = [ttl ' | no echo detected (open loop)'];
end
title(ax1, ttl, 'Interpreter', 'none', 'Color', ink, 'FontSize', 10)
styleAx(ax1, grid_c, muted, ink)

ax2 = nexttile;
hold(ax2, 'on')
yline(ax2, target, ':', 'Color', muted, 'LineWidth', 1)
plot(ax2, base.tc, base.b, '-', 'Color', [red 0.9], 'LineWidth', 1.1)
if det.apply
    plot(ax2, fixed.tc, fixed.b, '-', 'Color', ink, 'LineWidth', 1.3)
    legend(ax2, {'target', 'OSI margin - dd as wired today', ...
        'OSI margin - echo-subtracted tap'}, 'Location', 'southwest', ...
        'Box', 'off', 'FontSize', 8)
else
    legend(ax2, {'target', 'OSI margin'}, 'Location', 'southwest', ...
        'Box', 'off', 'FontSize', 8)
end
ylabel(ax2, 'NCF margin')
ylim(ax2, [0 0.75])
styleAx(ax2, grid_c, muted, ink)

ax3 = nexttile;
hold(ax3, 'on')
stairs(ax3, base.tc, base.a, '-', 'Color', [red 0.9], 'LineWidth', 1.2)
if det.apply
    stairs(ax3, fixed.tc, fixed.a, '-', 'Color', aqua, 'LineWidth', 1.4)
    legend(ax3, {'authority - baseline', 'authority - fixed tap'}, ...
        'Location', 'southwest', 'Box', 'off', 'FontSize', 8)
end
ylabel(ax3, 'authority a')
xlabel(ax3, 'time (s)')
ylim(ax3, [0 1.05])
styleAx(ax3, grid_c, muted, ink)

linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [t(1) t(end)])
png = fullfile(figDir, ['echo_fix_' name '.png']);
exportgraphics(fig, png, 'Resolution', 130)
close(fig)
fprintf('  figure: %s\n', png);
end

function styleAx(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9, 'Layer', 'top')
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
end

% ==========================================================================
function s = slim(f)
s = rmfield(f, intersect(fieldnames(f), {'decision'}));
end

function d = slimDet(det)
d = rmfield(det, intersect(fieldnames(det), ...
    {'dd_clean', 'echo', 'gate'}));
end

function y = ternary(c, a, b)
if c, y = a; else, y = b; end
end
