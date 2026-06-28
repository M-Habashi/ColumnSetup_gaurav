%% Robust vHS Phase-Lead Optimization Across Damage States
% This script is intentionally self-contained under research/optimizing_pl/codex.
% It does not modify the production optimizer. It searches phase-lead and
% safety-attenuation candidates against a healthy/damaged/further-damaged
% ensemble, then runs full-record time-domain checks on the strongest candidates.

clear; clc; close all;

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(fileparts(script_dir)));
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', 'id_utils'));
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', ...
    'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
addpath(fullfile(project_root, 'results_analysis'));

config = defaultConfig();
context = buildContext(project_root, config);
damage_cases = buildDamageCases(context, config);
candidates = buildCandidateSet(context, config);

fprintf('\nRobust vHS phase-lead search\n')
fprintf('Candidate count: %d\n', numel(candidates))
fprintf('Damage case count: %d\n', numel(damage_cases))

margin_table = evaluateMarginGrid(context, damage_cases, candidates, config);
margin_table = sortrows(margin_table, 'MarginScore', 'ascend');
top_candidate_ids = margin_table.CandidateId( ...
    1:min(config.time_domain_candidate_count, height(margin_table)));
top_candidate_ids = unique([1; top_candidate_ids(:); ...
    forcedTimeDomainCandidateIds(candidates)], 'stable');

time_table = evaluateTimeDomainCandidates(context, damage_cases, ...
    candidates, top_candidate_ids, config);
summary_table = combineMarginAndTime(margin_table, time_table, config);
summary_table = sortrows(summary_table, 'FinalScore', 'ascend');

best_candidate = candidates(summary_table.CandidateId(1));
safety_table = evaluateSafetySchedule(context, damage_cases, best_candidate, ...
    config);

result = struct( ...
    'config', config, ...
    'context_summary', context.summary, ...
    'damage_cases', damage_cases, ...
    'best_candidate', best_candidate, ...
    'margin_table', margin_table, ...
    'time_table', time_table, ...
    'summary_table', summary_table, ...
    'safety_table', safety_table);

result_file = fullfile(script_dir, 'robust_vhs_phase_lead_result.mat');
save(result_file, 'result')

report_file = fullfile(script_dir, 'robust_vhs_phase_lead_report.md');
writeMarkdownReport(report_file, result)
plot_file = fullfile(script_dir, 'robust_vhs_phase_lead_summary.png');
plotSummary(plot_file, summary_table, safety_table, config)

fprintf('\nBest candidate\n')
printCandidate(best_candidate)
disp(summary_table(1:min(12, height(summary_table)), ...
    {'CandidateId', 'Label', 'Alpha', 'CenterHz', 'Ratio', 'MinNCF', ...
    'MinGM_dB', 'MaxAbsPole', 'MaxJ4_percent', 'FinalScore', ...
    'WorstNCFCase'}))
fprintf('Saved result: %s\n', result_file)
fprintf('Saved report: %s\n', report_file)
fprintf('Saved plot:   %s\n', plot_file)

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
    'ncf_hard_target', 0.30, ...
    'ncf_preferred_target', 0.35, ...
    'gm_hard_target_db', 7.0, ...
    'pole_hard_target', 0.99995, ...
    'command_ratio_limit', 1.25, ...
    'min_k_ratio', 0.50, ...
    'grid_center_hz', [0.75 1 1.5 2 3 4 6 8 12 18 27 40 60], ...
    'grid_ratio', [1 1.05 1.1 1.2 1.5 2 3 5 8 12], ...
    'grid_alpha', [1.0 0.95 0.9 0.85 0.8 0.7 0.6], ...
    'lowpass_cutoff_mode_factors', [1.1 1.25 1.5 2.0 2.5 3.0], ...
    'lowpass_orders', [1 2], ...
    'time_domain_candidate_count', 28, ...
    'safety_alpha_grid', linspace(1, 0.05, 20), ...
    'report_top_count', 15);
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
    'healthy_tf_file', healthy_tf_file, ...
    'damaged_tf_file', damaged_tf_file, ...
    'healthy_specimen_file', healthy_specimen_file, ...
    'damaged_specimen_file', damaged_specimen_file, ...
    'fem_file', fem_file, ...
    'H_healthy', H_healthy, ...
    'H_damaged', H_damaged, ...
    'Hh_response', Hh_response, ...
    'Hd_response', Hd_response, ...
    'damage_ratio_response', Hd_response./Hh_response, ...
    'controller', controller, ...
    'controller_response', controller_response, ...
    'pid_values', pid_values, ...
    'fem', fem, ...
    'hs', hs, ...
    'num_model', num_model, ...
    'num_tf', num_tf, ...
    'num_response', num_response, ...
    'sample_time', sample_time, ...
    'ag_sample', ag_sample, ...
    'u_reference_sample', u_reference_sample(:, 1:hs.n_floor), ...
    'k_healthy', specimen_healthy_si.stiffness, ...
    'k_damaged', specimen_damaged_si.stiffness, ...
    'summary', struct( ...
        'gamma_fit', gamma_fit, ...
        'fit_error_percent', fit_error_percent, ...
        'ref_mode_frequency_hz', referenceModeFrequencies(fem.ref), ...
        'num_mode_frequency_hz', condensedModeFrequencies(fem.num), ...
        'healthy_stiffness_N_per_m', specimen_healthy_si.stiffness, ...
        'damaged_stiffness_N_per_m', specimen_damaged_si.stiffness, ...
        'damaged_to_healthy_k_ratio', ...
            specimen_damaged_si.stiffness/specimen_healthy_si.stiffness));
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

