%FABLE_RECOVERY_ANALYSIS GDBqFpKb record extraction + HEAD-runtime replays.
% Exports gdb_data.json to the scratchpad folder for the HTML report.

clear fable_osi_runtime %#ok<CLFUNC>
scratch = fileparts(mfilename('fullpath'));
projectFolder = ['C:\Users\Victus\Desktop\folder_working\a purdue\' ...
    'aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main'];
cd(projectFolder)
addpath(genpath(fullfile(projectFolder, 'control_and_HS')))
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'OSI_tests', 'fable')))

S = load(fullfile(projectFolder, 'saved_results', 'tests', ...
    'tsting_osi', 'GDBqFpKb.mat'));
r = S.result;
t = r.t(:); dt = r.dt; N = numel(t);
gain = r.Results(:, 21);

out = struct();

% ---- logged record traces --------------------------------------------------
% step-grid sampling (published values hold between 0.125 s publishes)
isp = 256:256:N;
out.rec.t = round(t(isp), 4);
out.rec.b_osi = sig(r.b_osi(isp));
out.rec.b_st = sig(r.b_st(isp));
out.rec.b_res = sig(r.b_res(isp));
out.rec.b_fast = sig(r.b_fast(isp));
out.rec.auth = sig(r.auth(isp));
out.rec.gain = sig(gain(isp));
% dm min/max decimation for the context strip
nb = 1200; edgesI = round(linspace(1, N + 1, nb + 1));
dmlo = zeros(nb, 1); dmhi = zeros(nb, 1); tb = zeros(nb, 1);
for k = 1:nb
    seg = r.dm(edgesI(k):edgesI(k+1)-1);
    dmlo(k) = min(seg); dmhi(k) = max(seg);
    tb(k) = t(edgesI(k));
end
out.rec.dm_t = round(tb, 3); out.rec.dm_lo = round(dmlo, 4);
out.rec.dm_hi = round(dmhi, 4);

% ---- input-tap choice check ------------------------------------------------
% replay 85 s with u_osi vs dd as the runtime's first input, compare the
% published margin with the logged b_osi (as-run era differences noted)
tapNames = {'u_osi', 'dd'};
tapErr = NaN(1, 2);
for m = 1:2
    x = r.(tapNames{m})(:);
    hs1 = asRunHs(projectFolder, r);
    st1 = prepare_fable_runtime(projectFolder, dt, hs1);
    clear fable_osi_runtime
    Nn = round(85/dt);
    bb = NaN(N, 1);
    for i = 1:Nn
        [~, bi] = fable_osi_runtime(x(i), r.dm(i), 1, st1.fbls, ...
            st1.fblw, st1.fblbins, st1.fblfw, st1.fblfbins, ...
            st1.fblag, st1.fbla);
        bb(i) = bi;
    end
    clear fable_osi_runtime
    msk = isfinite(bb(1:Nn)) & isfinite(r.b_osi(1:Nn)) & t(1:Nn) > 20;
    tapErr(m) = median(abs(bb(msk) - r.b_osi(msk)));
    fprintf('tap %-6s median |b_replay - b_logged| = %.4g (n=%d)\n', ...
        tapNames{m}, tapErr(m), nnz(msk));
end
[~, best] = min(tapErr);
tap = r.(tapNames{best})(:);
fprintf('using tap: %s\n', tapNames{best});
out.meta.tap = tapNames{best};
out.meta.tap_err = tapErr;

% ---- replay R1: as-run intent at HEAD (clamp only, no blind probe) --------
hs1 = asRunHs(projectFolder, r);
[out.r1, w1] = replayRuntime(projectFolder, dt, hs1, tap, r.dm(:), t);
out.r1.warn = w1;

% ---- replay R2: production config at HEAD (clamp + blind probe) -----------
hs2 = productionHs(projectFolder);
[out.r2, w2] = replayRuntime(projectFolder, dt, hs2, tap, r.dm(:), t);
out.r2.warn = w2;

% ---- desktop-law policy comparison on R2's published sequences ------------
% baseline: production prm, pred off; candidate: same + context-aware blind
% probe (last valid margin was at/above the recovery threshold => probe
% after 1 s at the model-verified rate instead of 5 s at the cautious rate)
prm0 = productionPrm();
seqB = out.r2.b_seq; seqV = out.r2.valid_seq;
seqT = out.r2.trip_seq; seqF = out.r2.b_fast_seq;
aBase = runAuthPolicy(prm0, seqB, seqV, seqT, seqF, false);
aSmart = runAuthPolicy(prm0, seqB, seqV, seqT, seqF, true);
out.pol.t = out.r2.t;
out.pol.a_base = sig(aBase);
out.pol.a_smart = sig(aSmart);

% divergence of the pred-off desktop baseline vs the actual runtime replay
d = abs(aBase - out.r2.a);
fprintf('pred-off desktop baseline vs runtime replay: max|da| = %.4g\n', ...
    max(d));

