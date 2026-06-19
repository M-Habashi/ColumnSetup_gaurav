%% THREE-STORY FRAME RESPONSE TO ALL EARTHQUAKE RECORDS
% Runs the reference model for every available earthquake and overlays the
% ground accelerations and relative floor displacements.

clear;
clc;
close all;

%% INPUTS
earthquake_scale = 1.0;
damping_ratio = 0.02;

validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'earthquake_scale');
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1}, mfilename, 'damping_ratio');

%% MODEL DEFINITION
g0 = 9806.65;                       % gravitational acceleration [mm/s^2]
ft_to_mm = 304.8;                   % [mm/ft]
n_story = 3;
story_height = 6.67*ft_to_mm;       % [mm]

E = 200000;                         % [N/mm^2]
nu = 0.30;
G = E/(2*(1+nu));                   % [N/mm^2]

W8x28 = struct('d', 205, 'tw', 7.24, 'Ix', 40.8e6);
W8x35 = struct('d', 206, 'tw', 7.87, 'Ix', 52.9e6);
W8x28.Av = W8x28.d*W8x28.tw;
W8x35.Av = W8x35.d*W8x35.tw;

k_ext = columnLateralStiffness(E, G, W8x28.Ix, W8x28.Av, story_height);
k_int = columnLateralStiffness(E, G, W8x35.Ix, W8x35.Av, story_height);
k_story = 2*k_ext + 2*k_int;        % [N/mm]

K = k_story*[2, -1,  0;
            -1,  2, -1;
             0, -1,  1];           % [N/mm]

floor_mass_kg = [20121; 20121; 18426];
M = diag(floor_mass_kg)/1000;       % [N*s^2/mm]
influence = ones(n_story, 1);

[modes, omega2] = eig(K, M, 'vector');
[omega, mode_order] = sort(sqrt(omega2));
modes = modes(:, mode_order);
for mode_id = 1:n_story
    modes(:, mode_id) = modes(:, mode_id)/ ...
        sqrt(modes(:, mode_id)'*M*modes(:, mode_id));
end
frequency_hz = omega/(2*pi);
C = M*modes*diag(2*damping_ratio*omega)*modes'*M;

%% LOAD AND RUN ALL EARTHQUAKES
record_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
record_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};
n_record = numel(record_fields);

script_dir = fileparts(mfilename('fullpath'));
earthquake_file = fullfile(script_dir, '..', 'input_signals', 'earthquakes.mat');
assert(isfile(earthquake_file), 'Earthquake file not found: %s', earthquake_file);
earthquake_data = load(earthquake_file, record_fields{:});

responses = cell(n_record, 1);
for record_id = 1:n_record
    assert(isfield(earthquake_data, record_fields{record_id}), ...
        'Record "%s" is missing from earthquakes.mat.', record_fields{record_id});
    record = earthquake_data.(record_fields{record_id});
    assert(size(record, 2) == 2 && all(isfinite(record), 'all'), ...
        'Record %s must contain finite [time, acceleration] data.', ...
        record_names{record_id});

    time = record(:, 1);                                  % [s]
    ag = record(:, 2)*1000*earthquake_scale;              % [mm/s^2]
    assert(all(diff(time) > 0), '%s time must be strictly increasing.', ...
        record_names{record_id});

    effective_force = -(M*influence)*ag';                 % [N]
    u_relative = newmarkAverageAcceleration(time, M, C, K, effective_force);
    assert(all(isfinite(u_relative), 'all'), ...
        '%s produced a nonfinite response.', record_names{record_id});

    responses{record_id} = struct('time', time, 'ag', ag, ...
        'u_relative', u_relative);
    peak_floor_displacement = max(abs(u_relative), [], 1);
    fprintf(['%-22s PGA = %7.4f g; peak relative displacement [mm]: ' ...
        'F1 = %9.4f, F2 = %9.4f, F3 = %9.4f\n'], ...
        record_names{record_id}, max(abs(ag))/g0, peak_floor_displacement);
end

%% OVERLAID RESPONSE PLOTS
figure('Color', 'w', 'Name', 'All earthquake relative responses');
response_layout = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
record_colors = lines(n_record);

ground_axes = nexttile;
hold(ground_axes, 'on');
for record_id = 1:n_record
    plot(responses{record_id}.time, responses{record_id}.ag/g0, ...
        'Color', record_colors(record_id, :), 'LineWidth', 0.9);
end
hold(ground_axes, 'off');
ylabel(ground_axes, 'a_g (g)');
grid(ground_axes, 'on');
legend(ground_axes, record_names, 'Location', 'eastoutside');

response_axes = gobjects(n_story, 1);
for floor_id = 1:n_story
    response_axes(floor_id) = nexttile;
    hold(response_axes(floor_id), 'on');
    for record_id = 1:n_record
        plot(responses{record_id}.time, ...
            responses{record_id}.u_relative(:, floor_id), ...
            'Color', record_colors(record_id, :), 'LineWidth', 0.9);
    end
    hold(response_axes(floor_id), 'off');
    ylabel(response_axes(floor_id), sprintf('Floor %d (mm)', floor_id));
    grid(response_axes(floor_id), 'on');
end
xlabel(response_axes(end), 'Time (s)');
title(response_layout, 'All ground accelerations and relative floor displacements');
subtitle(response_layout, sprintf(['Scale = %.3g; damping = %.1f%%; ' ...
    'natural frequencies = %.3f, %.3f, %.3f Hz'], earthquake_scale, ...
    100*damping_ratio, frequency_hz(1), frequency_hz(2), frequency_hz(3)));
linkaxes([ground_axes; response_axes], 'x');

%% LOCAL FUNCTIONS
function k = columnLateralStiffness(E, G, Ix, Av, L)
phi = 12*E*Ix/(G*Av*L^2);
k = 12*E*Ix/(L^3*(1+phi));
end

function u = newmarkAverageAcceleration(time, M, C, K, force)
n_step = numel(time);
n_dof = size(M, 1);
u = zeros(n_step, n_dof);
v = zeros(n_step, n_dof);
a = zeros(n_step, n_dof);
a(1, :) = (M\(force(:, 1)-C*v(1, :)'-K*u(1, :)'))';

beta = 1/4;
gamma = 1/2;
for step = 2:n_step
    dt = time(step)-time(step-1);
    a0 = 1/(beta*dt^2);
    a1 = gamma/(beta*dt);
    a2 = 1/(beta*dt);
    a3 = 1/(2*beta)-1;
    a4 = gamma/beta-1;
    a5 = dt*(gamma/(2*beta)-1);

    effective_stiffness = K+a0*M+a1*C;
    effective_rhs = force(:, step) ...
        + M*(a0*u(step-1, :)'+a2*v(step-1, :)'+a3*a(step-1, :)') ...
        + C*(a1*u(step-1, :)'+a4*v(step-1, :)'+a5*a(step-1, :)');

    u(step, :) = (effective_stiffness\effective_rhs)';
    a(step, :) = (a0*(u(step, :)'-u(step-1, :)') ...
        - a2*v(step-1, :)'-a3*a(step-1, :)')';
    v(step, :) = (v(step-1, :)'+dt*((1-gamma)*a(step-1, :)' ...
        + gamma*a(step, :)'))';
end
end
