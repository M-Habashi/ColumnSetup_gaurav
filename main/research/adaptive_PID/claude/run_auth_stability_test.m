function results = run_auth_stability_test(overrides)
%RUN_AUTH_STABILITY_TEST Test the canonical adaptive-PID stability law on the 5 OSI cases.
% Drives a single authority scalar a in [a_min, a_max] (applied after a fixed PID) with the
% codegen-safe law control_and_HS/OSI/auth_stability_gain.m, fed by the online OSI margin
% control_and_HS/OSI/m91_adaptive_margin.m (STEP mode) updated every cfg.update_interval_s
% (default 0.05 s). For every one of the 5 osi_test_cases it runs a no-adaptation baseline
% and the adaptive law, then plots authority(t) and the NCF margin (M9.1 estimate + analytic
% true) WITH vs WITHOUT adaptation, prints a converged-margin table, and saves a PNG + .mat
% to results/.
%
%   results = run_auth_stability_test();                          % defaults (update 0.05 s)
%   results = run_auth_stability_test(struct('update_interval_s',0.01))  % faster OSI update
%   results = run_auth_stability_test(struct('seed',7))           % different excitation draw
%
% The real safety goal is the TRUE margin: a case "passes" when the true NCF margin in the
% converged damaged phase is at/above target (marked * in the table), with no false
% adaptation on the healthy case C1 (authority must stay ~1).

if nargin < 1, overrides = struct(); end
here = fileparts(mfilename('fullpath'));
cfg  = auth_config(here, overrides);

addpath(cfg.osi); addpath(genpath(cfg.osi)); addpath(cfg.optdir);
[cases, ctx] = load_adaptive_ctx(cfg);
if ~exist(cfg.results,'dir'), mkdir(cfg.results); end

nC = numel(cases);
R = cell(nC, 2);                         % R{case,1}=baseline, R{case,2}=adaptive
fprintf('auth_stability_gain test: %d cases x {baseline, adaptive}, OSI update %.0f ms ...\n', ...
    nC, 1000*cfg.update_interval_s);
tic;
for ci = 1:nC
    R{ci,1} = simulate_auth_case(cases(ci), ctx, cfg, false);
    R{ci,2} = simulate_auth_case(cases(ci), ctx, cfg, true);
    fprintf('  %s done (%.0fs)\n', cases(ci).id, toc);
end
ui_actual = R{1,1}.update_interval_s;
results = struct('cfg',cfg,'cases',{cases},'R',{R},'bnom',R{1,1}.bnom, ...
    'update_interval_actual_s',ui_actual);

% ---------- colors / style ----------
cW=[0.00 0.45 0.74]; cWt=[0.30 0.65 0.90];      % adaptive: M9.1 (dark) / true (light)
cB=[0.45 0.45 0.45]; cA=[0.85 0.33 0.10];       % baseline grey / authority orange
tgt=cfg.law.target_margin; thr=cfg.m91.threshold; sw=cfg.switch_s;

% ===================== one figure: authority (top) + margin (bottom) per case =========
f = figure('Color','w','Position',[60 60 1500 560], ...
    'Name',sprintf('auth_stability_gain @ %.0f ms',1000*ui_actual));
