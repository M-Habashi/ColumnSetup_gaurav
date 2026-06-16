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

fig = figure('Name', 'Windowed LSE specimen parameters', ...
    'NumberTitle', 'off', 'Color', 'w', 'Position', [100 100 1100 750]);
uicontrol(fig, 'Style', 'text', 'String', 'Window size (s)', ...
    'Units', 'normalized', 'Position', [0.08 0.945 0.12 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '5', ...
    'Units', 'normalized', 'Position', [0.20 0.947 0.08 0.035]);
status_text = uicontrol(fig, 'Style', 'text', 'String', 'Done', ...
    'Units', 'normalized', 'Position', [0.30 0.945 0.12 0.035], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')

window_edit.Callback = @(src, ~)update_plot(src, ax, status_text, fig, t, x, v, a_mps2, F, dt);
window_edit.KeyReleaseFcn = @(src, ~)update_plot(src, ax, status_text, fig, t, x, v, a_mps2, F, dt);
update_plot(window_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)

function update_plot(window_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)
    blue = [0 124 168] / 255;
    purple = [116 5 138] / 255;
    copperwood = [172 100 32] / 255;

    window_s = str2double(window_edit.String);
    if isnan(window_s) || window_s <= 0
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(3, round(window_s / dt));

    aa = movsum(a_mps2 .* a_mps2, [n_window - 1 0], 'Endpoints', 'discard');
    av = movsum(a_mps2 .* v, [n_window - 1 0], 'Endpoints', 'discard');
    axx = movsum(a_mps2 .* x, [n_window - 1 0], 'Endpoints', 'discard');
    vv = movsum(v .* v, [n_window - 1 0], 'Endpoints', 'discard');
    vx = movsum(v .* x, [n_window - 1 0], 'Endpoints', 'discard');
    xx = movsum(x .* x, [n_window - 1 0], 'Endpoints', 'discard');
    aF = movsum(a_mps2 .* F, [n_window - 1 0], 'Endpoints', 'discard');
    vF = movsum(v .* F, [n_window - 1 0], 'Endpoints', 'discard');
    xF = movsum(x .* F, [n_window - 1 0], 'Endpoints', 'discard');
    FF = movsum(F .* F, [n_window - 1 0], 'Endpoints', 'discard');

    tc = t(n_window:end);
    m = zeros(size(tc));
    c = zeros(size(tc));
    k = zeros(size(tc));
    m_ci = zeros(size(tc));
    c_ci = zeros(size(tc));
    k_ci = zeros(size(tc));

    for i = 1:numel(tc)
        G = [aa(i), av(i), axx(i); av(i), vv(i), vx(i); axx(i), vx(i), xx(i)];
        b = [aF(i); vF(i); xF(i)];
        theta = G \ b;
        sigma2 = max(0, FF(i) - theta' * b) / (n_window - 3);
        ci = 1.96 * sqrt(diag(sigma2 * inv(G)));

        m(i) = theta(1);
        c(i) = theta(2);
        k(i) = theta(3);
        m_ci(i) = ci(1);
        c_ci(i) = ci(2);
        k_ci(i) = ci(3);
    end

    plot_step = max(1, floor(numel(tc) / 12000));
    ip = 1:plot_step:numel(tc);
    tp = tc(ip);
    kp = k(ip);
    mp = m(ip);
    cp = c(ip);
    kcip = k_ci(ip);
    mcip = m_ci(ip);
    ccip = c_ci(ip);

    plot(ax(1), t, x, 'Color', blue, 'LineWidth', 1.0)
    grid(ax(1), 'on')
    ylabel(ax(1), 'x (mm)')
    title(ax(1), sprintf('Sliding window LSE, %.3g s causal window', window_s))

    plot(ax(2), t, F, 'Color', purple, 'LineWidth', 1.0)
    grid(ax(2), 'on')
    ylabel(ax(2), 'F (N)')

    fill(ax(3), [tp; flipud(tp)], [kp - kcip; flipud(kp + kcip)], ...
        blue, 'FaceAlpha', 0.18, 'EdgeColor', 'none')
    hold(ax(3), 'on')
    plot(ax(3), tp, kp - kcip, ':', 'Color', blue, 'LineWidth', 0.8)
    plot(ax(3), tp, kp + kcip, ':', 'Color', blue, 'LineWidth', 0.8)
    plot(ax(3), tp, kp, 'Color', blue, 'LineWidth', 1.2)
    hold(ax(3), 'off')
    grid(ax(3), 'on')
    ylabel(ax(3), 'k (N/mm)')

    fill(ax(4), [tp; flipud(tp)], [mp - mcip; flipud(mp + mcip)], ...
        purple, 'FaceAlpha', 0.18, 'EdgeColor', 'none')
    hold(ax(4), 'on')
    plot(ax(4), tp, mp - mcip, ':', 'Color', purple, 'LineWidth', 0.8)
    plot(ax(4), tp, mp + mcip, ':', 'Color', purple, 'LineWidth', 0.8)
    plot(ax(4), tp, mp, 'Color', purple, 'LineWidth', 1.2)
    hold(ax(4), 'off')
    grid(ax(4), 'on')
    ylabel(ax(4), 'm (kg)')

    fill(ax(5), [tp; flipud(tp)], [cp - ccip; flipud(cp + ccip)], ...
        copperwood, 'FaceAlpha', 0.18, 'EdgeColor', 'none')
    hold(ax(5), 'on')
    plot(ax(5), tp, cp - ccip, ':', 'Color', copperwood, 'LineWidth', 0.8)
    plot(ax(5), tp, cp + ccip, ':', 'Color', copperwood, 'LineWidth', 0.8)
    plot(ax(5), tp, cp, 'Color', copperwood, 'LineWidth', 1.2)
    hold(ax(5), 'off')
    grid(ax(5), 'on')
    xlabel(ax(5), 'Time (s)')
    ylabel(ax(5), 'c (N s/mm)')
    linkaxes(ax, 'x')
    status_text.String = 'Done';
    fig.Pointer = 'arrow';
    drawnow
end
