%% RUN_GPT2_STUDY GPT-5.6.2 validation: suite, fabby score, GDB, live record.
% Everything writes beside this script under research/gpt5_6_2/fable.
% All record-based validation reads osi_calibration_test.mat (the corrected
% export of the 20260710_1845 run; only dc differs - logged pre-diagnostic-
% gain there - and the OSI consumes u_osi/dm, which are bit-identical).

clear
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(fileparts(here)));
cd(here)
warning('off', 'MATLAB:rmpath:DirNotFound')
try, rmpath(fullfile(project, 'research', 'gpt5_6')); end %#ok<TRYNC>
addpath(here)
addpath(fullfile(project, 'OSI_tests', 'fable'))
addpath(fullfile(project, 'research', 'fable_2'))
addpath(genpath(fullfile(project, 'control_and_HS', 'OSI')))
addpath(genpath(fullfile(project, 'helpers')))
clear functions %#ok<CLFUNC>

%% canonical ten-case suite (v2) + fabby score; FABLE + old-GPT baselines are
% reused from the saved gpt5_6 study (same harness, same rng seed)
fprintf('Running the ten canonical cases with GPT-5.6.2...\n')
gpt_suite = gpt_synthetic_suite('gpt', 0.55);
fabby = fabby_score(gpt_suite, project);
Sold = load(fullfile(project, 'research', 'gpt5_6', 'results', 'gpt_osi_study.mat'));
fable_suite = Sold.result.fable_suite;
old_suite = Sold.result.gpt_suite;
old_fabby = Sold.result.fabby_score;

