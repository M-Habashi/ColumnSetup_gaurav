function [updated_files, skipped_files] = backfill_saved_test_git_provenance()
%BACKFILL_SAVED_TEST_GIT_PROVENANCE Add current Git provenance to test MAT files.

main_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
provenance = get_git_provenance(main_folder, 'backfilled_current');
files = dir(fullfile(main_folder, 'saved_results', 'tests', '**', '*.mat'));
updated_files = strings(0, 1);
skipped_files = strings(0, 1);

for file_id = 1:numel(files)
    file_path = fullfile(files(file_id).folder, files(file_id).name);
    variables = whos('-file', file_path);
    if ~any(strcmp({variables.name}, 'result'))
        skipped_files(end+1, 1) = string(file_path); %#ok<AGROW>
        continue
    end
    data = load(file_path, 'result');
    if ~isfield(data, 'result') || ~isstruct(data.result)
        skipped_files(end+1, 1) = string(file_path); %#ok<AGROW>
        continue
    end
    result = data.result;
    result.git_provenance = provenance;
    save(file_path, 'result', '-append')
    updated_files(end+1, 1) = string(file_path); %#ok<AGROW>
end

fprintf('Git provenance added to %d saved test result(s).\n', ...
    numel(updated_files))
if ~isempty(skipped_files)
    fprintf('Skipped %d file(s) without a result struct.\n', ...
        numel(skipped_files))
end
end
