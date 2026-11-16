if ~exist('sys', 'var')
    if exist('digital_cntrlr', 'var') && exist('analog_cl', 'var')
        sys = digital_cntrlr * analog_cl;
    else
        mp = 37.8690;
        kp = 1190000;
        zeta = 0.01;
        cp = 2 * zeta * sqrt(kp * mp);

        transfer_sys = inner_open_loop2_with_params(mp, cp, kp);
        opts = pidtuneOptions('PhaseMargin', 60);
        analog_cntrlr = pid(1, 0, 0);
        analog_cl = feedback(analog_cntrlr * transfer_sys, 1);
        digital_cntrlr = pidtune(analog_cl, 'PI', 80, opts);
        sys = digital_cntrlr * analog_cl;
    end
end

font_name = 'Times New Roman';
font_size = 10;
line_main = 1.5;
line_aux = 1.1;

color_main = [0 0 0];
color_neg = [0.70 0.70 0.70];
color_gm = hex2rgb('#0c558e');
color_pm = hex2rgb('#c04a93');
color_gm_light = 0.35 * color_gm + 0.65 * [1 1 1];
color_pm_light = 0.35 * color_pm + 0.65 * [1 1 1];

w_plot = logspace(0, 3, 5000);
[mag, phase, wout] = bode(sys, w_plot);
mag_db = 20 * log10(squeeze(mag));
phase_deg = unwrap(squeeze(phase) * pi / 180) * 180 / pi;
[Gm, Pm, Wcg, Wcp] = margin(sys);
Gm_db = 20 * log10(Gm);

[re, im, w_nyq] = nyquist(sys, w_plot);
re = squeeze(re);
im = squeeze(im);
w_nyq = squeeze(w_nyq);
resp_gm = squeeze(freqresp(sys, Wcg));
resp_pm = squeeze(freqresp(sys, Wcp));

fig = figure('Units', 'inches', ...
    'Position', [0.5 0.5 8.6 5.4], ...
    'Color', 'w');

set(fig, 'DefaultAxesFontName', font_name, ...
    'DefaultAxesFontSize', font_size, ...
    'DefaultTextFontName', font_name, ...
    'DefaultTextFontSize', font_size);

ax_mag = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.56 0.50 0.39]);
hold(ax_mag, 'on');
semilogx(ax_mag, wout, mag_db, 'Color', color_main, 'LineWidth', line_main);
yline(ax_mag, 0, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
plot_vertical(ax_mag, Wcg, color_gm_light);
plot_vertical(ax_mag, Wcp, color_pm_light);
plot(ax_mag, [Wcg Wcg], [0 -Gm_db], 'Color', color_gm, 'LineWidth', 1.4);
style_bode_axes(ax_mag, [1 1000], [-25 30], font_name, font_size);
ylabel(ax_mag, 'Magnitude (dB)', 'FontName', font_name, 'FontSize', font_size + 1);
set(ax_mag, 'XTickLabel', []);

ax_phase = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.16 0.50 0.39]);
hold(ax_phase, 'on');
semilogx(ax_phase, wout, phase_deg, 'Color', color_main, 'LineWidth', line_main);
yline(ax_phase, -180, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);
plot_vertical(ax_phase, Wcg, color_gm_light);
plot_vertical(ax_phase, Wcp, color_pm_light);
phase_at_wcp = interp1(wout, phase_deg, Wcp);
plot(ax_phase, [Wcp Wcp], [-180 phase_at_wcp], 'Color', color_pm, 'LineWidth', 1.4);
style_bode_axes(ax_phase, [1 1000], [-400 -50], font_name, font_size);
set(ax_phase, 'YTick', -360:90:-90);
xlabel(ax_phase, 'Frequency (rad/sec)', 'FontName', font_name, 'FontSize', font_size + 1);
ylabel(ax_phase, 'Phase (deg)', 'FontName', font_name, 'FontSize', font_size + 1);

