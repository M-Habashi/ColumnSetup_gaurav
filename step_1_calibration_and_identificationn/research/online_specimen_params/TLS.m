% Windowed incremental total least squares specimen parameters.
% Each causal window is locally demeaned to estimate tangent-like [m, c, k].
% Healthy windows use unscaled TLS so the stiffness matches the offline TSE
% estimate. When the window force RMS is below F min, the last estimate is
% held because neither TLS nor LSE has useful excitation. When TLS has a much
% larger force residual than same-window LSE, controlled by r routing max, the
% window is routed to LSE. A tuned KF then smooths the routed estimates with
% separate TLS/LSE measurement noise and stronger damping for upward k spikes.

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

fig = figure('Name', 'Moving window TLS specimen parameters', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [100 100 1100 750]);
uicontrol(fig, 'Style', 'text', 'String', 'Window (s)', ...
    'Units', 'normalized', 'Position', [0.03 0.955 0.07 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '1.5', ...
    'Units', 'normalized', 'Position', [0.10 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'F min', ...
    'Units', 'normalized', 'Position', [0.17 0.955 0.04 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
fmin_edit = uicontrol(fig, 'Style', 'edit', 'String', '50', ...
    'Units', 'normalized', 'Position', [0.21 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'r route', ...
    'Units', 'normalized', 'Position', [0.28 0.955 0.05 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
routing_edit = uicontrol(fig, 'Style', 'edit', 'String', '3', ...
    'Units', 'normalized', 'Position', [0.33 0.957 0.04 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'Q scale', ...
    'Units', 'normalized', 'Position', [0.39 0.955 0.05 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
q_edit = uicontrol(fig, 'Style', 'edit', 'String', '200', ...
    'Units', 'normalized', 'Position', [0.45 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'R TLS', ...
    'Units', 'normalized', 'Position', [0.52 0.955 0.05 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
r_tls_edit = uicontrol(fig, 'Style', 'edit', 'String', '200', ...
    'Units', 'normalized', 'Position', [0.57 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'R LSE', ...
    'Units', 'normalized', 'Position', [0.64 0.955 0.05 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
r_lse_edit = uicontrol(fig, 'Style', 'edit', 'String', '1000', ...
    'Units', 'normalized', 'Position', [0.69 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'R up', ...
    'Units', 'normalized', 'Position', [0.76 0.955 0.04 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
r_up_edit = uicontrol(fig, 'Style', 'edit', 'String', '100', ...
    'Units', 'normalized', 'Position', [0.80 0.957 0.05 0.030]);
status_text = uicontrol(fig, 'Style', 'text', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [0.88 0.955 0.08 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
uicontrol(fig, 'Style', 'text', 'String', 'm0', ...
    'Units', 'normalized', 'Position', [0.03 0.915 0.03 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
m0_edit = uicontrol(fig, 'Style', 'edit', 'String', '2.04', ...
    'Units', 'normalized', 'Position', [0.06 0.917 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'c0', ...
    'Units', 'normalized', 'Position', [0.13 0.915 0.03 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
c0_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.012', ...
    'Units', 'normalized', 'Position', [0.16 0.917 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'k0', ...
    'Units', 'normalized', 'Position', [0.23 0.915 0.03 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
k0_edit = uicontrol(fig, 'Style', 'edit', 'String', '7028', ...
    'Units', 'normalized', 'Position', [0.26 0.917 0.06 0.030]);

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')

controls = [window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit];
for i = 1:numel(controls)
    controls(i).Callback = @(~, ~)update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
    controls(i).KeyReleaseFcn = @(~, ~)update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
end
update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)

function update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)
    blue = [0 124 168] / 255;
    purple = [116 5 138] / 255;
    copperwood = [172 100 32] / 255;
    innovation_down_max = 36;
    innovation_up_max = 16;

    window_s = str2double(window_edit.String);
    f_min = str2double(fmin_edit.String);
    r_routing_max = str2double(routing_edit.String);
    q_scale = str2double(q_edit.String);
    r_tls_scale = str2double(r_tls_edit.String);
    r_lse_scale = str2double(r_lse_edit.String);
    r_up_factor = str2double(r_up_edit.String);
    theta0 = [str2double(m0_edit.String); str2double(c0_edit.String); str2double(k0_edit.String)];
    if any(isnan([window_s f_min r_routing_max q_scale r_tls_scale r_lse_scale r_up_factor theta0'])) ...
            || window_s <= 0 || f_min < 0 || r_routing_max <= 0 || q_scale < 0 ...
            || r_tls_scale <= 0 || r_lse_scale <= 0 || r_up_factor <= 0
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(4, round(window_s / dt));
    [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, r_routing_max, theta0);
    [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, method_id, theta0, dt, ...
        q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max);

    plot_step = max(1, floor(numel(tc) / 12000));
    ip = 1:plot_step:numel(tc);
    tp = tc(ip);
    winp = theta_win(ip, :);
    kfp = theta_kf(ip, :);
    cip = 1.96 * sqrt(max(pdiag_kf(ip, :), 0));

    plot(ax(1), t, x, 'Color', blue, 'LineWidth', 1.0)
    grid(ax(1), 'on')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf('Moving window TLS/LSE + KF, %.3g s window, TLS %.0f%%, LSE %.0f%%, hold %.0f%%', ...
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

function [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, r_routing_max, theta0)
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
    cov_win = zeros(numel(tc), 3);
    method_id = zeros(numel(tc), 1);
    theta_last = theta0(:);

    for i = 1:numel(tc)
        G = [aa(i), av(i), axx(i); av(i), vv(i), vx(i); axx(i), vx(i), xx(i)];
        b = [aF(i); vF(i); xF(i)];
        F_rms = sqrt(max(FF(i), 0) / n_window);

        if F_rms <= f_min
            theta = theta_last;
        else
            theta_lse = pinv(G) * b;
            C = [G, b; b', FF(i)];
            [V, D] = eig((C + C') / 2);
            [~, j] = min(diag(D));
            tls_vec = V(:, j);
            if tls_vec(4) ~= 0
                theta = -tls_vec(1:3) / tls_vec(4);
                sse_lse = max(FF(i) - theta_lse' * b, 0);
                sse_tls = max(theta' * G * theta - 2 * theta' * b + FF(i), 0);
                residual_ratio = sqrt(sse_tls / max(sse_lse, eps));
                if isfinite(residual_ratio) && residual_ratio <= r_routing_max
                    method_id(i) = 1;
                else
                    theta = theta_lse;
                    method_id(i) = 2;
                end
            else
                theta = theta_lse;
                method_id(i) = 2;
            end
        end

        sigma2 = max(theta' * G * theta - 2 * theta' * b + FF(i), 0) / max(n_window - 3, 1);
        Ctheta = sigma2 * pinv(G);
        cov_win(i, :) = max(diag((Ctheta + Ctheta') / 2), eps)';
        theta_win(i, :) = theta';
        theta_last = theta;
    end
end

function [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, method_id, theta0, dt, q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max)
    n = size(theta_win, 1);
    theta_kf = zeros(n, 3);
    pdiag_kf = zeros(n, 3);
    q_std = [0.02; 0.0002; 20];
    r_floor = [0.02; 0.0002; 20];
    Q_kf = q_scale * diag(q_std .^ 2) * dt;
    theta = theta0(:);
    P = diag([0.5; 0.05; 1000] .^ 2);

    for i = 1:n
        P = P + Q_kf;
        valid = method_id(i) ~= 0 && all(isfinite(theta_win(i, :))) && theta_win(i, 1) > 0 && theta_win(i, 3) > 0;

        if valid
            if method_id(i) == 1
                r_scale = r_tls_scale;
            else
                r_scale = r_lse_scale;
            end

            R_kf = r_scale * diag(max(cov_win(i, :)', r_floor .^ 2));
            innovation = theta_win(i, :)' - theta;
            if innovation(3) > 0
                R_kf = r_up_factor * R_kf;
                innovation_max = innovation_up_max;
            else
                innovation_max = innovation_down_max;
            end

            S = P + R_kf;
            nis = innovation' * (S \ innovation);
            R_kf = max(1, nis / innovation_max) * R_kf;
            K = P / (P + R_kf);
            theta = theta + K * innovation;
            P = (eye(3) - K) * P;
            P = (P + P') / 2;
        end

        theta_kf(i, :) = theta';
        pdiag_kf(i, :) = diag(P)';
    end
end

function plot_param(ax, tp, winp, kfp, cip, color, ytext)
    light_color = 0.65 * color + 0.35 * [1 1 1];
    fill(ax, [tp; flipud(tp)], [kfp - cip; flipud(kfp + cip)], ...
        color, 'FaceAlpha', 0.12, 'EdgeColor', 'none')
    hold(ax, 'on')
    plot(ax, tp, winp, ':', 'Color', light_color, 'LineWidth', 0.9)
    plot(ax, tp, kfp, 'Color', color, 'LineWidth', 1.2)
    hold(ax, 'off')
    grid(ax, 'on')
    ylabel(ax, ytext)
end
