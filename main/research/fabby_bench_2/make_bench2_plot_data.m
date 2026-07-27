function make_bench2_plot_data()
%MAKE_BENCH2_PLOT_DATA Traces for the docs/Sol_osi/index.html results section.
%
%   Builds one JSON payload holding, for every Fabby Bench 2 test and each of
%   the two estimators (implemented and simplified):
%   the measured displacement dm, the reported OSI b, the applied authority
%   factor, plus the true NCF and the diagnostic gain where the test has
%   them.  Writes docs/Sol_osi/bench2_data.js.
%
%   The ten synthetic cases and the scorecards are read from the saved
%   Fabby Bench 2 results so the page cannot disagree with the benchmark.
%   The two experimental scenarios are re-run here only because the
%   benchmark does not retain dm; both are deterministic, and this function
%   asserts that the re-run reproduces the saved b trace exactly.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin');
addpath(fullfile(project, 'OSI_tests', 'fable'));
rehash;

methods = struct( ...
    'key',   {'sol_osi_v1', 'sol_osi'}, ...
    'label', {'v1', 'current'}, ...
    'fn',    {@sol_osi_v1, @sol_osi}, ...
    'color', {'#007ca8', '#ac6420'});
nm = numel(methods);

experimental_target = 0.30;
saved = cell(nm, 1);
for i = 1:nm
    f = fullfile(project, 'research', 'osi_benchmark', 'results', ...
        ['fabby_bench_2_' methods(i).key '_benchmark.mat']);
    assert(isfile(f), 'Missing %s - run compare_fabby_bench_2 first.', f);
    S = load(f);
    saved{i} = S.result;
end

E5 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;

tests = {};

%% ---- the ten synthetic cases ----------------------------------------------
scn = suiteScenarios();
ncase = numel(saved{1}.suite.cases);
for c = 1:ncase
    name = saved{1}.suite.cases(c).name;
    fprintf('synthetic  %-26s\n', name);
    T = struct('key', name, 'label', prettify(name), 'group', 'synthetic', ...
        'target', saved{1}.suite.target, 'marks', {plantMarks(scn(c))}, ...
        'note', '');
    tc = [];
    for i = 1:nm
        sim = saved{i}.suite.cases(c).sim;
        [T.dm_t, T.dm.(methods(i).key)] = thin(sim.t, sim.dm, 900);
        if isempty(tc), tc = sim.tc(:); end
        assert(isequal(size(tc), size(sim.tc(:))), 'tc mismatch on %s', name)
        T.osi.(methods(i).key) = round(sim.b_est(:), 4);
        T.ncf.(methods(i).key) = round(sim.b_true(:), 4);
        T.auth.(methods(i).key) = round(sim.a(:), 4);
    end
    T.tc = round(tc, 4);
    T.has_ncf = true;
    T.has_gain = false;
    tests{end+1} = T; %#ok<AGROW>
end

%% ---- live closed-loop scenario ---------------------------------------------
fprintf('experimental live closed-loop scenario\n');
T = struct('key', 'live_closed_loop', ...
    'label', 'Live closed loop (osi_calibration_test)', ...
    'group', 'experimental', 'target', experimental_target, 'marks', {{}}, ...
    'note', ['Closed-loop simulation on the corrected record: the plant is ' ...
             'the identified 5k model throughout, so there is no 7k/5k ' ...
             'transition to mark. dm is simulated per method.']);
tc = [];
for i = 1:nm
    e = liveScenario(project, pv, methods(i).fn, @gpt5_6_4_auth, ...
        experimental_target);
    assert(max(abs(e.b - saved{i}.emulation.b)) < 1e-12, ...
        'live re-run differs from the saved benchmark for %s', methods(i).key)
    [T.dm_t, T.dm.(methods(i).key)] = thin(e.t_sig, e.dm, 900);
    if isempty(tc), tc = e.tc(:); end
    T.osi.(methods(i).key) = round(e.b(:), 4);
    T.ncf.(methods(i).key) = round(e.b_true(:), 4);
    T.auth.(methods(i).key) = round(e.a(:), 4);
    gain = e.gain(:);
end
T.tc = round(tc, 4);
T.gain = round(gain, 4);
T.has_ncf = true;
T.has_gain = true;
tests{end+1} = T;

