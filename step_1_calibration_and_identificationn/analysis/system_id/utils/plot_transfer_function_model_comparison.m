function plot_transfer_function_model_comparison(tf_discrete, tf_fit, tf_parametric, freq_hz, freq_rad, plot_config)
%PLOT_TRANSFER_FUNCTION_MODEL_COMPARISON Plot Bode and pole-zero comparisons.

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

    %% Plot Bode magnitude and phase comparison
    figure('Name', 'Analog Closed-Loop Identification Comparison', 'Color', 'w');
    tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    semilogx(freq_hz, mag_discrete_db, 'kx', 'DisplayName', 'tf_{discrete} (xfunc)');
    hold on
    semilogx(freq_hz, mag_fit_db, 'b-', 'LineWidth', 1.4, 'DisplayName', 'tf_{fit} (invfreq)');
    semilogx(freq_hz, mag_parametric_db, 'r--', 'LineWidth', 1.6, 'DisplayName', 'tf_{parametric}');
    grid on
    xlim(plot_config.f_lim);
    ylabel('Magnitude (dB)');
    title(plot_config.desc);
    legend('Location', 'best');

    nexttile;
    semilogx(freq_hz, phase_discrete_deg, 'kx', 'DisplayName', 'tf_{discrete} (xfunc)');
    hold on
    semilogx(freq_hz, phase_fit_deg, 'b-', 'LineWidth', 1.4, 'DisplayName', 'tf_{fit} (invfreq)');
    semilogx(freq_hz, phase_parametric_deg, 'r--', 'LineWidth', 1.6, 'DisplayName', 'tf_{parametric}');
    grid on
    xlim(plot_config.f_lim);
    xlabel('Frequency (Hz)');
    ylabel('Phase (deg)');
    legend('Location', 'best');

    figure('Name', 'Poles and Zeros for Transfer-Function Models', 'Color', 'w');
    plot_poles_and_zeros(tf_fit, tf_parametric);
end

function plot_poles_and_zeros(tf_fit, tf_parametric)
    % Plot fitted and parametric model pole-zero locations together.
    fit_color = [0, 0.25, 1];
    parametric_color = [1, 0, 0];

    hold on
    plot_model_poles_and_zeros(tf_fit, fit_color);
    plot_model_poles_and_zeros(tf_parametric, parametric_color);
    xline(0, 'k:');
    yline(0, 'k:');
    grid on
    box on
    axis equal
    xlabel('Real');
    ylabel('Imaginary');
    title('Poles and Zeros');

    fit_legend = plot(nan, nan, '-', 'Color', fit_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{fit}');
    parametric_legend = plot(nan, nan, '-', 'Color', parametric_color, 'LineWidth', 1.6, ...
        'DisplayName', 'tf_{parametric}');
    legend([fit_legend, parametric_legend], 'Location', 'best');
end

function plot_model_poles_and_zeros(sys, marker_color)
    % Draw poles as x markers and zeros as circle markers.
    poles = pole(sys);
    zeros = zero(sys);

    if ~isempty(zeros)
        plot(real(zeros), imag(zeros), 'o', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
    if ~isempty(poles)
        plot(real(poles), imag(poles), 'x', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
end
