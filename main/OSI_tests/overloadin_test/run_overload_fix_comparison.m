function cmp = run_overload_fix_comparison()
%RUN_OVERLOAD_FIX_COMPARISON New time-sliced vs pre-fix burst OSI runtime.
%
% Runs the 10-scenario closed-loop synthetic suite (fable_synthetic_suite)
% with BOTH implementations, then replays the three saved hardware records
% through both. Saves traces, per-case metrics and comparison figures for
% the overloading-fix report (report.html in this folder).
%
% The two implementations are the same arithmetic (asserted bitwise by
% test_fable_runtime_equivalence); the time-sliced one publishes 56 base-
% rate ticks (27 ms) after each 0.125 s step boundary instead of bursting
% everything in the boundary tick. In the block-stepped suite that appears
% as a one-block (0.125 s) shift of the applied authority.

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))
figDir = fullfile(here, 'figures_comparison');
if ~exist(figDir, 'dir'), mkdir(figDir), end

% ---- 10 synthetic scenarios, both implementations -------------------------
new_m = struct('name', 'runtime_sliced', 'block_n', 256, ...
    'init', @initSliced, 'step', @stepSliced);
old_m = struct('name', 'runtime_burst', 'block_n', 256, ...
    'init', @initBurst, 'step', @stepBurst);

suite_new = fable_synthetic_suite('method', new_m);
suite_old = fable_synthetic_suite('method', old_m);

% ---- three hardware records, both implementations --------------------------
recBase = fullfile(projectFolder, 'saved_results', 'tests');
recs = { ...
    fullfile('20260617', ['20260617_1731_sp_1_ori_Pvar_I30_D0001_' ...
    'Po_015_Io_20_Do_00015.mat']), ...
    fullfile('20260617', ['20260617_1749_sp_1_ori_Pvar_I30_D0001_' ...
    'Po_015_Io_20_Do_00015.mat']), ...
    fullfile('20260630', '20260630_1930_testing_OSI.mat')};
recNames = {'record_1731_Pvar', 'record_1749_Pvar', 'record_1930_OSI'};

hsRec = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', 0.55, 'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0);

records = struct('name', {}, 'tc', {}, 'old', {}, 'new', {}, ...
    'dm', {}, 't', {}, 'max_shift_diff', {});
for r = 1:numel(recs)
    L = load(fullfile(recBase, recs{r}));
    if isfield(L, 'result'), data = L.result; else, data = L; end
    dd = data.dd(:);
    dm = data.dm(:);
    dt = data.dt;
    setup = prepare_fable_runtime(projectFolder, dt, hsRec);
    fprintf('=== %s (%.0f s) ===\n', recNames{r}, numel(dd)*dt);
    old = replayRecord(@refWrap, dd, dm, setup, 0);
    new = replayRecord(@newWrap, dd, dm, setup, round(setup.cfg.step_n/2));
    n = min(numel(old.b), numel(new.b));
    d = maxDiffNaN(old.b(1:n), new.b(1:n));
    d = max(d, maxDiffNaN(old.a(1:n), new.a(1:n)));
    fprintf('  step-aligned max|old-new| (b, a): %.3g\n', d)
    records(end+1) = struct('name', recNames{r}, ...
        'tc', (1:n)'*setup.cfg.step_s, ...
        'old', struct('b', old.b(1:n), 'a', old.a(1:n), ...
        'b_st', old.b_st(1:n), 'b_fast', old.b_fast(1:n), ...
        'trip', old.trip(1:n)), ...
        'new', struct('b', new.b(1:n), 'a', new.a(1:n), ...
        'b_st', new.b_st(1:n), 'b_fast', new.b_fast(1:n), ...
        'trip', new.trip(1:n)), ...
        'dm', dm(1:64:end), 't', (1:64:numel(dm))'*dt, ...
        'max_shift_diff', d); %#ok<AGROW>
end

