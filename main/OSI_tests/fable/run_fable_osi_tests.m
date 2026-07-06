function results = run_fable_osi_tests(which_records)
%RUN_FABLE_OSI_TESTS Replay fable OSI + authority on the 3 saved records.
%
%   results = run_fable_osi_tests            % all three records
%   results = run_fable_osi_tests([1 3])     % subset
%
% For each record this computes, from dd/dm only (ignoring any OSI values
% stored in the record):
%   * the fable margin + authority replay (fable_osi / fable_auth),
%   * the CURRENT implementation replay (m91_adaptive_margin +
%     auth_stability_gain, exactly as run_current_osi_auth_factor_cases),
%   * an offline reference margin (20 s windows, 2 s Welch segments,
%     coherence-gated chordal margin of the dd->dm map) as the best
%     after-the-fact estimate where the input allows one,
% then saves per-record figures, a metrics table and a results .mat under
% OSI_tests/fable/.
%
% Replay caveat (applies to every offline runner in this folder): the
% authority computed here did NOT act on the plant, so it shows what the
% law would have commanded given the observed margins. Closed-loop
% behavior is validated separately in run_fable_synthetic_checks.

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

figDir = fullfile(here, 'figures');
resDir = fullfile(here, 'results');
if ~exist(figDir, 'dir'), mkdir(figDir), end
if ~exist(resDir, 'dir'), mkdir(resDir), end

records = recordMeta(projectFolder);
if nargin < 1 || isempty(which_records)
    which_records = 1:numel(records);
end

target = 0.50;

% prior loop model (same file the current implementation uses)
E = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
dt0 = 1/2048;
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt0, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H = E.H_dc_dm;
if get(H, 'Ts') == 0, H = c2d(H, dt0, 'zoh'); end
L0 = C*H;

results = struct('name', {}, 'fable', {}, 'current', {}, 'ref', {}, ...
    'metrics', {}, 'meta', {});
for k = which_records(:)'
    rec = records(k);
    fprintf('\n===== %s =====\n', rec.name);
    cacheFile = fullfile(resDir, ['replay_' rec.name '.mat']);
    S = struct();
    if isfile(cacheFile)
        fprintf('  using cached replay %s\n', cacheFile);
        S = load(cacheFile);
    end
    % the fable replay depends on the target; current/reference do not
    fable_ok = isfield(S, 'fable') && isfield(S, 'target') ...
        && abs(S.target - target) < 1e-12;
    if ~isfield(S, 'current') || ~fable_ok
        data = loadRecord(rec.file);
        if ~isfield(S, 'current')
            S.data_t = data.t(:);
            S.data_dm = data.dm(:);
            S.asrun_t = [];
            S.asrun_a = [];
            if isfield(data, 'osi_gain')   % rec 1930 ran with OSI live
                S.asrun_t = data.t(1:64:end);
                S.asrun_a = data.osi_gain(1:64:end);
            end

            fprintf('  current-implementation replay ...\n'); tic
            S.current = currentReplay(projectFolder, data);
            fprintf('    %.1f s\n', toc);

            fprintf('  offline reference margin ...\n'); tic
            S.ref = referenceMargin(data);
            fprintf('    %.1f s\n', toc);
        end

        fprintf('  fable replay (target %.2f) ...\n', target); tic
        S.fable = fableReplay(data, L0, target);
        fprintf('    %.1f s\n', toc);
        S.target = target;
        save(cacheFile, '-struct', 'S', '-v7.3');
    end

    M = computeMetrics(S, rec, target);
    printMetrics(rec.name, M);
    plotRecord(rec, S, target, figDir);

    results(end+1) = struct('name', rec.name, 'fable', S.fable, ...
        'current', S.current, 'ref', S.ref, 'metrics', M, ...
        'meta', rec); %#ok<AGROW>
end

if numel(which_records) == numel(records)
    metrics = [results.metrics]; %#ok<NASGU>
    save(fullfile(resDir, 'fable_osi_tests_metrics.mat'), 'metrics');
end
end

