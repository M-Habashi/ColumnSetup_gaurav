%% VALIDATE MATLAB FEM AGAINST SAP2000 TEMPLATE
% SAP case DEAD applies +1000 N at the first floor. The expected floor
% translations were read from sap/template.sdb through the SAP2000 v26 API.

clear;
clc;

frame = sapTemplateFrameDefinition();
[K, ~] = assembleCondensedFrameStiffness( ...
    frame.n_story, frame.n_bay, frame.bay_width, frame.story_height, ...
    frame.E, frame.section, frame.beam_connection_k, ...
    frame.base_rotation_k);

sap_load = [1000; 0; 0];             % [N]
sap_displacement = [ ...
    0.052457635652102444;
    0.06702527044325596;
    0.06941380096760506];            % [mm]
fem_displacement = K\sap_load;
absolute_error = abs(fem_displacement-sap_displacement);

assert(max(absolute_error) < 1e-10, ...
    'MATLAB FEM does not match the SAP template static response.');

fprintf('\nMATLAB FEM and SAP template static comparison\n');
fprintf('Base rotational stiffness: %.12g N*mm/rad\n', ...
    frame.base_rotation_k);
fprintf('Floor   SAP (mm)          MATLAB FEM (mm)   Absolute error (mm)\n');
for floor_id = 1:frame.n_story
    fprintf('%5d   % .12e   % .12e   %.3e\n', floor_id, ...
        sap_displacement(floor_id), fem_displacement(floor_id), ...
        absolute_error(floor_id));
end
fprintf('Maximum absolute error: %.3e mm\n\n', max(absolute_error));
