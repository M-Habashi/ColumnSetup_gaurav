function results = run_adaptive_study(overrides)
%RUN_ADAPTIVE_STUDY  Adaptive-PID study: 5 methods x 5 cases, driven by M9.1 NCF margin.
% For every case it runs the no-adaptation baseline and each adaptive method, using the
% canonical OSI estimator m91_adaptive_margin (STEP mode) as the online margin signal
% and the asymmetric margin_law to hold that margin at/above cfg.b_target (default 0.5).
%
% Produces, per method, a figure with (top) the adapted PARAMETER vs time and (bottom)
% the NCF margin WITH the method vs WITHOUT it (baseline), for all 5 cases; plus a
% summary scorecard figure and a console table. Saves PNGs + results.mat to results/.
%
%   results = run_adaptive_study();                      % defaults from adaptive_config
%   results = run_adaptive_study(struct('b_target',0.55))% override any config field

if nargin < 1, overrides = struct(); end
cfg = adaptive_config(overrides);
addpath(cfg.dir);
[cases, ctx] = load_adaptive_ctx(cfg);
M = adaptive_methods();
if ~exist(cfg.results,'dir'), mkdir(cfg.results); end

nC = numel(cases); nM = numel(M);
R = cell(nC, nM);                         % R{case, method} = simulate output
fprintf('Running %d cases x %d methods ...\n', nC, nM-1);
tic;
for ci = 1:nC
    for mi = 1:nM
        R{ci,mi} = simulate_adaptive_case(cases(ci), M(mi), ctx, cfg);
    end
    fprintf('  %s done (%.0fs)\n', cases(ci).id, toc);
end
results = struct('cfg',cfg,'cases',{cases},'methods',M,'R',{R},'ctx_bnom',R{1,1}.bnom);

% ---------- colors / style ----------
cW=[0.00 0.45 0.74]; cWt=[0.30 0.65 0.90];      % with-method: M9.1 (dark) / true (light)
cB=[0.45 0.45 0.45]; cP1=[0.85 0.33 0.10]; cP2=[0.20 0.60 0.25];
tgt=cfg.b_target; thr=cfg.m91.threshold; sw=cfg.switch_s;

% ===================== one figure per method =====================
for mi = 2:nM
    f = figure('Color','w','Position',[60 60 1500 560], ...
        'Name',sprintf('%s — %s',M(mi).id,M(mi).name));
    tl = tiledlayout(f,2,nC,'TileSpacing','compact','Padding','compact');
    for ci = 1:nC
        o = R{ci,mi}; ob = R{ci,1};
        % --- top: parameter(s) ---
        ax = nexttile(tl, ci); hold(ax,'on'); grid(ax,'on');
        plot_params(ax, o, M(mi).kind, cP1, cP2, ci==1);
        xline(ax,sw,'--','Color',[0.6 0 0],'HandleVisibility','off');
        title(ax, sprintf('%s  %s', cases(ci).id, short(cases(ci).name)),'FontWeight','normal');
        if ci==1, ylabel(ax,'parameter'); end
        xlim(ax,[0 cfg.dur_s]);
        % --- bottom: margin with vs without ---
        ax2 = nexttile(tl, nC+ci); hold(ax2,'on'); grid(ax2,'on');
        hb1=plot(ax2, ob.tc, ob.m91, '-', 'Color',cB,'LineWidth',1.4);
        hb2=plot(ax2, ob.tc, ob.true,'--','Color',cB,'LineWidth',1.0);
        hw1=plot(ax2, o.tc,  o.m91,  '-', 'Color',cW,'LineWidth',1.9);
        hw2=plot(ax2, o.tc,  o.true, '--','Color',cWt,'LineWidth',1.3);
        ht =yline(ax2,tgt,':','Color',cP2,'LineWidth',1.3);
        hh =yline(ax2,thr,':','Color',[0.8 0 0],'LineWidth',1.0);
        xline(ax2,sw,'--','Color',[0.6 0 0],'HandleVisibility','off');
        ylim(ax2,[0 0.72]); xlim(ax2,[0 cfg.dur_s]);
        if ci==1, ylabel(ax2,'NCF margin'); end
        xlabel(ax2,'time (s)');
        legH = [hb1 hb2 hw1 hw2 ht hh];
    end
    lg = legend(legH, {'M9.1 baseline','true baseline','M9.1 w/ method','true w/ method', ...
        sprintf('target %.2f',tgt),'threshold'}, 'Orientation','horizontal');
    lg.Layout.Tile = 'south';
    title(tl, sprintf('%s  (%s).   Top: adapted parameter.   Bottom: NCF margin with vs without.', ...
        M(mi).name, M(mi).note), 'FontWeight','bold');
    png = fullfile(cfg.results, sprintf('method_%s.png', M(mi).id));
    exportgraphics(f, png, 'Resolution',130);
    fprintf('saved %s\n', png);
end

