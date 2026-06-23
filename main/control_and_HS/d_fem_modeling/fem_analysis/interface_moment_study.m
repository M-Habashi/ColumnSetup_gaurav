%% INTERFACE MOMENT STUDY
% Compare the reference frame with two hybrid partitions:
% 1. the implemented horizontal-force-only interface (released rotation),
% 2. a translational-and-rotational interface (exact frame partition).

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
fem_dir = fileparts(script_dir);
project_root = fileparts(fileparts(fem_dir));
addpath(fullfile(fem_dir, 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

damping_ratio = 0.02;
[fem, ~, ~] = loadFemDefinition(project_root, false);
fem_num = fem.num;
fem_ref = fem.ref;

n = fem_num.frame.n_story;
floor_dofs = fem_num.floor_dofs;
interface_dofs = [fem_num.interface_dof, ...
    fem_num.assembly.interface_rotation_dof];
M = fem_ref.M;
K_reference = fem_ref.K;

% Existing horizontal-force-only hybrid stiffness.
K_coupled = fem_num.K;
K_coupled(fem_num.interface_dof, fem_num.interface_dof) = ...
    K_coupled(fem_num.interface_dof, fem_num.interface_dof) ...
    + fem_num.experimental_k;
K_released = condense(K_coupled, floor_dofs);

% Full stiffness of the experimental lower column at [u_I, theta_I].
column = fem_num.experimental_column;
L = column.height;
EI = fem_num.frame.E*fem_num.frame.section.W8x28.Ix;
k_element = EI/L^3*[12, 6*L, -12, 6*L; ...
    6*L, 4*L^2, -6*L, 2*L^2; ...
    -12, -6*L, 12, -6*L; ...
    6*L, 2*L^2, -6*L, 4*L^2];
transform = diag([-1, 1, -1, 1]);
k_element = transform'*k_element*transform;
k_active = k_element([2, 3, 4], [2, 3, 4]);
k_active(1, 1) = k_active(1, 1)+fem_num.frame.base_rotation_k;
K_tip = k_active(2:3, 2:3) ...
    - k_active(2:3, 1)*(k_active(1, 1)\k_active(1, 2:3));

K_full_rotation = fem_num.assembly.K_full;
K_full_rotation(interface_dofs, interface_dofs) = ...
    K_full_rotation(interface_dofs, interface_dofs)+K_tip;
K_rotation = condense(K_full_rotation, floor_dofs);

%% MODAL COMPARISON
[phi_reference, frequency_reference] = modes(K_reference, M);
[phi_released, frequency_released] = modes(K_released, M);
[phi_rotation, frequency_rotation] = modes(K_rotation, M);

modal_mac_released = diag(mac(phi_reference, phi_released, M));
modal_mac_rotation = diag(mac(phi_reference, phi_rotation, M));

internal_dofs = setdiff(1:size(K_full_rotation, 1), floor_dofs);
T_internal = -(K_full_rotation(internal_dofs, internal_dofs) ...
    \K_full_rotation(internal_dofs, floor_dofs));
[~, interface_positions] = ismember(interface_dofs, internal_dofs);
T_interface = T_internal(interface_positions, :);
moment_from_floors = K_tip(2, :)*T_interface;

% Scale each mode to unit roof displacement. The moment ratio uses the
% peak end moment of the first-story left column as its reference scale.
interface_moment = zeros(n, 1);
interface_moment_ratio = zeros(n, 1);
for mode_id = 1:n
    shape = phi_reference(:, mode_id)/phi_reference(end, mode_id);
    q_interface = T_interface*shape;
    interface_moment(mode_id) = moment_from_floors*shape;
    lower_end_force = K_tip*q_interface;
    base_moment = lower_end_force(2)-lower_end_force(1)*L;
    interface_moment_ratio(mode_id) = 100*abs(interface_moment(mode_id)) ...
        /max(abs([lower_end_force(2), base_moment]));
end

mode = (1:n)';
modal_results = table(mode, frequency_reference, frequency_released, ...
    100*(frequency_released./frequency_reference-1), ...
    frequency_rotation, modal_mac_released, modal_mac_rotation, ...
    interface_moment, interface_moment_ratio, ...
    'VariableNames', {'Mode', 'ReferenceFrequencyHz', ...
    'ReleasedFrequencyHz', 'ReleasedFrequencyChangePercent', ...
    'RotationalFrequencyHz', 'ReleasedMAC', 'RotationalMAC', ...
    'InterfaceMomentNmPerMRoof', 'InterfaceMomentRatioPercent'});

%% RECORD-LEVEL COMPARISON
record_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
record_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};
earthquake_file = fullfile(project_root, 'input_signals', 'earthquakes.mat');
metric = validation_metrics();
J_released = zeros(numel(record_fields), 4);
J_rotation = zeros(numel(record_fields), 4);
moment_rms = zeros(numel(record_fields), 1);
moment_peak = zeros(numel(record_fields), 1);

C = M*phi_reference*diag(2*damping_ratio*2*pi*frequency_reference) ...
    *phi_reference'*M;
systems = cell(3, 1);
stiffness = {K_reference, K_released, K_rotation};
for system_id = 1:3
    A = [zeros(n), eye(n); -M\stiffness{system_id}, -M\C];
    systems{system_id} = ss(A, [zeros(n); eye(n)], ...
        [eye(n), zeros(n)], zeros(n));
end

for record_id = 1:numel(record_fields)
    data = load(earthquake_file, record_fields{record_id});
    record = data.(record_fields{record_id});
    time = record(:, 1)-record(1, 1);
    load_history = -(M*fem_ref.influence)*record(:, 2)';
    integration_dt = min(median(diff(time)), ...
        1/(20*max(frequency_released)));
    integration_time = linspace(0, time(end), ...
        ceil(time(end)/integration_dt)+1)';
    input = interp1(time, load_history', integration_time, 'linear');
    response = cell(3, 1);
    for system_id = 1:3
        fine_response = lsim(systems{system_id}, input, integration_time);
        response{system_id} = interp1(integration_time, fine_response, ...
            time, 'linear');
    end

    reference = response{1};
    J_released(record_id, :) = response_metrics( ...
        metric, response{2}, reference);
    J_rotation(record_id, :) = response_metrics( ...
        metric, response{3}, reference);
    moment_history = (moment_from_floors*reference')';
    moment_rms(record_id) = rms(moment_history);
    moment_peak(record_id) = max(abs(moment_history));
end

record_results = table(record_names', moment_rms, moment_peak, ...
    J_released(:, 1), J_released(:, 2), J_released(:, 3), ...
    J_released(:, 4), J_rotation(:, 1), J_rotation(:, 2), ...
    J_rotation(:, 3), J_rotation(:, 4), ...
    'VariableNames', {'Record', 'InterfaceMomentRmsNm', ...
    'InterfaceMomentPeakNm', 'ReleasedJ4Percent', 'ReleasedJ5Percent', ...
    'ReleasedJ6Percent', 'ReleasedJ7Percent', 'RotationalJ4Percent', ...
    'RotationalJ5Percent', 'RotationalJ6Percent', ...
    'RotationalJ7Percent'});

fprintf('\nModal comparison\n');
disp(modal_results);
fprintf('Maximum |K_rotation-K_reference| / |K_reference| = %.3e\n', ...
    norm(K_rotation-K_reference, 'fro')/norm(K_reference, 'fro'));
fprintf('\nRecord comparison\n');
disp(record_results);

verification_dir = fullfile(fileparts(project_root), '.codex', ...
    'verification', 'higher_mode_interface_moment');
if ~isfolder(verification_dir), mkdir(verification_dir); end
save(fullfile(verification_dir, 'interface_moment_study.mat'), ...
    'modal_results', 'record_results', 'K_reference', 'K_released', ...
    'K_rotation', 'K_tip');
writetable(modal_results, fullfile(verification_dir, 'modal_results.csv'));
writetable(record_results, fullfile(verification_dir, 'record_results.csv'));

function K_condensed = condense(K, retained)
internal = setdiff(1:size(K, 1), retained);
K_condensed = K(retained, retained)-K(retained, internal) ...
    *(K(internal, internal)\K(internal, retained));
K_condensed = (K_condensed+K_condensed')/2;
end

function [shape, frequency] = modes(K, M)
[shape, eigenvalue] = eig(K, M, 'vector');
[frequency, order] = sort(sqrt(real(eigenvalue))/(2*pi));
shape = real(shape(:, order));
for mode_id = 1:size(shape, 2)
    shape(:, mode_id) = shape(:, mode_id) ...
        /sqrt(shape(:, mode_id)'*M*shape(:, mode_id));
end
end

function value = mac(a, b, M)
value = abs(a'*M*b).^2./((diag(a'*M*a))*(diag(b'*M*b))');
end

function value = response_metrics(metric, response, reference)
value = [metric.J4(response(:, 1), reference(:, 1)), ...
    metric.J5(response(:, 1), reference(:, 1)), ...
    metric.J6(response(:, 2), reference(:, 2)), ...
    metric.J7(response(:, 3), reference(:, 3))];
end
