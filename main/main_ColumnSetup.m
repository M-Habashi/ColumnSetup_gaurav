%% Script Header (Read First)

%% Units
% Inputs and stored raw outputs use: t/dt [s], fs [Hz], dd/dc/dm [mm],
% fm [N], and am [g]. Online estimates are m_hat [kg], c_hat [N*s/m],
% and k_hat [N/m]. Convert raw data to SI only for physical calculations;
% raw displacement and acceleration visualizations remain in mm and g.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%              ***  Simulation Tool for ColumnSetup ***                   %
%                     MATLAB/SIMULINK Version R2020b                      %
%            ===============================================              %
%                                                                         %
%              IISL, Purdue University, West Lafayette, IN                %
%                                                                         %
%              Coded by:           Mohamed Gomaa                          %
%                                  Edwin Patino                           %
%                                  Tao Zhang                              %
%                                                                         %
%              Supervised by:      Shirley J. Dyke                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Note Board
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1. Purpose: This script supports the first step of the ColumnSetup
% testing
% Goals:
% 1. Calibrate the Speedgoat command and measurement signals.
% 2. Collect the data needed to identify the system dynamics.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% If this is a new setup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% If this is a new setup, make sure to adjust the following:
% 1. All calibration factors (v2d, v2f, v2a, correction factor)
% 2. The channels (Here in the script only, Simulink will adjust
% automatically)
% 3. Saturation limits
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Preparing the Workspace
clear; close all
addpaths();
projectFolder = fileparts(mfilename('fullpath'));

disp('===============================================================')
disp('                         Column Setup                          ')
disp('                        Simulation To.ol                        ')
disp('===============================================================')

%% Test Inputs
test_type = 'testing_OSI';
testname = test_type;

%% Hybrid Simulation Parameters
hs = struct( ...
    'fem_file', '', ... % Selected from saved_results/fem below.
    'exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'phase_lead_file', fullfile(projectFolder, 'saved_results', ...
    'phase_lead', 'pl_5k_48.mat'), ...
    'earthquake_type', 'el_centro', ... % Field name in input_signals/earthquakes.mat.
    'intensity_factor', 0.025, ...   % Earthquake acceleration multiplier.
    'time_scale_factor', 1.0, ...  % >1 stretches earthquake time; dt is unchanged.
    'force_sign', 1.0, ...         % Use -1 only if force calibration requires it.
    'osi_gain_initial', 1.0, ...
    'osi_gain_min', 0.2, ...
    'target_outer_ncf', 0.35, ... % GPT-5.6 regulated NCF target.
    'gpt5_6_override', struct(), ...
    'osi_branch_split_hz', [], ... % Used only if branch bands are empty.
    'osi_st_branch_hz', [2 10], ...
    'osi_residual_branch_hz', [30 80]);


%% Simulation Parameters
   
% Sampling Variables
fs = 2048;                      % Sampling frequency [Hz]
dt = 1/fs;                      % Sampling period [s]
zero_alpha = dt/0.5;              % Adaptive measurement zeroing update gain
t_ending = 5;                   % Smooth-stop transition time [s]

% phase_lead used on the Hybrid Simulation numerical dd command.
[phase_lead_data, phase_lead_file, phase_lead_name] = ...
    load_saved_result_file(projectFolder, 'phase_lead', false, ...
    hs.phase_lead_file);
phase_lead_tf = phase_lead_data.phase_lead_tf;
phase_lead_tf_discrete = c2d(phase_lead_tf, dt, 'tustin');
[phase_lead_num, phase_lead_den] = tfdata(phase_lead_tf_discrete, 'v');
phase_lead_num = phase_lead_num(:).';
phase_lead_den = phase_lead_den(:).';
pid_values = phase_lead_data.pid_values;
pid_P = pid_values.P;
pid_I = pid_values.I;
pid_D = pid_values.D;
pid_N = pid_values.derivative_filter_N;
fprintf('phase_lead loaded: %s\n', phase_lead_file)
fprintf('PID gains from phase_lead: P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', ...
    pid_P, pid_I, pid_D, pid_N)

% Conversion Factors
% Voltage to Engineering Units
v2d_gain        = 7.62;     % mm/volts  MTS/SG
v2d_const       = 0;                % mm
v2f_gain        = 4.448*1000;  % N/volts (1125.4109330128)
v2f_const       = 0;                % N
        v2a_gain        = -1000/510;         % g/volt, 510 mV/g
        v2a_const       = 0;                 % g
correction_gain = 1.013;     % This to address the minor change in input and output displacement calibration gain (should be close to 1)

