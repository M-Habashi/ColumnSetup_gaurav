function interactive_validation_metrics
%INTERACTIVE_VALIDATION_METRICS Inspect J1-J7 over a draggable time region.
% Units: t/window [s], dd/dc/dm [mm], J1 [ms], J2-J7 [%].

script_folder = fileparts(mfilename('fullpath'));
project_folder = fileparts(script_folder);
addpath(script_folder)
addpath(fullfile(project_folder, 'helpers', 'utils'))
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'))

[data, ~, file_name] = load_saved_result_file( ...
    project_folder, 'tests', false, '', false);
assert(isfield(data, 'result') && isstruct(data.result), ...
    'The selected file must contain one top-level result struct.')
result = data.result;

options = struct('plot', false);
if isfield(result, 'hs') && isstruct(result.hs) && isfield(result.hs, 'fem')
    [~, comparison] = compare_hs_response_to_reference( ...
        result.hs.fem, result, [], [], [], [], options);
else
    [~, comparison] = compare_hs_response_to_reference( ...
        [], result, [], [], [], [], options);
end

n = min([numel(comparison.t), numel(result.dd), numel(result.dc), ...
    numel(result.dm), numel(comparison.dm_filtfilt), ...
    numel(comparison.u_control_test_mm)]);
t = comparison.t(1:n);
dd = result.dd(1:n);
d_n = comparison.u_control_test_mm(1:n);
dc = result.dc(1:n);
dm = result.dm(1:n);
dm_filtfilt = comparison.dm_filtfilt(1:n);
running = comparison.pause_enable(1:n) == 0;
selected_window = [t(1), t(end)];

colors.black = [0 0 0];
colors.copperwood = sscanf('AC6420', '%2x%2x%2x', [1 3])/255;
colors.blue = sscanf('007CA8', '%2x%2x%2x', [1 3])/255;

fig = figure('Name', ['Interactive J1-J7 - ' file_name], ...
    'NumberTitle', 'off', 'Color', 'w', 'WindowState', 'maximized');
ax = axes(fig, 'Position', [0.07 0.34 0.90 0.61]);
max_plot_points = 50000;
plot_step = max(1, ceil(n/max_plot_points));
plot_index = unique([1:plot_step:n, n]);

plot(ax, t(plot_index), dd(plot_index), '--', ...
    'Color', colors.black, 'LineWidth', 1.8, 'DisplayName', 'dd');
hold(ax, 'on')
plot(ax, t(plot_index), d_n(plot_index), '--', ...
    'Color', colors.black, 'LineWidth', 2.2, ...
    'DisplayName', 'd_n (replayed)');
plot(ax, t(plot_index), dc(plot_index), '-', ...
    'Color', colors.copperwood, 'LineWidth', 1.0, 'DisplayName', 'dc');
plot(ax, t(plot_index), dm(plot_index), '-', ...
    'Color', colors.blue, 'LineWidth', 1.0, 'DisplayName', 'dm');
plot(ax, t(plot_index), dm_filtfilt(plot_index), '-', ...
    'Color', colors.blue, 'LineWidth', 1.4, 'DisplayName', 'dm_filtfilt');
grid(ax, 'on')
xlabel(ax, 'Time (s)')
ylabel(ax, 'Displacement (mm)')
title(ax, sprintf('%s - drag the yellow boundaries to evaluate J1-J7', ...
    file_name), 'Interpreter', 'none')
plot_legend = legend(ax, 'Location', 'best');
plot_legend.ItemHitFcn = @toggle_signal_visibility;
xlim(ax, [t(1), t(end)])

