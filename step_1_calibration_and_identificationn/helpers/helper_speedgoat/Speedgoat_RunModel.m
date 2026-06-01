function logsout = Speedgoat_RunModel(model, tend)
% Run a Simulink Real-Time model and return imported logsout.

open_system(model);
if ~isfile([model '.mldatx'])
    slbuild(model);
end

tg = slrealtime;

for attempt = 1:3
    try
        clear logsout
        evalin('base','clear logsout')
        tg.load(model)

        if nargin < 2
            tg.start('AutoImportFileLog',true);
        else
            tg.start('AutoImportFileLog',true,'StopTime',tend);
        end

        while ~strcmpi(tg.ModelStatus.State,'DONE')
            pause(0.05)
        end

        if exist('logsout','var')
            return
        end
        if evalin('base','exist(''logsout'',''var'')')
            logsout = evalin('base','logsout');
            return
        end
    catch ME
        if attempt == 3
            rethrow(ME)
        end
    end
    pause(2)
end

error('No logsout was returned from %s.',model)
end
