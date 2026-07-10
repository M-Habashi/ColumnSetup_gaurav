function provenance = get_git_provenance(repo_folder, capture_mode)
%GET_GIT_PROVENANCE Return the checked-out repository path and commit.

if nargin < 1 || isempty(repo_folder)
    main_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    repo_folder = fileparts(main_folder);
end
if nargin < 2 || isempty(capture_mode)
    capture_mode = 'at_save';
end

command = sprintf('git -C "%s" ', strrep(repo_folder, '"', '\"'));
[status, repo_path] = system([command 'rev-parse --show-toplevel']);
assert(status == 0, 'get_git_provenance:NotRepository', ...
    'Git repository not found at %s.', repo_folder)
[status, commit] = system([command 'rev-parse HEAD']);
assert(status == 0, 'get_git_provenance:CommitUnavailable', ...
    'Unable to determine the checked-out Git commit.')

provenance = struct('repo_path', strtrim(repo_path), ...
    'commit', strtrim(commit), 'capture_mode', char(capture_mode));
end