% ---- figures ----------------------------------------------------------------
for i = 1:numel(suite_new.cases)
    plotSuiteCase(suite_new.cases(i), suite_old.cases(i), ...
        suite_new.target, figDir);
end
for r = 1:numel(records)
    plotRecordCase(records(r), figDir);
end

cmp = struct('suite_new', suite_new, 'suite_old', suite_old, ...
    'records', records);
save(fullfile(here, 'overload_fix_comparison.mat'), 'cmp', '-v7.3')
fprintf('COMPARISON_DONE new_all_pass=%d old_all_pass=%d\n', ...
    suite_new.all_pass, suite_old.all_pass)
end

% ==========================================================================
function ctx = initSliced(dt, ~, target, cm)
clear fable_osi_runtime
ctx = prepCtx(dt, target, cm);
end
function [ctx, b, a, trip] = stepSliced(ctx, dd_blk, dm_blk)
b = NaN; a = 1; trip = 0;
for i = 1:numel(dd_blk)
    [a, b, ~, ~, ~, trip] = fable_osi_runtime(dd_blk(i), dm_blk(i), 1, ...
        ctx.fbls, ctx.fblw, ctx.fblbins, ctx.fblfw, ctx.fblfbins, ...
        ctx.fblag, ctx.fbla);
end
end

function ctx = initBurst(dt, ~, target, cm)
clear reference_burst_runtime
ctx = prepCtx(dt, target, cm);
end
function [ctx, b, a, trip] = stepBurst(ctx, dd_blk, dm_blk)
b = NaN; a = 1; trip = 0;
for i = 1:numel(dd_blk)
    [a, b, ~, ~, ~, trip] = reference_burst_runtime(dd_blk(i), ...
        dm_blk(i), 1, ctx.fbls, ctx.fblw, ctx.fblbins, ctx.fblfw, ...
        ctx.fblfbins, ctx.fblag, ctx.fbla);
end
end