function candidates = buildCandidateSet(context, config)
candidates = emptyCandidateStruct();
candidate_id = 0;

candidate_id = candidate_id + 1;
candidates(candidate_id) = makeCandidate(candidate_id, 'no lead', ...
    1, NaN, 1, context, config);

for alpha_id = 1:numel(config.grid_alpha)
    alpha = config.grid_alpha(alpha_id);
    if alpha < 1
        candidate_id = candidate_id + 1;
        candidates(candidate_id) = makeCandidate(candidate_id, ...
            sprintf('attenuation %.3g', alpha), alpha, NaN, 1, ...
            context, config);
    end
    for center_id = 1:numel(config.grid_center_hz)
        for ratio_id = 1:numel(config.grid_ratio)
            ratio = config.grid_ratio(ratio_id);
            if ratio <= 1 && alpha == 1
                continue
            end
            candidate_id = candidate_id + 1;
            candidates(candidate_id) = makeCandidate(candidate_id, ...
                sprintf('alpha %.3g, lead %.3g Hz x %.3g', alpha, ...
                config.grid_center_hz(center_id), ratio), alpha, ...
                config.grid_center_hz(center_id), ratio, context, config);
        end
    end
end
candidates = appendSavedLeadCandidates(candidates, context, config);
candidates = appendLowPassCandidates(candidates, context, config);
end

function candidates = emptyCandidateStruct()
candidates = struct('Id', {}, 'Label', {}, 'Alpha', {}, 'CenterHz', {}, ...
    'Ratio', {}, 'ZeroHz', {}, 'PoleHz', {}, 'Gain', {}, ...
    'G_tf', {}, 'G_response', {});
end

function candidate = makeCandidate(id, label, alpha, center_hz, ratio, ...
        context, config)
if isnan(center_hz) || ratio <= 1
    G_tf = tf(alpha, 1, config.sample_dt);
    zero_hz = NaN;
    pole_hz = NaN;
    gain = alpha;
else
    zero_hz = center_hz/sqrt(ratio);
    pole_hz = center_hz*sqrt(ratio);
    gain = alpha*ratio;
    continuous_filter = gain ...
        * tf(poly(-2*pi*zero_hz), poly(-2*pi*pole_hz));
    G_tf = c2d(continuous_filter, config.sample_dt, 'tustin');
end
G_response = squeeze(freqresp(G_tf, context.freq_rad_s));
candidate = struct( ...
    'Id', id, ...
    'Label', string(label), ...
    'Alpha', alpha, ...
    'CenterHz', center_hz, ...
    'Ratio', ratio, ...
    'ZeroHz', zero_hz, ...
    'PoleHz', pole_hz, ...
    'Gain', gain, ...
    'G_tf', G_tf, ...
    'G_response', G_response(:));
end

function candidates = appendSavedLeadCandidates(candidates, context, config)
saved_names = {'pl_sp1_5000.mat', 'pl_sp1_7000.mat'};
for file_id = 1:numel(saved_names)
    saved_file = fullfile(context.project_root, 'saved_results', ...
        'delay_comp', saved_names{file_id});
    if ~isfile(saved_file)
        continue
    end
    data = load(saved_file, 'delay_comp_tf');
    for alpha_id = 1:numel(config.grid_alpha)
        alpha = config.grid_alpha(alpha_id);
        next_id = numel(candidates) + 1;
        label = sprintf('saved %s alpha %.3g', ...
            saved_names{file_id}, alpha);
        candidates(next_id) = makeCandidateFromLeadTf(next_id, label, ...
            alpha, data.delay_comp_tf, context, config);
    end
