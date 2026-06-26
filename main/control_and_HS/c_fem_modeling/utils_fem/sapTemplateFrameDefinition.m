function frame = sapTemplateFrameDefinition()
%SAPTEMPLATEFRAMEDEFINITION Inputs reproduced from sap/template.sdb.
%   Specimen-specific calibration is performed by build_fem_3.m; this
%   function contains only the immutable template properties.
% Units: length [m], E [N/m^2], Ix [m^4], rotational stiffness [N*m/rad].

frame.n_story = 3;
frame.n_bay = 3;
frame.bay_width = 10*0.3048;         % [m]
frame.story_height = 6.67*0.3048;    % [m]
frame.E = 200e9;                     % [N/m^2]

% Exact values returned by SAP2000 v26 for the AISC15 sections.
frame.section.W8x24.Ix = 34422337.62688249e-12;
frame.section.W8x28.Ix = 40790679.708799995e-12;
frame.section.W8x35.Ix = 52861391.051199995e-12;
frame.section.W12x40.Ix = 127783047.65919998e-12;

frame.beam_connection_k = Inf;
frame.base_rotation_k = 1.04e7;      % [N*m/rad], sap/template.sdb
end
