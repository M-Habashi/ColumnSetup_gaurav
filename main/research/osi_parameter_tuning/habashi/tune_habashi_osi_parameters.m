%% Habashi GPT-5.6.4 OSI Parameter Tuning
% Edit habashi_osi_parameter_sets.m, run this script, choose a saved test
% record, and compare the replayed OSI behavior against the current
% implementation. Both parameter sets replay through the deployed
% historical control_and_HS/OSI V1 implementation.

clear; close all; clc

script_root = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(script_root)));
addpath(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

%% Build New And Current Parameter Sets
[new_params, current_params] = habashi_osi_parameter_sets(projectFolder);

%% Select Testing Data
[test_data, test_file, test_name] = load_saved_result_file(projectFolder, ...
    'tests');
fprintf('Selected test data: %s\n', test_file)

%% Plot Replay Comparison
clear plot_habashi_osi_parameter_comparison sol_osi_v1_runtime
rehash
habashi_osi_comparison = plot_habashi_osi_parameter_comparison( ...
    test_data, test_file, new_params, current_params);
assignin('base', 'habashi_osi_comparison', habashi_osi_comparison)
fprintf('Comparison complete for %s\n', test_name)
