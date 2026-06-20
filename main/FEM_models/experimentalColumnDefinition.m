function column = experimentalColumnDefinition()
%EXPERIMENTALCOLUMNDEFINITION Single source for the physical column definition.

column.shape = 'W8x28';
column.height_mm = 40*25.4;          % [mm]
column.E = 200000;                   % [N/mm^2]

column.section.Ix = 40.8e6;          % [mm^4]
end
