%% Digital Controller Tuning
% Tune the digital PI controller around one identified analog closed-loop model.
% Research-only analysis: saved controller results do not affect simulations.

%% Units
% Transfer functions, controller gains, and response amplitudes are
% dimensionless. Time is s, frequency is Hz or rad/s, phase is deg.

clear
clc
close all
rng(0);

%% Inputs
controller_name = "controller_digital_01";
model_source = "fit";          % "fit" for red tf_fit, "paarametric" for tf_parametric
digital_phase_margin = 70;
digital_bandwidth = 20;

%% Setup
project_root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(project_root));
addpath(step_root);
addpaths();

model_source = normalize_model_source(model_source);
[model_data, model_file, model_file_name] = load_saved_result_file(step_root, fullfile('models', model_source));
[analog_cl, model_label] = get_analog_closed_loop_model(model_data, model_source);
analog_cl = minreal(analog_cl, [], false);
[~, model_name] = fileparts(model_file);

if strlength(strtrim(controller_name)) == 0
    controller_name = sprintf('%s_digital', model_name);
end
controller_file_name = regexprep(char(controller_name), '[^\w.-]', '_');
saved_controller_dir = fullfile(step_root, 'saved_results', 'controllers');
if ~exist(saved_controller_dir, 'dir')
    mkdir(saved_controller_dir);
end

%% Digital Tuning
optimize_choice = input('Do you want to optimize digital settling time? [y/n]: ', 's');
if strcmpi(optimize_choice, 'y')
    tuning = optimize_digital_tuning(analog_cl, struct( ...
        'x0', [digital_phase_margin, digital_bandwidth]));
    digital_phase_margin = tuning.x(1);
    digital_bandwidth = tuning.x(2);
    digital_cntrlr = tuning.digital_cntrlr;
    digital_cl = tuning.digital_cl;
else
    opts = pidtuneOptions('PhaseMargin', digital_phase_margin);
    [digital_cntrlr, ~] = pidtune(analog_cl, 'PI', digital_bandwidth, opts);
    digital_cl = feedback(digital_cntrlr * analog_cl, 1);
end

info_analog = stepinfo(analog_cl);
info_digital = stepinfo(digital_cl);
digital_Kp = digital_cntrlr.Kp;
digital_Ki = digital_cntrlr.Ki;

controller_save_path = fullfile(saved_controller_dir, sprintf('%s.mat', controller_file_name));
save(controller_save_path, ...
    'controller_name', ...
    'model_source', ...
    'model_file', ...
    'model_file_name', ...
    'model_label', ...
    'digital_phase_margin', ...
    'digital_bandwidth', ...
    'digital_Kp', ...
    'digital_Ki', ...
    'analog_cl', ...
    'digital_cntrlr', ...
    'digital_cl');

%% Summary
fprintf('\n%% ========================================\n');
fprintf('%% Digital Controller Tuning Summary\n');
fprintf('%% ========================================\n');
fprintf('%% Model source = %s\n', char(model_source));
fprintf('%% Model file   = %s\n', model_file_name);
fprintf('%% Model used   = %s\n', model_label);
fprintf('%% Digital PI controller\n');
fprintf('%%   phase margin target = %.6g deg\n', digital_phase_margin);
fprintf('%%   bandwidth target    = %.6g rad/s\n', digital_bandwidth);
fprintf('%%   Kp = %.12g\n', digital_Kp);
fprintf('%%   Ki = %.12g\n', digital_Ki);
fprintf('%% Step response\n');
fprintf('%%   Analog closed-loop settling time  = %.6g s\n', info_analog.SettlingTime);
fprintf('%%   Digital closed-loop settling time = %.6g s\n', info_digital.SettlingTime);
fprintf('%% Saved controller = %s\n', controller_save_path);
fprintf('%% ========================================\n');

%% Plots
plot_colors = get_plot_colors();
figure('Name', 'Digital Tuning Step Responses', 'Color', 'w');
plot_step_toggle_compare(gca, {analog_cl, digital_cl}, ...
    [info_analog.SettlingTime, info_digital.SettlingTime], ...
    {sprintf('Analog closed loop (%s)', model_label), 'Digital closed loop'}, ...
    'Digital Controller Tuning', ...
    {plot_colors.blue, plot_colors.purple});

bode_freq_hz = logspace(-1, 2, 600);
figure('Name', 'Digital Tuning Bode Diagrams', 'Color', 'w');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
plot_bode_compare(nexttile, nexttile, {analog_cl, digital_cl}, ...
    {sprintf('Analog closed loop (%s)', model_label), 'Digital closed loop'}, ...
    'Digital Controller Tuning', bode_freq_hz, ...
    {plot_colors.blue, plot_colors.purple});

