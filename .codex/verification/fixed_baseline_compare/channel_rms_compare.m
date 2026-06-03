repoFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav';
outputFolder = fullfile(repoFolder, '.codex', 'verification', 'fixed_baseline_compare');

baselineFile = fullfile(repoFolder, '.codex', 'verification', 'file_log_move_test', 'baseline_pre_move.mat');
currentFile = fullfile(outputFolder, 'current_20260601_1146_config.mat');

baseline = load(baselineFile);
current = load(currentFile);

channels = {'dd'; 'dc'; 'vc'; 'dm'; 'fm'; 'am'};
rmsDifference = nan(size(channels));
baselineRms = nan(size(channels));
currentRms = nan(size(channels));

for k = 1:numel(channels)
    channel = channels{k};
    n = min(numel(baseline.(channel)), numel(current.(channel)));
    b = baseline.(channel)(1:n);
    c = current.(channel)(1:n);
    rmsDifference(k) = sqrt(mean((c - b).^2, 'omitnan'));
    baselineRms(k) = sqrt(mean(b.^2, 'omitnan'));
    currentRms(k) = sqrt(mean(c.^2, 'omitnan'));
end

save(fullfile(outputFolder, 'channel_rms_comparison.mat'), ...
    'baselineFile', 'currentFile', 'channels', 'rmsDifference', 'baselineRms', 'currentRms')

fid = fopen(fullfile(outputFolder, 'channel_rms_comparison.csv'), 'w');
fprintf(fid, 'channel,rms_current_minus_baseline,baseline_rms,current_rms\n');
for k = 1:numel(channels)
    fprintf(fid, '%s,%.12g,%.12g,%.12g\n', channels{k}, rmsDifference(k), baselineRms(k), currentRms(k));
end
fclose(fid);

disp(table(channels, rmsDifference, baselineRms, currentRms, ...
    'VariableNames', {'Channel', 'RMS_CurrentMinusBaseline', 'Baseline_RMS', 'Current_RMS'}))
