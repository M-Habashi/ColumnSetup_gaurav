controller_name = "controller_01";
P_analog_multiplier = 1;
I_analog_multiplier = 1;
include_bg = true; % Set to false to hide bg plot
digital_phase_margin = 70;
digital_bandwidth = 20;
factor = 0.1;

project_root = fileparts(mfilename('fullpath'));
step_root = fileparts(fileparts(project_root));
addpath(step_root);
addpaths();

[parametric_model, parametric_model_file, parametric_model_file_name] = ...
    load_saved_result_file(step_root, fullfile('models', 'paarametric'));
[~, parametric_model_name] = fileparts(parametric_model_file);

if strlength(strtrim(controller_name)) == 0
    controller_name = string(parametric_model_name);
end
controller_file_name = regexprep(char(controller_name), '[^\w.-]', '_');
saved_controller_dir = fullfile(step_root, 'saved_results', 'controllers');
if ~exist(saved_controller_dir, 'dir')
    mkdir(saved_controller_dir);
end
case_file = fullfile(project_root, '..', 'Building cases', 'Case_1.mat');
use_numerical_model = exist(case_file, 'file') == 2;
if use_numerical_model
    load(case_file, 'M', 'C', 'K');
else
    fprintf('Numerical model file not found. Skipping numerical stability indicator: %s\n', case_file);
end
specimen_params = parametric_model.specimen_params;
assert(isfield(parametric_model, 'id_units') ...
    && isfield(parametric_model.id_units, 'schema_version') ...
    && parametric_model.id_units.schema_version >= 2, ...
    ['The selected parametric model predates the SI-unit correction. ' ...
     'Rerun sys_id.m, then retune the controller.']);
fprintf('Using specimen parameters from: %s\n', specimen_params.name);
fprintf('Using actuator/plant parameters from identification model: %s\n', parametric_model_file_name);

%% Run RUN_vRTHS_demo first and add this folder to tha path
% Load Case_1.mat first
%% specimen
specimen_si = specimen_params_si(specimen_params);
mp = specimen_si.mass;      % kg
kp = specimen_si.stiffness; % N/m
cp = specimen_si.damping;   % N*s/m
zeta = cp / (2*sqrt(kp*mp));
%% Numerical system (needed for margin 1 only)
if use_numerical_model
    m_e     = mp;
    k_e     = kp;
    z_e     = zeta;
    n=3;
    ME = zeros(n);
    ME(1,1) = m_e;
    KE      = zeros(n);
    KE(1,1) = k_e;
    CE = zeros(n);
    c_e = 2*z_e*m_e*sqrt(KE(1,1)/m_e);
    CE(1,1) = c_e;
    % NUMERICAL SUBSTRUCTURE
    MN = M-ME;
    KN = K-KE;
    CN = C-CE;
    % State Space form
    iota = ones(n,1);
    A_ns = [...
        zeros(n) eye(n);
        -MN\KN -MN\CN];
    B_ns = [...
        zeros(n,1)      zeros(n);
        -(MN\M)*iota    -(MN\eye(n))];
    C_ns = [...
        eye(n)              zeros(n);
        zeros(n)            eye(n);
        -MN\KN              -MN\CN];
    D_ns = [...
        zeros(n,1)            zeros(n);
        zeros(n,1)            zeros(n);
        (-MN\M + eye(n))*iota    -(MN\eye(n))]; % for TOTAL acc
    sys_num = ss(A_ns,B_ns,C_ns,D_ns);