% Hardware Channel Configuration
ch.am = 2;         % Acceleration measurement analog input
ch.dm = 3;         % Displacement measurement analog input
ch.fm = 4;         % Force measurement analog input
ch.dd = 5;         % Actuator command analog output
command_channel_selector = double((1:7)' == ch.dd);

% Saturation Limit
sat_limit = 70; % mm
                   
% Test File Name % IMPORTANT!
runStartTime = datetime('now');
timestampValue = runStartTime;
timestampValue.Format = 'yyyyMMdd_HHmm';
timestamp = char(timestampValue);
dateValue = runStartTime;
dateValue.Format = 'yyyyMMdd';
saveFolder = fullfile(projectFolder, 'saved_results', 'tests', char(dateValue));
file_name = fullfile(saveFolder, [timestamp '_' testname '.mat']);

% Make sure there is a folder named 'yyyymmdd'
% inside the 'saved_results/tests' folder
if ~exist(saveFolder, 'dir')
       mkdir(saveFolder)
       disp('A New Test Folder was created')
end

disp('Test File Name Created:')
disp(file_name)

%% Test Signal Parameters

% Select the active test signal manually in Simulink.
tend = inf;

[hs.fem, hs.fem_file, hs.fem_name] = loadFemDefinition( ...
    projectFolder, false, hs.fem_file);
fem_num = hs.fem.num;
fem_ref = hs.fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.K_if = K_if;
hs.K_ii = K_ii;
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, hs.fem);
hs.damping_ratio = hs.damping.target_ratio;
earthquakes = load(fullfile(projectFolder, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);

hs_M = hs.M;
hs_C = hs.C;
hs_K = hs.K;
hs_K_if = hs.K_if;
hs_K_ii = hs.K_ii;
hs_force_to_floor = hs.force_to_floor;
hs_interface_from_floor = hs.interface_from_floor;
hs_interface_from_force = hs.interface_from_force;
hs_ground_force_gain = hs.ground_force_gain;
hs_time = hs.time;
hs_ag = hs.ag;
hs_time_scale_factor_codegen = hs.time_scale_factor;
hs_force_sign_codegen = hs.force_sign;

gpt5_6_setup = prepare_gpt5_6_runtime(projectFolder, dt, hs);
exp_tf_file = gpt5_6_setup.exp_tf_file;
exp_tf_name = gpt5_6_setup.exp_tf_name;
fprintf('exp_tf loaded: %s\n', exp_tf_file)
fprintf(['GPT-5.6 setup: step %.3g s, target %.3g, initial %.3g, ' ...
    'minimum %.3g, publish delay %d ticks\n'], gpt5_6_setup.cfg.step_s, ...
    gpt5_6_setup.target_outer_ncf, gpt5_6_setup.gain_initial, ...
    gpt5_6_setup.gain_min, gpt5_6_setup.publish_ticks)

%%% 1- Time history parameters
        run(fullfile(projectFolder, 'input_signals', 'sample_time_history.m'))
        tend_time_history = time_history(end, 1);

%%% 3- BLWN parameters
% amp_2_percentile is the filtered BLWN amplitude exceeded by
% exceed_percentile percent of the samples.
        amp_2_percentile = 0.4;
        exceed_percentile = 0.5;
        f1 = 5;  % cutoff frequency (MUST be changed in the Simulink filter designer)

%%% 4- Chirp parameters
        f_init = 0.001;
        f_final = 20;
        tend_chirp = 30;
            


%% Running the Simulation

disp('===============================================================')
disp('                         Test Started                          ')
disp('===============================================================')

% Type Simulink model name
model = 'model_ColumnSetup_00';
% Clearing output variable
clear logsout

disp('Hybrid Simulation Setup:')
fprintf('  Earthquake type: %s\n', hs.earthquake_type)
fprintf('  Intensity factor: %.6g\n', hs.intensity_factor)
fprintf('  Earthquake duration: %.6g s\n', hs.time(end))
fprintf('  Time scale factor: %.6g\n', hs.time_scale_factor)
[~, fem_name, fem_ext] = fileparts(hs.fem_file);
[~, phase_lead_name, phase_lead_ext] = fileparts(phase_lead_file);
[~, exp_tf_name, exp_tf_ext] = fileparts(exp_tf_file);
fprintf('  FEM file: %s\n', [fem_name fem_ext])
fprintf('  phase_lead file: %s\n', [phase_lead_name phase_lead_ext])
fprintf('  exp_tf file: %s\n', [exp_tf_name exp_tf_ext])
fprintf('  OSI target: %.6g, gain initial: %.6g, minimum factor: %.6g\n', ...
    gpt5_6_setup.target_outer_ncf, gpt5_6_setup.gain_initial, ...
    gpt5_6_setup.gain_min)
continue_prompt = sprintf(['Continue and open Simulink? ' ...
    '(OSI minimum factor %.6g) (y/n): '], gpt5_6_setup.gain_min);
continue_response = lower(strtrim(input(continue_prompt, 's')));
if ~strcmp(continue_response, 'y')
    disp('Script stopped before opening Simulink.')
    return
end

tg = connect_speedgoat_target;
fileLogRunCountBefore = height(list(tg.FileLog));
load_system(model);
osi_gain_enable_parameter = Simulink.Parameter(0);
osi_gain_enable_parameter.CoderInfo.StorageClass = 'ExportedGlobal';
assignin(get_param(model, 'ModelWorkspace'), ...
    'osi_gain_enable_initial', osi_gain_enable_parameter);
open_system(model);
disp('*** Run the Simulink model ***')
disp('*** Click on "Run on Target" button under the "REAL-TIME" tab ***') 
disp('*** Once simulation is complete hit the space-bar to continue ***')
pause

% If running Simulink through MATLAB, uncomment and run the following script:
% Speedgoat_RunSimulink

%% Saving Data

projectFolder = fileparts(mfilename('fullpath'));
model = 'model_ColumnSetup_00';

if ~exist('logsout', 'var')
    fileLogRuns = list(tg.FileLog);
    assert(height(fileLogRuns) > fileLogRunCountBefore, ...
        ['No new Speedgoat file-log run was found. Refusing to import ' ...
         'and relabel an older experiment.']);
    tg.FileLog.import(fileLogRuns(end, :));
    logsout = evalin('base', 'logsout');
end

sig = logsout.FileLogSignals{1}.Values;
Results{1} = sig.Data;
t          = sig.Time;

dd = Results{1}(:,1);
dc = Results{1}(:,2);
dm = Results{1}(:,3);
fm = Results{1}(:,4);
am = Results{1}(:,5);
m_hat = [];
c_hat = [];
k_hat = [];
tse_fallback = [];
dd_pause_enable_log = [];
auth = [];
b_osi = [];
b_st = [];
b_res = [];
b_fast = [];
trip_reason = [];
valid = [];
decision = [];
g_armed = [];
u_osi = [];
if size(Results{1}, 2) >= 9
    m_hat = Results{1}(:,6);
    c_hat = Results{1}(:,7);
    k_hat = Results{1}(:,8);
    tse_fallback = Results{1}(:,9);
end
if size(Results{1}, 2) >= 10
    dd_pause_enable_log = Results{1}(:,10);
end
if size(Results{1}, 2) >= 18
    auth = Results{1}(:,11);
    b_osi = Results{1}(:,12);
    b_st = Results{1}(:,13);
    b_res = Results{1}(:,14);
    b_fast = Results{1}(:,15);
    trip_reason = Results{1}(:,16);
    valid = Results{1}(:,17);
    decision = Results{1}(:,18);
end
if size(Results{1}, 2) >= 21
    g_armed = Results{1}(:,19);
    u_osi = Results{1}(:,20);
end

units = struct('t', 's', 'dt', 's', 'fs', 'Hz', ...
    'dd', 'mm', 'dc', 'mm', 'dm', 'mm', ...
    'fm', 'N', 'am', 'g', 'm_hat', 'kg', 'c_hat', 'N*s/m', ...
    'k_hat', 'N/m', 'tse_fallback', 'dimensionless', ...
    'dd_pause_enable_log', 'dimensionless', ...
    'auth', 'dimensionless', 'b_osi', 'dimensionless', ...
    'b_st', 'dimensionless', 'b_res', 'dimensionless', ...
    'b_fast', 'dimensionless', 'trip_reason', 'code', ...
    'valid', 'logical', 'decision', 'code', ...
    'g_armed', 'logical', 'u_osi', 'mm');

result = struct('t', t, 'dd', dd, 'dc', dc, 'dm', dm, ...
    'fm', fm, 'am', am, 'fs', fs, 'dt', dt, ...
    'm_hat', m_hat, 'c_hat', c_hat, 'k_hat', k_hat, ...
    'tse_fallback', tse_fallback, ...
    'dd_pause_enable_log', dd_pause_enable_log, ...
    'auth', auth, 'b_osi', b_osi, 'b_st', b_st, ...
    'b_res', b_res, 'b_fast', b_fast, ...
    'trip_reason', trip_reason, 'valid', valid, ...
    'decision', decision, 'g_armed', g_armed, ...
    'u_osi', u_osi, ...
    'units', units, ...
    'Results', Results, 'logsout', logsout, 'testname', testname, ...
    'test_type', test_type, 'model', model, 'runStartTime', runStartTime, ...
    'file', [timestamp '_' testname '.mat']);
if exist('hs', 'var')
    result.hs = hs;
end
if exist('phase_lead_file', 'var')
    result.phase_lead_file = phase_lead_file;
end
if exist('phase_lead_name', 'var')
    result.phase_lead_name = phase_lead_name;
end
if exist('exp_tf_file', 'var')
    result.exp_tf_file = exp_tf_file;
end
if exist('exp_tf_name', 'var')
    result.exp_tf_name = exp_tf_name;
end
result.git_provenance = get_git_provenance(projectFolder);

save(file_name, 'result', '-v7.3')

disp('*** Data file saved! ***')
disp(file_name)

%% Finalizing the Simulation

disp('===============================================================')
disp('                        Test Completed!                        ')
disp('===============================================================')

%% Plotting Simulation Data

plot_test_result(result, file_name, exp_tf_file)
%%

%slrtExplorer

  
    
    
