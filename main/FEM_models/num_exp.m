%% NUMERICAL-EXPERIMENTAL SUBSTRUCTURE COMPARISON
% The physical column is defined by experimentalColumnDefinition.

clear; clc; close all;

%% INPUTS
earthquake_id = 1;
earthquake_scale = 1.0;
damping_ratio = 0.02;
exp_k_reduction = 1;                                 % 0.9 = 10% reduction
frame = sapTemplateFrameDefinition();
beam_connection_k = frame.beam_connection_k;
base_rotation_k = frame.base_rotation_k;             % [N*mm/rad]

validateattributes(earthquake_id, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 10});
validateattributes(earthquake_scale, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(damping_ratio, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 1});
validateattributes(exp_k_reduction, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<=', 1});

%% REFERENCE MODEL
n_story = frame.n_story;
n_bay = frame.n_bay;
bay_width = frame.bay_width;
story_height = frame.story_height;
E = frame.E;                                          % [N/mm^2]
experimental_column = experimentalColumnDefinition();

section = frame.section;

% Full 2-D frame assembly followed by static condensation of rotations.
[K_reference, frame_model] = assembleCondensedFrameStiffness( ...
    n_story, n_bay, bay_width, story_height, E, section, ...
    beam_connection_k, base_rotation_k);

M = diag([20121; 20121; 18426])/1000;
influence = ones(n_story, 1);

[modes, omega2] = eig(K_reference, M, 'vector');
[omega, order] = sort(sqrt(omega2));
modes = modes(:, order);
for mode_id = 1:n_story
    modes(:, mode_id) = modes(:, mode_id)/ ...
        sqrt(modes(:, mode_id)'*M*modes(:, mode_id));
end
C = M*modes*diag(2*damping_ratio*omega)*modes'*M;

%% NUMERICAL-EXPERIMENTAL PARTITION
% The single-actuator partition still exchanges only horizontal displacement
% and shear. Its fixed-fixed half-column approximation is retained until the
% experiment can exchange interface rotation and moment as well.
k_ext = 12*E*section.W8x28.Ix/story_height^3;

% Remove the same scalar restoring contribution that the experimental
% substructure returns. This preserves the reference solution when the
% experimental reduction factor is one.
K_numerical = K_reference;
K_numerical(1, 1) = K_numerical(1, 1)-k_ext;

% Double curvature: d_exp = u1/2 and the unreduced k_exp = 2*k_ext.
k_experimental = exp_k_reduction*2*k_ext;
interface_dof = 1;

%% EARTHQUAKE INPUT
record_fields = {'el_centro', 'northridge', 'kobe', 'loma_prieta', ...
    'chi_chi', 'imperial_valley', 'landers', 'tabas', ...
    'san_fernando', 'tohoku'};
record_names = {'El Centro 1940', 'Northridge 1994', 'Kobe 1995', ...
    'Loma Prieta 1989', 'Chi-Chi 1999', 'Imperial Valley 1979', ...
    'Landers 1992', 'Tabas 1978', 'San Fernando 1971', 'Tohoku 2011'};

script_dir = fileparts(mfilename('fullpath'));
earthquake_file = fullfile(script_dir, '..', 'input_signals', 'earthquakes.mat');
data = load(earthquake_file, record_fields{earthquake_id});
record = data.(record_fields{earthquake_id});
time = record(:, 1);
ag = record(:, 2)*1000*earthquake_scale;               % [mm/s^2]
assert(size(record, 2) == 2 && all(isfinite(record), 'all'));
assert(all(diff(time) > 0), 'Earthquake time must be strictly increasing.');
applied_force = -(M*influence)*ag';                    % [N]

%% INITIALIZE BOTH NEWMARK SOLUTIONS
n_step = numel(time);
u_reference = zeros(n_step, n_story);
v_reference = zeros(n_step, n_story);
a_reference = zeros(n_step, n_story);
u_num_exp = zeros(n_step, n_story);
v_num_exp = zeros(n_step, n_story);
a_num_exp = zeros(n_step, n_story);
experimental_force = zeros(n_step, 1);
iteration_count = ones(n_step, 1);

a_reference(1, :) = (M\applied_force(:, 1))';
a_num_exp(1, :) = a_reference(1, :);
beta = 1/4;
gamma = 1/2;
force_tolerance = 1e-12;
max_iterations = 100;

%% REFERENCE AND COUPLED TIME INTEGRATION
for step = 2:n_step
    dt = time(step)-time(step-1);
    c0 = 1/(beta*dt^2);
    c1 = gamma/(beta*dt);
    c2 = 1/(beta*dt);
    c3 = 1/(2*beta)-1;
    c4 = gamma/beta-1;
    c5 = dt*(gamma/(2*beta)-1);

    % Complete reference model.
    rhs_ref = applied_force(:, step) ...
        + M*(c0*u_reference(step-1, :)'+c2*v_reference(step-1, :)' ...
        + c3*a_reference(step-1, :)') ...
        + C*(c1*u_reference(step-1, :)'+c4*v_reference(step-1, :)' ...
        + c5*a_reference(step-1, :)');
    u_reference(step, :) = ((K_reference+c0*M+c1*C)\rhs_ref)';
    a_reference(step, :) = (c0*(u_reference(step, :)' ...
        - u_reference(step-1, :)')-c2*v_reference(step-1, :)' ...
        - c3*a_reference(step-1, :)')';
    v_reference(step, :) = (v_reference(step-1, :)' ...
        + dt*((1-gamma)*a_reference(step-1, :)' ...
        + gamma*a_reference(step, :)'))';

    % Partitioned model with iterative force-displacement exchange.
    rhs_num = applied_force(:, step) ...
        + M*(c0*u_num_exp(step-1, :)'+c2*v_num_exp(step-1, :)' ...
        + c3*a_num_exp(step-1, :)') ...
        + C*(c1*u_num_exp(step-1, :)'+c4*v_num_exp(step-1, :)' ...
        + c5*a_num_exp(step-1, :)');
    Keff_num = K_numerical+c0*M+c1*C;
    force_guess = experimental_force(step-1);

    for iteration = 1:max_iterations
        displacement_trial = numericalSubstructure(force_guess, ...
            Keff_num, rhs_num, interface_dof);
        force_trial = experimentalSubstructure( ...
            displacement_trial(interface_dof)/2, k_experimental);
        if abs(force_trial-force_guess) <= ...
                force_tolerance*max(1, abs(force_trial))
            force_guess = force_trial;
            displacement_trial = numericalSubstructure(force_guess, ...
                Keff_num, rhs_num, interface_dof);
            break;
        end
        force_guess = force_trial;
    end
    assert(iteration < max_iterations, ...
        'Interface iteration failed at time %.6f s.', time(step));

    iteration_count(step) = iteration;
    experimental_force(step) = force_guess;
    u_num_exp(step, :) = displacement_trial';
    a_num_exp(step, :) = (c0*(u_num_exp(step, :)'-u_num_exp(step-1, :)') ...
        - c2*v_num_exp(step-1, :)'-c3*a_num_exp(step-1, :)')';
    v_num_exp(step, :) = (v_num_exp(step-1, :)' ...
        + dt*((1-gamma)*a_num_exp(step-1, :)' ...
        + gamma*a_num_exp(step, :)'))';
end

%% ACCURACY CHECK
maximum_error = max(abs(u_num_exp-u_reference), [], 'all');

% J1-J3 require separate commanded and measured actuator displacement
% histories. This numerical experiment only provides structural responses,
% so only the applicable response-validation metrics J4-J7 are evaluated.
addpath(fullfile(script_dir, '..', 'helpers', 'analysis_visualization'));
metric = validation_metrics();
J4 = metric.J4(u_num_exp(:, 1), u_reference(:, 1));
J5 = metric.J5(u_num_exp(:, 1), u_reference(:, 1));
J6 = metric.J6(u_num_exp(:, 2), u_reference(:, 2));
J7 = metric.J7(u_num_exp(:, 3), u_reference(:, 3));

fprintf('\n%s numerical-experimental partition\n', record_names{earthquake_id});
fprintf('Model: condensed 2-D frame FEM (%d full DOFs)\n', ...
    size(frame_model.K_full, 1));
fprintf('Beam-column rotational stiffness: Inf (rigid)\n');
fprintf('Base rotational stiffness: %.12g N*mm/rad\n', base_rotation_k);
fprintf('Experimental k: %.6f N/mm (reduction factor: %.3f)\n', ...
    k_experimental, exp_k_reduction);
fprintf('Maximum displacement difference: %.6e mm\n', maximum_error);
fprintf('Maximum interface iterations: %d\n\n', max(iteration_count));
for floor_id = 1:n_story
    fprintf('Floor %d peak: reference = %.6f mm, num_exp = %.6f mm\n', ...
        floor_id, max(abs(u_reference(:, floor_id))), ...
        max(abs(u_num_exp(:, floor_id))));
end
fprintf('\nValid validation metrics:\n');
fprintf('J4 - first-floor normalized RMS error: %.2f%%\n', J4);
fprintf('J5 - first-floor normalized peak error: %.2f%%\n', J5);
fprintf('J6 - second-floor normalized RMS error: %.2f%%\n', J6);
fprintf('J7 - third-floor normalized RMS error: %.2f%%\n\n', J7);

%% TIME-HISTORY OVERLAY
floor_colors = lines(n_story);
figure('Color', 'w', 'Name', 'Reference and num exp comparison');
time_layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax = nexttile;
    hold(ax, 'on');
    plot(time, u_reference(:, floor_id), '--', 'Color', [0.35 0.35 0.35], ...
        'LineWidth', 2.4, 'DisplayName', 'Reference');
    plot(time, u_num_exp(:, floor_id), '-', 'Color', floor_colors(floor_id, :), ...
        'LineWidth', 1.0, 'DisplayName', 'num\_exp');
    hold(ax, 'off'); grid(ax, 'on');
    ylabel(ax, sprintf('Floor %d (mm)', floor_id));
    if floor_id == 1, legend(ax, 'Location', 'best'); end
end
xlabel(ax, 'Time (s)');
title(time_layout, sprintf('%s: reference and num\\_exp response', ...
    record_names{earthquake_id}));
subtitle(time_layout, sprintf('Maximum difference = %.3e mm', maximum_error));
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% ONE-SIDED DISPLACEMENT FFT OVERLAY
dt = median(diff(time));
sampling_frequency = 1/dt;
frequency = (0:floor(n_step/2))'*sampling_frequency/n_step;
reference_complex = fft(u_reference, n_step, 1)/n_step;
num_exp_complex = fft(u_num_exp, n_step, 1)/n_step;
reference_amplitude = 2*abs(reference_complex(1:numel(frequency), :));
num_exp_amplitude = 2*abs(num_exp_complex(1:numel(frequency), :));
reference_amplitude(1, :) = reference_amplitude(1, :)/2;
num_exp_amplitude(1, :) = num_exp_amplitude(1, :)/2;
if rem(n_step, 2) == 0
    reference_amplitude(end, :) = reference_amplitude(end, :)/2;
    num_exp_amplitude(end, :) = num_exp_amplitude(end, :)/2;
end

figure('Color', 'w', 'Name', 'Reference and num exp FFT comparison');
fft_layout = tiledlayout(n_story, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for floor_id = 1:n_story
    ax_fft = nexttile;
    hold(ax_fft, 'on');
    plot(frequency, reference_amplitude(:, floor_id), '--', ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 2.4, ...
        'DisplayName', 'Reference');
    plot(frequency, num_exp_amplitude(:, floor_id), '-', ...
        'Color', floor_colors(floor_id, :), 'LineWidth', 1.0, ...
        'DisplayName', 'num\_exp');
    hold(ax_fft, 'off'); grid(ax_fft, 'on'); xlim(ax_fft, [0 100]);
    ylabel(ax_fft, sprintf('Floor %d (mm)', floor_id));
    if floor_id == 1, legend(ax_fft, 'Location', 'best'); end
end
xlabel(ax_fft, 'Frequency (Hz)');
title(fft_layout, sprintf('%s: displacement FFT comparison', ...
    record_names{earthquake_id}));
subtitle(fft_layout, 'One-sided amplitude spectrum');
linkaxes(findall(gcf, 'Type', 'axes'), 'x');

%% NUMERICAL-EXPERIMENTAL FRAME PARTITION
frame_x = (0:n_bay)*bay_width;
frame_y = (0:n_story)*story_height;
interface_y = experimental_column.height_mm;

figure('Color', 'w', 'Name', 'Numerical-experimental frame partition');
hold on;

% Numerical beams.
for level_id = 2:numel(frame_y)
    plot([frame_x(1), frame_x(end)], frame_y(level_id)*[1 1], ...
        'k-', 'LineWidth', 3, 'HandleVisibility', 'off');
end

% Numerical columns. The lower-left column starts at the interface because
% the segment below it belongs to the experimental substructure.
for column_id = 1:numel(frame_x)
    if column_id == 1
        plot(frame_x(column_id)*[1 1], [interface_y, frame_y(end)], ...
            'k-', 'LineWidth', 3, 'HandleVisibility', 'off');
    else
        plot(frame_x(column_id)*[1 1], [frame_y(1), frame_y(end)], ...
            'k-', 'LineWidth', 3, 'HandleVisibility', 'off');
    end
end

% Experimental lower half of the first-story left exterior column.
h_experimental = plot(frame_x(1)*[1 1], [frame_y(1), interface_y], ...
    '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 6, ...
    'DisplayName', 'Experimental substructure');
h_interface = plot(frame_x(1), interface_y, 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.85 0.10 0.10], ...
    'MarkerEdgeColor', 'k', 'DisplayName', 'Interface');
h_numerical = plot(nan, nan, 'k-', 'LineWidth', 3, ...
    'DisplayName', 'Numerical substructure');

% Fixed supports.
for column_id = 1:numel(frame_x)
    plot(frame_x(column_id)+0.16*bay_width*[-1 1], [0 0], ...
        'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
    for hatch_id = -2:2
        hatch_x = frame_x(column_id)+hatch_id*0.055*bay_width;
        plot([hatch_x-0.035*bay_width, hatch_x], ...
            [-0.08*story_height, 0], 'k-', 'HandleVisibility', 'off');
    end
end

text(frame_x(1)+0.12*bay_width, interface_y, ...
    'Interface: d_{exp} = u_1/2', 'Color', [0.75 0.05 0.05], ...
    'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
text(frame_x(1)+0.12*bay_width, 0.20*story_height, ...
    sprintf('Experimental %s column', experimental_column.shape), ...
    'Color', [0.75 0.05 0.05]);

legend([h_numerical, h_experimental, h_interface], 'Location', 'northoutside', ...
    'Orientation', 'horizontal');
title('Numerical-experimental frame partition');
subtitle('Black: numerical model; red: experimental substructure');
axis equal;
axis off;
xlim([-0.45*bay_width, frame_x(end)+0.45*bay_width]);
ylim([-0.15*story_height, frame_y(end)+0.35*story_height]);
hold off;

%% COUPLING FUNCTIONS
function displacement = numericalSubstructure(experimental_force, ...
        effective_stiffness, effective_rhs, interface_dof)
% Experimental force in; numerical displacement out.
restoring_force = zeros(size(effective_rhs));
restoring_force(interface_dof) = experimental_force;
displacement = effective_stiffness\(effective_rhs-restoring_force);
end

function force = experimentalSubstructure(displacement, stiffness)
% Commanded displacement in; experimental force out.
force = stiffness*displacement;
end