tl = tiledlayout(f,2,nC,'TileSpacing','compact','Padding','compact');
for ci = 1:nC
    oA = R{ci,2}; oB = R{ci,1};
    % --- top: authority a(t) ---
    ax = nexttile(tl, ci); hold(ax,'on'); grid(ax,'on');
    plot(ax, oA.tc, oA.a, '-', 'Color',cA,'LineWidth',1.8);
    yline(ax, cfg.law.a_min, ':','Color',[0.5 0.5 0.5],'HandleVisibility','off');
    xline(ax, sw, '--','Color',[0.6 0 0],'HandleVisibility','off');
    title(ax, sprintf('%s  %s', cases(ci).id, short(cases(ci).name,17)),'FontWeight','normal');
    ylim(ax,[0 1.05]); xlim(ax,[0 cfg.dur_s]);
    if ci==1, ylabel(ax,'authority a'); legend(ax,{'a'},'Location','southwest','FontSize',8); end
    % --- bottom: NCF margin, with vs without ---
    ax2 = nexttile(tl, nC+ci); hold(ax2,'on'); grid(ax2,'on');
    hb1=plot(ax2, oB.tc, oB.m91, '-', 'Color',cB,'LineWidth',1.4);
    hb2=plot(ax2, oB.tc, oB.true,'--','Color',cB,'LineWidth',1.0);
    hw1=plot(ax2, oA.tc, oA.m91, '-', 'Color',cW,'LineWidth',1.9);
    hw2=plot(ax2, oA.tc, oA.true,'--','Color',cWt,'LineWidth',1.3);
    ht =yline(ax2,tgt,':','Color',[0.20 0.60 0.25],'LineWidth',1.3);
    hh =yline(ax2,thr,':','Color',[0.8 0 0],'LineWidth',1.0);
    xline(ax2,sw,'--','Color',[0.6 0 0],'HandleVisibility','off');
    ylim(ax2,[0 0.72]); xlim(ax2,[0 cfg.dur_s]);
    if ci==1, ylabel(ax2,'NCF margin'); end
    xlabel(ax2,'time (s)');
    legH = [hb1 hb2 hw1 hw2 ht hh];
end
lg = legend(legH, {'M9.1 baseline','true baseline','M9.1 adaptive','true adaptive', ...
    sprintf('target %.2f',tgt),'threshold'}, 'Orientation','horizontal');
lg.Layout.Tile = 'south';
title(tl, sprintf(['Canonical adaptive PID: auth\\_stability\\_gain driven by M9.1 ' ...
    '(OSI update %.0f ms).   Top: authority a.   Bottom: NCF margin with vs without.'], ...
    1000*ui_actual), 'FontWeight','bold');
png = fullfile(cfg.results,'auth_stability_test.png');
exportgraphics(f, png, 'Resolution',130);
fprintf('saved %s\n', png);

% ===================== converged-margin table ========================================
em = @(o) o.tc > cfg.dur_s - 6;          % last 6 s = converged damaged phase
trueB=zeros(nC,1); trueA=zeros(nC,1); m91A=zeros(nC,1); aEnd=zeros(nC,1); m91B=zeros(nC,1);
for ci=1:nC
    oB=R{ci,1}; oA=R{ci,2};
    trueB(ci)=mean(oB.true(em(oB)),'omitnan');  m91B(ci)=mean(oB.m91(em(oB)),'omitnan');
    trueA(ci)=mean(oA.true(em(oA)),'omitnan');  m91A(ci)=mean(oA.m91(em(oA)),'omitnan');
    aEnd(ci) =mean(oA.a(em(oA)),'omitnan');
end
results.trueBase=trueB; results.trueAdapt=trueA; results.m91Adapt=m91A; results.aEnd=aEnd;

fprintf('\n=========  auth_stability_gain @ %.1f ms  —  converged margin (last 6 s)  =========\n', ...
    1000*ui_actual);
fprintf('TRUE = analytic NCF of the live loop (the real safety goal).  target = %.2f.\n', tgt);
fprintf('* = TRUE adaptive margin held at/above target.\n\n');
fprintf('%-4s %-22s | %-9s %-9s | %-9s %-9s | %-7s\n', ...
    'id','case','trueBase','m91Base','trueAdpt','m91Adpt','a_end');
fprintf('%s\n', repmat('-',1,78));
for ci=1:nC
    mk=' '; if trueA(ci)>=tgt, mk='*'; end
    fprintf('%-4s %-22s |  %.2f      %.2f    |  %.2f%s     %.2f    |  %.2f\n', ...
        cases(ci).id, short(cases(ci).name,22), trueB(ci), m91B(ci), trueA(ci), mk, m91A(ci), aEnd(ci));
end
nPass = nnz(trueA(2:end) >= tgt);          % C2..C5 are the damaged cases that must be held
c1_noFalse = abs(aEnd(1)-cfg.law.a_max) < 0.02;
fprintf('%s\n', repmat('-',1,78));
fprintf(['Held %d/4 damaged cases (C2-C5) at/above target.  C1 false-adaptation check: ' ...
    'a_end=%.2f (%s).\n'], nPass, aEnd(1), ternary(c1_noFalse,'OK, no false alarm','MOVED'));