%% ---- GDBqFpKb replay -------------------------------------------------------
fprintf('experimental GDBqFpKb replay\n');
T = struct('key', 'gdb_replay', 'label', 'GDBqFpKb replay', ...
    'group', 'experimental', 'target', experimental_target, 'marks', {{}}, ...
    'note', ['Open-loop replay of the recorded rig data, so dm is the ' ...
             'measured signal and is identical for all four methods; the ' ...
             'record carries no true NCF and no 7k/5k transition.']);
tc = [];
for i = 1:nm
    g = gdbScenario(project, pv, methods(i).fn, @gpt5_6_4_auth, ...
        experimental_target);
    assert(max(abs(g.b - saved{i}.gdb.b)) < 1e-12, ...
        'gdb re-run differs from the saved benchmark for %s', methods(i).key)
    [T.dm_t, T.dm.(methods(i).key)] = thin(g.t_sig, g.dm, 900);
    if isempty(tc), tc = g.tc(:); end
    T.osi.(methods(i).key) = round(g.b(:), 4);
    T.auth.(methods(i).key) = round(g.a(:), 4);
    gain = g.gain(:);
end
T.tc = round(tc, 4);
T.gain = round(gain, 4);
T.has_ncf = false;
T.has_gain = true;
tests{end+1} = T;

%% ---- scorecard table -------------------------------------------------------
rows = {'all_gates_pass', 'All seven gates', 'gate'; ...
        'fabby_score_1',  'Synthetic score', 'score'; ...
        'fabby_score_2',  'Experimental score', 'score'; ...
        'S3_detection',   'S3 detection', 'score'; ...
        'S4_smoothness',  'S4 smoothness', 'score'; ...
        'S5_gdb_recovery','S5 GDB recovery', 'score'; ...
        'composite',      'Raw composite', 'score'; ...
        'roughness',      'Indicator jitter', 'low'; ...
        'unstable_time_s','Unstable time [s]', 'low'; ...
        'tail_max_a',     'G4 tail max a', 'low'};
table_rows = {};
for r = 1:size(rows, 1)
    row = struct('key', rows{r, 1}, 'label', rows{r, 2}, 'kind', rows{r, 3});
    vals = zeros(1, nm);
    for i = 1:nm
        R = saved{i};
        switch rows{r, 1}
            case 'all_gates_pass', vals(i) = R.all_gates_pass;
            case 'composite',      vals(i) = R.composite;
            case 'roughness',      vals(i) = R.roughness;
            case 'unstable_time_s',vals(i) = R.emulation.unstable_time_s;
            case 'tail_max_a',     vals(i) = R.emulation.tail_max_a;
            otherwise,             vals(i) = R.scores.(rows{r, 1});
        end
    end
    row.values = round(vals, 3);
    table_rows{end+1} = row; %#ok<AGROW>
end

%% ---- write -----------------------------------------------------------------
data = struct( ...
    'generated_at', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), ...
    'synthetic_target', saved{1}.suite.target, ...
    'experimental_target', experimental_target, ...
    'g_crit_over_3', round(saved{1}.emulation.g_crit/3, 4), ...
    'methods', {arrayfun(@(m) struct('key', m.key, 'label', m.label, ...
        'color', m.color), methods, 'UniformOutput', false)}, ...
    'tests', {tests}, 'table', {table_rows});

outfile = fullfile(project, 'docs', 'Sol_osi', 'bench2_data.js');
fid = fopen(outfile, 'w');
fwrite(fid, ['window.BENCH2_DATA = ' jsonencode(data) ';']);
fclose(fid);
d = dir(outfile);
fprintf('\nwrote %s (%.0f kB, %d tests)\n', outfile, d.bytes/1024, numel(tests));
end

%% ===========================================================================
function marks = plantMarks(s)
% Vertical marks where the plant blend lambda changes: lambda = 0 is the 7k
% model, lambda = 1 is the 5k model.  Duplicate breakpoints (a step) collapse
% into a single combined mark.
marks = {};
if isempty(s.lam_t), return, end
xt = s.lam_t; xv = s.lam_v;
k = 1;
while k <= numel(xt)
    j = k;
    while j < numel(xt) && xt(j+1) == xt(k), j = j + 1; end
    if j > k
        lab = [modelName(xv(k)) char(8594) modelName(xv(j))];
    else
        lab = modelName(xv(k));
    end
    marks{end+1} = struct('t', xt(k), 'label', lab); %#ok<AGROW>
    k = j + 1;
end
end

function n = modelName(lam)
if lam < 0.5, n = '7k'; else, n = '5k'; end
end

