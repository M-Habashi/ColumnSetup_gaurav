function addpaths()
%ADDPATHS Add project folders to the MATLAB path.

project_root = fileparts(mfilename('fullpath'));
project_folders = strsplit(genpath(project_root), pathsep);
project_folders = project_folders(~cellfun('isempty', project_folders));

excluded = {'docs', 'saved_results', 'slprj'};
for i = 1:numel(excluded)
    excluded_root = fullfile(project_root, excluded{i});
    is_excluded = strcmpi(project_folders, excluded_root) | ...
        startsWith(project_folders, [excluded_root filesep], 'IgnoreCase', true);
    project_folders(is_excluded) = [];
end

addpath(strjoin(project_folders, pathsep));
end
