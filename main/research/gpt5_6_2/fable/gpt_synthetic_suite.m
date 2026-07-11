function suite = gpt_synthetic_suite(method_name, target, scenario_ids, ...
        auth_override, osi_override)
%GPT_SYNTHETIC_SUITE Local copy of the canonical ten FABLE scenarios.
% This harness writes nothing; callers save results under
% research/gpt5_6_2/fable.  Identical to research/gpt5_6's copy except the
% project-root computation (this file sits one level deeper).

if nargin < 1, method_name = 'gpt'; end
if nargin < 2, target = 0.55; end
if nargin < 3, scenario_ids = 1:10; end
if nargin < 4, auth_override = struct(); end
if nargin < 5, osi_override = struct(); end

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(fileparts(here)));
addpath(here)
addpath(fullfile(project, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(project, 'control_and_HS', 'OSI')))
addpath(genpath(fullfile(project, 'helpers')))

rng(7, 'twister')
dt = 1/2048;
E7 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
E5 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H7 = ss(c2d(E7.H_dc_dm, dt, 'zoh'));
H5 = ss(c2d(E5.H_dc_dm, dt, 'zoh'));
f = (1:100)';
cm = struct('dt', dt, 'C', C, 'H7', H7, 'H5', H5, ...
    'L7', squeeze(freqresp(C*H7, 2*pi*f)), ...
    'L5', squeeze(freqresp(C*H5, 2*pi*f)), ...
    'target', target, 'noise_std', 0.05, 'cmd_rms', 0.15, ...
    'nominal_tf', C*H7, 'gpt_auth_override', auth_override, ...
    'gpt_osi_override', osi_override);

switch lower(method_name)
    case 'gpt'
        method = struct('name', 'gpt', 'block_n', 256, ...
            'init', @initGpt, 'step', @stepGpt);
    case 'fable'
        method = struct('name', 'fable', 'block_n', 256, ...
            'init', @initFable, 'step', @stepFable);
    otherwise
        error('gpt_synthetic_suite:Method', 'Method must be ''gpt'' or ''fable''.')
end

scenarios = scenarioTable();
suite = struct('method', method.name, 'target', target, ...
    'cases', struct('name', {}, 'pass', {}, 'detail', {}, 'timing', {}, 'sim', {}));
for i = scenario_ids(:)'
    fprintf('\n=== %2d %s (%s) ===\n', i, scenarios(i).name, method.name)
    sim = simulateScenario(scenarios(i), cm, method);
    [pass, detail] = evaluateScenario(scenarios(i), sim, cm);
    timing = timingMetrics(scenarios(i), sim);
    suite.cases(end+1) = struct('name', scenarios(i).name, ...
        'pass', pass, 'detail', detail, 'timing', timing, ...
        'sim', keepLight(sim));
    fprintf('%s\n', detail)
end
suite.all_pass = all([suite.cases.pass]);
fprintf('\n%s: %d/%d PASS\n', upper(method.name), ...
    nnz([suite.cases.pass]), numel(suite.cases))
end

