%FABLE_CAND_RUN Validate the candidate law: 10-case suite + GDB blind tail.
% Needs out (gdb_data) in base workspace from fable_recovery_analysis.m;
% reloads the JSON if absent. Exports cand_data.json.

scratch = fileparts(mfilename('fullpath'));
addpath(scratch)
projectFolder = ['C:\Users\Victus\Desktop\folder_working\a purdue\' ...
    'aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main'];
cd(projectFolder)
addpath(genpath(fullfile(projectFolder, 'OSI_tests', 'fable')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
addpath(genpath(fullfile(projectFolder, 'helpers')))

aovr = struct('sev_down_rate', 8.0, 'trip_cool_s', 2.5, ...
    'b_filt_tau_s', 0.4, 'down_deadband', 0.01, 'down_confirm_n', 2, ...
    'down_power', 1.5, 'down_rate', 2.0, 'down_settle_s', 1.25, ...
    're_shed_delta', 0.02, 'sev_frac', 0.50, 'up_deadband', 0.04, ...
    'up_hold_s', 1, 'up_rate', 0.25, 'up_prop', 3, ...
    'up_rate_blind', 0.06, 'blind_up_after_s', 5, 'trip_drop', 0.50, ...
    'trip_power', 1.5, 'trip_undo_s', 2.5, 'self_move_gate_s', 1.5, ...
    'self_move_frac', 0.02, 'latch_relax', 1.15, ...
    'latch_decay_tau_s', 120);   % restored caution; heal path releases it

% ---- candidate method for the suite ---------------------------------------
m = struct('name', 'cand', 'block_n', 256, ...
    'init', @(dt, L0, target, cm) initCand(dt, L0, target, cm, aovr), ...
    'step', @stepCand);
suite = fable_synthetic_suite('method', m, 'target', 0.55, 'plot', false);

% also: isolate the pure latch effect (production config, latch 120, no
% heal logic) using the stock law
aovrL = aovr; aovrL.blind_up_after_s = 5;
suiteL = fable_synthetic_suite('method', 'fable', 'target', 0.55, ...
    'auth_override', aovrL, 'plot', false);

% ---- GDB blind-tail with the candidate law --------------------------------
gd = jsondecode(fileread(fullfile(scratch, 'gdb_data.json')));
R = gd.r2;
o = aovr; o.target = 0.55; o.a_min = 0.2; o.a_init = 1.0;
o.dt_update = 0.125; o.use_pred = 0;
prm = fable_auth_cand('params', o);
ast = fable_auth_cand('state', prm);
n = numel(R.b_seq);
aC = NaN(n, 1);
for k = 1:n
    [aC(k), ast] = fable_auth_cand(R.b_seq(k), R.valid_seq(k) ~= 0, ...
        R.trip_seq(k), R.b_fast_seq(k), NaN, false, 1, ast, prm, ...
        false, false);
end
tg_ret = 75.4692;
i9 = find(R.t > tg_ret & aC >= 0.9, 1);
i1 = find(R.t > tg_ret & aC >= 0.999, 1);
fprintf('CAND on GDB: a>=0.9 at t=%.3f (+%.2f s), full at t=%.3f (+%.2f s)\n', ...
    R.t(i9), R.t(i9) - tg_ret, R.t(i1), R.t(i1) - tg_ret);

J = struct();
J.cand_gdb = struct('t', R.t, 'a', round(aC*1e4)/1e4);
J.suite_cand = suiteSummary(suite);
J.suite_latch120 = suiteSummary(suiteL);
fid = fopen(fullfile(scratch, 'cand_data.json'), 'w');
fwrite(fid, jsonencode(J));
fclose(fid);
fprintf('WROTE cand_data.json\n');
delete(fullfile(projectFolder, 'OSI_tests', 'fable', 'results', ...
    'suite_cand.mat'))

function s = suiteSummary(suite)
s = struct('all_pass', suite.all_pass, 'cases', {{}});
for i = 1:numel(suite.cases)
    s.cases{end+1} = struct('name', suite.cases(i).name, ...
        'pass', suite.cases(i).pass, 'detail', suite.cases(i).detail);
end
end

function ctx = initCand(dt, L0, target, cm, aovr)
ovr = cm.osi_override;
if ~isfield(ovr, 'cal_skip_s'), ovr.cal_skip_s = 6; end
if ~isfield(ovr, 'cal_windows'), ovr.cal_windows = 60; end
ovr.threshold = target;
cfg = fable_osi('config', dt, L0, ovr);
aovr.target = target;
aovr.dt_update = cfg.step_s;
prm = fable_auth_cand('params', aovr);
gprm = fable_evidence_gate('params', struct('dt_step', cfg.step_s));
ctx = struct('cfg', cfg, 'state', fable_osi('state', cfg), ...
    'prm', prm, 'ast', fable_auth_cand('state', prm), ...
    'gst', fable_evidence_gate('state', gprm), 'gprm', gprm, ...
    'a_last', prm.a_init);
end

function [ctx, b, a, trip] = stepCand(ctx, dd_blk, dm_blk)
ctx.state.a_cmd = ctx.a_last;
[b, ctx.state, oi] = fable_osi(dd_blk, dm_blk, ctx.cfg, ctx.state);
[b, valid_up, armed, ctx.gst] = fable_evidence_gate(dd_blk, b, ...
    oi.st_valid, ctx.gprm, ctx.gst);
[a, ctx.ast] = fable_auth_cand(b, valid_up, oi.trip_reason, oi.b_fast, ...
    oi.pred_margin, oi.pred_valid && armed, oi.alpha_grid, ctx.ast, ...
    ctx.prm, oi.st_binding, oi.regime_recal);
ctx.a_last = a;
trip = oi.trip_reason;
end
