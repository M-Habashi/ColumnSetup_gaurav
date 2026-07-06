%RUN_FABLE_SPEEDGOAT_SMOKE_TEST Build and run the OSI model on Speedgoat.
%
% Optional caller variables:
%   fableSmokeStopTime       target run duration in seconds, default 60
%   fableSmokeTag            filename tag, default 'smoke'
%   fableSmokeEnableInitial  runtime enable flag, default 1
%
% The actuator can remain disconnected. This smoke test only checks that the
% real-time application builds, loads, runs for the requested duration, logs
% the expected columns, and imports the target file log.

if ~exist('fableSmokeStopTime', 'var') || isempty(fableSmokeStopTime)
    fableSmokeStopTime = 60;
end
if ~exist('fableSmokeTag', 'var') || isempty(fableSmokeTag)
    fableSmokeTag = 'smoke';
end
if ~exist('fableSmokeEnableInitial', 'var') || isempty(fableSmokeEnableInitial)
    fableSmokeEnableInitial = 1;
end

clearvars -except fableSmokeStopTime fableSmokeTag ...
    fableSmokeEnableInitial

projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\main';
repoFolder = fileparts(projectFolder);
verificationFolder = fullfile(repoFolder, '.codex', 'verification', ...
    'fable_speedgoat');
if ~exist(verificationFolder, 'dir')
    mkdir(verificationFolder)
end

cd(projectFolder)
addpaths();
addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

test_type = ['fable_speedgoat_' char(fableSmokeTag)];
testname = test_type;
runStartTime = datetime('now');
timestampValue = runStartTime;
timestampValue.Format = 'yyyyMMdd_HHmmss';
timestamp = char(timestampValue);

hs = struct( ...
    'fem_file', '', ...
    'exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'phase_lead_file', fullfile(projectFolder, 'saved_results', ...
    'phase_lead', 'pl_7000_ncf4.mat'), ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.06, ...
    'time_scale_factor', 1.0, ...
    'force_sign', 1.0, ...
    'osi_gain_initial', 1.0, ...
    'osi_gain_min', 0.08, ...
    'target_outer_ncf', 0.3, ...
    'fable_gate_override', struct(), ...
    'osi_branch_split_hz', [], ...
    'osi_st_branch_hz', [2 30], ...
    'osi_residual_branch_hz', [40 80]);

fs = 2048;
dt = 1/fs;
zero_alpha = dt/0.5;
t_ending = 5;

[phase_lead_data, phase_lead_file, phase_lead_name] = ...
    load_saved_result_file(projectFolder, 'phase_lead', false, ...
    hs.phase_lead_file);
phase_lead_tf = phase_lead_data.phase_lead_tf;
phase_lead_tf_discrete = c2d(phase_lead_tf, dt, 'tustin');
[phase_lead_num, phase_lead_den] = tfdata(phase_lead_tf_discrete, 'v');
phase_lead_num = phase_lead_num(:).';
phase_lead_den = phase_lead_den(:).';

v2d_gain = 7.62;
v2d_const = 0;
v2f_gain = 4.448*1000;
v2f_const = 0;
v2a_gain = -1000/510;
v2a_const = 0;
correction_gain = 1.013;

ch.am = 2;
ch.dm = 3;
ch.fm = 4;
ch.dd = 5;
command_channel_selector = double((1:7)' == ch.dd);
sat_limit = 70;

saveFolder = fullfile(projectFolder, 'saved_results', 'tests', ...
    char(datetime(runStartTime, 'Format', 'yyyyMMdd')));
file_name = fullfile(saveFolder, [timestamp '_' testname '.mat']);
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder)
end

tend = inf;
[hs.fem, hs.fem_file, hs.fem_name] = loadFemDefinition( ...
    projectFolder, false, hs.fem_file);
fem_num = hs.fem.num;
fem_ref = hs.fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.K_if = K_if;
hs.K_ii = K_ii;
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, hs.fem);
hs.damping_ratio = hs.damping.target_ratio;
earthquakes = load(fullfile(projectFolder, 'input_signals', ...
    'earthquakes.mat'), hs.earthquake_type);
earthquake = earthquakes.(hs.earthquake_type);
hs.time = earthquake(:, 1) - earthquake(1, 1);
hs.ag = hs.intensity_factor*earthquake(:, 2);

hs_M = hs.M;
hs_C = hs.C;
hs_K = hs.K;
hs_K_if = hs.K_if;
hs_K_ii = hs.K_ii;
hs_force_to_floor = hs.force_to_floor;
hs_interface_from_floor = hs.interface_from_floor;
hs_interface_from_force = hs.interface_from_force;
hs_ground_force_gain = hs.ground_force_gain;
hs_time = hs.time;
hs_ag = hs.ag;
hs_time_scale_factor_codegen = hs.time_scale_factor;
hs_force_sign_codegen = hs.force_sign;

