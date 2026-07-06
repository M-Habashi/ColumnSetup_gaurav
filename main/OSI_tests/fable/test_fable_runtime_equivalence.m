function results = test_fable_runtime_equivalence(record_idx)
%TEST_FABLE_RUNTIME_EQUIVALENCE Runtime wrapper vs desktop implementation.
%
%   results = test_fable_runtime_equivalence        % synthetic signal only
%   results = test_fable_runtime_equivalence(2)     % + replay record #2
%
% Feeds the SAME dd/dm stream through
%   (a) fable_osi('config'/'state'/step) + evidence gate + fable_auth
%   (b) fable_osi_runtime sample-by-sample              (Speedgoat wrapper)
% and asserts the margin, branch, trip and authority traces are identical
% (same arithmetic -> must match bitwise; any mismatch is a porting bug).
%
% The runtime time-slices each step's work across base-rate ticks and
% publishes at a FIXED 56-tick latency after the step boundary (the
% Speedgoat CPU-overload fix), so the runtime trace is sampled mid-step
% (tick T0 + step_n/2 > 56) where the published values for that step are
% guaranteed stable. Values still match the desktop stream bitwise.
%
% The synthetic stream is designed to exercise every code path:
% calibration + finalize, excited/quiet classification, ST branch, fast
% FRF-change trip (mid-record plant-gain step), quiet-band burst +
% residual engagement (growing 35 Hz tone at the end), and the authority
% shed/recover/latch machinery.
%
% Run this after ANY change to fable_osi.m, fable_auth.m or
% fable_osi_runtime.m.

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

results = struct('name', {}, 'pass', {}, 'max_diff', {});

% ---- case A: synthetic path-coverage stream ------------------------------
rng(11, 'twister')
dt = 1/2048;
fs = 1/dt;
T = 90;
N = round(T*fs);
t = (1:N)'*dt;

E = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
H = E.H_dc_dm;
if get(H, 'Ts') == 0, H = c2d(H, dt, 'zoh'); end
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

% broadband command through the plant (open loop is fine for equivalence)
dd = randn(N, 1);
dd = bandLimit(dd, fs, [2 100])*0.2;
dm = lsim(ss(H), dd, t) + 0.02*randn(N, 1);
% mid-record FRF change (plant-gain step: fast ST trip material)
dm(t > 55) = 1.8*dm(t > 55);
% end-of-record growing quiet-band tone (residual + burst material)
grow = t > 75;
dm(grow) = dm(grow) + 0.15*exp((t(grow) - 75)/8) ...
    .*sin(2*pi*35*t(grow));

results(end+1) = runCase('synthetic', projectFolder, dt, dd, dm); %#ok<AGROW>

% ---- case B: optional record replay ---------------------------------------
if nargin >= 1 && ~isempty(record_idx)
    base = fullfile(projectFolder, 'saved_results', 'tests');
    files = { ...
        fullfile('20260617', ['20260617_1731_sp_1_ori_Pvar_I30_D0001_' ...
         'Po_015_Io_20_Do_00015.mat']), ...
        fullfile('20260617', ['20260617_1749_sp_1_ori_Pvar_I30_D0001_' ...
         'Po_015_Io_20_Do_00015.mat']), ...
        fullfile('20260630', '20260630_1930_testing_OSI.mat')};
    fp = fullfile(base, files{record_idx});
    L = load(fp);
    if isfield(L, 'result'), data = L.result; else, data = L; end
    results(end+1) = runCase(sprintf('record_%d', record_idx), ...
        projectFolder, data.dt, data.dd(:), data.dm(:)); %#ok<AGROW>
end

fprintf('\n============ equivalence summary ============\n');
for i = 1:numel(results)
    if results(i).pass, tag = 'PASS'; else, tag = 'FAIL'; end
    fprintf('%-14s max|diff| = %.3g   %s\n', results(i).name, ...
        results(i).max_diff, tag);
end
assert(all([results.pass]), 'runtime/desktop equivalence FAILED')
end

% ==========================================================================
function r = runCase(name, projectFolder, dt, dd, dm)
fprintf('=== %s (%.0f s of data) ===\n', name, numel(dd)*dt);

hs = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', 0.55, 'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0);
setup = prepare_fable_runtime(projectFolder, dt, hs);
cfg = setup.cfg;
prm = setup.prm;
gprm = setup.gate;
gprm.dt_step = cfg.step_s;
gprm = fable_evidence_gate('params', gprm);
fbls = setup.fbls; fblw = setup.fblw; fblbins = setup.fblbins;
fblfw = setup.fblfw; fblfbins = setup.fblfbins; fblag = setup.fblag;
fbla = setup.fbla;

n_step = floor(numel(dd)/cfg.step_n);

