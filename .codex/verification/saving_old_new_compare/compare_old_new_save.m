projectFolder = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\main';
outDir = 'C:\Users\BOWN1111PC1\Documents\Mohamed\ColumnSetup_gaurav\.codex\verification\saving_old_new_compare';
cd(projectFolder)

old_file = fullfile(outDir, 'old_save.mat');
new_file = fullfile(outDir, 'new_save.mat');
model = 'model_ColumnSetup_00';

old_logsout = logsout;
Results{1} = old_logsout.FileLogSignals{1}.Values.Data;
t = old_logsout.FileLogSignals{1}.Values.Time;
dd = Results{1}(:,1);
dc = Results{1}(:,2);
dm = Results{1}(:,3);
fm = Results{1}(:,4);
am = Results{1}(:,5);
logsout = old_logsout;
file_name = old_file;
save(file_name)

sig = logsout.FileLogSignals{1}.Values;
Results{1} = sig.Data;
t = sig.Time;
dd = Results{1}(:,1);
dc = Results{1}(:,2);
dm = Results{1}(:,3);
fm = Results{1}(:,4);
am = Results{1}(:,5);
file_name = new_file;
save(file_name, 't', 'dd', 'dc', 'dm', 'fm', 'am', 'fs', 'dt', ...
    'Results', 'logsout', 'testname', 'model', 'file_name', '-v7.3')

old = load(old_file, 't', 'dd', 'dc', 'dm', 'fm', 'am');
new = load(new_file, 't', 'dd', 'dc', 'dm', 'fm', 'am');
channels = {'t', 'dd', 'dc', 'dm', 'fm', 'am'};

fprintf('\nOld/new save comparison:\n')
all_match = true;
for k = 1:numel(channels)
    ch = channels{k};
    diff_rms = sqrt(mean((old.(ch) - new.(ch)).^2, 'omitnan'));
    diff_max = max(abs(old.(ch) - new.(ch)));
    exact_match = isequaln(old.(ch), new.(ch));
    all_match = all_match && exact_match;
    fprintf('%s: exact=%d, RMS=%.17g, max=%.17g\n', ch, exact_match, diff_rms, diff_max)
end
fprintf('all exact match: %d\n', all_match)
fprintf('old file: %s\n', old_file)
fprintf('new file: %s\n', new_file)
