%% Notch Filter Study for Damage-Robust vHS Compensation
% Focused offline study for frequency-shaped authority reduction.
% The notch has unity DC/high-frequency gain and attenuates a selected band:
% A(s) = (s^2 + 2*zeta_z*w0*s + w0^2)/(s^2 + 2*zeta_p*w0*s + w0^2)
% where notch depth at w0 is zeta_z/zeta_p.

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(fileparts(script_dir)));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', 'id_utils'));
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));

config = defaultConfig();
context = buildContext(project_root, config);
damage_cases = buildDamageCases(context, config);
candidates = buildNotchCandidates(context, config);

fprintf('\nNotch filter study\n')
fprintf('Candidate count: %d\n', numel(candidates))
fprintf('Damage case count: %d\n', numel(damage_cases))
fprintf('Numerical modes [Hz]: %s\n', numericVectorText( ...
    context.summary.num_mode_frequency_hz))

margin_table = evaluateMarginGrid(context, damage_cases, candidates, config);
margin_table = sortrows(margin_table, 'MarginScore', 'ascend');
time_candidate_ids = selectTimeDomainCandidates(margin_table, candidates, ...
    config);
time_table = evaluateTimeDomainCandidates(context, damage_cases, candidates, ...
    time_candidate_ids);
summary_table = combineMarginAndTime(margin_table, time_table, config);
summary_table = sortrows(summary_table, 'FinalScore', 'ascend');

result = struct( ...
    'config', config, ...
    'context_summary', context.summary, ...
    'damage_cases', damage_cases, ...
    'margin_table', margin_table, ...
    'time_table', time_table, ...
    'summary_table', summary_table);

save(fullfile(script_dir, 'notch_filter_study_result.mat'), 'result')
writeMarkdownReport(fullfile(script_dir, 'notch_filter_study_report.md'), ...
    result)
plotSummary(fullfile(script_dir, 'notch_filter_study_summary.png'), result)

fprintf('\nBest verified candidates\n')
disp(summary_table(1:min(16, height(summary_table)), ...
    {'CandidateId', 'Label', 'Alpha', 'CenterHz', 'Depth', ...
    'ZetaPole', 'MinNCF', 'MinGM_dB', 'MaxAbsPole', ...
    'MaxJ4_percent', 'MaxPeakCommandRatio', 'FinalScore', ...
    'WorstNCFCase'}))
fprintf('Saved notch study outputs under %s\n', script_dir)

function config = defaultConfig()
config = struct( ...
    'sample_dt', 1/2048, ...
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.2, ...
    'time_scale_factor', 1.0, ...
    'force_sign', 1.0, ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    'frequency_range_hz', [0.1 80], ...
    'frequency_point_count', 10000, ...
    'ncf_preferred_target', 0.35, ...
    'gm_target_db', 7.0, ...
    'pole_target', 0.99995, ...
    'command_ratio_limit', 1.25, ...
    'min_k_ratio', 0.50, ...
    'alpha_values', [1.0 0.8 0.6], ...
    'notch_center_hz', [22 26 30 34 35.5 38 42 46 52], ...
    'notch_depth', [0.2 0.35 0.5 0.65 0.8], ...
    'notch_zeta_pole', [0.08 0.12 0.18 0.25 0.35], ...
    'time_domain_candidate_count', 16, ...
    'report_top_count', 18);
end

function context = buildContext(project_root, config)
dt = config.sample_dt;
freq_hz = logspace(log10(config.frequency_range_hz(1)), ...
    log10(config.frequency_range_hz(2)), ...
    config.frequency_point_count).';
freq_rad_s = 2*pi*freq_hz;

healthy_tf_file = fullfile(project_root, 'saved_results', 'exp_tf', ...
    'tf_sp_1_7000_20260627_210411.mat');
