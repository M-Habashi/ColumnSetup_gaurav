function suite = fable_synthetic_suite(varargin)
%FABLE_SYNTHETIC_SUITE Closed-loop scenario library + harness for OSI methods.
%
% Ground-truth test bench: a sample-accurate closed inner loop (discrete
% PID x identified plants) where the TRUE chordal NCF margin is computable
% at every update, so ANY indicator+authority method can be validated
% against known answers - including future methods that do not exist yet.
%
%   suite = fable_synthetic_suite                       % fable, all scenarios
%   suite = fable_synthetic_suite('scenarios', [1 3 8]) % subset
%   suite = fable_synthetic_suite('method', 'runtime')  % Speedgoat wrapper
%   suite = fable_synthetic_suite('method', m)          % YOUR method struct
%   suite = fable_synthetic_suite('target', 0.55, ...)  % regulation target
%   names = fable_synthetic_suite('list');              % scenario names
%   m     = fable_synthetic_suite('template');          % method skeleton
%
% ---------------------------------------------------------------------
% PLUGGING IN A NEW METHOD - copy the template and fill in two handles:
%   m.name    = 'my_method';
%   m.block_n = 256;                       % samples consumed per step
%   m.init    = @(dt, L0, target, pf) ctx; % build config/state once
%   m.step    = @(ctx, dd_blk, dm_blk) deal4(ctx, b, a, trip);
%             consume one block, return margin estimate b (NaN = no
%             evidence), authority a in [0,1], trip flag (0 if unused).
% The harness owns the plant; the returned authority scales the PID
% output from the next sample on (exactly like the real runtime).
% ---------------------------------------------------------------------
%
% Scenarios (all with computable true margin; healthy plant tf_sp1_7000,
% degraded tf_sp1_5000; true margins 0.588 / 0.345 at full authority):
%    1 healthy_broadband     no damage: accuracy, no false adaptation
%    2 intensity_step        input x5 mid-run: indicator must not move
%    3 damage_step_broadband plant swap: detect fast, shed, defend target
%    4 damage_step_lowband   damage invisible to the command band:
%                            quiet-band paths must catch it
%    5 silent                no command: no false alarms, no adaptation
%    6 gradual_softening     specimen stiffness fades over 40 s (realistic
%                            degradation, no step): track + defend
%    7 damage_then_repair    swap, then swap BACK (stability improves):
%                            deliberate latched recovery after a trip
%    8 starts_damaged_improves  starts BELOW target -> regulate onto the
%                            target; plant then heals -> fast, un-latched
%                            recovery to full authority
%    9 regime_change_healthy low-band -> broadband excitation switch on a
%                            healthy plant: rebaseline, no lasting shed
%   10 transient_pulse       0.3 s exogenous output burst: bounded
%                            reaction, no permanent collapse
%
% Figures land in figures/suite_<name>_<method>.png; results in
% results/suite_<method>.mat. Returns the suite struct with all traces.

% ---- argument handling ----------------------------------------------------
if nargin >= 1 && ischar(varargin{1})
    switch lower(varargin{1})
        case 'list'
            scn = scenarioTable();
            suite = {scn.name}';
            return
        case 'template'
            suite = methodTemplate();
            return
    end
end
opt = struct('scenarios', [], 'method', 'fable', 'target', 0.55, ...
    'osi_override', struct(), 'auth_override', struct(), 'plot', true);
for i = 1:2:numel(varargin)
    opt.(lower(varargin{i})) = varargin{i+1};
end

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
figDir = fullfile(here, 'figures');
resDir = fullfile(here, 'results');
if ~exist(figDir, 'dir'), mkdir(figDir), end
if ~exist(resDir, 'dir'), mkdir(resDir), end

rng(7, 'twister')
dt = 1/2048;

