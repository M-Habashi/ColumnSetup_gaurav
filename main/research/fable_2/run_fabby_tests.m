function run_fabby_tests()
%RUN_FABBY_TESTS Full fabby validation: 10-case suite (fabby + fable
% reference), GDBqFpKb replay, and report_data.js export for
% fabby_report.html. Leaves OSI_tests/fable untouched (the suite harness
% writes its own results there; this script moves/restores them).

here = fileparts(mfilename('fullpath'));
main = fileparts(fileparts(here));
addpath(here)
addpath(fullfile(main, 'OSI_tests', 'fable'))
resDir = fullfile(here, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir), end
harnessRes = fullfile(main, 'OSI_tests', 'fable', 'results');

% ---- fabby on the 10-case suite -------------------------------------------
clear fable_osi fabby_osi fable_osi_runtime
suite_fabby = fable_synthetic_suite('method', fabby_method(), 'plot', false);
moveResult(fullfile(harnessRes, 'suite_fabby.mat'), ...
    fullfile(resDir, 'suite_fabby.mat'));

% ---- fable reference on the same suite (restore its results file) ---------
fableResFile = fullfile(harnessRes, 'suite_fable.mat');
bak = [];
if exist(fableResFile, 'file')
    bak = fileread_bytes(fableResFile);
end
clear fable_osi
suite_fable = fable_synthetic_suite('method', 'fable', 'plot', false);
copyfile(fableResFile, fullfile(resDir, 'suite_fable_ref.mat'))
if ~isempty(bak)
    fid = fopen(fableResFile, 'w');
    fwrite(fid, bak);
    fclose(fid);
end

% ---- GDBqFpKb replay -------------------------------------------------------
gdb = replay_gdb(main);

save(fullfile(resDir, 'fabby_results.mat'), 'suite_fabby', 'suite_fable', ...
    'gdb');

% ---- export the report data ------------------------------------------------
make_report_data(here, suite_fabby, suite_fable, gdb)
fprintf('\nfabby suite all_pass = %d | fable reference: %d/%d\n', ...
    suite_fabby.all_pass, nnz([suite_fable.cases.pass]), ...
    numel(suite_fable.cases));
end

% ---------------------------------------------------------------------------
function gdb = replay_gdb(main)
S = load(fullfile(main, 'saved_results', 'tests', 'tsting_osi', ...
    'GDBqFpKb.mat'));
r = S.result;
E5 = load(fullfile(main, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, r.dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H5 = ss(c2d(E5.H_dc_dm, r.dt, 'zoh'));

res = fabby_osi('run', r.u_osi, r.dm, r.dt, C*H5, struct());
prm = fabby_auth('params', struct('target', 0.55));
ast = fabby_auth('state', prm);
a = NaN(numel(res.b), 1);
for k = 1:numel(res.b)
    [a(k), ast] = fabby_auth(res.b(k), ast, prm);
end

gdb = struct('tc', res.tc, 'b', res.b, 'b_st', res.b_st, 'b_q', res.b_q, ...
    'a', a, ...
    'auth_logged', interp1(r.t, r.auth, res.tc, 'previous'), ...
    'b_logged', interp1(r.t, r.b_osi, res.tc, 'previous'), ...
    'diag_gain', interp1(r.t, r.Results(:, 21), res.tc, 'previous'), ...
    't_raw', r.t, 'u_osi', r.u_osi, 'dm', r.dm);
end

function moveResult(src, dst)
if exist(src, 'file')
    movefile(src, dst)
end
end

function b = fileread_bytes(f)
fid = fopen(f, 'r');
b = fread(fid, inf, '*uint8');
fclose(fid);
end
