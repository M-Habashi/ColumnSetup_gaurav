% SCRIPTED_MAIN Pure-MATLAB implementation of RUN_vRTHS_demo_new.
% This entry point does not load or execute any Simulink model.

clc;
clear;
close all;

Building_c = 1;            % Partitioning case (1-4)
simulation_case = 2;       % Paper case (1-4); see case definitions below
plot_on = 'n';             % Plot RTHS results? ('y' or 'n')
modified = 1;              % Test modified version? (1=yes, 0=no)
alpha_min = 0.4;           % Legacy mode only: final stiffness ratio (0-0.75)
b_th = 0.15;               % Indicator threshold
b_th_2 = 0.185;            % A NCF threshold for switching back from B
switch_back_hold = 2;      % Required continuous time above b_th_2 [s]
switch_transition_duration = 0.25; % Linear A/B ramp duration [s]
num_add = 0;               % Number of additional (perturbed) trials
enable_indicator_plot = 1; % Plot indicator figure? (1=yes, 0=no)
fs = 4096;                 % RTHS sampling frequency [Hz]

%%%%%%%%%%%%%%
% controller inputs
bw_a = 70; pm_a = 70;
bw_b = 55; pm_b = 55;
bw_c = 40; pm_c = 60;      % NOT used by custom C; legacy compatibility only
target_ncf_c = 0.40;       % Controller C custom-PI NCF target
target_ncf_c_alpha = 1;    % Alpha where Controller C's NCF is enforced
%%%%%%%%%%%%
%specimen
alpha_start =1;         % Initial specimen/reference stiffness ratio (0-1)
%%%%%%%%%%%%
% degrading Bouc-Wen damage (consider_damage = 2)
% F_BW = k0*(post_yield_ratio*d + (1-post_yield_ratio)*z)
% z_dot = (d_dot - nu*beta_b*abs(d_dot)*z*abs(z)^(n-1) ...
%     - nu*gamma_b*d_dot*abs(z)^n)/eta
% E_dot = (abs(z)/u_y)^q*z*d_dot
% nu = 1 + delta_nu*E; eta = 1 + delta_eta*E
post_yield_ratio = 0.001;    % Equation rho: residual stiffness ratio [-]
n = 8;                     % Transition sharpness [-]
u_y = 1.5;                 % Equivalent yield displacement [mm]
sigma = 0.769230769230769; % beta_b/(beta_b+gamma_b) [-]
delta_nu = 0.03;           % Strength degradation [mm^-2]
delta_eta = 0.03;          % Stiffness degradation [mm^-2]
reference_delta_nu = 0.05; % Reference strength degradation [mm^-2]
reference_delta_eta = 0.05; % Reference stiffness degradation [mm^-2]
q = 10;                      % Yield-proximity energy exponent [-]
lse_window = 0.5;            % Moving-LSE stiffness window [s]
beta_b = sigma / u_y^n;    % 2.74881368074e-6 [mm^-n]
gamma_b = (1-sigma) / u_y^n; % 8.24644104221e-7 [mm^-n]

%%%%%%%%
% phase-lead compensator: G_lead(s) = lead_gain*(s+lead_zero)/(s+lead_pole)
lead_gain = 31.6431547;         % Compensator gain [-]
lead_zero = 49.3502225;         % Zero frequency [rad/s]
lead_pole = 1657.846121;        % Pole frequency [rad/s]

%%%%%%%%
% paper simulation cases
switch simulation_case
    case 1
        % Linear specimen with Controller A.
        consider_damage = 0;
        start_c = 'A';
        switch_on = 0;
        run_name = 'case_01';
        run_title = 'Case I';
    case 2
        % Linear specimen with the more robust Controller B.
        consider_damage = 0;
        start_c = 'B';
        switch_on = 0;
        run_name = 'case_02';
        run_title = 'Case II';
    case 3
        % Degrading nonlinear specimen with Controller A retained.
        consider_damage = 2;
        start_c = 'A';
        switch_on = 0;
        run_name = 'case_03';
        run_title = 'Case III';
    case 4
        % Degrading nonlinear specimen with A-to-B switching enabled.
        consider_damage = 2;
        start_c = 'A';
        switch_on = 1;
        run_name = 'case_04';
        run_title = 'Case IV';
    otherwise
        error('simulation_case must be an integer from 1 to 4.')