% ==========================================================================
function records = recordMeta(projectFolder)
base = fullfile(projectFolder, 'saved_results', 'tests', 'important');
records = struct( ...
    'name', {'20260617_1731', '20260617_1749', '20260630_1930'}, ...
    'file', { ...
        fullfile(base, ['20260617_1731_sp1_ori_Pvar_I30_D0001_' ...
            'Po_015_Io_20_Do_00015.mat']), ...
        fullfile(base, ['20260617_1749_sp1_ori_Pvar_I30_D0001_' ...
            'Po_015_Io_20_Do_00015.mat']), ...
        fullfile(base, '20260630_1930_testing_OSI.mat')}, ...
    'event_s', {[695 775], [248 290], [400 414]}, ...
    'healthy_s', {[625 690], [40 210], [80 395]}, ...
    'note', { ...
        'command off until ~620 s, then broadband; P-gain excursion event', ...
        'low-band command (~2-7 Hz coherent); oscillation at end of record', ...
        'el-centro EQ phases; live OSI runtime was active (osi_gain logged)'});
end

function data = loadRecord(filePath)
assert(isfile(filePath), 'Saved result not found: %s', filePath)
loaded = load(filePath);
if isfield(loaded, 'result') && isstruct(loaded.result)
    data = loaded.result;
else
    data = loaded;
end
for f = {'t', 'dd', 'dm', 'dt', 'fs'}
    assert(isfield(data, f{1}), 'missing field %s', f{1})
end
end

% ==========================================================================
function fab = fableReplay(data, L0, target)
ovr = struct('threshold', target, 'cal_skip_s', 12);
run = fable_osi('run', data.dd, data.dm, data.dt, L0, ovr);

prm = fable_auth('params', struct('target', target, 'a_init', 1.0, ...
    'a_min', 0.08, 'dt_update', run.cfg.step_s));
ast = fable_auth('state', prm);
gprm = fable_evidence_gate('params', struct('dt_step', run.cfg.step_s));
gst = fable_evidence_gate('state', gprm);
nU = numel(run.tc);
a = NaN(nU, 1);
dec = zeros(nU, 1);
armed = false(nU, 1);
for k = 1:nU
    idx = (k-1)*run.cfg.step_n + (1:run.cfg.step_n);
    [b, valid_up, armed(k), gst] = fable_evidence_gate(data.dd(idx), ...
        run.b(k), run.st_valid(k), gprm, gst);
    st_binding = run.st_valid(k) && ...
        (isnan(run.b_res(k)) || run.b_st(k) <= run.b_res(k));
    [ak, ast, dk] = fable_auth(b, valid_up, run.trip_reason(k), ...
        run.b_fast(k), run.pred_margin(:, k), ...
        run.pred_valid(k) && armed(k), run.alpha_grid, ast, prm, ...
        st_binding, run.regime_recal(k));
    a(k) = ak;
    dec(k) = dk;
    run.b(k) = b;
    run.valid(k) = valid_up;
end
fab = struct('tc', run.tc, 'b', run.b, 'valid', run.valid, ...
    'b_st', run.b_st, 'b_res', run.b_res, 'b_fast', run.b_fast, ...
    'f_st', run.f_st, ...
    'f_res', run.f_res, 'z_max', run.z_max, 'st_valid', run.st_valid, ...
    'res_on', run.res_on, 'fast_trip', run.fast_trip, ...
    'trip_reason', run.trip_reason, ...
    'n_excited', run.n_excited, 'a', a, 'decision', dec, ...
    'g_armed', armed, 'cap', run.cfg.cap, 'a_init', prm.a_init);
% keep the pred matrix out of the saved struct (large, reproducible)
end

% ==========================================================================
function cur = currentReplay(projectFolder, data)
% Faithful copy of localReplayCurrentImplementation in
% OSI_tests/run_current_osi_auth_factor_cases.m (same settings).
dd = data.dd(:);
dm = data.dm(:);
dt = data.dt;