end
%%%%
%% original system
transfer_sys = build_identified_open_loop(parametric_model, mp, cp, kp);
reduced_transfer_sys = build_identified_open_loop(parametric_model, mp, cp, factor*kp);
analog_base_Kp = parametric_model.Kp;
analog_base_Ki = parametric_model.Ki;
analog_Kp = P_analog_multiplier * analog_base_Kp;
analog_Ki = I_analog_multiplier * analog_base_Ki;
analog_cntrlr = pid(analog_Kp, analog_Ki, 0);
analog_cl = feedback(analog_cntrlr*transfer_sys, 1);
tuning_config = struct( ...
    'x0', [digital_phase_margin, digital_bandwidth], ...
    'controller_name', char(controller_name), ...
    'parametric_model', parametric_model_name, ...
    'specimen_params', specimen_params, ...
    'P_analog_multiplier', P_analog_multiplier, ...
    'I_analog_multiplier', I_analog_multiplier);
optimize_choice = input('Do you want to optimize settling time? [y/n]: ', 's');

if strcmpi(optimize_choice, 'y')
    tuning = optimize_settling_time_tuning(transfer_sys, analog_cntrlr, struct( ...
        'x0', [digital_phase_margin, digital_bandwidth], ...
        'use_cache', false, ...
        'cache_context', tuning_config));
    digital_phase_margin = tuning.x(1);
    digital_bandwidth = tuning.x(2);
    analog_cntrlr = tuning.analog_cntrlr;
    digital_cntrlr = tuning.digital_cntrlr;
    analog_cl = tuning.analog_cl;
    digital_cl = tuning.digital_cl;
    fprintf('\n%% ========================================\n');
    fprintf('%% Optimal Tuning Parameters\n');
    fprintf('%% ========================================\n');
    fprintf('%% digital phase margin = %.6g\n', digital_phase_margin);
    fprintf('%% digital bandwidth    = %.6g\n', digital_bandwidth);
    fprintf('%% Optimal original settling time = %.6g s\n', tuning.settling_time);
    fprintf('%% ========================================\n');
else
    destabilizing_optimize_choice = input('Do you want to run the destabilizing optimization? [y/n]: ', 's');
    if strcmpi(destabilizing_optimize_choice, 'y')
        tuning = optimize_destabilizing_tuning(transfer_sys, reduced_transfer_sys, analog_cntrlr, struct( ...
            'x0', [digital_phase_margin, digital_bandwidth], ...
            'use_cache', false, ...
            'cache_context', tuning_config));
        digital_phase_margin = tuning.x(1);
        digital_bandwidth = tuning.x(2);
        analog_cntrlr = tuning.analog_cntrlr;
        digital_cntrlr = tuning.digital_cntrlr;
        analog_cl = tuning.analog_cl;
        digital_cl = tuning.digital_cl;
        fprintf('\n%% ========================================\n');
        fprintf('%% Destabilizing Optimization Result\n');
        fprintf('%% ========================================\n');
        fprintf('%% digital phase margin = %.6g\n', digital_phase_margin);
        fprintf('%% digital bandwidth    = %.6g\n', digital_bandwidth);
        if tuning.found_solution
            fprintf('%% Destabilizing solution found     = yes\n');
        else
            fprintf('%% Destabilizing solution found     = no\n');
        end
        fprintf('%% Analog settling time  = %.6g s\n', tuning.analog_settling_time);
        fprintf('%% Digital settling time = %.6g s\n', tuning.digital_settling_time);
        fprintf('%% Cost                  = %.6g\n', tuning.cost);
        fprintf('%% Reduced system unstable at alpha = %.2f -> %s\n', factor, string(tuning.reduced_is_unstable));
        fprintf('%% Reduced max real pole            = %.6g\n', tuning.reduced_max_real_pole);
        fprintf('%% ========================================\n');
    else
        opts = pidtuneOptions('PhaseMargin', digital_phase_margin);
        [digital_cntrlr, info_d] = pidtune(analog_cl, 'PI', digital_bandwidth, opts);
        digital_cl = feedback(digital_cntrlr*analog_cl, 1);
    end
end
%% one iteration example
analog_cl_r_ex = feedback(analog_cntrlr*reduced_transfer_sys, 1);
digital_cl_r_ex = feedback(digital_cntrlr*analog_cl_r_ex, 1);
info_analog_nom = stepinfo(analog_cl);
info_analog_red = stepinfo(analog_cl_r_ex);
info_nom = stepinfo(digital_cl);
info_red = stepinfo(digital_cl_r_ex);

