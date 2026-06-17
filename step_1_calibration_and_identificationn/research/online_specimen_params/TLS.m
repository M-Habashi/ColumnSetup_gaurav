% Windowed incremental total least squares + Kalman filtering.
% This mirrors KF_windowed_incremental.m: each causal window is locally
% demeaned to estimate tangent-like [m, c, k], then a random-walk Kalman
% filter smooths the parameter sequence. The only estimator change is that
% the window measurement uses total least squares, allowing noise in both
% [a, v, x] and F. TLS is computed from the centered 4-by-4 covariance of
% [a, v, x, F], which is equivalent to a direct window SVD but much cheaper.

clear; clc; close all

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
tls_scale = max(std([a_mps2, v, x, F], 0, 1), eps);

fig = figure('Name', 'Windowed incremental TLS KF specimen parameters', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [100 100 1100 750]);
uicontrol(fig, 'Style', 'text', 'String', 'Window size (s)', ...
    'Units', 'normalized', 'Position', [0.03 0.945 0.11 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.5', ...
    'Units', 'normalized', 'Position', [0.14 0.947 0.05 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'Q scale', ...
    'Units', 'normalized', 'Position', [0.21 0.945 0.06 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
q_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.1', ...
    'Units', 'normalized', 'Position', [0.27 0.947 0.05 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'R scale', ...
    'Units', 'normalized', 'Position', [0.34 0.945 0.05 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
r_edit = uicontrol(fig, 'Style', 'edit', 'String', '50', ...
    'Units', 'normalized', 'Position', [0.39 0.947 0.05 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'F min', ...
    'Units', 'normalized', 'Position', [0.46 0.945 0.05 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
fmin_edit = uicontrol(fig, 'Style', 'edit', 'String', '500', ...
    'Units', 'normalized', 'Position', [0.51 0.947 0.06 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'm0', ...
    'Units', 'normalized', 'Position', [0.59 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
m0_edit = uicontrol(fig, 'Style', 'edit', 'String', '2.04', ...
    'Units', 'normalized', 'Position', [0.62 0.947 0.05 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'c0', ...
    'Units', 'normalized', 'Position', [0.69 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
c0_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.012', ...
    'Units', 'normalized', 'Position', [0.72 0.947 0.05 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'k0', ...
    'Units', 'normalized', 'Position', [0.79 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
k0_edit = uicontrol(fig, 'Style', 'edit', 'String', '7028', ...
    'Units', 'normalized', 'Position', [0.82 0.947 0.06 0.035]);
status_text = uicontrol(fig, 'Style', 'text', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [0.90 0.945 0.08 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')

controls = [window_edit, q_edit, r_edit, fmin_edit, m0_edit, c0_edit, k0_edit];
for i = 1:numel(controls)
    controls(i).Callback = @(~, ~)update_plot(window_edit, q_edit, r_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt, tls_scale);
    controls(i).KeyReleaseFcn = @(~, ~)update_plot(window_edit, q_edit, r_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt, tls_scale);
end
update_plot(window_edit, q_edit, r_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt, tls_scale)

function update_plot(window_edit, q_edit, r_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt, tls_scale)
    blue = [0 124 168] / 255;
    purple = [116 5 138] / 255;
    copperwood = [172 100 32] / 255;

    window_s = str2double(window_edit.String);
    q_scale = str2double(q_edit.String);
    r_scale = str2double(r_edit.String);
    f_min = str2double(fmin_edit.String);
    theta0 = [str2double(m0_edit.String); str2double(c0_edit.String); str2double(k0_edit.String)];
    if any(isnan([window_s q_scale r_scale f_min theta0'])) || window_s <= 0 || q_scale < 0 || r_scale <= 0 || f_min < 0
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(4, round(window_s / dt));
    [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, tls_scale, f_min, theta0);
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
    title(ax(1), sprintf('Incremental window TLS/LSE + KF, %.3g s window, TLS %.0f%%, LSE %.0f%%, hold %.0f%%', ...
        window_s, 100 * mean(method_id == 1), 100 * mean(method_id == 2), 100 * mean(method_id == 0)))

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

function [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, tls_scale, f_min, theta0)
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
    method_id = zeros(numel(tc), 1);
    theta_last = theta0(:);
    cov_last = diag(max(abs(theta_last), 1));
    cond_max = 1e8;

    for i = 1:numel(tc)
        G = [aa(i), av(i), axx(i); av(i), vv(i), vx(i); axx(i), vx(i), xx(i)];
        b = [aF(i); vF(i); xF(i)];
        F_rms = sqrt(max(FF(i), 0) / n_window);

        if F_rms <= f_min
            theta = theta_last;
            theta_cov = cov_last;
        elseif cond(G) < cond_max
            C = [G, b; b', FF(i)];
            Cs = C ./ (tls_scale' * tls_scale);
            [V, D] = eig((Cs + Cs') / 2);
            [~, j] = min(diag(D));
            tls_vec = V(:, j) ./ tls_scale';
            theta = -tls_vec(1:3) / tls_vec(4);
            sigma2 = max(0, theta' * G * theta - 2 * theta' * b + FF(i)) / (n_window - 4);
            theta_cov = sigma2 * (G \ eye(3));
            method_id(i) = 1;
        else
            theta = pinv(G) * b;
            sigma2 = max(0, FF(i) - theta' * b) / (n_window - 4);
            theta_cov = sigma2 * pinv(G);
            method_id(i) = 2;
        end

        theta_win(i, :) = theta';
        cov_win(:, :, i) = theta_cov;
        theta_last = theta;
        cov_last = theta_cov;
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
