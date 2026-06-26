function run_data = plot_sys_id_model_run(model_results_file)
%PLOT_SYS_ID_MODEL_RUN Recreate sys_id plots from a saved model run.
% Units: saved data keeps the units recorded by sys_id.m; frequency axes are
% Hz, time is seconds, and displacement is plotted in the saved signal units.

    helper_root = fileparts(mfilename('fullpath'));
    step_root = fileparts(fileparts(fileparts(helper_root)));
    addpath(fullfile(step_root, 'helpers', 'utils'))

    if nargin < 1 || isempty(model_results_file)
        [run_data, model_results_file] = load_saved_result_file( ...
            step_root, 'exp_tf');
    elseif isstruct(model_results_file)
        run_data = model_results_file;
        model_results_file = 'loaded workspace';
    else
        run_data = load(model_results_file);
    end

    fprintf('\nPlotting saved system-identification run = %s\n', ...
        model_results_file)
    plot_time_series(run_data)
    plot_pole_zero(run_data)
    plot_bode(run_data)
end

function plot_time_series(run_data)
    ts = run_data.time_series_fit;
    figure('Name', 'Time-Series Model Comparison', 'Color', 'w')
    plot(ts.time, ts.dm, '-', 'Color', [0 0.486 0.659], ...
        'LineWidth', 1.2, 'DisplayName', 'dm')
    hold on
    plot(ts.time, ts.dm_H_dd_dm, '-', 'Color', [0.224 0.749 0.369], ...
        'LineWidth', 1.4, 'DisplayName', 'H_{dd to dm}')
    plot(ts.time, ts.dm_PID_H_dc_dm, '-', 'Color', [0.675 0.392 0.125], ...
        'LineWidth', 1.4, 'DisplayName', 'PID + H_{dc to dm}')
    plot(ts.time, ts.dm_PID_H_dc_dm_random_noise, '--', ...
        'Color', [0.565 0.082 0], 'LineWidth', 1.4, ...
        'DisplayName', 'PID + H_{dc to dm} + random noise')
    grid on
    xlabel('Time (s)')
    ylabel('Displacement')
    title('Time-Series Model Comparison')
    lgd = legend('Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
end

function plot_pole_zero(run_data)
    models = run_data.models;
    pole_zero_systems = {models.H_dc_dm_d, models.H_dd_dm_d, ...
        models.PID_H_dc_dm, models.optimized_PID_H_dc_dm};
    labels = {'H_{dc to dm}', 'H_{dd to dm}', 'PID + H_{dc to dm}', ...
        'Optimized PID + H_{dc to dm}'};
    colors = {[0.675 0.392 0.125], [0 0.486 0.659], ...
        [0.224 0.749 0.369], [0.565 0.082 0]};

    figure('Name', 'Digital Controller Pole-Zero Comparison', 'Color', 'w')
    hold on
    legend_items = gobjects(numel(pole_zero_systems), 1);
    for i = 1:numel(pole_zero_systems)
        poles = pole(pole_zero_systems{i});
        zeros_ = zero(pole_zero_systems{i});
        pole_points = plot(real(poles), imag(poles), 'x', 'Color', colors{i}, ...
            'LineWidth', 1.6, 'MarkerSize', 9, ...
            'HandleVisibility', 'off');
        zero_points = plot(real(zeros_), imag(zeros_), 'o', 'Color', colors{i}, ...
            'LineWidth', 1.4, 'MarkerSize', 7, ...
            'HandleVisibility', 'off');
        legend_items(i) = plot(nan, nan, '-', 'Color', colors{i}, ...
            'LineWidth', 1.4, 'DisplayName', labels{i});
        setappdata(legend_items(i), 'LinkedLegendItems', ...
            [pole_points, zero_points, legend_items(i)]);
    end
    theta = linspace(0, 2*pi, 400);
    plot(cos(theta), sin(theta), 'k:', 'HandleVisibility', 'off')
    xline(0, 'k:')
    yline(0, 'k:')
    grid on
    axis equal
    xlabel('Real Axis (z)')
    ylabel('Imaginary Axis (z)')
    title('Discrete Pole-Zero Comparison')
    lgd = legend(legend_items, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
end

function plot_bode(run_data)
    c = run_data.model_metadata.fit_config;
    freq_hz = logspace(log10(c.f_lim(1)), log10(c.f_lim(2)), 800);
    freq_rad = 2*pi*freq_hz;
    models = run_data.models;
    systems = {models.H_dc_dm, models.H_dd_dm, models.PID_H_dc_dm, ...
        models.optimized_PID_H_dc_dm, models.H_dc_dm_param};
    labels = {'H\_dc\_dm', 'H\_dd\_dm', 'PID + H\_dc\_dm', ...
        'Optimized PID + H\_dc\_dm', 'H\_dc\_dm\_param'};
    colors = {[0.675 0.392 0.125], [0 0.486 0.659], ...
        [0.224 0.749 0.369], [0.565 0.082 0], [0 0 0]};

    figure('Name', 'Digital Controller Bode Comparison', 'Color', 'w')
    tiledlayout(2, 1)
    ax_mag = nexttile;
    hold(ax_mag, 'on')
    ax_phase = nexttile;
    hold(ax_phase, 'on')
    mag_lines = gobjects(numel(systems), 1);
    phase_lines = gobjects(numel(systems), 1);
    for i = 1:numel(systems)
        response = squeeze(freqresp(systems{i}, freq_rad));
        mag_lines(i) = semilogx(ax_mag, freq_hz, 20*log10(abs(response)), ...
            'Color', colors{i}, 'LineWidth', 1.4, ...
            'DisplayName', labels{i});
        phase_lines(i) = semilogx(ax_phase, freq_hz, ...
            unwrap(angle(response))*180/pi, ...
            'Color', colors{i}, 'LineWidth', 1.4, ...
            'HandleVisibility', 'off');
        setappdata(mag_lines(i), 'LinkedLegendItems', ...
            [mag_lines(i), phase_lines(i)]);
    end

    scatter(ax_mag, run_data.H_dc_dm_xfunc.freq_hz, ...
        20*log10(abs(run_data.H_dc_dm_xfunc.points)), 10, colors{1}, ...
        'filled', 'MarkerFaceAlpha', 0.2, 'HandleVisibility', 'off')
    scatter(ax_mag, run_data.H_dd_dm_xfunc.freq_hz, ...
        20*log10(abs(run_data.H_dd_dm_xfunc.points)), 10, colors{2}, ...
        'filled', 'MarkerFaceAlpha', 0.2, 'HandleVisibility', 'off')
    scatter(ax_phase, run_data.H_dc_dm_xfunc.freq_hz, ...
        unwrap(angle(run_data.H_dc_dm_xfunc.points))*180/pi, 10, ...
        colors{1}, 'filled', 'MarkerFaceAlpha', 0.2, ...
        'HandleVisibility', 'off')
    scatter(ax_phase, run_data.H_dd_dm_xfunc.freq_hz, ...
        unwrap(angle(run_data.H_dd_dm_xfunc.points))*180/pi, 10, ...
        colors{2}, 'filled', 'MarkerFaceAlpha', 0.2, ...
        'HandleVisibility', 'off')

    grid(ax_mag, 'on')
    grid(ax_phase, 'on')
    ylabel(ax_mag, 'Magnitude (dB)')
    ylabel(ax_phase, 'Phase (deg)')
    xlabel(ax_phase, 'Frequency (Hz)')
    title(ax_mag, 'Experimental and Digital-Controller System Comparison')
    lgd = legend(ax_mag, mag_lines, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
end

function toggle_legend_item(~, event)
    targets = event.Peer;
    linked_items = getappdata(event.Peer, 'LinkedLegendItems');
    if ~isempty(linked_items)
        targets = linked_items;
    end
    if strcmp(event.Peer.Visible, 'on')
        set(targets, 'Visible', 'off');
    else
        set(targets, 'Visible', 'on');
    end
end
