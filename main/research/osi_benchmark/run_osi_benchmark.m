function result = run_osi_benchmark(osi_fn, auth_fn, label, target_override)
%RUN_OSI_BENCHMARK Run the Fabby Benchmark for an OSI + authority law.
%
%   result = run_osi_benchmark(@my_osi, @my_auth, 'my_label')
%
% ONE call runs every test a candidate method must face, prints a scorecard,
% and saves results/<label>_benchmark.mat.  Read README.md in this folder
% before designing a method - it states the interface contract and the
% factual basis of every criterion.  The three non-negotiable rules:
%
%   1. CLOSED LOOP.  The live-scenario test runs the candidate's own
%      authority through the plant (this harness does it).  Open-loop
%      replays hide feedback failure modes: two candidates in this
%      project's history looked safe open-loop and were unstable closed
%      (see README).  The candidate must honor state.a_cmd - the harness
%      writes the applied authority there before every step.
%   2. ONE PARAMETER SET.  The method runs its DEFAULTS everywhere; the
%      only per-test values are target and a_min, and they come from each
%      record's own hs configuration (facts of the test), never from the
%      candidate.  Per-record tuning profiles void a validation.
%   3. THE CORRECTED RECORD ONLY.  The live scenario is
%      saved_results/tests/gpt5_6_tests/osi_calibration_test.mat.  Other
%      exports of that run log dc AFTER the diagnostic gain (old dc = g x
%      correct dc, verified): a method reading them "detects" the gain by
%      reading the test knob.  A method may consume ONLY u_osi and dm
%      (plus the a_cmd feedback) unless it documents and justifies more.
%
% Interface contract (the gpt_osi / gpt_auth convention):
%   cfg   = osi_fn('config', dt, initial_loop_tf, struct())
%   ost   = osi_fn('state', cfg)            % must expose ost.a_cmd
%   [b, ost, info] = osi_fn(dd_blk, dm_blk, cfg, ost)
%       info must provide: full_margin, residual_weight, ready
%   prm   = auth_fn('params', struct('target',T,'a_min',A,'dt_update',cfg.step_s))
%   ast   = auth_fn('state', prm)
%   [a, ast] = auth_fn(b, info.full_margin, info.residual_weight, ast, prm)
%
% HARD GATES (all must pass; each is a measurable fact):
%   G1 canonical suite 10/10   (OSI_tests/fable/fable_synthetic_suite)
%   G2 fabby_score_1 > 90      (research/fable_2/fabby_score ground truth)
%   G3 closed-loop live scenario: 0 s with g*a >= g_crit, where g_crit is
%      COMPUTED from the identified model (first g destabilizing
%      feedback(g*C*H5k)) - not a chosen number
%   G4 end-hold: after the excitation ends the diagnostic gain is still 3,
%      so any a > g_crit/3 is inside the unstable region; max a for
%      t >= 66 s must stay below g_crit/3
%   G5 GDB idle: no authority shed before the quake (t < 44 s)
%   G6 GDB quake deficit flagged within 2 s of activity onset
%   G7 continuity/reliability: no NaN outputs; |da| never exceeds the
%      method's own declared max_step
%
% SCORES (0-100 each, formulas printed in the scorecard and README):
%   fabby_score_1       - established suite tracking metric: estimation
%                         quality on the 10 synthetic cases against model
%                         ground truth (unsafe-side error x3, scale 0.10)
%   fabby_score_2       - the SAME error metric applied to the closed-loop
%                         live scenario (osi_calibration_test.mat):
%                         regulation quality of the true margin against the
%                         ideal setpoint b* = max(target, b_true at a=1).
%                         Per-sample saturated (each update loses at most
%                         its share of the 0.10 scale) so it stays
%                         informative even when a stability gate fails
%   S3 detection        - fraction of the five diagnostic-gain rises
%                         (three live, two GDB) reflected in the reading
%                         within 2 s (pre-depressed readings count: the
%                         criterion is b <= b_healthy - 0.04)
%   S4 smoothness       - 100*(1 - travel/travel_live) on 45-63 s, where
%                         travel_live is the measured authority travel of
%                         the failed 2026-07-10 run (the factual baseline)
%   S5 gdb_recovery     - linear from 3 s (=100, the canonical
%                         requirement) to 20 s (=0, the post-restore
%                         window the record offers) after the gain restore
%   composite           - mean of the five, reported ONLY if all gates pass
%
% REPORTED FACTS (not scores, not folded into the composite):
%   roughness           - indicator jitter, 1000*median|b(k)-2b(k-1)+b(k-2)|
%                         pooled over every update of every test. The second
%                         difference ignores a legitimate ramp and the median
%                         ignores the handful of genuine fast edges, so what
%                         is left is the update-to-update fuzz on the trace.
%                         Lower is better; it is deliberately NOT scored,
%                         because a method may buy a clean trace with output
%                         filtering that S3 detection would have to pay for