function ctx = prepCtx(dt, target, cm)
hs = struct('exp_tf_file', fullfile(cm.projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_7000_20260627_210411.mat'), ...
    'target_outer_ncf', target, 'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0, ...
    'fable_osi_override', setDefaults(cm.osi_override, ...
    struct('cal_skip_s', 6, 'cal_windows', 60)), ...
    'fable_auth_override', cm.auth_override);
ctx = prepare_fable_runtime(cm.projectFolder, dt, hs);
end

function s = setDefaults(s, d)
fn = fieldnames(d);
for i = 1:numel(fn)
    if ~isfield(s, fn{i}), s.(fn{i}) = d.(fn{i}); end
end
end

% ==========================================================================
function out = replayRecord(stepFcn, dd, dm, setup, sample_offset)
% stream a record; sample step outputs at the step boundary + offset
clear reference_burst_runtime fable_osi_runtime   % fresh persistents
step_n = setup.cfg.step_n;
n_step = floor(numel(dd)/step_n);
out = struct('b', NaN(n_step, 1), 'a', NaN(n_step, 1), ...
    'b_st', NaN(n_step, 1), 'b_fast', NaN(n_step, 1), ...
    'trip', zeros(n_step, 1));
k = 0;
N = n_step*step_n + sample_offset;
for i = 1:N
    if i <= numel(dd), du = dd(i); yu = dm(i); else, du = 0; yu = 0; end
    [a, b, b_st, ~, b_fast, trip] = stepFcn(du, yu, setup);
    if i > sample_offset && mod(i - sample_offset, step_n) == 0
        k = k + 1;
        out.b(k) = b;
        out.a(k) = a;
        out.b_st(k) = b_st;
        out.b_fast(k) = b_fast;
        out.trip(k) = trip;
    end
end
end

function [a, b, b_st, b_res, b_fast, trip] = refWrap(du, yu, setup)
[a, b, b_st, b_res, b_fast, trip] = reference_burst_runtime(du, yu, 1, ...
    setup.fbls, setup.fblw, setup.fblbins, setup.fblfw, setup.fblfbins, ...
    setup.fblag, setup.fbla);
end
function [a, b, b_st, b_res, b_fast, trip] = newWrap(du, yu, setup)
[a, b, b_st, b_res, b_fast, trip] = fable_osi_runtime(du, yu, 1, ...
    setup.fbls, setup.fblw, setup.fblbins, setup.fblfw, setup.fblfbins, ...
    setup.fblag, setup.fbla);
end

function d = maxDiffNaN(x, y)
nanmis = xor(isnan(x), isnan(y));
both = ~isnan(x) & ~isnan(y);
d = 0;
if any(nanmis), d = Inf; end
if any(both), d = max(d, max(abs(x(both) - y(both)))); end
end

% ==========================================================================
function plotSuiteCase(cn, co, target, figDir)
f = figure('Visible', 'off', 'Position', [50 50 1100 640]);
subplot(2, 1, 1)
plot(cn.sim.tc, cn.sim.b_true, 'k--', 'LineWidth', 1.8), hold on
plot(co.sim.tc, co.sim.b_est, '-', 'Color', '#AC6420', 'LineWidth', 1.4)
plot(cn.sim.tc, cn.sim.b_est, '-', 'Color', '#007CA8', 'LineWidth', 1.0)
yline(target, ':', 'Color', '#901500');
grid on, ylabel('margin b')
legend('true margin', 'pre-fix burst', 'time-sliced', 'target', ...
    'Location', 'best')
title(strrep(cn.name, '_', '\_'), 'Interpreter', 'tex')
subplot(2, 1, 2)
plot(co.sim.tc, co.sim.a, '-', 'Color', '#AC6420', 'LineWidth', 1.4), hold on
plot(cn.sim.tc, cn.sim.a, '-', 'Color', '#007CA8', 'LineWidth', 1.0)
to = co.sim.tc(co.sim.trip > 0);
tn = cn.sim.tc(cn.sim.trip > 0);
if ~isempty(to), plot(to, ones(size(to))*1.03, 'v', 'Color', '#AC6420'), end
if ~isempty(tn), plot(tn, ones(size(tn))*1.06, 'v', 'Color', '#007CA8'), end
grid on, ylim([0 1.1]), ylabel('authority a'), xlabel('time (s)')
legend('pre-fix burst', 'time-sliced', 'Location', 'best')
print(f, fullfile(figDir, ['suite_' cn.name '.png']), '-dpng', '-r110')
close(f)
end

function plotRecordCase(rec, figDir)
f = figure('Visible', 'off', 'Position', [50 50 1100 780]);
subplot(3, 1, 1)
plot(rec.t, rec.dm, '-', 'Color', '#007CA8')
grid on, ylabel('dm (mm)')
title(strrep(rec.name, '_', '\_'), 'Interpreter', 'tex')
subplot(3, 1, 2)
plot(rec.tc, rec.old.b, '-', 'Color', '#AC6420', 'LineWidth', 1.4), hold on
plot(rec.tc, rec.new.b, '-', 'Color', '#007CA8', 'LineWidth', 1.0)
grid on, ylabel('margin b')
legend('pre-fix burst', 'time-sliced', 'Location', 'best')
subplot(3, 1, 3)
plot(rec.tc, rec.old.a, '-', 'Color', '#AC6420', 'LineWidth', 1.4), hold on
plot(rec.tc, rec.new.a, '-', 'Color', '#007CA8', 'LineWidth', 1.0)
to = rec.tc(rec.old.trip > 0);
tn = rec.tc(rec.new.trip > 0);
if ~isempty(to), plot(to, ones(size(to))*1.03, 'v', 'Color', '#AC6420'), end
if ~isempty(tn), plot(tn, ones(size(tn))*1.06, 'v', 'Color', '#007CA8'), end
grid on, ylim([0 1.1]), ylabel('authority a'), xlabel('time (s)')
legend('pre-fix burst', 'time-sliced', 'Location', 'best')
print(f, fullfile(figDir, [rec.name '.png']), '-dpng', '-r110')
close(f)
end
