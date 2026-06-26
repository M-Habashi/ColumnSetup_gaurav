function osi_report_series(result, cfg)
%OSI_REPORT_SERIES Save (.mat), plot (.png) and print one trial's margin series.
% result fields: tag, method, tc, ncf, nominal; optional threshold, extra
%   extra : struct array with fields .name (char) and .data (column vector).
    if nargin < 2, cfg = osi_config(); end
    if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
    if ~isfield(result, 'extra'), result.extra = struct('name', {}, 'data', {}); end
    if ~isfield(result, 'threshold'), result.threshold = cfg.ncf_threshold; end

    save(fullfile(cfg.results_dir, [result.tag '_result.mat']), 'result');

    % ---- printed table ----
    fprintf('\n=== %s ===\n', result.method);
    header = sprintf('%14s %12s', 'win_center_s', 'NCF_margin');
    for e = 1:numel(result.extra), header = [header sprintf(' %12s', result.extra(e).name)]; end %#ok<AGROW>
    fprintf('%s\n', header);
    for k = 1:numel(result.tc)
        line = sprintf('%14.1f %12.4f', result.tc(k), result.ncf(k));
        for e = 1:numel(result.extra), line = [line sprintf(' %12.4f', result.extra(e).data(k))]; end %#ok<AGROW>
        fprintf('%s\n', line);
    end
    fprintf('nominal = %.4f | first = %.4f | last = %.4f\n', ...
        result.nominal, result.ncf(1), result.ncf(end));

    % ---- figure ----
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 780 470]);
    plot(result.tc, result.ncf, '-o', 'LineWidth', 1.8, ...
        'MarkerFaceColor', 'w', 'DisplayName', 'estimated NCF'); hold on
    for e = 1:numel(result.extra)
        plot(result.tc, result.extra(e).data, '--s', 'LineWidth', 1.2, ...
            'DisplayName', result.extra(e).name);
    end
    yline(result.nominal, '--', 'nominal', 'Color', [0 0.45 0.74], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');
    yline(result.threshold, ':', 'threshold', 'Color', [0.85 0.33 0.10], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');
    grid on; xlabel('time (s)'); ylabel('NCF stability margin');
    title(result.method, 'Interpreter', 'none');
    legend('Location', 'southwest'); ylim([min(0, min(result.ncf)-0.05) 0.8]);
    saveas(fig, fullfile(cfg.results_dir, [result.tag '.png'])); close(fig);
    fprintf('saved %s_result.mat and %s.png\n', result.tag, result.tag);
end
