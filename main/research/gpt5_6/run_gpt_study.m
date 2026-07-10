%% RUN_GPT_STUDY Fresh ten-case comparison and GDBqFpKb replay.
% All outputs remain beside this script under research/gpt5_6.

clear
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
cd(here)
addpath(here)
addpath(fullfile(project, 'OSI_tests', 'fable'))
addpath(fullfile(project, 'research', 'fable_2'))
addpath(genpath(fullfile(project, 'control_and_HS', 'OSI')))
addpath(genpath(fullfile(project, 'helpers')))

fprintf('Running fresh canonical FABLE comparison...\n')
fable_suite = gpt_synthetic_suite('fable', 0.55);
fprintf('Running GPT OSI on the same ten cases...\n')
gpt_suite = gpt_synthetic_suite('gpt', 0.55);
fabby_score_result = fabby_score(gpt_suite, project);

fprintf('Replaying GDBqFpKb with gain hidden from GPT OSI...\n')
S = load(fullfile(project, 'saved_results', 'tests', 'tsting_osi', ...
    'GDBqFpKb.mat'));
r = S.result;
E = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, r.dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L0 = C*c2d(E.H_dc_dm, r.dt, 'zoh');
cfg = gpt_osi('config', r.dt, L0, struct());
prm = gpt_auth('params', struct('dt_update', cfg.step_s));
ost = gpt_osi('state', cfg);
ast = gpt_auth('state', prm);

tap = r.u_osi(:);
dm = r.dm(:);
t = r.t(:);
gain = r.Results(:,21);
nU = floor(min([numel(t),numel(tap),numel(dm)])/cfg.step_n);
tc = NaN(nU,1); bg = NaN(nU,1); ag = NaN(nU,1); bst = NaN(nU,1);
bres = NaN(nU,1); tap_rms = NaN(nU,1); ready = false(nU,1);
a = prm.a_init;
for k = 1:nU
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    ost.a_cmd = r.auth(ii(1));
    [bg(k),ost,oi] = gpt_osi(tap(ii),dm(ii),cfg,ost);
    [a,ast] = gpt_auth(bg(k),oi.full_margin, ...
        oi.residual_weight,ast,prm);
    tc(k) = t(ii(end)); ag(k) = a; bst(k) = oi.b_st; bres(k) = oi.b_res;
    tap_rms(k) = rms(ost.u);
    ready(k) = oi.ready;
end
idx = (1:nU)'*cfg.step_n;
g = gain(idx);
gdb = struct('t',tc,'gain',g,'diag_gain_inverse',min(1,1./g), ...
    'target_ncf',prm.target,'up_hysteresis',prm.guard, ...
    'a_init',prm.a_init,'regulator_rate',prm.rate, ...
    'logged_fable_b',r.b_osi(idx),'logged_fable_a',r.auth(idx), ...
    'gpt_b',bg,'gpt_b_st',bst,'gpt_b_res',bres, ...
    'gpt_a',ag,'tap_rms',tap_rms,'ready',ready);
gdb.metrics = gdbMetrics(gdb);

acceptance = acceptanceMetrics(gpt_suite,gdb,prm);
acceptance.fabby_score = fabby_score_result.mean_score;
acceptance.fabby_score_pass = acceptance.fabby_score > 92;
acceptance.all_pass = acceptance.all_pass&&acceptance.fabby_score_pass;
result = struct('generated_at',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')), ...
    'method','GPT OSI','target_ncf',0.55,'fable_suite',fable_suite, ...
    'gpt_suite',gpt_suite,'fabby_score',fabby_score_result, ...
    'gdb',gdb,'acceptance',acceptance);

results_dir = fullfile(here,'results');
if ~exist(results_dir,'dir'), mkdir(results_dir), end
save(fullfile(results_dir,'gpt_osi_study.mat'),'result','-v7.3')
writeReportData(fullfile(here,'report_data.js'),result)
writeSummary(fullfile(here,'results','summary.txt'),result)

fprintf('\nGPT canonical cases: %d/10\n',nnz([gpt_suite.cases.pass]))
fprintf('Fabby score: %.2f\n',fabby_score_result.mean_score)
fprintf('Continuous output: %s\n',passText(acceptance.continuous))
fprintf('Warm-up <= 2 s: %s (%.3f s)\n',passText(acceptance.warmup_pass),acceptance.worst_warmup_s)
fprintf('Margin-drop detection <= 2 s: %s (%.3f s)\n', ...
    passText(acceptance.detection_pass),acceptance.worst_detection_s)
