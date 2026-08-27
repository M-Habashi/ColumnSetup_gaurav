%% Recover and Save an Unsaved Speedgoat Result
% Run after main_ColumnSetup stops because logsout was not imported in time.
% The completed experiment and its initialized base workspace must still be
% available. This script does not start or rerun the physical experiment.

projectFolder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(projectFolder, 'helpers', 'utils'))

required = {'fs', 'dt', 'testname', 'test_type', 'runStartTime', ...
    'pid_values', 'pid_gain_source', 'file_name'};
missing = required(~cellfun(@(v) evalin('base', ...
    sprintf('exist(''%s'', ''var'')', v)), required));
assert(isempty(missing), ...
    'Required main_ColumnSetup workspace variables are missing: %s', ...
    strjoin(missing, ', '))

if ~exist('logsout', 'var')
    assert(exist('tg', 'var') == 1, ...
        'Neither logsout nor the Speedgoat target object tg is available.')

    importStarted = false;
    importTimer = tic;
    while ~evalin('base', 'exist(''logsout'', ''var'')') && toc(importTimer) < 60
        fileLogRuns = list(tg.FileLog);
        newRunAvailable = height(fileLogRuns) > 0;
        if exist('fileLogRunCountBefore', 'var')
            newRunAvailable = height(fileLogRuns) > fileLogRunCountBefore;
        end

        if newRunAvailable && ~importStarted
            tg.FileLog.import(fileLogRuns(end, :));
            importStarted = true;
        end
        pause(0.5)
    end

    assert(evalin('base', 'exist(''logsout'', ''var'')') == 1, ...
        'The latest Speedgoat file log did not import within 60 seconds.')
    logsout = evalin('base', 'logsout');
end

sig = logsout.FileLogSignals{1}.Values;
Results{1} = sig.Data;
t = sig.Time;

assert(size(Results{1}, 2) >= 5, ...
    'The recovered file log contains fewer than five required channels.')
dd = Results{1}(:, 1);
dc = Results{1}(:, 2);
dm = Results{1}(:, 3);
fm = Results{1}(:, 4);
am = Results{1}(:, 5);
m_hat = [];
c_hat = [];
k_hat = [];
tse_fallback = [];
dd_pause_enable_log = [];
auth = [];
b_osi = [];
b_st = [];
b_res = [];
b_fast = [];
trip_reason = [];
valid = [];
decision = [];
g_armed = [];
u_osi = [];

if size(Results{1}, 2) >= 9
    m_hat = Results{1}(:, 6);
    c_hat = Results{1}(:, 7);
    k_hat = Results{1}(:, 8);
    tse_fallback = Results{1}(:, 9);
end
if size(Results{1}, 2) >= 10
    dd_pause_enable_log = Results{1}(:, 10);
end
if size(Results{1}, 2) >= 18
    auth = Results{1}(:, 11);
    b_osi = Results{1}(:, 12);
    b_st = Results{1}(:, 13);
    b_res = Results{1}(:, 14);
    b_fast = Results{1}(:, 15);
    trip_reason = Results{1}(:, 16);
    valid = Results{1}(:, 17);
    decision = Results{1}(:, 18);
end
if size(Results{1}, 2) >= 20
    g_armed = Results{1}(:, 19);
    u_osi = Results{1}(:, 20);
end

units = struct('t', 's', 'dt', 's', 'fs', 'Hz', ...
    'dd', 'mm', 'dc', 'mm', 'dm', 'mm', ...
    'fm', 'N', 'am', 'g', 'm_hat', 'kg', 'c_hat', 'N*s/m', ...
    'k_hat', 'N/m', 'tse_fallback', 'dimensionless', ...
    'dd_pause_enable_log', 'dimensionless', ...
    'auth', 'dimensionless', 'b_osi', 'dimensionless', ...
    'b_st', 'dimensionless', 'b_res', 'dimensionless', ...
    'b_fast', 'dimensionless', 'trip_reason', 'code', ...
    'valid', 'logical', 'decision', 'code', ...
    'g_armed', 'logical', 'u_osi', 'mm');

model = 'model_ColumnSetup_00';
[~, savedName, savedExtension] = fileparts(file_name);
result = struct('t', t, 'dd', dd, 'dc', dc, 'dm', dm, ...
    'fm', fm, 'am', am, 'fs', fs, 'dt', dt, ...
    'm_hat', m_hat, 'c_hat', c_hat, 'k_hat', k_hat, ...
    'tse_fallback', tse_fallback, ...
    'dd_pause_enable_log', dd_pause_enable_log, ...
    'auth', auth, 'b_osi', b_osi, 'b_st', b_st, ...
    'b_res', b_res, 'b_fast', b_fast, ...
    'trip_reason', trip_reason, 'valid', valid, ...
    'decision', decision, 'g_armed', g_armed, ...
    'u_osi', u_osi, 'units', units, ...
    'Results', Results, 'logsout', logsout, 'testname', testname, ...
    'test_type', test_type, 'model', model, 'runStartTime', runStartTime, ...
    'pid_values', pid_values, 'pid_gain_source', pid_gain_source, ...
    'file', [savedName savedExtension]);

if exist('hs', 'var'), result.hs = hs; end
if exist('phase_lead_file', 'var'), result.phase_lead_file = phase_lead_file; end
if exist('phase_lead_name', 'var'), result.phase_lead_name = phase_lead_name; end
if exist('exp_tf_file', 'var'), result.exp_tf_file = exp_tf_file; end
if exist('exp_tf_name', 'var'), result.exp_tf_name = exp_tf_name; end

result.git_provenance = get_git_provenance(projectFolder);
[result, missingDependencies] = embed_saved_result_dependencies( ...
    result, projectFolder);
assert(isempty(missingDependencies), ...
    'Saved result dependencies could not be embedded: %s', ...
    strjoin(missingDependencies, '; '))

if isempty(regexp(char(file_name), '^[A-Za-z]:[\\/]|^\\\\', 'once'))
    file_name = fullfile(projectFolder, file_name);
end
outputFolder = fileparts(file_name);
temporaryFile = [tempname(outputFolder) '.mat'];
save(temporaryFile, 'result', '-v7.3')
[saved, message] = movefile(temporaryFile, file_name, 'f');
assert(saved, 'Could not save the recovered result: %s', message)

fprintf('Recovered data file saved:\n%s\n', file_name)
