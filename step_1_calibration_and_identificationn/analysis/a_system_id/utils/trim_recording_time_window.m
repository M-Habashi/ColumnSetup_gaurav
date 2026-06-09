function data = trim_recording_time_window(data)
%TRIM_RECORDING_TIME_WINDOW Select and apply a time-window trim to recording data.

    [t, dm] = get_time_and_displacement(data);
    t = t(:);
    dm = dm(:);

    selected_window = [t(1), t(end)];
    fig = figure('Name', 'Select recording trim window', ...
        'NumberTitle', 'off', 'Color', 'w');
    ax = axes(fig);
    plot(ax, t, dm, 'Color', [0 0.486 0.659], 'LineWidth', 1.2)
    grid(ax, 'on')
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'Measured displacement')
    title(ax, 'Drag the yellow window handles, then click Continue')
    hold(ax, 'on')

    yl = ylim(ax);
    patch_handle = patch(ax, ...
        [selected_window(1), selected_window(2), selected_window(2), selected_window(1)], ...
        [yl(1), yl(1), yl(2), yl(2)], ...
        [1 0.85 0], 'FaceAlpha', 0.22, 'EdgeColor', 'none');
    left_line = plot(ax, selected_window([1 1]), yl, 'Color', [0.85 0.55 0], ...
        'LineWidth', 2.5, 'ButtonDownFcn', @(~,~)start_drag(1));
    right_line = plot(ax, selected_window([2 2]), yl, 'Color', [0.85 0.55 0], ...
        'LineWidth', 2.5, 'ButtonDownFcn', @(~,~)start_drag(2));
    uistack(patch_handle, 'bottom')

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Continue', ...
        'Units', 'normalized', 'Position', [0.43 0.01 0.14 0.06], ...
        'Callback', @(~,~)uiresume(fig));

    dragging_side = 0;
    set(fig, 'WindowButtonMotionFcn', @drag_window_handle, ...
        'WindowButtonUpFcn', @(~,~)stop_drag());
    uiwait(fig)

    if isvalid(fig)
        close(fig)
    end

    selected_window = sort(selected_window);
    keep = t >= selected_window(1) & t <= selected_window(2);
    data = trim_data(data, keep, selected_window, t);
    data.trim_time_window = selected_window;

    function start_drag(side)
        dragging_side = side;
    end

    function stop_drag()
        dragging_side = 0;
    end

    function drag_window_handle(~, ~)
        if dragging_side == 0
            return
        end
        cp = get(ax, 'CurrentPoint');
        x = min(max(cp(1, 1), t(1)), t(end));
        selected_window(dragging_side) = x;
        update_window()
    end

    function update_window()
        x1 = selected_window(1);
        x2 = selected_window(2);
        set(patch_handle, 'XData', [x1, x2, x2, x1])
        set(left_line, 'XData', [x1, x1])
        set(right_line, 'XData', [x2, x2])
        drawnow limitrate
    end
end

function [t, dm] = get_time_and_displacement(data)
    if isfield(data, 'dm')
        dm = data.dm;
        n = numel(dm);
        if isfield(data, 't') && numel(data.t) == n
            t = data.t;
        elseif isfield(data, 'tt') && numel(data.tt) == n
            t = data.tt;
        elseif isfield(data, 'fs')
            t = (0:n-1).' / data.fs;
        elseif isfield(data, 'dt')
            t = (0:n-1).' * data.dt;
        else
            t = (1:n).';
        end
        return
    end

    sig = data.logsout.FileLogSignals{1}.Values;
    signal_names = string({sig.DataInfo.Units});
    t = sig.Time;
    dm = sig.Data(:, strcmpi(signal_names, 'dm'));
end

function data = trim_data(data, keep, selected_window, t)
    n = numel(keep);
    names = fieldnames(data);
    for i = 1:numel(names)
        value = data.(names{i});
        if isnumeric(value)
            data.(names{i}) = trim_numeric(value, keep, n);
        end
    end

    if isfield(data, 'logsout')
        data.logsout = trim_logsout(data.logsout, selected_window);
    end

    if isfield(data, 't')
        data.t = t(keep);
    end
end

function value = trim_numeric(value, keep, n)
    if isvector(value) && numel(value) == n
        value = value(keep);
    elseif size(value, 1) == n
        value = value(keep, :);
    elseif size(value, 2) == n
        value = value(:, keep);
    end
end

function logsout = trim_logsout(logsout, selected_window)
    sig = logsout.FileLogSignals{1}.Values;
    keep = sig.Time >= selected_window(1) & sig.Time <= selected_window(2);
    sig = getsamples(sig, find(keep));
    logsout.FileLogSignals{1}.Values = sig;
end
