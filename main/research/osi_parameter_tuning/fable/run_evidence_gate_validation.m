function out = run_evidence_gate_validation(opt_in)
%RUN_EVIDENCE_GATE_VALIDATION Validate the excitation-evidence arming gate.
%
% Replays selected records through the UNCHANGED fable_osi + fable_auth,
% on the echo-cleaned tap (where the echo dominates), and compares the
% authority with and without fable_evidence_gate in front of the law.
%
% What must hold:
%   1. RTHS_02: the ~5 s low-margin transient at loop engagement no longer
%      sheds authority (a = 1.0 through the start), steady-state behavior
%      unchanged, and the stale post-disengagement tail holds instead of
%      shedding.
%   2. RHTS_no_inst_butindicators_jump (closed loop, ~zero excitation, no
%      tracking): never arms -> authority never moves. This record's
%      "indicator jumps" disappear entirely.
%   3. RTHS_instability_during_eq / RTHS_instability_at_the_end: genuine
%      events still shed; report the extra delay (if any) introduced by
%      arming.
%   4. 20260630_1930 (open-loop control): behavior essentially unchanged
%      while excitation is present.
% Plus a theta / arm_s sweep on records 1 and 3 for robustness.

here = fileparts(mfilename('fullpath'));
proj = fileparts(fileparts(fileparts(here)));
addpath(fullfile(proj, 'OSI_tests', 'fable'))
figDir = fullfile(here, 'figures');
resDir = fullfile(here, 'results');

opt = struct('target', 0.55, 'gate', struct());
if nargin >= 1
    fn = fieldnames(opt_in);
    for i = 1:numel(fn), opt.(fn{i}) = opt_in.(fn{i}); end
end

