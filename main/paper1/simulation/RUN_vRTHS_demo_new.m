%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%               Simulation Tool for v-RTHS MDOF benchmark                 %
%                                                                         %
%              IISL, Purdue University, West Lafayette, IN                %
%          SSTL, University of Illinois, Urbana-Champaign, IL             %
%                                                                         %
%                    Coded by:           Daniel Gomez                     %
%                    Collaborators:      Christian Silva                  %
%                                        Amin Maghareh                    %
%                    Supervised by:      Shirley J. Dyke                  % 
%                                        B.F.Spencer, Jr                  %  
%                    Created:                                             % 
%                                  November 01, 2017                      %
%                    Last Updated:                                        %
%                                  July 31, 2018                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc, clear, close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                             User Input                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Building_c = 1;            % Partitioning case (1-4)
plot_on = 'n';             % Plot RTHS results? ('y' or 'n')
modified = 1;              % Test modified version? (1=yes, 0=no)
consider_damage = 0;       % Consider damage? (1=yes, 0=no)
b_th = 0.13;               % Indicator threshold
num_add = 0;               % Number of additional (perturbed) trials
enable_indicator_plot = 1; % Plot indicator figure? (1=yes, 0=no)
test_name = 'test';        % Test name for saving results ('None' = use timestamp)

disp('=====================================================')
disp('     VIRTUAL RTHS MDOF BENCHMARK CONTROL PROBLEM     ')
disp('                   Simulation Tool                   ')
disp('=====================================================')
disp(' ')
real_time = 'n';  % Always run in non-real-time mode

fs = 4096;              % Sampling frequency [Hz]
dt_rths = 1/fs;         % Sampling period [sec]

%% Real-time option
simulink_file = 'vRTHS_2024';
load_system('vRTHS_MDOF_SimRT2014a.slx')
           
%%  Number of trials
num_t = 1+num_add;
for ii = 1:num_t

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                             Input file                              %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    F1_input_file
    F1_Modifications

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                             Controller                              %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    F2_controller

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                             Simulation                              %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    F3_simulation

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                             Evaluation                              %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    F4_evaluation
end

Results = table(J1, J2, J3, J4, J5, J6, J7, J8, J9,'RowNames',test)
disp('Note:')
disp('- Nominal and perturbed cases are described in the companion paper')
disp('- J1 is in [msec]')
disp('- J2 to J9 are in [%]')

%% Plot Indicator Figure
if enable_indicator_plot == 1
    run('helper/plot_indicator.m')
end
