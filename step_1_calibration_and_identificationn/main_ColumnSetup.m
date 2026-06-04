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
% If this is a nw setup you need to make sure to adjust the following
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
testname = 'config';

%% Simulation Parameters
   
% Sampling Variables
fs = 2048;                      % Sampling frequency [Hz]
dt = 1/fs;                      % Sampling period [s]
zero_alpha = dt/0.5;              % Adaptive measurement zeroing update gain

% Conversion Factors
% Voltage to Enginnering Units
v2d_gain        = 7.62;     % mm/volts  MTS/SG
v2d_const       = 0;                % mm
v2f_gain        = 1000;  % N/volts (1125.4109330128)
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
sat_limit = 60; % mm
                   
% Test File Name % IMPORTANT!
timestamp = datestr(now,'yyyymmdd_HHMM');
projectFolder = fileparts(mfilename('fullpath'));
path = fullfile(projectFolder, 'saved_results', datestr(now,'yyyymmdd'));
file_name = fullfile(path, [timestamp '_' testname '.mat']);

% Make sure there is a folder named 'yyyymmdd'
% inside the 'saved_results' folder
if ~exist(path, 'dir')
       mkdir(path)
       disp('A New Test Folder was created')
end

disp('Test File Name Created:')
disp(file_name)

%% Test Signal Selection

% Select type of test signal
% 1: Stair signal (Calibration) or Time History Signal
% 2: Sine Wave (Edit parameters in Simulink)
% 3: BLWN
% 4: Chirp
% 5: constant


test_signal = 3;


%%% 1- Stair Signal Calculation
    % User-defined parameters
    start_dsip  = -7*v2d_gain;    % mm, Starting displacement
    end_disp    = 7*v2d_gain;     % mm, Ending displacement
    increment   = 1*v2d_gain;     % mm, Increment value
    step_length = 5;              % Seconds

    % Calculate the number of steps
    stair_steps = start_dsip:increment:end_disp;

    % Generate the stair signal
    clearvars stair_signal
    stair_signal = [];
    for ii = 1:length(stair_steps)
        stair_signal = [stair_signal (1:step_length/dt)*0 + stair_steps(ii)]; % Signal vector
    end
    stair_time_smoothed   = [];
    stair_signal_smoothed = [];
    for ii = 1:length(stair_steps)
        % Smooth the stair signal
        stair_time_period   = ((ii-1)*step_length/dt:ii*step_length/dt-1)*dt;
        stair_signal_period = stair_signal((ii-1)*step_length/dt+1:ii*step_length/dt);
        stair_time_smoothed = [stair_time_smoothed; stair_time_period'];
        % Apply spline interpolation
        x_ramp = [stair_time_period(1) stair_time_period(floor(length(stair_time_period)/5)) stair_time_period(floor(length(stair_time_period)/2))];
        y_ramp = [stair_signal_period(1)-increment stair_signal_period(1)-0.35*increment stair_signal_period(end)];
        stair_signal_period_smoothed = spline(x_ramp, y_ramp, stair_time_period(1:floor(length(stair_time_period)/2)));
        stair_signal_period_smoothed = [stair_signal_period_smoothed stair_signal_period(floor(length(stair_signal_period)/2)+1:end)];
        stair_signal_smoothed = [stair_signal_smoothed; stair_signal_period_smoothed'];
    end
    stair_time = (1:length(stair_steps)*step_length/dt)*dt; % Time vector
%                 % Plot the stair signal
%                 plot(stair_time, stair_signal); hold on
%                 grid on; grid minor
%                 xlim([0 stair_time(end)]);
%                 xlabel('Time')
%                 ylabel('Voltage')
%                 title('Stair Signal')
% 
%                 % Plot the smoothed stair signal
%                 plot(stair_time_smoothed, stair_signal_smoothed)
%                 grid on; grid minor
%                 xlim([0 stair_time_smoothed(end)]);
%                 xlabel('Time')
%                 ylabel('Voltage')
%                 title('Stair Signal Smoothed'); hold off

    tend_stair = stair_time_smoothed(end);
    time_history = [stair_time_smoothed stair_signal_smoothed];

%%% 2- Sine wave parameters

%%% 3- BLWN parameters
        wn_power = 0.01;
        wn_bandwidth = 2;  % in HZ  (Design the filter from simulink)
        
        std_blwn = 4;
        f1 = 20;  % cutoff frequency
        tend_BLWN = 120;

%%% 4- Chirp parameters
        f_init = 0.001;
        f_final = 50;
        % chirp_gain = 5 * v2d_gain;
        chirp_gain = 5;
        tend_chirp = 90;
            

switch test_signal
    case 1  % Stair Signal
        
        tend = tend_stair;
 
    case 2  % Sine

        tend = 30000;
        
    case 3  % BLWN

        tend = tend_BLWN;
        
    case 4  % Chirp  

        tend = tend_chirp;
        
    case 5  % Chirp  

        tend = inf;
end

%% Initializing the Simulation

% Keep old initial-voltage offsets neutral; measurement zeroing is handled in the model.
ini_v = zeros(1,7);

%% Running the Simulation

disp('===============================================================')
disp('                         Test Started                          ')
disp('===============================================================')

% Type Simulink model name
model = 'model_ColumnSetup_00';
% Clearing output variable
clear logsout

% If running Simulink directly:
open_system(model);
disp('*** Run the Simulink model ***')
disp('*** Click on "Run on Target" button under the "REAL-TIME" tab ***') 
disp('*** Once simulation is complete hit the space-bar to continue ***')
pause

% If running Simulink through MATLAB, uncomment and run the following script:
% Speedgoat_RunSimulink

%% Getting Simulation Data

if exist('logsout','var')
    Results{1} = logsout.FileLogSignals{1}.Values.Data;
    t          = logsout.FileLogSignals{1}.Values.Time;

    dd = Results{1}(:,1);
    dc = Results{1}(:,2);
    dm = Results{1}(:,3);
    fm = Results{1}(:,4);
    am = Results{1}(:,5);
    
    save(file_name)
    disp('*** Data file saved! ***')
else
    disp('*** No output variable exist.***')
    disp('*** No .mat file saved. ***')
    disp('*** Check simulation. ***')
end

%% Finilazing the Simulation

% Closing the model
save_system(model)
close_system(model)

disp('===============================================================')
disp('                        Test Completed!                        ')
disp('===============================================================')

%% Plotting Simulation Data

outputVerificationFile = file_name;
run(fullfile(projectFolder, 'helpers', 'visualization', 'visualize_saved_results.m'))


%slrtExplorer
  
    
    
