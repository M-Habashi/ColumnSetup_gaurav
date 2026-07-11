function plots = plot_test_result(result, result_file, exp_tf_file)
%PLOT_TEST_RESULT Create the standard saved-result, HS, and OSI plots.
% With no result input, selects a test using load_saved_result_file.
% Units: result fields retain their saved units: t [s], displacements [mm],
% force [N], and acceleration [g].

project_folder = fileparts(mfilename('fullpath'));
addpath(fullfile(project_folder, '..', 'helpers', 'utils'));
addpath(fullfile(project_folder, '..', 'control_and_HS', 'd_HS', 'utils_HS'));

if nargin < 1 || isempty(result)
    [data, result_file, selected_file_name] = load_saved_result_file( ...
        fileparts(project_folder), 'tests', false, '', false);
    if ~isfield(data, 'result') || ~isstruct(data.result)
        printConversionMessage(selected_file_name)
        plots = struct('saved_result', [], 'hs_comparison', [], 'osi_replay', []);
        return
    end
    result = data.result;
elseif nargin < 2
    result_file = '';
end
if isfield(result, 'result') && isstruct(result.result)
    result = result.result;
end
if ~isNewResultStruct(result)
    printConversionMessage(getResultName(result))
    plots = struct('saved_result', [], 'hs_comparison', [], 'osi_replay', []);
    return
end
if nargin < 3 || isempty(exp_tf_file)
    exp_tf_file = fieldOr(result, 'exp_tf_file', '');
end

plots = struct('saved_result', [], 'hs_comparison', [], 'osi_replay', []);
plots.saved_result = visualize_saved_results(result);

try
    recorded_data = result;
    if ~isempty(result_file) && isfile(result_file)
        recorded_data = result_file;
    end
    if isfield(result, 'hs') && isstruct(result.hs) && isfield(result.hs, 'fem')
        plots.hs_comparison = compare_hs_response_to_reference( ...
            result.hs.fem, recorded_data);
    else
        plots.hs_comparison = compare_hs_response_to_reference([], recorded_data);
    end
catch ME
    fprintf('Comparison failed: %s\n', ME.message)
end

has_embedded_exp_tf = isfield(result, 'dependencies') ...
    && isfield(result.dependencies, 'exp_tf');
if has_embedded_exp_tf || isfile(exp_tf_file)
    try
        if has_embedded_exp_tf
            plots.osi_replay = analyze_osi(result, ...
                result.dependencies.exp_tf);
        elseif isempty(result_file)
            plots.osi_replay = analyze_osi(result, exp_tf_file);
        else
            plots.osi_replay = analyze_osi(result_file, exp_tf_file);
        end
    catch ME
        fprintf('OSI analysis failed: %s\n', ME.message)
    end
else
    fprintf('OSI analysis skipped: experimental TF file not found.\n')
end
end

function tf = isNewResultStruct(result)
required_fields = {'file', 't', 'dd', 'dc', 'dm', 'fm', 'am', 'fs', 'dt'};
tf = isstruct(result) && all(isfield(result, required_fields));
end

function printConversionMessage(result_name)
if nargin < 1 || isempty(result_name)
    result_name = 'selected MAT file';
end
fprintf('\n%s uses the old saved-result format.\n', result_name)
fprintf('Convert saved test MAT files from the main folder with:\n')
fprintf('  convert_saved_result_to_struct\n\n')
end

function result_name = getResultName(result)
if isfield(result, 'file')
    [~, name, ext] = fileparts(result.file);
    result_name = [name ext];
elseif isfield(result, 'testname')
    result_name = char(string(result.testname));
else
    result_name = 'selected MAT file';
end
end

function value = fieldOr(s, name, default)
if isfield(s, name)
    value = s.(name);
else
    value = default;
end
end
