function [metric_table, comparison] = compare_hs_test_to_reference(varargin)
%COMPARE_HS_TEST_TO_REFERENCE Compatibility wrapper for HS reference checks.

project_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'));

if nargout == 0
    compare_hs_response_to_reference(varargin{:});
elseif nargout == 1
    metric_table = compare_hs_response_to_reference(varargin{:});
else
    [metric_table, comparison] = compare_hs_response_to_reference(varargin{:});
end
end