assert(nargin >= 3 && ischar(label) || isstring(label), ...
    'Usage: run_osi_benchmark(@osi_fn, @auth_fn, ''label'')')
label = char(label);
if nargin < 4
    target_override = [];
end
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(fullfile(project, 'OSI_tests', 'fable'))
addpath(fullfile(project, 'research', 'fable_2'))

%% ---- shared models --------------------------------------------------------
E5 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;

%% ---- G1/G2/S1: canonical suite + fabby ------------------------------------
fprintf('[1/3] Canonical ten-case suite...\n')
method = struct('name', ['bench_' label], 'block_n', 256, ...
    'init', @(dt, L0, target, cm) initMethod(osi_fn, auth_fn, dt, L0, target), ...
    'step', @stepMethod);
suite = fable_synthetic_suite('method', method, 'plot', false);
side = fullfile(project, 'OSI_tests', 'fable', 'results', ...
    ['suite_bench_' label '.mat']);
if isfile(side), delete(side), end   % harness side effect, not a result
fab = fabby_score(suite, project);

%% ---- G3/G4/S2/S3/S4: closed-loop live scenario ----------------------------
fprintf('[2/3] Closed-loop live scenario (osi_calibration_test)...\n')
emu = closedLoopScenario(project, pv, osi_fn, auth_fn, target_override);

%% ---- G5/G6/S3/S5: GDBqFpKb replay -----------------------------------------
fprintf('[3/3] GDBqFpKb replay...\n')
gdb = gdbReplay(project, pv, osi_fn, auth_fn, target_override);

%% ---- gates ----------------------------------------------------------------
gates = struct( ...
    'G1_suite_10_of_10', nnz([suite.cases.pass]) == 10, ...
    'G2_fabby_1_gt_90', fab.mean_score > 90, ...
    'G3_zero_unstable_time', emu.unstable_time_s == 0, ...
    'G4_end_hold', emu.tail_max_a < emu.g_crit/3, ...
    'G5_gdb_no_idle_shed', gdb.no_idle_shed, ...
    'G6_gdb_quake_2s', isfinite(gdb.quake_latency_s) && gdb.quake_latency_s <= 2, ...
    'G7_continuous', emu.continuous && gdb.continuous && ...
        all(arrayfun(@(c) all(isfinite(c.sim.b_est)) && all(isfinite(c.sim.a)), suite.cases)));
gate_names = fieldnames(gates);
all_gates = all(struct2array(gates));

%% ---- scores ---------------------------------------------------------------
det_lat = [emu.edge_latency_s(:); gdb.edge_latency_s(:)];
scores = struct( ...
    'fabby_score_1', fab.mean_score, ...
    'fabby_score_2', emu.tracking_score, ...
    'S3_detection', 100*mean(isfinite(det_lat) & det_lat <= 2), ...
    'S4_smoothness', 100*min(max(1 - emu.travel/emu.travel_live, 0), 1), ...
    'S5_gdb_recovery', 100*min(max((20 - gdb.recovery_latency_s)/(20 - 3), 0), 1));
if ~isfinite(scores.S5_gdb_recovery), scores.S5_gdb_recovery = 0; end
composite = mean(struct2array(scores));

%% ---- reported facts --------------------------------------------------------
traces = cell(numel(suite.cases)+2, 1);
for i = 1:numel(suite.cases), traces{i} = suite.cases(i).sim.b_est(:); end
traces{end-1} = emu.b(:);
traces{end} = gdb.b(:);
roughness = indicatorJitter(traces);

%% ---- scorecard ------------------------------------------------------------
fprintf('\n=============== FABBY BENCHMARK: %s ===============\n', label)
for i = 1:numel(gate_names)
    fprintf('  %-24s %s\n', gate_names{i}, passText(gates.(gate_names{i})))
