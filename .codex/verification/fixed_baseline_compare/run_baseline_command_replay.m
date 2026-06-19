repoFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav';
projectFolder = fullfile(repoFolder, 'main');
outputFolder = fullfile(repoFolder, '.codex', 'verification', 'fixed_baseline_compare');
baselineFile = fullfile(repoFolder, '.codex', 'verification', 'file_log_move_test', 'baseline_pre_move.mat');

cd(projectFolder)
addpath(genpath(fullfile(projectFolder, 'helpers')));
if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

load(baselineFile)
test_signal = 1;
time_history = [t(:) dd(:)];
correction_gain = 1.01;
sat_limit = 60;
tend = 60;

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
file_name = fullfile(outputFolder, ['current_' timestamp '_baseline_command_replay.mat']);

model = 'model_ColumnSetup_00';
load_system(model)
controllerBlocks = find_system(model, 'LookUnderMasks','all', 'FollowLinks','on', ...
    'RegExp','on', 'Name','Controller.*placeholder');
set_param(controllerBlocks{1}, 'Gain', 'correction_gain')
tg = slrealtime;
if strcmp(tg.status, 'running')
    tg.stop
end
slbuild(model);
tg.load(model)
tg.start('AutoImportFileLog', true, 'StopTime', tend);
T = timer('TimerFcn', @(~,~)disp('*** Baseline-command replay target run complete. ***'), 'StartDelay', tend + 5);
start(T); wait(T); delete(T);

Results{1} = logsout.FileLogSignals{1}.Values.Data;
t = logsout.FileLogSignals{1}.Values.Time;
dd = Results{1}(:,1);
dc = Results{1}(:,2);
dm = Results{1}(:,3);
fm = Results{1}(:,4);
am = Results{1}(:,5);
if exist('vc', 'var'), clear vc, end
save(file_name, 'Results', 't', 'dd', 'dc', 'dm', 'fm', 'am', 'fs', 'dt', ...
    'ch', 'command_channel_selector', 'correction_gain', 'test_signal', ...
    'sat_limit', 'time_history', 'tend', 'file_name', 'model')
close_system(model, 0)

baseline = load(baselineFile);
current = load(file_name);
channels = {'dd'; 'dc'; 'vc'; 'dm'; 'fm'; 'am'};
rmsDifference = nan(size(channels));
normalizedChange = nan(size(channels));
baselineRms = nan(size(channels));
currentRms = nan(size(channels));

for k = 1:numel(channels)
    channel = channels{k};
    if isfield(baseline, channel) && isfield(current, channel)
        n = min(numel(baseline.(channel)), numel(current.(channel)));
        b = baseline.(channel)(1:n);
        c = current.(channel)(1:n);
        rmsDifference(k) = sqrt(mean((c - b).^2, 'omitnan'));
        baselineRms(k) = sqrt(mean(b.^2, 'omitnan'));
        currentRms(k) = sqrt(mean(c.^2, 'omitnan'));
        normalizedChange(k) = 100 * rmsDifference(k) / max(baselineRms(k), currentRms(k));
    end
end

[~, currentBase] = fileparts(file_name);
save(fullfile(outputFolder, ['channel_rms_comparison_' currentBase '.mat']), ...
    'baselineFile', 'file_name', 'channels', 'rmsDifference', 'normalizedChange', 'baselineRms', 'currentRms')

csvPath = fullfile(outputFolder, ['channel_rms_comparison_' currentBase '.csv']);
fid = fopen(csvPath, 'w');
fprintf(fid, 'Channel,RMS(current - baseline),Normalized change (%%)\n');
for k = 1:numel(channels)
    fprintf(fid, '%s,%.12g,%.12g\n', channels{k}, rmsDifference(k), normalizedChange(k));
end
fclose(fid);

disp(table(channels, rmsDifference, normalizedChange, ...
    'VariableNames', {'Channel', 'RMS_current_minus_baseline', 'Normalized_change_percent'}))
fprintf('currentArtifactFile: %s\n', file_name);
fprintf('csvPath: %s\n', csvPath);