% ===================== summary scorecard =====================
em = @(o) o.tc > cfg.dur_s - 6;            % last 6 s = converged damaged phase
trueEnd = zeros(nC,nM); m91End = zeros(nC,nM);
for ci = 1:nC
    for mi = 1:nM
        o = R{ci,mi};
        trueEnd(ci,mi) = mean(o.true(em(o)),'omitnan');
        m91End(ci,mi)  = mean(o.m91(em(o)),'omitnan');
    end
end

fs2 = figure('Color','w','Position',[80 80 1300 520],'Name','Scorecard');
tl2 = tiledlayout(fs2,1,2,'TileSpacing','compact','Padding','compact');
labels = {M.id}; barcols = lines(nM);
for p=1:2
    ax=nexttile(tl2,p);
    if p==1, data=trueEnd; ttl='True NCF margin (converged)'; else, data=m91End; ttl='M9.1 estimate (converged)'; end
    b=bar(ax, categorical({cases.id}), data); for k=1:nM, b(k).FaceColor=barcols(k,:); end
    hold(ax,'on'); yline(ax,tgt,'--','Color',cP2,'LineWidth',1.5,'Label','target 0.50');
    yline(ax,thr,':','Color',[0.8 0 0]); grid(ax,'on'); ylim(ax,[0 0.72]);
    ylabel(ax,'NCF margin'); title(ax,ttl);
    if p==2, legend(ax, labels,'Location','northoutside','Orientation','horizontal'); end
end
title(tl2,'Adaptive-PID scorecard: converged margin by case and method (vs baseline)','FontWeight','bold');
exportgraphics(fs2, fullfile(cfg.results,'scorecard.png'),'Resolution',130);
fprintf('saved %s\n', fullfile(cfg.results,'scorecard.png'));

% ---------- console table ----------
fprintf('\n================  CONVERGED MARGIN  (target %.2f)  ================\n', tgt);
fprintf('M9.1 estimate (and [true NCF]) over the last 6 s of the damaged phase.\n');
fprintf('* = TRUE margin held at/above target (the real safety goal).\n\n');
fprintf('%-4s %-22s', 'id','case');
for mi=1:nM, fprintf(' | %-13s', M(mi).id); end
fprintf('\n');
for ci=1:nC
    fprintf('%-4s %-22s', cases(ci).id, short(cases(ci).name));
    for mi=1:nM
        mk = ' '; if trueEnd(ci,mi)>=tgt, mk='*'; end
        fprintf(' | %.2f[%.2f]%-1s', m91End(ci,mi), trueEnd(ci,mi), mk);
    end
    fprintf('\n');
end
fprintf(['\nbaseline = no adaptation.  M1 authority, M2 integral detune, M3 low-pass,\n' ...
    'M4 scheduled, M5 authority+notch.  On the low-frequency cases C4 (~20 Hz) and\n' ...
    'C5 (~2.5 Hz) the M9.1 ESTIMATE saturates near 0.5 even at full safe authority --\n' ...
    'its known low-frequency conservatism -- so the true margin parks at 0.59-0.66\n' ...
    '(a built-in safety factor) while the indicator reads ~0.5.\n']);

save(fullfile(cfg.results,'adaptive_results.mat'),'results','trueEnd','m91End','-v7.3');
results.trueEnd=trueEnd; results.m91End=m91End;
fprintf('\nSaved results to %s\n', fullfile(cfg.results,'adaptive_results.mat'));
end

% ===================== helpers =====================
function plot_params(ax, o, kind, c1, c2, showleg)
lg = {};
switch kind
    case 'authority'
        plot(ax,o.tc,o.a,'-','Color',c1,'LineWidth',1.8); ylim(ax,[0 1.05]);
        lg = {'a (authority)'};
    case 'integral'
        plot(ax,o.tc,o.gI,'-','Color',c1,'LineWidth',1.8); ylim(ax,[0 1.05]);
        lg = {'g_I (integral scale)'};
    case 'lowpass'
        plot(ax,o.tc,o.fc,'-','Color',c1,'LineWidth',1.8);
        ylabel(ax,'f_c [Hz]'); ylim(ax,[0 130]);
        lg = {'f_c cutoff (gap = off)'};
    case 'schedule'
        plot(ax,o.tc,o.a,'-','Color',c1,'LineWidth',1.8);
        plot(ax,o.tc,o.gI,'-','Color',c2,'LineWidth',1.8); ylim(ax,[0 1.05]);
        lg = {'a','g_I'};
        if ~strcmp(o.route,'none'), text(ax,0.04,0.13,['route: ' o.route],'Units','normalized','FontSize',8); end
    case 'auth_notch'
        plot(ax,o.tc,o.a,'-','Color',c1,'LineWidth',1.8);
        plot(ax,o.tc,o.depth,'-','Color',c2,'LineWidth',1.8); ylim(ax,[0 1.05]);
        lg = {'a','notch depth'};
end
if showleg && ~isempty(lg), legend(ax,lg,'Location','southwest','FontSize',8); end
end

function s = short(name)
s = name; if numel(s)>17, s = s(1:17); end
end
