function u_num_floors_sample = hybrid_response_at_time_scale( ...
        hs, fem_num, k_experimental, sample_dt, time_scale_factor)
%HYBRID_RESPONSE_AT_TIME_SCALE Replay ideal HS floor response at a time scale.
% Units: time/sample_dt [s], displacement [m], stiffness [N/m].

hs.time_scale_factor = time_scale_factor;
model_time = hs.time;
real_time = model_time*hs.time_scale_factor;
hs_real_time = (0:ceil(real_time(end)/sample_dt))'*sample_dt;
hs_model_time = hs_real_time/hs.time_scale_factor;
ag_sample = interp1(model_time, hs.ag, hs_model_time, 'linear', 0);

floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_coupled = fem_num.K;
K_coupled(interface_dof, interface_dof) = ...
    K_coupled(interface_dof, interface_dof) + k_experimental;
K_floor_floor = K_coupled(floor_dofs, floor_dofs);
K_floor_interface = K_coupled(floor_dofs, interface_dof);
K_interface_floor = K_coupled(interface_dof, floor_dofs);
K_interface_interface = K_coupled(interface_dof, interface_dof);
K_hybrid_reference = K_floor_floor - K_floor_interface ...
    *(K_interface_interface\K_interface_floor);
interface_from_floors = -(K_interface_interface\K_interface_floor);

numerical_load_sample = hs.ground_force_gain*ag_sample';
u_hybrid_reference_sample = newmarkAverageAcceleration(hs_real_time, ...
    hs.M, hs.C, K_hybrid_reference, numerical_load_sample);
interface_displacement_reference_sample = ...
    (interface_from_floors*u_hybrid_reference_sample')';
measured_force_sample = k_experimental*interface_displacement_reference_sample;

state = [];
u_num_floors_sample = zeros(numel(hs_real_time), hs.n_floor);
for step = 2:numel(hs_real_time)
    [~, state] = step_HS(measured_force_sample(step), 0, sample_dt, ...
        hs, state);
    u_num_floors_sample(step, :) = state(1:hs.n_floor)';
end
end