end
end

function candidates = appendLowPassCandidates(candidates, context, config)
highest_mode_hz = max(context.summary.num_mode_frequency_hz);
for order_id = 1:numel(config.lowpass_orders)
    order = config.lowpass_orders(order_id);
    for factor_id = 1:numel(config.lowpass_cutoff_mode_factors)
        factor = config.lowpass_cutoff_mode_factors(factor_id);
        cutoff_hz = factor*highest_mode_hz;
        next_id = numel(candidates) + 1;
        label = sprintf('lowpass order %d fc %.4g Hz (%.2gx mode)', ...
            order, cutoff_hz, factor);
        candidates(next_id) = makeCandidateFromLowPass(next_id, label, ...
            order, cutoff_hz, context, config);
    end
end
end

function candidate = makeCandidateFromLowPass(id, label, order, cutoff_hz, ...
        context, config)
wc = 2*pi*cutoff_hz;
if order == 1
    continuous_filter = tf(wc, [1 wc]);
elseif order == 2
    continuous_filter = tf(wc^2, [1 sqrt(2)*wc wc^2]);
else
    error('Unsupported low-pass order %d.', order)
end
G_tf = forceLeadDiscrete(continuous_filter, config.sample_dt);
G_response = squeeze(freqresp(G_tf, context.freq_rad_s));
candidate = struct( ...
    'Id', id, ...
    'Label', string(label), ...
    'Alpha', 1, ...
    'CenterHz', cutoff_hz, ...
    'Ratio', NaN, ...
    'ZeroHz', NaN, ...
    'PoleHz', NaN, ...
    'Gain', dcgain(G_tf), ...
    'G_tf', G_tf, ...
    'G_response', G_response(:));
end

function candidate = makeCandidateFromLeadTf(id, label, alpha, lead_tf, ...
        context, config)
G_tf = forceLeadDiscrete(alpha*lead_tf, config.sample_dt);
G_response = squeeze(freqresp(G_tf, context.freq_rad_s));
candidate = struct( ...
    'Id', id, ...
    'Label', string(label), ...
    'Alpha', alpha, ...
    'CenterHz', NaN, ...
    'Ratio', NaN, ...
    'ZeroHz', NaN, ...
    'PoleHz', NaN, ...
    'Gain', dcgain(G_tf), ...
    'G_tf', G_tf, ...
    'G_response', G_response(:));
end

function candidate_ids = forcedTimeDomainCandidateIds(candidates)
candidate_ids = [];
for candidate_id = 1:numel(candidates)
    label = candidates(candidate_id).Label;
    alpha = candidates(candidate_id).Alpha;
    is_saved = contains(label, 'saved ');
    is_lowpass = contains(label, 'lowpass ');
    is_key_alpha = abs(alpha - 1) < 1e-12 || abs(alpha - 0.6) < 1e-12;
    if (is_saved && is_key_alpha) || is_lowpass
        candidate_ids(end+1, 1) = candidates(candidate_id).Id; %#ok<AGROW>
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
ratio = zeros(n_candidate, 1);
min_ncf = zeros(n_candidate, 1);
min_gm_db = zeros(n_candidate, 1);
max_abs_pole = zeros(n_candidate, 1);
margin_score = zeros(n_candidate, 1);
feasible = false(n_candidate, 1);
worst_ncf_case = strings(n_candidate, 1);
worst_gm_case = strings(n_candidate, 1);
worst_pole_case = strings(n_candidate, 1);

for i = 1:n_candidate
    candidate = candidates(i);
    [case_table, pole_table] = evaluateCandidateMargins(context, ...
        damage_cases, candidate);
    [min_ncf(i), ncf_index] = min(case_table.NCF);
    [min_gm_db(i), gm_index] = min(case_table.GM_dB);
    if isempty(pole_table)
        max_abs_pole(i) = NaN;
        worst_pole_case(i) = "";
    else
        [max_abs_pole(i), pole_index] = max(pole_table.MaxAbsPole);
        worst_pole_case(i) = pole_table.Case(pole_index);
    end
    candidate_id(i) = candidate.Id;
    label(i) = candidate.Label;
    alpha(i) = candidate.Alpha;
    center_hz(i) = candidate.CenterHz;
    ratio(i) = candidate.Ratio;
    worst_ncf_case(i) = case_table.Case(ncf_index);
    worst_gm_case(i) = case_table.Case(gm_index);
    feasible(i) = min_ncf(i) >= config.ncf_hard_target ...
        && min_gm_db(i) >= config.gm_hard_target_db ...
        && (isnan(max_abs_pole(i)) ...
            || max_abs_pole(i) <= config.pole_hard_target);
    margin_score(i) = robustMarginScore(min_ncf(i), min_gm_db(i), ...
        max_abs_pole(i), candidate, config);
