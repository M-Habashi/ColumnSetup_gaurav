function [targetNCF, alpha] = scripted_controller_c_settings
%SCRIPTED_CONTROLLER_C_SETTINGS Resolve Controller C settings for commands.
%   Habashi commands use values left in the base workspace by
%   scripted_main. If scripted_main has not been run in this MATLAB session,
%   the current standalone defaults below are used.

targetNCF = baseValueOrDefault('target_ncf_c', 0.21);
alpha = baseValueOrDefault('target_ncf_c_alpha', 0.1);

validateattributes(targetNCF, {'numeric'}, ...
    {'real', 'finite', 'scalar', '>', 0, '<', 1}, ...
    mfilename, 'target_ncf_c');
validateattributes(alpha, {'numeric'}, ...
    {'real', 'finite', 'scalar', '>=', 0, '<=', 1}, ...
    mfilename, 'target_ncf_c_alpha');
end

function value = baseValueOrDefault(variableName, defaultValue)
existsInBase = evalin('base', sprintf( ...
    'exist(''%s'', ''var'') == 1', variableName));
if existsInBase
    value = evalin('base', variableName);
else
    value = defaultValue;
end
end
