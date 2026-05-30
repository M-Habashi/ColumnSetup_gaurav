% Ramping actuator to zero
% By: Mohameed Gomaa
% Updated on 07/10/2024 by Edwin

Speedgoat_ReadOffsets

ramp_ini_v = ini_v(ch.dm);
% 0.256196610889764 in/sec*(25.4 mm/in)*(1/6.5073939166 volts/mm) = 1 volts/sec
ramp_vel = 1; % volts/sec
ramp_slope = -sign(ramp_ini_v)*ramp_vel;
ramp_time = 1 + abs(ramp_ini_v)/ramp_vel;

tend_ramp = ceil(ramp_time) + 2;

model = 'Model_Speedgoat_RampToZero';

open_system(model); slbuild(model);
tg = slrealtime; tg.load(model)

tg.start('AutoImportFileLog',true,'StopTime',tend_ramp);
T = timer('TimerFcn',@(~,~)disp('*** Ramping actuator to zero...***'),...
    'StartDelay',tend_ramp+5); start(T); wait(T);

close_system(model)

disp(' ')
disp('*** RampToZero Complete! ***')