% ---- models ---------------------------------------------------------------
E7 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
E5 = load(fullfile(projectFolder, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H7 = ss(c2d(E7.H_dc_dm, dt, 'zoh'));
H5 = ss(c2d(E5.H_dc_dm, dt, 'zoh'));
fgrid = (1:100)';
cm = struct('dt', dt, 'C', C, 'H7', H7, 'H5', H5, ...
    'L7', squeeze(freqresp(C*H7, 2*pi*fgrid)), ...
    'L5', squeeze(freqresp(C*H5, 2*pi*fgrid)), ...
    'target', opt.target, 'noise_std', 0.05, 'cmd_rms', 0.15, ...
    'nominal_tf', C*H7, 'projectFolder', projectFolder, ...
    'osi_override', opt.osi_override, 'auth_override', opt.auth_override);

% ---- method ---------------------------------------------------------------
if ischar(opt.method)
    switch lower(opt.method)
        case 'fable'
            method = fableMethod();
        case 'runtime'
            method = runtimeMethod();
        otherwise
            error('unknown built-in method %s', opt.method)
    end
else
    method = opt.method;
end

scn = scenarioTable();
if isempty(opt.scenarios)
    opt.scenarios = 1:numel(scn);
end

suite = struct('method', method.name, 'target', opt.target, ...
    'cases', struct('name', {}, 'pass', {}, 'detail', {}, 'sim', {}));
for i = opt.scenarios(:)'
    fprintf('\n=== %2d %s (%s) ===\n', i, scn(i).name, method.name);
    sim = simulateScenario(scn(i), cm, method);
    [pass, detail] = evaluateScenario(scn(i), sim, cm);
    if opt.plot
        plotScenario(scn(i), sim, cm, figDir, method.name);
    end
    suite.cases(end+1) = struct('name', scn(i).name, 'pass', pass, ...
        'detail', detail, 'sim', keepLight(sim));
    fprintf('%s\n', detail);
end

fprintf('\n================ SUITE SUMMARY (%s) ================\n', ...
    method.name);
for i = 1:numel(suite.cases)
    fprintf('%-26s %s\n', suite.cases(i).name, ...
        ternary(suite.cases(i).pass, 'PASS', 'FAIL'));
end
suite.all_pass = all([suite.cases.pass]);
save(fullfile(resDir, ['suite_' method.name '.mat']), 'suite');
end

% ==========================================================================
% scenario definitions
% ==========================================================================
function scn = scenarioTable()
% Fields:
%   dur_s        duration
%   band         command band [lo hi] Hz (NaN = silent)
%   band2/band_switch_s  second band + switch time (regime change)
%   lam_t/lam_v  breakpoints of the plant blend lambda(t):
%                y = (1-lambda)*y_healthy + lambda*y_damaged
%   amp_step_s   input x5 amplitude step time
%   pulse_s      [start len] of an exogenous output burst (30-60 Hz)
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
% piecewise-linear plant blend (0 = healthy, 1 = damaged); duplicate
% breakpoints encode steps
if isempty(scn.lam_t)
    lam = 0;
    return
end
xt = scn.lam_t;
xv = scn.lam_v;
if t <= xt(1)
    lam = xv(1);
    return
end
if t >= xt(end)
    lam = xv(end);
    return
end
lam = xv(1);
for i = numel(xt)-1:-1:1
    if t >= xt(i)
        if xt(i+1) > xt(i)
            lam = xv(i) + (xv(i+1) - xv(i))*(t - xt(i))/(xt(i+1) - xt(i));
        else
            lam = xv(i+1);
        end
        return
    end
end
end

% ==========================================================================
% built-in method adapters
% ==========================================================================
function m = fableMethod()
% the fable desktop implementation (fable_osi + fable_auth)
m = struct('name', 'fable', 'block_n', 256, ...
    'init', @initFable, 'step', @stepFable);
end
function ctx = initFable(dt, L0, target, cm)
ovr = cm.osi_override;
ovr.cal_skip_s = getfieldwithdefault(ovr, 'cal_skip_s', 6);
ovr.cal_windows = getfieldwithdefault(ovr, 'cal_windows', 60);
ovr.threshold = target;
cfg = fable_osi('config', dt, L0, ovr);
aovr = cm.auth_override;
aovr.target = target;
aovr.dt_update = cfg.step_s;
prm = fable_auth('params', aovr);
ctx = struct('cfg', cfg, 'state', fable_osi('state', cfg), ...
    'prm', prm, 'ast', fable_auth('state', prm), 'a_last', prm.a_init);
end
function [ctx, b, a, trip] = stepFable(ctx, dd_blk, dm_blk)
ctx.state.a_cmd = ctx.a_last;   % authority applied during this block
[b, ctx.state, oi] = fable_osi(dd_blk, dm_blk, ctx.cfg, ctx.state);
[a, ctx.ast] = fable_auth(b, oi.st_valid, oi.trip_reason, oi.b_fast, ...
    oi.pred_margin, oi.pred_valid, oi.alpha_grid, ctx.ast, ctx.prm, ...
    oi.st_binding, oi.regime_recal);
ctx.a_last = a;
trip = oi.trip_reason;
end

function m = runtimeMethod()
% the flattened Speedgoat wrapper (fable_osi_runtime) - what the target
% actually executes; bitwise-identical to 'fable' by test_fable_runtime_
% equivalence, so use 'fable' for speed and this for final confirmation
m = struct('name', 'runtime', 'block_n', 256, ...
    'init', @initRuntime, 'step', @stepRuntime);
end
function ctx = initRuntime(dt, ~, target, cm)
clear fable_osi_runtime
hs = struct('exp_tf_file', fullfile(cm.projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_7000_20260627_210411.mat'), ...
    'target_outer_ncf', target, 'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0, ...
    'fable_osi_override', setfieldwithdefaults(cm.osi_override, ...
        struct('cal_skip_s', 6, 'cal_windows', 60)), ...
    'fable_auth_override', cm.auth_override);
ctx = prepare_fable_runtime(cm.projectFolder, dt, hs);
end
function [ctx, b, a, trip] = stepRuntime(ctx, dd_blk, dm_blk)
b = NaN; a = 1; trip = 0;
for i = 1:numel(dd_blk)
    [a, b, ~, ~, ~, trip] = fable_osi_runtime(dd_blk(i), dm_blk(i), 1, ...
        ctx.fbls, ctx.fblw, ctx.fblbins, ctx.fblfw, ctx.fblfbins, ...
        ctx.fblag, ctx.fbla);
end
end

function m = methodTemplate()
% copy this, rename, fill in init/step - then
%   fable_synthetic_suite('method', m)
m = struct('name', 'template_passthrough', 'block_n', 256, ...
    'init', @(dt, L0, target, cm) struct(), ...
    'step', @(ctx, dd_blk, dm_blk) deal(ctx, NaN, 1, 0));
end

function s = setfieldwithdefaults(s, d)
fn = fieldnames(d);
for i = 1:numel(fn)
    if ~isfield(s, fn{i})
        s.(fn{i}) = d.(fn{i});
    end
end
end
function v = getfieldwithdefault(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end

% ==========================================================================
% closed-loop simulation
% ==========================================================================
function sim = simulateScenario(scn, cm, method)
dt = cm.dt;
fs = 1/dt;
N = round(scn.dur_s*fs);
t = (1:N)'*dt;

% command: band-limited noise, optional band switch / amplitude step
dd = zeros(N, 1);
if ~any(isnan(scn.band))
    dd = bandNoise(N, fs, scn.band)*cm.cmd_rms;
    if isfinite(scn.band_switch_s) && ~isempty(scn.band2)
        i2 = t >= scn.band_switch_s;
        d2 = bandNoise(N, fs, scn.band2)*cm.cmd_rms;
        dd(i2) = d2(i2);
    end
    if isfinite(scn.amp_step_s)
        dd(t >= scn.amp_step_s) = 5*dd(t >= scn.amp_step_s);
    end
end
v = cm.noise_std*randn(N, 1);
% exogenous output burst (30-60 Hz), e.g. an impact on the table
pulse = zeros(N, 1);
if ~isempty(scn.pulse_s)
    ip = t >= scn.pulse_s(1) & t < scn.pulse_s(1) + scn.pulse_s(2);
    pb = bandNoise(N, fs, [30 60]);
    pulse(ip) = 0.6*pb(ip);
end

[Ac, Bc, Cc, Dc] = ssdata(ss(cm.C));
[A7, B7, C7] = ssdata(cm.H7);
[A5, B5, C5] = ssdata(cm.H5);
xc = zeros(size(Ac, 1), 1);
x7 = zeros(size(A7, 1), 1);
x5 = zeros(size(A5, 1), 1);

ctx = method.init(dt, cm.nominal_tf, cm.target, cm);
blkN = method.block_n;
nU = floor(N/blkN);
tc = NaN(nU, 1); bE = NaN(nU, 1); bT = NaN(nU, 1); aU = NaN(nU, 1);
trp = zeros(nU, 1);
bSt = NaN(nU, 1); bRes = NaN(nU, 1); bFast = NaN(nU, 1);
dec = zeros(nU, 1);

dm = zeros(N, 1);
a = 1;
ku = 0;
dd_blk = zeros(blkN, 1); dm_blk = zeros(blkN, 1); blk_i = 0;

for k = 1:N
    lam = lambdaAt(scn, t(k));
    y = (1 - lam)*(C7*x7) + lam*(C5*x5);
    dm(k) = y + v(k) + pulse(k);
    e = dd(k) - dm(k);
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = a*u;
    x7 = A7*x7 + B7*dck;
    x5 = A5*x5 + B5*dck;

    blk_i = blk_i + 1;
    dd_blk(blk_i) = dd(k);
    dm_blk(blk_i) = dm(k);
    if blk_i == blkN
        blk_i = 0;
        ku = ku + 1;
        if nargout(method.step) >= 5
            [ctx, b, a, tr, extra] = method.step(ctx, dd_blk, dm_blk);
        else
            [ctx, b, a, tr] = method.step(ctx, dd_blk, dm_blk);
            extra = struct();
        end
        a = min(max(a, 0), 1);
        tc(ku) = t(k);
        bE(ku) = b;
        aU(ku) = a;
        trp(ku) = tr;
        if isfield(extra, 'b_st'), bSt(ku) = extra.b_st; end
        if isfield(extra, 'b_res'), bRes(ku) = extra.b_res; end
        if isfield(extra, 'b_fast'), bFast(ku) = extra.b_fast; end
        if isfield(extra, 'decision'), dec(ku) = extra.decision; end
        La = a*((1 - lam)*cm.L7 + lam*cm.L5);
        bT(ku) = min(abs(1 + La)./sqrt(2*(1 + abs(La).^2)));
    end
end

sim = struct('t', t, 'dm', dm, 'tc', tc, 'b_est', bE, 'b_true', bT, ...
    'a', aU, 'trip', trp, 'b_st', bSt, 'b_res', bRes, ...
    'b_fast', bFast, 'decision', dec);
end

function x = bandNoise(N, fs, band)
w = randn(N, 1);
X = fft(w);
f = (0:N-1)'*fs/N;
f = min(f, fs - f);
x = real(ifft(X.*(f >= band(1) & f <= band(2))));
x = x/rms(x);
end

% ==========================================================================
% evaluation
% ==========================================================================
function [pass, detail] = evaluateScenario(scn, sim, cm)
tg = cm.target;
msgs = {};
ok = true;
ready_t = sim.tc(find(~isnan(sim.b_est), 1));
if isempty(ready_t), ready_t = Inf; end
post = sim.tc > ready_t + 2;

switch scn.name
    case {'healthy_broadband', 'intensity_step'}
        if strcmp(scn.name, 'intensity_step')
            mid = post & abs(sim.tc - scn.amp_step_s) < 4;
        else
            mid = false(size(post));
        end
        w = post & ~mid;
        e = abs(sim.b_est(w) - sim.b_true(w));
        [ok, msgs] = chk(ok, msgs, median(e, 'omitnan') <= 0.06, ...
            sprintf('median |b_est-b_true| = %.3f (<= 0.06)', ...
            median(e, 'omitnan')));
        % the target sits ~1.5 sigma under the healthy margin, so noise
        % straddles it by design: flag MATERIAL false deficits only
        fl = mean(sim.b_est(w) < tg - 0.04, 'omitnan');
        [ok, msgs] = chk(ok, msgs, fl <= 0.02, ...
            sprintf('material false-low rate = %.1f%% (<= 2%%)', 100*fl));
        % target 0.55 sits only 0.04 under the healthy margin (0.588), a
        % ~2-sigma gap for the estimator: occasional small regulation
        % moves are CORRECT tracking behavior - demand mostly-full, never
        % deeply shed authority instead of a hard a==1
        [ok, msgs] = chk(ok, msgs, mean(sim.a(w)) >= 0.92, ...
            sprintf('mean authority = %.3f (>= 0.92)', mean(sim.a(w))));
        [ok, msgs] = chk(ok, msgs, min(sim.a(w)) >= 0.70, ...
            sprintf('min authority = %.2f (>= 0.70)', min(sim.a(w))));
        [ok, msgs] = chk(ok, msgs, ~any(sim.trip(w) > 0), 'no fast trips');
        [ok, msgs] = chk(ok, msgs, ...
            mean(sim.b_true(w) < tg - 0.02, 'omitnan') == 0, ...
            'true margin never regulated below target-0.02');
    case {'damage_step_broadband', 'damage_step_lowband'}
        lowband = strcmp(scn.name, 'damage_step_lowband');
        act_lim = 0.75 + 1.25*lowband;   % strict 0.5 s validated in
                                         % run_fable_synthetic_checks S3
        swap_s = scn.lam_t(1);
        ipre = find(sim.tc <= swap_s, 1, 'last');
        a_pre = sim.a(ipre);
        iact = find(sim.tc > swap_s & sim.a < 0.98*a_pre, 1);
        tact = NaN;
        if ~isempty(iact), tact = sim.tc(iact) - swap_s; end
        [ok, msgs] = chk(ok, msgs, ~isnan(tact) && tact <= act_lim, ...
            sprintf('authority moved %.3f s after damage (<= %g s)', ...
            tact, act_lim));
        if lowband
            % quiet-band information limit is ABSOLUTE, not target-
            % relative: the residual branch cannot even engage below
            % res_min_growth_db (3 dB) of growth, which maps to a
            % defendable level of nominal/sqrt(2) ~= 0.42 for this rig
            tol_def = max(0.10, tg - 0.40);
        else
            tol_def = 0.03;
        end
        lastw = sim.tc > sim.tc(end) - 30;
        viol = mean(sim.b_true(lastw) < tg - tol_def, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol == 0, ...
            sprintf('true margin defended to target-%.2f (viol %.1f%%)', ...
            tol_def, 100*viol));
        [ok, msgs] = chk(ok, msgs, min(sim.a) < 0.9, ...
            sprintf('authority shed (min a = %.2f)', min(sim.a)));
        pre_h = post & sim.tc < swap_s;
        [ok, msgs] = chk(ok, msgs, ~any(sim.trip(pre_h) > 0), ...
            'no fast trips before damage');
    case 'silent'
        [ok, msgs] = chk(ok, msgs, all(sim.a >= sim.a(1) - 1e-9), ...
            'authority never shed on silence');
        [ok, msgs] = chk(ok, msgs, ~any(sim.trip > 0), 'no alarms');
    case 'gradual_softening'
        r0 = scn.lam_t(1);
        w = sim.tc > r0 - 5;
        viol = mean(sim.b_true(w) < tg - 0.04, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol <= 0.02, ...
            sprintf(['true margin held >= target-0.04 through the ' ...
            'ramp (viol %.1f%%)'], 100*viol));
        [ok, msgs] = chk(ok, msgs, sim.a(end) <= 0.80, ...
            sprintf('authority regulating at end (a = %.2f <= 0.80)', ...
            sim.a(end)));
        lastw = sim.tc > sim.tc(end) - 20;
        e = abs(sim.b_est(lastw) - sim.b_true(lastw));
        [ok, msgs] = chk(ok, msgs, median(e, 'omitnan') <= 0.08, ...
            sprintf('settled estimate error = %.3f (<= 0.08)', ...
            median(e, 'omitnan')));
        pre_h = post & sim.tc < r0 - 2;
        [ok, msgs] = chk(ok, msgs, ~any(sim.trip(pre_h) > 0), ...
            'no fast trips before the ramp');
    case 'damage_then_repair'
        swap_s = scn.lam_t(1);
        rep_s = scn.lam_t(3);
        iact = find(sim.tc > swap_s & sim.a < 0.98, 1);
        tact = NaN;
        if ~isempty(iact), tact = sim.tc(iact) - swap_s; end
        [ok, msgs] = chk(ok, msgs, ~isnan(tact) && tact <= 0.5, ...
            sprintf('authority moved %.3f s after damage (<= 0.5 s)', tact));
        dmg = sim.tc > swap_s + 25 & sim.tc < rep_s;
        viol = mean(sim.b_true(dmg) < tg - 0.03, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol == 0, ...
            sprintf('damaged phase defended to target-0.03 (viol %.1f%%)', ...
            100*viol));
        a60 = sim.a(find(sim.tc <= rep_s + 60, 1, 'last'));
        a105 = sim.a(find(sim.tc <= rep_s + 105, 1, 'last'));
        % recovery after a TRIP is deliberately latched (latch_decay_tau_s):
        % partial reclaim within a minute, not a sprint to 1.0
        [ok, msgs] = chk(ok, msgs, a60 >= 0.65, ...
            sprintf('a = %.2f at repair+60 s (>= 0.65, latched)', a60));
        [ok, msgs] = chk(ok, msgs, a105 >= 0.75, ...
            sprintf('a = %.2f at repair+105 s (>= 0.75)', a105));
        [ok, msgs] = chk(ok, msgs, a105 > sim.a(find(sim.tc <= rep_s, ...
            1, 'last')) + 0.1, 'authority recovering after repair');
        posth = sim.tc > rep_s + 5;
        viol2 = mean(sim.b_true(posth) < tg - 0.02, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol2 == 0, ...
            'true margin healthy throughout recovery');
    case 'starts_damaged_improves'
        imp_s = scn.lam_t(2);
        reg = sim.tc > 35 & sim.tc < imp_s;
        viol = mean(sim.b_true(reg) < tg - 0.03, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol == 0, ...
            sprintf(['damaged-start regulated to >= target-0.03 ' ...
            '(viol %.1f%%)'], 100*viol));
        emed = median(abs(sim.b_true(reg) - tg), 'omitnan');
        [ok, msgs] = chk(ok, msgs, emed <= 0.06, sprintf( ...
            'regulation tracks target (median |b_true-target| = %.3f)', ...
            emed));
        [ok, msgs] = chk(ok, msgs, max(sim.a(reg)) < 1, ...
            'authority below max while damaged');
        irec = find(sim.tc > imp_s & sim.a >= 0.95, 1);
        trec = NaN;
        if ~isempty(irec), trec = sim.tc(irec) - imp_s; end
        % NO trip fired here (the plant improved), so nothing is latched:
        % recovery is fast - this is the "improvement" contrast to case 7
        [ok, msgs] = chk(ok, msgs, ~isnan(trec) && trec <= 30, ...
            sprintf('full authority %.1f s after improvement (<= 30 s)', ...
            trec));
    case 'regime_change_healthy'
        sw = scn.band_switch_s;
        w = post & (sim.tc < sw - 2 | sim.tc > sw + 10);
        fl = mean(sim.b_est(w) < tg - 0.04, 'omitnan');
        [ok, msgs] = chk(ok, msgs, fl <= 0.02, ...
            sprintf('material false-low rate = %.1f%% (<= 2%%)', 100*fl));
        tr_out = any(sim.trip > 0 & (sim.tc < sw - 2 | sim.tc > sw + 6));
        [ok, msgs] = chk(ok, msgs, ~tr_out, ...
            'no fast trips outside the transition window');
        late = sim.tc > sw + 20;
        [ok, msgs] = chk(ok, msgs, all(sim.a(late) >= 0.85), ...
            sprintf('authority >= 0.85 after the switch (min %.2f)', ...
            min(sim.a(late))));
    case 'transient_pulse'
        p0 = scn.pulse_s(1);
        tr_out = any(sim.trip > 0 & (sim.tc < p0 - 0.5 | sim.tc > p0 + 6));
        [ok, msgs] = chk(ok, msgs, ~tr_out, ...
            'trips confined to the pulse + window flush');
        lowdur = sum(sim.b_est < tg & sim.tc > p0 & ...
            sim.tc < p0 + 30)*(sim.tc(2) - sim.tc(1));
        [ok, msgs] = chk(ok, msgs, lowdur <= 10, ...
            sprintf('margin depressed %.1f s only (<= 10 s)', lowdur));
        i40 = find(sim.tc <= p0 + 40, 1, 'last');
        [ok, msgs] = chk(ok, msgs, sim.a(i40) >= 0.22, ...
            sprintf('a = %.2f at pulse+40 s (>= 0.22, latched climb)', ...
            sim.a(i40)));
        a_end = sim.a(end);
        [ok, msgs] = chk(ok, msgs, a_end >= 0.5, ...
            sprintf('authority recovering by end (a = %.2f >= 0.5)', a_end));
        posth = sim.tc > p0 + 20;
        viol = mean(sim.b_true(posth) < tg - 0.02, 'omitnan');
        [ok, msgs] = chk(ok, msgs, viol == 0, ...
            'true margin healthy after the pulse');
end
pass = ok;
detail = strjoin(msgs, ' | ');
end

function [ok, msgs] = chk(ok, msgs, cond, msg)
tag = 'ok';
if ~cond, tag = 'FAIL'; end
msgs{end+1} = sprintf('[%s] %s', tag, msg);
ok = ok && cond;
end

% ==========================================================================
function plotScenario(scn, sim, cm, figDir, mname)
ink = [11 11 11]/255; muted = [137 135 129]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; aqua = [27 175 122]/255; red = [227 73 72]/255;
yellow = [237 161 0]/255;

fig = figure('Color', 'w', 'Position', [80 80 1000 720], 'Visible', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(ax1, sim.t(1:4:end), sim.dm(1:4:end), '-', 'Color', blue, ...
    'LineWidth', 0.5)
styleAxis(ax1, grid_c, muted, ink)
ylabel(ax1, 'dm (mm)')
title(ax1, sprintf('%s  [%s]', strrep(scn.name, '_', ' '), mname), ...
    'Color', ink)

ax2 = nexttile;
hold(ax2, 'on')
yline(ax2, cm.target, ':', 'target', 'Color', muted, 'LineWidth', 1)
hT = plot(ax2, sim.tc, sim.b_true, '-', 'Color', ink, 'LineWidth', 1.6);
hE = plot(ax2, sim.tc, sim.b_est, '-', 'Color', blue, 'LineWidth', 1.2);
legend(ax2, [hT hE], {'true margin', 'estimate'}, ...
    'Location', 'best', 'Box', 'off')
for tb = scn.lam_t
    xline(ax2, tb, '--', 'Color', red, 'LineWidth', 0.8, ...
        'HandleVisibility', 'off')
end
if isfinite(scn.band_switch_s)
    xline(ax2, scn.band_switch_s, '--', 'band switch', 'Color', yellow, ...
        'HandleVisibility', 'off')
end
styleAxis(ax2, grid_c, muted, ink)
ylabel(ax2, 'NCF margin')
ylim(ax2, [0 0.75])

ax3 = nexttile;
hold(ax3, 'on')
stairs(ax3, sim.tc, sim.a, '-', 'Color', aqua, 'LineWidth', 1.5)
tr = sim.trip > 0;
if any(tr)
    plot(ax3, sim.tc(tr), sim.a(tr), 'v', 'Color', yellow, ...
        'MarkerFaceColor', yellow, 'MarkerSize', 5)
end
styleAxis(ax3, grid_c, muted, ink)
ylabel(ax3, 'authority a')
ylim(ax3, [0 1.05])
xlabel(ax3, 'time (s)')
linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [0 sim.t(end)])

png = fullfile(figDir, ['suite_' scn.name '_' mname '.png']);
exportgraphics(fig, png, 'Resolution', 140)
close(fig)
end

function styleAxis(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9)
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
ax.Title.Color = ink;
end

function s = keepLight(sim)
s = sim;
s.dm = s.dm(1:8:end);
s.t = s.t(1:8:end);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