function ctx = initGpt(dt, L0, target, cm)
cfg = gpt_osi('config', dt, L0, cm.gpt_osi_override);
aovr = cm.gpt_auth_override;
aovr.target = target;
aovr.dt_update = cfg.step_s;
prm = gpt_auth('params', aovr);
ctx = struct('cfg', cfg, 'osi', gpt_osi('state', cfg), ...
    'prm', prm, 'auth', gpt_auth('state', prm), 'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = stepGpt(ctx, dd, dm)
ctx.osi.a_cmd = ctx.a_last;
[b, ctx.osi, oi] = gpt_osi(dd, dm, ctx.cfg, ctx.osi);
a0 = ctx.a_last;
[a, ctx.auth] = gpt_auth(b, oi.full_margin, oi.residual_weight, ...
    ctx.auth, ctx.prm);
ctx.a_last = a;
trip = 0;
extra = struct('b_st', oi.b_st, 'b_res', oi.b_res, 'b_fast', NaN, ...
    'decision', sign(a-a0), 'ready', oi.ready, ...
    'a_target', a, 'confidence', oi.confidence);
end

function ctx = initFable(dt, L0, target, ~)
cfg = fable_osi('config', dt, L0, struct('cal_skip_s', 6, ...
    'cal_windows', 60, 'threshold', target));
prm = fable_auth('params', struct('target', target, ...
    'dt_update', cfg.step_s));
gprm = fable_evidence_gate('params', struct('dt_step', cfg.step_s));
ctx = struct('cfg', cfg, 'osi', fable_osi('state', cfg), ...
    'prm', prm, 'auth', fable_auth('state', prm), ...
    'gprm', gprm, 'gate', fable_evidence_gate('state', gprm), ...
    'a_last', prm.a_init);
end

function [ctx, b, a, trip, extra] = stepFable(ctx, dd, dm)
ctx.osi.a_cmd = ctx.a_last;
[b, ctx.osi, oi] = fable_osi(dd, dm, ctx.cfg, ctx.osi);
[b, valid_up, armed, ctx.gate] = fable_evidence_gate(dd, b, ...
    oi.st_valid, ctx.gprm, ctx.gate);
[a, ctx.auth, decision] = fable_auth(b, valid_up, oi.trip_reason, ...
    oi.b_fast, oi.pred_margin, oi.pred_valid && armed, oi.alpha_grid, ...
    ctx.auth, ctx.prm, oi.st_binding, oi.regime_recal);
ctx.a_last = a;
trip = oi.trip_reason;
extra = struct('b_st', oi.ncf_st, 'b_res', oi.ncf_res, ...
    'b_fast', oi.b_fast, 'decision', decision, ...
    'ready', isfinite(b), 'a_target', NaN, 'confidence', double(valid_up));
end

function scn = scenarioTable()
scn = struct( ...
    'name', {'healthy_broadband', 'intensity_step', ...
             'damage_step_broadband', 'damage_step_lowband', 'silent', ...
             'gradual_softening', 'damage_then_repair', ...
             'starts_damaged_improves', 'regime_change_healthy', ...
             'transient_pulse'}, ...
    'dur_s', {75, 100, 105, 120, 60, 150, 210, 150, 140, 180}, ...
    'band', {[2 100], [2 100], [2 100], [2 10], [NaN NaN], ...
             [2 100], [2 100], [2 100], [2 7], [2 100]}, ...
    'band2', {[], [], [], [], [], [], [], [], [2 100], []}, ...
    'band_switch_s', {Inf, Inf, Inf, Inf, Inf, Inf, Inf, Inf, 70, Inf}, ...
    'lam_t', {[], [], [45 45], [50 50], [], [60 100], ...
              [50 50 100 100], [0 80 80], [], []}, ...
    'lam_v', {[], [], [0 1], [0 1], [], [0 1], ...
              [0 1 1 0], [1 1 0], [], []}, ...
    'amp_step_s', {Inf, 50, Inf, Inf, Inf, Inf, Inf, Inf, Inf, Inf}, ...
    'pulse_s', {[], [], [], [], [], [], [], [], [], [45 0.3]});
end

function lam = lambdaAt(scn, t)
if isempty(scn.lam_t), lam = 0; return, end
xt = scn.lam_t; xv = scn.lam_v;
if t <= xt(1), lam = xv(1); return, end
if t >= xt(end), lam = xv(end); return, end
lam = xv(1);
for i = numel(xt)-1:-1:1
    if t >= xt(i)
        if xt(i+1) > xt(i)
            lam = xv(i)+(xv(i+1)-xv(i))*(t-xt(i))/(xt(i+1)-xt(i));
        else
            lam = xv(i+1);
        end
        return
    end
end
end

function sim = simulateScenario(scn, cm, method)
dt = cm.dt; fs = 1/dt; N = round(scn.dur_s*fs); t = (1:N)'*dt;
dd = zeros(N, 1);
if ~any(isnan(scn.band))
    dd = bandNoise(N, fs, scn.band)*cm.cmd_rms;
    if isfinite(scn.band_switch_s) && ~isempty(scn.band2)
        i2 = t >= scn.band_switch_s;
        d2 = bandNoise(N, fs, scn.band2)*cm.cmd_rms;
        dd(i2) = d2(i2);
    end
    if isfinite(scn.amp_step_s), dd(t >= scn.amp_step_s) = 5*dd(t >= scn.amp_step_s); end
end
noise = cm.noise_std*randn(N, 1);
pulse = zeros(N, 1);
if ~isempty(scn.pulse_s)
    ip = t >= scn.pulse_s(1) & t < scn.pulse_s(1)+scn.pulse_s(2);
    pb = bandNoise(N, fs, [30 60]);
    pulse(ip) = 0.6*pb(ip);
end

[Ac, Bc, Cc, Dc] = ssdata(ss(cm.C));
[A7, B7, C7] = ssdata(cm.H7);
[A5, B5, C5] = ssdata(cm.H5);
xc = zeros(size(Ac,1),1); x7 = zeros(size(A7,1),1); x5 = zeros(size(A5,1),1);
ctx = method.init(dt, cm.nominal_tf, cm.target, cm);
blk = method.block_n; nU = floor(N/blk);
tc = NaN(nU,1); bE = NaN(nU,1); bT = NaN(nU,1); aU = NaN(nU,1);
trip = zeros(nU,1); bst = NaN(nU,1); bres = NaN(nU,1); bfast = NaN(nU,1);
decision = zeros(nU,1); ready = false(nU,1); atarget = NaN(nU,1); conf = NaN(nU,1);
dm = zeros(N,1); a = 1; ku = 0; ib = 0;
ddBlock = zeros(blk,1); dmBlock = zeros(blk,1);
for k = 1:N
    lam = lambdaAt(scn, t(k));
    y = (1-lam)*(C7*x7)+lam*(C5*x5);
    dm(k) = y+noise(k)+pulse(k);
    e = dd(k)-dm(k);
    u = Cc*xc+Dc*e;
    xc = Ac*xc+Bc*e;
    dck = a*u;
    x7 = A7*x7+B7*dck;
    x5 = A5*x5+B5*dck;
    ib = ib+1; ddBlock(ib) = dd(k); dmBlock(ib) = dm(k);
    if ib == blk
        ib = 0; ku = ku+1;
        [ctx, b, a, tr, ex] = method.step(ctx, ddBlock, dmBlock);
        a = min(max(a,0),1);
        tc(ku) = t(k); bE(ku) = b; aU(ku) = a; trip(ku) = tr;
        bst(ku) = ex.b_st; bres(ku) = ex.b_res; bfast(ku) = ex.b_fast;
        decision(ku) = ex.decision; ready(ku) = ex.ready;
        atarget(ku) = ex.a_target; conf(ku) = ex.confidence;
        La = a*((1-lam)*cm.L7+lam*cm.L5);
        bT(ku) = min(abs(1+La)./sqrt(2*(1+abs(La).^2)));
    end
end
sim = struct('t', t, 'dm', dm, 'tc', tc, 'b_est', bE, 'b_true', bT, ...
    'a', aU, 'trip', trip, 'b_st', bst, 'b_res', bres, ...
    'b_fast', bfast, 'decision', decision, 'ready', ready, ...
    'a_target', atarget, 'confidence', conf);
end

function x = bandNoise(N, fs, band)
w = randn(N,1); X = fft(w); f = (0:N-1)'*fs/N; f = min(f,fs-f);
x = real(ifft(X.*(f >= band(1) & f <= band(2))));
x = x/rms(x);
end

function [pass, detail] = evaluateScenario(scn, sim, cm)
tg = cm.target; msgs = {}; ok = true;
ready_t = sim.tc(find(isfinite(sim.b_est),1));
if isempty(ready_t), ready_t = Inf; end
post = sim.tc > ready_t+2;
switch scn.name
    case {'healthy_broadband','intensity_step'}
        if strcmp(scn.name,'intensity_step'), mid = post & abs(sim.tc-scn.amp_step_s)<4;
        else, mid = false(size(post)); end
        w = post & ~mid; e = abs(sim.b_est(w)-sim.b_true(w));
        [ok,msgs] = chk(ok,msgs,median(e,'omitnan')<=0.06, ...
            sprintf('median error %.3f <= 0.06',median(e,'omitnan')));
        fl = mean(sim.b_est(w)<tg-0.04,'omitnan');
        [ok,msgs] = chk(ok,msgs,fl<=0.02,sprintf('false-low %.1f%% <= 2%%',100*fl));
        [ok,msgs] = chk(ok,msgs,mean(sim.a(w))>=0.92,sprintf('mean a %.3f >= 0.92',mean(sim.a(w))));
        [ok,msgs] = chk(ok,msgs,min(sim.a(w))>=0.70,sprintf('min a %.2f >= 0.70',min(sim.a(w))));
        [ok,msgs] = chk(ok,msgs,~any(sim.trip(w)>0),'no fast trips');
        [ok,msgs] = chk(ok,msgs,mean(sim.b_true(w)<tg-0.02,'omitnan')==0,'true margin >= target-0.02');
    case {'damage_step_broadband','damage_step_lowband'}
        lowband = strcmp(scn.name,'damage_step_lowband'); lim = 0.75+1.25*lowband;
        sw = scn.lam_t(1); ip = find(sim.tc<=sw,1,'last'); apre = sim.a(ip);
        ia = find(sim.tc>sw & sim.a<0.98*apre,1); tact = NaN;
        if ~isempty(ia), tact = sim.tc(ia)-sw; end
        [ok,msgs] = chk(ok,msgs,isfinite(tact)&&tact<=lim,sprintf('authority response %.3f s <= %.2f s',tact,lim));
        tol = 0.03; if lowband, tol = max(0.10,tg-0.40); end
        last = sim.tc>sim.tc(end)-30; viol = mean(sim.b_true(last)<tg-tol,'omitnan');
        [ok,msgs] = chk(ok,msgs,viol==0,sprintf('defended violations %.1f%%',100*viol));
        [ok,msgs] = chk(ok,msgs,min(sim.a)<0.9,sprintf('min a %.2f < 0.90',min(sim.a)));
        pre = post & sim.tc<sw;
        [ok,msgs] = chk(ok,msgs,~any(sim.trip(pre)>0),'no pre-damage trips');
    case 'silent'
        [ok,msgs] = chk(ok,msgs,all(sim.a>=sim.a(1)-1e-9),'authority never sheds');
        [ok,msgs] = chk(ok,msgs,~any(sim.trip>0),'no alarms');
    case 'gradual_softening'
        r0 = scn.lam_t(1); w = sim.tc>r0-5;
        viol = mean(sim.b_true(w)<tg-0.04,'omitnan');
        [ok,msgs] = chk(ok,msgs,viol<=0.02,sprintf('ramp violations %.1f%% <= 2%%',100*viol));
        [ok,msgs] = chk(ok,msgs,sim.a(end)<=0.80,sprintf('final a %.2f <= 0.80',sim.a(end)));
        last = sim.tc>sim.tc(end)-20; e = abs(sim.b_est(last)-sim.b_true(last));
        [ok,msgs] = chk(ok,msgs,median(e,'omitnan')<=0.08,sprintf('settled error %.3f <= 0.08',median(e,'omitnan')));
        pre = post & sim.tc<r0-2; [ok,msgs] = chk(ok,msgs,~any(sim.trip(pre)>0),'no pre-ramp trips');
    case 'damage_then_repair'
        sw = scn.lam_t(1); rep = scn.lam_t(3);
        ia = find(sim.tc>sw & sim.a<0.98,1); tact = NaN;
        if ~isempty(ia), tact = sim.tc(ia)-sw; end
        [ok,msgs] = chk(ok,msgs,isfinite(tact)&&tact<=0.5,sprintf('damage response %.3f s <= 0.5 s',tact));
        dmg = sim.tc>sw+25 & sim.tc<rep; viol = mean(sim.b_true(dmg)<tg-0.03,'omitnan');
        [ok,msgs] = chk(ok,msgs,viol==0,sprintf('damaged violations %.1f%%',100*viol));
        a60 = sim.a(find(sim.tc<=rep+60,1,'last')); a105 = sim.a(find(sim.tc<=rep+105,1,'last'));
        [ok,msgs] = chk(ok,msgs,a60>=0.65,sprintf('a(repair+60) %.2f >= 0.65',a60));
        [ok,msgs] = chk(ok,msgs,a105>=0.75,sprintf('a(repair+105) %.2f >= 0.75',a105));
        arep = sim.a(find(sim.tc<=rep,1,'last'));
        [ok,msgs] = chk(ok,msgs,a105>arep+0.1,'authority recovers');
        ph = sim.tc>rep+5; [ok,msgs] = chk(ok,msgs,mean(sim.b_true(ph)<tg-0.02,'omitnan')==0,'healthy recovery margin');
    case 'starts_damaged_improves'
        imp = scn.lam_t(2); reg = sim.tc>35 & sim.tc<imp;
        viol = mean(sim.b_true(reg)<tg-0.03,'omitnan');
        [ok,msgs] = chk(ok,msgs,viol==0,sprintf('damaged-start violations %.1f%%',100*viol));
        em = median(abs(sim.b_true(reg)-tg),'omitnan');
        [ok,msgs] = chk(ok,msgs,em<=0.06,sprintf('target error %.3f <= 0.06',em));
        [ok,msgs] = chk(ok,msgs,max(sim.a(reg))<1,'authority below max while damaged');
        ir = find(sim.tc>imp & sim.a>=0.95,1); tr = NaN;
        if ~isempty(ir), tr = sim.tc(ir)-imp; end
        [ok,msgs] = chk(ok,msgs,isfinite(tr)&&tr<=30,sprintf('full authority %.2f s <= 30 s',tr));
    case 'regime_change_healthy'
        sw = scn.band_switch_s; w = post & (sim.tc<sw-2 | sim.tc>sw+10);
        fl = mean(sim.b_est(w)<tg-0.04,'omitnan');
        [ok,msgs] = chk(ok,msgs,fl<=0.02,sprintf('false-low %.1f%% <= 2%%',100*fl));
        tr = any(sim.trip>0 & (sim.tc<sw-2 | sim.tc>sw+6));
        [ok,msgs] = chk(ok,msgs,~tr,'no trips outside transition');
        late = sim.tc>sw+20;
        [ok,msgs] = chk(ok,msgs,all(sim.a(late)>=0.85),sprintf('late min a %.2f >= 0.85',min(sim.a(late))));
    case 'transient_pulse'
        p = scn.pulse_s(1); tr = any(sim.trip>0 & (sim.tc<p-0.5 | sim.tc>p+6));
        [ok,msgs] = chk(ok,msgs,~tr,'trips confined to pulse');
        lowdur = sum(sim.b_est<tg & sim.tc>p & sim.tc<p+30)*(sim.tc(2)-sim.tc(1));
        [ok,msgs] = chk(ok,msgs,lowdur<=10,sprintf('low duration %.1f s <= 10 s',lowdur));
        i40 = find(sim.tc<=p+40,1,'last');
        [ok,msgs] = chk(ok,msgs,sim.a(i40)>=0.22,sprintf('a(pulse+40) %.2f >= 0.22',sim.a(i40)));
        [ok,msgs] = chk(ok,msgs,sim.a(end)>=0.5,sprintf('final a %.2f >= 0.5',sim.a(end)));
        ph = sim.tc>p+20; [ok,msgs] = chk(ok,msgs,mean(sim.b_true(ph)<tg-0.02,'omitnan')==0,'healthy post-pulse margin');
end
pass = ok; detail = strjoin(msgs,' | ');
end

function timing = timingMetrics(scn, sim)
timing = struct('warmup_s', firstTime(sim.tc,sim.ready), ...
    'detection_s', NaN, 'authority_s', NaN, 'recovery_s', NaN);
if ~isempty(scn.lam_t)
    event = scn.lam_t(1); ip = find(sim.tc<=event,1,'last');
    if ~isempty(ip)
        apre = sim.a(ip);
        pre = sim.tc>=event-1 & sim.tc<=event;
        bpre = median(sim.b_est(pre),'omitnan');
        timing.detection_s = delay(sim.tc, ...
            sim.tc>event & sim.b_est<=bpre-0.04, event);
        timing.authority_s = delay(sim.tc, sim.tc>event & sim.a<0.98*apre, event);
    end
    if strcmp(scn.name,'damage_then_repair')
        rep = scn.lam_t(3); timing.recovery_s = delay(sim.tc,sim.tc>rep & sim.a>=0.95,rep);
    elseif strcmp(scn.name,'starts_damaged_improves')
        rep = scn.lam_t(2); timing.recovery_s = delay(sim.tc,sim.tc>rep & sim.a>=0.95,rep);
    end
end
end

function t = firstTime(x, mask)
i = find(mask,1); if isempty(i), t = NaN; else, t = x(i); end
end

function d = delay(t, mask, t0)
i = find(mask,1); if isempty(i), d = NaN; else, d = t(i)-t0; end
end

function [ok,msgs] = chk(ok,msgs,cond,msg)
tag = 'ok'; if ~cond, tag = 'FAIL'; end
msgs{end+1} = sprintf('[%s] %s',tag,msg);
ok = ok && cond;
end

function s = keepLight(s)
s.dm = s.dm(1:8:end); s.t = s.t(1:8:end);
end