hs = struct( ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', 'exp_tf', ...
        'tf_sp1_5000_20260627_233333.mat'), ...
    'osi_gain_initial', 0.3, ...
    'osi_gain_min', 0.08, ...
    'target_outer_ncf', 0.3, ...
    'osi_branch_split_hz', [], ...
    'osi_st_branch_hz', [2 30], ...
    'osi_residual_branch_hz', [40 80]);

setup = prepare_osi_gain_runtime(projectFolder, dt, hs); %#ok<NASGU>
% prepare_osi_gain_runtime assigns osigs & friends into this workspace
cfg = setup.m91_cfg;
state = m91_adaptive_margin('state', cfg);

nWindow = floor((min(numel(dd), numel(dm)) - cfg.window_n) ...
    /cfg.update_interval_n) + 1;
tc = NaN(nWindow, 1);
ncfSelected = NaN(nWindow, 1);
ncfSt = NaN(nWindow, 1);
ncfResidual = NaN(nWindow, 1);
authFactor = NaN(nWindow, 1);

auth = osigs(1);
marginFiltered = osigs(2);
marginGuarded = osigs(2);
aboveCount = 0;
belowCount = 0;

for k = 1:nWindow
    idx = (k - 1)*cfg.update_interval_n + (1:cfg.window_n);
    tc(k) = data.t(idx(end));
    [margin, state, info] = m91_adaptive_margin(dd(idx), dm(idx), ...
        cfg, state);
    ncfSt(k) = info.ncf_st;
    ncfResidual(k) = info.ncf_residual;
    ncfSelected(k) = margin;
    [auth, marginFiltered, marginGuarded, aboveCount, belowCount] = ...
        auth_stability_gain(margin, auth, marginFiltered, ...
        marginGuarded, aboveCount, belowCount, osigs(2), ...
        cfg.update_interval_actual_s, osigs(3), osigs(4), ...
        osigs(5), osigs(6), osigs(7), osigs(8), osigs(9), ...
        osigs(10), osigs(11), osigs(12), osigs(13), osigs(14), ...
        osigs(15), osigs(16));
    authFactor(k) = auth;
end

cur = struct('tc', tc, 'b', ncfSelected, 'b_st', ncfSt, ...
    'b_res', ncfResidual, 'a', authFactor, 'a_init', osigs(1));
end

% ==========================================================================
function ref = referenceMargin(data)
% After-the-fact margin of the dd->dm map: long windows, fine Welch
% resolution, hard coherence gate. Only defined where the input allows it.
fs = data.fs;
dd = data.dd(:);
dm = data.dm(:);
win_n = round(20*fs);
hop_n = round(5*fs);
seg_n = round(2*fs);
n = min(numel(dd), numel(dm));
nW = floor((n - win_n)/hop_n) + 1;
tc = NaN(nW, 1);
b = NaN(nW, 1);
w = hann(seg_n);
for k = 1:nW
    idx = (k-1)*hop_n + (1:win_n);
    u = dd(idx);
    y = dm(idx);
    if rms(u) < 1e-9
        tc(k) = data.t(idx(end));
        continue
    end
    [Suu, f] = cpsd(u, u, w, seg_n/2, seg_n, fs);
    Syy = cpsd(y, y, w, seg_n/2, seg_n, fs);
    Suy = cpsd(u, y, w, seg_n/2, seg_n, fs);
    g2 = abs(Suy).^2./max(Suu.*Syy, eps);
    M = Suy./max(Suu, eps);
    keep = f >= 2 & f <= 100 & ~(f >= 58 & f <= 62) & g2 > 0.5 ...
        & Suu > 10^(-35/10)*max(Suu(f >= 2 & f <= 100));
    if nnz(keep) >= 8
        chord = 1./(sqrt(2)*sqrt(abs(1 - M(keep)).^2 + abs(M(keep)).^2));
        b(k) = min(1/sqrt(2), min(movmedian(chord, 3)));
    end
    tc(k) = data.t(idx(end));
end
ref = struct('tc', tc, 'b', b);
end

