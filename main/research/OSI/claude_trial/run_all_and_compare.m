%% run_all_and_compare -- run all six OSI trials, compare, and Kalman-smooth.
% Produces: comparison.png, method6_vs_others.png, comparison_table.csv,
% comparison_metrics.csv, comparison_results.mat in claude_trial/results.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

tags    = {'trial_1','trial_2','trial_3','trial_4','trial_5','trial_6'};
labels  = {'M1 H1-direct','M2 parametric','M3 dd-instrument', ...
           'M4 nu-gap drift','M5 RLS','M6 freq-KF (0.5s)'};
nM = numel(tags);
runtime = zeros(nM,1);
S = cell(nM,1);
for i = 1:nM
    script = fullfile(this_dir, tags{i}, ['run_' tags{i} '.m']);
    runtime(i) = time_run(script);                       % isolated workspace + timed
    Ld = load(fullfile(cfg.results_dir, [tags{i} '_result.mat']));
    S{i} = Ld.result;
end
tc = ctx.tc; nW = ctx.nW;                                % 10 s grid (M1..M5)

% --- comparable loop-only NCF matrix (M1,M2,M3,M5); M4 & M6 kept separate ---
loop_idx = [1 2 3 5];
NCF = nan(nW, numel(loop_idx));
for j = 1:numel(loop_idx), NCF(:,j) = S{loop_idx(j)}.ncf; end
m4_bpred = S{4}.ncf;  m4_drift = S{4}.extra(1).data;  m4_base = S{4}.nominal;
tc6 = S{6}.tc;  ncf6 = S{6}.ncf;                          % Method 6 fine grid (0.5 s)

% --- Kalman post-smoothing (random-walk KF + RTS) on the loop-only series ---
NCF_kf = nan(size(NCF));
for j = 1:numel(loop_idx)
    [~, NCF_kf(:,j)] = osi_apply_kf(NCF(:,j), cfg.kf_q, cfg.kf_r);
end
[~, m3_smooth] = osi_apply_kf(S{3}.ncf, cfg.kf_q, cfg.kf_r);   % recommended = M3

% --- summary metrics (M1..M5 on common 10 s grid) ---
stable = tc <= 700; thr = cfg.ncf_threshold;
Method = labels(1:5).';
StartNCF = nan(5,1); EndNCF = nan(5,1); StableMean = nan(5,1);
StableStd = nan(5,1); Jitter = nan(5,1); DetectRaw = nan(5,1); DetectKF = nan(5,1);
for i = 1:5
    s = S{i}.ncf;
    StartNCF(i) = s(1); EndNCF(i) = s(end);
    StableMean(i) = mean(s(stable), 'omitnan');
    StableStd(i)  = std(s(stable), 'omitnan');
    Jitter(i)     = mean(abs(diff(s(stable))), 'omitnan');
    if i == 4
        DetectRaw(i) = first_cross(m4_drift, m4_base, tc, true);
        DetectKF(i)  = DetectRaw(i);
    else
        [~, sm] = osi_apply_kf(s, cfg.kf_q, cfg.kf_r);
        DetectRaw(i) = first_cross(s, thr, tc, false);
        DetectKF(i)  = first_cross(sm, thr, tc, false);
    end
end
Runtime_s = runtime(1:5);
metrics = table(Method, StartNCF, StableMean, StableStd, Jitter, EndNCF, ...
    DetectRaw, DetectKF, Runtime_s);
metrics.Properties.VariableNames{7} = 'DetectRaw_s';
metrics.Properties.VariableNames{8} = 'DetectKF_s';

% --- append Method 6 (its own 0.5 s grid) ---
st6 = tc6 <= 700;
m6row = table(labels(6), ncf6(1), mean(ncf6(st6)), std(ncf6(st6)), ...
    mean(abs(diff(ncf6(st6)))), ncf6(end), S{6}.detect_time, S{6}.detect_time, runtime(6), ...
    'VariableNames', metrics.Properties.VariableNames);
metrics = [metrics; m6row];

fprintf('\n================ OSI METHOD COMPARISON ================\n');
fprintf('nominal loop-only NCF = %.4f ; true b0 = %.4f ; threshold = %.2f\n', ...
    ctx.nom_ncf, ctx.nom_bexact, thr);
fprintf('(M1-M5: 10 s windows, 15 samples ; M6: 0.5 s updates, %d samples)\n', numel(tc6));
disp(metrics);

R = corrcoef(NCF, 'Rows', 'pairwise');
fprintf('Pairwise correlation of loop-only series (M1,M2,M3,M5):\n');
disp(array2table(R, 'VariableNames', labels(loop_idx), 'RowNames', labels(loop_idx)));

% --- saved tables ---
T = table(tc, NCF(:,1), NCF(:,2), NCF(:,3), NCF(:,4), m4_bpred, m3_smooth, ...
    'VariableNames', {'time_s','M1','M2','M3','M5','M4_bpred','M3_KFsmooth'});
writetable(T, fullfile(cfg.results_dir, 'comparison_table.csv'));
writetable(table(tc6, ncf6, S{6}.extra(1).data, ...
    'VariableNames', {'time_s','M6','M6_raw'}), ...
    fullfile(cfg.results_dir, 'comparison_table_method6.csv'));
writetable(metrics, fullfile(cfg.results_dir, 'comparison_metrics.csv'));

% --- figure 1: 5-method comparison (loop methods + M4 drift) ---
fig = figure('Visible','off','Color','w','Position',[80 80 980 760]);
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
co = lines(4);
for j = 1:numel(loop_idx)
    plot(ax1, tc, NCF(:,j), '-o', 'Color', co(j,:), 'LineWidth', 1.3, ...
        'MarkerSize', 4, 'DisplayName', labels{loop_idx(j)});
