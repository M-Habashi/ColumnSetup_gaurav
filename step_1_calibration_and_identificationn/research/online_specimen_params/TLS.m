% Windowed incremental total least squares specimen parameters.
% Each causal window is locally demeaned to estimate tangent-like [m, c, k].
% Healthy windows use unscaled TLS so the stiffness matches the offline TSE
% estimate. When the window force RMS is below F min, the last estimate is
% held because neither TLS nor LSE has useful excitation. When TLS has a much
% larger force residual than same-window LSE, controlled by r routing max, the
% window is routed to LSE. A tuned KF then smooths the routed estimates with
% separate TLS/LSE measurement noise and stronger damping for upward k spikes.
%
% Tuning meanings:
% r route: TLS/LSE routing threshold based on force-residual ratio. This is
% not a Kalman covariance.
% R TLS: Kalman measurement-noise scale for accepted TLS windows. Larger
% values trust TLS measurements less.
% R LSE: Kalman measurement-noise scale for LSE-routed windows. Larger values
% trust fallback LSE measurements less.
% R up: extra multiplier on Kalman R when the k innovation is upward, used to
% damp upward stiffness spikes while keeping downward tracking fast.
% Q scale: Kalman process-noise scale, used for mean tracking responsiveness.
% The shaded band is the nominal 95% KF covariance band. During low-excitation
% holds, the state and covariance are both held because there is no informative
% parameter evolution to track.

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
window_edit = uicontrol(fig, 'Style', 'edit', 'String', '1', ...
    'Units', 'normalized', 'Position', [0.10 0.957 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 'F min', ...
    'Units', 'normalized', 'Position', [0.17 0.955 0.04 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
fmin_edit = uicontrol(fig, 'Style', 'edit', 'String', '120', ...
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
uicontrol(fig, 'Style', 'text', 'String', 't1', ...
    'Units', 'normalized', 'Position', [0.35 0.915 0.03 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
t1_edit = uicontrol(fig, 'Style', 'edit', 'String', '0', ...
    'Units', 'normalized', 'Position', [0.38 0.917 0.05 0.030]);
uicontrol(fig, 'Style', 'text', 'String', 't2', ...
    'Units', 'normalized', 'Position', [0.45 0.915 0.03 0.030], ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
t2_edit = uicontrol(fig, 'Style', 'edit', 'String', '0', ...
    'Units', 'normalized', 'Position', [0.48 0.917 0.05 0.030]);
calculate_button = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Calculate', ...
    'Units', 'normalized', 'Position', [0.56 0.917 0.08 0.030]);

ax(1) = subplot(5, 1, 1, 'Parent', fig);
ax(2) = subplot(5, 1, 2, 'Parent', fig);
ax(3) = subplot(5, 1, 3, 'Parent', fig);
ax(4) = subplot(5, 1, 4, 'Parent', fig);
ax(5) = subplot(5, 1, 5, 'Parent', fig);
set(ax, 'PositionConstraint', 'innerposition')
layout_axes(ax)

calculate_button.Callback = @(~, ~)update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, t1_edit, t2_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt);
update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, t1_edit, t2_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)

function layout_axes(ax)
    plot_top = 0.84;
    plot_bottom = 0.075;
    plot_gap = 0.052;
    plot_height = (plot_top - plot_bottom - plot_gap * 4) / 5;
    for i = 1:numel(ax)
        y = plot_top - i * plot_height - (i - 1) * plot_gap;
        ax(i).Units = 'normalized';
        ax(i).Position = [0.125 y 0.84 plot_height];
    end
end

function update_plot(window_edit, fmin_edit, routing_edit, q_edit, r_tls_edit, r_lse_edit, r_up_edit, m0_edit, c0_edit, k0_edit, t1_edit, t2_edit, ax, status_text, fig, t, x, v, a_mps2, F, dt)
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
    t1 = str2double(t1_edit.String);
    t2 = str2double(t2_edit.String);
    if any(isnan([window_s f_min r_routing_max q_scale r_tls_scale r_lse_scale r_up_factor theta0' t1 t2])) ...
            || window_s <= 0 || f_min < 0 || r_routing_max <= 0 || q_scale < 0 ...
            || r_tls_scale <= 0 || r_lse_scale <= 0 || r_up_factor <= 0
        return
    end
    full_update = t1 == 0 && t2 == 0;
    t_range = sort([t1 t2]);
    if ~full_update && t_range(1) == t_range(2)
        return
    end
    status_text.String = 'Calculating...';
    fig.Pointer = 'watch';
    drawnow

    n_window = max(4, round(window_s / dt));
    state = getappdata(fig, 'tls_state');
    do_redraw = full_update || isempty(state) || ~isfield(state, 'tc');

    if do_redraw
        [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, r_routing_max, theta0);
        [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, method_id, theta0, dt, ...
            q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max);
        state = struct('tc', tc, 'theta_win', theta_win, 'cov_win', cov_win, ...
            'method_id', method_id, 'theta_kf', theta_kf, 'pdiag_kf', pdiag_kf);
        title_text = sprintf('Moving window TLS/LSE + KF, %.3g s window, full update, TLS %.0f%%, LSE %.0f%%, hold %.0f%%', ...
            window_s, 100 * mean(method_id == 1), 100 * mean(method_id == 2), 100 * mean(method_id == 0));
        highlight_range = [];
    else
        idx = find(state.tc >= t_range(1) & state.tc <= t_range(2));
        raw_idx = round(interp1(t, 1:numel(t), state.tc(idx), 'nearest', 'extrap'));
        valid = raw_idx >= n_window & raw_idx <= numel(t);
        idx = idx(valid);
        raw_idx = raw_idx(valid);
        if isempty(idx)
            status_text.String = 'Done';
            fig.Pointer = 'arrow';
            return
        end

        if idx(1) > 1
            theta_tls0 = state.theta_win(idx(1) - 1, :)';
            theta_kf0 = state.theta_kf(idx(1) - 1, :)';
            P0 = diag(state.pdiag_kf(idx(1) - 1, :));
        else
            theta_tls0 = theta0;
            theta_kf0 = theta0;
            P0 = diag([0.5; 0.05; 1000] .^ 2);
        end

        [~, theta_win, cov_win, method_id] = incremental_window_tls_samples(t, x, v, a_mps2, F, n_window, raw_idx, f_min, r_routing_max, theta_tls0, theta0);
        [theta_kf, pdiag_kf] = parameter_kf_segment(theta_win, cov_win, method_id, theta_kf0, P0, theta0, dt, ...
            q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max);
        state.theta_win(idx, :) = theta_win;
        state.cov_win(idx, :) = cov_win;
        state.method_id(idx) = method_id;
        state.theta_kf(idx, :) = theta_kf;
        state.pdiag_kf(idx, :) = pdiag_kf;
        title_text = sprintf('Moving window TLS/LSE + KF, %.3g s window, %.3g-%.3g s update, TLS %.0f%%, LSE %.0f%%, hold %.0f%%', ...
            window_s, t_range(1), t_range(2), 100 * mean(method_id == 1), 100 * mean(method_id == 2), 100 * mean(method_id == 0));
        highlight_range = t_range;
    end

    state = draw_tls_results(ax, t, x, F, state, highlight_range, blue, purple, copperwood, title_text, do_redraw);
    setappdata(fig, 'tls_state', state)

    status_text.String = 'Done';
    fig.Pointer = 'arrow';
    drawnow
end

function state = draw_tls_results(ax, t, x, F, state, highlight_range, blue, purple, copperwood, title_text, do_redraw)
    plot_step = max(1, floor(numel(state.tc) / 12000));
    ip = 1:plot_step:numel(state.tc);
    tp = state.tc(ip);
    winp = state.theta_win(ip, :);
    kfp = state.theta_kf(ip, :);
    cip = 1.96 * sqrt(max(state.pdiag_kf(ip, :), 0));

    have_handles = isfield(state, 'h') && isfield(state.h, 'kf') && all(isgraphics(state.h.kf));
    if do_redraw || ~have_handles
        plot(ax(1), t, x, 'Color', blue, 'LineWidth', 1.0)
        grid(ax(1), 'on')
        ylabel(ax(1), 'x (mm)')

        plot(ax(2), t, F, 'Color', purple, 'LineWidth', 1.0)
        grid(ax(2), 'on')
        ylabel(ax(2), 'F (N)')

        [state.h.ci(1), state.h.win(1), state.h.kf(1)] = plot_param(ax(3), tp, winp(:, 3), kfp(:, 3), cip(:, 3), blue, 'k (N/mm)');
        [state.h.ci(2), state.h.win(2), state.h.kf(2)] = plot_param(ax(4), tp, winp(:, 1), kfp(:, 1), cip(:, 1), purple, 'm (kg)');
        [state.h.ci(3), state.h.win(3), state.h.kf(3)] = plot_param(ax(5), tp, winp(:, 2), kfp(:, 2), cip(:, 2), copperwood, 'c (N s/mm)');
        xlabel(ax(5), 'Time (s)')
        linkaxes(ax, 'x')
    else
        update_param(state.h.ci(1), state.h.win(1), state.h.kf(1), tp, winp(:, 3), kfp(:, 3), cip(:, 3))
        update_param(state.h.ci(2), state.h.win(2), state.h.kf(2), tp, winp(:, 1), kfp(:, 1), cip(:, 1))
        update_param(state.h.ci(3), state.h.win(3), state.h.kf(3), tp, winp(:, 2), kfp(:, 2), cip(:, 2))
        set(ax(3:5), 'YLimMode', 'auto')
    end

    title(ax(1), title_text)
    state.h.highlight = update_highlight(ax, state, highlight_range);
end

function update_param(h_ci, h_win, h_kf, tp, winp, kfp, cip)
    set(h_ci, 'XData', [tp; flipud(tp)], 'YData', [kfp - cip; flipud(kfp + cip)])
    set(h_win, 'XData', tp, 'YData', winp)
    set(h_kf, 'XData', tp, 'YData', kfp)
end

function h_highlight = update_highlight(ax, state, t_range)
    if isfield(state, 'h') && isfield(state.h, 'highlight')
        h_highlight = state.h.highlight;
    else
        h_highlight = gobjects(numel(ax), 1);
    end

    if isempty(t_range)
        delete(h_highlight(isgraphics(h_highlight)))
        h_highlight = gobjects(numel(ax), 1);
        return
    end

    yellow = [1 0.85 0];
    for i = 1:numel(ax)
        yl = ylim(ax(i));
        xh = [t_range(1) t_range(2) t_range(2) t_range(1)];
        yh = [yl(1) yl(1) yl(2) yl(2)];
        if i <= numel(h_highlight) && isgraphics(h_highlight(i))
            set(h_highlight(i), 'XData', xh, 'YData', yh)
        else
            h_highlight(i) = patch(ax(i), xh, yh, yellow, ...
                'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HitTest', 'off');
        end
        uistack(h_highlight(i), 'bottom')
    end
end

function [tc, theta_win, cov_win, method_id] = incremental_window_tls(t, x, v, a_mps2, F, n_window, f_min, r_routing_max, theta0)
    sample_idx = n_window:numel(t);
    [tc, theta_win, cov_win, method_id] = incremental_window_tls_samples(t, x, v, a_mps2, F, n_window, sample_idx, f_min, r_routing_max, theta0, theta0);
end

function [tc, theta_win, cov_win, method_id] = incremental_window_tls_samples(t, x, v, a_mps2, F, n_window, sample_idx, f_min, r_routing_max, theta_seed, theta_ref)
    sample_idx = sample_idx(:);
    sample_idx = sample_idx(sample_idx >= n_window & sample_idx <= numel(t));
    i1 = sample_idx - n_window + 1;
    i2 = sample_idx;

    Sa = window_sum(a_mps2, i1, i2);
    Sv = window_sum(v, i1, i2);
    Sx = window_sum(x, i1, i2);
    SF = window_sum(F, i1, i2);
    Saa = window_sum(a_mps2 .* a_mps2, i1, i2);
    Sav = window_sum(a_mps2 .* v, i1, i2);
    Sax = window_sum(a_mps2 .* x, i1, i2);
    Svv = window_sum(v .* v, i1, i2);
    Svx = window_sum(v .* x, i1, i2);
    Sxx = window_sum(x .* x, i1, i2);
    SaF = window_sum(a_mps2 .* F, i1, i2);
    SvF = window_sum(v .* F, i1, i2);
    SxF = window_sum(x .* F, i1, i2);
    SFF = window_sum(F .* F, i1, i2);
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

    tc = t(sample_idx);
    theta_win = zeros(numel(tc), 3);
    cov_win = zeros(numel(tc), 3);
    method_id = zeros(numel(tc), 1);
    [theta_min, theta_max] = parameter_bounds(theta_ref, 0.02);
    theta_last = clamp_parameters(theta_seed, theta_min, theta_max);

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

        theta = clamp_parameters(theta, theta_min, theta_max);
        sigma2 = max(theta' * G * theta - 2 * theta' * b + FF(i), 0) / max(n_window - 3, 1);
        Ctheta = sigma2 * pinv(G);
        cov_win(i, :) = max(diag((Ctheta + Ctheta') / 2), eps)';
        theta_win(i, :) = theta';
        theta_last = theta;
    end
end

function s = window_sum(y, i1, i2)
    cy = [0; cumsum(y(:))];
    s = cy(i2 + 1) - cy(i1);
end

function [theta_kf, pdiag_kf] = parameter_kf(theta_win, cov_win, method_id, theta0, dt, q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max)
    P = diag([0.5; 0.05; 1000] .^ 2);
    [theta_kf, pdiag_kf] = parameter_kf_segment(theta_win, cov_win, method_id, theta0(:), P, theta0, dt, ...
        q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max);
end

function [theta_kf, pdiag_kf] = parameter_kf_segment(theta_win, cov_win, method_id, theta, P, theta0, dt, q_scale, r_tls_scale, r_lse_scale, r_up_factor, innovation_down_max, innovation_up_max)
    n = size(theta_win, 1);
    theta_kf = zeros(n, 3);
    pdiag_kf = zeros(n, 3);
    q_std = [0.02; 0.0002; 20];
    r_floor = [0.02; 0.0002; 20];
    Q_kf = q_scale * diag(q_std .^ 2) * dt;
    [theta_min, theta_max] = parameter_bounds(theta0, 0.02);
    theta = clamp_parameters(theta, theta_min, theta_max);

    for i = 1:n
        valid = method_id(i) ~= 0 && all(isfinite(theta_win(i, :))) && theta_win(i, 1) > 0 && theta_win(i, 3) > 0;

        if method_id(i) ~= 0
            P = P + Q_kf;
        end

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
            theta = clamp_parameters(theta, theta_min, theta_max);
            P = (eye(3) - K) * P;
            P = (P + P') / 2;
        end

        theta_kf(i, :) = theta';
        pdiag_kf(i, :) = diag(P)';
    end
end

function [theta_min, theta_max] = parameter_bounds(theta0, rel_limit)
    theta0 = theta0(:);
    theta_min = theta0 * rel_limit;
    theta_max = inf(size(theta0));
end

function theta = clamp_parameters(theta, theta_min, theta_max)
    theta = min(max(theta(:), theta_min), theta_max);
end

function [h_ci, h_win, h_kf] = plot_param(ax, tp, winp, kfp, cip, color, ytext)
    light_color = 0.65 * color + 0.35 * [1 1 1];
    h_ci = fill(ax, [tp; flipud(tp)], [kfp - cip; flipud(kfp + cip)], ...
        color, 'FaceAlpha', 0.28, 'EdgeColor', 'none');
    hold(ax, 'on')
    h_win = plot(ax, tp, winp, ':', 'Color', light_color, 'LineWidth', 0.9);
    h_kf = plot(ax, tp, kfp, 'Color', color, 'LineWidth', 1.2);
    hold(ax, 'off')
    grid(ax, 'on')
    ylabel(ax, ytext)
end