figure('Name', 'Digital Tuning Poles and Zeros', 'Color', 'w');
plot_pole_zero_compare(gca, {analog_cl, digital_cl}, ...
    {sprintf('Analog closed loop (%s)', model_label), 'Digital closed loop'}, ...
    'Digital Controller Tuning', ...
    {plot_colors.blue, plot_colors.purple});

function model_source = normalize_model_source(model_source)
% Units: input and output labels are unitless text.
    model_source = lower(strtrim(string(model_source)));
    if any(model_source == ["parametric", "paarametric"])
        model_source = "paarametric";
    elseif model_source == "fit"
        model_source = "fit";
    else
        error('model_source must be "fit" or "paarametric".');
    end
end

function [analog_cl, model_label] = get_analog_closed_loop_model(model_data, model_source)
% Units: model transfer function and label are dimensionless.
    if model_source == "fit"
        analog_cl = model_data.tf_fit;
        model_label = 'tf_fit (red)';
    else
        assert(isfield(model_data, 'id_units') ...
            && isfield(model_data.id_units, 'schema_version') ...
            && model_data.id_units.schema_version >= 2, ...
            ['The selected parametric model predates the SI-unit correction. ' ...
             'Rerun sys_id.m before tuning.']);
        analog_cl = model_data.tf_parametric;
        model_label = 'tf_parametric';
    end
end

function tuning = optimize_digital_tuning(analog_cl, opts)
% Units: analog_cl is dimensionless; phase settings are deg, bandwidth Hz, time s.
    defaults = struct( ...
        'x0', [70, 20], ...
        'lb', [30, 1], ...
        'ub', [85, 200], ...
        'num_random_starts', 6);
    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end

    seeds = [opts.x0; 45 30; 60 60; 70 100; 80 140];
    seeds = [seeds; opts.lb + rand(opts.num_random_starts, 2) .* (opts.ub - opts.lb)];
    optim_opts = optimoptions('fmincon', ...
        'Display', 'off', ...
        'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 300, ...
        'MaxIterations', 80);

    best.f = Inf;
    best.x = opts.x0;
    fprintf('\n%% ========================================\n');
    fprintf('%% Digital Settling-Time Optimization\n');
    fprintf('%% ========================================\n');
    fprintf('%% Optimization Progress: 000%%');
    warning_state = warning;
    warning('off', 'all');
    cleanup_warnings = onCleanup(@() warning(warning_state));
    for i = 1:size(seeds, 1)
        x0 = min(max(seeds(i, :), opts.lb), opts.ub);
        [x_try, f_try] = fmincon(@(x)digital_objective(x, analog_cl), ...
            x0, [], [], [], [], opts.lb, opts.ub, ...
            @(x)digital_constraint(x, analog_cl), optim_opts);
        if f_try < best.f
            best.f = f_try;
            best.x = x_try;
        end
        fprintf('\b\b\b\b%3d%%', floor(i / size(seeds, 1) * 100));
    end
    clear cleanup_warnings
    fprintf('\n');

    [digital_cntrlr, digital_cl] = build_digital_loop(best.x, analog_cl);
    tuning.x = best.x;
    tuning.digital_cntrlr = digital_cntrlr;
    tuning.digital_cl = digital_cl;
    tuning.cost = best.f;
    tuning.digital_settling_time = stepinfo(digital_cl).SettlingTime;
end

function f = digital_objective(x, analog_cl)
% Units: x is [deg, Hz], analog_cl is dimensionless, objective is s.
    try
        [~, digital_cl] = build_digital_loop(x, analog_cl);
        info_d = stepinfo(digital_cl);
        f = info_d.SettlingTime;
        if ~isfinite(f) || f <= 0 || ~isstable(digital_cl)
            f = 1e6;
        end
    catch
        f = 1e6;
    end
end

function [c, ceq] = digital_constraint(x, analog_cl)
% Units: x is [deg, Hz]; constraints are normalized dimensionless values.
    ceq = [];
    try
        [~, digital_cl] = build_digital_loop(x, analog_cl);
        c = stepinfo(digital_cl).Peak - 1.2;
        if ~isfinite(c)
            c = 1;
        end
    catch
        c = 1;
    end
end

