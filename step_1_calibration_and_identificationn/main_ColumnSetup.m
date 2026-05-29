%% Script Header (Read First)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%              ***  Simulation Tool for ColumnSetup ***                   %
%                     MATLAB/SIMULINK Version R2020b                      %
%            ===============================================              %
%                                                                         %
%              IISL, Purdue University, West Lafayette, IN                %
%                                                                         %
%              Coded by:           Mohamed Gomaa                          %
%                                  Edwin Patino**                         %
%                                  Tao Zhang                              %
%                                                                         %
%              Supervised by:      Shirley J. Dyke                        %
%                                                                         %
%              Created:            June 24, 2024                          %
%                                                                         %
%              Last Updated:       May 28, 2024                        %
%                                  by: Mohamed                       %
%                                                                         %
%                                                                         %
%                                                                         %
% **: Lead contact                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Note Board (Read First)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1. Purpose: This script and Simulink model provide a basic setup for
% running four types of signals (stair signal, sine wave, BLWN, and 
% frequency sweep) in the ColumnSetup. The goal is to help you 
% familiarize yourself with the setup and the interaction between MATLAB, 
% Simulink, and Speedgoat. This is a Ready-to-Run Model with current
% Simulink-Speedgoat-MTS configurations as of 07/30/2024.

% 2. Attention: Pay close attention to the comments that will appear in the
% command window as these will provide you with important information about
% the test status and the steps you need to follow.

% 3. Assistance: If you need help getting started with this script, are 
% unsure about how to use any feature, or have a recommended modification,
% please contact any of the people listed above before proceeding.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Preparing the Workspace
tmp = matlab.desktop.editor.getActive;
cd(fileparts(tmp.Filename));
clear; clc; close all

disp('===============================================================')
disp('                         Column Setup                          ')
disp('                        Simulation Tool                        ')
disp('===============================================================')

%% Simulation Parameters
   
% Sampling Variables
fs = 2048;                      % Sampling frequency [Hz]
dt = 1/fs;                      % Sampling period [s]

% Conversion Factors
% Voltage to Enginnering Units
v2d_gain        = 7.62;     % mm/volts  MTS/SG
v2d_const       = 0;                % mm
v2f_gain        = 1000;  % N/volts (1125.4109330128)
v2f_const       = 0;                % N
v2a_gain        = -1000/50.6;       % (mm/s^2)/volts
v2a_const       = 0;                % mm/s^2
correction_gain = 1.01;     % Volts MTS/Volts Speedgoat

% Saturation Limit
sat_limit = 130/v2d_gain; % Volts
                   
% Test File Name % IMPORTANT!
datename = datestr(now,'mmddyyyy');         % Date
nametime = datestr(now,'HHMMSS');           % Time 
path     = ['.\2_TestFiles\' datename '\']; % Path to load files
type     = 'Test_';                         % Type of test
date     = [datename '_'];                  % Date experimental data was taken
time     = [nametime '_'];                  % Time

signal   = 'Signal_';                       % Type of signal
feat1    = '01_';                           % Number of test
feat2    = 'Hz_';                           % Signal frequency
feat3    = 'NA_';                           % Feature 3

feat4    = 'plate';                         % Specimen
feat5    = '';                              % Feature 5
feat6    = '.mat';                          % File extension

file_name     = strcat(path,type,date,time,signal,feat1,feat2,feat3,feat4,feat5,feat6);

% Make sure there is a folder named 'mmddyyyy'
% inside the '2_TestFiles' folder
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


test_signal = 2;


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
        wn_power = 1;
        wn_bandwidth = 50;  % in HZ  (Design the filter from simulink)
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

% Adding supporting files
addpath(genpath('1_SupportFiles'));
% Ramping all channels to zero
Speedgoat_RampToZero
% Reading the initial vaues of voltages for all channels
Speedgoat_ReadOffsets

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
    vc = Results{1}(:,3);
    dm = Results{1}(:,4);
    fm = Results{1}(:,5);
    am = Results{1}(:,6);
    
    save(file_name)
    savedfile_flag = 1;
    disp('*** Data file saved! ***')
else
    disp('*** No output variable exist.***')
    disp('*** No .mat file saved. ***')
    disp('*** Check simulation. ***')
end

%% Finilazing the Simulation

if exist('savedfile_flag','var')
    % Closing the model
    save_system(model)
    close_system(model)

    % Ramping all channels to zero
    % ATTENTION: output variable will be cleared.
    
    if input('Ramp to Zero? (logsout will be cleared) (Y/N): ','s') == 'Y'
        Speedgoat_RampToZero
        clear logsout
    end
    
    disp('===============================================================')
    disp('                        Test Completed!                        ')
    disp('===============================================================')
 
end

%% Plotting Simulation Data

if exist('savedfile_flag','var')
    
    figure('WindowState','maximized');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    subplot(311)
    plot(t,dd,'r'); hold on
    plot(t,dm,'b');
    title('Displacement Time History');
    grid on; xlabel('Time (sec)'); ylabel('Displacement (mm)');
    legend('Desired displacement' ,'Measured displacement');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    subplot(312)
    plot(t,fm,'b');
    title('Measured Force History');
    grid on; xlabel('Time (sec)'); ylabel('Measured Force (N)');
    legend('Measured force');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    subplot(313)
    plot(t,am,'b');
    title('Measured Acceleration History');
    grid on; xlabel('Time (sec)'); ylabel('Measured Acceleration (mm/s^2)');
    legend('Measured Acceleration');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
end



  
    
    
