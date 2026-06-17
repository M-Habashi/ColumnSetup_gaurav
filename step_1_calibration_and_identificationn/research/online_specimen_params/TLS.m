% Windowed incremental total least squares specimen parameters.
% Each causal window is locally demeaned to estimate tangent-like [m, c, k].
% Healthy windows use unscaled TLS and low-force windows hold the last value.

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
uicontrol(fig, 'Style', 'text', 'String', 'Window size (s)', ...
    'Units', 'normalized', 'Position', [0.05 0.945 0.10 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.5', ...
    'Units', 'normalized', 'Position', [0.16 0.947 0.06 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'F min', ...
    'Units', 'normalized', 'Position', [0.25 0.945 0.05 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
fmin_edit = uicontrol(fig, 'Style', 'edit', 'String', '50', ...
    'Units', 'normalized', 'Position', [0.30 0.947 0.06 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'm0', ...
    'Units', 'normalized', 'Position', [0.41 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
m0_edit = uicontrol(fig, 'Style', 'edit', 'String', '2.04', ...
    'Units', 'normalized', 'Position', [0.44 0.947 0.06 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'c0', ...
    'Units', 'normalized', 'Position', [0.53 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
c0_edit = uicontrol(fig, 'Style', 'edit', 'String', '0.012', ...
    'Units', 'normalized', 'Position', [0.56 0.947 0.06 0.035]);
uicontrol(fig, 'Style', 'text', 'String', 'k0', ...
    'Units', 'normalized', 'Position', [0.65 0.945 0.03 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
k0_edit = uicontrol(fig, 'Style', 'edit', 'String', '7028', ...
    'Units', 'normalized', 'Position', [0.68 0.947 0.07 0.035]);
status_text = uicontrol(fig, 'Style', 'text', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [0.78 0.945 0.06 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')

controls = [window_edit, fmin_edit, m0_edit, c0_edit, k0_edit];
for i = 1:numel(controls)
    controls(i).Callback = @(~, ~)update_plot(window_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
    controls(i).KeyReleaseFcn = @(~, ~)update_plot(window_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
end
update_plot(window_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)

function update_plot(window_edit, fmin_edit, m0_edit, c0_edit, k0_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)
    blue = [0 124 168] / 255;
    purple = [116 5 138] / 255;
    copperwood = [172 100 32] / 255;

    window_s = str2double(window_edit.String);
    f_min = str2double(fmin_edit.String);
    theta0 = [str2double(m0_edit.String); str2double(c0_edit.String); str2double(k0_edit.String)];
    if any(isnan([window_s f_min theta0'])) || window_s <= 0 || f_min < 0
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(4, round(window_s / dt));
    [tc, theta_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, theta0);

    plot_step = max(1, floor(numel(tc) / 12000));
    ip = 1:plot_step:numel(tc);
    tp = tc(ip);
    winp = theta_win(ip, :);

    plot(ax(1), t, x, 'Color', blue, 'LineWidth', 1.0)
    grid(ax(1), 'on')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf('Moving window TLS/LSE, %.3g s window, TLS %.0f%%, LSE %.0f%%, hold %.0f%%', ...
        window_s, 100 * mean(method_id == 1), 100 * mean(method_id == 2), 100 * mean(method_id == 0)))

    plot(ax(2), t, F, 'Color', purple, 'LineWidth', 1.0)
    grid(ax(2), 'on')
    ylabel(ax(2), 'F (N)')

    plot_param(ax(3), tp, winp(:, 3), blue, 'k (N/mm)')
    plot_param(ax(4), tp, winp(:, 1), purple, 'm (kg)')
    plot_param(ax(5), tp, winp(:, 2), copperwood, 'c (N s/mm)')
    xlabel(ax(5), 'Time (s)')
    linkaxes(ax, 'x')

    status_text.String = 'Done';
    fig.Pointer = 'arrow';
    drawnow
end

function [tc, theta_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, theta0)
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
    method_id = zeros(numel(tc), 1);
    theta_last = theta0(:);

    for i = 1:numel(tc)
        G = [aa(i), av(i), axx(i); av(i), vv(i), vx(i); axx(i), vx(i), xx(i)];
        b = [aF(i); vF(i); xF(i)];
        F_rms = sqrt(max(FF(i), 0) / n_window);

        if F_rms <= f_min
            theta = theta_last;
        else
            C = [G, b; b', FF(i)];
            [V, D] = eig((C + C') / 2);
            [~, j] = min(diag(D));
            tls_vec = V(:, j);
            if tls_vec(4) ~= 0
                theta = -tls_vec(1:3) / tls_vec(4);
                method_id(i) = 1;
            else
                theta = pinv(G) * b;
                method_id(i) = 2;
            end
        end

        theta_win(i, :) = theta';
        theta_last = theta;
    end
end

function plot_param(ax, tp, winp, color, ytext)
    plot(ax, tp, winp, 'Color', color, 'LineWidth', 1.2)
    grid(ax, 'on')
    ylabel(ax, ytext)
end
