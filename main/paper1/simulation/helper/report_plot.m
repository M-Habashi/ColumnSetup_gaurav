%% Plot Indicator Figure (Same style as foromat_sim_fig_v2)
% This script plots x1, x2, x3 displacements and alpha/indicator from simulation
% PREREQUISITE: Run demo first (variables X_m, Num_resp, Ref_Resp, t, alpha, indicator must exist)
% Set plot_indicator = 1 in User Input to enable this plot

%% 0. Configuration
load('reporty_1.mat')
ylim_x1 = [-4.9  4.9];
ylim_x2 = [-7.9  7.9];
y_tick_step = 3;

% ---- Time window (Zoom) ----
% Use [] for full duration, or [t_start t_end] in seconds to zoom in.
t_zoom = [];       % paper zoom is [12,18]
t_tick_step = [];       % [] = auto; Example: 0.5 (sec)
% ----------------------------

% Colors
c_grey   = '#555555';
c_blue   = '#0c558e';
c_purple = '#7434a5';
c_green = '#a53434';

% Figure styling
figW = 4.25;
figH = 5;
fontName = 'Times New Roman';
fontSize = 9;
lw_thin  = 1.0;

% Stacking: 'ref' (reference on top) or 'vrths' (vRTHS on top)
top_on = 'ref';

%% 1. Extract Data from Workspace
time = t(:);
x1_vrths = X_m.Data(:,1);
x2_vrths = Num_resp.Data(:,2);
x1_ref = Ref_Resp(:,1);
x2_ref = Ref_Resp(:,2);

% Check if alpha and indicator exist (lowercase from Simulink)
has_alpha = exist('alpha', 'var') && ~isempty(alpha);
has_indicator = exist('indicator', 'var') && ~isempty(indicator);

% Store Case I (reporty_1) data temporarily
alpha_case1 = alpha;
indicator_case1 = indicator;

%% 2. Create New Figure
fig = figure('Units','inches','Position',[1 1 figW figH], 'Color', 'w');

if has_alpha || has_indicator
    rows = 3;
else
    rows = 2;
end
left = 0.12; right = 0.9;
width = right - left;
top = 0.96; bottom = 0.07;
gap = 0.04;
height = (top - bottom - (rows-1)*gap) / rows;

%% 3. Plot Subplots

% Subplot 1: x1
ax1 = axes('Units','normalized', 'Position', [left, top-height, width, height]);
plot_signal_pair(ax1, time, x1_vrths*1e3, x1_ref*1e3, '$x_1$ (mm)', c_grey, c_blue, top_on, lw_thin, 'vRTHS (Case I)');

% Subplot 2: x2
load('reporty_2.mat', 't', 'X_m', 'Num_resp', 'Ref_Resp', 'alpha', 'indicator')
x1_vrths = X_m.Data(:,1);
x2_vrths = Num_resp.Data(:,2);
x1_ref = Ref_Resp(:,1);
x2_ref = Ref_Resp(:,2);
ax2 = axes('Units','normalized', 'Position', [left, top-2*height-gap, width, height]);
plot_signal_pair(ax2, time, x1_vrths*1e3, x1_ref*1e3, '$x_1$ (mm)', c_grey, c_blue, top_on, lw_thin, 'vRTHS (Case II)');

% Subplot 3: Alpha & Indicator (if available)
if has_alpha || has_indicator
    ax4 = axes('Units','normalized', 'Position', [left, bottom, width, height]);
    hold(ax4, 'on');
    
    % LEFT y-axis: Alpha
    yyaxis(ax4, 'left');
    h_alpha = [];
    if has_alpha
        alpha_time = alpha.Time(:);
        alpha_data = alpha.Data(:);
        h_alpha = plot(ax4, alpha_time, alpha_data, ...
            'Color', c_grey, 'LineWidth', lw_thin, 'LineStyle', '-');
    end
    ylabel(ax4, '$k_t \, / \, k_o$', 'Interpreter','latex');
    
    % RIGHT y-axis: Indicator (b_g)
    yyaxis(ax4, 'right');
    h_bg_case1 = [];
    h_bg_case2 = [];
    if has_indicator
        % Plot Case I indicator first
        ind_time_case1 = indicator_case1.Time(:);
        ind_data_case1 = indicator_case1.Data(:);
        h_bg_case1 = plot(ax4, ind_time_case1, ind_data_case1, ...
            'Color', c_green, 'LineWidth', lw_thin, 'LineStyle', '--');

        % Plot Case II indicator
        ind_time_case2 = indicator.Time(:);
        ind_data_case2 = indicator.Data(:);
        h_bg_case2 = plot(ax4, ind_time_case2, ind_data_case2, ...
            'Color', c_purple, 'LineWidth', lw_thin, 'LineStyle', '-');
    end
    ylabel(ax4, '$b_g$', 'Interpreter','latex');
    
    % Limits + ticks
    ax4.YAxis(1).Limits     = [-0.02 1.06];
    ax4.YAxis(1).TickValues = 0:0.2:1;
    ax4.YAxis(2).Limits     = [-0.01 0.53];
    ax4.YAxis(2).TickValues = 0:0.1:0.5;
    
    % Match y-axis colors to line colors
    ax4.YAxis(1).Color = hex2rgb(c_grey);
    ax4.YAxis(2).Color = hex2rgb(c_purple);
    
    xlabel(ax4, 'Time (sec)', 'Interpreter','latex');
    grid(ax4, 'on');
    
    % Legend
    leg_h4 = []; leg_s4 = {};
    if ~isempty(h_alpha), leg_h4 = [leg_h4 h_alpha]; leg_s4 = [leg_s4 {'$k_t \, / \, k_o$'}]; end
    if ~isempty(h_bg_case1),    leg_h4 = [leg_h4 h_bg_case1];    leg_s4 = [leg_s4 {'$b_g$ (Case I)'}];    end
    if ~isempty(h_bg_case2),    leg_h4 = [leg_h4 h_bg_case2];    leg_s4 = [leg_s4 {'$b_g$ (Case II)'}];    end
    if ~isempty(leg_h4)
        legend(ax4, leg_h4, leg_s4, 'Location','northeast', ...
            'Interpreter','latex', 'Box','on');
    end
    
    all_sigs = [ax1, ax2, ax4];