fprintf('Authority response <= 2 s: %s (%.3f s)\n', ...
    passText(acceptance.authority_pass),acceptance.worst_authority_s)
fprintf('Recovery <= 2 s: %s (%.3f s)\n', ...
    passText(acceptance.recovery_pass),acceptance.worst_recovery_s)
fprintf('Tail reliability: %s (excess %.4f/s, step %.4f)\n', ...
    passText(acceptance.reliability_pass), ...
    acceptance.max_tail_excess_rate,acceptance.max_tail_step)
fprintf('GDB canonical replay: NCF target %.3f | rate %.2f\n', ...
    gdb.target_ncf,gdb.regulator_rate)
fprintf('GDB idle/no-shed: %s | quake deficit %.3f s (%s)\n', ...
    passText(acceptance.gdb_no_idle_shed_pass), ...
    gdb.metrics.quake_deficit_latency_s,passText(acceptance.gdb_detect_quake_deficit_pass))
fprintf('GDB edge 1.5x %.3f s (%s) | edge 2x %.3f s (%s)\n', ...
    gdb.metrics.indicator_latency_s(1),passText(acceptance.gdb_detect_edge_1p5_pass), ...
    gdb.metrics.indicator_latency_s(2),passText(acceptance.gdb_detect_edge_2_pass))
fprintf('GDB recovery %.3f s (%s), hold %.3f\n', ...
    gdb.metrics.recovery_latency_s,passText(acceptance.gdb_recovery_pass), ...
    gdb.metrics.recovery_tail_min_a)

function out = acceptanceMetrics(suite,gdb,prm)
warm = [suite.cases.timing]; warm = [warm.warmup_s];
ids = [3 4 7]; timing = [suite.cases(ids).timing];
detect = [timing.detection_s]; authority = [timing.authority_s];
idsr = [7 8]; timingr = [suite.cases(idsr).timing]; recover = [timingr.recovery_s];
finite_all = all(arrayfun(@(c) all(isfinite(c.sim.b_est)),suite.cases));
finite_gdb = all(isfinite(gdb.gpt_b));
max_step = zeros(1,numel(suite.cases));
max_backtrack = zeros(1,numel(suite.cases));
tail_excess_rate = zeros(1,numel(suite.cases));
tail_step = zeros(1,numel(suite.cases));
for i = 1:numel(suite.cases)
    a = suite.cases(i).sim.a(:); t = suite.cases(i).sim.tc(:);
    da = diff(a);
    max_step(i) = max(abs(da));
    reverse = da(1:end-1).*da(2:end)<0;
    leg = min(abs(da(1:end-1)),abs(da(2:end)));
    if any(reverse), max_backtrack(i) = max(leg(reverse)); end
    tail = t>=t(end)-30; at = a(tail); tt = t(tail);
    tail_step(i) = max(abs(diff(at)));
    travel = sum(abs(diff(at)))-abs(at(end)-at(1));
    tail_excess_rate(i) = travel/(tt(end)-tt(1));
end
out = struct('canonical_pass',suite.all_pass, ...
    'canonical_pass_count',nnz([suite.cases.pass]), ...
    'continuous',finite_all&&finite_gdb, ...
    'worst_warmup_s',max(warm),'warmup_pass',all(warm<=2), ...
    'worst_detection_s',max(detect),'detection_pass',all(isfinite(detect)&detect<=2), ...
    'worst_authority_s',max(authority),'authority_pass',all(isfinite(authority)&authority<=2), ...
    'worst_recovery_s',max(recover),'recovery_pass',all(isfinite(recover)&recover<=2), ...
    'max_update_step',max(max_step), ...
    'max_immediate_backtrack',max(max_backtrack), ...
    'max_tail_step',max(tail_step), ...
    'max_tail_excess_rate',max(tail_excess_rate), ...
    'reliability_pass',max(max_step)<=prm.max_step+1e-12 && ...
        max(max_backtrack)<=0.05 && max(tail_step)<=0.05, ...
    'gdb_continuous_pass',finite_gdb, ...
    'gdb_no_idle_shed_pass',gdb.metrics.no_idle_shed_pass, ...
    'gdb_no_idle_min_a',gdb.metrics.no_idle_min_a, ...
    'gdb_detect_quake_deficit_pass',gdb.metrics.quake_deficit_pass, ...
    'gdb_quake_activity_s',gdb.metrics.quake_activity_s, ...
    'gdb_quake_deficit_latency_s',gdb.metrics.quake_deficit_latency_s, ...
    'gdb_detect_edge_1p5_pass',gdb.metrics.indicator_pass(1), ...
    'gdb_detect_edge_2_pass',gdb.metrics.indicator_pass(2), ...
    'gdb_edge_1p5_latency_s',gdb.metrics.indicator_latency_s(1), ...
    'gdb_edge_2_latency_s',gdb.metrics.indicator_latency_s(2), ...
    'gdb_recovery_pass',gdb.metrics.recovery_pass, ...
    'gdb_recovery_margin_cross_s',gdb.metrics.recovery_margin_cross_s, ...
    'gdb_recovery_latency_s',gdb.metrics.recovery_latency_s, ...
    'gdb_recovery_tail_min_a',gdb.metrics.recovery_tail_min_a, ...
    'all_pass',false);
