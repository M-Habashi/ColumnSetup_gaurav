clear
clc

projectFolder = fileparts(fileparts(mfilename('fullpath')));
cd(projectFolder)
addpath(genpath(fullfile(projectFolder, 'control_and_HS')))
addpath(genpath(fullfile(projectFolder, 'OSI_tests', 'fable')))

reportFile = fullfile(projectFolder, 'z_temp', 'GDBqFpKb_debug_output.txt');
if exist(reportFile, 'file'), delete(reportFile), end
diary(reportFile)
cleanupDiary = onCleanup(@() diary('off'));

dataFile = fullfile(projectFolder, 'saved_results', 'tests', ...
    'tsting_osi', 'GDBqFpKb.mat');
s = load(dataFile);
result = s.result;

fprintf('FILE: %s\n', dataFile)
fprintf('FIELDS: %s\n', strjoin(fieldnames(result).', ', '))
fprintf('samples=%d, dt=%.12g s, fs=%.12g Hz, duration=%.6f s\n', ...
    numel(result.t), result.dt, result.fs, result.t(end) - result.t(1))

names = {'auth','b_osi','b_st','b_res','b_fast','trip_reason', ...
    'valid','decision','g_armed','u_osi','dd','dc','dm'};
for k = 1:numel(names)
    name = names{k};
    if isfield(result, name) && ~isempty(result.(name))
        x = result.(name)(:);
        fprintf('%-12s n=%d finite=%d min=%g max=%g unique=%d\n', ...
            name, numel(x), nnz(isfinite(x)), min(x(isfinite(x))), ...
            max(x(isfinite(x))), numel(unique(x(isfinite(x)))))
    end
end

fprintf('\nHS CONFIG\n')
disp(result.hs)

fprintf('\nAUTHORITY CHANGE EVENTS\n')
ia = [1; find(abs(diff(result.auth(:))) > 1e-10) + 1];
authEvents = table(result.t(ia), result.auth(ia), result.decision(ia), ...
    result.trip_reason(ia), result.b_osi(ia), result.b_st(ia), ...
    result.b_res(ia), result.b_fast(ia), result.valid(ia), ...
    result.g_armed(ia), 'VariableNames', ...
    {'t','auth','decision','trip','b_osi','b_st','b_res','b_fast','valid','armed'});
disp(authEvents)

fprintf('\nTRIP EVENTS\n')
it = find(result.trip_reason(:) ~= 0 & ...
    [true; diff(result.trip_reason(:)) ~= 0]);
if isempty(it)
    fprintf('none\n')
else
    disp(table(result.t(it), result.trip_reason(it), result.auth(it), ...
        result.b_osi(it), result.b_st(it), result.b_res(it), ...
        result.b_fast(it), 'VariableNames', ...
        {'t','trip','auth','b_osi','b_st','b_res','b_fast'}))
end

fprintf('\nU_OSI / LOGGED-GAIN CHANGE EVENTS\n')
if isfield(result, 'u_osi') && ~isempty(result.u_osi)
    iu = [1; find(abs(diff(result.u_osi(:))) > 1e-10) + 1];
    disp(table(result.t(iu), result.u_osi(iu), result.auth(iu), ...
        result.b_osi(iu), result.b_st(iu), result.valid(iu), ...
        'VariableNames', {'t','u_osi','auth','b_osi','b_st','valid'}))
end

fprintf('\nDECISION WINDOWS\n')
d = result.decision(:);
edges = [1; find(diff(d) ~= 0) + 1; numel(d) + 1];
for k = 1:numel(edges)-1
    i1 = edges(k); i2 = edges(k+1)-1;
    if d(i1) ~= 0 || result.t(i2) >= 40
        fprintf('%8.3f to %8.3f  decision=%g  auth %.4f -> %.4f  b %.4f -> %.4f\n', ...
            result.t(i1), result.t(i2), d(i1), result.auth(i1), ...
            result.auth(i2), result.b_osi(i1), result.b_osi(i2))
    end
end

fprintf('\nSLOW UPDATE SAMPLES 45--90 s\n')
ib = find([true; abs(diff(result.b_osi(:))) > 1e-12] & ...
    result.t(:) >= 45 & result.t(:) <= 90);
slowTable = table(result.t(ib), result.b_osi(ib), result.b_st(ib), ...
    result.b_res(ib), result.b_fast(ib), result.auth(ib), ...
    result.decision(ib), result.valid(ib), result.g_armed(ib), ...
    'VariableNames', {'t','b_osi','b_st','b_res','b_fast','auth', ...
    'decision','valid','armed'});
disp(slowTable)

expData = load(result.hs.exp_tf_file);
fprintf('\nPID / ACTUATOR MODEL\n')
disp(expData.pid_values)
disp(expData.H_dc_dm)
C = pid(expData.pid_values.P, expData.pid_values.I, ...
    expData.pid_values.D, 1/expData.pid_values.derivative_filter_N, ...
    result.dt, 'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L = minreal(C*expData.H_dc_dm);
margins = allmargin(L);
fprintf('PID*H stable=%d, disk-free classical GM=%s, PM=%s\n', ...
    isstable(feedback(L,1)), mat2str(margins.GainMargin,5), ...
    mat2str(margins.PhaseMargin,5))

plData = load(result.hs.phase_lead_file);
fprintf('\nPHASE LEAD\n')
if isfield(plData, 'phase_lead'), disp(plData.phase_lead), end
disp(plData.phase_lead_tf)

fprintf('\nLOGSOUT ELEMENTS\n')
if isfield(result, 'logsout') && ~isempty(result.logsout)
    for k = 1:result.logsout.numElements
        el = result.logsout.get(k);
        fprintf('%2d  %s\n', k, el.Name)
    end
end

diary off