% ==========================================================================
function M = computeMetrics(S, rec, target)
M = struct('name', rec.name);
for src = {'fable', 'current'}
    s = S.(src{1});
    hw = s.tc >= rec.healthy_s(1) & s.tc <= rec.healthy_s(2);
    ew = s.tc >= rec.event_s(1) & s.tc <= rec.event_s(2);
    post = s.tc > rec.event_s(2);

    bh = s.b(hw);
    bh = bh(~isnan(bh));
    m.healthy_margin_med = median(bh);
    m.healthy_margin_iqr = iqrLocal(bh);
    m.healthy_false_low = mean(bh < target);
    m.healthy_fast_trips = 0;
    if isfield(s, 'fast_trip')
        m.healthy_fast_trips = nnz(s.fast_trip(hw));
    end
    m.healthy_a_hi = mean(s.a(hw) >= 0.95*s.a_init);
    m.min_a = min(s.a);
    m.event_min_margin = min(s.b(ew), [], 'omitnan');
    idet = find(ew & s.b < target, 1);
    m.detect_s = NaN;
    if ~isempty(idet), m.detect_s = s.tc(idet) - rec.event_s(1); end
    % recovery: authority back to 90% of its pre-event value
    a_pre = median(s.a(hw), 'omitnan');
    irec = find(post & s.a >= 0.9*a_pre, 1);
    m.recover_s = NaN;
    if ~isempty(irec), m.recover_s = s.tc(irec) - rec.event_s(2); end
    % agreement with the offline reference: same evaluation times for both
    % estimators - healthy period, reference defined, and coherent input
    % available (fable ST branch valid there)
    bi = interp1(s.tc, s.b, S.ref.tc);
    stv = interp1(S.fable.tc, double(S.fable.st_valid), S.ref.tc) > 0.5;
    both = ~isnan(bi) & ~isnan(S.ref.b) & stv ...
        & S.ref.tc >= rec.healthy_s(1) & S.ref.tc <= rec.healthy_s(2);
    m.ref_mae = NaN;
    if nnz(both) >= 3
        m.ref_mae = median(abs(bi(both) - S.ref.b(both)));
    end
    M.(src{1}) = m;
end
end

function printMetrics(name, M)
fprintf('  %-30s %10s %10s\n', name, 'fable', 'current');
rows = {
    'healthy margin (median)', 'healthy_margin_med'
    'healthy margin IQR', 'healthy_margin_iqr'
    'healthy false-low rate', 'healthy_false_low'
    'healthy fast trips (n)', 'healthy_fast_trips'
    'healthy time at full auth', 'healthy_a_hi'
    'min authority', 'min_a'
    'event min margin', 'event_min_margin'
    'event detect latency (s)', 'detect_s'
    'auth recovery after event (s)', 'recover_s'
    'median |err| vs reference', 'ref_mae'};
for i = 1:size(rows, 1)
    fprintf('  %-30s %10.3f %10.3f\n', rows{i, 1}, ...
        M.fable.(rows{i, 2}), M.current.(rows{i, 2}));
end
end

function v = iqrLocal(x)
x = sort(x(~isnan(x)));
if isempty(x), v = NaN; return, end
q = @(p) interp1((0.5:numel(x))/numel(x), x, p, 'linear', 'extrap');
v = q(0.75) - q(0.25);
end

% ==========================================================================
function plotRecord(rec, S, target, figDir)
ink = [11 11 11]/255; muted = [137 135 129]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; aqua = [27 175 122]/255; violet = [74 58 167]/255;
red = [227 73 72]/255; yellow = [237 161 0]/255;
event_wash = [227 73 72]/255;

fig = figure('Color', 'w', 'Position', [60 60 1180 880], 'Visible', 'off');
tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- dm ---
ax1 = nexttile;
hold(ax1, 'on')
plot(ax1, S.data_t(1:4:end), S.data_dm(1:4:end), '-', 'Color', blue, ...
    'LineWidth', 0.4)
styleAxis(ax1, grid_c, muted, ink)
ylabel(ax1, 'dm (mm)')
title(ax1, sprintf('%s - %s', rec.name, rec.note), 'Color', ink, ...
    'Interpreter', 'none')

