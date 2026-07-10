%% RUN_GPT_STUDY Fresh ten-case comparison and GDBqFpKb replay.
% All outputs remain beside this script under research/gpt5_6.

clear
here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
cd(here)
addpath(here)
addpath(fullfile(project, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(project, 'control_and_HS', 'OSI')))
addpath(genpath(fullfile(project, 'helpers')))

fprintf('Running fresh canonical FABLE comparison...\n')
fable_suite = gpt_synthetic_suite('fable', 0.55);
fprintf('Running GPT OSI on the same ten cases...\n')
gpt_suite = gpt_synthetic_suite('gpt', 0.55);

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
prm = gpt_auth('params', struct('target', 0.55, 'a_min', 0.2, ...
    'dt_update', cfg.step_s));
ost = gpt_osi('state', cfg);
ast = gpt_auth('state', prm);

tap = r.u_osi(:);
dm = r.dm(:);
t = r.t(:);
gain = r.Results(:,21);
nU = floor(min([numel(t),numel(tap),numel(dm)])/cfg.step_n);
tc = NaN(nU,1); bg = NaN(nU,1); ag = NaN(nU,1); bst = NaN(nU,1);
bres = NaN(nU,1); ready = false(nU,1); atarget = NaN(nU,1);
a = prm.a_init;
for k = 1:nU
    ii = (k-1)*cfg.step_n+(1:cfg.step_n);
    ost.a_cmd = a;
    [bg(k),ost,oi] = gpt_osi(tap(ii),dm(ii),cfg,ost);
    [a,ast,ai] = gpt_auth(bg(k),oi.L_hat,oi.b_res,ast,prm);
    tc(k) = t(ii(end)); ag(k) = a; bst(k) = oi.b_st; bres(k) = oi.b_res;
    ready(k) = oi.ready; atarget(k) = ai.a_target;
end
idx = (1:nU)'*cfg.step_n;
g = gain(idx);
aref = min(1,1./g);
gdb = struct('t',tc,'gain',g,'a_reference',aref, ...
    'fable_b',r.b_osi(idx),'fable_a',r.auth(idx), ...
    'gpt_b',bg,'gpt_b_st',bst,'gpt_b_res',bres, ...
    'gpt_a',ag,'gpt_a_target',atarget,'ready',ready);
gdb.metrics = gdbMetrics(gdb);

acceptance = acceptanceMetrics(gpt_suite,gdb);
result = struct('generated_at',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss Z')), ...
    'method','GPT OSI','target_ncf',0.55,'fable_suite',fable_suite, ...
    'gpt_suite',gpt_suite,'gdb',gdb,'acceptance',acceptance);

results_dir = fullfile(here,'results');
if ~exist(results_dir,'dir'), mkdir(results_dir), end
save(fullfile(results_dir,'gpt_osi_study.mat'),'result','-v7.3')
writeReportData(fullfile(here,'report_data.js'),result)
writeSummary(fullfile(here,'results','summary.txt'),result)

fprintf('\nGPT canonical cases: %d/10\n',nnz([gpt_suite.cases.pass]))
fprintf('Continuous output: %s\n',passText(acceptance.continuous))
fprintf('Warm-up <= 2 s: %s (%.3f s)\n',passText(acceptance.warmup_pass),acceptance.worst_warmup_s)
fprintf('Damage authority response <= 2 s: %s (%.3f s)\n', ...
    passText(acceptance.detection_pass),acceptance.worst_detection_s)
fprintf('Recovery <= 2 s: %s (%.3f s)\n', ...
    passText(acceptance.recovery_pass),acceptance.worst_recovery_s)
fprintf('GDB inverse-gain MAE: GPT %.3f | FABLE %.3f\n', ...
    gdb.metrics.gpt_mae,gdb.metrics.fable_mae)

function out = acceptanceMetrics(suite,gdb)
warm = [suite.cases.timing]; warm = [warm.warmup_s];
ids = [3 4 7]; timing = [suite.cases(ids).timing]; detect = [timing.authority_s];
idsr = [7 8]; timingr = [suite.cases(idsr).timing]; recover = [timingr.recovery_s];
finite_all = all(arrayfun(@(c) all(isfinite(c.sim.b_est)),suite.cases));
finite_gdb = all(isfinite(gdb.gpt_b));
chatter = zeros(1,numel(suite.cases));
for i = 1:numel(suite.cases)
    a = suite.cases(i).sim.a;
    da = diff(a); material = da(abs(da)>0.002);
    chatter(i) = nnz(diff(sign(material))~=0);
end
out = struct('canonical_pass',suite.all_pass, ...
    'canonical_pass_count',nnz([suite.cases.pass]), ...
    'continuous',finite_all&&finite_gdb, ...
    'worst_warmup_s',max(warm),'warmup_pass',all(warm<=2), ...
    'worst_detection_s',max(detect),'detection_pass',all(isfinite(detect)&detect<=2), ...
    'worst_recovery_s',max(recover),'recovery_pass',all(isfinite(recover)&recover<=2), ...
    'max_material_reversals',max(chatter),'chatter_pass',max(chatter)<=12, ...
    'all_pass',false);
out.all_pass = out.canonical_pass&&out.continuous&&out.warmup_pass&& ...
    out.detection_pass&&out.recovery_pass&&out.chatter_pass&&gdb.metrics.transition_pass;
end

function m = gdbMetrics(gdb)
t = gdb.t; g = gdb.gain; ref = gdb.a_reference;
edges = find([true;abs(diff(g))>1e-12]);
lat = NaN(numel(edges)-1,1); det = NaN(numel(edges)-1,1);
for j = 2:numel(edges)
    k = edges(j); t0 = t(k); newref = ref(k);
    if newref < ref(k-1)
        hit = find(t>=t0 & gdb.gpt_a<=newref+0.05,1);
        d = find(t>=t0 & gdb.gpt_b<=gdb.gpt_b(max(1,k-1))-0.04,1);
    else
        hit = find(t>=t0 & gdb.gpt_a>=newref-0.05,1);
        d = find(t>=t0 & gdb.gpt_b>=gdb.gpt_b(max(1,k-1))+0.04,1);
    end
    if ~isempty(hit), lat(j-1) = t(hit)-t0; end
    if ~isempty(d), det(j-1) = t(d)-t0; end
end
settled = t>=50.25;
m = struct('gpt_mae',mean(abs(gdb.gpt_a(settled)-ref(settled)),'omitnan'), ...
    'fable_mae',mean(abs(gdb.fable_a(settled)-ref(settled)),'omitnan'), ...
    'transition_latency_s',lat,'indicator_latency_s',det, ...
    'worst_transition_s',max(lat),'transition_pass',all(isfinite(lat)&lat<=2), ...
    'fable_nan_fraction',mean(~isfinite(gdb.fable_b)), ...
    'gpt_nan_fraction',mean(~isfinite(gdb.gpt_b)));
end

function writeReportData(file,result)
D = struct('generated_at',result.generated_at,'target',result.target_ncf, ...
    'acceptance',result.acceptance,'gdb_metrics',result.gdb.metrics, ...
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
    'a_reference',round(result.gdb.a_reference,5), ...
    'fable_b',round(result.gdb.fable_b,5),'fable_a',round(result.gdb.fable_a,5), ...
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
fprintf(fid,'GDB transition latencies: '); fprintf(fid,'%.3f ',result.gdb.metrics.transition_latency_s); fprintf(fid,'s\n');
end

function s = passText(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
