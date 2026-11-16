function result = ncf
%NCF Plot Controller-A/B NCF margins in the manuscript figure style.
%   With the "scripted" folder on the MATLAB path, run this figure with:
%       ncf
%
%   The exact controllers and options are loaded from the last completed
%   SCRIPTED_RUN snapshot. Alpha scales the experimental stiffness, and the
%   corresponding damping is recalculated for each alpha.

fs = 4096;                 % RTHS sampling frequency [Hz]
modified = 1;              % 1 = modified experimental mass/lead setup
bw_a = 70; pm_a = 70;      % Controller A: bandwidth [rad/s], PM [deg]
bw_b = 55; pm_b = 55;      % Controller B: bandwidth [rad/s], PM [deg]
bw_c = 40; pm_c = 60;      % Not used by custom C; compatibility only
[target_ncf_c, target_ncf_c_alpha] = ...
    scripted_controller_c_settings;
alpha = 1:-0.01:0;         % Experimental stiffness ratio

scriptedDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptedDir);
addpath(scriptedDir);

options = struct( ...
    'Building_c', 1, ...
    'plot_on', 'n', ...
    'modified', modified, ...
    'consider_damage', 1, ...
    'alpha_start', 1, ...
    'alpha_min', 0.5, ...
    'b_th', 0.13, ...
    'num_add', 0, ...
    'enable_indicator_plot', 0, ...
    'test_name', 'None', ...
    'fs', fs, ...
    'bw_a', bw_a, 'pm_a', pm_a, ...
    'bw_b', bw_b, 'pm_b', pm_b, ...
    'bw_c', bw_c, 'pm_c', pm_c, ...
    'target_ncf_c', target_ncf_c, ...
    'target_ncf_c_alpha', target_ncf_c_alpha, ...
    'start_c', 'C', ...
    'switch_on', 1);

[lastRun, configurationPath] = ...
    scripted_last_run_configuration(projectRoot);
if isempty(lastRun)
    warning('scripted:NoLastRunConfiguration', ...
        ['No completed-run controller snapshot was found. Using the ', ...
        'fallback settings declared in ncf.m.'])
    configurationSource = "ncf.m fallback";
    p = scripted_build_trial(options, projectRoot, 1);
else
    options = lastRun.Options;
    options.plot_on = 'n';
    options.num_add = 0;
    options.enable_indicator_plot = 0;
    options.test_name = 'None';
    p = scripted_build_trial(options, projectRoot, 1);
    p.controller_a = controllerFromRecord(lastRun.ControllerA);
    p.controller_b = controllerFromRecord(lastRun.ControllerB);
    p.controller_c = controllerFromRecord(lastRun.ControllerC);
    p.pi_a_kp = p.controller_a.Kp;
    p.pi_a_ki = p.controller_a.Ki;
    p.pi_b_kp = p.controller_b.Kp;
    p.pi_b_ki = p.controller_b.Ki;
    p.pi_c_kp = p.controller_c.Kp;
    p.pi_c_ki = p.controller_c.Ki;
    bw_a = options.bw_a;
    pm_a = options.pm_a;
    bw_b = options.bw_b;
    pm_b = options.pm_b;
    target_ncf_c = options.target_ncf_c;
    target_ncf_c_alpha = options.target_ncf_c_alpha;
    configurationSource = string(configurationPath);
end
fprintf('NCF controllers loaded from: %s\n', configurationSource)
ncfA = zeros(size(alpha));
ncfB = zeros(size(alpha));

for index = 1:numel(alpha)
    alphaNow = alpha(index);
    stiffness = alphaNow * p.k_e;
    damping = 2 * p.z_e * sqrt(stiffness * p.m_e);
    alphaPlant = feedback(scripted_inner_open_loop(p.m_e, damping, ...
        stiffness), 1);

    % As in the reference stability figure, report no margin after a
    % controller has made the corresponding closed loop unstable.
    ncfA(index) = blk_indicator_margin(alphaNow, 1, p) * ...
        double(isstable(feedback(p.controller_a * alphaPlant, 1)));
    ncfB(index) = blk_indicator_margin(alphaNow, 0, p) * ...
        double(isstable(feedback(p.controller_b * alphaPlant, 1)));