% --- margins ---
ax2 = nexttile;
hold(ax2, 'on')
yline(ax2, target, ':', 'target', 'Color', muted, 'LineWidth', 1, ...
    'HandleVisibility', 'off')
hCur = plot(ax2, S.current.tc, S.current.b, '-', ...
    'Color', [red 0.45], 'LineWidth', 0.6);
hFab = plot(ax2, S.fable.tc, S.fable.b, '-', 'Color', blue, ...
    'LineWidth', 1.4);
hRef = plot(ax2, S.ref.tc, S.ref.b, '.', 'Color', ink, 'MarkerSize', 9);
resv = S.fable.res_on & S.fable.b_res < S.fable.cap - 1e-9;
hRes = plot(ax2, S.fable.tc(resv), S.fable.b_res(resv), '.', ...
    'Color', violet, 'MarkerSize', 7);
styleAxis(ax2, grid_c, muted, ink)
ylabel(ax2, 'NCF margin')
ylim(ax2, [0 0.75])
hs = [hFab hCur hRef];
lbl = {'fable margin', 'current impl. margin', 'offline reference'};
if any(resv)
    hs(end+1) = hRes;
    lbl{end+1} = 'fable residual branch';
end
legend(ax2, hs, lbl, 'Location', 'southwest', 'Box', 'off', 'FontSize', 8)

% --- authority ---
ax3 = nexttile;
hold(ax3, 'on')
hCa = stairs(ax3, S.current.tc, S.current.a, '-', 'Color', red, ...
    'LineWidth', 1.0);
hFa = stairs(ax3, S.fable.tc, S.fable.a, '-', 'Color', aqua, ...
    'LineWidth', 1.5);
hs = [hFa hCa];
lbl = {'fable authority (a_0=1)', 'current authority (a_0=0.3)'};
if isfield(S, 'asrun_t') && ~isempty(S.asrun_t)
    hAr = plot(ax3, S.asrun_t, S.asrun_a, '--', 'Color', muted, ...
        'LineWidth', 1.0);
    hs(end+1) = hAr;
    lbl{end+1} = 'as-run osi\_gain (live test)';
end
styleAxis(ax3, grid_c, muted, ink)
ylabel(ax3, 'authority a')
ylim(ax3, [0 1.05])
legend(ax3, hs, lbl, 'Location', 'best', 'Box', 'off', 'FontSize', 8)

% --- diagnostics ---
ax4 = nexttile;
hold(ax4, 'on')
plot(ax4, S.fable.tc, S.fable.z_max, '-', 'Color', violet, ...
    'LineWidth', 0.8)
yline(ax4, 3.5, ':', 'z_{on}', 'Color', muted, 'HandleVisibility', 'off')
tr = S.fable.fast_trip;
if any(tr)
    plot(ax4, S.fable.tc(tr), 0*S.fable.tc(tr) + 12, 'v', ...
        'Color', yellow, 'MarkerFaceColor', yellow, 'MarkerSize', 5)
end
styleAxis(ax4, grid_c, muted, ink)
ylabel(ax4, 'residual z_{max}')
xlabel(ax4, 'time (s)')
ylim(ax4, [-4 14])

linkaxes([ax1 ax2 ax3 ax4], 'x')
xlim(ax1, [0 S.data_t(end)])
for ax = [ax1 ax2 ax3 ax4]
    washEvent(ax, rec.event_s, event_wash)
end

png = fullfile(figDir, [rec.name '_fable_vs_current.png']);
exportgraphics(fig, png, 'Resolution', 140)
savefig(fig, fullfile(figDir, [rec.name '_fable_vs_current.fig']))
close(fig)
fprintf('  figure: %s\n', png);
end

function washEvent(ax, ev, c)
% shaded event window drawn AFTER the data: freeze limits, patch, send back
yl = ylim(ax);
ylim(ax, yl)
p = patch(ax, ev([1 2 2 1]), yl([1 1 2 2]), c, 'FaceAlpha', 0.07, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
uistack(p, 'bottom')
end

function styleAxis(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9, 'Layer', 'top')
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
ax.Title.Color = ink;
end