function [digital_cntrlr, digital_cl] = build_digital_loop(x, analog_cl)
% Units: x is [deg, Hz]; transfer functions and controller are dimensionless.
    opts_d = pidtuneOptions('PhaseMargin', x(1));
    [digital_cntrlr, ~] = pidtune(analog_cl, 'PI', x(2), opts_d);
    digital_cl = feedback(digital_cntrlr * analog_cl, 1);
end

function plot_step_toggle_compare(ax, systems, settling_times, labels, plot_title, colors)
% Units: step amplitude is dimensionless, time and settling times are s.
    hold(ax, 'on')
    for i = 1:numel(systems)
        [y, t] = step(systems{i});
        plot(ax, t(:), squeeze(y), 'Color', colors{i}, ...
            'LineWidth', 1.4, 'DisplayName', labels{i});
        if isfinite(settling_times(i))
            xline(ax, settling_times(i), ':', 'HandleVisibility', 'off');
        end
    end
    grid(ax, 'on')
    title(ax, plot_title)
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'Response (dimensionless)')
    lgd = legend(ax, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    hold(ax, 'off')
end

function plot_bode_compare(ax_mag, ax_phase, systems, labels, plot_title, freq_hz, colors)
% Units: magnitude is dimensionless (dB), phase deg, frequency Hz.
    freq_rad = 2 * pi * freq_hz;
    hold(ax_mag, 'on')
    hold(ax_phase, 'on')
    for i = 1:numel(systems)
        [mag, phase] = bode(systems{i}, freq_rad);
        semilogx(ax_mag, freq_hz, 20 * log10(squeeze(mag) + eps), ...
            '-', 'Color', colors{i}, 'LineWidth', 1.4, 'DisplayName', labels{i});
        semilogx(ax_phase, freq_hz, unwrap(squeeze(phase) * pi / 180) * 180 / pi, ...
            '-', 'Color', colors{i}, 'LineWidth', 1.4, 'DisplayName', labels{i});
    end
    grid(ax_mag, 'on')
    grid(ax_phase, 'on')
    xlim(ax_mag, [freq_hz(1), freq_hz(end)])
    xlim(ax_phase, [freq_hz(1), freq_hz(end)])
    ylabel(ax_mag, 'Magnitude (dB, dimensionless ratio)')
    ylabel(ax_phase, 'Phase (deg)')
    xlabel(ax_phase, 'Frequency (Hz)')
    title(ax_mag, plot_title)
    lgd = legend(ax_mag, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    lgd = legend(ax_phase, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    hold(ax_mag, 'off')
    hold(ax_phase, 'off')
end

function plot_pole_zero_compare(ax, systems, labels, plot_title, colors)
% Units: pole/zero coordinates are rad/s; handles, labels, and colors are unitless.
    hold(ax, 'on')
    for i = 1:numel(systems)
        plot_model_poles_and_zeros(ax, systems{i}, colors{i});
    end
    xline(ax, 0, 'k:')
    yline(ax, 0, 'k:')
    grid(ax, 'on')
    box(ax, 'on')
    axis(ax, 'equal')
    xlabel(ax, 'Real (rad/s)')
    ylabel(ax, 'Imaginary (rad/s)')
    title(ax, plot_title)

    legend_handles = gobjects(numel(systems), 1);
    for i = 1:numel(systems)
        legend_handles(i) = plot(ax, nan, nan, '-', 'Color', colors{i}, ...
            'LineWidth', 1.6, 'DisplayName', labels{i});
    end
    lgd = legend(ax, legend_handles, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    hold(ax, 'off')
end

function plot_model_poles_and_zeros(ax, sys, marker_color)
% Units: sys is dimensionless; pole/zero coordinates are rad/s.
    zeros = zero(sys);
    poles = pole(sys);
    if ~isempty(zeros)
        plot(ax, real(zeros), imag(zeros), 'o', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
    if ~isempty(poles)
        plot(ax, real(poles), imag(poles), 'x', 'Color', marker_color, ...
            'MarkerSize', 8, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
end

function colors = get_plot_colors()
% Units: RGB outputs are dimensionless.
    colors.black = [0 0 0];
    colors.blue = hex_to_rgb('007CA8');
    colors.copperwood = hex_to_rgb('AC6420');
    colors.green = hex_to_rgb('39BF5E');
    colors.red = hex_to_rgb('901500');
    colors.purple = hex_to_rgb('74058A');
end

function rgb = hex_to_rgb(hex_color)
% Units: hexadecimal input and RGB output are dimensionless.
    rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end

function toggle_legend_item(~, event)
% Units: graphics handles and visibility state are unitless.
    if strcmp(event.Peer.Visible, 'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
end
