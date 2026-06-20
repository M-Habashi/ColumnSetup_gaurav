%% BUILD THE REFERENCE MODEL
% Goal: build a specimen-specific SAP2000 reference model that satisfies:
% 1. The experimental substructure matches the selected specimen file, and
%    the base rotational stiffness matches the experiment's actual stiffness.
% 2. The zero-bending-moment position is the control point: the experimental
%    substructure remains 40 in tall, while the numerical floor height may change.
% 3. A copy of sap/template.sdb is named after the specimen and updated with
%    the calculated base rotational stiffness.

clc;

%% PATHS AND SPECIMEN SELECTION
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
addpath(fullfile(project_root, 'helpers', 'utils'));

[specimen, specimen_file, specimen_name] = ...
    load_saved_result_file(project_root, 'specimens');

assert(isfield(specimen, 'k'), ...
    'The selected specimen file must contain lateral stiffness k.');
validateattributes(specimen.k, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'specimen.k');
if isfield(specimen, 'units') && isfield(specimen.units, 'k')
    assert(strcmpi(strrep(string(specimen.units.k), ' ', ''), 'N/mm'), ...
        'Specimen stiffness must use N/mm; the selected file reports %s.', ...
        string(specimen.units.k));
end

%% STEP 1: MATCH THE MEASURED LATERAL STIFFNESS
% The experimental column is an Euler-Bernoulli cantilever with a rotational
% spring at its base. Under a horizontal tip force, its compliance is
%
%   1/k_exp = L^3/(3*E*Ix) + L^2/k_theta.
%
% Solve this expression for the only unknown, k_theta.
column = experimentalColumnDefinition();
k_experimental = specimen.k;        % [N/mm]
[base_rotation_k, ~] = calculateBaseRotationStiffness( ...
    k_experimental, column);         % [N*mm/rad]

fprintf('\nReference-model calibration: %s\n', specimen_name);
fprintf('Specimen file: %s\n', specimen_file);
fprintf('Experimental column: %s, height = %.3f mm (40 in)\n', ...
    column.shape, column.height_mm);
fprintf('Measured lateral stiffness: %.6g N/mm\n', k_experimental);
fprintf('Required base rotational stiffness: %.12g N*mm/rad\n\n', ...
    base_rotation_k);

%% STEP 2: CREATE AND UPDATE THE SPECIMEN-SPECIFIC SAP MODEL
sap_directory = fullfile(script_dir, 'sap');
sap_template_file = fullfile(sap_directory, 'template.sdb');
sap_update_script = fullfile(script_dir, ...
    'updateSapBaseRotationalSprings.ps1');
assert(isfile(sap_template_file), ...
    'SAP template file not found: %s', sap_template_file);
assert(isfile(sap_update_script), ...
    'SAP update helper not found: %s', sap_update_script);

[~, specimen_stem] = fileparts(specimen_name);
assert(~strcmpi(specimen_stem, 'template'), ...
    'The specimen name cannot be "template".');
sap_reference_file = fullfile(sap_directory, [specimen_stem '.sdb']);

[copy_status, copy_message] = copyfile( ...
    sap_template_file, sap_reference_file, 'f');
assert(copy_status, 'Failed to copy the SAP template: %s', copy_message);

windows_directory = getenv('WINDIR');
if isempty(windows_directory)
    windows_directory = getenv('SystemRoot');
end
if isempty(windows_directory)
    windows_directory = 'C:\Windows';
end
powershell_executable = fullfile(windows_directory, ...
    'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
assert(isfile(powershell_executable), ...
    'Windows PowerShell was not found: %s', powershell_executable);

command = sprintf( ...
    ['"%s" -NoProfile -ExecutionPolicy Bypass -File "%s" ' ...
     '-ModelPath "%s" -BaseRotationKText "%.17g"'], ...
    powershell_executable, sap_update_script, sap_reference_file, ...
    base_rotation_k);
[sap_update_status, sap_update_output] = system(command);
assert(sap_update_status == 0, ...
    'SAP base-spring update failed:\n%s', sap_update_output);

fprintf('%s\n', strtrim(sap_update_output));
fprintf('SAP reference model: %s\n\n', sap_reference_file);
