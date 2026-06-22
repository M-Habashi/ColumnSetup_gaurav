function selected_window = select_recording_time_window(t, y, preview_function)
%SELECT_RECORDING_TIME_WINDOW Select a time window using draggable handles.
% Units: t and selected_window are s; y and plotted displacement preserve
% the caller's unit (normally stored mm).

    if nargin < 3
        preview_function = [];
    end

    t = t(:);
    y = y(:);

    selected_window = [t(1), t(end)];
    fig = figure('Name', 'Select recording trim window', ...
        'NumberTitle', 'off', 'Color', 'w');
    ax = axes(fig, 'Position', [0.13 0.20 0.775 0.72]);
    plot(ax, t, y, 'Color', [0 0.486 0.659], 'LineWidth', 1.2)
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
    preview_text = uicontrol(fig, 'Style', 'text', 'String', '', ...
        'Units', 'normalized', 'Position', [0.1 0.09 0.8 0.06], ...
        'BackgroundColor', 'w', 'FontWeight', 'bold', 'FontSize', 11);

    dragging_side = 0;
    set(fig, 'WindowButtonMotionFcn', @drag_window_handle, ...
        'WindowButtonUpFcn', @(~,~)stop_drag());
    update_preview()
    uiwait(fig)

    if isvalid(fig)
        close(fig)
    end

    selected_window = sort(selected_window);

    function start_drag(side)
        % Units: side is a unitless index.
        dragging_side = side;
    end

    function stop_drag()
        % Units: callback state is unitless.
        if dragging_side ~= 0
            update_preview()
        end
        dragging_side = 0;
    end

    function drag_window_handle(~, ~)
        % Units: pointer x-coordinate and selected window are s.
        if dragging_side == 0
            return
        end
        cp = get(ax, 'CurrentPoint');
        selected_window(dragging_side) = min(max(cp(1, 1), t(1)), t(end));
        update_window()
    end

    function update_window()
        % Units: selected window is s; y-axis limits preserve y units.
        x1 = selected_window(1);
        x2 = selected_window(2);
        set(patch_handle, 'XData', [x1, x2, x2, x1])
        set(left_line, 'XData', [x1, x1])
        set(right_line, 'XData', [x2, x2])
        drawnow limitrate
    end

    function update_preview()
        if ~isempty(preview_function)
            preview_text.String = preview_function(sort(selected_window));
            drawnow
        end
    end
end
