%% NUMERICAL-EXPERIMENTAL SUBSTRUCTURE CASE COMPARISON
% Compare three numerical-substructure choices with a constant experimental
% scalar spring, F_exp = k*x. This research script uses MATLAB assembly only;
% no SAP model is created, updated, or checked.

clearvars; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
fem_dir = fullfile(project_root, 'control_and_HS', 'c_fem_modeling');
addpath(fullfile(fem_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

%% INPUTS
earthquake_scale = 1.0;
damping_ratio = 0.03;
floor_mass_kg = [20121; 20121; 18426];

specimen_file = fullfile(project_root, 'saved_results', 'specimens', ...
    'sp_1_org.mat');
specimen = load(specimen_file);
specimen_si = specimen_params_si(specimen);
k_experimental = specimen_si.stiffness;

frame = sapTemplateFrameDefinition();
column = experimentalColumnDefinition();
experimental_height = column.height;
[base_rotation_k, rigid_base_k] = calculateBaseRotationStiffness( ...
    k_experimental, column);

%% EARTHQUAKE INPUT
earthquake_file = fullfile(project_root, 'input_signals', ...
    'earthquakes.mat');
earthquake_data = load(earthquake_file, 'el_centro');
record = earthquake_data.el_centro;
time = record(:, 1);
time = time-time(1);
ag = record(:, 2)*earthquake_scale;

%% CASE DEFINITIONS
case_data(1) = buildCase1(frame, floor_mass_kg, experimental_height);
case_data(2) = buildCase2(frame, floor_mass_kg, experimental_height, ...
    base_rotation_k);
case_data(3) = buildCase3(frame, floor_mass_kg, experimental_height, ...
    base_rotation_k);

metric = validation_metrics();
metric_names = {'J4'; 'J5'; 'J6'};
metric_values = zeros(numel(metric_names), numel(case_data));
maximum_error = zeros(1, numel(case_data));

for case_id = 1:numel(case_data)
    response = simulateCase(case_data(case_id), floor_mass_kg, ...
        k_experimental, damping_ratio, time, ag);
    reference = response.reference;
    hybrid = response.hybrid;

    metric_values(:, case_id) = [ ...
        metric.J4(hybrid(:, 1), reference(:, 1)); ...
        metric.J5(hybrid(:, 2), reference(:, 2)); ...
        metric.J6(hybrid(:, 3), reference(:, 3))];
    maximum_error(case_id) = max(abs(hybrid-reference), [], 'all');
end

%% PRINT RESULTS
fprintf('\nNumerical-experimental substructure comparison\n');
fprintf('Earthquake: El Centro 1940, scale %.3f\n', earthquake_scale);
fprintf('Specimen file: %s\n', specimen_file);
fprintf('Experimental substructure: F_exp = k*x, k = %.6g N/m, height = %.6g m (40 in)\n', ...
    k_experimental, experimental_height);
fprintf('Calibrated base rotational stiffness for Cases 2-3: %.12g N*m/rad\n', ...
    base_rotation_k);
fprintf('Rigid-base 40 in cantilever stiffness: %.6g N/m\n', rigid_base_k);
fprintf('SAP workflow: not used in this research script.\n\n');

fprintf('Applicable error indicators:\n');
fprintf('J4: first-floor displacement error std normalized by reference std [%%].\n');
fprintf('J5: second-floor displacement error std normalized by reference std [%%].\n');
fprintf('J6: third-floor displacement error std normalized by reference std [%%].\n');
fprintf(['J1-J3 require measured dm vs replayed numerical control point; ' ...
    'J7 requires measured dm vs full FEM control-point reference; ' ...
    'J8-J9 are not defined in this repo.\n\n']);

fprintf('Case descriptions:\n');
for case_id = 1:numel(case_data)
    c = case_data(case_id);
    fprintf('%s: %s\n', c.name, c.description);
    fprintf('  Reference story height = %.6g m (%.3f ft); reference full DOFs = %d; dynamic floor DOFs = 3.\n', ...
        c.story_height, c.story_height/0.3048, c.reference_full_dof_count);
end
fprintf('\n');

comparison_table = array2table(metric_values, ...
    'RowNames', metric_names, ...
    'VariableNames', {case_data.name});
disp(comparison_table);

error_table = array2table(maximum_error, ...
    'VariableNames', {case_data.name});
fprintf('Maximum absolute floor displacement difference [m]:\n');
disp(error_table);

%% LOCAL FUNCTIONS
function case_item = buildCase1(frame, floor_mass_kg, experimental_height)
story_height = 2*experimental_height;
frame.story_height = story_height;
frame.base_rotation_k = Inf;

K_reference = assembleTranslationOnlyReference(frame, story_height, Inf);
K_numerical = assembleTranslationOnlyHybrid(frame, story_height, ...
    experimental_height, Inf, false);

case_item.name = 'Case1';
case_item.description = ['translation-only fixed-rotation model; ' ...
    'inflection point fixed at mid-column'];
case_item.story_height = story_height;
case_item.K_reference = K_reference;
case_item.K_numerical = K_numerical;
case_item.reference_full_dof_count = frame.n_story;
case_item.floor_dofs = 1:frame.n_story;
case_item.interface_dof = frame.n_story+1;
case_item.floor_mass_kg = floor_mass_kg;
case_item.height_result = [];
end

function case_item = buildCase2(frame, floor_mass_kg, experimental_height, ...
        base_rotation_k)
height_result = findTranslationBaseInflectionHeight(frame, ...
    base_rotation_k, floor_mass_kg, experimental_height);
story_height = height_result.story_height;
frame.story_height = story_height;
frame.base_rotation_k = base_rotation_k;

[K_reference, reference_model] = assembleTranslationOnlyReference( ...
    frame, story_height, base_rotation_k);
[K_numerical, numerical_model] = assembleTranslationOnlyHybrid( ...
    frame, story_height, experimental_height, base_rotation_k, true);

case_item.name = 'Case2';
case_item.description = ['floor translations with calibrated base ' ...
    'rotational springs; released zero-moment interface rotation'];
case_item.story_height = story_height;
case_item.K_reference = K_reference;
case_item.K_numerical = K_numerical;
case_item.reference_full_dof_count = size(reference_model.K_full, 1);
case_item.floor_dofs = 1:frame.n_story;
case_item.interface_dof = numerical_model.interface_dof;
case_item.floor_mass_kg = floor_mass_kg;
case_item.height_result = height_result;
end

function case_item = buildCase3(frame, floor_mass_kg, experimental_height, ...
        base_rotation_k)
height_result = findFirstModeInflectionHeight(frame, base_rotation_k, ...
    floor_mass_kg, experimental_height);
story_height = height_result.story_height;
frame.story_height = story_height;
frame.base_rotation_k = base_rotation_k;

[K_reference, reference_model] = assembleCondensedFrameStiffness( ...
    frame.n_story, frame.n_bay, frame.bay_width, frame.story_height, ...
    frame.E, frame.section, frame.beam_connection_k, ...
    frame.base_rotation_k);
[K_numerical, numerical_model] = assembleNumericalSubstructureStiffness( ...
    frame, experimental_height);

case_item.name = 'Case3';
case_item.description = ['current num-exp style model; frame joint/base ' ...
    'rotations assembled as massless internal DOFs and condensed for ' ...
    'time integration; story height optimized for the first mode'];
case_item.story_height = story_height;
case_item.K_reference = K_reference;
case_item.K_numerical = K_numerical;
case_item.reference_full_dof_count = size(reference_model.K_full, 1);
case_item.floor_dofs = numerical_model.floor_dofs;
case_item.interface_dof = numerical_model.interface_dof;
case_item.floor_mass_kg = floor_mass_kg;
case_item.height_result = height_result;
end

function response = simulateCase(case_item, floor_mass_kg, k_experimental, ...
        damping_ratio, time, ag)
n_story = numel(floor_mass_kg);
M = diag(floor_mass_kg);
K_reference = case_item.K_reference;
C_reference = femDampingMatrix(struct('K', K_reference, 'M', M), ...
    struct('type', 'rayleigh', 'target_ratio', damping_ratio, ...
    'fit_modes', [1 2]));

load_history = -(M*ones(n_story, 1))*ag';
reference = simulateFloorSystem(M, C_reference, K_reference, ...
    load_history, time);

K_coupled = case_item.K_numerical;
interface_dof = case_item.interface_dof;
floor_dofs = case_item.floor_dofs;
K_coupled(interface_dof, interface_dof) = ...
    K_coupled(interface_dof, interface_dof)+k_experimental;
K_hybrid = condense(K_coupled, floor_dofs);
hybrid = simulateFloorSystem(M, C_reference, K_hybrid, ...
    load_history, time);

response.reference = reference;
response.hybrid = hybrid;
end

function displacement = simulateFloorSystem(M, C, K, load_history, time)
n_story = size(M, 1);
frequency_hz = sqrt(eig(K, M))/(2*pi);
integration_dt = min(median(diff(time)), 1/(20*max(frequency_hz)));
integration_time = linspace(0, time(end), ...
    ceil(time(end)/integration_dt)+1)';

zero = zeros(n_story);
identity = eye(n_story);
A = [zero, identity; -M\K, -M\C];
B = [zero; M\identity];
system = ss(A, B, [identity, zero], zero);
input = interp1(time, load_history', integration_time, 'linear');
fine_displacement = lsim(system, input, integration_time);
displacement = interp1(integration_time, fine_displacement, time, ...
    'linear');
end

function [K_floor, model] = assembleTranslationOnlyReference(frame, ...
        story_height, base_rotation_k)
n_story = frame.n_story;
n_bay = frame.n_bay;
next_dof = n_story;
base_rotation = zeros(n_bay+1, 1);
if ~isinf(base_rotation_k)
    for column_id = 1:(n_bay+1)
        next_dof = next_dof+1;
        base_rotation(column_id) = next_dof;
    end
end

K_full = zeros(next_dof);
for column_id = 1:(n_bay+1)
    section = columnSection(frame, column_id);
    for story_id = 1:n_story
        lower_translation = 0;
        if story_id > 1
            lower_translation = story_id-1;
        end
        lower_rotation = 0;
        if story_id == 1 && ~isinf(base_rotation_k)
            lower_rotation = base_rotation(column_id);
        end
        dofs = [lower_translation, lower_rotation, story_id, 0];
        k_column = bendingStiffness(frame.E, section.Ix, story_height);
        K_full = assembleElement(K_full, k_column, dofs);
    end
end

if ~isinf(base_rotation_k)
    for column_id = 1:(n_bay+1)
        dof = base_rotation(column_id);
        K_full(dof, dof) = K_full(dof, dof)+base_rotation_k;
    end
end

K_floor = condense(K_full, 1:n_story);
model.K_full = K_full;
model.base_rotation_dofs = base_rotation;
model.retained_dofs = 1:n_story;
model.internal_dofs = (n_story+1):next_dof;
end

function [K_retained, model] = assembleTranslationOnlyHybrid(frame, ...
        story_height, interface_height, base_rotation_k, ...
        release_interface_rotation)
n_story = frame.n_story;
n_bay = frame.n_bay;
interface_dof = n_story+1;
next_dof = interface_dof;
interface_rotation_dof = 0;
if release_interface_rotation
    next_dof = next_dof+1;
    interface_rotation_dof = next_dof;
end
base_rotation = zeros(n_bay+1, 1);
if ~isinf(base_rotation_k)
    for column_id = 2:(n_bay+1)
        next_dof = next_dof+1;
        base_rotation(column_id) = next_dof;
    end
end

K_full = zeros(next_dof);
for column_id = 1:(n_bay+1)
    section = columnSection(frame, column_id);
    for story_id = 1:n_story
        member_length = story_height;
        lower_translation = 0;
        if story_id > 1
            lower_translation = story_id-1;
        elseif column_id == 1
            member_length = story_height-interface_height;
            lower_translation = interface_dof;
        end

        lower_rotation = 0;
        if story_id == 1 && column_id == 1 && release_interface_rotation
            lower_rotation = interface_rotation_dof;
        end
        if story_id == 1 && column_id > 1 && ~isinf(base_rotation_k)
            lower_rotation = base_rotation(column_id);
        end

        dofs = [lower_translation, lower_rotation, story_id, 0];
        k_column = bendingStiffness(frame.E, section.Ix, member_length);
        K_full = assembleElement(K_full, k_column, dofs);
    end
end

if ~isinf(base_rotation_k)
    for column_id = 2:(n_bay+1)
        dof = base_rotation(column_id);
        K_full(dof, dof) = K_full(dof, dof)+base_rotation_k;
    end
end

retained = 1:interface_dof;
K_retained = condense(K_full, retained);
model.K_full = K_full;
model.base_rotation_dofs = base_rotation;
model.floor_dofs = 1:n_story;
model.interface_dof = interface_dof;
model.interface_rotation_dof = interface_rotation_dof;
model.retained_dofs = retained;
model.internal_dofs = setdiff(1:next_dof, retained);
end

function result = findTranslationBaseInflectionHeight(frame, ...
        base_rotation_k, floor_mass_kg, experimental_height)
minimum_height = 1.01*experimental_height;
maximum_height = 6*experimental_height;
scan_heights = linspace(minimum_height, maximum_height, 161);
scan_moments = zeros(size(scan_heights));
for height_id = 1:numel(scan_heights)
    scan_moments(height_id) = translationBaseInterfaceMoment( ...
        scan_heights(height_id), frame, base_rotation_k, ...
        floor_mass_kg, experimental_height);
end

bracket_ids = find(scan_moments(1:end-1).*scan_moments(2:end) <= 0);
assert(~isempty(bracket_ids), ...
    'No Case 2 zero-moment story height was found.');

options = optimset('Display', 'off', 'TolX', 1e-9);
candidate_heights = zeros(numel(bracket_ids), 1);
for bracket_id = 1:numel(bracket_ids)
    index = bracket_ids(bracket_id);
    bracket = scan_heights(index:index+1);
    candidate_heights(bracket_id) = fzero( ...
        @(height) translationBaseInterfaceMoment(height, frame, ...
            base_rotation_k, floor_mass_kg, experimental_height), ...
        bracket, options);
end
candidate_heights = uniquetol(candidate_heights, 1e-9);
[~, selected_id] = min(abs(candidate_heights-frame.story_height));
story_height = candidate_heights(selected_id);

[moment, floor_forces, frequency_hz, moment_scale] = ...
    translationBaseInterfaceMoment(story_height, frame, base_rotation_k, ...
    floor_mass_kg, experimental_height);
result.story_height = story_height;
result.floor_forces = floor_forces;
result.first_mode_frequency_hz = frequency_hz;
result.interface_moment = moment;
result.normalized_interface_moment = abs(moment)/moment_scale;
result.candidate_heights = candidate_heights;
result.search_bounds = [minimum_height, maximum_height];
end

function [moment, floor_forces, frequency_hz, moment_scale] = ...
        translationBaseInterfaceMoment(story_height, frame, ...
        base_rotation_k, floor_mass_kg, experimental_height)
[K, model] = assembleTranslationOnlyReference(frame, story_height, ...
    base_rotation_k);
M = diag(floor_mass_kg(:));
[mode_shapes, eigenvalues] = eig(K, M, 'vector');
[eigenvalues, order] = sort(real(eigenvalues));
first_mode = real(mode_shapes(:, order(1)));
if first_mode(end) < 0
    first_mode = -first_mode;
end
frequency_hz = sqrt(eigenvalues(1))/(2*pi);

floor_forces = M*first_mode;
floor_forces = 1000*floor_forces/sum(floor_forces);
floor_displacement = K\floor_forces;

full_displacement = zeros(size(model.K_full, 1), 1);
full_displacement(model.retained_dofs) = floor_displacement;
if ~isempty(model.internal_dofs)
    full_displacement(model.internal_dofs) = ...
        -model.K_full(model.internal_dofs, model.internal_dofs) ...
        \(model.K_full(model.internal_dofs, model.retained_dofs) ...
        *floor_displacement);
end

column_dofs = [0, model.base_rotation_dofs(1), 1, 0];
column_displacement = zeros(4, 1);
active = column_dofs > 0;
column_displacement(active) = full_displacement(column_dofs(active));
local_displacement = diag([-1, 1, -1, 1])*column_displacement;

EIx = frame.E*frame.section.W8x28.Ix;
moment = EIx*curvatureOperator(experimental_height, story_height) ...
    *local_displacement;
end_moments = EIx*[curvatureOperator(0, story_height); ...
    curvatureOperator(story_height, story_height)]*local_displacement;
moment_scale = max(max(abs(end_moments)), 1);
end

function K_condensed = condense(K, retained)
internal = setdiff(1:size(K, 1), retained);
if isempty(internal)
    K_condensed = K(retained, retained);
else
    K_condensed = K(retained, retained)-K(retained, internal) ...
        *(K(internal, internal)\K(internal, retained));
end
K_condensed = (K_condensed+K_condensed')/2;
end

function section = columnSection(frame, column_id)
section = frame.section.W8x35;
if column_id == 1 || column_id == frame.n_bay+1
    section = frame.section.W8x28;
end
end

function k = bendingStiffness(E, I, L)
k = E*I/L^3* ...
    [12,    6*L,   -12,    6*L; ...
     6*L, 4*L^2,  -6*L, 2*L^2; ...
     -12,  -6*L,    12,   -6*L; ...
     6*L, 2*L^2,  -6*L, 4*L^2];
transform = diag([-1, 1, -1, 1]);
k = transform'*k*transform;
end

function K = assembleElement(K, k_element, dofs)
active = dofs > 0;
active_dofs = dofs(active);
K(active_dofs, active_dofs) = K(active_dofs, active_dofs) ...
    + k_element(active, active);
end

function operator = curvatureOperator(x, length)
xi = x/length;
operator = [ ...
    (-6+12*xi)/length^2, ...
    (-4+6*xi)/length, ...
    (6-12*xi)/length^2, ...
    (-2+6*xi)/length];
end
