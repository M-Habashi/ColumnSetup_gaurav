%% Script Header (Read First)

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
clear; clc; close all
addpath(genpath('helpers'));

disp('===============================================================')
disp('                         Column Setup                          ')
disp('                        Simulation Tool                        ')
disp('===============================================================')

%% Test Inputs
test_type = 'sp_1_ori_P15_I30';
testname = test_type;

%% Simulation Parameters
   
% Sampling Variables
fs = 2048;                      % Sampling frequency [Hz]
dt = 1/fs;                      % Sampling period [s]
zero_alpha = dt/0.5;              % Adaptive measurement zeroing update gain
t_ending = 5;                   % Smooth-stop transition time [s]

% Conversion Factors
% Voltage to Engineering Units
v2d_gain        = 7.62;     % mm/volts  MTS/SG
v2d_const       = 0;                % mm
v2f_gain        = 4.448*1000;  % N/volts (1125.4109330128)
v2f_const       = 0;                % N
v2a_gain        = -1000/510*9810;       % (mm/s^2)/volts  510mv/g
v2a_const       = 0;                % mm/s^2
correction_gain = 1.013;     % This to address the minor change in input and output displacement calibration gain (should be close to 1)

% Hardware Channel Configuration
ch.am = 2;         % Acceleration measurement analog input
ch.dm = 3;         % Displacement measurement analog input
ch.fm = 4;         % Force measurement analog input
ch.dd = 5;         % Actuator command analog output
command_channel_selector = double((1:7)' == ch.dd);

% Saturation Limit
sat_limit = 1; % mm
                   
% Test File Name % IMPORTANT!
timestamp = datestr(now,'yyyymmdd_HHMM');
projectFolder = fileparts(mfilename('fullpath'));
saveFolder = fullfile(projectFolder, 'saved_results', 'tests', datestr(now,'yyyymmdd'));
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

%%% 1- Time history parameters
        run(fullfile(projectFolder, 'input_signals', 'sample_time_history.m'))
        tend_time_history = time_history(end, 1);

%%% 3- BLWN parameters
% amp_2_percentile is the filtered BLWN amplitude exceeded by
% exceed_percentile percent of the samples.
        amp_2_percentile = 0.4;
        exceed_percentile = 0.5;
        f1 = 50;  % cutoff frequency (MUST be changed in the Simulink filter designer)

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

tg = connect_speedgoat_target;
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
    tg = slrealtime;
    fileLogRuns = list(tg.FileLog);
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

save(file_name, 't', 'dd', 'dc', 'dm', 'fm', 'am', 'fs', 'dt', ...
    'Results', 'logsout', 'testname', 'test_type', 'model', 'file_name', '-v7.3')

disp('*** Data file saved! ***')
disp(file_name)

%% Finalizing the Simulation

disp('===============================================================')
disp('                        Test Completed!                        ')
disp('===============================================================')

%% Plotting Simulation Data

outputVerificationFile = file_name;
run(fullfile(projectFolder, 'helpers', 'analysis_visualization', 'visualize_saved_results.m'))


%slrtExplorer
  
    
    