% ---- desktop reference ----------------------------------------------------
fprintf('  desktop replay ...'); tic
st = fable_osi('state', cfg);
ast = fable_auth('state', prm);
gst = fable_evidence_gate('state', gprm);
A = allocTr(n_step);
ak = prm.a_init;
for k = 1:n_step
    idx = (k-1)*cfg.step_n + (1:cfg.step_n);
    st.a_cmd = ak;      % authority applied during this step's samples
    [bk, st, ik] = fable_osi(dd(idx), dm(idx), cfg, st);
    [bk, valid_up, g_armed, gst] = fable_evidence_gate(dd(idx), bk, ...
        ik.st_valid, gprm, gst);
    [ak, ast, dk] = fable_auth(bk, valid_up, ik.trip_reason, ...
        ik.b_fast, ik.pred_margin, ik.pred_valid && g_armed, ...
        ik.alpha_grid, ast, prm, ik.st_binding, ik.regime_recal);
    A.b(k) = bk;
    A.b_st(k) = ik.ncf_st;
    A.b_res(k) = ik.ncf_res;
    A.b_fast(k) = ik.b_fast;
    A.trip(k) = ik.trip_reason;
    A.a(k) = ak;
    A.dec(k) = dk;
    A.g_armed(k) = g_armed;
end
fprintf(' %.1f s\n', toc);

% ---- runtime wrapper -------------------------------------------------------
fprintf('  runtime replay ...'); tic
clear fable_osi_runtime          % reset persistents
B = allocTr(n_step);
k = 0;
half = round(cfg.step_n/2);      % sampling offset: > publish latency (34)
for i = 1:n_step*cfg.step_n + half
    if i <= numel(dd)
        du = dd(i);
        yu = dm(i);
    else
        du = 0;                  % tail padding only feeds the raw rings;
        yu = 0;                  % the last step's publish uses its T0
    end                          % snapshot, so outputs are unaffected
    [auth, b_osi, b_st, b_res, b_fast, trip, ~, dec, armed] = ...
        fable_osi_runtime(du, yu, 1, fbls, fblw, fblbins, ...
        fblfw, fblfbins, fblag, fbla);
    if i > half && mod(i, cfg.step_n) == half
        k = k + 1;               % reads step k = (i - half)/step_n
        B.b(k) = b_osi;
        B.b_st(k) = b_st;
        B.b_res(k) = b_res;
        B.b_fast(k) = b_fast;
        B.trip(k) = trip;
        B.a(k) = auth;
        B.dec(k) = dec;
        B.g_armed(k) = armed;
    end
end
clear fable_osi_runtime
fprintf(' %.1f s\n', toc);

% ---- compare ---------------------------------------------------------------
d = 0;
d = max(d, diffTr(A.b, B.b, 'b'));
d = max(d, diffTr(A.b_st, B.b_st, 'b_st'));
d = max(d, diffTr(A.b_res, B.b_res, 'b_res'));
d = max(d, diffTr(A.b_fast, B.b_fast, 'b_fast'));
d = max(d, diffTr(A.trip, B.trip, 'trip'));
d = max(d, diffTr(A.a, B.a, 'a'));
d = max(d, diffTr(A.dec, B.dec, 'decision'));
d = max(d, diffTr(A.g_armed, B.g_armed, 'g_armed'));
r = struct('name', name, 'pass', d == 0, 'max_diff', d);
end

function A = allocTr(n)
A = struct('b', NaN(n,1), 'b_st', NaN(n,1), 'b_res', NaN(n,1), ...
    'b_fast', NaN(n,1), 'trip', zeros(n,1), 'a', NaN(n,1), ...
    'dec', zeros(n,1), 'g_armed', zeros(n,1));
end

function d = diffTr(x, y, name)
% max abs difference treating NaN==NaN as equal, NaN mismatch as failure
nanmis = xor(isnan(x), isnan(y));
both = ~isnan(x) & ~isnan(y);
d = 0;
if any(nanmis)
    d = Inf;
    fprintf('  %-8s NaN pattern mismatch at %d steps (first: %d)\n', ...
        name, nnz(nanmis), find(nanmis, 1));
    return
end
if any(both)
    d = max(abs(x(both) - y(both)));
end
if d > 0
    i = find(abs(x - y) == d & both, 1);
    fprintf('  %-8s max|diff| = %.3g at step %d (%.9g vs %.9g)\n', ...
        name, d, i, x(i), y(i));
end
end

function y = bandLimit(x, fs, band)
N = numel(x);
X = fft(x);
f = (0:N-1)'*fs/N;
f = min(f, fs - f);
mask = f >= band(1) & f <= band(2);
y = real(ifft(X.*mask));
y = y/rms(y);
end
