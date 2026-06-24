clear; clc

project_root = 'C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\Gaurav Setup\ColumnSetup_gaurav\main';
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', 'utils_fem'));
addpath(fullfile(project_root, 'results_analysis'));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', 'id_utils'));

S_fem = load(fullfile(project_root, 'saved_results', 'fem', 'fem_sp_1_org.mat'), 'fem');
fem = S_fem.fem;
fem_num = fem.num;
fem_ref = fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

base_hs = struct();
base_hs.n_floor = numel(floor_dofs);
base_hs.M = fem_num.M(floor_dofs, floor_dofs);
base_hs.K = K_ff - K_fi*(K_ii\K_if);
base_hs.force_to_floor = K_fi/K_ii;
base_hs.interface_from_floor = -K_ii\K_if;
base_hs.interface_from_force = -1/K_ii;
base_hs.force_sign = 1.0;
base_hs.ground_force_gain = -(base_hs.M*fem_num.influence(floor_dofs(:)));

[modes, omega2] = eig(fem_ref.K, fem_ref.M, 'vector');
[omega, order] = sort(sqrt(real(omega2)));
modes = real(modes(:, order));
for mode_id = 1:size(modes, 2)
    modes(:, mode_id) = modes(:, mode_id) ...
        /sqrt(modes(:, mode_id)'*fem_ref.M*modes(:, mode_id));
end

model_dir = fullfile(project_root, 'saved_results', 'models');
files = dir(fullfile(model_dir, '*.mat'));
[~, file_order] = sort([files.datenum], 'descend');
files = files(file_order);
model_file = '';
for file_id = 1:numel(files)
    candidate = fullfile(files(file_id).folder, files(file_id).name);
    names = {whos('-file', candidate).name};
    if any(strcmp(names, 'H_dd_dm'))
        model_file = candidate;
        break
    end
end
assert(~isempty(model_file), 'No H_dd_dm model file found')

S = load(model_file, 'H_dd_dm', 'H_dc_dm', 'pid_values');
dt = 1/2048;
H_dd_dm = S.H_dd_dm;
if get(H_dd_dm, 'Ts') == 0
    Hdd = c2d(H_dd_dm, dt, 'zoh');
elseif abs(get(H_dd_dm, 'Ts')-dt) > 10*eps(dt)
    Hdd = d2d(H_dd_dm, dt, 'zoh');
else
    Hdd = H_dd_dm;
end

k0 = fem_num.experimental_k;
fprintf('Model file: %s\n', model_file)
fprintf('Original experimental stiffness k = %.12g N/m\n', k0)

zeta_vals = [0.02 0.03 0.04 0.05 0.06 0.08 0.10 0.15 0.20]';
damp_r = zeros(size(zeta_vals));
for i = 1:numel(zeta_vals)
    hs = base_hs;
    hs.C = fem_ref.M*modes*diag(2*zeta_vals(i)*omega)*modes'*fem_ref.M;
    Hnum = numerical_substructure_tf(hs, dt);
    damp_r(i) = max_abs_pole(Hnum, Hdd, k0);
end
disp('Numerical damping sweep')
disp(table(zeta_vals, damp_r, damp_r < 1, ...
    'VariableNames', {'DampingRatio', 'MaxAbsPole', 'Stable'}))

hs = base_hs;
hs.C = fem_ref.M*modes*diag(2*0.02*omega)*modes'*fem_ref.M;
Hnum = numerical_substructure_tf(hs, dt);

lo = 0;
hi = 1;
for i = 1:60
    mid = (lo+hi)/2;
    if max_abs_pole(Hnum, Hdd, k0*mid) < 1
        lo = mid;
    else
        hi = mid;
    end
end
critical_k_scale = lo;
scales = [0.50 0.75 0.90 0.95 critical_k_scale 0.99 1.00]';
scale_r = zeros(size(scales));
for i = 1:numel(scales)
    scale_r(i) = max_abs_pole(Hnum, Hdd, k0*scales(i));
end
fprintf('Critical k_exp_r about %.10f; stable below this value.\n', critical_k_scale)
disp('Experimental stiffness scale sweep')
disp(table(scales, scale_r, scale_r < 1, ...
    'VariableNames', {'KScale', 'MaxAbsPole', 'Stable'}))

lo = 0;
hi = 1;
for i = 1:60
    mid = (lo+hi)/2;
    if max_abs_pole(Hnum, Hdd*mid, k0) < 1
        lo = mid;
    else
        hi = mid;
    end
end
fprintf('Critical scalar gain on H_dd_dm about %.10f; stable if <= this.\n', lo)

[dominant_pole, max_radius] = dominant_closed_pole(Hnum, Hdd, k0);
dominant_frequency_hz = abs(angle(dominant_pole))/(2*pi*dt);
fprintf('Dominant pole = %.12g%+.12gi, |z| = %.12g, f = %.6g Hz\n', ...
    real(dominant_pole), imag(dominant_pole), max_radius, ...
    dominant_frequency_hz)

frequencies = [dominant_frequency_hz; omega(1)/(2*pi); omega(2)/(2*pi); omega(3)/(2*pi)];
loop_mag = zeros(size(frequencies));
loop_phase = zeros(size(frequencies));
hdd_mag = zeros(size(frequencies));
hdd_phase = zeros(size(frequencies));
for i = 1:numel(frequencies)
    z = exp(1i*2*pi*frequencies(i)*dt);
    Hdd_value = evalfr(Hdd, z);
    loop_value = -evalfr(Hnum, z)*(k0/1000)*Hdd_value;
    hdd_mag(i) = abs(Hdd_value);
    hdd_phase(i) = angle(Hdd_value)*180/pi;
    loop_mag(i) = abs(loop_value);
    loop_phase(i) = angle(loop_value)*180/pi;
end
disp('Frequency response at modal/dominant frequencies')
disp(table(frequencies, hdd_mag, hdd_phase, loop_mag, loop_phase, ...
    'VariableNames', {'FrequencyHz', 'HddMag', 'HddPhaseDeg', ...
    'LoopMag', 'LoopPhaseDeg'}))

if isfield(S, 'pid_values')
    fprintf('Saved PID: P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', ...
        S.pid_values.P, S.pid_values.I, S.pid_values.D, ...
        S.pid_values.derivative_filter_N)
end

if isfield(S, 'H_dc_dm') && isfield(S, 'pid_values')
    Hdc = S.H_dc_dm;
    if get(Hdc, 'Ts') == 0
        Hdc_d = c2d(Hdc, dt, 'zoh');
    elseif abs(get(Hdc, 'Ts')-dt) > 10*eps(dt)
        Hdc_d = d2d(Hdc, dt, 'zoh');
    else
        Hdc_d = Hdc;
    end
    base_pid = S.pid_values;
    gain_scales = [0.25 0.50 0.75 1.00 1.25 1.50 2.00 3.00 4.00]';
    pid_radius = zeros(size(gain_scales));
    pid_hdd_mag = zeros(size(gain_scales));
    pid_hdd_phase = zeros(size(gain_scales));
    pid_stable = false(size(gain_scales));
    z_dom = exp(1i*2*pi*dominant_frequency_hz*dt);
    for i = 1:numel(gain_scales)
        C = pid(base_pid.P*gain_scales(i), base_pid.I*gain_scales(i), ...
            base_pid.D*gain_scales(i), 1/base_pid.derivative_filter_N, ...
            dt, 'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
        Hdd_pid = feedback(C*Hdc_d, 1);
        pid_radius(i) = max_abs_pole(Hnum, Hdd_pid, k0);
        pid_stable(i) = pid_radius(i) < 1;
        Hdd_value = evalfr(Hdd_pid, z_dom);
        pid_hdd_mag(i) = abs(Hdd_value);
        pid_hdd_phase(i) = angle(Hdd_value)*180/pi;
    end
    disp('PID all-gain scale sweep using H_dd_dm = feedback(PID*H_dc_dm, 1)')
    disp(table(gain_scales, pid_radius, pid_stable, pid_hdd_mag, ...
        pid_hdd_phase, 'VariableNames', {'PidGainScale', 'MaxAbsPole', ...
        'Stable', 'HddMagAtDomFreq', 'HddPhaseDegAtDomFreq'}))

    p_scales = [0.5 1 2 3 4 6 8]';
    i_scales = [0.25 0.5 1 1.5 2 3]';
    best = table([], [], [], [], [], ...
        'VariableNames', {'PScale', 'IScale', 'DScale', 'MaxAbsPole', ...
        'Stable'});
    for pi = 1:numel(p_scales)
        for ii = 1:numel(i_scales)
            C = pid(base_pid.P*p_scales(pi), base_pid.I*i_scales(ii), ...
                base_pid.D, 1/base_pid.derivative_filter_N, dt, ...
                'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
            Hdd_pid = feedback(C*Hdc_d, 1);
            r = max_abs_pole(Hnum, Hdd_pid, k0);
            best = [best; {p_scales(pi), i_scales(ii), 1, r, r < 1}]; %#ok<AGROW>
        end
    end
    best = sortrows(best, 'MaxAbsPole');
    disp('Best P/I scale candidates with D unchanged')
    disp(best(1:min(12, height(best)), :))
end

function Hnum = numerical_substructure_tf(hs, dt)
n = hs.n_floor;
beta = 1/4;
gamma = 1/2;
a0 = 1/(beta*dt^2);
a1 = gamma/(beta*dt);
a2 = 1/(beta*dt);
a3 = 1/(2*beta)-1;
a4 = gamma/beta-1;
a5 = dt*(gamma/(2*beta)-1);
effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
solver = effective_stiffness\eye(n);
Su = solver*[a0*hs.M+a1*hs.C, a2*hs.M+a4*hs.C, a3*hs.M+a5*hs.C];
Sf = solver*(hs.force_to_floor*hs.force_sign);
A = zeros(3*n);
B = zeros(3*n, 1);
A(1:n, :) = Su;
B(1:n) = Sf;
A(2*n+1:3*n, :) = a0*(Su-[eye(n), zeros(n), zeros(n)]) ...
    - a2*[zeros(n), eye(n), zeros(n)] ...
    - a3*[zeros(n), zeros(n), eye(n)];
B(2*n+1:3*n) = a0*Sf;
A(n+1:2*n, :) = [zeros(n), eye(n), zeros(n)] ...
    + dt*((1-gamma)*[zeros(n), zeros(n), eye(n)] ...
    + gamma*A(2*n+1:3*n, :));
B(n+1:2*n) = dt*gamma*B(2*n+1:3*n);
C = 1000*(hs.interface_from_floor*Su);
D = 1000*(hs.interface_from_floor*Sf + hs.interface_from_force*hs.force_sign);
Hnum = ss(A, B, C, D, dt);
end

function value = max_abs_pole(Hnum, Hdd, k)
value = max(abs(pole(feedback(Hnum, -(k/1000)*Hdd))));
end

function [dominant_pole, radius] = dominant_closed_pole(Hnum, Hdd, k)
p = pole(feedback(Hnum, -(k/1000)*Hdd));
[radius, idx] = max(abs(p));
dominant_pole = p(idx);
end