end

margin_table = table(candidate_id, label, alpha, center_hz, ratio, ...
    min_ncf, min_gm_db, max_abs_pole, feasible, margin_score, ...
    worst_ncf_case, worst_gm_case, worst_pole_case, ...
    'VariableNames', {'CandidateId', 'Label', 'Alpha', 'CenterHz', ...
    'Ratio', 'MinNCF', 'MinGM_dB', 'MaxAbsPole', 'Feasible', ...
    'MarginScore', 'WorstNCFCase', 'WorstGMCase', 'WorstPoleCase'});
end

function score = robustMarginScore(min_ncf, min_gm_db, max_abs_pole, ...
        candidate, config)
ncf_shortfall = max(0, config.ncf_preferred_target - min_ncf);
gm_shortfall = max(0, config.gm_hard_target_db - min_gm_db);
if isnan(max_abs_pole)
    pole_shortfall = 0;
else
    pole_shortfall = max(0, max_abs_pole - config.pole_hard_target);
end
attenuation_penalty = 2.5*(1 - candidate.Alpha)^2;
ratio_penalty = 0.002*max(0, candidate.Ratio - 1);
score = 3000*ncf_shortfall^2 + 20*gm_shortfall^2 ...
    + 1e5*pole_shortfall^2 - 2*min_ncf ...
    + attenuation_penalty + ratio_penalty;
end

function [case_table, pole_table] = evaluateCandidateMargins(context, ...
        damage_cases, candidate)
n_case = numel(damage_cases);
case_name = strings(n_case, 1);
gm_db = zeros(n_case, 1);
pm_deg = zeros(n_case, 1);
ncf_margin = zeros(n_case, 1);
for case_id = 1:n_case
    damage_case = damage_cases(case_id);
    loop_response = coupledLoopResponse(context, damage_case, candidate);
    [gm_db(case_id), pm_deg(case_id), ncf_margin(case_id)] = ...
        stabilityMarginsFromResponse(loop_response);
    case_name(case_id) = damage_case.Name;
end
case_table = table(case_name, gm_db, pm_deg, ncf_margin, ...
    'VariableNames', {'Case', 'GM_dB', 'PM_deg', 'NCF'});

pole_case = strings(0, 1);
max_abs_pole = zeros(0, 1);
for case_id = 1:n_case
    damage_case = damage_cases(case_id);
    if ~damage_case.UseTimeDomain
        continue
    end
    stability = coupledPoleStability(context, damage_case, candidate);
    pole_case(end+1, 1) = damage_case.Name; %#ok<AGROW>
    max_abs_pole(end+1, 1) = stability.coupled_max_abs_pole; %#ok<AGROW>
end
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
lead_filter = discreteSiso(candidate.G_tf, context.dt);
stability = analyzeActuatorLoop(context.num_model, actuator, lead_filter, ...
    damage_case.k, context.dt);
end

function time_table = evaluateTimeDomainCandidates(context, damage_cases, ...
        candidates, candidate_ids, config)
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
lead_filter = discreteSiso(candidate.G_tf, context.dt);
controller = discreteSiso(context.controller, context.dt);
stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
    damage_case.k, context.dt);

n_step = numel(context.sample_time);
u_num_floors_sample = zeros(n_step, context.hs.n_floor);
dd_sample = zeros(n_step, 1);
dd_lead_sample = zeros(n_step, 1);
dm_sample = zeros(n_step, 1);
dc_sample = zeros(n_step, 1);
x_num = zeros(size(num_model.A, 1), 1);
k_mm = damage_case.k/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;

