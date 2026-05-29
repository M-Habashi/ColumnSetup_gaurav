% Determining the offset in the measured signals
% By: Mohameed Gomaa
% Updated on 07/10/2024 by Edwin

model = 'Model_Speedgoat_ReadOffset';
tend_offset = 5;  % Seconds

open_system(model); slbuild(model);
tg = slrealtime; tg.load(model)

tg.start('AutoImportFileLog',true,'StopTime',tend_offset);
T = timer('TimerFcn',@(~,~)disp('*** Reading offsets in channels...***'),...
    'StartDelay',tend_offset+5); start(T); wait(T);

measured_data = logsout.LiveStreamSignals{1}.Values.Data;
ini_v = mean(measured_data);

close_system(model)

disp(' ')
disp('*** ReadOffsets Complete! ***')

% Simulink.sdi.view
% slrtExplorer
