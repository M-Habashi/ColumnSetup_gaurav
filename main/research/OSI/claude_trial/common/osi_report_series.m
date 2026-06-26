function osi_report_series(result, cfg)
%OSI_REPORT_SERIES Save (.mat), plot (.png) and print one trial's margin series.
% Works for both the 10 s (15-sample) and fast 0.5 s (298-sample) grids.
% result fields: tag, method, tc, ncf, nominal; optional threshold, extra, runtime.
%   extra : struct array with fields .name (char) and .data (column vector).
    if nargin < 2, cfg = osi_config(); end
    if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
    if ~isfield(result, 'extra'), result.extra = struct('name', {}, 'data', {}); end
    if ~isfield(result, 'threshold'), result.threshold = cfg.ncf_threshold; end

    stem = [result.tag '_' cfg.data_id];   % per-data-file result/plot name
    save(fullfile(cfg.results_dir, [stem '_result.mat']), 'result');

    tc = result.tc(:); s = result.ncf(:); n = numel(tc);
    stable = tc <= 700;
    below = s < result.threshold;
    hit = find(movsum(below, [cfg.detect_consec-1, 0]) >= cfg.detect_consec, 1);
    det = NaN; if ~isempty(hit), det = tc(hit); end

    % ---- printed summary (downsampled for long series) ----
    fprintf('\n=== %s ===\n', result.method);
    fprintf('samples=%d | nominal=%.3f | stable mean=%.3f std=%.3f | end=%.3f | detect=%.1f s\n', ...
        n, result.nominal, mean(s(stable),'omitnan'), std(s(stable),'omitnan'), s(end), det);
    if isfield(result,'runtime'), fprintf('runtime=%.2f s (%.1f ms/update)\n', result.runtime, 1e3*result.runtime/n); end
    step = max(1, round(n/18));
    fprintf('%14s %12s\n', 'win_center_s', 'NCF_margin');
    for k = 1:step:n, fprintf('%14.1f %12.4f\n', tc(k), s(k)); end

    % ---- figure ----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 820 470]);
    if n <= 40, sty = {'-o','MarkerFaceColor','w'}; else, sty = {'-'}; end
    plot(tc, s, sty{:}, 'Color', [0.20 0.30 0.55], 'LineWidth', 1.7, ...
        'DisplayName', 'estimated NCF'); hold on
    for e = 1:numel(result.extra)
        plot(tc, result.extra(e).data, '-', 'Color', [0.6 0.7 0.85], ...
            'LineWidth', 0.9, 'DisplayName', result.extra(e).name);
    end
    yline(result.nominal, '--', 'nominal', 'Color', [0 0.45 0.74], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');
    yline(result.threshold, ':', 'threshold', 'Color', [0.85 0.33 0.10], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');
    if ~isnan(det), xline(det, '-.', sprintf('detect %.1f s', det), ...
            'Color', [0.6 0 0], 'HandleVisibility', 'off'); end
    grid on; xlim([cfg.t_start cfg.t_end]); xlabel('time (s)'); ylabel('NCF stability margin');
    title(sprintf('%s  (data %s)', result.method, cfg.data_id), 'Interpreter', 'none');
    legend('Location', 'southwest');
    lo = min(0, min(s, [], 'omitnan') - 0.05); if isempty(lo) || isnan(lo), lo = 0; end
    ylim([lo 0.8]);
    saveas(fig, fullfile(cfg.results_dir, [stem '.png'])); close(fig);
    fprintf('saved %s_result.mat and %s.png\n', stem, stem);
end
