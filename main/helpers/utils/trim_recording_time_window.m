function data = trim_recording_time_window(data, preview_function)
%TRIM_RECORDING_TIME_WINDOW Select and apply a time-window trim to recording data.
% Units: time and trim window are s; all signal fields retain their original units.

    if nargin < 2
        preview_function = [];
    end

    [t, y] = get_time_and_displacement(data);
    t = t(:);
    y = y(:);

    selected_window = select_recording_time_window(t, y, preview_function);
    keep = t >= selected_window(1) & t <= selected_window(2);
    data = trim_data(data, keep, selected_window, t);
    data.trim_time_window = selected_window;
end

function [t, y] = get_time_and_displacement(data)
% Units: t is s; y preserves stored displacement units (normally mm).
    if isfield(data, 'dm')
        y = data.dm;
        t = get_time_vector(data, numel(y));
        return
    end

    if isfield(data, 'x')
        y = data.x;
        t = get_time_vector(data, numel(y));
        return
    end

    sig = data.logsout.FileLogSignals{1}.Values;
    signal_names = string({sig.DataInfo.Units});
    t = sig.Time;
    y = sig.Data(:, strcmpi(signal_names, 'dm'));
end

function t = get_time_vector(data, n)
% Units: output t is s; n is a unitless sample count.
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
end

function data = trim_data(data, keep, selected_window, t)
% Units: selected_window and t are s; signal field units pass through unchanged.
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
% Units: value preserves its input unit; keep and n are unitless indexing data.
    if isvector(value) && numel(value) == n
        value = value(keep);
    elseif size(value, 1) == n
        value = value(keep, :);
    elseif size(value, 2) == n
        value = value(:, keep);
    end
end

function logsout = trim_logsout(logsout, selected_window)
% Units: selected_window is s; logged signal units pass through unchanged.
    sig = logsout.FileLogSignals{1}.Values;
    keep = sig.Time >= selected_window(1) & sig.Time <= selected_window(2);
    sig = getsamples(sig, find(keep));
    logsout.FileLogSignals{1}.Values = sig;
end
