%% Clean Simulink Generated Files
% Deletes generated Simulink cache, backup, and build files.

clear; clc

root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end

folderPatterns = {'slprj', '*_slrealtime_rtw', '*_ert_rtw', '*_grt_rtw'};
filePatterns = {'*.slxc', '*.mldatx', '*.asv', '*.autosave', '*.bak', '*.tmp', '~$*'};

deleted = {};
nDeleted = 0;

for i = 1:numel(folderPatterns)
    items = dir(fullfile(root, folderPatterns{i}));
    for j = 1:numel(items)
        if items(j).isdir && ~startsWith(items(j).name, '.')
            p = fullfile(items(j).folder, items(j).name);
            rmdir(p, 's');
            nDeleted = nDeleted + 1;
            deleted{nDeleted, 1} = relpath(p, root); %#ok<SAGROW>
        end
    end
end

for i = 1:numel(filePatterns)
    items = dir(fullfile(root, '**', filePatterns{i}));
    for j = 1:numel(items)
        if ~items(j).isdir
            p = fullfile(items(j).folder, items(j).name);
            delete(p);
            nDeleted = nDeleted + 1;
            deleted{nDeleted, 1} = relpath(p, root); %#ok<SAGROW>
        end
    end
end

fprintf('Cleanup complete.\n')

if isempty(deleted)
    fprintf('No generated Simulink backup/cache files were found.\n')
else
    fprintf('Deleted files and folders:\n')
    printTree(sort(deleted(:)), root)
end

function out = relpath(p, root)
out = strrep(p, [root filesep], '');
end

function printTree(paths, rootName)
fprintf('%s\n', getLastFolder(rootName))

nodes = {};
for i = 1:numel(paths)
    parts = strsplit(paths{i}, filesep);
    for j = 1:numel(parts)
        nodes(end + 1) = {strjoin(parts(1:j), filesep)}; %#ok<AGROW>
    end
end

nodes = unique(nodes);
for i = 1:numel(nodes)
    parts = strsplit(nodes{i}, filesep);
    fprintf('%s|-- %s\n', repmat('  ', 1, numel(parts)), parts{end})
end
end

function name = getLastFolder(p)
[~, name] = fileparts(p);
end
