function results = run_osi_auth_factor_tests_from_osi_tests(caseNames)
%RUN_OSI_AUTH_FACTOR_TESTS_FROM_OSI_TESTS Compatibility wrapper.
% The canonical OSI test runner is main/OSI_tests/run_current_osi_auth_factor_cases.m.

if nargin < 1 || isempty(caseNames)
    caseNames = 'all';
end

scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(fileparts(scriptFolder)));
addpath(fullfile(projectFolder, 'OSI_tests'))

results = run_current_osi_auth_factor_cases(caseNames);
end