else
    % No alpha/indicator - show x-axis labels on ax2
    xlabel(ax2, 'Time (sec)', 'Interpreter','latex');
    ax2.XTickLabelMode = 'auto';  % ensure labels show (plot_signal_pair clears them)
    all_sigs = [ax1, ax2];
end

%% 4. Standardization & Linking
linkaxes(all_sigs, 'x');

% ---- Apply Time Limits (Parametric Zoom) ----
t_min = min(time);
t_max = max(time);

if isempty(t_zoom)
    t_start = t_min;
    t_end   = t_max;
else
    t_zoom = sort(t_zoom(:).');
    if numel(t_zoom) ~= 2
        error('t_zoom must be [] or a 2-element vector [t_start t_end].');
    end
    t_start = max(t_min, t_zoom(1));
    t_end   = min(t_max, t_zoom(2));
    if t_end <= t_start
        warning('Invalid t_zoom after clamping; reverting to full time range.');
        t_start = t_min;
        t_end   = t_max;
    end
end

xlim(ax1, [t_start t_end]);   % linked to other axes via linkaxes

% Tick spacing (auto if not specified)
if isempty(t_tick_step)
    span = t_end - t_start;
    if span <= 2
        tick_step = 0.2;
    elseif span <= 5
        tick_step = 0.5;
    elseif span <= 15
        tick_step = 1;
    elseif span <= 40
        tick_step = 2;
    elseif span <= 120
        tick_step = 5;
    else
        tick_step = 10;
    end
else
    tick_step = t_tick_step;
end

tick_vec = t_start:tick_step:t_end;
for ax = all_sigs
    xticks(ax, tick_vec);
end
% --------------------------------------------

% Apply Custom Y-Limits & Zero-Centered Ticks
ylim(ax1, ylim_x1);
ticks_x1 = unique([0:y_tick_step:ylim_x1(2), 0:-y_tick_step:ylim_x1(1)]);
yticks(ax1, ticks_x1(ticks_x1 >= ylim_x1(1) & ticks_x1 <= ylim_x1(2)));

ylim(ax2, ylim_x2);
ticks_x2 = unique([0:y_tick_step:ylim_x2(2), 0:-y_tick_step:ylim_x2(1)]);
yticks(ax2, ticks_x2(ticks_x2 >= ylim_x2(1) & ticks_x2 <= ylim_x2(2)));

% Apply Fonts
for ax = all_sigs
    ax.FontName = fontName;
    ax.FontSize = fontSize;
    ax.TickLabelInterpreter = 'latex';
    ax.XTickLabelRotation = 0;
    ax.Box = 'on';
end

%% 5. Output
drawnow;
copygraphics(fig, 'ContentType', 'image', 'Resolution', 300);
disp('Indicator figure copied to clipboard!')

%% --- LOCAL FUNCTIONS ---

function plot_signal_pair(ax, t, y_vrths, y_ref, y_lab, c_ref, c_vrths, top_on, lw, vRTHS_label)
    if nargin < 10, vRTHS_label = 'vRTHS'; end
    if nargin < 9, lw = 1.0; end
    if nargin < 8 || isempty(top_on), top_on = 'ref'; end
    top_on = lower(string(top_on));
    hold(ax, 'on');
    
    % Reference Model -> Black Dotted
    h_ref = patch(ax, 'XData', [t(:); NaN], 'YData', [y_ref(:); NaN], ...
        'EdgeColor', 'k', 'FaceColor', 'none', ...
        'LineWidth', 1.5, 'LineStyle', ':', 'EdgeAlpha', 0.9);
    
    % vRTHS -> Blue Solid
    h_vrths = patch(ax, 'XData', [t(:); NaN], 'YData', [y_vrths(:); NaN], ...
        'EdgeColor', c_vrths, 'FaceColor', 'none', ...
        'LineWidth', lw, 'LineStyle', '-', 'EdgeAlpha', 0.9);
    
    % Stacking order
    if top_on == "vrths"
        uistack(h_ref, 'bottom');
        uistack(h_vrths, 'top');
    else
        uistack(h_vrths, 'bottom');
        uistack(h_ref, 'top');
    end
    
    ylabel(ax, y_lab, 'Interpreter','latex');
    grid(ax, 'on');
    ax.XTickLabel = [];

    legend(ax, [h_ref, h_vrths], {'Reference Model', vRTHS_label}, ...
        'Location','northeast', 'Interpreter','latex', 'Box','on');
end

function rgb = hex2rgb(hexStr)
    hexStr = char(hexStr);
    if hexStr(1) == '#', hexStr = hexStr(2:end); end
    rgb = reshape(sscanf(hexStr,'%2x')/255, 1, 3);
end