damaged_tf_file = fullfile(project_root, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat');
healthy_specimen_file = fullfile(project_root, 'saved_results', ...
    'specimens', 'sp1_7000.mat');
damaged_specimen_file = fullfile(project_root, 'saved_results', ...
    'specimens', 'sp1_5000.mat');
fem_file = fullfile(project_root, 'saved_results', 'fem', ...
    'fem_sp1_7000.mat');

healthy_data = load(healthy_tf_file, 'H_dc_dm');
damaged_data = load(damaged_tf_file, 'H_dc_dm');
H_healthy = forceDiscrete(healthy_data.H_dc_dm, dt);
H_damaged = forceDiscrete(damaged_data.H_dc_dm, dt);

pid_values = struct('P', config.pid_gain_override(1), ...
    'I', config.pid_gain_override(2), ...
    'D', config.pid_gain_override(3), ...
    'derivative_filter_N', config.pid_gain_override(4));
controller = pid(pid_values.P, pid_values.I, pid_values.D, ...
    1/pid_values.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');

specimen_healthy = unwrapLoadedStruct(load(healthy_specimen_file));
specimen_damaged = unwrapLoadedStruct(load(damaged_specimen_file));
specimen_healthy_si = specimen_params_si(specimen_healthy);
specimen_damaged_si = specimen_params_si(specimen_damaged);

fem_data = load(fem_file, 'fem');
fem = fem_data.fem;
hs = buildHybridSetup(fem, config);
num_model = numericalSubstructureDiscrete(hs, dt);
num_tf = ss(num_model.A, num_model.B_fm, num_model.C, ...
    num_model.D_fm, dt);

earthquakes = load(fullfile(project_root, 'input_signals', ...
    'earthquakes.mat'), config.earthquake_type);
earthquake = earthquakes.(config.earthquake_type);
model_time = earthquake(:, 1) - earthquake(1, 1);
ag = config.intensity_factor*earthquake(:, 2);
real_time = model_time*config.time_scale_factor;
sample_count = ceil(real_time(end)/dt) + 1;
sample_time = (0:sample_count-1)'*dt;
model_sample_time = sample_time/config.time_scale_factor;
ag_sample = interp1(model_time, ag, model_sample_time, 'linear', 0);
reference_load_sample = -(fem.ref.M*fem.ref.influence)*ag_sample';
u_reference_sample = newmarkAverageAcceleration(sample_time, ...
    fem.ref.M, hs.C, fem.ref.K, reference_load_sample);

Hh_response = squeeze(freqresp(H_healthy, freq_rad_s));
Hd_response = squeeze(freqresp(H_damaged, freq_rad_s));
controller_response = squeeze(freqresp(controller, freq_rad_s));
num_response = squeeze(freqresp(num_tf, freq_rad_s));
Hh_response = Hh_response(:);
Hd_response = Hd_response(:);
controller_response = controller_response(:);
num_response = num_response(:);
gamma_fit = real(sum(conj(Hh_response).*Hd_response) ...
    /sum(abs(Hh_response).^2));
fit_error_percent = 100*localRms(Hd_response - gamma_fit*Hh_response) ...
    /max(localRms(Hd_response), eps);

context = struct( ...
    'project_root', project_root, ...
    'dt', dt, ...
    'freq_hz', freq_hz, ...
    'freq_rad_s', freq_rad_s, ...
    'H_healthy', H_healthy, ...
    'H_damaged', H_damaged, ...
    'Hh_response', Hh_response, ...
    'Hd_response', Hd_response, ...
    'controller', controller, ...
    'controller_response', controller_response, ...
    'num_model', num_model, ...
    'num_tf', num_tf, ...
    'num_response', num_response, ...
    'hs', hs, ...
    'sample_time', sample_time, ...
    'ag_sample', ag_sample, ...
    'u_reference_sample', u_reference_sample(:, 1:hs.n_floor), ...
    'k_healthy', specimen_healthy_si.stiffness, ...
    'k_damaged', specimen_damaged_si.stiffness, ...
    'summary', struct( ...
        'gamma_fit', gamma_fit, ...
        'fit_error_percent', fit_error_percent, ...
        'healthy_stiffness_N_per_m', specimen_healthy_si.stiffness, ...
        'damaged_stiffness_N_per_m', specimen_damaged_si.stiffness, ...
        'damaged_to_healthy_k_ratio', ...
            specimen_damaged_si.stiffness/specimen_healthy_si.stiffness, ...
        'ref_mode_frequency_hz', referenceModeFrequencies(fem.ref), ...
        'num_mode_frequency_hz', condensedModeFrequencies(fem.num)));
end

function data = unwrapLoadedStruct(data)
if isfield(data, 'result') && isstruct(data.result)
    data = data.result;
end
end

function hs = buildHybridSetup(fem, config)
fem_num = fem.num;
fem_ref = fem.ref;
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K_num = fem_num.K;
K_ff = K_num(floor_dofs, floor_dofs);
K_fi = K_num(floor_dofs, interface_dof);
K_if = K_num(interface_dof, floor_dofs);
K_ii = K_num(interface_dof, interface_dof);
hs = struct( ...
    'fem', fem, ...
    'n_floor', numel(floor_dofs), ...
    'M', fem_num.M(floor_dofs, floor_dofs), ...
    'K', K_ff - K_fi*(K_ii\K_if), ...
    'K_if', K_if, ...
    'K_ii', K_ii, ...
    'force_to_floor', K_fi/K_ii, ...
    'interface_from_floor', -K_ii\K_if, ...
    'interface_from_force', -1/K_ii, ...
    'force_sign', config.force_sign, ...
    'ground_force_gain', ...
        -(fem_num.M(floor_dofs, floor_dofs) ...
        *fem_num.influence(floor_dofs(:))));
[hs.C, hs.damping] = femDampingMatrix(fem_ref, fem);
end

function damage_cases = buildDamageCases(context, config)
damage_cases = emptyCaseStruct();
kh = context.k_healthy;
kd = context.k_damaged;
gamma_fit = context.summary.gamma_fit;
damage_cases = addDamageCase(damage_cases, 'healthy H, healthy k', ...
    context.H_healthy, context.Hh_response, kh, true, 'measured');
damage_cases = addDamageCase(damage_cases, 'damaged H, damaged k', ...
    context.H_damaged, context.Hd_response, kd, true, 'measured');
damage_cases = addDamageCase(damage_cases, 'damaged H, healthy k', ...
    context.H_damaged, context.Hd_response, kh, true, 'mismatch');
damage_cases = addDamageCase(damage_cases, 'healthy H, damaged k', ...
    context.H_healthy, context.Hh_response, kd, true, 'mismatch');

gamma_values = unique([1.25 1.5 2.0 gamma_fit 3.0 3.5 4.0], 'stable');
for gamma_id = 1:numel(gamma_values)
    gamma_value = gamma_values(gamma_id);
    rho = (gamma_value - 1)/max(gamma_fit - 1, eps);
    k_value = boundedDamageStiffness(kh, kd, rho, config);
    damage_cases = addDamageCase(damage_cases, ...
        sprintf('scalar H gain %.3g, predicted k', gamma_value), ...
        gamma_value*context.H_healthy, gamma_value*context.Hh_response, ...
        k_value, true, 'scalar_gain');
end

extra_damaged_gain = [1.15 1.30];
for gain_id = 1:numel(extra_damaged_gain)
    gain_value = extra_damaged_gain(gain_id);
    damage_cases = addDamageCase(damage_cases, ...
        sprintf('%.3g*damaged H, healthy k', gain_value), ...
        gain_value*context.H_damaged, gain_value*context.Hd_response, ...
        kh, true, 'damaged_gain_healthy_k');
end

rho_values = [0.25 0.5 0.75 1.25 1.5 2.0];
for rho_id = 1:numel(rho_values)
    rho = rho_values(rho_id);
    H_response = context.Hh_response ...
        + rho*(context.Hd_response - context.Hh_response);
    k_value = boundedDamageStiffness(kh, kd, rho, config);
    damage_cases = addDamageCase(damage_cases, ...
        sprintf('measured-shape rho %.3g, predicted k', rho), ...
        [], H_response, k_value, false, 'measured_shape');
end
end

function damage_cases = emptyCaseStruct()
damage_cases = struct('Name', {}, 'H_tf', {}, 'H_response', {}, ...
    'k', {}, 'UseTimeDomain', {}, 'Category', {});
end

function damage_cases = addDamageCase(damage_cases, name, H_tf, ...
        H_response, k_value, use_time_domain, category)
next_id = numel(damage_cases) + 1;
damage_cases(next_id).Name = string(name);
damage_cases(next_id).H_tf = H_tf;
damage_cases(next_id).H_response = H_response(:);
damage_cases(next_id).k = k_value;
damage_cases(next_id).UseTimeDomain = use_time_domain;
damage_cases(next_id).Category = string(category);
end

function k_value = boundedDamageStiffness(kh, kd, rho, config)
k_value = kh + rho*(kd - kh);
k_value = max(k_value, config.min_k_ratio*kh);
end

function candidates = buildNotchCandidates(context, config)
candidates = emptyCandidateStruct();
candidates(1) = makeCandidate(1, 'no notch', 1, NaN, NaN, NaN, NaN, ...
    tf(1, 1, config.sample_dt), context);
candidates(2) = makeCandidate(2, 'authority 0.6 only', 0.6, NaN, NaN, ...
    NaN, NaN, tf(0.6, 1, config.sample_dt), context);
for alpha_id = 1:numel(config.alpha_values)
    alpha = config.alpha_values(alpha_id);
    for center_id = 1:numel(config.notch_center_hz)
        center_hz = config.notch_center_hz(center_id);
        for depth_id = 1:numel(config.notch_depth)
            depth = config.notch_depth(depth_id);
            for zeta_id = 1:numel(config.notch_zeta_pole)
                zeta_pole = config.notch_zeta_pole(zeta_id);
                zeta_zero = depth*zeta_pole;
                notch_tf = continuousNotch(center_hz, zeta_zero, ...
                    zeta_pole);
                G_tf = forceDiscrete(alpha*notch_tf, ...
                    config.sample_dt, 'tustin');
                label = sprintf(['notch alpha %.3g fc %.3g Hz ' ...
                    'depth %.2g zeta %.2g'], alpha, center_hz, ...
                    depth, zeta_pole);
                next_id = numel(candidates) + 1;
                candidates(next_id) = makeCandidate(next_id, label, ...
                    alpha, center_hz, depth, zeta_pole, zeta_zero, ...
                    G_tf, context);
            end
        end
    end
end
end

function candidates = emptyCandidateStruct()
candidates = struct('Id', {}, 'Label', {}, 'Alpha', {}, 'CenterHz', {}, ...
    'Depth', {}, 'ZetaPole', {}, 'ZetaZero', {}, 'G_tf', {}, ...
    'G_response', {});
end

function candidate = makeCandidate(id, label, alpha, center_hz, depth, ...
        zeta_pole, zeta_zero, G_tf, context)
G_response = squeeze(freqresp(G_tf, context.freq_rad_s));
candidate = struct( ...
    'Id', id, ...
    'Label', string(label), ...
    'Alpha', alpha, ...
    'CenterHz', center_hz, ...
    'Depth', depth, ...
    'ZetaPole', zeta_pole, ...
    'ZetaZero', zeta_zero, ...
    'G_tf', G_tf, ...
    'G_response', G_response(:));
end

function notch_tf = continuousNotch(center_hz, zeta_zero, zeta_pole)
w0 = 2*pi*center_hz;
notch_tf = tf([1 2*zeta_zero*w0 w0^2], ...
    [1 2*zeta_pole*w0 w0^2]);
end

function ids = selectTimeDomainCandidates(margin_table, candidates, config)
ids = margin_table.CandidateId( ...
    1:min(config.time_domain_candidate_count, height(margin_table)));
alpha_one = margin_table(abs(margin_table.Alpha - 1) < 1e-12, :);
if ~isempty(alpha_one)
    ids(end+1, 1) = alpha_one.CandidateId(1);
end
ids = unique([1; 2; ids(:); forcedCenterIds(candidates)], 'stable');
end

function ids = forcedCenterIds(candidates)
ids = [];
for i = 1:numel(candidates)
    label = candidates(i).Label;
    is_notch = contains(label, 'notch ');
    is_key_center = abs(candidates(i).CenterHz - 35.5) < 1e-9;
    is_key_depth = any(abs(candidates(i).Depth - [0.35 0.5]) < 1e-9);
    is_key_alpha = abs(candidates(i).Alpha - 1) < 1e-12;
    if is_notch && is_key_center && is_key_depth && is_key_alpha
        ids(end+1, 1) = candidates(i).Id; %#ok<AGROW>
    end
end
end

function margin_table = evaluateMarginGrid(context, damage_cases, ...
        candidates, config)
n_candidate = numel(candidates);
candidate_id = zeros(n_candidate, 1);
label = strings(n_candidate, 1);
alpha = zeros(n_candidate, 1);
center_hz = zeros(n_candidate, 1);
depth = zeros(n_candidate, 1);
zeta_pole = zeros(n_candidate, 1);
min_ncf = zeros(n_candidate, 1);
min_gm_db = zeros(n_candidate, 1);
max_abs_pole = zeros(n_candidate, 1);
feasible = false(n_candidate, 1);
margin_score = zeros(n_candidate, 1);
worst_ncf_case = strings(n_candidate, 1);
for i = 1:n_candidate
    candidate = candidates(i);
    [case_table, pole_table] = evaluateCandidateMargins(context, ...
        damage_cases, candidate);
    [min_ncf(i), ncf_index] = min(case_table.NCF);
    min_gm_db(i) = min(case_table.GM_dB);
    max_abs_pole(i) = max(pole_table.MaxAbsPole);
    candidate_id(i) = candidate.Id;
    label(i) = candidate.Label;
    alpha(i) = candidate.Alpha;
    center_hz(i) = candidate.CenterHz;
    depth(i) = candidate.Depth;
    zeta_pole(i) = candidate.ZetaPole;
    feasible(i) = min_ncf(i) >= config.ncf_preferred_target ...
        && min_gm_db(i) >= config.gm_target_db ...
        && max_abs_pole(i) < 1;
    margin_score(i) = marginScore(min_ncf(i), min_gm_db(i), ...
        max_abs_pole(i), candidate, config);
    worst_ncf_case(i) = case_table.Case(ncf_index);
end
margin_table = table(candidate_id, label, alpha, center_hz, depth, ...
    zeta_pole, min_ncf, min_gm_db, max_abs_pole, feasible, ...
    margin_score, worst_ncf_case, ...
    'VariableNames', {'CandidateId', 'Label', 'Alpha', 'CenterHz', ...
    'Depth', 'ZetaPole', 'MinNCF', 'MinGM_dB', 'MaxAbsPole', ...
    'Feasible', 'MarginScore', 'WorstNCFCase'});
end

function score = marginScore(min_ncf, min_gm_db, max_abs_pole, ...
        candidate, config)
ncf_shortfall = max(0, config.ncf_preferred_target - min_ncf);
gm_shortfall = max(0, config.gm_target_db - min_gm_db);
pole_shortfall = max(0, max_abs_pole - config.pole_target);
authority_penalty = 2.5*(1 - candidate.Alpha)^2;
score = 3000*ncf_shortfall^2 + 20*gm_shortfall^2 ...
    + 1e5*pole_shortfall^2 - 2*min_ncf + authority_penalty;
end

function [case_table, pole_table] = evaluateCandidateMargins(context, ...
        damage_cases, candidate)
n_case = numel(damage_cases);
case_name = strings(n_case, 1);
gm_db = zeros(n_case, 1);
pm_deg = zeros(n_case, 1);
ncf_margin = zeros(n_case, 1);
pole_case = strings(0, 1);
max_abs_pole = zeros(0, 1);
for case_id = 1:n_case
    damage_case = damage_cases(case_id);
    loop_response = coupledLoopResponse(context, damage_case, candidate);
    [gm_db(case_id), pm_deg(case_id), ncf_margin(case_id)] = ...
        stabilityMarginsFromResponse(loop_response);
    case_name(case_id) = damage_case.Name;
    if damage_case.UseTimeDomain
        stability = coupledPoleStability(context, damage_case, candidate);
        pole_case(end+1, 1) = damage_case.Name; %#ok<AGROW>
        max_abs_pole(end+1, 1) = stability.coupled_max_abs_pole; %#ok<AGROW>
    end
end
case_table = table(case_name, gm_db, pm_deg, ncf_margin, ...
    'VariableNames', {'Case', 'GM_dB', 'PM_deg', 'NCF'});
pole_table = table(pole_case, max_abs_pole, ...
    'VariableNames', {'Case', 'MaxAbsPole'});
end

function loop_response = coupledLoopResponse(context, damage_case, candidate)
controller_plant = context.controller_response.*damage_case.H_response;
PID_H_response = controller_plant./(1 + controller_plant);
loop_response = -context.num_response*(damage_case.k/1000) ...
    .*candidate.G_response.*PID_H_response;
loop_response = loop_response(:);
end

function stability = coupledPoleStability(context, damage_case, candidate)
PID_H = feedback(context.controller*damage_case.H_tf, 1);
actuator = discreteSiso(PID_H, context.dt);
notch_filter = discreteSiso(candidate.G_tf, context.dt);
stability = analyzeActuatorLoop(context.num_model, actuator, notch_filter, ...
    damage_case.k, context.dt);
end

function time_table = evaluateTimeDomainCandidates(context, damage_cases, ...
        candidates, candidate_ids)
time_cases = damage_cases([damage_cases.UseTimeDomain]);
n_row = numel(candidate_ids)*numel(time_cases);
candidate_id = zeros(n_row, 1);
case_name = strings(n_row, 1);
j4_percent = zeros(n_row, 1);
response_nrmse_percent = zeros(n_row, 1);
tracking_nrmse_percent = zeros(n_row, 1);
peak_command_ratio = zeros(n_row, 1);
max_abs_pole = zeros(n_row, 1);
stable = false(n_row, 1);
row = 0;
fprintf('\nFull-record time-domain verification for %d candidates x %d cases\n', ...
    numel(candidate_ids), numel(time_cases))
for candidate_index = 1:numel(candidate_ids)
    candidate = candidates(candidate_ids(candidate_index));
    fprintf('  candidate %d/%d: %s\n', candidate_index, ...
        numel(candidate_ids), candidate.Label)
    for case_id = 1:numel(time_cases)
        row = row + 1;
        metrics = simulateVhsCase(context, time_cases(case_id), candidate);
        candidate_id(row) = candidate.Id;
        case_name(row) = time_cases(case_id).Name;
        j4_percent(row) = metrics.j4_percent;
        response_nrmse_percent(row) = metrics.response_nrmse_percent;
        tracking_nrmse_percent(row) = metrics.tracking_nrmse_percent;
        peak_command_ratio(row) = metrics.peak_command_ratio;
        max_abs_pole(row) = metrics.max_abs_pole;
        stable(row) = metrics.stable;
    end
end
time_table = table(candidate_id, case_name, j4_percent, ...
    response_nrmse_percent, tracking_nrmse_percent, peak_command_ratio, ...
    max_abs_pole, stable, ...
    'VariableNames', {'CandidateId', 'Case', 'J4_percent', ...
    'ResponseNRMSE_percent', 'TrackingNRMSE_percent', ...
    'PeakCommandRatio', 'MaxAbsPole', 'Stable'});
end

function metrics = simulateVhsCase(context, damage_case, candidate)
num_model = context.num_model;
PID_H = feedback(context.controller*damage_case.H_tf, 1);
actuator = discreteSiso(PID_H, context.dt);
notch_filter = discreteSiso(candidate.G_tf, context.dt);
controller = discreteSiso(context.controller, context.dt);
stability = analyzeActuatorLoop(num_model, actuator, notch_filter, ...
    damage_case.k, context.dt);

n_step = numel(context.sample_time);
u_num_floors_sample = zeros(n_step, context.hs.n_floor);
dd_sample = zeros(n_step, 1);
dd_notch_sample = zeros(n_step, 1);
dm_sample = zeros(n_step, 1);
x_num = zeros(size(num_model.A, 1), 1);
k_mm = damage_case.k/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*notch_filter.D;
for step = 2:n_step
    dd_sample(step) = (num_model.C*x_num ...
        + num_model.D_fm*k_mm*actuator.D*notch_filter.C*notch_filter.x ...
        + num_model.D_fm*k_mm*actuator.C*actuator.x ...
        + num_model.D_ag*context.ag_sample(step))/denominator;
    dd_notch_sample(step) = outputDiscreteSiso(notch_filter, dd_sample(step));
    dm_sample(step) = outputDiscreteSiso(actuator, dd_notch_sample(step));
    force_sample = k_mm*dm_sample(step);
    controller_output = outputDiscreteSiso(controller, ...
        dd_notch_sample(step) - dm_sample(step)); %#ok<NASGU>
    x_num = num_model.A*x_num + num_model.B_fm*force_sample ...
        + num_model.B_ag*context.ag_sample(step);
    notch_filter = updateDiscreteSiso(notch_filter, dd_sample(step));
    actuator = updateDiscreteSiso(actuator, dd_notch_sample(step));
    controller = updateDiscreteSiso(controller, ...
        dd_notch_sample(step) - dm_sample(step));
    u_num_floors_sample(step, :) = x_num(1:context.hs.n_floor)';
end
response_error = u_num_floors_sample - context.u_reference_sample;
metrics = struct( ...
    'j4_percent', 100*std(u_num_floors_sample(:, 1) ...
        - context.u_reference_sample(:, 1)) ...
        /max(std(context.u_reference_sample(:, 1)), eps), ...
    'response_nrmse_percent', 100*localRms(response_error) ...
        /max(localRms(context.u_reference_sample), eps), ...
    'tracking_nrmse_percent', 100*localRms(dd_notch_sample - dm_sample) ...
        /max(localRms(dd_notch_sample), eps), ...
    'peak_command_ratio', max(abs(dd_notch_sample)) ...
        /max(max(abs(dd_sample)), eps), ...
    'max_abs_pole', stability.coupled_max_abs_pole, ...
    'stable', stability.coupled_stable);
end

function summary_table = combineMarginAndTime(margin_table, time_table, config)
summary_table = margin_table;
n_row = height(summary_table);
max_j4 = inf(n_row, 1);
max_response_nrmse = inf(n_row, 1);
max_tracking_nrmse = inf(n_row, 1);
max_peak_command = inf(n_row, 1);
time_stable = false(n_row, 1);
final_score = inf(n_row, 1);
for row = 1:n_row
    mask = time_table.CandidateId == summary_table.CandidateId(row);
    if ~any(mask)
        continue
    end
    max_j4(row) = max(time_table.J4_percent(mask));
    max_response_nrmse(row) = max(time_table.ResponseNRMSE_percent(mask));
    max_tracking_nrmse(row) = max(time_table.TrackingNRMSE_percent(mask));
    max_peak_command(row) = max(time_table.PeakCommandRatio(mask));
    time_stable(row) = all(time_table.Stable(mask));
    final_score(row) = max_j4(row) ...
        + 0.15*max_response_nrmse(row) ...
        + 0.02*max_tracking_nrmse(row) ...
        + summary_table.MarginScore(row) ...
        + 80*max(0, max_peak_command(row) ...
            - config.command_ratio_limit)^2;
end
summary_table.MaxJ4_percent = max_j4;
summary_table.MaxResponseNRMSE_percent = max_response_nrmse;
summary_table.MaxTrackingNRMSE_percent = max_tracking_nrmse;
summary_table.MaxPeakCommandRatio = max_peak_command;
summary_table.TimeStable = time_stable;
summary_table.FinalScore = final_score;
end

function model = forceDiscrete(model, sample_time, method)
if nargin < 3
    method = 'zoh';
end
if get(model, 'Ts') == 0
    model = c2d(model, sample_time, method);
elseif abs(get(model, 'Ts') - sample_time) > 10*eps(sample_time)
    model = d2d(model, sample_time, method);
end
end

function model = numericalSubstructureDiscrete(hs, sample_time)
n = hs.n_floor;
h = sample_time;
beta = 1/4;
gamma = 1/2;
a0 = 1/(beta*h^2);
a1 = gamma/(beta*h);
a2 = 1/(beta*h);
a3 = 1/(2*beta)-1;
a4 = gamma/beta-1;
a5 = h*(gamma/(2*beta)-1);
effective_stiffness = hs.K + a0*hs.M + a1*hs.C;
solver = effective_stiffness\eye(n);
state_to_displacement = solver * [a0*hs.M + a1*hs.C, ...
    a2*hs.M + a4*hs.C, a3*hs.M + a5*hs.C];
force_to_displacement = solver*(hs.force_to_floor*hs.force_sign);
ag_to_displacement = solver*hs.ground_force_gain;
model.A = zeros(3*n);
model.B_fm = zeros(3*n, 1);
model.B_ag = zeros(3*n, 1);
model.A(1:n, :) = state_to_displacement;
model.B_fm(1:n) = force_to_displacement;
model.B_ag(1:n) = ag_to_displacement;
model.A(2*n+1:3*n, :) = a0*(state_to_displacement ...
    - [eye(n), zeros(n), zeros(n)]) ...
    - a2*[zeros(n), eye(n), zeros(n)] ...
    - a3*[zeros(n), zeros(n), eye(n)];
model.B_fm(2*n+1:3*n) = a0*force_to_displacement;
model.B_ag(2*n+1:3*n) = a0*ag_to_displacement;
model.A(n+1:2*n, :) = [zeros(n), eye(n), zeros(n)] ...
    + h*((1-gamma)*[zeros(n), zeros(n), eye(n)] ...
    + gamma*model.A(2*n+1:3*n, :));
model.B_fm(n+1:2*n) = h*gamma*model.B_fm(2*n+1:3*n);
model.B_ag(n+1:2*n) = h*gamma*model.B_ag(2*n+1:3*n);
model.C = 1000*(hs.interface_from_floor*state_to_displacement);
model.D_fm = 1000*(hs.interface_from_floor*force_to_displacement ...
    + hs.interface_from_force*hs.force_sign);
model.D_ag = 1000*(hs.interface_from_floor*ag_to_displacement);
end

function stability = analyzeActuatorLoop(num_model, actuator, notch_filter, ...
        k_experimental, sample_time)
k_mm = k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*notch_filter.D;
dd_from_num = num_model.C/denominator;
dd_from_notch = num_model.D_fm*k_mm*actuator.D*notch_filter.C ...
    /denominator;
dd_from_actuator = num_model.D_fm*k_mm*actuator.C/denominator;
dd_notch_from_num = notch_filter.D*dd_from_num;
dd_notch_from_notch = notch_filter.C + notch_filter.D*dd_from_notch;
dd_notch_from_actuator = notch_filter.D*dd_from_actuator;
force_from_num = k_mm*actuator.D*dd_notch_from_num;
force_from_notch = k_mm*actuator.D*dd_notch_from_notch;
force_from_actuator = k_mm*(actuator.C ...
    + actuator.D*dd_notch_from_actuator);
closed_loop_A = [ ...
    num_model.A + num_model.B_fm*force_from_num, ...
    num_model.B_fm*force_from_notch, ...
    num_model.B_fm*force_from_actuator; ...
    notch_filter.B*dd_from_num, ...
    notch_filter.A + notch_filter.B*dd_from_notch, ...
    notch_filter.B*dd_from_actuator; ...
    actuator.B*dd_notch_from_num, ...
    actuator.B*dd_notch_from_notch, ...
    actuator.A + actuator.B*dd_notch_from_actuator];
closed_loop_poles = eig(closed_loop_A);
[coupled_max_abs_pole, dominant_index] = max(abs(closed_loop_poles));
stability.coupled_max_abs_pole = coupled_max_abs_pole;
stability.coupled_stable = coupled_max_abs_pole < 1;
stability.dominant_pole = closed_loop_poles(dominant_index);
stability.dominant_frequency_hz = abs(angle(stability.dominant_pole)) ...
    /(2*pi*sample_time);
end

function system = discreteSiso(system_model, sample_time)
system_model = forceDiscrete(system_model, sample_time);
system_model = ss(system_model);
[system.A, system.B, system.C, system.D] = ssdata(system_model);
system.x = zeros(size(system.A, 1), 1);
system.u = 0;
end

function y = outputDiscreteSiso(system, u)
y = system.C*system.x + system.D*u;
y = y(1);
end

function system = updateDiscreteSiso(system, u)
system.x = system.A*system.x + system.B*u;
system.u = u;
end

function [gain_margin_db, phase_margin_deg, ncf_margin] = ...
        stabilityMarginsFromResponse(response)
response = response(:);
imag_response = imag(response);
phase_crossings = find(imag_response(1:end-1).*imag_response(2:end) <= 0);
gain_candidates = [];
for i = phase_crossings.'
    denominator = imag_response(i+1) - imag_response(i);
    if abs(denominator) <= eps
        continue
    end
    fraction = -imag_response(i)/denominator;
    crossing_response = response(i) + fraction*(response(i+1) - response(i));
    if real(crossing_response) < 0
        candidate = 1/abs(crossing_response);
        if candidate >= 1
            gain_candidates(end+1, 1) = candidate; %#ok<AGROW>
        end
    end
end
gain_margin_db = 20*log10(min([gain_candidates; Inf]));

log_magnitude = log(abs(response));
gain_crossings = find(log_magnitude(1:end-1).*log_magnitude(2:end) <= 0);
phase_deg = unwrap(angle(response))*180/pi;
phase_candidates = [];
for i = gain_crossings.'
    denominator = log_magnitude(i+1) - log_magnitude(i);
    if abs(denominator) <= eps
        continue
    end
    fraction = -log_magnitude(i)/denominator;
    crossing_phase = phase_deg(i) + fraction*(phase_deg(i+1) - phase_deg(i));
    candidate = mod(180 + crossing_phase + 180, 360) - 180;
    if candidate > 0
        phase_candidates(end+1, 1) = candidate; %#ok<AGROW>
    end
end
phase_margin_deg = min([phase_candidates; Inf]);
ncf_margin = min(abs(1 + response) ./ sqrt(2*(1 + abs(response).^2)));
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

function frequency_hz = referenceModeFrequencies(fem_ref)
frequency_hz = modeFrequencies(fem_ref.K, fem_ref.M);
end

function frequency_hz = condensedModeFrequencies(fem_num)
floor_dofs = fem_num.floor_dofs(:)';
interface_dof = fem_num.interface_dof;
K = fem_num.K;
K_ff = K(floor_dofs, floor_dofs);
K_fi = K(floor_dofs, interface_dof);
K_if = K(interface_dof, floor_dofs);
K_ii = K(interface_dof, interface_dof);
K_condensed = K_ff - K_fi*(K_ii\K_if);
M_condensed = fem_num.M(floor_dofs, floor_dofs);
frequency_hz = modeFrequencies(K_condensed, M_condensed);
end

function frequency_hz = modeFrequencies(K, M)
[~, eigenvalue_matrix] = eig(K, M);
omega = sqrt(real(diag(eigenvalue_matrix)));
frequency_hz = sort(omega(isfinite(omega) & omega > 1e-6)/(2*pi));
frequency_hz = frequency_hz(:).';
end

function value = localRms(x)
x = x(:);
value = sqrt(mean(abs(x).^2));
end

function text = numericVectorText(values)
parts = arrayfun(@(value) sprintf('%.4g', value), values(:).', ...
    'UniformOutput', false);
text = strjoin(parts, ', ');
end

function writeMarkdownReport(report_file, result)
fid = fopen(report_file, 'w');
cleanup = onCleanup(@() fclose(fid));
summary = result.summary_table;
verified = summary(isfinite(summary.MaxJ4_percent), :);
verified = sortrows(verified, 'FinalScore', 'ascend');
notch_only = verified(abs(verified.Alpha - 1) < 1e-12 ...
    & contains(verified.Label, 'notch '), :);
notch_alpha = verified(contains(verified.Label, 'notch '), :);
fprintf(fid, '# Notch filter study report\n\n');
fprintf(fid, 'Generated by `notch_filter_study.m`.\n\n');
fprintf(fid, '## Setup\n\n');
fprintf(fid, '- Numerical-substructure modes: `%s Hz`.\n', ...
    numericVectorText(result.context_summary.num_mode_frequency_hz));
fprintf(fid, '- Reference FEM modes: `%s Hz`.\n', ...
    numericVectorText(result.context_summary.ref_mode_frequency_hz));
fprintf(fid, '- Damage scalar fit: `H_damaged ~= %.6g * H_healthy`.\n\n', ...
    result.context_summary.gamma_fit);
fprintf(fid, '## Best verified candidates\n\n');
writeCandidateTable(fid, verified(1:min(18, height(verified)), :))
fprintf(fid, '\n## Best notch-only candidates (`alpha = 1`)\n\n');
writeCandidateTable(fid, notch_only(1:min(12, height(notch_only)), :))
fprintf(fid, '\n## Best notch candidates including authority scaling\n\n');
writeCandidateTable(fid, notch_alpha(1:min(12, height(notch_alpha)), :))
fprintf(fid, '\n## Interpretation\n\n');
fprintf(fid, ['A notch can target the dangerous band without suppressing all ' ...
    'frequencies, but in this sweep the notch by itself did not clear the ' ...
    '`NCF >= 0.35` robust target. The best verified candidates still use ' ...
    'authority reduction (`alpha < 1`).\n']);
end

function writeCandidateTable(fid, table_data)
fprintf(fid, ['| Id | Label | min NCF | min GM dB | max pole | max J4 %% | ' ...
    'max command ratio | final score | worst NCF case |\n']);
fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---:|---|\n');
for row = 1:height(table_data)
    fprintf(fid, ...
        '| %d | %s | %.4f | %.3f | %.6f | %.3f | %.3f | %.3f | %s |\n', ...
        table_data.CandidateId(row), markdownEscape(table_data.Label(row)), ...
        table_data.MinNCF(row), table_data.MinGM_dB(row), ...
        table_data.MaxAbsPole(row), table_data.MaxJ4_percent(row), ...
        table_data.MaxPeakCommandRatio(row), table_data.FinalScore(row), ...
        markdownEscape(table_data.WorstNCFCase(row)));
end
end

function text = markdownEscape(value)
text = char(string(value));
text = strrep(text, '|', '\|');
end

function plotSummary(plot_file, result)
summary = result.summary_table;
verified = summary(isfinite(summary.MaxJ4_percent), :);
fig = figure('Color', 'w', 'Visible', 'off', 'Name', 'Notch study summary');
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
scatter(ax, verified.MinNCF, verified.MaxJ4_percent, 36, ...
    verified.Alpha, 'filled');
grid(ax, 'on')
xline(ax, result.config.ncf_preferred_target, ':');
xlabel(ax, 'Worst-case NCF')
ylabel(ax, 'Max J4 over time cases (%)')
title(ax, 'Verified notch candidates')
colorbar(ax)
ax = nexttile;
notch_only = verified(abs(verified.Alpha - 1) < 1e-12 ...
    & contains(verified.Label, 'notch '), :);
scatter(ax, notch_only.CenterHz, notch_only.MinNCF, 40, ...
    notch_only.Depth, 'filled');
grid(ax, 'on')
yline(ax, result.config.ncf_preferred_target, ':');
xlabel(ax, 'Notch center (Hz)')
ylabel(ax, 'Worst-case NCF')
title(ax, 'Notch-only margin')
colorbar(ax)
saveas(fig, plot_file)
close(fig)
end
