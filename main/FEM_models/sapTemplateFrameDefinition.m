function frame = sapTemplateFrameDefinition()
%SAPTEMPLATEFRAMEDEFINITION Inputs reproduced from sap/template.sdb.
%   The SAP model stores the base spring rounded to the nearest 1e8
%   N*mm/rad. Its unrounded value is calibrated from sp1_ori_2.mat by the
%   same equation used in build_FEM.m.

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
specimen_file = fullfile(project_root, 'saved_results', 'specimens', ...
    'sp1_ori_2.mat');
assert(isfile(specimen_file), 'SAP calibration specimen not found: %s', ...
    specimen_file);
specimen = load(specimen_file, 'k');

column = experimentalColumnDefinition();
[calibrated_base_rotation_k, ~] = calculateBaseRotationStiffness( ...
    specimen.k, column);
sap_rounding_increment = 1e8;

frame.n_story = 3;
frame.n_bay = 3;
frame.bay_width = 10*304.8;          % [mm]
frame.story_height = 6.67*304.8;     % [mm]
frame.E = 200000;                    % [N/mm^2]

% Exact values returned by SAP2000 v26 for the AISC15 sections.
frame.section.W8x24.Ix = 34422337.62688249;
frame.section.W8x28.Ix = 40790679.708799995;
frame.section.W8x35.Ix = 52861391.051199995;

frame.beam_connection_k = Inf;
frame.base_rotation_k_calibrated = calibrated_base_rotation_k;
frame.base_rotation_k = round( ...
    calibrated_base_rotation_k/sap_rounding_increment) ...
    *sap_rounding_increment;
frame.specimen_file = specimen_file;

assert(frame.base_rotation_k == 1.04e10, ...
    ['The selected specimen no longer reproduces the rotational spring ' ...
     'stored in sap/template.sdb.']);
end