ax_nyq = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.66 0.16 0.30 0.79]);
hold(ax_nyq, 'on');
plot(ax_nyq, re, im, 'Color', color_main, 'LineWidth', line_main);
plot(ax_nyq, re, -im, 'Color', color_neg, 'LineWidth', line_aux);
theta = linspace(0, 2 * pi, 400);
plot(ax_nyq, cos(theta), sin(theta), '-.', 'Color', color_pm, 'LineWidth', 1.2);
xline(ax_nyq, 0, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);
yline(ax_nyq, 0, 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);
plot(ax_nyq, -1, 0, 'k+', 'MarkerSize', 12, 'LineWidth', 1.2);
plot(ax_nyq, [0 real(resp_gm)], [0 imag(resp_gm)], 'Color', color_gm, 'LineWidth', 1.2);

set(ax_nyq, 'FontName', font_name, 'FontSize', font_size, ...
    'LineWidth', 0.8, 'Box', 'on', 'Layer', 'top');
grid(ax_nyq, 'on');
ax_nyq.GridColor = [0.85 0.85 0.85];
ax_nyq.GridAlpha = 0.8;
ax_nyq.XMinorGrid = 'off';
ax_nyq.YMinorGrid = 'off';
axis(ax_nyq, 'equal');
xlim(ax_nyq, [-1.5 2.5]);
ylim(ax_nyq, [-4 4]);
xlabel(ax_nyq, 'Real Axis', 'FontName', font_name, 'FontSize', font_size + 1);
ylabel(ax_nyq, 'Imaginary Axis', 'FontName', font_name, 'FontSize', font_size + 1);

add_curve_arrow(ax_nyq, re, im, w_nyq, 1.8, 0.28, color_main);
add_curve_arrow(ax_nyq, re, im, w_nyq, 120, 0.28, color_main);
add_curve_arrow(ax_nyq, re, -im, w_nyq, 8, 0.28, color_main);

annotation(fig, 'textbox', [0.27 0.02 0.05 0.04], 'String', '(a)', ...
    'Interpreter', 'latex', 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontName', font_name, 'FontSize', font_size + 1);
annotation(fig, 'textbox', [0.80 0.02 0.05 0.04], 'String', '(b)', ...
    'Interpreter', 'latex', 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontName', font_name, 'FontSize', font_size + 1);

script_path = mfilename('fullpath');
[script_dir, ~] = fileparts(script_path);
script_name = 'Figure_7';
if exist('figure7_output_name', 'var') && ~isempty(figure7_output_name)
    script_name = figure7_output_name;
end
output_file = fullfile(script_dir, [script_name '.svg']);
drawnow;
exportgraphics(fig, output_file, 'ContentType', 'vector');

function style_bode_axes(ax, x_limits, y_limits, font_name, font_size)
set(ax, 'XScale', 'log', ...
    'XLim', x_limits, ...
    'YLim', y_limits, ...
    'FontName', font_name, ...
    'FontSize', font_size, ...
    'LineWidth', 0.8, ...
    'Box', 'on', ...
    'Layer', 'top');
grid(ax, 'on');
ax.GridColor = [0.85 0.85 0.85];
ax.GridAlpha = 0.8;
ax.XMinorGrid = 'on';
ax.YMinorGrid = 'off';
ax.MinorGridColor = [0.88 0.88 0.88];
ax.MinorGridAlpha = 0.9;
end

function plot_vertical(ax, x_val, color_val)
yl = ylim(ax);
plot(ax, [x_val x_val], yl, '--', 'Color', color_val, 'LineWidth', 1.1);
end

function add_curve_arrow(ax, x_curve, y_curve, w_curve, target_w, arrow_size, color_val)
[~, idx] = min(abs(w_curve - target_w));
idx = max(2, min(idx, numel(x_curve) - 1));
dx = x_curve(idx + 1) - x_curve(idx - 1);
dy = y_curve(idx + 1) - y_curve(idx - 1);
angle = atan2(dy, dx);
L = arrow_size;
W = 0.42 * arrow_size;
verts_x = [0; -L; -L];
verts_y = [0; W; -W];
R = [cos(angle) -sin(angle); sin(angle) cos(angle)];
verts_rot = R * [verts_x'; verts_y'];
patch(ax, verts_rot(1,:) + x_curve(idx), verts_rot(2,:) + y_curve(idx), color_val, 'EdgeColor', 'none');
end

function rgb = hex2rgb(hex_str)
hex_str = strrep(hex_str, '#', '');
rgb = [hex2dec(hex_str(1:2)), hex2dec(hex_str(3:4)), hex2dec(hex_str(5:6))] / 255;
end