fprintf('\n%% ========================================\n');
fprintf('%% Controller Summary\n');
fprintf('%% ========================================\n');
fprintf('%% Parametric model = %s\n', parametric_model_file_name);
fprintf('%% Specimen: m = %.6g, c = %.6g, k = %.6g, zeta = %.6g\n', mp, cp, kp, zeta);
fprintf('%% Analog PI controller\n');
fprintf('%%   base Kp = %.6g, multiplier = %.6g, final Kp = %.6g\n', ...
    analog_base_Kp, P_analog_multiplier, analog_Kp);
fprintf('%%   base Ki = %.6g, multiplier = %.6g, final Ki = %.6g\n', ...
    analog_base_Ki, I_analog_multiplier, analog_Ki);
fprintf('%%\n');
fprintf('%% Digital PI controller\n');
fprintf('%%   Kp = %.6g\n', digital_cntrlr.Kp);
fprintf('%%   Ki = %.6g\n', digital_cntrlr.Ki);
fprintf('%%\n');
fprintf('%% Step Response Summary\n');
fprintf('%%   Analog original settling time       = %.6g s\n', info_analog_nom.SettlingTime);
fprintf('%%   Analog reduced settling time        = %.6g s  (alpha = %.2f)\n', info_analog_red.SettlingTime, factor);
fprintf('%%   Original settling time              = %.6g s\n', info_nom.SettlingTime);
fprintf('%%   Reduced-stiffness settling time     = %.6g s  (alpha = %.2f)\n', info_red.SettlingTime, factor);
fprintf('%% ========================================\n');

digital_Kp = digital_cntrlr.Kp;
digital_Ki = digital_cntrlr.Ki;
controller_save_path = fullfile(saved_controller_dir, sprintf('%s.mat', controller_file_name));
save(controller_save_path, ...
    'controller_name', ...
    'parametric_model_file', ...
    'parametric_model_name', ...
    'specimen_params', ...
    'mp', ...
    'cp', ...
    'kp', ...
    'zeta', ...
    'P_analog_multiplier', ...
    'I_analog_multiplier', ...
    'analog_base_Kp', ...
    'analog_base_Ki', ...
    'analog_Kp', ...
    'analog_Ki', ...
    'digital_phase_margin', ...
    'digital_bandwidth', ...
    'digital_Kp', ...
    'digital_Ki', ...
    'analog_cntrlr', ...
    'digital_cntrlr', ...
    'analog_cl', ...
    'digital_cl');
fprintf('%% Saved controller = %s\n', controller_save_path);

step_plot_opts = struct('show_indicators', true);
figure('Name', 'Closed-Loop Step Responses', 'Color', 'w');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
plot_step_toggle_compare(ax1, {analog_cl, analog_cl_r_ex}, ...
    [info_analog_nom.SettlingTime, info_analog_red.SettlingTime], ...
    { ...
    sprintf('Original analog closed loop (t_s = %.3f s)', info_analog_nom.SettlingTime), ...
    sprintf('Reduced-stiffness analog closed loop (\\alpha = %.2f, t_s = %.3f s)', factor, info_analog_red.SettlingTime), ...
    }, 'Analog Closed Loop', step_plot_opts);

ax2 = nexttile;
plot_step_toggle_compare(ax2, {digital_cl, digital_cl_r_ex}, ...
    [info_nom.SettlingTime, info_red.SettlingTime], ...
    { ...
    sprintf('Original digital closed loop (t_s = %.3f s)', info_nom.SettlingTime), ...
    sprintf('Reduced-stiffness digital closed loop (\\alpha = %.2f, t_s = %.3f s)', factor, info_red.SettlingTime), ...
    }, 'Digital Closed Loop', step_plot_opts);

