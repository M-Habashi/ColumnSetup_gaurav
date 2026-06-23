function plot_transfer_function_model_comparison(tf_discrete, tf_fit, tf_parametric, freq_hz, freq_rad, plot_config)
%PLOT_TRANSFER_FUNCTION_MODEL_COMPARISON Plot Bode and pole-zero comparisons.
% Units: transfer functions/magnitude are dimensionless, frequency is Hz
% or rad/s, phase is deg, and pole/zero coordinates are rad/s.

    %% Evaluate each model on the measured frequency grid
    tf_discrete_resp = squeeze(freqresp(tf_discrete, freq_rad));
    tf_fit_resp = squeeze(freqresp(tf_fit, freq_rad));
    tf_parametric_resp = squeeze(freqresp(tf_parametric, freq_rad));

    mag_discrete_db = 20 * log10(abs(tf_discrete_resp) + eps);
    mag_fit_db = 20 * log10(abs(tf_fit_resp) + eps);
    mag_parametric_db = 20 * log10(abs(tf_parametric_resp) + eps);

    phase_discrete_deg = unwrap(angle(tf_discrete_resp)) * 180 / pi;
    phase_fit_deg = unwrap(angle(tf_fit_resp)) * 180 / pi;
    phase_parametric_deg = unwrap(angle(tf_parametric_resp)) * 180 / pi;
    fit_color = [144 21 0] / 255;        % #901500
    parametric_color = [46 158 78] / 255; % darker #39BF5E

    %% Plot Bode magnitude and phase comparison
    figure('Name', 'Analog Closed-Loop Identification Comparison', 'Color', 'w');
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax_mag = nexttile;
    h_mag(1) = semilogx(freq_hz, mag_discrete_db, 'kx', 'DisplayName', 'tf_{discrete} (xfunc)');
    hold on
    h_mag(2) = semilogx(freq_hz, mag_fit_db, '-', 'Color', fit_color, 'LineWidth', 1.4, ...
        'DisplayName', 'tf_{fit} (regularized)');
    h_mag(3) = semilogx(freq_hz, mag_parametric_db, '--', 'Color', parametric_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{parametric}');
    grid on
    xlim(plot_config.f_lim);
    ylabel('Magnitude (dB, dimensionless ratio)');
    title(plot_config.desc);
    lgd = legend(h_mag, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;

    ax_phase = nexttile;
    h_phase(1) = semilogx(freq_hz, phase_discrete_deg, 'kx', 'DisplayName', 'tf_{discrete} (xfunc)');
    hold on
    h_phase(2) = semilogx(freq_hz, phase_fit_deg, '-', 'Color', fit_color, 'LineWidth', 1.4, ...
        'DisplayName', 'tf_{fit} (regularized)');
    h_phase(3) = semilogx(freq_hz, phase_parametric_deg, '--', 'Color', parametric_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{parametric}');
    grid on
    xlim(plot_config.f_lim);
    xlabel('Frequency (Hz)');
    ylabel('Phase (deg)');
    lgd = legend(h_phase, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    link_legend_pairs(h_mag, h_phase);
    setappdata(ax_mag, 'LinkedLegendAxes', ax_phase);
    setappdata(ax_phase, 'LinkedLegendAxes', ax_mag);

    figure('Name', 'Poles and Zeros for Transfer-Function Models', 'Color', 'w');
    plot_poles_and_zeros(tf_fit, tf_parametric, fit_color, parametric_color);
end

function plot_poles_and_zeros(tf_fit, tf_parametric, fit_color, parametric_color)
    % Plot fitted and parametric model pole-zero locations together.
    % Units: transfer functions are dimensionless; pole/zero coordinates are rad/s.
    hold on
    [fit_poles, fit_zeros] = plot_model_poles_and_zeros(tf_fit, fit_color);
    [parametric_poles, parametric_zeros] = plot_model_poles_and_zeros(tf_parametric, parametric_color);
    xline(0, 'k:');
    yline(0, 'k:');
    grid on
    box on
    axis equal
    xlabel('Real (rad/s)');
    ylabel('Imaginary (rad/s)');
    title('Poles and Zeros');

    fit_legend = plot(nan, nan, '-', 'Color', fit_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{fit}');
    parametric_legend = plot(nan, nan, '-', 'Color', parametric_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{parametric}');
    setappdata(fit_legend, 'LinkedLegendItems', [fit_poles, fit_zeros]);
    setappdata(parametric_legend, 'LinkedLegendItems', [parametric_poles, parametric_zeros]);
    lgd = legend([fit_legend, parametric_legend], 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
end

function [pole_plot, zero_plot] = plot_model_poles_and_zeros(sys, marker_color)
    % Draw poles as x markers and zeros as circle markers.
    % Units: sys is dimensionless; plotted coordinates are rad/s; colors are unitless.
    poles = pole(sys);
    zeros = zero(sys);
    pole_plot = gobjects(0);
    zero_plot = gobjects(0);

    if ~isempty(zeros)
        zero_plot = plot(real(zeros), imag(zeros), 'o', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
    if ~isempty(poles)
        pole_plot = plot(real(poles), imag(poles), 'x', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
end

function link_legend_pairs(h_mag, h_phase)
    % Units: graphics handles and links are unitless.
    for i = 1:numel(h_mag)
        setappdata(h_mag(i), 'LinkedLegendItems', h_phase(i));
        setappdata(h_phase(i), 'LinkedLegendItems', h_mag(i));
    end
end

function toggle_legend_item(~, event)
    % Units: graphics handles, visibility, and cached limits are unitless.
    ax = ancestor(event.Peer, 'axes');
    x_limits = xlim(ax);
    y_limits = ylim(ax);
    linked_ax = getappdata(ax, 'LinkedLegendAxes');
    if ~isempty(linked_ax) && isvalid(linked_ax)
        linked_x_limits = xlim(linked_ax);
        linked_y_limits = ylim(linked_ax);
    end

    linked_items = getappdata(event.Peer, 'LinkedLegendItems');
    targets = [event.Peer, linked_items];
    targets = targets(isvalid(targets));
    if strcmp(event.Peer.Visible, 'on')
        set(targets, 'Visible', 'off');
    else
        set(targets, 'Visible', 'on');
    end

    xlim(ax, x_limits);
    ylim(ax, y_limits);
    if ~isempty(linked_ax) && isvalid(linked_ax)
        xlim(linked_ax, linked_x_limits);
        ylim(linked_ax, linked_y_limits);
    end
end
