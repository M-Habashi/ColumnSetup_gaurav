function column = experimentalColumnDefinition()
%EXPERIMENTALCOLUMNDEFINITION Single source for the physical column definition.

column.shape = 'W8x28';
column.height_mm = 40*25.4;          % [mm]
column.E = 200000;                   % [N/mm^2]

% Exact SAP2000 v26 AISC15 property, shared with the frame definition.
column.section.Ix = 40790679.708799995; % [mm^4]
end