plot_colors = get_plot_colors();
analog_labels = { ...
    'Original analog closed loop', ...
    sprintf('Reduced-stiffness analog closed loop (\\alpha = %.2f)', factor)};
digital_labels = { ...
    'Original digital closed loop', ...
    sprintf('Reduced-stiffness digital closed loop (\\alpha = %.2f)', factor)};
bode_freq_hz = logspace(-1, 2, 600);

figure('Name', 'Closed-Loop Bode Diagrams', 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plot_bode_compare(nexttile, nexttile, {analog_cl, analog_cl_r_ex}, ...
    analog_labels, 'Analog Closed Loop', bode_freq_hz, ...
    {plot_colors.blue, plot_colors.red});
plot_bode_compare(nexttile, nexttile, {digital_cl, digital_cl_r_ex}, ...
    digital_labels, 'Digital Closed Loop', bode_freq_hz, ...
    {plot_colors.purple, plot_colors.green});

figure('Name', 'Closed-Loop Poles and Zeros', 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plot_pole_zero_compare(nexttile, {analog_cl, analog_cl_r_ex}, ...
    analog_labels, 'Analog Closed Loop', {plot_colors.blue, plot_colors.red});
plot_pole_zero_compare(nexttile, {digital_cl, digital_cl_r_ex}, ...
    digital_labels, 'Digital Closed Loop', {plot_colors.purple, plot_colors.green});
%% Loop Through Stiffness Factors and Compute Margins
% Define the vector of stiffness factors to test (from 0 to 1)
factors = 1:-0.01:0;
if use_numerical_model
    margins1 = zeros(size(factors));
else
    margins1 = NaN(size(factors));
end
margins2 = zeros(size(factors));
margins3 = zeros(size(factors));
margins4 = zeros(size(factors));
margins5 = zeros(size(factors));
closed_loop_stable = false(size(factors));
% Loop over each factor
if use_numerical_model
    n = size(C_ns,1); AA_p = zeros(n); BB_p = eye(n); CC_p = zeros(1,n);
end
for i = 1:length(factors)
    current_factor = factors(i);
    ki = current_factor * kp;
    ci = 2*zeta*sqrt(current_factor*kp*mp);
    analog_cl_r = feedback(analog_cntrlr * build_identified_open_loop(parametric_model, mp, ci, ki), 1);
    sys = digital_cntrlr*analog_cl_r;
    digital_cl_r = feedback(sys, 1);
    % profile on
    gain_phase_margins = allmargin(sys);
    closed_loop_stable(i) = gain_phase_margins.Stable;
    ncfmargin_value = ncfmargin(analog_cl_r, digital_cntrlr)*closed_loop_stable(i);
    % profile viewer
    % profile off
    if use_numerical_model
        % Numerical Stability
        %n_p for numerical physical, minreal is essential for stability check,
        %evalc to silent the mireal function
        DD_p = [ki 0 0 ci 0 0 mp 0 0];
        ss_phy = ss(AA_p,BB_p, CC_p, DD_p);
        ss_comb = series(sys_num, -ss_phy);
        temp = evalc('n_p_sys = minreal(ss_comb(:,2));');
        numerical_margins = allmargin(n_p_sys);
        margins1(i) = min([min(numerical_margins.DelayMargin) ...
            *numerical_margins.Stable, inf]);
        margins3(i) = min([min(numerical_margins.GainMargin) ...
            *numerical_margins.Stable, inf]); %ignore this one
    end
    margins2(i) = min([min(gain_phase_margins.DelayMargin) ...
        *closed_loop_stable(i), inf]);
    margins4(i) = min([20*log10(min(gain_phase_margins.GainMargin)) ...
        *closed_loop_stable(i), inf]);
    margins5(i) = ncfmargin_value;
end
%% Plotting the Results (Formatted for Single Column Manuscript / Review Draft)
% Dimensions: 6.5 inches is standard text width (8.5" page - 2x1" margins)
fig_width = 12.27; 
fig_height = 6; % Aspect ratio approx 1.6 (Golden ratio-ish)
% === 1) Figure & Axes setup ===
fig = figure('Units','inches','Position',[5 5 fig_width fig_height],'Color','w');
ax  = axes('Parent',fig, ...
    'XDir','reverse', 'XLim',[0 1], 'YLim',[0 2], ...           
    'YTick',0:0.2:2, ...                                        % Higher tick density for wider plot
    'TickLabelInterpreter','latex', ...
    'FontName', 'Times New Roman', 'FontSize',14, ...          % 10pt Times New Roman
    'GridColor',[0.7 0.7 0.7],'GridLineStyle','--','GridAlpha',1, ... 
    'LineWidth',0.5,'Box','on','Layer','bottom');                    
grid(ax,'on'); hold(ax,'on');
% === 2) Curves ===
ls = {'LineStyle','-','LineWidth',1.5}; 
legend_labels = {};
if use_numerical_model
    plot(ax,factors, normalize_indicator(margins1), ls{:}, 'Color','#555555');
    legend_labels{end+1} = '${\tau_{cr,N}}$';