end
plot(ax1, tc6, ncf6, '-', 'Color', [0.45 0 0.55], 'LineWidth', 1.1, ...
    'DisplayName', 'M6 freq-KF (0.5 s)');
plot(ax1, tc, m3_smooth, 'k-', 'LineWidth', 2.2, 'DisplayName', 'M3 + Kalman smoother');
yline(ax1, ctx.nom_ncf, '--', 'nominal', 'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
yline(ax1, thr, ':', 'threshold 0.40', 'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
xlabel(ax1,'time (s)'); ylabel(ax1,'loop-only NCF margin');
title(ax1,'Online NCF stability indicator -- all loop-only methods'); ylim(ax1,[0 0.8]);
legend(ax1,'Location','southwest','NumColumns',2);

ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
yyaxis(ax2,'left');
plot(ax2, tc, m4_drift, '-s', 'LineWidth', 1.6, 'DisplayName', 'nu-gap drift vs start');
yline(ax2, m4_base, '--', 'baseline margin', 'Color', [0 0.45 0.74], ...
    'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
ylabel(ax2,'nu-gap drift'); ylim(ax2,[0 1]);
yyaxis(ax2,'right');
plot(ax2, tc, m4_bpred, '-^', 'LineWidth', 1.6, 'DisplayName', 'predicted margin b0-drift');
yline(ax2, 0, ':', 'instability bound', 'Color', [0.85 0.33 0.10], ...
    'LabelHorizontalAlignment', 'right', 'HandleVisibility', 'off');
ylabel(ax2,'predicted margin'); xlabel(ax2,'time (s)');
title(ax2,'Method 4 -- model-reference drift early-warning'); legend(ax2,'Location','west');
saveas(fig, fullfile(cfg.results_dir, 'comparison.png')); close(fig);

% --- figure 2: Method 6 (fast) vs the 10 s methods + collapse zoom ---
fig2 = figure('Visible','off','Color','w','Position',[80 80 980 760]);
bx1 = subplot(2,1,1); hold(bx1,'on'); grid(bx1,'on');
plot(bx1, tc6, S{6}.extra(1).data, '-', 'Color',[0.75 0.8 0.92], 'LineWidth',0.7, ...
    'DisplayName','M6 raw (0.5 s)');
plot(bx1, tc6, ncf6, '-', 'Color',[0.10 0.20 0.55], 'LineWidth',1.8, ...
    'DisplayName','M6 indicator (0.5 s)');
plot(bx1, tc, S{3}.ncf, '-o', 'Color',[0.85 0.33 0.10], 'LineWidth',1.4, ...
    'MarkerFaceColor','w', 'DisplayName','M3 dd-instrument (10 s)');
plot(bx1, tc, S{1}.ncf, '-s', 'Color',[0.30 0.6 0.30], 'LineWidth',1.0, ...
    'DisplayName','M1 H1-direct (10 s)');
yline(bx1, ctx.nom_ncf, '--', 'Color',[0 0.45 0.74], 'HandleVisibility','off');
yline(bx1, thr, ':', 'threshold 0.40', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
xlim(bx1,[cfg.t_start cfg.t_end]); ylim(bx1,[0 0.8]);
xlabel(bx1,'time (s)'); ylabel(bx1,'loop-only NCF margin');
title(bx1,'Method 6 (0.5 s updates) vs the 10 s methods'); legend(bx1,'Location','southwest');

bx2 = subplot(2,1,2); hold(bx2,'on'); grid(bx2,'on');
zoomwin = [758 770.1];
plot(bx2, tc6, ncf6, '-o', 'Color',[0.10 0.20 0.55], 'LineWidth',1.8, 'MarkerSize',3, ...
    'DisplayName','M6 (0.5 s) resolves the collapse');
plot(bx2, tc, S{3}.ncf, '-o', 'Color',[0.85 0.33 0.10], 'LineWidth',1.4, ...
    'MarkerFaceColor','w', 'MarkerSize',8, 'DisplayName','M3 (10 s): one point');
yline(bx2, thr, ':', 'threshold 0.40', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
xlim(bx2, zoomwin); ylim(bx2,[0 0.7]);
xlabel(bx2,'time (s)'); ylabel(bx2,'loop-only NCF margin');
title(bx2,'Zoom on the final collapse -- 0.5 s resolution vs 10 s'); legend(bx2,'Location','southwest');
saveas(fig2, fullfile(cfg.results_dir, 'method6_vs_others.png')); close(fig2);

save(fullfile(cfg.results_dir, 'comparison_results.mat'), ...
    'tc','NCF','NCF_kf','m4_bpred','m4_drift','m4_base','m3_smooth', ...
    'tc6','ncf6','metrics','R','labels','loop_idx','runtime','ctx');
fprintf('\nSaved comparison.png, method6_vs_others.png, comparison_table*.csv, comparison_metrics.csv, comparison_results.mat\n');

%% ---- local functions ----
function rt = time_run(script)
% Run a trial script in this function's (isolated) workspace and time it.
    t0 = tic;
    evalc(['run(''' script ''')']);
    rt = toc(t0);
end

function tcross = first_cross(series, level, tc, rising)
% First window-center time where series crosses 'level'.
    series = series(:);
    if rising, hit = find(series >= level, 1);
    else,      hit = find(series <= level, 1);
    end
    if isempty(hit), tcross = NaN; else, tcross = tc(hit); end
end