out.all_pass = out.canonical_pass&&out.continuous&&out.warmup_pass&& ...
    out.detection_pass&&out.authority_pass&&out.recovery_pass&& ...
    out.reliability_pass&&out.gdb_continuous_pass&&out.gdb_no_idle_shed_pass&& ...
    out.gdb_detect_quake_deficit_pass&&out.gdb_detect_edge_1p5_pass&& ...
    out.gdb_detect_edge_2_pass&&out.gdb_recovery_pass;
end

function m = gdbMetrics(gdb)
t = gdb.t; g = gdb.gain;
edges = find(abs(diff(g))>0.05)+1;
det = NaN(numel(edges),1);
direction = NaN(numel(edges),1);
for j = 1:numel(edges)
    k = edges(j); t0 = t(k);
    d = [];
    if j<numel(edges), kend = edges(j+1)-1; else, kend = numel(t); end
    window = false(size(t)); window(k:kend) = true;
    direction(j) = sign(g(k)-g(k-1));
    if direction(j)>0
        pre = t>=t0-1 & t<t0;
        bpre = median(gdb.gpt_b(pre),'omitnan');
        d = find(window & gdb.gpt_b<=bpre-0.04,1);
    end
    if ~isempty(d), det(j) = t(d)-t0; end
end
onset = find(t>=45 & gdb.tap_rms>0.05,1);
quake_hit = find(t>=t(onset) & gdb.gpt_b<gdb.target_ncf,1);
recovery_cross = find(t>=75.5 & ...
    gdb.gpt_b>=gdb.target_ncf+gdb.up_hysteresis,1);
recovery_hit = [];
if ~isempty(recovery_cross)
    recovery_hit = find(t>=t(recovery_cross) & gdb.gpt_a>=0.95,1);
end
idle = t<44;
m = struct('edge_time_s',t(edges),'gain_before',g(edges-1), ...
    'gain_after',g(edges),'indicator_latency_s',det, ...
    'indicator_pass',isfinite(det)&det<=2, ...
    'no_idle_min_a',min(gdb.gpt_a(idle)), ...
    'no_idle_shed_pass',all(abs(gdb.gpt_a(idle)-gdb.a_init)<=1e-12), ...
    'quake_activity_s',t(onset), ...
    'quake_deficit_latency_s',latency(t,onset,quake_hit), ...
    'quake_deficit_pass',isfinite(latency(t,onset,quake_hit)) && ...
        latency(t,onset,quake_hit)<=2, ...
    'recovery_margin_cross_s',timeAt(t,recovery_cross), ...
    'recovery_latency_s',latency(t,recovery_cross,recovery_hit), ...
    'recovery_tail_min_a',tailMin(gdb.gpt_a,recovery_hit), ...
    'recovery_pass',isfinite(latency(t,recovery_cross,recovery_hit)) && ...
        latency(t,recovery_cross,recovery_hit)<=3 && ...
        tailMin(gdb.gpt_a,recovery_hit)>=0.95, ...
    'logged_fable_nan_fraction',mean(~isfinite(gdb.logged_fable_b)), ...
    'gpt_nan_fraction',mean(~isfinite(gdb.gpt_b)));
end

function x = latency(t,start_idx,hit_idx)
if isempty(start_idx) || isempty(hit_idx), x = NaN; else, x = t(hit_idx)-t(start_idx); end
end

function x = timeAt(t,idx)
if isempty(idx), x = NaN; else, x = t(idx); end
end

function x = tailMin(a,idx)
if isempty(idx), x = NaN; else, x = min(a(idx:end)); end
end

function writeReportData(file,result)
score = struct('mean_score',result.fabby_score.mean_score, ...
    'case_scores',[result.fabby_score.cases.score]);
