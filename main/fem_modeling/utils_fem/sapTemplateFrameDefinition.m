function frame = sapTemplateFrameDefinition()
%SAPTEMPLATEFRAMEDEFINITION Inputs reproduced from sap/template.sdb.
%   Specimen-specific calibration is performed by build_fem.m; this
%   function contains only the immutable template properties.

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
frame.base_rotation_k = 1.04e10;     % [N*mm/rad], sap/template.sdb
end