end
plot(ax,factors, normalize_indicator(margins2), ls{:}, 'Color','#0c558e');
plot(ax,factors, normalize_indicator(margins4), ls{:}, 'Color','#a5347b');
legend_labels = [legend_labels, {'${\tau_{cr,P}}$','${GM_{P}}$'}];

% Logic for including bg
if include_bg
    plot(ax,factors, normalize_indicator(margins5), ls{:}, 'Color','#318C12');
    legend_labels{end+1} = '${NCF}$';
end

% === 3) Title, labels, legend ===font
xlabel(ax,'$\bf{\alpha}$','Interpreter','latex','FontName','Times New Roman','FontSize',14);
ylabel(ax,'Normalized Stability Indicator ($SI_{\alpha}/SI_{\alpha=1}$)', ... 
       'Interpreter','latex','FontName','Times New Roman','FontSize',14);
% Legend
lgd = legend(ax, legend_labels, ...
       'Interpreter','latex','FontName','Times New Roman','FontSize',14,'Location','northeast');
lgd.ItemTokenSize = [20, 18]; % Standard token size for wider plot
% === 4) Instability marker & annotation ===
first_unstable = find(~closed_loop_stable, 1, 'first');
if ~isempty(first_unstable)
    alpha_instability = factors(first_unstable);
    xline(ax,alpha_instability,'--','Color','k','LineWidth',1.5, ...
        'HandleVisibility','off');
    text(ax,alpha_instability+0.015,1.1, ...
        sprintf('First unstable sample at $\\alpha = %.2f$', alpha_instability), ...
        'Rotation',90,'Color','k','FontName','Times New Roman', ...
        'FontSize',14,'Interpreter','latex');
end
hold(ax,'off');
% === 5) Copy to Clipboard ===
copygraphics(fig, 'ContentType', 'vector'); 

%% Useful functions
function transfer_sys = build_identified_open_loop(p, m, c, k)
    plant_den = [m, ...
        c + p.a3*m + p.beta1*m, ...
        p.a2 + k + p.a3*c + p.beta1*c + p.beta2*m + p.a3*p.beta1*m, ...
        p.a2*p.beta1 + p.beta2*c + p.a3*k + p.beta1*k + p.a3*p.beta1*c + p.a3*p.beta2*m, ...
        p.a2*p.beta2 + p.beta2*k + p.a3*p.beta2*c + p.a3*p.beta1*k, ...
        p.a3*p.beta2*k];
    transfer_sys = tf(p.a1b0, plant_den);
end

function y = normalize_indicator(x)
    y = x;
    ref = x(find(isfinite(x) & abs(x) > eps, 1, 'first'));
    if isempty(ref)
        y(:) = 0;
        return
    end
    y = x / ref;
    y(~isfinite(y)) = NaN;
end