%% GDBqFpKb replay (closed authority: the v2 law drives its own a_cmd)
fprintf('Replaying GDBqFpKb...\n')
Sg = load(fullfile(project, 'saved_results', 'tests', 'tsting_osi', 'GDBqFpKb.mat'));
rg = Sg.result;
Eg = load(fullfile(project, 'saved_results', 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'));
pvg = Eg.pid_values;
Cg = pid(pvg.P, pvg.I, pvg.D, 1/pvg.derivative_filter_N, rg.dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L0g = Cg*c2d(Eg.H_dc_dm, rg.dt, 'zoh');
cfgG = gpt_osi('config', rg.dt, L0g, struct());
prmG = gpt_auth('params', struct('dt_update', cfgG.step_s));
ostG = gpt_osi('state', cfgG);
astG = gpt_auth('state', prmG);
tapg = rg.u_osi(:); dmg = rg.dm(:); tgv = rg.t(:); gaing = rg.Results(:, 21);
nG = floor(min([numel(tgv), numel(tapg), numel(dmg)])/cfgG.step_n);
gdb = struct('t', NaN(nG,1), 'b', NaN(nG,1), 'a', NaN(nG,1), ...
    'rho', NaN(nG,1), 'trip', zeros(nG,1), 'tap_rms', NaN(nG,1));
aG = prmG.a_init;
for k = 1:nG
    ii = (k-1)*cfgG.step_n+(1:cfgG.step_n);
    ostG.a_cmd = aG;
    [gdb.b(k), ostG, oiG] = gpt_osi(tapg(ii), dmg(ii), cfgG, ostG);
    [aG, astG] = gpt_auth(gdb.b(k), oiG.full_margin, oiG.residual_weight, astG, prmG);
    gdb.t(k) = tgv(ii(end)); gdb.a(k) = aG; gdb.rho(k) = oiG.rho;
    gdb.trip(k) = oiG.trip; gdb.tap_rms(k) = rms(ostG.u);
end
idxg = (1:nG)'*cfgG.step_n;
gdb.gain = gaing(idxg);
gdb.logged_fable_b = rg.b_osi(idxg);
gdb.logged_fable_a = rg.auth(idxg);
gdb.target = prmG.target;
gdb.guard = prmG.guard;
gdb.metrics = gdbMetrics(gdb);

%% live record (osi_calibration_test): open replay (logged authority) old vs new
fprintf('Replaying the osi_calibration_test record (old vs new readings)...\n')
Sr = load(fullfile(project, 'saved_results', 'tests', 'gpt5_6_tests', ...
    'osi_calibration_test.mat'));
rr = Sr.result;
L0r = Cg*c2d(Eg.H_dc_dm, rr.dt, 'zoh');
old_dir = fullfile(project, 'research', 'gpt5_6');
cur = pwd; cd(old_dir); h_osi = @gpt_osi; h_auth = @gpt_auth; cd(cur);
rec = struct();
rec.new = replayRecord(rr, L0r, @gpt_osi);
rec.old = replayRecord(rr, L0r, h_osi);
rec.edges = recordEdges(rr, rec.new, rec.old);

%% closed-loop emulation of the live scenario: old vs new law in charge
fprintf('Closed-loop emulation (new law)...\n')
emu_new = record_emulation('new', project);
fprintf('Closed-loop emulation (old law)...\n')
emu_old = record_emulation('old', project, h_osi, h_auth);

%% acceptance
acc = acceptanceMetrics(gpt_suite, gdb, prmG);
acc.fabby_score = fabby.mean_score;
acc.fabby_score_pass = acc.fabby_score > 92;
acc.emulation_new_unstable_s = sum(emu_new.gain.*emu_new.a >= 2.25)*0.125;
acc.emulation_old_unstable_s = sum(emu_old.gain.*emu_old.a >= 2.25)*0.125;
acc.emulation_pass = acc.emulation_new_unstable_s == 0;
acc.all_pass = acc.canonical_pass && acc.continuous && acc.warmup_pass && ...
    acc.detection_pass && acc.authority_pass && acc.recovery_pass && ...
    acc.reliability_pass && acc.fabby_score_pass && acc.emulation_pass;

result = struct('generated_at', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss Z')), ...
    'method', 'GPT-5.6.2', 'target_ncf', 0.55, ...
    'gpt_suite', gpt_suite, 'fable_suite', fable_suite, 'old_suite', old_suite, ...
    'fabby', fabby, 'old_fabby', old_fabby, 'gdb', gdb, ...
    'record', rec, 'emu_new', emu_new, 'emu_old', emu_old, 'acceptance', acc);

results_dir = fullfile(here, 'results');
if ~exist(results_dir, 'dir'), mkdir(results_dir), end
save(fullfile(results_dir, 'gpt2_study.mat'), 'result', '-v7.3')
writeReportData(fullfile(here, 'report_data.js'), result)
writeSummary(fullfile(results_dir, 'summary.txt'), result)

fprintf('\nSuite: %d/10 | fabby %.2f (old %.2f) | GDB quake %.2fs, edges [%.2f %.2f]s, recovery %.2fs\n', ...
    nnz([gpt_suite.cases.pass]), fabby.mean_score, old_fabby.mean_score, ...
    gdb.metrics.quake_deficit_latency_s, gdb.metrics.indicator_latency_s(1), ...
    gdb.metrics.indicator_latency_s(2), gdb.metrics.recovery_latency_s)
fprintf('Emulation unstable time: old %.2fs -> new %.2fs\n', ...
    acc.emulation_old_unstable_s, acc.emulation_new_unstable_s)

%% ------------------------------------------------------------------------
function rep = replayRecord(rr, L0, osi_fn)
cfg = osi_fn('config', rr.dt, L0, struct());
ost = osi_fn('state', cfg);
n = floor(numel(rr.t)/cfg.step_n);
rep = struct('t', NaN(n,1), 'b', NaN(n,1), 'rho', NaN(n,1), 'trip', zeros(n,1));
for k = 1:n
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    ost.a_cmd = rr.auth(ii(1));
    [rep.b(k), ost, oi] = osi_fn(rr.u_osi(ii), rr.dm(ii), cfg, ost);
    rep.t(k) = rr.t(ii(end));
    if isfield(oi, 'rho'), rep.rho(k) = oi.rho; end
    if isfield(oi, 'trip'), rep.trip(k) = oi.trip; end
end
idx = (1:n)'*cfg.step_n;
rep.gain = rr.Results(idx, 21);
rep.auth = rr.auth(idx);
rep.logged_b = rr.b_osi(idx);
end

function edges = recordEdges(rr, new, old)
tE = [34.014 37.703 44.958];
gE = {'1 -> 1.5', '1.5 -> 2', '2 -> 3'};
edges = struct('t', {}, 'label', {}, 'new_detect_s', {}, 'old_detect_s', {});
for j = 1:numel(tE)
    e = struct('t', tE(j), 'label', gE{j});
    for v = {'new', 'old'}
        if strcmp(v{1}, 'new'), rep = new; else, rep = old; end
        pre = rep.t >= tE(j)-1 & rep.t < tE(j);
        bpre = median(rep.b(pre), 'omitnan');
        hit = find(rep.t >= tE(j) & rep.b <= bpre-0.04, 1);
        lat = NaN;
        if ~isempty(hit) && rep.t(hit)-tE(j) < 8, lat = rep.t(hit)-tE(j); end
        e.([v{1} '_detect_s']) = lat;
    end
    edges(end+1) = e; %#ok<AGROW>
end
end

function m = gdbMetrics(gdb)
t = gdb.t; g = gdb.gain;
edges = find(abs(diff(g)) > 0.05)+1;
det = NaN(numel(edges), 1);
for j = 1:numel(edges)
    k = edges(j); t0 = t(k);
    if g(k) > g(k-1)
        pre = t >= t0-1 & t < t0;
        bpre = median(gdb.b(pre), 'omitnan');
        if j < numel(edges), kend = edges(j+1)-1; else, kend = numel(t); end
        w = false(size(t)); w(k:kend) = true;
        d = find(w & gdb.b <= bpre-0.04, 1);
        if ~isempty(d), det(j) = t(d)-t0; end
    end
end
onset = find(t >= 45 & gdb.tap_rms > 0.05, 1);
qhit = find(t >= t(onset) & gdb.b < gdb.target, 1);
rc = find(t >= 75.5 & gdb.b >= gdb.target+gdb.guard, 1);
rh = [];
if ~isempty(rc), rh = find(t >= t(rc) & gdb.a >= 0.95, 1); end
idle = t < 44;
m = struct('edge_time_s', t(edges), 'gain_after', g(edges), ...
    'indicator_latency_s', det(isfinite(g(edges))), ...
    'indicator_pass', isfinite(det) & det <= 2, ...
    'no_idle_shed_pass', all(abs(gdb.a(idle)-1) <= 1e-12), ...
    'quake_deficit_latency_s', latency(t, onset, qhit), ...
    'quake_deficit_pass', isfinite(latency(t, onset, qhit)) && latency(t, onset, qhit) <= 2, ...
    'recovery_margin_cross_s', timeAt(t, rc), ...
    'recovery_latency_s', latency(t, rc, rh), ...
    'recovery_tail_min_a', tailMin(gdb.a, rh), ...
    'recovery_pass', isfinite(latency(t, rc, rh)) && latency(t, rc, rh) <= 3 && ...
        tailMin(gdb.a, rh) >= 0.95, ...
    'trips', nnz(gdb.trip));
m.indicator_latency_s = det;
end

function out = acceptanceMetrics(suite, gdb, prm)
warm = [suite.cases.timing]; warm = [warm.warmup_s];
ids = [3 4 7]; timing = [suite.cases(ids).timing];
detect = [timing.detection_s]; authority = [timing.authority_s];
idsr = [7 8]; timingr = [suite.cases(idsr).timing]; recover = [timingr.recovery_s];
finite_all = all(arrayfun(@(c) all(isfinite(c.sim.b_est)), suite.cases));
max_step = zeros(1, numel(suite.cases));
tail_step = zeros(1, numel(suite.cases));
for i = 1:numel(suite.cases)
    a = suite.cases(i).sim.a(:); tcv = suite.cases(i).sim.tc(:);
    max_step(i) = max(abs(diff(a)));
    tail = tcv >= tcv(end)-30;
    tail_step(i) = max(abs(diff(a(tail))));
end
out = struct('canonical_pass', suite.all_pass, ...
    'canonical_pass_count', nnz([suite.cases.pass]), ...
    'continuous', finite_all && all(isfinite(gdb.b)), ...
    'worst_warmup_s', max(warm), 'warmup_pass', all(warm <= 2), ...
    'worst_detection_s', max(detect), 'detection_pass', all(isfinite(detect) & detect <= 2), ...
    'worst_authority_s', max(authority), 'authority_pass', all(isfinite(authority) & authority <= 2), ...
    'worst_recovery_s', max(recover), 'recovery_pass', all(isfinite(recover) & recover <= 2), ...
    'max_update_step', max(max_step), 'max_tail_step', max(tail_step), ...
    'reliability_pass', max(max_step) <= prm.max_step+1e-12 && max(tail_step) <= 0.05, ...
    'gdb_no_idle_shed_pass', gdb.metrics.no_idle_shed_pass, ...
    'gdb_quake_pass', gdb.metrics.quake_deficit_pass, ...
    'gdb_edge_pass', gdb.metrics.indicator_pass, ...
    'gdb_recovery_pass', gdb.metrics.recovery_pass, ...
    'gdb_recovery_latency_s', gdb.metrics.recovery_latency_s, ...
    'all_pass', false);
end

function x = latency(t, i0, i1)
if isempty(i0) || isempty(i1), x = NaN; else, x = t(i1)-t(i0); end
end

function x = timeAt(t, idx)
if isempty(idx), x = NaN; else, x = t(idx); end
end

function x = tailMin(a, idx)
if isempty(idx), x = NaN; else, x = min(a(idx:end)); end
end

function writeReportData(file, result)
dec = @(v, n) round(v(1:n:end), 5);
D = struct('generated_at', result.generated_at, 'target', result.target_ncf, ...
    'fabby', struct('mean', result.fabby.mean_score, ...
        'cases', [result.fabby.cases.score], ...
        'old_mean', result.old_fabby.mean_score, ...
        'old_cases', [result.old_fabby.cases.score]), ...
    'acceptance', result.acceptance, 'gdb_metrics', result.gdb.metrics, ...
    'record_edges', result.record.edges);
for i = 1:numel(result.gpt_suite.cases)
    c = result.gpt_suite.cases(i); o = result.old_suite.cases(i); f = result.fable_suite.cases(i);
    D.cases(i).name = c.name;
    D.cases(i).pass = c.pass; D.cases(i).old_pass = o.pass; D.cases(i).fable_pass = f.pass;
    D.cases(i).detail = c.detail;
    D.cases(i).t = dec(c.sim.tc, 4);
    D.cases(i).b_true = dec(c.sim.b_true, 4);
    D.cases(i).b = dec(c.sim.b_est, 4);
    D.cases(i).a = dec(c.sim.a, 4);
    D.cases(i).old_a = dec(o.sim.a, 4);
    D.cases(i).fable_a = dec(f.sim.a, 4);
    D.cases(i).b_star = dec(result.fabby.cases(i).b_star, 4);
end
D.gdb = struct('t', dec(result.gdb.t, 2), 'gain', dec(result.gdb.gain, 2), ...
    'b', dec(result.gdb.b, 2), 'a', dec(result.gdb.a, 2), ...
    'rho', dec(result.gdb.rho, 2), ...
    'fable_b', dec(result.gdb.logged_fable_b, 2), ...
    'fable_a', dec(result.gdb.logged_fable_a, 2));
rn = result.record.new; ro = result.record.old;
D.record = struct('t', dec(rn.t, 2), 'gain', dec(rn.gain, 2), ...
    'auth', dec(rn.auth, 2), 'logged_b', dec(rn.logged_b, 2), ...
    'new_b', dec(rn.b, 2), 'new_rho', dec(rn.rho, 2), ...
    'old_b', dec(ro.b, 2), ...
    'new_trips', rn.t(rn.trip ~= 0), 'trip_sign', rn.trip(rn.trip ~= 0));
en = result.emu_new; eo = result.emu_old;
D.emu = struct('t', dec(en.t, 2), 'gain', dec(en.gain, 2), ...
    'new_a', dec(en.a, 2), 'new_b_true', dec(en.b_true, 2), ...
    'new_b', dec(en.b, 2), 'new_rho', dec(en.rho, 2), 'new_dc', dec(en.dc_rms, 2), ...
    'old_a', dec(eo.a, 2), 'old_b_true', dec(eo.b_true, 2), ...
    'old_b', dec(eo.b, 2), 'old_dc', dec(eo.dc_rms, 2), 'target', en.target);
fid = fopen(file, 'w');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, ['window.GPT2_DATA=' jsonencode(D, 'ConvertInfAndNaN', true) ';'], 'char');
end

function writeSummary(file, result)
fid = fopen(file, 'w'); cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'GPT-5.6.2 STUDY\nGenerated: %s\n\n', result.generated_at);
for i = 1:numel(result.gpt_suite.cases)
    c = result.gpt_suite.cases(i);
    fprintf(fid, '%-28s %s\n%s\n\n', c.name, pass(c.pass), c.detail);
end
a = result.acceptance;
fprintf(fid, 'Suite: %d/10 %s | fabby %.2f (>92 %s; old %.2f)\n', ...
    a.canonical_pass_count, pass(a.canonical_pass), a.fabby_score, ...
    pass(a.fabby_score_pass), result.old_fabby.mean_score);
m = result.gdb.metrics;
fprintf(fid, 'GDB: idle %s | quake %.2fs %s | edges [%s]s | recovery %.2fs tail %.3f %s | trips %d\n', ...
    pass(m.no_idle_shed_pass), m.quake_deficit_latency_s, pass(m.quake_deficit_pass), ...
    num2str(m.indicator_latency_s(:)', '%.2f '), m.recovery_latency_s, ...
    m.recovery_tail_min_a, pass(m.recovery_pass), m.trips);
for j = 1:numel(result.record.edges)
    e = result.record.edges(j);
    fprintf(fid, 'Record edge %s @%.2fs: new %.2fs, old %.2fs\n', ...
        e.label, e.t, e.new_detect_s, e.old_detect_s);
end
fprintf(fid, 'Emulation unstable time: old %.2fs -> new %.2fs | dc max old %.2f -> new %.2f\n', ...
    a.emulation_old_unstable_s, a.emulation_new_unstable_s, ...
    max(result.emu_old.dc_rms), max(result.emu_new.dc_rms));
end

function s = pass(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
