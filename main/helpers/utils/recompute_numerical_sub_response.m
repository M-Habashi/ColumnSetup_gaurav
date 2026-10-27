function [numerical_sub, hs] = recompute_numerical_sub_response(result)
%RECOMPUTE_NUMERICAL_SUB_RESPONSE Recompute d_n by stepping from logged fm.
% Units: result.t/effective_time [s], result.fm [N], d_n [mm], x_n [m].

project_folder = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(project_folder, 'control_and_HS', 'd_HS', 'utils_HS'));
addpath(fullfile(project_folder, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));

if isfield(result, 'result') && isstruct(result.result)
    result = result.result;
end
assert(isfield(result, 'hs') && isfield(result.hs, 'fem'), ...
    'Result does not contain hs.fem for numerical sub recomputation.')
assert(isfield(result, 'fm'), ...
    'Result does not contain logged fm for numerical sub recomputation.')

t = result.t(:);
fm = result.fm(:);
if isfield(result, 'dt')
    dt = result.dt;
else
    dt = mean(diff(t));
end
pause_enable = getPauseEnable(result, numel(t));
n = min([numel(t), numel(fm), numel(pause_enable)]);
t = t(1:n);
fm = fm(1:n);
pause_enable = pause_enable(1:n);

hs = prepareHs(result.hs, project_folder);
[x_n, d_n, effective_time] = replayNumericalSub(fm, pause_enable, dt, hs);

numerical_sub = struct('t', t, 'effective_time', effective_time, ...
    'pause_enable', pause_enable, 'd_n_mm', d_n, 'x_n_m', x_n);
end

function hs = prepareHs(hs, project_folder)
required = {'n_floor', 'M', 'K', 'C', 'force_to_floor', ...
    'interface_from_floor', 'interface_from_force', ...
    'ground_force_gain', 'time', 'ag', 'time_scale_factor', 'force_sign'};
if all(isfield(hs, required))
    return
end

fem_num = hs.fem.num;
fem_ref = hs.fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);

hs.n_floor = numel(floor_dofs);
hs.M = fem_num.M(floor_dofs, floor_dofs);
hs.K = K_ff - K_fi*(K_ii\K_if);
hs.force_to_floor = K_fi/K_ii;
hs.interface_from_floor = -K_ii\K_if;
hs.interface_from_force = -1/K_ii;
hs.ground_force_gain = -(hs.M*fem_num.influence(floor_dofs(:)));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, hs.fem);

if ~isfield(hs, 'time') || ~isfield(hs, 'ag')
    earthquakes = load(fullfile(project_folder, 'input_signals', ...
        'earthquakes.mat'), hs.earthquake_type);
    earthquake = earthquakes.(hs.earthquake_type);
    hs.time = earthquake(:, 1) - earthquake(1, 1);
    hs.ag = hs.intensity_factor*earthquake(:, 2);
end
if ~isfield(hs, 'force_sign') || isempty(hs.force_sign)
    hs.force_sign = 1.0;
end
end

function [x_n, d_n, effective_time] = replayNumericalSub(fm, ...
        pause_enable, dt, hs)
n = numel(fm);
state = [];
x_n = zeros(n, hs.n_floor);
d_n = zeros(n, 1);
effective_time = zeros(n, 1);
for step = 2:n
    [d_n(step), state] = step_HS(fm(step), pause_enable(step), ...
        dt, hs, state);
    x_n(step, :) = state(1:hs.n_floor)';
    effective_time(step) = effective_time(step - 1);
    if pause_enable(step) == 0
        effective_time(step) = effective_time(step) + dt;
    end
end
end

function pause_enable = getPauseEnable(result, n)
if isfield(result, 'dd_pause_enable_log') ...
        && ~isempty(result.dd_pause_enable_log)
    pause_enable = result.dd_pause_enable_log(:);
elseif isfield(result, 'dd_pause_enable') && ~isempty(result.dd_pause_enable)
    pause_enable = result.dd_pause_enable(:);
elseif isfield(result, 'Results') && numel(result.Results) >= 1 ...
        && size(result.Results{1}, 2) >= 10
    pause_enable = result.Results{1}(:, 10);
else
    pause_enable = zeros(n, 1);
end
end
