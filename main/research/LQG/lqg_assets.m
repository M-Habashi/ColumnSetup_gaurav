function assets = lqg_assets
%LQG_ASSETS Read-only source paths for the isolated LQG study.

lqgFolder = fileparts(mfilename('fullpath'));
mainFolder = fileparts(fileparts(lqgFolder));
savedResults = fullfile(mainFolder, 'saved_results');

assets.system_7k = fullfile(savedResults, 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat');
assets.system_5k = fullfile(savedResults, 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat');
assets.specimen_7k = fullfile(savedResults, 'specimens', 'sp1_7000.mat');
assets.specimen_5k = fullfile(savedResults, 'specimens', 'sp1_5000.mat');
assets.broadband_record = fullfile(savedResults, 'tests', 'important', ...
    '20260617_1731_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat');
assets.results = fullfile(lqgFolder, 'results');
end