function s = prettify(name)
s = strrep(name, '_', ' ');
s(1) = upper(s(1));
end

function [tt, yy] = thin(t, y, nmax)
t = t(:); y = y(:);
stride = max(1, ceil(numel(t)/nmax));
idx = 1:stride:numel(t);
tt = round(t(idx), 4);
yy = round(y(idx), 5);
end

function scn = suiteScenarios()
% Mirrors the scenario table of OSI_tests/fable/fable_synthetic_suite.m; only
% the plant-blend breakpoints are needed here.
scn = struct( ...
    'lam_t', {[], [], [45 45], [50 50], [], [60 100], ...
              [50 50 100 100], [0 80 80], [], []}, ...
    'lam_v', {[], [], [0 1], [0 1], [], [0 1], ...
              [0 1 1 0], [1 1 0], [], []});
end

%% ===== live closed-loop scenario (mirrors run_osi_benchmark) ===============
function emu = liveScenario(project, pv, osi_fn, auth_fn, target_override)
S = load(fullfile(project, 'saved_results', 'tests', 'gpt5_6_tests', ...
    'osi_calibration_test.mat'));
rec = S.result;
dt = rec.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H5 = ss(c2d(loadH(project), dt, 'zoh'));
L0 = C*H5;
target = target_override;
a_min = rec.hs.osi_gain_min;
t = rec.t(:);
ref = rec.u_osi(:);
gain = rec.Results(:, 21);
N = numel(t);
rng(3, 'twister')
noise = 0.06*randn(N, 1);
dc_sat = 10;

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
tc = NaN(nU,1); bE = NaN(nU,1); bT = NaN(nU,1); aU = NaN(nU,1);
dmAll = zeros(N, 1);
a = prm.a_init; ib = 0; ku = 0;
refB = zeros(blk,1); dmB = zeros(blk,1);
for k = 1:N
    y = Cp*xp;
    dmk = y + noise(k);
    e = ref(k) - dmk;
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = min(max(gain(k)*a*u, -dc_sat), dc_sat);
    xp = Ap*xp + Bp*dck;
    dmAll(k) = dmk;
    ib = ib + 1;
    refB(ib) = ref(k); dmB(ib) = dmk;
    if ib == blk
        ib = 0; ku = ku + 1;
        ost.a_cmd = a;
        [b, ost, oi] = osi_fn(refB, dmB, cfg, ost);
        [a, ast] = auth_fn(b, oi.full_margin, oi.residual_weight, ast, prm);
        tc(ku) = t(k); bE(ku) = b; aU(ku) = a;
        La = gain(k)*a*L5f;
        bT(ku) = min(abs(1+La)./sqrt(2*(1+abs(La).^2)));
    end
end
emu = struct('t_sig', t, 'dm', dmAll, 'tc', tc, 'b', bE, 'b_true', bT, ...
    'a', aU, 'gain', gain((1:nU)'*blk));
end

%% ===== GDBqFpKb replay (mirrors run_osi_benchmark) =========================
function gdb = gdbScenario(project, pv, osi_fn, auth_fn, target_override)
S = load(fullfile(project, 'saved_results', 'tests', 'tsting_osi', ...
    'GDBqFpKb.mat'));
r = S.result;
dt = r.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L0 = C*c2d(loadH(project), dt, 'zoh');
cfg = osi_fn('config', dt, L0, struct());
auth_override = struct('dt_update', cfg.step_s, 'target', target_override);
prm = auth_fn('params', auth_override);
ost = osi_fn('state', cfg);
ast = auth_fn('state', prm);
tap = r.u_osi(:); dm = r.dm(:); t = r.t(:); gain = r.Results(:, 21);
n = floor(min([numel(t), numel(tap), numel(dm)])/cfg.step_n);
tc = NaN(n,1); b = NaN(n,1); aa = NaN(n,1);
a = prm.a_init;
for k = 1:n
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    ost.a_cmd = a;
    [b(k), ost, oi] = osi_fn(tap(ii), dm(ii), cfg, ost);
    [a, ast] = auth_fn(b(k), oi.full_margin, oi.residual_weight, ast, prm);
    tc(k) = t(ii(end)); aa(k) = a;
end
last = n*cfg.step_n;
gdb = struct('t_sig', t(1:last), 'dm', dm(1:last), 'tc', tc, 'b', b, ...
    'a', aa, 'gain', gain((1:n)'*cfg.step_n));
end

function H = loadH(project)
E = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
H = E.H_dc_dm;
end
