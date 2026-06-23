function column = experimentalColumnDefinition()
%EXPERIMENTALCOLUMNDEFINITION Single source for the physical column definition.
% Units: height [m], E [N/m^2], Ix [m^4].

column.shape = 'W8x28';
column.height = 40*0.0254;           % [m]
column.E = 200e9;                    % [N/m^2]

% Exact SAP2000 v26 AISC15 property, shared with the frame definition.
column.section.Ix = 40790679.708799995e-12; % [m^4]
end
