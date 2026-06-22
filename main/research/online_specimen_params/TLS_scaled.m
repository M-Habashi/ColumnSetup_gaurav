% Interactive online-style noise-whitened TLS comparison.
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

fig = figure('Name', 'Interactive noise-whitened online TLS', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [80 50 1250 900]);

labels = {'Window (s)', 'Filter (Hz)', 'Plot stride', 'F min (N)', 'Q rel.', 'R rel.'};
defaults = {'1', '30', '64', '20', '0.01', '0.10'};
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

calculate.Callback = @(~, ~) update_plot(edits, ax, status, S);
for i = 1:numel(edits)
    edits(i).Callback = calculate.Callback;
end

update_plot(edits, ax, status, S)

function update_plot(edits, ax, status, S)
    values = arrayfun(@(h) str2double(h.String), edits);
    window_s = values(1);
    cutoff = values(2);
    plot_stride = round(values(3));
    f_min = values(4);
    q_rel = values(5);
    r_rel = values(6);

    status.String = 'Calculating...';
    drawnow

    t = S.t(:);
    dt = S.dt;
    [x, v, a, F] = filtered_regression_signals(S.dm/1000, S.fm, dt, cutoff);
    noise_idx = t <= t(1) + 2;
    noise_scale = std([a(noise_idx), v(noise_idx), x(noise_idx), F(noise_idx)], 0, 1);
    noise_scale(noise_scale == 0) = 1;

    keep = ~noise_idx;
    t = t(keep);
    x = x(keep);
    v = v(keep);
    a = a(keep);
    F = F(keep);

    n_window = round(window_s/dt);
    sample_idx = n_window:plot_stride:numel(t);
    n = numel(sample_idx);

    theta0 = [2.04; 12; 7028000];
    theta_raw = nan(n, 3);
    theta_kf = nan(n, 3);
    accepted = false(n, 1);
    theta = theta0;
    P = diag((0.25*theta0).^2);
    Q = diag((q_rel*theta0).^2);
    R = diag((r_rel*theta0).^2);
    last_update = -inf;

    for i = 1:n
        i2 = sample_idx(i);
        idx = (i2 - n_window + 1):i2;
        if rms(F(idx) - mean(F(idx))) > f_min
            estimate = noise_whitened_tls(a(idx), v(idx), x(idx), F(idx), noise_scale);
            if all(isfinite(estimate)) && estimate(1) > 0 && estimate(3) > 0
                theta_raw(i, :) = estimate';
            end
        end

        if i2 - last_update >= n_window && all(isfinite(theta_raw(i, :)))
            P = P + Q*window_s;
            K = P/(P + R);
            theta = theta + K*(theta_raw(i, :)' - theta);
            P = (eye(3) - K)*P;
            last_update = i2;
            accepted(i) = true;
        end
        theta_kf(i, :) = theta';
    end

    tc = t(sample_idx);
    names = {'Mass (kg)', 'Damping (N s/m)', 'Stiffness (N/m)'};
    colors = [0.1725 0.1725 0.1725; 0.6745 0.3922 0.1255; 0 0.4863 0.6588];
    for i = 1:numel(ax)
        cla(ax(i))
    end

    plot(ax(1), t, 1000*x, 'Color', '#007CA8')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf(['Whitened TLS: %.2f s window, %d-sample display stride, ' ...
        '%d non-overlap KF updates'], window_s, plot_stride, nnz(accepted)))

    plot(ax(2), t, F, 'Color', '#74058A')
    ylabel(ax(2), 'F (N)')

    for j = 1:3
        plot(ax(j + 2), tc, theta_raw(:, j), '.', 'Color', [0.65 0.65 0.65]); hold(ax(j + 2), 'on')
        plot(ax(j + 2), tc, theta_kf(:, j), 'LineWidth', 1.6, 'Color', colors(j, :))
        plot(ax(j + 2), tc(accepted), theta_kf(accepted, j), 'o', ...
            'Color', colors(j, :), 'MarkerFaceColor', 'w', 'MarkerSize', 4)
        yline(ax(j + 2), theta0(j), '--k', 'LineWidth', 1.4)
        ylabel(ax(j + 2), names{j})
    end
    xlabel(ax(end), 'Time (s)')
    legend(ax(end), 'Dense TLS', 'Non-overlap KF', 'KF assimilation', 'Initial reference')
    linkaxes(ax, 'x')
    xlim(ax(1), [t(1) t(end)])
    fit_positive_estimate_axis(ax(3), theta_kf(:, 1), theta0(1))
    fit_positive_estimate_axis(ax(5), theta_kf(:, 3), theta0(3))

    status.String = sprintf('%d TLS / %d KF', nnz(all(isfinite(theta_raw), 2)), nnz(accepted));
    fprintf('Noise scales [a v x F] = [%g %g %g %g]\n', noise_scale)
end

function fit_positive_estimate_axis(ax, estimate, reference)
    upper = 1.05*max([estimate(isfinite(estimate)); reference]);
    ylim(ax, [0 upper])
end
