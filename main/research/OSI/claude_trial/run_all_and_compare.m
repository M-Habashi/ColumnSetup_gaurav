%% run_all_and_compare -- compare all six OSI methods (loads cached trial results).
% Each trial saves results/trial_k_result.mat; this script LOADS them (re-running
% a trial only if its result is missing), compares, Kalman-smooths, and plots.
% In the default sliding (0.5 s) mode all six share one 298-sample grid.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

tags    = {'trial_1','trial_2','trial_3','trial_4','trial_5','trial_6','trial_7'};
labels  = {'M1 H1-direct','M2 parametric','M3 dd-instrument', ...
           'M4 nu-gap drift','M5 RLS','M6 freq-KF','M7 resonance(out)'};
nM = numel(tags); S = cell(nM,1);
for i = 1:nM
    f = fullfile(cfg.results_dir, [tags{i} '_' cfg.data_id '_result.mat']);
    if ~isfile(f), evalc(['run(''' fullfile(this_dir,tags{i},['run_' tags{i} '.m']) ''')']); end
    Ld = load(f); S{i} = Ld.result;
end
tc = S{1}.tc; thr = cfg.ncf_threshold; cons = cfg.detect_consec;
mid = cfg.t_start + 0.6*(cfg.t_end-cfg.t_start);   % "stable phase" boundary (per file)

% loop-only margin methods that work at small windows: M1,M3,M5,M6 (M2 separate)
work_idx = [1 3 5 6];
m4_bpred = S{4}.ncf; m4_drift = S{4}.extra(1).data; m4_base = S{4}.nominal;
[~, m1_smooth] = osi_apply_kf(S{1}.ncf, cfg.kf_q, cfg.kf_r);

% --- metrics (all seven; each on its own grid) ---
Method=labels(:); StartNCF=nan(nM,1); StableMean=nan(nM,1); StableStd=nan(nM,1);
Jitter=nan(nM,1); EndNCF=nan(nM,1); Detect_s=nan(nM,1); Runtime_s=nan(nM,1);
for i = 1:nM
    s = S{i}.ncf; ti = S{i}.tc; sti = ti <= mid;
    i1 = find(~isnan(s),1); il = find(~isnan(s),1,'last');
    if ~isempty(i1), StartNCF(i)=s(i1); EndNCF(i)=s(il); end   % NaN if all-NaN (e.g. M4 N/A)
    StableMean(i)=mean(s(sti),'omitnan'); StableStd(i)=std(s(sti),'omitnan');
    Jitter(i)=mean(abs(diff(s(sti))),'omitnan');
    if isfield(S{i},'detect_time'), Detect_s(i)=S{i}.detect_time;       % M6, M7 store it
    elseif i==4, Detect_s(i)=sustained_cross(m4_drift, m4_base, ti, cons, true);
    else,        Detect_s(i)=sustained_cross(s, thr, ti, cons, false); end
    if isfield(S{i},'runtime'), Runtime_s(i)=S{i}.runtime; end
end
metrics = table(Method, StartNCF, StableMean, StableStd, Jitter, EndNCF, Detect_s, Runtime_s);
fprintf('\n=========== OSI METHOD COMPARISON (%s) ===========\n', osi_window_label(cfg));
fprintf('nominal loop-only NCF=%.3f | threshold=%.2f | samples=%d | detect rule=%d consecutive\n', ...
    ctx.nom_ncf, thr, numel(tc), cons);
disp(metrics);
fprintf(['Note: at the 0.5 s window the parametric methods M2 and M4 have too few FRF\n' ...
    'points per window to fit reliably -> noisy / not usable. The nonparametric (M1,M3)\n' ...
    'and recursive (M5,M6) methods are the ones suited to fast small-window detection.\n']);

Rwork = corrcoef([S{1}.ncf S{3}.ncf S{5}.ncf S{6}.ncf], 'Rows','pairwise');
fprintf('\nCorrelation of the working fast methods (M1,M3,M5,M6):\n');
disp(array2table(Rwork, 'VariableNames', labels(work_idx), 'RowNames', labels(work_idx)));

writetable(table(tc, S{1}.ncf, S{2}.ncf, S{3}.ncf, S{5}.ncf, S{6}.ncf, m4_bpred, ...
    'VariableNames', {'time_s','M1','M2','M3','M5','M6','M4_bpred'}), ...
    fullfile(cfg.results_dir, ['comparison_table_' cfg.data_id '.csv']));
writetable(metrics, fullfile(cfg.results_dir, ['comparison_metrics_' cfg.data_id '.csv']));

% --- figure 1: working fast methods (top) + parametric failures (bottom) ---
fig = figure('Visible','off','Color','w','Position',[80 80 980 760]);
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on'); co = lines(4);
for j = 1:4
    plot(ax1, tc, S{work_idx(j)}.ncf, '-', 'Color', co(j,:), 'LineWidth', 1.2, ...
        'DisplayName', labels{work_idx(j)});
end
plot(ax1, tc, m1_smooth, 'k-', 'LineWidth', 2.0, 'DisplayName', 'M1 + Kalman smoother');
plot(ax1, S{7}.tc, S{7}.ncf, '-', 'Color',[0.55 0 0.35], 'LineWidth', 1.8, ...
    'DisplayName','M7 output resonance');
yline(ax1, S{7}.nominal, '--', 'nominal', 'Color', [0 0.45 0.74], 'HandleVisibility','off');
yline(ax1, thr, ':', 'threshold 0.40', 'Color', [0.85 0.33 0.10], 'HandleVisibility','off');
xlim(ax1,[cfg.t_start cfg.t_end]); ylim(ax1,[0 0.8]);
xlabel(ax1,'time (s)'); ylabel(ax1,'NCF margin');
title(ax1, sprintf('Indicators that work (%s): FRF M1/M3/M5/M6 + output-resonance M7', osi_window_label(cfg)));
legend(ax1,'Location','southwest','NumColumns',2);

ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
plot(ax2, tc, S{2}.ncf, '-', 'Color', [0.6 0.2 0.2], 'LineWidth', 1.0, 'DisplayName','M2 parametric (loop-only)');
plot(ax2, tc, m4_bpred, '-', 'Color', [0.2 0.2 0.6], 'LineWidth', 1.0, 'DisplayName','M4 nu-gap predicted margin');
yline(ax2, thr, ':', 'threshold 0.40', 'Color', [0.85 0.33 0.10], 'HandleVisibility','off');
yline(ax2, 0, '-', 'Color', [0.5 0.5 0.5], 'HandleVisibility','off');
xlim(ax2,[cfg.t_start cfg.t_end]);
xlabel(ax2,'time (s)'); ylabel(ax2,'margin');
title(ax2,'Parametric methods are NOT reliable at the 0.5 s window (cautionary)');
legend(ax2,'Location','southwest');
saveas(fig, fullfile(cfg.results_dir, ['comparison_' cfg.data_id '.png'])); close(fig);

% --- figure 2: collapse zoom -- which fast methods capture the divergence ---
fig2 = figure('Visible','off','Color','w','Position',[80 80 980 420]);
hold on; grid on;
plot(tc, S{1}.ncf, '-o', 'Color',[0.30 0.6 0.30], 'MarkerSize',3, 'DisplayName','M1 H1-direct');
plot(tc, S{5}.ncf, '-o', 'Color',[0.5 0.2 0.6],  'MarkerSize',3, 'DisplayName','M5 RLS');
plot(tc, S{6}.ncf, '-o', 'Color',[0.10 0.20 0.55],'LineWidth',1.6,'MarkerSize',3,'DisplayName','M6 freq-KF');
plot(tc, S{3}.ncf, '-o', 'Color',[0.85 0.33 0.10],'MarkerSize',3, 'DisplayName','M3 dd-instrument');
plot(S{7}.tc, S{7}.ncf, '-', 'Color',[0.55 0 0.35],'LineWidth',1.8,'DisplayName','M7 output resonance');
yline(thr, ':', 'threshold 0.40', 'Color',[0.85 0.33 0.10], 'HandleVisibility','off');
xlim([max(cfg.t_start, cfg.t_end-12) cfg.t_end]); ylim([0 0.7]);
xlabel('time (s)'); ylabel('NCF margin');
title('End-of-window zoom (0.5 s)');
legend('Location','southwest');
saveas(fig2, fullfile(cfg.results_dir, ['method6_vs_others_' cfg.data_id '.png'])); close(fig2);

save(fullfile(cfg.results_dir, ['comparison_results_' cfg.data_id '.mat']), 'tc','S','metrics','Rwork','labels','ctx');
fprintf('\nSaved comparison/metrics/results for data %s\n', cfg.data_id);

%% ---- local function ----
function tcross = sustained_cross(series, level, tc, consec, rising)
% First time 'series' stays past 'level' for 'consec' consecutive samples.
    series = series(:);
    if rising, below = series >= level; else, below = series <= level; end
    below(isnan(series)) = false;
    hit = find(movsum(below, [consec-1, 0]) >= consec, 1);
    if isempty(hit), tcross = NaN; else, tcross = tc(hit); end
end
