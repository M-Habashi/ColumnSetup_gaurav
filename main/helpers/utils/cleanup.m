%% Clean Generated Files
% Deletes generated Simulink files and SAP analysis/output files. SAP model
% databases (*.sdb) and text backups (*.$2k) are preserved.
% Units: file paths, names, counters, and all script outputs are unitless.

clear; clc

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if isempty(root), root = pwd; end

folderNames = {'slprj'};
folderPatterns = {'*_slrealtime_rtw', '*_ert_rtw', '*_grt_rtw'};
filePatterns = {'*.slxc', '*.mldatx', '*.asv', '*.autosave', '*.bak', '*.tmp', '~$*'};

deleted = {};
nDeleted = 0;
folders = dir(fullfile(root, '**', '*'));
folders = folders([folders.isdir] & ~startsWith({folders.name}, '.'));

for i = 1:numel(folderNames)
    items = folders(strcmp({folders.name}, folderNames{i}));
    for j = 1:numel(items)
        p = fullfile(items(j).folder, items(j).name);
        rmdir(p, 's');
        nDeleted = nDeleted + 1;
        deleted{nDeleted, 1} = relpath(p, root); %#ok<SAGROW>
    end
end

for i = 1:numel(folderPatterns)
    items = folders(~cellfun('isempty', regexp({folders.name}, ['^' regexptranslate('wildcard', folderPatterns{i}) '$'], 'once')));
    for j = 1:numel(items)
        p = fullfile(items(j).folder, items(j).name);
        rmdir(p, 's');
        nDeleted = nDeleted + 1;
        deleted{nDeleted, 1} = relpath(p, root); %#ok<SAGROW>
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

%% SAP generated analysis files
sapFolder = fullfile(root, 'control_and_HS', 'c_fem_modeling', 'sap');
if isfolder(sapFolder)
    sapItems = dir(sapFolder);
    sapItems = sapItems(~[sapItems.isdir]);
    sapNames = lower(string({sapItems.name}));
    keepSapFile = endsWith(sapNames, '.sdb') | ...
        endsWith(sapNames, '.$2k');

    for i = find(~keepSapFile)
        p = fullfile(sapItems(i).folder, sapItems(i).name);
        delete(p);
        nDeleted = nDeleted + 1;
        deleted{nDeleted, 1} = relpath(p, root); %#ok<SAGROW>
    end
end

fprintf('Cleanup complete.\n')

if isempty(deleted)
    fprintf('No generated files were found.\n')
else
    fprintf('Deleted files and folders:\n')
    printTree(sort(deleted(:)), root)
end

function out = relpath(p, root)
% Units: input and output paths are unitless.
out = strrep(p, [root filesep], '');
end

function printTree(paths, rootName)
% Units: paths, labels, and printed tree output are unitless.
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
% Units: input path and output name are unitless.
[~, name] = fileparts(p);
end