end
fprintf('  ------------------------------------------\n')
fprintf('  fabby_score_1      %6.1f   (suite estimation, >90 required)\n', scores.fabby_score_1)
fprintf('  fabby_score_2      %6.1f   (closed-loop regulation on osi_calibration_test)\n', scores.fabby_score_2)
fprintf('  S3 detection       %6.1f   (%d/%d gain rises within 2 s)\n', ...
    scores.S3_detection, nnz(isfinite(det_lat) & det_lat <= 2), numel(det_lat))
fprintf('  S4 smoothness      %6.1f   (travel %.2f vs live %.2f)\n', ...
    scores.S4_smoothness, emu.travel, emu.travel_live)
fprintf('  S5 gdb recovery    %6.1f   (latency %.1f s)\n', ...
    scores.S5_gdb_recovery, gdb.recovery_latency_s)
fprintf('  ------------------------------------------\n')
if all_gates
    fprintf('  COMPOSITE          %6.1f   (all gates PASS)\n', composite)
else
    fprintf('  COMPOSITE          --      (GATED OUT: fix the FAILed gates first;\n')
    fprintf('                              would have been %.1f)\n', composite)
end
fprintf('  facts: g_crit %.3f | emu unstable %.2f s | tail max a %.3f (limit %.3f)\n', ...
    emu.g_crit, emu.unstable_time_s, emu.tail_max_a, emu.g_crit/3)
