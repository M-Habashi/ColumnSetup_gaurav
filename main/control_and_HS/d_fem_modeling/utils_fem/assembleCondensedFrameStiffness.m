function [K_floor, model] = assembleCondensedFrameStiffness( ...
        n_story, n_bay, bay_width, story_height, E, section, ...
        beam_connection_k, base_rotation_k)
%ASSEMBLECONDENSEDFRAMESTIFFNESS Assemble and condense a 2-D frame FEM.
%   Floor translations are retained. Column-joint, beam-end, and finite-base
%   rotations are assembled explicitly and then statically condensed.
% Units: length [m], E [N/m^2], I [m^4], rotational springs [N*m/rad],
% output stiffness matrices [N/m].
%   Rotational spring units are N*m/rad. Inf imposes an exact rigid
%   connection without introducing an artificially large stiffness.

validateattributes(n_story, {'numeric'}, {'scalar','integer','positive'});
validateattributes(n_bay, {'numeric'}, {'scalar','integer','positive'});
validateattributes(bay_width, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(story_height, {'numeric'}, {'scalar','real','finite','positive'});
validateattributes(E, {'numeric'}, {'scalar','real','finite','positive'});
validateRotationalStiffness(beam_connection_k, 'beam_connection_k');
validateRotationalStiffness(base_rotation_k, 'base_rotation_k');

required_sections = {'W8x24','W8x28','W8x35'};
for section_id = 1:numel(required_sections)
    name = required_sections{section_id};
    assert(isfield(section, name) && isfield(section.(name), 'Ix'), ...
        'Section %s must define Ix.', name);
end

% The first n_story DOFs are the retained rigid-diaphragm translations.
next_dof = n_story;
joint_rotation = zeros(n_bay+1, n_story+1);
for column_id = 1:(n_bay+1)
    if ~isinf(base_rotation_k)
        next_dof = next_dof+1;
        joint_rotation(column_id, 1) = next_dof;
    end
    for level_id = 1:n_story
        next_dof = next_dof+1;
        joint_rotation(column_id, level_id+1) = next_dof;
    end
end

beam_rotation = zeros(n_story, 2*n_bay);
if isinf(beam_connection_k)
    for level_id = 1:n_story
        for bay_id = 1:n_bay
            beam_rotation(level_id, 2*bay_id-1) = ...
                joint_rotation(bay_id, level_id+1);
            beam_rotation(level_id, 2*bay_id) = ...
                joint_rotation(bay_id+1, level_id+1);
        end
    end
else
    for level_id = 1:n_story
        for beam_end = 1:(2*n_bay)
            next_dof = next_dof+1;
            beam_rotation(level_id, beam_end) = next_dof;
        end
    end
end

K_full = zeros(next_dof);

% Euler-Bernoulli columns. All nodes on a floor share one translation,
% while each beam-column joint retains its own rotation.
for column_id = 1:(n_bay+1)
    column_section = section.W8x35;
    if column_id == 1 || column_id == n_bay+1
        column_section = section.W8x28;
    end
    k_column = eulerBernoulliBendingStiffness( ...
        E, column_section.Ix, story_height);
    % A vertical member's positive local transverse direction is opposite
    % the positive global floor-translation direction.
    transform = diag([-1, 1, -1, 1]);
    k_column = transform'*k_column*transform;

    for story_id = 1:n_story
        lower_translation = 0;
        if story_id > 1
            lower_translation = story_id-1;
        end
        dofs = [lower_translation, joint_rotation(column_id, story_id), ...
            story_id, joint_rotation(column_id, story_id+1)];
        K_full = assembleElement(K_full, k_column, dofs);
    end
end

% Beam bending supplies the rotational coupling between adjacent joints.
k_beam = eulerBernoulliBendingStiffness( ...
    E, section.W8x24.Ix, bay_width);
k_beam_rotation = k_beam([2, 4], [2, 4]);
for level_id = 1:n_story
    for bay_id = 1:n_bay
        beam_dofs = beam_rotation(level_id, [2*bay_id-1, 2*bay_id]);
        K_full = assembleElement(K_full, k_beam_rotation, beam_dofs);
        if ~isinf(beam_connection_k)
            joint_dofs = joint_rotation([bay_id, bay_id+1], level_id+1);
            for end_id = 1:2
                spring_dofs = [joint_dofs(end_id), beam_dofs(end_id)];
                K_full = assembleElement(K_full, ...
                    beam_connection_k*[1, -1; -1, 1], spring_dofs);
            end
        end
    end
end

if ~isinf(base_rotation_k)
    base_dofs = joint_rotation(:, 1);
    for column_id = 1:(n_bay+1)
        K_full(base_dofs(column_id), base_dofs(column_id)) = ...
            K_full(base_dofs(column_id), base_dofs(column_id)) ...
            + base_rotation_k;
    end
end

retained = 1:n_story;
internal = (n_story+1):next_dof;
K_rr = K_full(internal, internal);
assert(rcond(K_rr) > 1e-14, ...
    'The rotational stiffness block is singular or ill-conditioned.');
K_floor = K_full(retained, retained) ...
    - K_full(retained, internal)*(K_rr\K_full(internal, retained));
K_floor = (K_floor+K_floor')/2;

assert(norm(K_floor-K_floor', 'fro') < 1e-10*norm(K_floor, 'fro'), ...
    'The condensed stiffness matrix must be symmetric.');
assert(all(eig(K_floor) > 0), ...
    'The condensed stiffness matrix must be positive definite.');

model.K_full = K_full;
model.joint_rotation_dofs = joint_rotation;
model.beam_rotation_dofs = beam_rotation;
model.retained_dofs = retained;
model.internal_dofs = internal;
model.beam_connection_k = beam_connection_k;
model.base_rotation_k = base_rotation_k;
end

function k = eulerBernoulliBendingStiffness(E, I, L)
% Units: E [N/m^2], I [m^4], L [m]; output uses consistent N-m units.
k = E*I/L^3* ...
    [12,    6*L,   -12,    6*L;
     6*L, 4*L^2,  -6*L, 2*L^2;
     -12,  -6*L,    12,   -6*L;
     6*L, 2*L^2,  -6*L, 4*L^2];
end

function K = assembleElement(K, k_element, dofs)
% Units: K/k_element use consistent N-m units; dofs are unitless indices.
active = dofs > 0;
active_dofs = dofs(active);
K(active_dofs, active_dofs) = K(active_dofs, active_dofs) ...
    + k_element(active, active);
end

function validateRotationalStiffness(value, name)
% Units: value [N*m/rad]; name is unitless text.
assert(isnumeric(value) && isscalar(value) && isreal(value) ...
    && value > 0 && (isfinite(value) || isinf(value)), ...
    '%s must be a positive finite scalar or Inf.', name);
end