fprintf(['Note: on the low-binding-freq cases C4 (~20 Hz) and C5 (~2.5 Hz) the M9.1 ESTIMATE\n' ...
    'is conservative and parks near %.2f even at safe authority, while the TRUE margin sits\n' ...
    'higher (a built-in safety factor).\n'], tgt);

save(fullfile(cfg.results,'auth_stability_test.mat'),'results','-v7.3');
fprintf('\nSaved results to %s\n', fullfile(cfg.results,'auth_stability_test.mat'));
end

% ===================== config + helpers ==============================================
function cfg = auth_config(here, overrides)
%AUTH_CONFIG Parametric setup for the auth_stability_gain test (the "parametric file").
ui = 0.05;                       % <-- OSI update interval under test (s)
cfg = struct();
% scenario (healthy -> case JUMP, same convention as the OSI/adaptive-PID work)
cfg.switch_s      = 13;          % time of the healthy->damaged jump (after M9.1 calibrates)
cfg.dur_s         = 48;          % total record length (35 s of damaged adaptation)
cfg.crossfade_s   = 0.10;        % raised-cosine blend at the jump (state-continuous splice)
cfg.cmd_band_hz   = [2 100];     % broadband command so M9.1's S,T branch is excited
cfg.cmd_std_mm    = 1.0;         % command (dd_lead) amplitude [mm]
cfg.meas_noise_fr = 0.01;        % sensor noise as a fraction of dm std
cfg.seed          = 11;          % rng seed for command + disturbance (shared by both runs)
cfg.update_interval_s = ui;      % OSI margin update interval (the thing under test)

% M9.1 (canonical OSI function) overrides -- valid fields of the CURRENT function only.
cfg.m91 = struct('window_s',5,'threshold',0.40,'cap',0.70);

% authority law (auth_stability_gain) parameters. Asymmetric: drop fast when the margin is
% low, give authority back slowly only once safely above target+up_deadband.
cfg.law = struct( ...
  'target_margin',        0.50, ...   % hold the M9.1-indicated NCF margin at/above this
  'update_interval_s',    ui,   ...   % must equal the OSI update interval (up_hold conversion)
  'a_min',                0.12, ...   % authority floor (a:1 -> a_min)
  'a_max',                1.00, ...   % nominal authority
  'down_deadband',        0.005, ...  % below target-this counts as "low"
  'down_rate',            0.03, ...   % max downward step of a per update (rate limit)
  'down_immediate_margin',0.40, ...   % margin <= this is SEVERE -> act without confirmation
  'down_confirm_n',       3,    ...   % consecutive low windows to confirm a non-severe dip
  'up_deadband',          0.12, ...   % only give back when guarded margin > target+this
  'power_law',            2.0,  ...   % desired = a*(margin/target)^power_law on a confirmed dip
  'smooth_down',          0.5,  ...   % blend toward the power-law desired
  'up_rate',              0.01, ...   % max upward (give-back) step of a
  'up_hold_s',            0.5,  ...   % dwell safely-above before each give-back step
  'margin_guard_up_rate', 0.01, ...   % guarded-margin slew up
  'margin_guard_down_rate',0.02, ...  % guarded-margin slew down
  'margin_filter_alpha',  0.2);       % EMA on the reported filtered margin (telemetry only)

% project paths (self-locating)
cfg.dir    = here;
cfg.main   = fileparts(fileparts(fileparts(here)));   % .../main
cfg.osi    = fullfile(cfg.main,'control_and_HS','OSI');
cfg.optdir = fullfile(cfg.main,'research','optimizing_pl','claude');  % osi_test_cases
cfg.results= fullfile(here,'results');

if nargin >= 2 && ~isempty(overrides)
    fn = fieldnames(overrides);
    for i = 1:numel(fn), cfg.(fn{i}) = overrides.(fn{i}); end
end
cfg.law.update_interval_s = cfg.update_interval_s;     % keep law + OSI interval in lockstep
end

function s = short(name, n)
s = name; if numel(s) > n, s = s(1:n); end
end

function v = ternary(c, a, b), if c, v=a; else, v=b; end, end
