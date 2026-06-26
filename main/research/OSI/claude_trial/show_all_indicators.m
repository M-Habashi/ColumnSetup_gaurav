%% show_all_indicators -- run all six OSI methods and show an overview figure.
% Panel 1: the reference dd and the response dm over the analysis window.
% Panels 2-7: the estimated NCF-margin indicator from each method (M1..M6).
% Panel 8: zoom on the final collapse (M6 0.5 s resolution vs M3 10 s).

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

tags  = {'trial_1','trial_2','trial_3','trial_4','trial_5','trial_6'};
short = {'M1: nonparametric H1 (direct)', 'M2: parametric per-window', ...
         'M3: dd-instrument (recommended)', 'M4: nu-gap drift (early-warning)', ...
         'M5: recursive RLS tracker', 'M6: recursive freq-point Kalman (0.5 s)'};

% --- run every method (isolated workspace, silent) and load its result ---
S = cell(6,1);
for i = 1:6
    run_isolated(fullfile(this_dir, tags{i}, ['run_' tags{i} '.m']));
    Ld = load(fullfile(cfg.results_dir, [tags{i} '_result.mat']));
    S{i} = Ld.result;
end

% --- signals restricted to the analysis window (decimated for a light plot) ---
inWin = ctx.t >= cfg.t_start & ctx.t <= cfg.t_end;
tw = ctx.t(inWin); dd = ctx.dd(inWin); dm = ctx.dm(inWin);
stride = max(1, round(numel(tw)/6000));
ts = tw(1:stride:end); dds = dd(1:stride:end); dms = dm(1:stride:end);

% --- 4x2 overview figure ---
fig = figure('Color','w','Name','OSI overview','Position',[40 40 1280 940]);

ax1 = subplot(4,2,1);
plot(ax1, ts, dds, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.0, 'DisplayName','dd (reference)');
hold(ax1,'on');
plot(ax1, ts, dms, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.0, 'DisplayName','dm (response)');
grid(ax1,'on'); xlim(ax1,[cfg.t_start cfg.t_end]);
xlabel(ax1,'time (s)'); ylabel(ax1,'displacement (mm)');
title(ax1,'Reference dd and response dm'); legend(ax1,'Location','northwest');

for i = 1:6
    ax = subplot(4,2,i+1); r = S{i};
    if numel(r.tc) <= 30, style = {'-o','MarkerFaceColor','w'}; else, style = {'-'}; end
    plot(ax, r.tc, r.ncf, style{:}, 'Color',[0.20 0.30 0.55], 'LineWidth',1.6, ...
        'DisplayName','indicator'); hold(ax,'on');
    if isfield(r,'extra')
        for e = 1:numel(r.extra)
            plot(ax, r.tc, r.extra(e).data, '-', 'Color',[0.6 0.7 0.85], ...
                'LineWidth',0.7, 'DisplayName', r.extra(e).name);
        end
    end
    thr = cfg.ncf_threshold; if isfield(r,'threshold'), thr = r.threshold; end
    yline(ax, r.nominal, '--', 'nominal', 'Color',[0 0.45 0.74], 'HandleVisibility','off');
    yline(ax, thr, ':', 'threshold', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
    grid(ax,'on'); xlim(ax,[cfg.t_start cfg.t_end]);
    xlabel(ax,'time (s)'); ylabel(ax,'NCF margin'); title(ax, short{i});
end

% Panel 8: collapse zoom (M6 0.5 s vs M3 10 s)
axz = subplot(4,2,8); hold(axz,'on'); grid(axz,'on');
plot(axz, S{6}.tc, S{6}.ncf, '-o', 'Color',[0.10 0.20 0.55], 'LineWidth',1.6, ...
    'MarkerSize',3, 'DisplayName','M6 (0.5 s)');
plot(axz, S{3}.tc, S{3}.ncf, '-o', 'Color',[0.85 0.33 0.10], 'LineWidth',1.4, ...
    'MarkerFaceColor','w', 'MarkerSize',7, 'DisplayName','M3 (10 s)');
yline(axz, cfg.ncf_threshold, ':', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
xlim(axz,[758 770.1]); ylim(axz,[0 0.7]);
xlabel(axz,'time (s)'); ylabel(axz,'NCF margin');
title(axz,'Final-collapse zoom: M6 0.5 s vs M3 10 s'); legend(axz,'Location','southwest');

sgtitle(sprintf('OSI methods over %.0f-%.1f s   (blue dash = nominal, orange dot = threshold)', ...
    cfg.t_start, cfg.t_end), 'FontWeight','bold');

saveas(fig, fullfile(cfg.results_dir, 'all_indicators_overview.png'));
fprintf('Displayed overview (signals + M1..M6 + collapse zoom); saved all_indicators_overview.png\n');

%% ---- local function ----
function run_isolated(script)
    evalc(['run(''' script ''')']);
end
