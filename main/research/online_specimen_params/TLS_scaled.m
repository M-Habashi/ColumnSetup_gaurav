% Interactive official online-style noise-whitened TLS estimator.
% The first 2 s are stationary zero-command noise and are excluded from fits.
% Dense overlapping TLS estimates are plotted, but the KF only assimilates
% approximately non-overlapping windows. Acceleration is derived from dm.

clear; clc; close all

root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(root));
addpath(fullfile(step_root, 'research', 'specimen_mode', 'methods'))
addpath(fullfile(step_root, 'helpers', 'utils'))

fprintf(['Select a record whose first 2 s are zero-command, stationary ' ...
    'noise-only data.\n'])
[S, data_file] = load_saved_result_file(step_root, 'tests', true);
config = official_tls_config;

fig = figure('Name', 'Official noise-whitened online TLS', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [80 50 1250 900]);

labels = {'Window (s)', 'Filter (Hz)', 'Plot stride', 'F min (N)', 'Q rel.', 'R rel.'};
defaults = {num2str(config.window_s), num2str(config.filter_hz), ...
    num2str(config.plot_stride), num2str(config.f_min), ...
    num2str(config.q_rel), num2str(config.r_rel)};
edits = gobjects(1, numel(labels));
for i = 1:numel(labels)
    x0 = 0.015 + (i - 1)*0.125;
    uicontrol(fig, 'Style', 'text', 'String', labels{i}, ...
        'Units', 'normalized', 'Position', [x0 0.957 0.075 0.025], ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    edits(i) = uicontrol(fig, 'Style', 'edit', 'String', defaults{i}, ...
        'Units', 'normalized', 'Position', [x0 + 0.075 0.958 0.045 0.028]);
end

calculate = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Calculate', ...
    'Units', 'normalized', 'Position', [0.79 0.954 0.085 0.035]);
status = uicontrol(fig, 'Style', 'text', 'String', '', ...
    'Units', 'normalized', 'Position', [0.88 0.952 0.11 0.040], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

layout = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact', 'Position', [0.055 0.055 0.925 0.88]);
ax = gobjects(5, 1);
for i = 1:5
    ax(i) = nexttile(layout);
    grid(ax(i), 'on')
end
linkaxes(ax, 'x')

calculate.Callback = @(~, ~) update_plot(edits, ax, status, S, config);
for i = 1:numel(edits)
    edits(i).Callback = calculate.Callback;
end

update_plot(edits, ax, status, S, config)

function update_plot(edits, ax, status, S, config)
    values = arrayfun(@(h) str2double(h.String), edits);
    config.window_s = values(1);
    config.filter_hz = values(2);
    config.plot_stride = round(values(3));
    config.f_min = values(4);
    config.q_rel = values(5);
    config.r_rel = values(6);

    status.String = 'Calculating...';
    drawnow

    t = S.t(:);
    dt = S.dt;
    [x, v, a, F] = filtered_regression_signals(S.dm/1000, S.fm, dt, config.filter_hz);
    noise_idx = t <= t(1) + config.noise_duration;
    noise_scale = std([a(noise_idx), v(noise_idx), x(noise_idx), F(noise_idx)], 0, 1);
    noise_scale(noise_scale == 0) = 1;

    keep = ~noise_idx;
    t = t(keep);
    x = x(keep);
    v = v(keep);
    a = a(keep);
    F = F(keep);

    estimate = windowed_noise_whitened_tls(t, a, v, x, F, noise_scale, config);
    tc = estimate.t;
    theta_raw = estimate.theta_raw;
    theta_kf = estimate.theta_kf;
    accepted = estimate.accepted;
    names = {'Mass (kg)', 'Damping (N s/m)', 'Stiffness (N/m)'};
    colors = [0.1725 0.1725 0.1725; 0.6745 0.3922 0.1255; 0 0.4863 0.6588];
    for i = 1:numel(ax)
        cla(ax(i))
    end

    plot(ax(1), t, 1000*x, 'Color', '#007CA8')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf(['Official whitened TLS: %.2f s window, %d-sample display stride, ' ...
        '%d non-overlap KF updates'], config.window_s, config.plot_stride, nnz(accepted)))

    plot(ax(2), t, F, 'Color', '#74058A')
    ylabel(ax(2), 'F (N)')

    for j = 1:3
        plot(ax(j + 2), tc, theta_raw(:, j), '.', 'Color', [0.65 0.65 0.65]); hold(ax(j + 2), 'on')
        plot(ax(j + 2), tc, theta_kf(:, j), 'LineWidth', 1.6, 'Color', colors(j, :))
        plot(ax(j + 2), tc(accepted), theta_kf(accepted, j), 'o', ...
            'Color', colors(j, :), 'MarkerFaceColor', 'w', 'MarkerSize', 4)
        ylabel(ax(j + 2), names{j})
    end
    xlabel(ax(end), 'Time (s)')
    legend(ax(end), 'Dense TLS', 'Non-overlap KF', 'KF assimilation')
    linkaxes(ax, 'x')
    xlim(ax(1), [t(1) t(end)])
    fit_positive_estimate_axis(ax(3), theta_kf(:, 1))
    fit_positive_estimate_axis(ax(5), theta_kf(:, 3))

    status.String = sprintf('%d TLS / %d KF', nnz(all(isfinite(theta_raw), 2)), nnz(accepted));
    fprintf('Noise scales [a v x F] = [%g %g %g %g]\n', noise_scale)
end

function fit_positive_estimate_axis(ax, estimate)
    upper = 1.05*max(estimate(isfinite(estimate)));
    ylim(ax, [0 upper])
end
