%% BUILD THE REFERENCE AND NUMERICAL FEM MODELS
%% Units
% Input specimen: m [kg], c [N*s/m], k [N/m]. FEM/SAP geometry [m],
% force [N], mass [kg], K [N/m], C [N*s/m], rotational stiffness [N*m/rad].
% Goal: build specimen-specific reference and numerical FEMs that satisfy:
% 1. The experimental specimen lateral stiffness matches the
%    corresponding numerical part. This is achieved by adjusting the base
%    rotational stiffness.
% 2. The zero-bending-moment position is the control point. This is 
%   achieved by changing the numerical model floor height while keeping 
%   the experimental substructure equal to the actual specimen (40 in).
% 3. The two inner-column base rotational springs are assigned double the
%    calibrated exterior-column stiffness, and the inner columns are W12x40.
% 4. Reference and numerical FEM definitions are saved together as one
%    saved_results/fem/fem_<specimen>_3.mat file. SAP updating is skipped.
%
% CONSTANT MODELING ASSUMPTIONS
% - Three stories and three 3.048 m bays; linear Euler-Bernoulli bending.
% - W8x24 beams, W8x28 exterior columns, W12x40 interior columns.
% - E = 200 GPa; rigid beam-column connections.
% - Each rigid floor diaphragm enforces one common lateral translation but
%   does not tie joint rotations; rotations are assembled then condensed.
% - Floor masses are [20121, 20121, 18426] kg. Axial deformation is omitted.
% - The physical W8x28 column is 1.016 m tall and is represented only by its
%   measured scalar lateral stiffness k.
% - At the hybrid interface, a numerical roller carries the vertical/axial
%   reaction. The experiment transfers horizontal force only: F_exp = k*u_I.
%   No experimental axial force or moment is applied to the numerical FEM.
%
% GEOMETRY AND HYBRID PARTITION (elevation)
%                 u3  o----------o----------o----------o
%                     |          |          |          |
%                 u2  o----------o----------o----------o
%                     |          |          |          |
%                 u1  o----------o----------o----------o
%                     |          |          |          |
%       F_exp <---- uI o  roller |          |          |
%                     :          |          |          |
%                 [ experimental k ]        |          |
%                     |__________|__________|__________|
%                          <----- 3.048 m bays ----->
%   The common story height and base rotational stiffness are calibrated
%   for the selected specimen; the listed geometry/material data stay fixed.

clc;

%% PATHS AND SPECIMEN SELECTION
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
addpath(fullfile(script_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));

if exist('specimen_file_override', 'var') && ~isempty(specimen_file_override)
    [specimen, specimen_file, specimen_name] = load_saved_result_file( ...
        project_root, 'specimens', false, specimen_file_override);
else
    [specimen, specimen_file, specimen_name] = ...
        load_saved_result_file(project_root, 'specimens', false);
end

assert(isfield(specimen, 'k'), ...
    'The selected specimen file must contain lateral stiffness k.');
specimen_si = specimen_params_si(specimen);

%% STEP 1: MATCH THE MEASURED LATERAL STIFFNESS
% The experimental column is an Euler-Bernoulli cantilever with a rotational
% spring at its base. Under a horizontal tip force, its compliance is
%
%   1/k_exp = L^3/(3*E*Ix) + L^2/k_theta.
%
% Solve this expression for the only unknown, k_theta.
column = experimentalColumnDefinition();
k_experimental = specimen_si.stiffness; % [N/m]
[base_rotation_k, ~] = calculateBaseRotationStiffness( ...
    k_experimental, column);         % [N*m/rad]

fprintf('\nReference-model calibration: %s\n', specimen_name);
fprintf('Specimen file: %s\n', specimen_file);
fprintf('Experimental column: %s, height = %.6g m\n', ...
    column.shape, column.height);
fprintf('Measured lateral stiffness: %.6g N/m\n', k_experimental);
fprintf('Required base rotational stiffness: %.12g N*m/rad\n\n', ...
    base_rotation_k);

%% STEP 2: PLACE THE FIRST-MODE INFLECTION POINT AT THE INTERFACE
frame = sapTemplateFrameDefinition();
frame.section.W12x40.Ix = 307*0.0254^4; % [m^4]
frame.section.inner_column = 'W12x40';
base_rotation_k_by_column = base_rotation_k*ones(frame.n_bay+1, 1);
inner_column_ids = 2:frame.n_bay;
base_rotation_k_by_column(inner_column_ids) = 2*base_rotation_k;

fprintf('Inner-column section: %s\n', frame.section.inner_column);
fprintf('Base rotational stiffness by column [N*m/rad]:');
fprintf(' %.12g', base_rotation_k_by_column);
fprintf('\n\n');

floor_mass_kg = [20121; 20121; 18426];
damping_ratio = 0.03;
height_result = findFirstModeInflectionHeight( ...
    frame, base_rotation_k_by_column, floor_mass_kg, column.height);