fid = fopen(fullfile(scratch, 'gdb_data.json'), 'w');
fwrite(fid, jsonencode(out));
fclose(fid);
fprintf('WROTE %s\n', fullfile(scratch, 'gdb_data.json'));

% ============================================================================
function hs = asRunHs(projectFolder, r)
hs = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', 0.8, 'osi_gain_min', 0.2, ...
    'osi_gain_initial', 1.0, ...
    'fable_auth_override', r.hs.fable_auth_override, ...
    'fable_gate_override', r.hs.fable_gate_override);
end

function hs = productionHs(projectFolder)
hs = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', 0.55, 'osi_gain_min', 0.2, ...
    'osi_gain_initial', 1.0, ...
    'fable_auth_override', productionAuthOverride(), ...
    'fable_gate_override', struct('arm_s', 3.0, 'drop_s', 2.5));
end

function o = productionAuthOverride()
% mirror of main_ColumnSetup.m hs.fable_auth_override at current HEAD
o = struct('sev_down_rate', 8.0, 'trip_cool_s', 2.5, ...
    'b_filt_tau_s', 0.4, 'down_deadband', 0.01, 'down_confirm_n', 2, ...
    'down_power', 1.5, 'down_rate', 2.0, 'down_settle_s', 1.25, ...
    're_shed_delta', 0.02, 'sev_frac', 0.50, 'up_deadband', 0.04, ...
    'up_hold_s', 1, 'up_rate', 0.25, 'up_prop', 3, ...
    'up_rate_blind', 0.06, 'blind_up_after_s', 5, 'trip_drop', 0.50, ...
    'trip_power', 1.5, 'trip_undo_s', 2.5, 'self_move_gate_s', 1.5, ...
    'self_move_frac', 0.02, 'latch_relax', 1.15, 'latch_decay_tau_s', 1);
end

function prm = productionPrm()
o = productionAuthOverride();
o.target = 0.55; o.a_min = 0.2; o.a_init = 1.0; o.dt_update = 0.125;
o.use_pred = 0;
prm = fable_auth('params', o);
end

function [res, warnmsg] = replayRuntime(projectFolder, dt, hs, x, dm, t)
lastwarn('');
setup = prepare_fable_runtime(projectFolder, dt, hs);
warnmsg = lastwarn;
step_n = setup.cfg.step_n;
N = floor(min(numel(x), numel(dm))/step_n)*step_n;
half = round(step_n/2);
nU = floor((N - half)/step_n);
tc = NaN(nU, 1); b = NaN(nU, 1); bst = NaN(nU, 1); bres = NaN(nU, 1);
bfa = NaN(nU, 1); trip = zeros(nU, 1); a = NaN(nU, 1); vld = zeros(nU, 1);
clear fable_osi_runtime
k = 0;
for i = 1:N
    [ai, bi, bsti, bresi, bfi, tri, vi] = fable_osi_runtime( ...
        x(i), dm(i), 1, setup.fbls, setup.fblw, setup.fblbins, ...
        setup.fblfw, setup.fblfbins, setup.fblag, setup.fbla);
    if i > half && mod(i - half, step_n) == 0 && k < nU
        k = k + 1;
        tc(k) = t(i - half);
        b(k) = bi; bst(k) = bsti; bres(k) = bresi; bfa(k) = bfi;
        trip(k) = tri; a(k) = ai; vld(k) = double(vi ~= 0);
    end
end
clear fable_osi_runtime
res = struct('t', round(tc, 4), 'b', sig(b), 'b_st', sig(bst), ...
    'b_res', sig(bres), 'b_fast', sig(bfa), 'a', sig(a), ...
    'trip', trip, 'valid', vld, ...
    'target_eff', setup.target_outer_ncf, ...
    'b_seq', b, 'valid_seq', vld ~= 0, 'trip_seq', trip, ...
    'b_fast_seq', bfa);
fprintf(['replay done: target_eff=%.4g  a_end=%.3f  min_a=%.3f  ' ...
    'trips=%d\n'], setup.target_outer_ncf, a(end), min(a), nnz(trip > 0));
end

function a = runAuthPolicy(prm, b, valid, trip, bfast, smart)
% desktop fable_auth over published sequences; pred disabled (not logged).
% smart = context-aware blind probe: if the last valid margin was at or
% above target + up_deadband, blind recovery starts after 1 s at up_rate.
ast = fable_auth('state', prm);
n = numel(b);
a = NaN(n, 1);
b_last_valid = NaN;
for k = 1:n
    p = prm;
    if smart && isnan(b(k)) && isfinite(b_last_valid) ...
            && b_last_valid >= prm.target + prm.up_deadband
        p.blind_up_after_s = 1.0;
        p.up_rate_blind = prm.up_rate;
    end
    [a(k), ast] = fable_auth(b(k), valid(k), trip(k), bfast(k), ...
        NaN, false, 1, ast, p, false, false);
    if isfinite(b(k))
        b_last_valid = b(k);
    end
end
end

function y = sig(x)
y = round(x*1e4)/1e4;
end