fprintf('  roughness %.2f (indicator jitter x1000, lower is smoother)\n', roughness)
fprintf('  emu edges [%s] s | gdb edges [%s] s | b_true min %.3f\n', ...
    num2str(emu.edge_latency_s(:)', '%.2f '), ...
    num2str(gdb.edge_latency_s(:)', '%.2f '), emu.b_true_min)
fprintf('====================================================\n')

result = struct('label', label, 'generated_at', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'gates', gates, 'all_gates_pass', all_gates, 'scores', scores, ...
    'composite', composite, 'roughness', roughness, ...
    'suite', suite, 'fabby', fab, ...
    'emulation', emu, 'gdb', gdb);
resdir = fullfile(here, 'results');
if ~exist(resdir, 'dir'), mkdir(resdir), end
save(fullfile(resdir, [label '_benchmark.mat']), 'result', '-v7.3')
end

%% ===== canonical-suite adapter =============================================
function ctx = initMethod(osi_fn, auth_fn, dt, L0, target)
cfg = osi_fn('config', dt, L0, struct());
prm = auth_fn('params', struct('target', target, 'dt_update', cfg.step_s));
ctx = struct('osi_fn', osi_fn, 'auth_fn', auth_fn, 'cfg', cfg, ...
    'ost', osi_fn('state', cfg), 'prm', prm, ...
    'ast', auth_fn('state', prm), 'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = stepMethod(ctx, dd, dm)
ctx.ost.a_cmd = ctx.a_last;
[b, ctx.ost, oi] = ctx.osi_fn(dd, dm, ctx.cfg, ctx.ost);
a0 = ctx.a_last;
[a, ctx.ast] = ctx.auth_fn(b, oi.full_margin, oi.residual_weight, ...
    ctx.ast, ctx.prm);
ctx.a_last = a;
trip = 0;
extra = struct('b_st', getf(oi, 'b_st', b), 'b_res', getf(oi, 'b_res', b), ...
    'b_fast', NaN, 'decision', sign(a-a0), 'ready', getf(oi, 'ready', true), ...
    'a_target', a, 'confidence', getf(oi, 'confidence', NaN));
end

function v = getf(s, f, dflt)
if isfield(s, f), v = s.(f); else, v = dflt; end
end

%% ===== closed-loop live scenario ===========================================
function emu = closedLoopScenario(project, pv, osi_fn, auth_fn, target_override)
S = load(fullfile(project, 'saved_results', 'tests', 'gpt5_6_tests', ...
    'osi_calibration_test.mat'));
rec = S.result;
dt = rec.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H5 = ss(c2d(load_H(project), dt, 'zoh'));
L0 = C*H5;

% instability boundary: COMPUTED from the identified model, not assumed
g_crit = stabilityBoundary(L0);

% test facts come from the record, not from the candidate
target = rec.hs.target_outer_ncf;
if ~isempty(target_override), target = target_override; end
a_min = rec.hs.osi_gain_min;
t = rec.t(:);
ref = rec.u_osi(:);
gain = rec.Results(:, 21);
N = numel(t);
rng(3, 'twister')
noise = 0.06*randn(N, 1);               % measured idle dm level of the rig
dc_sat = 10;                            % actuator command limit [mm]

cfg = osi_fn('config', dt, L0, struct());
prm = auth_fn('params', struct('target', target, 'a_min', a_min, ...
    'dt_update', cfg.step_s));
ost = osi_fn('state', cfg);
ast = auth_fn('state', prm);

f = (1:100)';
L5f = squeeze(freqresp(L0, 2*pi*f));
[Ac, Bc, Cc, Dc] = ssdata(ss(C));
[Ap, Bp, Cp] = ssdata(H5);
xc = zeros(size(Ac, 1), 1);
xp = zeros(size(Ap, 1), 1);
blk = cfg.step_n;
nU = floor(N/blk);
tc = NaN(nU,1); bE = NaN(nU,1); bT = NaN(nU,1); aU = NaN(nU,1); dcr = NaN(nU,1);
a = prm.a_init; ib = 0; ku = 0;
refB = zeros(blk,1); dmB = zeros(blk,1); dcW = zeros(blk,1);
for k = 1:N
    y = Cp*xp;
    dmk = y + noise(k);
    e = ref(k) - dmk;
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = min(max(gain(k)*a*u, -dc_sat), dc_sat);
    xp = Ap*xp + Bp*dck;
    ib = ib + 1;
    refB(ib) = ref(k); dmB(ib) = dmk; dcW(ib) = dck;
    if ib == blk
        ib = 0; ku = ku + 1;
        ost.a_cmd = a;                              % closed loop, rule 1
        [b, ost, oi] = osi_fn(refB, dmB, cfg, ost);
        [a, ast] = auth_fn(b, oi.full_margin, oi.residual_weight, ast, prm);
        tc(ku) = t(k); bE(ku) = b; aU(ku) = a;
        La = gain(k)*a*L5f;
        bT(ku) = min(abs(1+La)./sqrt(2*(1+abs(La).^2)));
        dcr(ku) = rms(dcW);
    end
end
gU = gain((1:nU)'*blk);

% ideal margin per fabby's definition: never detune a loop that is healthy
% at full authority, regulate a damaged one exactly onto the target
b_full = arrayfun(@(g) min(abs(1+g*L5f)./sqrt(2*(1+abs(g*L5f).^2))), gU);
b_star = max(target, b_full);
mask = tc > 4 & isfinite(bT);
err = bT - b_star;
w = ones(size(err)); w(err < 0) = 3;
% Per-sample saturation: each update can lose at most its own share of the
% 0.10 error scale, so a bounded catastrophic stretch costs its duration
% instead of zeroing the whole score. The stretch itself is judged by
% G3/G4; this score stays informative even when a hard gate fails.
tracking = 100*(1 - mean(min(w(mask).*abs(err(mask))/0.10, 1)));

% detection: in a CLOSED loop good regulation keeps b at the target, so an
% edge counts as detected if the reading falls 0.04 below its healthy level
% OR the authority responds (a <= 0.98*a_pre, the canonical suite's own
% detection rule) within 2 s
edges = [34.014 37.703 44.958];
healthy = median(bE(tc >= 33 & tc < 34), 'omitnan');
lat = edgeLatencies(tc, bE, aU, edges, healthy);

live_auth = rec.auth((1:nU)'*blk);
win = tc >= 45 & tc <= 63;
emu = struct('t', tc, 'b', bE, 'b_true', bT, 'a', aU, 'gain', gU, ...
    'dc_rms', dcr, 'target', target, 'a_min', a_min, 'g_crit', g_crit, ...
    'unstable_time_s', sum(gU.*aU >= g_crit)*(tc(2)-tc(1)), ...
    'tail_max_a', max(aU(tc >= 66)), ...
    'b_true_min', min(bT(mask)), ...
    'tracking_score', tracking, ...
    'edge_time_s', edges(:), 'edge_latency_s', lat, ...
    'healthy_read', healthy, ...
    'travel', sum(abs(diff(aU(win)))), ...
    'travel_live', sum(abs(diff(live_auth(win)))), ...
    'continuous', all(isfinite(bE)) && all(isfinite(aU)));
end

function H = load_H(project)
E = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
H = E.H_dc_dm;
end

function g_crit = stabilityBoundary(L0)
lo = 1; hi = 8;
assert(isstable(feedback(lo*L0, 1)) && ~isstable(feedback(hi*L0, 1)), ...
    'Unexpected stability at the bisection brackets.')
for it = 1:24
    mid = (lo+hi)/2;
    if isstable(feedback(mid*L0, 1)), lo = mid; else, hi = mid; end
end
g_crit = (lo+hi)/2;
end

%% ===== GDBqFpKb replay ======================================================
function gdb = gdbReplay(project, pv, osi_fn, auth_fn, target_override)
S = load(fullfile(project, 'saved_results', 'tests', 'tsting_osi', ...
    'GDBqFpKb.mat'));
r = S.result;
dt = r.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L0 = C*c2d(load_H(project), dt, 'zoh');
cfg = osi_fn('config', dt, L0, struct());
auth_override = struct('dt_update', cfg.step_s);
if ~isempty(target_override), auth_override.target = target_override; end
prm = auth_fn('params', auth_override);
ost = osi_fn('state', cfg);
ast = auth_fn('state', prm);
tap = r.u_osi(:); dm = r.dm(:); t = r.t(:); gain = r.Results(:, 21);
n = floor(min([numel(t), numel(tap), numel(dm)])/cfg.step_n);
tc = NaN(n,1); b = NaN(n,1); aa = NaN(n,1); tapr = NaN(n,1);
a = prm.a_init;
for k = 1:n
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    ost.a_cmd = a;                                  % closed authority
    [b(k), ost, oi] = osi_fn(tap(ii), dm(ii), cfg, ost);
    [a, ast] = auth_fn(b(k), oi.full_margin, oi.residual_weight, ast, prm);
    tc(k) = t(ii(end)); aa(k) = a; tapr(k) = rms(ost.u);
end
g = gain((1:n)'*cfg.step_n);

idle = tc < 44;
onset = find(tc >= 45 & tapr > 0.05, 1);
qhit = find(tc >= tc(onset) & b < prm.target, 1);

% detection on the two gain rises, same rule as the emulation (reading drop
% OR authority response)
edges_t = [];
ke = find(diff(g) > 0.05)+1;
for j = 1:numel(ke), edges_t(end+1) = tc(ke(j)); end %#ok<AGROW>
healthy = median(b(tc >= 46.5 & tc < 50), 'omitnan');
lat = edgeLatencies(tc, b, aa, edges_t, healthy);

restore = tc(find(diff(g) < -0.05, 1)+1);
rhit = find(tc >= restore & aa >= 0.95, 1);
rec_lat = NaN;
if ~isempty(rhit) && min(aa(rhit:end)) >= 0.95
    rec_lat = tc(rhit)-restore;
end

gdb = struct('t', tc, 'b', b, 'a', aa, 'gain', g, ...
    'no_idle_shed', all(abs(aa(idle)-prm.a_init) <= 1e-12), ...
    'quake_latency_s', tc(qhit)-tc(onset), ...
    'edge_time_s', edges_t(:), 'edge_latency_s', lat, ...
    'healthy_read', healthy, 'restore_time_s', restore, ...
    'recovery_latency_s', rec_lat, ...
    'continuous', all(isfinite(b)) && all(isfinite(aa)));
end

function lat = edgeLatencies(tc, b, a, edges_t, healthy)
% an edge is detected when the reading falls 0.04 below the method's own
% healthy-driven level OR the applied authority drops to 0.98*a_pre (the
% canonical suite's authority-response rule), within 2 s of the edge
lat = NaN(numel(edges_t), 1);
for j = 1:numel(edges_t)
    kpre = find(tc < edges_t(j), 1, 'last');
    if isempty(kpre), continue, end
    a_pre = a(kpre);
    hit = find(tc >= edges_t(j) & tc <= edges_t(j)+2 & ...
        (b <= healthy-0.04 | a <= 0.98*a_pre), 1);
    if ~isempty(hit), lat(j) = max(tc(hit)-edges_t(j), 0); end
end
end

function s = passText(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end

function j = indicatorJitter(traces)
% Update-to-update fuzz on the reported margin, pooled over every test.
%
% The second difference is what makes this a noise metric rather than a
% responsiveness penalty: a genuine ramp has a near-zero second difference,
% and a genuine step contributes only at its own edge. The median then
% discards those few edges, so a method is not charged for reacting.
d = [];
for i = 1:numel(traces)
    b = traces{i};
    b = b(isfinite(b));
    if numel(b) < 3, continue, end
    d = [d; abs(diff(b, 2))]; %#ok<AGROW>
end
if isempty(d), j = NaN; else, j = 1000*median(d); end
end