D = struct('generated_at',result.generated_at,'target',result.target_ncf, ...
    'fabby_score',score,'acceptance',result.acceptance, ...
    'gdb_metrics',result.gdb.metrics, ...
    'cases',[],'gdb',[]);
for i = 1:numel(result.gpt_suite.cases)
    g = result.gpt_suite.cases(i); f = result.fable_suite.cases(i);
    D.cases(i).name = g.name;
    D.cases(i).gpt_pass = g.pass; D.cases(i).fable_pass = f.pass;
    D.cases(i).gpt_detail = g.detail; D.cases(i).fable_detail = f.detail;
    D.cases(i).gpt_timing = g.timing; D.cases(i).fable_timing = f.timing;
    D.cases(i).t = round(g.sim.tc,4);
    D.cases(i).true_b = round(g.sim.b_true,5);
    D.cases(i).gpt_b = round(g.sim.b_est,5);
    D.cases(i).gpt_b_st = round(g.sim.b_st,5);
    D.cases(i).gpt_b_res = round(g.sim.b_res,5);
    D.cases(i).gpt_a = round(g.sim.a,5);
    D.cases(i).fable_b = round(f.sim.b_est,5);
    D.cases(i).fable_a = round(f.sim.a,5);
end
D.gdb = struct('t',round(result.gdb.t,4),'gain',result.gdb.gain, ...
    'diag_gain_inverse',round(result.gdb.diag_gain_inverse,5), ...
    'fable_b',round(result.gdb.logged_fable_b,5), ...
    'fable_a',round(result.gdb.logged_fable_a,5), ...
    'gpt_b',round(result.gdb.gpt_b,5),'gpt_b_st',round(result.gdb.gpt_b_st,5), ...
    'gpt_b_res',round(result.gdb.gpt_b_res,5),'gpt_a',round(result.gdb.gpt_a,5));
fid = fopen(file,'w');
cleanup = onCleanup(@()fclose(fid));
fwrite(fid,['window.GPT_OSI_DATA=' jsonencode(D,'ConvertInfAndNaN',true) ';'],'char');
end

function writeSummary(file,result)
fid = fopen(file,'w'); cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'GPT OSI STUDY\nGenerated: %s\n\n',result.generated_at);
for i = 1:numel(result.gpt_suite.cases)
    c = result.gpt_suite.cases(i);
    fprintf(fid,'%-28s %s\n%s\n\n',c.name,passText(c.pass),c.detail);
end
fprintf(fid,'Acceptance all pass: %s\n',passText(result.acceptance.all_pass));
fprintf(fid,'Fabby score: %.3f | > 92 | %s\n',result.acceptance.fabby_score,passText(result.acceptance.fabby_score_pass));
fprintf(fid,'GDB target: %.3f\n',result.gdb.target_ncf);
fprintf(fid,'GDB continuous: %s | %.0f NaN\n',passText(result.acceptance.gdb_continuous_pass),result.gdb.metrics.gpt_nan_fraction*numel(result.gdb.gpt_b));
fprintf(fid,'GDB no idle shed: %s | min a %.3f (t < 44 s)\n',passText(result.acceptance.gdb_no_idle_shed_pass),result.acceptance.gdb_no_idle_min_a);
fprintf(fid,'GDB quake deficit: %s | activity %.3f s, margin latency %.3f s (limit <= 2.000 s)\n',passText(result.acceptance.gdb_detect_quake_deficit_pass),result.acceptance.gdb_quake_activity_s,result.acceptance.gdb_quake_deficit_latency_s);
fprintf(fid,'GDB detect edge 1.5: %s | %.3f s (drop >= 0.040, limit <= 2.000 s)\n',passText(result.acceptance.gdb_detect_edge_1p5_pass),result.acceptance.gdb_edge_1p5_latency_s);
fprintf(fid,'GDB detect edge 2: %s | %.3f s (drop >= 0.040, limit <= 2.000 s)\n',passText(result.acceptance.gdb_detect_edge_2_pass),result.acceptance.gdb_edge_2_latency_s);
fprintf(fid,'GDB recovery: %s | margin cross %.3f s, authority latency %.3f s, tail min a %.3f (limit <= 3.000 s)\n',passText(result.acceptance.gdb_recovery_pass),result.acceptance.gdb_recovery_margin_cross_s,result.acceptance.gdb_recovery_latency_s,result.acceptance.gdb_recovery_tail_min_a);
end

function s = passText(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