E = load(fullfile(proj, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
dt0 = 1/2048;
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt0, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H = E.H_dc_dm; if get(H, 'Ts') == 0, H = c2d(H, dt0, 'zoh'); end
L0 = C*H;
PL = load(fullfile(proj, 'saved_results', 'phase_lead', 'fem3_ncf3.mat'));

imp = fullfile(proj, 'saved_results', 'tests', 'important');
tst = fullfile(proj, 'saved_results', 'tests', 'tsting_osi');
recs = { ...
  fullfile(imp, '20260625_1740_RTHS_02.mat'),            'clean', NaN;
  fullfile(tst, 'RHTS_no_inst_butindicators_jump.mat'),  'clean', NaN;
  fullfile(tst, 'RTHS_instability_during_eq.mat'),       'clean', 37.5;
  fullfile(tst, 'RTHS_instability_at_the_end.mat'),      'raw',   87.0;
  fullfile(imp, '20260630_1930_testing_OSI.mat'),        'raw',   NaN};
% 'clean' = echo dominant, subtract; 'raw' = leave as recorded.
% 3rd col = genuine-event onset (s) for shed-delay accounting (NaN = none).

out = struct('name', {}, 'tc', {}, 'b', {}, 'armed', {}, ...
    'a_ungated', {}, 'a_gated', {}, 'metrics', {});
for k = 1:size(recs, 1)
    [~, nm] = fileparts(recs{k, 1});
    fprintf('\n===== %s (%s tap) =====\n', nm, recs{k, 2});
    L = load(recs{k, 1});
    if isfield(L, 'result'), d = L.result; else, d = L; end
    clear L
    dd = d.dd(:); dm = d.dm(:); dt = d.dt; fs = 1/dt;
    if isfield(d, 't'), t = d.t(:); else, t = (1:numel(dd))'*dt; end

    u = dd;
    if strcmp(recs{k, 2}, 'clean')
        Gd = c2d(PL.phase_lead_tf, dt, 'tustin');
        [nb, na] = tfdata(Gd, 'v');
        echo = filter(nb, na, 1000*d.hs.interface_from_force*d.fm(:));
        mr = sqrt(movmean(dd.^2, round(fs)));
        thr = 0.05*prctile(mr(mr > 0), 95);
        eng = mr > max(thr, 1e-6);
        [bh, ah] = butter(4, 25/(fs/2), 'high');
        g = movmin(eng, round(fs));
        ddh = filtfilt(bh, ah, dd);
        ech = filtfilt(bh, ah, echo);
        s = ech(g)\ddh(g);
        u = dd - s*echo.*eng;
        fprintf('  echo scale %.3f\n', s);
    end

    run = fable_osi('run', u, dm, dt, L0, ...
        struct('threshold', opt.target, 'cal_skip_s', 12));

    gprm = fable_evidence_gate('params', opt.gate);
    [aU, ~] = authReplay(run, opt.target, [], [], u);
    [aG, armed] = authReplay(run, opt.target, gprm, ...
        fable_evidence_gate('state', gprm), u);

    m = gateMetrics(run, aU, aG, armed, t, u, fs, recs{k, 3}, opt.target);
    printMetrics(m);

    makeFig(figDir, nm, t, dm, run, aU, aG, armed, opt.target);
    out(end+1) = struct('name', nm, 'tc', run.tc, 'b', run.b, ...
        'armed', armed, 'a_ungated', aU, 'a_gated', aG, ...
        'metrics', m); %#ok<AGROW>
    clear d dd dm u t echo
end
save(fullfile(resDir, 'evidence_gate_validation.mat'), 'out', 'opt', ...
    '-v7.3');

% ---- robustness sweep on RTHS_02 + during_eq ------------------------------
fprintf('\n===== theta / arm_s sweep =====\n');
sweep = runSweep(recs, out, opt, L0, PL, proj);
save(fullfile(resDir, 'evidence_gate_validation.mat'), 'out', 'opt', ...
    'sweep', '-v7.3');
fprintf('saved %s\n', fullfile(resDir, 'evidence_gate_validation.mat'));
end

% ==========================================================================
function [a, armed] = authReplay(run, target, gprm, gst, u)
% authority replay; if gprm nonempty, the evidence gate sits between the
% OSI outputs and the law (slow margin only - trips pass through).
prm = fable_auth('params', struct('target', target, 'a_init', 1.0, ...
    'a_min', 0.08, 'dt_update', run.cfg.step_s));
ast = fable_auth('state', prm);
nU = numel(run.tc);
a = NaN(nU, 1);
armed = true(nU, 1);
step_n = run.cfg.step_n;
for k = 1:nU
    b = run.b(k);
    vu = run.st_valid(k);
    if ~isempty(gprm)
        i2 = min(k*step_n, numel(u));
        i1 = (k-1)*step_n + 1;
        [b, vu, armed(k), gst] = fable_evidence_gate(u(i1:i2), b, vu, ...
            gprm, gst);
    end
    st_binding = vu && (isnan(run.b_res(k)) || run.b_st(k) <= run.b_res(k));
    [ak, ast] = fable_auth(b, vu, run.trip_reason(k), run.b_fast(k), ...
        run.pred_margin(:, k), run.pred_valid(k) && armed(k), ...
        run.alpha_grid, ast, prm, st_binding, run.regime_recal(k));
    a(k) = ak;
end
end

% ==========================================================================
function m = gateMetrics(run, aU, aG, armed, t, u, fs, t_event, target)
% engagement time from u activity
mr = sqrt(movmean(u.^2, round(fs)));
thr = 0.05*max(prctile(mr(mr > 0), 95), 1e-9);
i_on = find(mr > thr, 1, 'first');
t_on = t(min(max(i_on, 1), numel(t)));
onset = run.tc >= t_on & run.tc <= t_on + 20;
m = struct();
m.t_on = t_on;
m.onset_amin_ungated = min([aU(onset); NaN]);
m.onset_amin_gated = min([aG(onset); NaN]);
m.full_a_ungated = 100*mean(aU >= 0.95);
m.full_a_gated = 100*mean(aG >= 0.95);
m.armed_pct = 100*mean(armed);
m.amin_ungated = min(aU);
m.amin_gated = min(aG);
m.shed_delay = NaN;
if isfinite(t_event)
    tu = run.tc(find(run.tc >= t_event & aU < 0.9, 1, 'first'));
    tg = run.tc(find(run.tc >= t_event & aG < 0.9, 1, 'first'));
    if ~isempty(tu) && ~isempty(tg)
        m.shed_t_ungated = tu;
        m.shed_t_gated = tg;
        m.shed_delay = tg - tu;
    end
end
end

function printMetrics(m)
fprintf(['  engage %.1f s | onset a_min: ungated %.2f  gated %.2f | ' ...
    'full-a %.0f%% -> %.0f%% | armed %.0f%%\n'], m.t_on, ...
    m.onset_amin_ungated, m.onset_amin_gated, m.full_a_ungated, ...
    m.full_a_gated, m.armed_pct);
if isfinite(m.shed_delay)
    fprintf('  genuine event: shed at %.1f s ungated vs %.1f s gated (delay %+.2f s)\n', ...
        m.shed_t_ungated, m.shed_t_gated, m.shed_delay);
end
end

% ==========================================================================
function sweep = runSweep(recs, out, opt, L0, PL, proj) %#ok<INUSD>
% theta / arm_s robustness on RTHS_02 (onset must not shed) and
% instability_during_eq (event shed delay)
sweep = struct('rec', {}, 'theta', {}, 'arm_s', {}, ...
    'onset_amin', {}, 'shed_delay', {}, 'armed_pct', {});
for k = [1 3]
    [~, nm] = fileparts(recs{k, 1});
    L = load(recs{k, 1});
    if isfield(L, 'result'), d = L.result; else, d = L; end
    clear L
    dd = d.dd(:); dt = d.dt; fs = 1/dt;
    if isfield(d, 't'), t = d.t(:); else, t = (1:numel(dd))'*dt; end
    Gd = c2d(PL.phase_lead_tf, dt, 'tustin');
    [nb, na] = tfdata(Gd, 'v');
    echo = filter(nb, na, 1000*d.hs.interface_from_force*d.fm(:));
    mr = sqrt(movmean(dd.^2, round(fs)));
    thr = 0.05*prctile(mr(mr > 0), 95);
    eng = mr > max(thr, 1e-6);
    [bh, ah] = butter(4, 25/(fs/2), 'high');
    g = movmin(eng, round(fs));
    ddh = filtfilt(bh, ah, dd); ech = filtfilt(bh, ah, echo);
    s = ech(g)\ddh(g);
    u = dd - s*echo.*eng;

    % rebuild the full OSI run once per record (the sweep only re-gates)
    full = fable_osi('run', u, d.dm(:), dt, L0, ...
        struct('threshold', opt.target, 'cal_skip_s', 12));
    aU_ref = out(k).a_ungated;
    for th = [0.03 0.05 0.08]
        for as_ = [5 6 8]
            gprm = fable_evidence_gate('params', ...
                struct('theta_mm', th, 'arm_s', as_));
            [aG, armed] = authReplayLocal(full, opt.target, gprm, u);
            m = gateMetrics(full, aU_ref, aG, armed, t, u, fs, ...
                eventOf(nm), opt.target);
            sweep(end+1) = struct('rec', nm, 'theta', th, ...
                'arm_s', as_, 'onset_amin', m.onset_amin_gated, ...
                'shed_delay', m.shed_delay, ...
                'armed_pct', m.armed_pct); %#ok<AGROW>
            fprintf('  %-28s theta %.2f arm %d: onset a_min %.2f, shed delay %+5.2f s, armed %3.0f%%\n', ...
                nm, th, as_, m.onset_amin_gated, m.shed_delay, ...
                m.armed_pct);
        end
    end
    clear d u echo
end
end

function te = eventOf(nm)
if contains(nm, 'during_eq'), te = 37.5; else, te = NaN; end
end

function [a, armed] = authReplayLocal(run, target, gprm, u)
[a, armed] = authReplay(run, target, gprm, ...
    fable_evidence_gate('state', gprm), u);
end

% ==========================================================================
function makeFig(figDir, nm, t, dm, run, aU, aG, armed, target)
ink = [11 11 11]/255; muted = [120 118 112]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; red = [204 74 59]/255; aqua = [27 175 122]/255;
amber = [237 161 0]/255;

fig = figure('Color', 'w', 'Position', [40 40 1150 760], 'Visible', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot(ax1, t(1:8:end), dm(1:8:end), '-', 'Color', [blue 0.8], ...
    'LineWidth', 0.4)
ylabel(ax1, 'dm (mm)')
title(ax1, sprintf('%s - evidence-gated authority (theta %s)', nm, ...
    'default 0.05 mm / 6 s'), 'Interpreter', 'none', 'Color', ink, ...
    'FontSize', 10)
styleAx(ax1, grid_c, muted, ink)

ax2 = nexttile;
hold(ax2, 'on')
shadeArmed(ax2, run.tc, armed, [0.92 0.97 0.94])
yline(ax2, target, ':', 'Color', muted)
plot(ax2, run.tc, run.b, '-', 'Color', ink, 'LineWidth', 1.1)
ylabel(ax2, 'OSI margin (cleaned tap)')
ylim(ax2, [0 0.75])
legend(ax2, {'armed (evidence present)', 'target', 'margin'}, ...
    'Location', 'southwest', 'Box', 'off', 'FontSize', 8)
styleAx(ax2, grid_c, muted, ink)

ax3 = nexttile;
hold(ax3, 'on')
shadeArmed(ax3, run.tc, armed, [0.92 0.97 0.94])
stairs(ax3, run.tc, aU, '-', 'Color', [red 0.9], 'LineWidth', 1.2)
stairs(ax3, run.tc, aG, '-', 'Color', aqua, 'LineWidth', 1.5)
ylabel(ax3, 'authority a')
xlabel(ax3, 'time (s)')
ylim(ax3, [0 1.05])
legend(ax3, {'armed', 'ungated law', 'evidence-gated law'}, ...
    'Location', 'southwest', 'Box', 'off', 'FontSize', 8)
styleAx(ax3, grid_c, muted, ink)

linkaxes([ax1 ax2 ax3], 'x')
xlim(ax1, [t(1) t(end)])
png = fullfile(figDir, ['gate_' nm '.png']);
exportgraphics(fig, png, 'Resolution', 130)
close(fig)
fprintf('  figure: %s\n', png);
end

function shadeArmed(ax, tc, armed, c)
d = diff([false; armed(:); false]);
i0 = find(d == 1); i1 = find(d == -1) - 1;
for j = 1:numel(i0)
    x = [tc(i0(j)) tc(i1(j))];
    patch(ax, [x(1) x(2) x(2) x(1)], [0 0 1.05 1.05], c, ...
        'EdgeColor', 'none', 'FaceAlpha', 1, 'HandleVisibility', ...
        ternary(j == 1, 'on', 'off'));
end
end

function y = ternary(c, a, b)
if c, y = a; else, y = b; end
end

function styleAx(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9, 'Layer', 'top')
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
end