end

% Derive both manuscript markers from the same saved controller snapshot
% used for the curves. The theoretical calculation supplies alpha_cr and
% the Lyapunov sweep supplies the lowest common-Lyapunov alpha for A/B.
theoreticalResult = theoretical;
lyapunovResult = lyap('A', 'B');
alphaInstability = theoreticalResult.alpha_cr;
switchingBoundary = lyapunovResult.MinimumAlpha;

figure('Name', 'NCF margin versus alpha', 'Units', 'inches', ...
    'Position', [2, 2, 8.27, 4], 'Color', 'w');
ax = axes('FontName', 'Times New Roman', 'FontSize', 10, ...
    'TickLabelInterpreter', 'latex', 'XDir', 'reverse', ...
    'XLim', [0, 1], 'Box', 'on', 'Layer', 'bottom');
hold(ax, 'on');
grid(ax, 'on');
ax.GridColor = [0.75, 0.75, 0.75];
ax.GridAlpha = 0.35;
ax.XTick = 0:0.1:1;

plot(ax, alpha, ncfA, 'Color', '#0c558e', 'LineWidth', 1.5);
plot(ax, alpha, ncfB, 'Color', '#a5347b', 'LineWidth', 1.5);

yMaximum = ceil(max([ncfA, ncfB]) / 0.05) * 0.05;
if ~isfinite(yMaximum) || yMaximum <= 0
    yMaximum = 0.05;
end
ax.YLim = [0, yMaximum];
ax.YTick = 0:0.05:yMaximum;
xlabel(ax, '$\alpha$', 'Interpreter', 'latex');
ylabel(ax, 'NCF margin ($b_g$)', 'Interpreter', 'latex');

lgd = legend(ax, {'Controller A', 'Controller B'}, ...
    'Location', 'northeast', 'Interpreter', 'latex', ...
    'FontName', 'Times New Roman', 'FontSize', 10);
lgd.Units = 'normalized';
legendPosition = lgd.Position;
legendPosition(1) = 1 - legendPosition(3) - 0.086;
legendPosition(2) = 1 - legendPosition(4) - 0.082;
lgd.Position = legendPosition;
try
    lgd.ItemTokenSize = [20, 18];
catch
end

markerColor = '#555555';
if isfinite(switchingBoundary)
    xline(ax, switchingBoundary, '--', 'Color', markerColor, ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');
end
if isfinite(alphaInstability)
    xline(ax, alphaInstability, '--', 'Color', markerColor, ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');
end
% At 90 degrees, right alignment pins the end of the text at the top and
% makes the label extend downward into the axes.
markerLabelHeight = 0.985 * yMaximum;
markerTextOffset = 0.012;
if isfinite(switchingBoundary)
    text(ax, min(switchingBoundary + markerTextOffset, 0.99), markerLabelHeight, ...
        sprintf('Switching Boundary: $\\alpha = %.2f$', switchingBoundary), ...
        'Interpreter', 'latex', 'FontName', 'Times New Roman', ...
        'FontSize', 10, 'Rotation', 90, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end
if isfinite(alphaInstability)
    text(ax, min(alphaInstability + markerTextOffset, 0.99), markerLabelHeight, ...
        sprintf('Theoretical Instability: $\\alpha = %.2f$', alphaInstability), ...
        'Interpreter', 'latex', 'FontName', 'Times New Roman', ...
        'FontSize', 10, 'Rotation', 90, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

result = struct('Alpha', alpha, 'ControllerA', ncfA, 'ControllerB', ncfB, ...
    'TheoreticalInstabilityAlpha', alphaInstability, ...
    'SwitchingBoundaryAlpha', switchingBoundary, ...
    'ConfigurationSource', configurationSource, ...
    'Theoretical', theoreticalResult, 'Lyapunov', lyapunovResult);
end

function controller = controllerFromRecord(record)
controller = pid(record.Kp, record.Ki, record.Kd, record.Tf);
end
