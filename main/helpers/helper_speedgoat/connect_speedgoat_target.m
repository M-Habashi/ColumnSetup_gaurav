function tg = connect_speedgoat_target(targetName)
%CONNECT_SPEEDGOAT_TARGET Connect to the Simulink Real-Time target.

    if nargin < 1 || isempty(targetName)
        tg = slrealtime;
    else
        tg = slrealtime(targetName);
    end

    if ~isConnected(tg)
        connect(tg);
    end

    disp('Simulink Real-Time target is connected.')
end
