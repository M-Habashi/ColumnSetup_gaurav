function [K_retained, model] = assembleNumericalSubstructureStiffness( ...
        frame, interface_height)
%ASSEMBLENUMERICALSUBSTRUCTURESTIFFNESS Assemble the hybrid numerical FEM.
%   The experimental lower-left column is removed. The retained interface
%   DOF is horizontal translation only; its rotation is released and its
%   vertical translation is restrained by the numerical roller.
% Units: geometry [m], E [N/m^2], I [m^4], rotational stiffness [N*m/rad],
% output stiffness matrices [N/m].

n_story = frame.n_story;
n_bay = frame.n_bay;
validateattributes(interface_height, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', frame.story_height});

interface_dof = n_story+1;
next_dof = interface_dof;
joint_rotation = zeros(n_bay+1, n_story+1);

% The left base is experimental. Other column bases retain their springs.
for column_id = 2:(n_bay+1)
    if ~isinf(frame.base_rotation_k)
        next_dof = next_dof+1;
        joint_rotation(column_id, 1) = next_dof;
    end
end
for column_id = 1:(n_bay+1)
    for level_id = 1:n_story
        next_dof = next_dof+1;
        joint_rotation(column_id, level_id+1) = next_dof;
    end
end
next_dof = next_dof+1;
interface_rotation_dof = next_dof;

beam_rotation = zeros(n_story, 2*n_bay);
if isinf(frame.beam_connection_k)
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
for column_id = 1:(n_bay+1)
    column_section = frame.section.W8x35;
    if column_id == 1 || column_id == n_bay+1
        column_section = frame.section.W8x28;
    end

    for story_id = 1:n_story
        member_length = frame.story_height;
        lower_translation = 0;
        lower_rotation = joint_rotation(column_id, story_id);
        if story_id > 1
            lower_translation = story_id-1;
        elseif column_id == 1
            member_length = frame.story_height-interface_height;
            lower_translation = interface_dof;
            lower_rotation = interface_rotation_dof;
        end

        k_column = bendingStiffness( ...
            frame.E, column_section.Ix, member_length);
        transform = diag([-1, 1, -1, 1]);
        k_column = transform'*k_column*transform;
        dofs = [lower_translation, lower_rotation, story_id, ...
            joint_rotation(column_id, story_id+1)];
        K_full = assembleElement(K_full, k_column, dofs);
    end
end

k_beam = bendingStiffness( ...
    frame.E, frame.section.W8x24.Ix, frame.bay_width);
k_beam_rotation = k_beam([2, 4], [2, 4]);
for level_id = 1:n_story
    for bay_id = 1:n_bay
        beam_dofs = beam_rotation(level_id, [2*bay_id-1, 2*bay_id]);
        K_full = assembleElement(K_full, k_beam_rotation, beam_dofs);
        if ~isinf(frame.beam_connection_k)
            joint_dofs = joint_rotation([bay_id, bay_id+1], level_id+1);
            for end_id = 1:2
                spring_dofs = [joint_dofs(end_id), beam_dofs(end_id)];
                K_full = assembleElement(K_full, ...
                    frame.beam_connection_k*[1, -1; -1, 1], spring_dofs);
            end
        end
    end
end

if ~isinf(frame.base_rotation_k)
    for column_id = 2:(n_bay+1)
        base_dof = joint_rotation(column_id, 1);
        K_full(base_dof, base_dof) = K_full(base_dof, base_dof) ...
            + frame.base_rotation_k;
    end
end

retained = 1:interface_dof;
internal = (interface_dof+1):next_dof;
K_retained = K_full(retained, retained) ...
    - K_full(retained, internal) ...
    *(K_full(internal, internal)\K_full(internal, retained));
K_retained = (K_retained+K_retained')/2;

assert(all(eig(K_retained) > 0), ...
    'The condensed numerical stiffness must be positive definite.');

model.K_full = K_full;
model.retained_dofs = retained;
model.internal_dofs = internal;
model.floor_dofs = 1:n_story;
model.interface_dof = interface_dof;
model.interface_rotation_dof = interface_rotation_dof;
model.joint_rotation_dofs = joint_rotation;
model.beam_rotation_dofs = beam_rotation;
model.interface_height = interface_height;
model.interface_restraint = 'vertical roller; horizontal translation free';
model.interface_transfers = 'horizontal force only';
end

function k = bendingStiffness(E, I, L)
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
dofs = dofs(active);
K(dofs, dofs) = K(dofs, dofs)+k_element(active, active);
end