story_height = height_result.story_height;              % [m]
first_mode_floor_forces = height_result.floor_forces;    % [N]

assert(height_result.normalized_interface_moment < 1e-10, ...
    'The optimized MATLAB interface moment is not sufficiently close to zero.');
fprintf('Optimized common floor height: %.12g m\n', story_height);
fprintf('First-mode frequency: %.9g Hz\n', ...
    height_result.first_mode_frequency_hz);
fprintf('First-mode equivalent floor forces [N]: %.9g, %.9g, %.9g\n', ...
    first_mode_floor_forces);
fprintf('MATLAB interface moment: %.6e N*m\n\n', ...
    height_result.interface_moment);

%% STEP 3: SAVE THE REFERENCE AND NUMERICAL FEM DEFINITIONS
frame.story_height = story_height;
frame.base_rotation_k = base_rotation_k_by_column;
[K_reference, reference_assembly] = assembleCondensedFrameStiffness( ...
    frame.n_story, frame.n_bay, frame.bay_width, frame.story_height, ...
    frame.E, frame.section, frame.beam_connection_k, ...
    frame.base_rotation_k);
[K_numerical, numerical_assembly] = ...
    assembleNumericalSubstructureStiffness(frame, column.height);

M_reference = diag(floor_mass_kg);              % [kg] = [N*s^2/m]
M_numerical = diag([floor_mass_kg; 0]);         % massless interface DOF
[~, specimen_stem] = fileparts(specimen_name);
fem_name = ['fem_' specimen_stem '_3.mat'];
fem_directory = fullfile(project_root, 'saved_results', 'fem');
if ~isfolder(fem_directory), mkdir(fem_directory); end
fem_file = fullfile(fem_directory, fem_name);

fem_ref.kind = 'reference';
fem_ref.specimen_name = specimen_stem;
fem_ref.specimen_file = specimen_file;
fem_ref.frame = frame;
fem_ref.experimental_column = column;
fem_ref.floor_mass_kg = floor_mass_kg;
fem_ref.K = K_reference;
fem_ref.M = M_reference;
fem_ref.units = femUnits();
fem_ref.damping_ratio = damping_ratio;
fem_ref.influence = ones(frame.n_story, 1);
fem_ref.assembly = reference_assembly;
fem_ref.assumptions = struct( ...
    'diaphragm', 'common floor translation; joint rotations free', ...
    'axial_deformation', 'omitted');

fem_num.kind = 'numerical';
fem_num.specimen_name = specimen_stem;
fem_num.specimen_file = specimen_file;
fem_num.frame = frame;
fem_num.experimental_column = column;
fem_num.experimental_k = k_experimental;
fem_num.floor_mass_kg = floor_mass_kg;
fem_num.K = K_numerical;
fem_num.M = M_numerical;
fem_num.units = femUnits();
fem_num.damping_ratio = damping_ratio;
fem_num.influence = [ones(frame.n_story, 1); 0];
fem_num.floor_dofs = numerical_assembly.floor_dofs;
fem_num.interface_dof = numerical_assembly.interface_dof;
fem_num.assembly = numerical_assembly;
fem_num.interface = struct( ...
    'height', column.height, ...
    'restraint', 'roller restrains vertical translation', ...
    'transferred_load', 'horizontal force only', ...
    'axial_force_from_experiment', false, ...
    'moment_from_experiment', false);

fem.kind = 'reference_and_numerical';
fem.schema_version = 1;
fem.specimen_name = specimen_stem;
fem.specimen_file = specimen_file;
fem.story_height_m = story_height;
fem.floor_mass_kg = floor_mass_kg;
fem.level_weight_N = floor_mass_kg*9.80665;
fem.base_rotation_k_by_column = base_rotation_k_by_column;
fem.variant = 'inner_column_base_rotation_double_w12x40';
fem.units = femUnits();
fem.damping_ratio = damping_ratio;
fem.ref = fem_ref;
fem.num = fem_num;

save(fem_file, 'fem');
fprintf('FEM saved: %s\n\n', fem_file);

fprintf('\nMATLAB FEM CALCULATION COMPLETE\n');
fprintf('Exterior base rotational stiffness: %.12g N*m/rad\n', ...
    base_rotation_k);
fprintf('Inner-column base rotational stiffness: %.12g N*m/rad\n', ...
    2*base_rotation_k);
fprintf('Inner-column section: %s\n', frame.section.inner_column);
fprintf('Common floor height: %.12g m\n', story_height);
fprintf('SAP update skipped.\n\n');

function units = femUnits()
% Units: output strings document the SI FEM storage convention.
units = struct('length', 'm', 'force', 'N', 'mass', 'kg', ...
    'stiffness', 'N/m', 'damping', 'N*s/m', ...
    'rotational_stiffness', 'N*m/rad', 'acceleration', 'm/s^2');
end
