% Determining the offset in the measured signals
% By: Mohameed Gomaa
% Updated on 07/10/2024 by Edwin

model = 'Model_Speedgoat_ReadOffset';
tend_offset = 1;  % Seconds

logsout = Speedgoat_RunModel(model,tend_offset);

disp('*** Reading offsets in channels...***')

if isfield(logsout,'LiveStreamSignals')
    measured_data = logsout.LiveStreamSignals{1}.Values.Data;
else
    measured_data = logsout.FileLogSignals{1}.Values.Data;
end
ini_v = mean(measured_data);

close_system(model)

disp(' ')
disp('*** ReadOffsets Complete! ***')

% Simulink.sdi.view
% slrtExplorer
