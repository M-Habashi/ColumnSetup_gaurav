function run_fabby_tests()
%RUN_FABBY_TESTS Full fabby validation: 10-case suite (fabby + fable
% reference), GDBqFpKb replay, and report_data.js export for
% fabby_report.html. Leaves OSI_tests/fable untouched (the suite harness
% writes its own results there; this script moves/restores them).

here = fileparts(mfilename('fullpath'));
main = fileparts(fileparts(here));
addpath(here)
addpath(fullfile(main, 'OSI_tests', 'fable'))
addpath(fullfile(main, 'research', 'gpt5_6'))
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

% ---- gpt5_6 on the same canonical suite ------------------------------------
clear gpt_osi
suite_gpt = fable_synthetic_suite('method', gpt5_method(), 'plot', false);
moveResult(fullfile(harnessRes, 'suite_gpt5.mat'), ...
    fullfile(resDir, 'suite_gpt5.mat'));

% ---- fabby score (margin-tracking metric) ----------------------------------
fprintf('\n== fabby ==');
score_fabby = fabby_score(suite_fabby, main);
fprintf('\n== fable ==');
score_fable = fabby_score(suite_fable, main);
fprintf('\n== gpt5 ==');
score_gpt = fabby_score(suite_gpt, main);

% ---- GDBqFpKb replay -------------------------------------------------------
gdb = replay_gdb(main);

save(fullfile(resDir, 'fabby_results.mat'), 'suite_fabby', 'suite_fable', ...
    'suite_gpt', 'gdb', 'score_fabby', 'score_fable', 'score_gpt');

% ---- export the report data ------------------------------------------------
make_report_data(here, suite_fabby, suite_fable, suite_gpt, gdb, ...
    score_fabby, score_fable, score_gpt)
fprintf('\nfabby suite all_pass = %d | fable: %d/10 | gpt5: %d/10\n', ...
    suite_fabby.all_pass, nnz([suite_fable.cases.pass]), ...
    nnz([suite_gpt.cases.pass]));
fprintf('score: fabby %.1f | fable %.1f | gpt5 %.1f\n', ...
    score_fabby.mean_score, score_fable.mean_score, score_gpt.mean_score);
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
    [a(k), ast] = fabby_auth(res.b(k), res.pred(:, k), res.agrid, ...
        res.blind(k), ast, prm);
end

% gpt5_6 on the same tap, same target; its estimator wants the authority
% that ACTED on the plant (the logged one, in an open-loop replay)
gcfg = gpt_osi('config', r.dt, C*H5, struct());
gprm = gpt_auth('params', struct('target', 0.55, 'dt_update', gcfg.step_s));
gost = gpt_osi('state', gcfg);
gast = gpt_auth('state', gprm);
n_step = numel(res.b);
b_gpt = NaN(n_step, 1);
a_gpt = NaN(n_step, 1);
for k = 1:n_step
    ii = (k-1)*gcfg.step_n + (1:gcfg.step_n);
    gost.a_cmd = r.auth(ii(1));
    [b_gpt(k), gost, gi] = gpt_osi(r.u_osi(ii), r.dm(ii), gcfg, gost);
    [a_gpt(k), gast] = gpt_auth(b_gpt(k), gi.full_margin, ...
        gi.residual_weight, gast, gprm);
end

gdb = struct('tc', res.tc, 'b', res.b, 'b_st', res.b_st, 'b_q', res.b_q, ...
    'a', a, 'b_gpt', b_gpt, 'a_gpt', a_gpt, ...
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
