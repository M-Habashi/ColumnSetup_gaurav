function result = findFirstModeInflectionHeight( ...
        frame, base_rotation_k, floor_mass_kg, experimental_height)
%FINDFIRSTMODEINFLECTIONHEIGHT Find a common story height for zero moment.
%   The target is zero bending moment at experimental_height in the
%   first-story left exterior column under first-mode equivalent forces.
% Units: geometry [m], mass [kg], stiffness [N/m or N*m/rad], force [N],
% moment [N*m], frequency [Hz].

validateBaseRotationStiffness(base_rotation_k, frame.n_bay+1);
validateattributes(floor_mass_kg, {'numeric'}, ...
    {'vector', 'numel', frame.n_story, 'real', 'finite', 'positive'});
validateattributes(experimental_height, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

minimum_height = 1.01*experimental_height;
maximum_height = 6*experimental_height;
scan_heights = linspace(minimum_height, maximum_height, 161);
scan_moments = zeros(size(scan_heights));
for height_id = 1:numel(scan_heights)
    scan_moments(height_id) = interfaceMoment( ...
        scan_heights(height_id), frame, base_rotation_k, ...
        floor_mass_kg, experimental_height);
end

bracket_ids = find(scan_moments(1:end-1).*scan_moments(2:end) <= 0);
assert(~isempty(bracket_ids), ...
    ['No zero-moment story height was found between %.6g and %.6g m. ' ...
     'The scanned moment range was [%.6g, %.6g] N*m.'], ...
    minimum_height, maximum_height, min(scan_moments), max(scan_moments));

options = optimset('Display', 'off', 'TolX', 1e-9);
candidate_heights = zeros(numel(bracket_ids), 1);
for bracket_id = 1:numel(bracket_ids)
    index = bracket_ids(bracket_id);
    bracket = scan_heights(index:index+1);
    candidate_heights(bracket_id) = fzero( ...
        @(height) interfaceMoment(height, frame, base_rotation_k, ...
            floor_mass_kg, experimental_height), ...
        bracket, options);
end
candidate_heights = uniquetol(candidate_heights, 1e-9);

% Choose the valid root requiring the smallest change from the template.
[~, selected_id] = min(abs(candidate_heights-frame.story_height));
story_height = candidate_heights(selected_id);
[target_moment, floor_forces, frequency_hz, moment_scale] = ...
    interfaceMoment(story_height, frame, base_rotation_k, ...
        floor_mass_kg, experimental_height);

result.story_height = story_height;
result.floor_forces = floor_forces;
result.first_mode_frequency_hz = frequency_hz;
result.interface_moment = target_moment;
result.normalized_interface_moment = abs(target_moment)/moment_scale;
result.candidate_heights = candidate_heights;
result.search_bounds = [minimum_height, maximum_height];
end

function [moment, floor_forces, frequency_hz, moment_scale] = ...
        interfaceMoment(story_height, frame, base_rotation_k, ...
        floor_mass_kg, experimental_height)
% Units: lengths [m], mass [kg], force [N], moment [N*m], frequency [Hz].
frame_at_height = frame;
frame_at_height.story_height = story_height;
[K, model] = assembleCondensedFrameStiffness( ...
    frame_at_height.n_story, frame_at_height.n_bay, ...
    frame_at_height.bay_width, frame_at_height.story_height, ...
    frame_at_height.E, frame_at_height.section, ...
    frame_at_height.beam_connection_k, base_rotation_k);

M = diag(floor_mass_kg(:));          % [kg] = [N*s^2/m]
[mode_shapes, eigenvalues] = eig(K, M, 'vector');
[eigenvalues, order] = sort(real(eigenvalues));
assert(eigenvalues(1) > 0, 'The first eigenvalue must be positive.');
first_mode = real(mode_shapes(:, order(1)));
if first_mode(end) < 0
    first_mode = -first_mode;
end
frequency_hz = sqrt(eigenvalues(1))/(2*pi);

floor_forces = M*first_mode;
floor_forces = 1000*floor_forces/sum(floor_forces); % total = 1000 N
floor_displacement = K\floor_forces;

full_displacement = zeros(size(model.K_full, 1), 1);
full_displacement(model.retained_dofs) = floor_displacement;
K_internal = model.K_full(model.internal_dofs, model.internal_dofs);
K_internal_retained = model.K_full( ...
    model.internal_dofs, model.retained_dofs);
full_displacement(model.internal_dofs) = ...
    -K_internal\(K_internal_retained*floor_displacement);

column_dofs = [0, model.joint_rotation_dofs(1, 1), ...
    1, model.joint_rotation_dofs(1, 2)];
column_displacement = zeros(4, 1);
active = column_dofs > 0;
column_displacement(active) = full_displacement(column_dofs(active));
local_displacement = diag([-1, 1, -1, 1])*column_displacement;

EIx = frame_at_height.E*frame_at_height.section.W8x28.Ix;
moment = EIx*curvatureOperator( ...
    experimental_height, story_height)*local_displacement;
end_moments = EIx*[ ...
    curvatureOperator(0, story_height); ...
    curvatureOperator(story_height, story_height)]*local_displacement;
moment_scale = max(max(abs(end_moments)), 1);
end

function operator = curvatureOperator(x, length)
% Units: x/length [m]; output has consistent inverse-length units.
xi = x/length;
operator = [ ...
    (-6+12*xi)/length^2, ...
    (-4+6*xi)/length, ...
    (6-12*xi)/length^2, ...
    (-2+6*xi)/length];
end

function validateBaseRotationStiffness(value, n_column)
% Units: value [N*m/rad]; n_column is a count.
assert(isnumeric(value) && isreal(value) && ~isempty(value) ...
    && (isscalar(value) || numel(value) == n_column) ...
    && all(value(:) > 0) ...
    && all(isfinite(value(:)) | isinf(value(:))), ...
    'base_rotation_k must be scalar or contain one positive value per column.');
end
