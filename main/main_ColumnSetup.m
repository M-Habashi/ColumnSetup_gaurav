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
test_type = 'RTHS_02';
testname = test_type;

%% Hybrid Simulation Parameters
hs = struct( ...
    'fem_file', fullfile(projectFolder, 'saved_results', 'fem', ...
     'fem_sp_1_org_3.mat'), ... % Run build_fem_3.m first.
    'delay_comp_file', fullfile(projectFolder, 'saved_results', ...
     'delay_comp', 'fem3_ncf3.mat'), ...
    'earthquake_type', 'el_centro', ... % Field name in input_signals/earthquakes.mat.
    'intensity_factor', 0.06, ...   % Earthquake acceleration multiplier.
    'time_scale_factor', 1.0, ...  % >1 stretches earthquake time; dt is unchanged.
    'force_sign', 1.0);            % Use -1 only if force calibration requires it.


%% Simulation Parameters
   
% Sampling Variables
fs = 2048;                      % Sampling frequency [Hz]
dt = 1/fs;                      % Sampling period [s]
zero_alpha = dt/0.5;              % Adaptive measurement zeroing update gain
t_ending = 5;                   % Smooth-stop transition time [s]

% Phase-lead compensator used on the Hybrid Simulation numerical dd command.
[delay_comp_data, delay_comp_file, delay_comp_name] = ...
    load_saved_result_file(projectFolder, 'delay_comp', false, ...
    hs.delay_comp_file);
delay_comp_tf = delay_comp_data.delay_comp_tf;
delay_comp_tf_discrete = c2d(delay_comp_tf, dt, 'tustin');
[delay_comp_num, delay_comp_den] = tfdata(delay_comp_tf_discrete, 'v');
delay_comp_num = delay_comp_num(:).';
delay_comp_den = delay_comp_den(:).';
fprintf('Phase-lead compensator loaded: %s\n', delay_comp_file)

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

data = load(hs.fem_file, 'fem');
hs.fem = data.fem;
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
fprintf('  FEM file: %s\n', hs.fem_file)
fprintf('  Delay compensator file: %s\n', delay_comp_file)
continue_response = lower(strtrim(input('Continue and open Simulink? (y/n): ', 's')));
if ~strcmp(continue_response, 'y')
    disp('Script stopped before opening Simulink.')
    return
end

tg = connect_speedgoat_target;
fileLogRunCountBefore = height(list(tg.FileLog));
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
if size(Results{1}, 2) >= 9
    m_hat = Results{1}(:,6);
    c_hat = Results{1}(:,7);
    k_hat = Results{1}(:,8);
    tse_fallback = Results{1}(:,9);
end

units = struct('t', 's', 'dt', 's', 'fs', 'Hz', ...
    'dd', 'mm', 'dc', 'mm', 'dm', 'mm', ...
    'fm', 'N', 'am', 'g', 'm_hat', 'kg', 'c_hat', 'N*s/m', ...
    'k_hat', 'N/m', 'tse_fallback', 'dimensionless');

result = struct('t', t, 'dd', dd, 'dc', dc, 'dm', dm, ...
    'fm', fm, 'am', am, 'fs', fs, 'dt', dt, ...
    'm_hat', m_hat, 'c_hat', c_hat, 'k_hat', k_hat, ...
    'tse_fallback', tse_fallback, 'units', units, ...
    'Results', Results, 'logsout', logsout, 'testname', testname, ...
    'test_type', test_type, 'model', model, 'runStartTime', runStartTime, ...
    'file', [timestamp '_' testname '.mat']);
if exist('hs', 'var')
    result.hs = hs;
end
if exist('delay_comp_file', 'var')
    result.delay_comp_file = delay_comp_file;
end
if exist('delay_comp_name', 'var')
    result.delay_comp_name = delay_comp_name;
end

save(file_name, 'result', '-v7.3')

disp('*** Data file saved! ***')
disp(file_name)

%% Finalizing the Simulation

disp('===============================================================')
disp('                        Test Completed!                        ')
disp('===============================================================')

%% Plotting Simulation Data

if ~exist('result', 'var')
    fprintf('\nLoaded data uses the old saved-result format.\n')
    fprintf('Convert saved test MAT files from the main folder with:\n')
    fprintf('  convert_saved_result_to_struct\n\n')
    return
end
if exist('projectFolder', 'var') ...
        && isfolder(fullfile(projectFolder, 'results_analysis'))
    addpath(fullfile(projectFolder, 'results_analysis'))
elseif isfolder(fullfile(pwd, 'results_analysis'))
    addpath(fullfile(pwd, 'results_analysis'))
end
visualize_saved_results(result)

%% Hybrid Simulation Reference Comparison

% Compare the recorded HS response against the full FEM reference.
try
    if exist('hs', 'var') && isfield(hs, 'fem') ...
            && exist('file_name', 'var') && isfile(file_name)
        compare_hs_response_to_reference(hs.fem, file_name, ...
            hs.earthquake_type, hs.intensity_factor, ...
            hs.time_scale_factor, hs.force_sign);
    else
        compare_hs_response_to_reference();
    end
catch ME
    fprintf('Comparison failed: %s\n', ME.message)
end
%%

%slrtExplorer

  
    
    