function plot_step_toggle_compare(ax, systems, settling_times, labels, plot_title, opts)
    if nargin < 6
        opts = struct();
    end
    if ~isfield(opts, 'show_indicators')
        opts.show_indicators = false;
    end

    hold(ax, 'on')
    for i = 1:numel(systems)
        [y, t] = step(systems{i});
        plot(ax, t(:), squeeze(y), 'LineWidth', 1.4, 'DisplayName', labels{i});
        if opts.show_indicators && isfinite(settling_times(i))
            xline(ax, settling_times(i), ':', 'HandleVisibility', 'off');
        end
    end
    grid(ax, 'on')
    title(ax, plot_title)
    xlabel(ax, 'Time (s)')
    ylabel(ax, 'Response')
    lgd = legend(ax, 'Location', 'best');
    lgd.ItemHitFcn = @toggle_legend_item;
    hold(ax, 'off')
end

function plot_bode_compare(ax_mag, ax_phase, systems, labels, plot_title, freq_hz, colors)
    freq_rad = 2*pi*freq_hz;
    hold(ax_mag, 'on')
    hold(ax_phase, 'on')
    for i = 1:numel(systems)
        [mag, phase] = bode(systems{i}, freq_rad);
        mag_db = 20*log10(squeeze(mag) + eps);
        phase_deg = unwrap(squeeze(phase)*pi/180)*180/pi;
        semilogx(ax_mag, freq_hz, mag_db, '-', 'Color', colors{i}, ...
            'LineWidth', 1.4, 'DisplayName', labels{i});
        semilogx(ax_phase, freq_hz, phase_deg, '-', 'Color', colors{i}, ...
            'LineWidth', 1.4, 'DisplayName', labels{i});
    end
    grid(ax_mag, 'on')
    grid(ax_phase, 'on')
    xlim(ax_mag, [freq_hz(1), freq_hz(end)])
    xlim(ax_phase, [freq_hz(1), freq_hz(end)])
    ylabel(ax_mag, 'Magnitude (dB)')
    ylabel(ax_phase, 'Phase (deg)')
    xlabel(ax_phase, 'Frequency (Hz)')
    title(ax_mag, plot_title)
    legend(ax_mag, 'Location', 'best')
    legend(ax_phase, 'Location', 'best')
    hold(ax_mag, 'off')
    hold(ax_phase, 'off')
end

function plot_pole_zero_compare(ax, systems, labels, plot_title, colors)
    hold(ax, 'on')
    for i = 1:numel(systems)
        plot_model_poles_and_zeros(ax, systems{i}, colors{i});
    end
    xline(ax, 0, 'k:')
    yline(ax, 0, 'k:')
    grid(ax, 'on')
    box(ax, 'on')
    axis(ax, 'equal')
    xlabel(ax, 'Real')
    ylabel(ax, 'Imaginary')
    title(ax, plot_title)

    legend_handles = gobjects(numel(systems), 1);
    for i = 1:numel(systems)
        legend_handles(i) = plot(ax, nan, nan, '-', 'Color', colors{i}, ...
            'LineWidth', 1.6, 'DisplayName', labels{i});
    end
    legend(ax, legend_handles, 'Location', 'best')
    hold(ax, 'off')
end

function plot_model_poles_and_zeros(ax, sys, marker_color)
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
    colors.black = [0 0 0];
    colors.blue = hex_to_rgb('007CA8');
    colors.copperwood = hex_to_rgb('AC6420');
    colors.green = hex_to_rgb('39BF5E');
    colors.red = hex_to_rgb('901500');
    colors.purple = hex_to_rgb('74058A');
end

function rgb = hex_to_rgb(hex_color)
    rgb = sscanf(hex_color, '%2x%2x%2x', [1 3]) / 255;
end

function toggle_legend_item(~, event)
    if strcmp(event.Peer.Visible, 'on')
        event.Peer.Visible = 'off';
    else
        event.Peer.Visible = 'on';
    end
end
