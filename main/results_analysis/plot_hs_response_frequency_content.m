function plot_hs_response_frequency_content(hs, selected_response, ...
        unit_scale_response, fs_hz, fmax_hz, test_duration_s, ag_sample)
%PLOT_HS_RESPONSE_FREQUENCY_CONTENT Plot vHS-style floor response FFT.
% Units: response [m], fs/fmax [Hz], duration [s], ag [m/s^2].

if nargin < 5 || isempty(fmax_hz)
    fmax_hz = 100;
end
if nargin < 6 || isempty(test_duration_s)
    test_duration_s = (size(selected_response, 1)-1)/fs_hz;
end
if nargin < 7
    ag_sample = [];
end

context = hs_frequency_context(hs, fs_hz, fmax_hz, test_duration_s, ...
    ag_sample);
n_story = size(selected_response, 2);
figure('Color', 'w', 'Name', 'HS response frequency content');
layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    yyaxis(ax, 'left')
    h_unit = gobjects(0);
    if ~isempty(unit_scale_response)
        [Y_unit, freq_unit] = fft_c(unit_scale_response(:, floor_id), ...
            fs_hz, fmax_hz);
        h_unit = plot(ax, freq_unit, abs(Y_unit), '-', ...
            'Color', [0.55 0.55 0.55], 'LineWidth', 1.0, ...
            'DisplayName', 'Time scale = 1');
    end
    hold(ax, 'on')

    [Y_selected, freq_selected] = fft_c(selected_response(:, floor_id), ...
        fs_hz, fmax_hz);
    h_selected = plot(ax, freq_selected, abs(Y_selected), '-', ...
        'Color', [0 0.486 0.659], 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Selected = %.3g', hs.time_scale_factor));

    for mode_id = 1:numel(context.mode_frequency_hz)
        xline(ax, context.mode_frequency_hz(mode_id), 'k--', ...
            'HandleVisibility', 'off', 'LineWidth', 0.8);
    end
    ylabel(ax, sprintf('|Floor %d| (m)', floor_id));

    h_eq = gobjects(0);
    if ~isempty(context.eq_freq_hz)
        yyaxis(ax, 'right')
        h_eq = area(ax, context.eq_freq_hz, context.eq_fft_abs, ...
            'FaceColor', [0.9 0.1 0.1], 'FaceAlpha', 0.18, ...
            'EdgeColor', 'none', 'DisplayName', 'Selected earthquake');
        ylabel(ax, '|ag(f)| (m/s^2)');
        ax.YAxis(2).Color = [0.7 0 0];
    end
    yyaxis(ax, 'left')
    ax.YAxis(1).Color = [0 0 0];
    hold(ax, 'off')
    grid(ax, 'on')
    xlim(ax, [0 fmax_hz]);

    if floor_id == 1
        legend_handles = [h_eq h_selected h_unit];
        legend_handles = legend_handles(isvalid(legend_handles));
        legend_handle = legend(ax, legend_handles, 'Location', 'best');
        legend_handle.ItemHitFcn = @toggleSignalVisibility;
    end
end
xlabel(ax, 'Frequency (Hz)');
title(layout, sprintf(['%s: response frequency content; test duration = ' ...
    '%.2f s'], hs.earthquake_type, test_duration_s));
subtitle(layout, ['Hybrid Simulation floor response, one-sided FFT ' ...
    'amplitude; dashed lines = modal frequencies']);
linkaxes(findall(gcf, 'Type', 'axes'), 'x');
end

function toggleSignalVisibility(~, event)
% Units: plotted data and axis limits pass through unchanged.
ax = ancestor(event.Peer, 'axes');
x_limits = xlim(ax);
y_limits = ylim(ax);
if strcmp(event.Peer.Visible, 'on')
    event.Peer.Visible = 'off';
else
    event.Peer.Visible = 'on';
end
xlim(ax, x_limits);
ylim(ax, y_limits);
set(ax, 'XLimMode', 'manual', 'YLimMode', 'manual')
end