fable_setup = prepare_fable_runtime(projectFolder, dt, hs);
exp_tf_file = fable_setup.exp_tf_file;
exp_tf_name = fable_setup.exp_tf_name;

run(fullfile(projectFolder, 'input_signals', 'sample_time_history.m'))
tend_time_history = time_history(end, 1);

amp_2_percentile = 0.4;
exceed_percentile = 0.5;
f1 = 5;
f_init = 0.001;
f_final = 20;
tend_chirp = 30;

model = 'model_ColumnSetup_00';
clear logsout
delete(timerfindall);
load_system(model)
osi_gain_enable_parameter = Simulink.Parameter(fableSmokeEnableInitial);
osi_gain_enable_parameter.CoderInfo.StorageClass = 'ExportedGlobal';
assignin(get_param(model, 'ModelWorkspace'), ...
    'osi_gain_enable_initial', osi_gain_enable_parameter);

fprintf('FABLE Speedgoat smoke: model=%s, enable=%g, stop=%.3f s\n', ...
    model, fableSmokeEnableInitial, fableSmokeStopTime)
fprintf('  phase_lead: %s\n', phase_lead_file)
fprintf('  exp_tf: %s\n', exp_tf_file)
fprintf('  fable init/min/target: %.6g / %.6g / %.6g\n', ...
    fable_setup.gain_initial, fable_setup.gain_min, ...
    fable_setup.target_outer_ncf)

tg = connect_speedgoat_target;
fileLogRunCountBefore = height(list(tg.FileLog));

slbuild(model);
try
    tg.load(model)
catch loadErr
    fprintf('Initial tg.load failed: %s\nRetrying after reconnect...\n', ...
        loadErr.message)
    pause(2)
    tg = slrealtime;
    if ~isConnected(tg)
        connect(tg)
    end
    tg.load(model)
end

runClock = tic;
tg.start('AutoImportFileLog', true, 'StopTime', fableSmokeStopTime);
pause(fableSmokeStopTime + 5)
try
    if strcmpi(tg.status, 'running')
        tg.stop
        pause(2)
    end
catch statusErr
    fprintf('Target status check skipped: %s\n', statusErr.message)
end
wallRunSeconds = toc(runClock);

if ~exist('logsout', 'var')
    fileLogRuns = list(tg.FileLog);
    assert(height(fileLogRuns) > fileLogRunCountBefore, ...
        'No new Speedgoat file-log run was found.')
    tg.FileLog.import(fileLogRuns(end, :));
    logsout = evalin('base', 'logsout');
end

sig = logsout.FileLogSignals{1}.Values;
Results{1} = sig.Data;
t = sig.Time;

duration_s = t(end) - t(1);
sample_count = numel(t);
column_count = size(Results{1}, 2);
assert(duration_s >= fableSmokeStopTime - 1/fs, ...
    'Target log duration %.6g s is shorter than requested %.6g s.', ...
    duration_s, fableSmokeStopTime)

auth_min = NaN;
auth_max = NaN;
if column_count >= 18
    auth = Results{1}(:, 11);
    auth_min = min(auth, [], 'omitnan');
    auth_max = max(auth, [], 'omitnan');
end

summary = struct( ...
    'tag', char(fableSmokeTag), ...
    'model', model, ...
    'enable_initial', fableSmokeEnableInitial, ...
    'requested_stop_time_s', fableSmokeStopTime, ...
    'logged_duration_s', duration_s, ...
    'wall_run_seconds', wallRunSeconds, ...
    'sample_count', sample_count, ...
    'column_count', column_count, ...
    'fs', fs, ...
    'dt', dt, ...
    'auth_min', auth_min, ...
    'auth_max', auth_max, ...
    'created_at', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

verificationFile = fullfile(verificationFolder, ...
    [timestamp '_' char(fableSmokeTag) '.mat']);
save(verificationFile, 'summary', 'Results', 't', 'logsout', 'hs', ...
    'phase_lead_file', 'phase_lead_name', 'exp_tf_file', 'exp_tf_name', ...
    'fable_setup', '-v7.3')

fprintf('FABLE_SPEEDGOAT_SMOKE_RESULT %s\n', verificationFile)
fprintf(['FABLE_SPEEDGOAT_SMOKE_SUMMARY duration=%.6f sample_count=%d ' ...
    'columns=%d auth_min=%.6g auth_max=%.6g wall=%.3f\n'], ...
    summary.logged_duration_s, summary.sample_count, ...
    summary.column_count, summary.auth_min, summary.auth_max, ...
    summary.wall_run_seconds)
