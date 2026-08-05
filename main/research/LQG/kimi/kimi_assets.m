function assets = kimi_assets
%KIMI_ASSETS Paths for the robust/adaptive LQG study (child of lqg_assets).

kimiFolder = fileparts(mfilename('fullpath'));
lqgFolder = fileparts(kimiFolder);
if ~exist(fullfile(lqgFolder, 'lqg_assets.m'), 'file')
    addpath(lqgFolder);
end
parent = lqg_assets;

assets.lqg_folder = lqgFolder;
assets.kimi_folder = kimiFolder;
assets.results = fullfile(kimiFolder, 'results');
assets.models = fullfile(parent.results, 'lqr_state_space_models.mat');
assets.baseline = fullfile(parent.results, 'lqr_baseline_design.mat');
assets.parent = parent;
end