yl = ylim(ax);
window_patch = patch(ax, selected_window([1 2 2 1]), yl([1 1 2 2]), ...
    [1 0.85 0], 'FaceAlpha', 0.16, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
left_line = plot(ax, selected_window([1 1]), yl, ...
    'Color', [0.85 0.55 0], 'LineWidth', 3, 'HandleVisibility', 'off', ...
    'ButtonDownFcn', @(~, ~)start_drag(1));
right_line = plot(ax, selected_window([2 2]), yl, ...
    'Color', [0.85 0.55 0], 'LineWidth', 3, 'HandleVisibility', 'off', ...
    'ButtonDownFcn', @(~, ~)start_drag(2));
uistack(window_patch, 'bottom')

window_label = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.07 0.295 0.90 0.035], 'BackgroundColor', 'w', ...
    'FontSize', 11, 'FontWeight', 'bold');
metric_labels = gobjects(7, 1);
for metric_id = 1:7
    if metric_id <= 4
        position = [0.07 + 0.225*(metric_id - 1), 0.17, 0.205, 0.10];
    else
        position = [0.18 + 0.225*(metric_id - 5), 0.045, 0.205, 0.10];
    end
    metric_labels(metric_id) = uicontrol(fig, 'Style', 'text', ...
        'Units', 'normalized', 'Position', position, ...
        'BackgroundColor', [0.96 0.96 0.96], 'FontSize', 11, ...
        'FontWeight', 'bold');
end

dragging_side = 0;
set(fig, 'WindowButtonMotionFcn', @drag_window_handle, ...
    'WindowButtonUpFcn', @(~, ~)stop_drag());
update_display()

    function start_drag(side)
        dragging_side = side;
    end

    function stop_drag()
        dragging_side = 0;
        update_display()
    end

    function toggle_signal_visibility(~, event)
        if strcmp(event.Peer.Visible, 'on')
            event.Peer.Visible = 'off';
        else
            event.Peer.Visible = 'on';
        end
    end

    function drag_window_handle(~, ~)
        if dragging_side == 0
            return
        end
        point = get(ax, 'CurrentPoint');
        selected_window(dragging_side) = min(max(point(1, 1), t(1)), t(end));
        selected_window = sort(selected_window);
        update_window_graphics()
    end

    function update_display()
        update_window_graphics()

        keep = t >= selected_window(1) & t <= selected_window(2) & running;
        values = calculate_metrics(keep);
        window_label.String = sprintf( ...
            'Selected running data: %.4g to %.4g s | %.4g s | %d samples', ...
            selected_window(1), selected_window(2), ...
            diff(selected_window), nnz(keep));
        descriptions = {'tracking delay', 'tracking RMS', 'tracking peak', ...
            'floor 1 RMS', 'floor 2 RMS', 'floor 3 RMS', 'interface NMSE'};
        units = {'ms', '%', '%', '%', '%', '%', '%'};
        for id = 1:7
            metric_labels(id).String = sprintf('J%d  %.4g %s\n%s', ...
                id, values(id), units{id}, descriptions{id});
        end
        drawnow
    end

    function update_window_graphics()
        yl_now = ylim(ax);
        set(window_patch, 'XData', selected_window([1 2 2 1]), ...
            'YData', yl_now([1 1 2 2]))
        set(left_line, 'XData', selected_window([1 1]), 'YData', yl_now)
        set(right_line, 'XData', selected_window([2 2]), 'YData', yl_now)
        drawnow limitrate
    end

    function values = calculate_metrics(keep)
        values = nan(7, 1);
        if nnz(keep) < 2
            return
        end
        metric = validation_metrics();
        u_test = comparison.u_test(1:n, :);
        u_reference = comparison.u_reference(1:n, :);
        d_r = 1000*comparison.u_control_reference(1:n);
        values = [metric.J1(dm_filtfilt(keep), d_n(keep), result.dt); ...
            metric.J2(dm_filtfilt(keep), d_n(keep)); ...
            metric.J3(dm_filtfilt(keep), d_n(keep)); ...
            metric.J4(u_test(keep, 1), u_reference(keep, 1)); ...
            metric.J5(u_test(keep, 2), u_reference(keep, 2)); ...
            metric.J6(u_test(keep, 3), u_reference(keep, 3)); ...
            metric.J7(dm_filtfilt(keep), d_r(keep))];
    end
end