for step = 2:n_step
    dd_sample(step) = (num_model.C*x_num ...
        + num_model.D_fm*k_mm*actuator.D*lead_filter.C*lead_filter.x ...
        + num_model.D_fm*k_mm*actuator.C*actuator.x ...
        + num_model.D_ag*context.ag_sample(step))/denominator;
    dd_lead_sample(step) = outputDiscreteSiso(lead_filter, dd_sample(step));
    dm_sample(step) = outputDiscreteSiso(actuator, dd_lead_sample(step));
    force_sample = k_mm*dm_sample(step);
    dc_sample(step) = outputDiscreteSiso(controller, ...
        dd_lead_sample(step) - dm_sample(step));
    x_num = num_model.A*x_num + num_model.B_fm*force_sample ...
        + num_model.B_ag*context.ag_sample(step);
    lead_filter = updateDiscreteSiso(lead_filter, dd_sample(step));
    actuator = updateDiscreteSiso(actuator, dd_lead_sample(step));
    controller = updateDiscreteSiso(controller, ...
        dd_lead_sample(step) - dm_sample(step));
    u_num_floors_sample(step, :) = x_num(1:context.hs.n_floor)';
end

response_error = u_num_floors_sample - context.u_reference_sample;
metrics = struct( ...
    'j4_percent', 100*std(u_num_floors_sample(:, 1) ...
        - context.u_reference_sample(:, 1)) ...
        /max(std(context.u_reference_sample(:, 1)), eps), ...
    'response_nrmse_percent', 100*localRms(response_error) ...
        /max(localRms(context.u_reference_sample), eps), ...
    'tracking_nrmse_percent', 100*localRms(dd_lead_sample - dm_sample) ...
        /max(localRms(dd_lead_sample), eps), ...
    'lead_change_percent', 100*localRms(dd_lead_sample - dd_sample) ...
        /max(localRms(dd_sample), eps), ...
    'peak_command_ratio', max(abs(dd_lead_sample)) ...
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
    candidate_id = summary_table.CandidateId(row);
    mask = time_table.CandidateId == candidate_id;
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

function safety_table = evaluateSafetySchedule(context, damage_cases, ...
        best_candidate, config)
alpha_grid = config.safety_alpha_grid(:);
n_alpha = numel(alpha_grid);
min_ncf = zeros(n_alpha, 1);
min_gm_db = zeros(n_alpha, 1);
worst_case = strings(n_alpha, 1);
for alpha_id = 1:n_alpha
    safe_candidate = best_candidate;
    safe_candidate.Label = sprintf('%s scaled %.3g', ...
        best_candidate.Label, alpha_grid(alpha_id));
    safe_candidate.Alpha = alpha_grid(alpha_id)*best_candidate.Alpha;
    safe_candidate.G_tf = alpha_grid(alpha_id)*best_candidate.G_tf;
    safe_candidate.G_response = alpha_grid(alpha_id) ...
        * best_candidate.G_response;
    ncf_values = zeros(numel(damage_cases), 1);
    gm_values = zeros(numel(damage_cases), 1);
    for case_id = 1:numel(damage_cases)
        loop_response = coupledLoopResponse(context, damage_cases(case_id), ...
            safe_candidate);
        [gm_values(case_id), ~, ncf_values(case_id)] = ...
            stabilityMarginsFromResponse(loop_response);
    end
    [min_ncf(alpha_id), worst_id] = min(ncf_values);
    min_gm_db(alpha_id) = min(gm_values);
    worst_case(alpha_id) = damage_cases(worst_id).Name;
end
safety_table = table(alpha_grid, min_ncf, min_gm_db, worst_case, ...
    'VariableNames', {'Scale', 'MinNCF', 'MinGM_dB', 'WorstNCFCase'});
end

function model = forceDiscrete(model, sample_time)
if get(model, 'Ts') == 0
    model = c2d(model, sample_time, 'zoh');
elseif abs(get(model, 'Ts') - sample_time) > 10*eps(sample_time)
    model = d2d(model, sample_time, 'zoh');
end
end

function model = forceLeadDiscrete(model, sample_time)
if isnumeric(model)
    model = tf(model);
end
if get(model, 'Ts') == 0
    model = c2d(model, sample_time, 'tustin');
elseif abs(get(model, 'Ts') - sample_time) > 10*eps(sample_time)
    model = d2d(model, sample_time, 'tustin');
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

function stability = analyzeActuatorLoop(num_model, actuator, lead_filter, ...
        k_experimental, sample_time)
k_mm = k_experimental/1000;
denominator = 1 - num_model.D_fm*k_mm*actuator.D*lead_filter.D;
dd_from_num = num_model.C/denominator;
dd_from_lead = num_model.D_fm*k_mm*actuator.D*lead_filter.C ...
    /denominator;
dd_from_actuator = num_model.D_fm*k_mm*actuator.C/denominator;
dd_lead_from_num = lead_filter.D*dd_from_num;
dd_lead_from_lead = lead_filter.C + lead_filter.D*dd_from_lead;
dd_lead_from_actuator = lead_filter.D*dd_from_actuator;
force_from_num = k_mm*actuator.D*dd_lead_from_num;
force_from_lead = k_mm*actuator.D*dd_lead_from_lead;
force_from_actuator = k_mm*(actuator.C ...
    + actuator.D*dd_lead_from_actuator);
closed_loop_A = [ ...
    num_model.A + num_model.B_fm*force_from_num, ...
    num_model.B_fm*force_from_lead, ...
    num_model.B_fm*force_from_actuator; ...
    lead_filter.B*dd_from_num, ...
    lead_filter.A + lead_filter.B*dd_from_lead, ...
    lead_filter.B*dd_from_actuator; ...
    actuator.B*dd_lead_from_num, ...
    actuator.B*dd_lead_from_lead, ...
    actuator.A + actuator.B*dd_lead_from_actuator];
closed_loop_poles = eig(closed_loop_A);
actuator_poles = eig(actuator.A);
lead_poles = eig(lead_filter.A);
[coupled_max_abs_pole, dominant_index] = max(abs(closed_loop_poles));
dominant_pole = closed_loop_poles(dominant_index);
stability.actuator_max_abs_pole = max([abs(actuator_poles); 0]);
stability.lead_max_abs_pole = max([abs(lead_poles); 0]);
stability.coupled_max_abs_pole = coupled_max_abs_pole;
stability.actuator_stable = stability.actuator_max_abs_pole < 1 ...
    && stability.lead_max_abs_pole < 1;
stability.coupled_stable = stability.coupled_max_abs_pole < 1;
stability.dominant_pole = dominant_pole;
stability.dominant_frequency_hz = abs(angle(dominant_pole)) ...
    /(2*pi*sample_time);
stability.closed_loop_poles = closed_loop_poles;
end

function system = discreteSiso(system_model, sample_time)
system_model = forceDiscrete(system_model, sample_time);
system_model = ss(system_model);
[system.A, system.B, system.C, system.D] = ssdata(system_model);
system.x = zeros(size(system.A, 1), 1);
system.u = 0;
end

function y = outputDiscreteSiso(system, u)
if nargin < 2
    u = system.u;
end
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

normalized_distance = abs(1 + response) ./ ...
    sqrt(2*(1 + abs(response).^2));
ncf_margin = min(normalized_distance);
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

function printCandidate(candidate)
if isnan(candidate.CenterHz)
    fprintf('%s: alpha %.6g, no lead\n', candidate.Label, ...
        candidate.Alpha)
else
    fprintf(['%s: alpha %.6g, center %.6g Hz, ratio %.6g, ' ...
        'zero %.6g Hz, pole %.6g Hz\n'], candidate.Label, ...
        candidate.Alpha, candidate.CenterHz, candidate.Ratio, ...
        candidate.ZeroHz, candidate.PoleHz)
end
end

function writeMarkdownReport(report_file, result)
fid = fopen(report_file, 'w');
cleanup = onCleanup(@() fclose(fid));
best = result.best_candidate;
summary = result.summary_table;
safety = result.safety_table;

fprintf(fid, '# Robust vHS phase-lead optimization report\n\n');
fprintf(fid, 'Generated by `robust_vhs_phase_lead_optimization.m`.\n\n');
fprintf(fid, '## Damage model findings\n\n');
fprintf(fid, '- Best scalar fit: `H_damaged ~= %.6g * H_healthy`.\n', ...
    result.context_summary.gamma_fit);
fprintf(fid, '- Scalar fit complex RMS error over %.3g-%.3g Hz: `%.3f %%`.\n', ...
    result.config.frequency_range_hz(1), result.config.frequency_range_hz(2), ...
    result.context_summary.fit_error_percent);
fprintf(fid, '- Healthy stiffness: `%.8g N/m`.\n', ...
    result.context_summary.healthy_stiffness_N_per_m);
fprintf(fid, '- Damaged stiffness: `%.8g N/m` (`%.4f` of healthy).\n\n', ...
    result.context_summary.damaged_stiffness_N_per_m, ...
    result.context_summary.damaged_to_healthy_k_ratio);
fprintf(fid, '## Structural modes\n\n');
fprintf(fid, '- Reference FEM modes: `%s Hz`.\n', ...
    numericVectorText(result.context_summary.ref_mode_frequency_hz));
fprintf(fid, '- Numerical-substructure condensed floor modes: `%s Hz`.\n', ...
    numericVectorText(result.context_summary.num_mode_frequency_hz));
fprintf(fid, '- Highest condensed floor mode: `%.4f Hz`.\n\n', ...
    max(result.context_summary.num_mode_frequency_hz));

fprintf(fid, '## Best candidate\n\n');
if isnan(best.CenterHz)
    fprintf(fid, '- Label: `%s`\n- Alpha: `%.6g`\n- Filter: no lead\n\n', ...
        char(best.Label), best.Alpha);
else
    fprintf(fid, ['- Label: `%s`\n- Alpha: `%.6g`\n' ...
        '- Center: `%.6g Hz`\n- Ratio: `%.6g`\n' ...
        '- Zero: `%.6g Hz`\n- Pole: `%.6g Hz`\n\n'], ...
        char(best.Label), best.Alpha, best.CenterHz, best.Ratio, ...
        best.ZeroHz, best.PoleHz);
end

writeNoAuthoritySection(fid, result)
writeSavedLeadSection(fid, result)
writeLowPassSection(fid, result)

fprintf(fid, '## Top candidates\n\n');
fprintf(fid, ['| Id | Label | min NCF | min GM dB | max pole | ' ...
    'max J4 %% | final score | worst NCF case |\n']);
fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---|\n');
for row = 1:min(result.config.report_top_count, height(summary))
    fprintf(fid, '| %d | %s | %.4f | %.3f | %.6f | %.3f | %.3f | %s |\n', ...
        summary.CandidateId(row), markdownEscape(summary.Label(row)), ...
        summary.MinNCF(row), summary.MinGM_dB(row), ...
        summary.MaxAbsPole(row), summary.MaxJ4_percent(row), ...
        summary.FinalScore(row), markdownEscape(summary.WorstNCFCase(row)));
end

fprintf(fid, '\n## Safety attenuation check for best candidate\n\n');
fprintf(fid, '| Scale | min NCF | min GM dB | worst NCF case |\n');
fprintf(fid, '|---:|---:|---:|---|\n');
for row = 1:height(safety)
    fprintf(fid, '| %.3f | %.4f | %.3f | %s |\n', ...
        safety.Scale(row), safety.MinNCF(row), safety.MinGM_dB(row), ...
        markdownEscape(safety.WorstNCFCase(row)));
end

fprintf(fid, '\n## Interpretation\n\n');
fprintf(fid, ['The optimizer ranks candidates by worst-case margin first and ' ...
    'then by full-record time-domain error on the measured/scalar rational ' ...
    'cases. A static phase lead is accepted only if it survives the ' ...
    'healthy, damaged, mismatch, scalar-gain, and measured-shape ' ...
    'frequency-response envelope.\n\n']);
fprintf(fid, ['The safety table is not assumed monotonic by theory. It is an ' ...
    'offline verification table for using command attenuation as the single ' ...
    'online safety knob.\n']);
end

function writeNoAuthoritySection(fid, result)
margin = sortrows(result.margin_table, 'MarginScore', 'ascend');
mask = abs(margin.Alpha - 1) < 1e-12;
fprintf(fid, '## Best no-authority candidate\n\n');
if ~any(mask)
    fprintf(fid, 'No `alpha = 1` candidate was evaluated.\n\n');
    return
end
row = find(mask, 1, 'first');
fprintf(fid, ['The best candidate with `alpha = 1` is `%s`, with ' ...
    '`min NCF = %.4f`, `min GM = %.3f dB`, and `max pole = %.6f`. ' ...
    'It is%s feasible against the robust envelope.\n\n'], ...
    char(margin.Label(row)), margin.MinNCF(row), margin.MinGM_dB(row), ...
    margin.MaxAbsPole(row), ternaryText(margin.Feasible(row), '', ' not'));

summary = result.summary_table;
no_lead = summary(summary.CandidateId == 1, :);
if ~isempty(no_lead)
    fprintf(fid, ['No-lead full-record check: `max J4 = %.3f %%`, ' ...
        '`min NCF = %.4f`, `min GM = %.3f dB`, worst case `%s`.\n\n'], ...
        no_lead.MaxJ4_percent(1), no_lead.MinNCF(1), ...
        no_lead.MinGM_dB(1), char(no_lead.WorstNCFCase(1)));
end
end

function writeSavedLeadSection(fid, result)
summary = result.summary_table;
saved_mask = contains(summary.Label, 'saved ');
if ~any(saved_mask)
    return
end
saved_mask = saved_mask & isfinite(summary.MaxJ4_percent);
saved = sortrows(summary(saved_mask, :), {'Alpha', 'FinalScore'}, ...
    {'descend', 'ascend'});
fprintf(fid, '## Saved phase-lead checks\n\n');
fprintf(fid, ...
    'Only saved-lead rows forced through full-record time simulation are shown.\n\n');
fprintf(fid, ['| Id | Label | min NCF | min GM dB | max pole | ' ...
    'max J4 %% | final score | worst NCF case |\n']);
fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---|\n');
for row = 1:height(saved)
    fprintf(fid, '| %d | %s | %.4f | %.3f | %.6f | %.3f | %.3f | %s |\n', ...
        saved.CandidateId(row), markdownEscape(saved.Label(row)), ...
        saved.MinNCF(row), saved.MinGM_dB(row), ...
        saved.MaxAbsPole(row), saved.MaxJ4_percent(row), ...
        saved.FinalScore(row), markdownEscape(saved.WorstNCFCase(row)));
end
fprintf(fid, '\n');
end

function writeLowPassSection(fid, result)
summary = result.summary_table;
mask = contains(summary.Label, 'lowpass ') ...
    & isfinite(summary.MaxJ4_percent);
if ~any(mask)
    return
end
lowpass = sortrows(summary(mask, :), 'FinalScore', 'ascend');
fprintf(fid, '## Low-pass candidates after the highest mode\n\n');
fprintf(fid, ['These candidates have DC gain 1 and cut off after the ' ...
    'highest condensed floor mode. They preserve low-frequency command ' ...
    'authority but add lag and attenuation near/above cutoff.\n\n']);
fprintf(fid, ['| Id | Label | min NCF | min GM dB | max pole | ' ...
    'max J4 %% | max command ratio | final score | worst NCF case |\n']);
fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|---:|---|\n');
for row = 1:height(lowpass)
    fprintf(fid, ...
        '| %d | %s | %.4f | %.3f | %.6f | %.3f | %.3f | %.3f | %s |\n', ...
        lowpass.CandidateId(row), markdownEscape(lowpass.Label(row)), ...
        lowpass.MinNCF(row), lowpass.MinGM_dB(row), ...
        lowpass.MaxAbsPole(row), lowpass.MaxJ4_percent(row), ...
        lowpass.MaxPeakCommandRatio(row), lowpass.FinalScore(row), ...
        markdownEscape(lowpass.WorstNCFCase(row)));
end
fprintf(fid, '\n');
end

function text = ternaryText(condition, true_text, false_text)
if condition
    text = true_text;
else
    text = false_text;
end
end

function text = markdownEscape(value)
text = char(string(value));
text = strrep(text, '|', '\|');
end

function text = numericVectorText(values)
parts = arrayfun(@(value) sprintf('%.4g', value), values(:).', ...
    'UniformOutput', false);
text = strjoin(parts, ', ');
end

function plotSummary(plot_file, summary_table, safety_table, config)
fig = figure('Color', 'w', 'Visible', 'off', ...
    'Name', 'Robust vHS phase-lead summary');
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile;
finite_mask = isfinite(summary_table.MaxJ4_percent);
scatter(ax, summary_table.MinNCF(finite_mask), ...
    summary_table.MaxJ4_percent(finite_mask), 36, ...
    summary_table.Alpha(finite_mask), 'filled');
grid(ax, 'on')
xline(ax, config.ncf_hard_target, '--');
xline(ax, config.ncf_preferred_target, ':');
xlabel(ax, 'Worst-case NCF')
ylabel(ax, 'Max J4 over time cases (%)')
title(ax, 'Candidate tradeoff')
colorbar(ax);

ax = nexttile;
plot(ax, safety_table.Scale, safety_table.MinNCF, '-o', 'LineWidth', 1.2);
grid(ax, 'on')
yline(ax, config.ncf_hard_target, '--');
yline(ax, config.ncf_preferred_target, ':');
set(ax, 'XDir', 'reverse')
xlabel(ax, 'Scale on selected filter')
ylabel(ax, 'Worst-case NCF')
title(ax, 'Safety attenuation sweep')

saveas(fig, plot_file)
close(fig)
end