end

%%%%%%%%
scripted_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(scripted_dir);
addpath(scripted_dir);

options = struct( ...
    'Building_c', Building_c, ...
    'plot_on', plot_on, ...
    'modified', modified, ...
    'consider_damage', consider_damage, ...
    'alpha_start', alpha_start, ...
    'alpha_min', alpha_min, ...
    'post_yield_ratio', post_yield_ratio, ...
    'n', n, ...
    'u_y', u_y, ...
    'sigma', sigma, ...
    'delta_nu', delta_nu, ...
    'delta_eta', delta_eta, ...
    'reference_delta_nu', reference_delta_nu, ...
    'reference_delta_eta', reference_delta_eta, ...
    'q', q, ...
    'lse_window', lse_window, ...
    'lead_gain', lead_gain, ...
    'lead_zero', lead_zero, ...
    'lead_pole', lead_pole, ...
    'b_th', b_th, ...
    'b_th_2', b_th_2, ...
    'switch_back_hold', switch_back_hold, ...
    'switch_transition_duration', switch_transition_duration, ...
    'num_add', num_add, ...
    'enable_indicator_plot', enable_indicator_plot, ...
    'test_name', run_name, ... % Backward-compatible filename option
    'run_name', run_name, ...
    'run_title', run_title, ...
    'fs', fs, ...
    'bw_a', bw_a, ...
    'pm_a', pm_a, ...
    'bw_b', bw_b, ...
    'pm_b', pm_b, ...
    'bw_c', bw_c, ...
    'pm_c', pm_c, ...
    'target_ncf_c', target_ncf_c, ...
    'target_ncf_c_alpha', target_ncf_c_alpha, ...
    'start_c', start_c, ...
    'switch_on', switch_on);

run_output = scripted_run(options, project_root);

% Match the primary base-workspace contract of RUN_vRTHS_demo_new.
t = run_output.t;
EQ_input = run_output.EQ_input;
X_m = run_output.X_m;
Num_resp = run_output.Num_resp;
Force_act = run_output.Force_act;
alpha = run_output.alpha;
BoucWen = run_output.BoucWen;
BoucWen_energy = run_output.BoucWen_energy;
Restoring_force = run_output.Restoring_force;
LSE_stiffness = run_output.LSE_stiffness;
indicator = run_output.indicator;
indicator_a = run_output.indicator_a;
indicator_b = run_output.indicator_b;
controller_beta = run_output.beta;
active_controller_a = run_output.active_controller_a;
switch_event = run_output.switch_event;
PI_command = run_output.PI_command;
PI_command_max_mm = run_output.PI_command_max_mm;
Ref_Resp = run_output.Ref_Resp;
eval_crit = run_output.eval_crit;
test = run_output.test;
J1 = run_output.J1;
J2 = run_output.J2;
J3 = run_output.J3;
J4 = run_output.J4;
J5 = run_output.J5;
J6 = run_output.J6;
J7 = run_output.J7;
J8 = run_output.J8;
J9 = run_output.J9;
ControllerCTune = run_output.ControllerCTune;
ControllerCharacteristics = run_output.ControllerCharacteristics;
Results = run_output.Results %#ok<NOPTS>
RunName = run_output.RunName;
RunTitle = run_output.RunTitle;
ResultFiles = run_output.ResultFiles;
SummaryFile = run_output.SummaryFile;

fprintf('Run "%s" saved.\n', RunTitle)
fprintf('Summary MAT file: %s\n', SummaryFile)

disp('Note:')
disp('- Nominal and perturbed cases are described in the companion paper')
disp('- J1 is in [msec]')
disp('- J2 to J9 are in [%]')
