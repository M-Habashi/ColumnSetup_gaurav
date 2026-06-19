clear; clc; close all
% 1.5 0.001 10000
root = fileparts(mfilename('fullpath'));
data_file = fullfile(root, 'data', 'sp_1_ori_P30_I0_t430_590.mat');

S = load(data_file);
t = S.t(:);
x = S.dm(:);
F = S.fm(:);
dt = S.dt;
v = gradient(x, dt);
a = gradient(v, dt);
a_mps2 = a / 1000;

fig = figure('Name', 'Windowed incremental KF specimen parameters', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [100 100 1100 750]);
uicontrol(fig, 'Style', 'text', 'String', 'Window size (s)', ...
    'Units', 'normalized', 'Position', [0.08 0.945 0.12 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.5', ...
    'Units', 'normalized', 'Position', [0.20 0.947 0.07 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'Q scale', ...
    'Units', 'normalized', 'Position', [0.30 0.945 0.07 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
q_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.1', ...
    'Units', 'normalized', 'Position', [0.37 0.947 0.07 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'R scale', ...
    'Units', 'normalized', 'Position', [0.47 0.945 0.07 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
r_edit = uicontrol(fig, 'Style', 'edit', 'String', '50', ...
    'Units', 'normalized', 'Position', [0.54 0.947 0.07 0.035]);
status_text = uicontrol(fig, 'Style', 'text', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [0.64 0.945 0.12 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')

controls = [window_edit, q_edit, r_edit];
for i = 1:numel(controls)
    controls(i).Callback = @(~, ~)update_plot(window_edit, q_edit, r_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
    controls(i).KeyReleaseFcn = @(~, ~)update_plot(window_edit, q_edit, r_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
end
update_plot(window_edit, q_edit, r_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)

function update_plot(window_edit, q_edit, r_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)
    blue = [0 124 168] / 255;
    purple = [116 5 138] / 255;
    copperwood = [172 100 32] / 255;

    window_s = str2double(window_edit.String);
    q_scale = str2double(q_edit.String);
    r_scale = str2double(r_edit.String);
    if any(isnan([window_s q_scale r_scale])) || window_s <= 0 || q_scale < 0 || r_scale <= 0
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(4, round(window_s / dt));
    [tc, theta_win, cov_win] = incremental_window_estimate(t, x, v, a_mps2, F, n_window);
    [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, q_scale, r_scale);

    plot_step = max(1, floor(numel(tc) / 12000));
    ip = 1:plot_step:numel(tc);
    tp = tc(ip);
    winp = theta_win(ip, :);
    kfp = theta_kf(ip, :);
    cip = 1.96 * sqrt(max(pdiag_kf(ip, :), 0));

    plot(ax(1), t, x, 'Color', blue, 'LineWidth', 1.0)
    grid(ax(1), 'on')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf('Incremental window estimate + KF, %.3g s causal window', window_s))

    plot(ax(2), t, F, 'Color', purple, 'LineWidth', 1.0)
    grid(ax(2), 'on')
    ylabel(ax(2), 'F (N)')

    plot_param(ax(3), tp, winp(:, 3), kfp(:, 3), cip(:, 3), blue, 'k (N/mm)')
    plot_param(ax(4), tp, winp(:, 1), kfp(:, 1), cip(:, 1), purple, 'm (kg)')
    plot_param(ax(5), tp, winp(:, 2), kfp(:, 2), cip(:, 2), copperwood, 'c (N s/mm)')
    xlabel(ax(5), 'Time (s)')
    linkaxes(ax, 'x')

    status_text.String = 'Done';
    fig.Pointer = 'arrow';
    drawnow
end

function [tc, theta_win, cov_win] = incremental_window_estimate(t, x, v, a_mps2, F, n_window)
    Sa = movsum(a_mps2, [n_window - 1 0], 'Endpoints', 'discard');
    Sv = movsum(v, [n_window - 1 0], 'Endpoints', 'discard');
    Sx = movsum(x, [n_window - 1 0], 'Endpoints', 'discard');
    SF = movsum(F, [n_window - 1 0], 'Endpoints', 'discard');

    Saa = movsum(a_mps2 .* a_mps2, [n_window - 1 0], 'Endpoints', 'discard');
    Sav = movsum(a_mps2 .* v, [n_window - 1 0], 'Endpoints', 'discard');
    Sax = movsum(a_mps2 .* x, [n_window - 1 0], 'Endpoints', 'discard');
    Svv = movsum(v .* v, [n_window - 1 0], 'Endpoints', 'discard');
    Svx = movsum(v .* x, [n_window - 1 0], 'Endpoints', 'discard');
    Sxx = movsum(x .* x, [n_window - 1 0], 'Endpoints', 'discard');
    SaF = movsum(a_mps2 .* F, [n_window - 1 0], 'Endpoints', 'discard');
    SvF = movsum(v .* F, [n_window - 1 0], 'Endpoints', 'discard');
    SxF = movsum(x .* F, [n_window - 1 0], 'Endpoints', 'discard');
    SFF = movsum(F .* F, [n_window - 1 0], 'Endpoints', 'discard');

    aa = Saa - Sa .* Sa / n_window;
    av = Sav - Sa .* Sv / n_window;
    axx = Sax - Sa .* Sx / n_window;
    vv = Svv - Sv .* Sv / n_window;
    vx = Svx - Sv .* Sx / n_window;
    xx = Sxx - Sx .* Sx / n_window;
    aF = SaF - Sa .* SF / n_window;
    vF = SvF - Sv .* SF / n_window;
    xF = SxF - Sx .* SF / n_window;
    FF = SFF - SF .* SF / n_window;

    tc = t(n_window:end);
    theta_win = zeros(numel(tc), 3);
    cov_win = zeros(3, 3, numel(tc));

    for i = 1:numel(tc)
        G = [aa(i), av(i), axx(i); av(i), vv(i), vx(i); axx(i), vx(i), xx(i)];
        b = [aF(i); vF(i); xF(i)];
        theta = G \ b;
        sigma2 = max(0, FF(i) - theta' * b) / (n_window - 4);

        theta_win(i, :) = theta';
        cov_win(:, :, i) = sigma2 * (G \ eye(3));
    end
end

function [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, q_scale, r_scale)
    n = size(theta_win, 1);
    theta_kf = zeros(n, 3);
    pdiag_kf = zeros(n, 3);

    theta = theta_win(1, :)';
    p0 = diag(max(diag(cov_win(:, :, 1)), eps));
    q = q_scale * diag(max(var(theta_win, 0, 1), eps));
    P = r_scale * p0 + q;

    for i = 1:n
        P = P + q;
        R = r_scale * diag(max(diag(cov_win(:, :, i)), eps));
        K = P / (P + R);
        theta = theta + K * (theta_win(i, :)' - theta);
        P = (eye(3) - K) * P;
        P = (P + P') / 2;

        theta_kf(i, :) = theta';
        pdiag_kf(i, :) = diag(P)';
    end
end

function plot_param(ax, tp, winp, kfp, cip, color, ytext)
    light_color = 0.65 * color + 0.35 * [1 1 1];

    fill(ax, [tp; flipud(tp)], [kfp - cip; flipud(kfp + cip)], ...
        color, 'FaceAlpha', 0.18, 'EdgeColor', 'none')
    hold(ax, 'on')
    plot(ax, tp, winp, ':', 'Color', light_color, 'LineWidth', 0.9)
    plot(ax, tp, kfp - cip, ':', 'Color', color, 'LineWidth', 0.8)
    plot(ax, tp, kfp + cip, ':', 'Color', color, 'LineWidth', 0.8)
    plot(ax, tp, kfp, 'Color', color, 'LineWidth', 1.2)
    hold(ax, 'off')
    grid(ax, 'on')
    ylabel(ax, ytext)
end
