function [configuration, configurationPath] = ...
        scripted_last_run_configuration(projectRoot, p)
%SCRIPTED_LAST_RUN_CONFIGURATION Save or load the last completed run setup.

arguments
    projectRoot (1,:) char
    p = []
end

if ~isempty(p) && (~isstruct(p) || ~isscalar(p))
    error('scripted:LastRunConfigurationInput', ...
        'p must be a scalar parameter structure when provided.')
end

configurationPath = fullfile(projectRoot, 'Results', ...
    'scripted_last_run_configuration.mat');

if isempty(p)
    configuration = struct.empty;
    if ~isfile(configurationPath)
        return
    end
    loaded = load(configurationPath, 'configuration');
    if ~isfield(loaded, 'configuration') || ...
            ~isValidConfiguration(loaded.configuration)
        warning('scripted:LastRunConfigurationFormat', ...
            'Ignoring an incompatible last-run configuration snapshot.')
        return
    end
    configuration = loaded.configuration;
    return
end

configuration = struct;
configuration.Version = 1;
configuration.CompletedAt = datetime('now');
configuration.Options = p.options;
configuration.ControllerA = controllerRecord(p.controller_a);
configuration.ControllerB = controllerRecord(p.controller_b);
configuration.ControllerC = controllerRecord(p.controller_c);

resultsDirectory = fileparts(configurationPath);
if ~isfolder(resultsDirectory)
    mkdir(resultsDirectory)
end
save(configurationPath, 'configuration')
end

function record = controllerRecord(controller)
record = struct('Kp', controller.Kp, 'Ki', controller.Ki, ...
    'Kd', controller.Kd, 'Tf', controller.Tf);
end

function valid = isValidConfiguration(configuration)
required = {'Version', 'CompletedAt', 'Options', 'ControllerA', ...
    'ControllerB', 'ControllerC'};
controllerFields = {'Kp', 'Ki', 'Kd', 'Tf'};
valid = isstruct(configuration) && isscalar(configuration) && ...
    all(isfield(configuration, required)) && ...
    isstruct(configuration.Options) && ...
    all(isfield(configuration.ControllerA, controllerFields)) && ...
    all(isfield(configuration.ControllerB, controllerFields)) && ...
    all(isfield(configuration.ControllerC, controllerFields));
end
