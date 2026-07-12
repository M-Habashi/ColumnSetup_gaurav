function result = optimize_vHS_phase_lead_robust(user_config)
%OPTIMIZE_VHS_PHASE_LEAD_ROBUST Damage-robust vHS phase_lead optimizer.
% Designs a prefilter G_T(s) applied to the numerical dd command:
%
%   G_T(s) = k_T * prod (s + zi)/(s + pi)                 [1st-order]
%            * prod (s^2 + 2*zzj*wj*s + wj^2)             [optional
%                  /(s^2 + 2*zpj*wj*s + wj^2)              notches]
%
% Each first-order section may be a lead (pole above zero) or a lag
% (pole below zero); each optional second-order section is a notch
% (zeta_zero < zeta_pole cuts the band around wj). k_T is chosen so the
% DC gain is always 1. The objective is the configured nominal
% validation metric (J4 by default, optionally J2) subject to
% TWO hard NCF constraints:
%
%   1. nominal:  NCF(L_healthy * G_T)               >= target_ncf_margin
%   2. robust :  min over scenarios NCF(L_s * G_T)  >= robust_ncf_target
%
% == The damage path (one or MORE identified damage states) ===========
% config.damage_states lists the identified damaged states in order of
% increasing damage, e.g. 5k, then (when identified later) 3k and 1k:
%
%   config.damage_states = struct( ...
%       'label', {'5k', '3k'}, ...
%       'specimen_file', {'<...>\sp1_5000.mat', '<...>\sp1_3000.mat'}, ...
%       'h_dc_dm_model_file', {'<...>\tf_sp1_5000_....mat', ...
%                              '<...>\tf_sp1_3000_....mat'});
%
% The engine anchors a piecewise-geometric path through every state:
% with A0 = healthy open loop and Ak = open loop of state k, the loop at
% path coordinate lambda in [k-1, k] is
%
%   L(lambda) = L_nominal * delta(lambda),
%   log delta(lambda) = sum_{j<k} log(Aj/Aj-1)
%                       + (lambda-k+1)*log(Ak/Ak-1)
%
% (complex log with unwrapped phase), so lambda = 0 is healthy,
% lambda = k is EXACTLY identified state k, and lambda beyond the last
% state extrapolates the final segment. Scenario constraints are placed
% at template_lambda_grid fractions inside every segment (entries <= 1)
% plus overshoot beyond the last state (entries > 1: 1.15 means
% lambda = n_states + 0.15). Because the loop is forced to keep a
% finite distance from -1 at every sampled lambda, the Nyquist winding
% number cannot change along the degradation, which certifies stability
% of every intermediate state, not just the identified endpoints.
%
% == HOW TO ADD A NEW DAMAGE STATE (e.g. the future 3k or 1k) =========
%   1. Run the usual identification on the new state:
%      a_specimen_id -> saved_results/specimens/sp1_3000.mat and
%      sys_id.m      -> saved_results/exp_tf/tf_sp1_3000_<stamp>.mat.
%   2. Append one entry to config.damage_states (keep the list ordered
%      from least to most damaged; the wrapper script
%      optimize_vHS_phase_lead_robust_ncf.m has the list at the top).
%   3. Re-run the wrapper. Nothing else changes: the path gains one
%      segment, every report/plot gains one identified-state column and
%      marker, and the constraints now cover the longer path.
%   Backward compatibility: the legacy single-state options
%   damaged_specimen_file / damaged_h_dc_dm_model_file are still
%   accepted and are converted into a one-entry damage_states list.
%
% == Designing for a NEW specimen (only its healthy state known) ======
% Set template_healthy_* to the REFERENCE specimen's healthy files and
% keep damage_states pointing at the reference specimen's damaged
% states. The path shape is then Ak/A0 of the reference pair (pure
% damage physics) applied to the new specimen's own nominal loop.
%
% Without any damage_states entry the engine falls back to a generic
% scenario family (stiffness scaling, extra delay, high-frequency gain
% inflation) - see k_scale_scenarios / extra_delay_scenarios_s /
% hf_gain_scenarios.
%
% Candidate evaluation reuses the v2 engine building blocks
% (optimize_vHS_phase_lead_v2('helpers')): the assembled closed-loop LTI
% simulation for the objective and analytic tustin-exact NCF constraints.
% The saved MAT keeps the legacy phase_lead format (phase_lead_tf holds
% the full filter including notches) so vHS.m loads it unchanged.

if nargin < 1 || isempty(user_config)
    user_config = struct();
end
if ischar(user_config) || isstring(user_config)
    assert(strcmp(char(user_config), 'helpers'), ...
        'optimize_vHS_phase_lead_robust:InvalidRequest', ...
        'The only supported text argument is ''helpers''.')
    result = struct( ...
        'default_config', @defaultRobustConfig, ...
        'prepare', @prepareRobustProblem, ...
        'robust_ncf', @robustNcfOfCandidate, ...
        'lead_response', @leadResponseOnGrid, ...
        'candidates_ncf', @candidatesNcf, ...
        'path_log_delta', @pathLogDelta, ...
        'phase_lead_from_x', @phaseLeadFromX);
    return
end

engine_dir = fileparts(mfilename('fullpath'));
hs_dir = fileparts(engine_dir);
project_root = fileparts(fileparts(hs_dir));
addpath(engine_dir);

config = mergeStructRobust(defaultRobustConfig(), user_config);
config = validateRobustConfig(config);

total_timer = tic;
fprintf('\n=== vHS phase_lead ROBUST optimizer ===\n')
fprintf(['Goal: min %s s.t. nominal NCF >= %.4g AND scenario NCF >= ' ...
    '%.4g | sections = %d (lead or lag) + %d notch(es)\n'], ...
    objectiveLabel(config), config.target_ncf_margin, config.robust_ncf_target, ...
    config.phase_lead_section_count, config.notch_section_count)

problem = prepareRobustProblem(project_root, config);

state = newRobustState(problem);
[state, baseline] = evaluateRobustLogged(state, [], 'baseline');
fprintf(['Baseline (no phase_lead): %s = %.4g %%, NCF nominal = %.4g, ' ...
    'NCF robust worst = %.4g (%s)\n'], objectiveLabel(config), ...
    baseline.objective, ...
    baseline.robust.ncf_nominal, baseline.robust.ncf_worst, ...
    baseline.robust.worst_scenario_name)

state = screenStageRobust(state);
state = simStageRobust(state);
state = polishStageRobust(state);

result = finalizeRobust(state, baseline, project_root, total_timer);
end

%% ----------------------------------------------------------------------
%% Configuration
%% ----------------------------------------------------------------------

function config = defaultRobustConfig()
config = struct( ...
    ... % --- record / plant inputs (same meaning as the v2 engine)
    'earthquake_type', 'el_centro', ...
    'intensity_factor', 0.2, ...
    'time_scale_factor', 1, ...
    'force_sign', 1.0, ...
    'optimization_record_fraction', 1.0, ...
    'k_exp_r', 1.0, ...
    'sample_dt', 1/2048, ...
    'h_dc_dm_model_file', '', ...
    'fem_file', '', ...
    'specimen_file', '', ...
    'pid_gain_override', [0.15 20 0.0015 512], ...
    'num_phase_lead_exp_margin_frequency_hz', [0.1 80], ...
    'num_phase_lead_exp_margin_point_count', 10000, ...
    ... % --- goals
    'objective_metric', 'J4', ...       % supported: J4 or J2
    'target_ncf_margin', 0.40, ...      % nominal (healthy) NCF floor
    'robust_ncf_target', 0.25, ...      % worst-scenario NCF floor
    'minimum_stability_margin', 0.01, ...
    ... % Optional anti-ringing condition (see optimize_vHS_phase_lead_v2
    ... % defaultConfigV2): minimum damping ratio required of every
    ... % coupled RTHS closed-loop pole inside the band. 0 = off (classic
    ... % behavior, accepts zeta ~ 0 designs that ring forever on the
    ... % rig - pl_5k had max|z| = 0.9998). Practical value: 0.015-0.02.
    'minimum_coupled_pole_damping', 0, ...
    'coupled_pole_damping_band_hz', [0.2 50], ...
    ... % --- damage scenario model
    ... % damage_states: struct array, ORDERED least -> most damaged,
    ... % fields: label, specimen_file, h_dc_dm_model_file. See the
    ... % header for how to append new states (3k, 1k, ...).
    'damage_states', struct('label', {}, 'specimen_file', {}, ...
        'h_dc_dm_model_file', {}), ...
    'damaged_specimen_file', '', ...    % legacy single-state alias
    'damaged_h_dc_dm_model_file', '', ...
    'template_healthy_specimen_file', '', ... % reference-pair healthy
    'template_healthy_h_dc_dm_model_file', '', ...
    ... % entries <= 1: fractions checked inside EVERY path segment;
    ... % entries > 1: overshoot beyond the last identified state
    ... % (1.15 -> lambda = n_states + 0.15).
    'template_lambda_grid', [0.35 0.7 1.0 1.15], ...
    ... % frequency-warp factors applied to the damage template: 0.85
    ... % re-checks the whole path with every template feature (e.g.
    ... % the damaged actuator resonance) moved 15% DOWN in frequency.
    ... % Essential when the design uses narrow notches: it forces the
    ... % notch wide enough to cover placement error in the template.
    'template_warp_scenarios', [], ...
    'k_scale_scenarios', [], ...        % generic fallback, e.g. [0.85 0.7]
    'extra_delay_scenarios_s', [], ...  % generic, e.g. [0.5e-3 1e-3]
    'hf_gain_scenarios', [], ...        % generic, rows [gamma corner_hz]
    ... % --- search space
    'phase_lead_section_count', 2, ...
    'center_frequency_bounds_hz', [0.5 80], ...
    'section_ratio_bounds', [1/25 25], ... % ratio < 1 makes a lag section
    'notch_section_count', 0, ...       % 2nd-order notch sections
    'notch_frequency_bounds_hz', [5 80], ...
    'notch_depth_bounds', [0.03 1], ... % zeta_zero/zeta_pole; 1 = identity
    'notch_zeta_pole_bounds', [0.2 2], ...
    ... % Warm starts: phase_lead structs (or saved phase_lead MAT file
    ... % names) evaluated before the screened candidates and offered to
    ... % the fmincon polish. Use it to re-optimize from a previous
    ... % design when new damage states or scenarios are added. Entries
    ... % must match phase_lead_section_count / notch_section_count.
    'seed_phase_leads', {{}}, ...
    ... % --- stage budgets
    'screen_sample_count', 30000, ...
    'screen_point_count', 1500, ...     % decimated grid for screening
    'sim_budget', 140, ...
    'sim_min_log_distance', 0.15, ...   % diversity radius for sim picks
    'use_fmincon_polish', true, ...
    'polish_start_count', 3, ...
    'polish_max_evaluations', 200, ...
    'polish_max_iterations', 80, ...
    'random_seed', 7, ...
    ... % --- objective proxy used before simulating
    'j4_proxy_band_hz', [0.1 12], ...
    ... % --- reporting / output
    'compare_phase_lead_files', {{}}, ... % saved_results/phase_lead names
    'report_lambda_step', 0.05, ...
    'progress_interval_seconds', 2, ...
    'checkpoint_min_interval_seconds', 5, ...
    'best_checkpoint_file', '', ...
    'phase_lead_file_name', 'pl_robust', ...
    'save_results', true, ...
    'save_best_checkpoint', true, ...
    'plot_results', true, ...
    'plot_export_dir', '', ...          % export PNGs here when nonempty
    'print_validation_tables', true);
end

function config = mergeStructRobust(config, override)
fields = fieldnames(override);
for field_id = 1:numel(fields)
    config.(fields{field_id}) = override.(fields{field_id});
end
end

function config = validateRobustConfig(config)
config.objective_metric = upper(char(string(config.objective_metric)));
assert(any(strcmp(config.objective_metric, {'J2', 'J4'})), ...
    'optimize_vHS_phase_lead_robust:InvalidObjectiveMetric', ...
    'config.objective_metric must be ''J2'' or ''J4''.')
validateattributes(config.target_ncf_margin, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<', 1}, mfilename, ...
    'config.target_ncf_margin');
validateattributes(config.robust_ncf_target, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative', '<', 1}, mfilename, ...
    'config.robust_ncf_target');
validateattributes(config.phase_lead_section_count, {'numeric'}, ...
    {'scalar', 'integer', 'positive', '<=', 6}, mfilename, ...
    'config.phase_lead_section_count');
validateattributes(config.notch_section_count, {'numeric'}, ...
    {'scalar', 'integer', 'nonnegative', '<=', 4}, mfilename, ...
    'config.notch_section_count');
validateattributes(config.section_ratio_bounds, {'numeric'}, ...
    {'vector', 'numel', 2, 'positive', 'increasing'}, mfilename, ...
    'config.section_ratio_bounds');

config.damage_states = normalizeDamageStates(config);
if isempty(config.damage_states) ...
        && isempty(config.k_scale_scenarios) ...
        && isempty(config.extra_delay_scenarios_s) ...
        && isempty(config.hf_gain_scenarios)
    % Generic fallback family when no damaged identification exists.
    config.k_scale_scenarios = [0.85 0.7 0.55];
    config.extra_delay_scenarios_s = [0.5e-3 1e-3];
    config.hf_gain_scenarios = [2 10; 4 15];
end
if ~isempty(config.template_healthy_specimen_file) ...
        || ~isempty(config.template_healthy_h_dc_dm_model_file)
    assert(~isempty(config.template_healthy_specimen_file) ...
        && ~isempty(config.template_healthy_h_dc_dm_model_file), ...
        'optimize_vHS_phase_lead_robust:IncompleteTemplateHealthy', ...
        ['Provide both template_healthy_specimen_file and ' ...
        'template_healthy_h_dc_dm_model_file (or neither).'])
    assert(~isempty(config.damage_states), ...
        'optimize_vHS_phase_lead_robust:TemplateWithoutDamageStates', ...
        'template_healthy_* requires at least one damage state.')
end
if ~iscell(config.compare_phase_lead_files)
    config.compare_phase_lead_files = ...
        cellstr(config.compare_phase_lead_files);
end
if isscalar(config.compare_phase_lead_files) ...
        && iscell(config.compare_phase_lead_files{1})
    % Tolerate the struct()-constructor double-brace idiom leaking into
    % a plain field assignment: {{'a', 'b'}} -> {'a', 'b'}.
    config.compare_phase_lead_files = config.compare_phase_lead_files{1};
end
end

function states = normalizeDamageStates(config)
% Accept struct arrays or cell arrays of structs; fold the legacy
% single-state fields into the list; validate ordering inputs.
states = config.damage_states;
if iscell(states)
    states = [states{:}];
end
if ~isempty(config.damaged_specimen_file) ...
        || ~isempty(config.damaged_h_dc_dm_model_file)
    assert(~isempty(config.damaged_specimen_file) ...
        && ~isempty(config.damaged_h_dc_dm_model_file), ...
        'optimize_vHS_phase_lead_robust:IncompleteDamagedState', ...
        ['Provide both damaged_specimen_file and ' ...
        'damaged_h_dc_dm_model_file (or neither).'])
    legacy = struct('label', 'damaged', ...
        'specimen_file', config.damaged_specimen_file, ...
        'h_dc_dm_model_file', config.damaged_h_dc_dm_model_file);
    states = [orderfields(legacy), arrayfun(@orderfields, states)];
end
for state_id = 1:numel(states)
    assert(isfield(states, 'specimen_file') ...
        && isfield(states, 'h_dc_dm_model_file'), ...
        'optimize_vHS_phase_lead_robust:InvalidDamageState', ...
        ['Each damage_states entry needs specimen_file and ' ...
        'h_dc_dm_model_file fields.'])
    if ~isfield(states, 'label') || isempty(states(state_id).label)
        states(state_id).label = sprintf('state%d', state_id);
    end
    states(state_id).label = char(string(states(state_id).label));
end
end

%% ----------------------------------------------------------------------
%% Problem preparation: nominal + damage states and the scenario set
%% ----------------------------------------------------------------------

function problem = prepareRobustProblem(project_root, config)
helpers = optimize_vHS_phase_lead_v2('helpers');
v2_config = helpers.default_config();
shared_fields = {'earthquake_type', 'intensity_factor', ...
    'time_scale_factor', 'force_sign', 'k_exp_r', 'sample_dt', ...
    'h_dc_dm_model_file', 'fem_file', 'specimen_file', ...
    'pid_gain_override', 'target_ncf_margin', ...
    'minimum_stability_margin', ...
    'minimum_coupled_pole_damping', ...
    'coupled_pole_damping_band_hz', ...
    'num_phase_lead_exp_margin_frequency_hz', ...
    'num_phase_lead_exp_margin_point_count', ...
    'phase_lead_section_count'};
for field_id = 1:numel(shared_fields)
    v2_config.(shared_fields{field_id}) = ...
        config.(shared_fields{field_id});
end
v2_config.save_results = false;
v2_config = helpers.normalize_config(v2_config);

fprintf('\nNominal (healthy) state:\n')
nominal = helpers.prepare(project_root, v2_config, ...
    config.optimization_record_fraction);
config.specimen_file = nominal.specimen_file;
config.h_dc_dm_model_file = nominal.h_dc_dm_model_file;
config.fem_file = nominal.fem_file;

damage_states = struct('label', {}, 'problem', {});
for state_id = 1:numel(config.damage_states)
    entry = config.damage_states(state_id);
    fprintf('Damage state %d/%d (%s):\n', state_id, ...
        numel(config.damage_states), entry.label)
    state_config = v2_config;
    state_config.specimen_file = entry.specimen_file;
    state_config.h_dc_dm_model_file = entry.h_dc_dm_model_file;
    state_config.fem_file = nominal.fem_file;
    state_problem = helpers.prepare(project_root, state_config, ...
        config.optimization_record_fraction);
    assert(max(abs(nominal.margin_frequency_rad_s ...
        - state_problem.margin_frequency_rad_s)) == 0, ...
        'optimize_vHS_phase_lead_robust:GridMismatch', ...
        'Nominal and damage-state margin frequency grids must match.')
    damage_states(state_id) = struct('label', entry.label, ...
        'problem', state_problem);
end

template_healthy_response = [];
if ~isempty(config.template_healthy_specimen_file)
    fprintf(['Template-healthy reference state (damage path anchored ' ...
        'at the reference pair):\n'])
    template_config = v2_config;
    template_config.specimen_file = ...
        config.template_healthy_specimen_file;
    template_config.h_dc_dm_model_file = ...
        config.template_healthy_h_dc_dm_model_file;
    template_config.fem_file = nominal.fem_file;
    template_healthy = helpers.prepare(project_root, template_config, ...
        config.optimization_record_fraction);
    template_healthy_response = ...
        template_healthy.base_open_loop_response(:);
end

scenarios = buildScenarioSet(config, nominal, damage_states, ...
    template_healthy_response);
fprintf('Scenario set (%d):\n', numel(scenarios.names))
for scenario_id = 1:numel(scenarios.names)
    fprintf('  %2d. %s\n', scenario_id, scenarios.names{scenario_id})
end

problem = struct( ...
    'config', config, ...
    'project_root', project_root, ...
    'helpers', helpers, ...
    'nominal', nominal, ...
    'damage_states', damage_states, ...
    'has_damage_states', ~isempty(damage_states), ...
    'scenarios', scenarios, ...
    'screen', buildScreenGrid(config, nominal, scenarios), ...
    'proxy_weight', j4ProxyWeights(config, nominal));
end

function scenarios = buildScenarioSet(config, nominal, damage_states, ...
        template_healthy_response)
% Scenario s is the nominal open loop multiplied by mult(:, s); the
% robust constraint is min over s of the NCF of mult(:,s).*L_nom.*G_T.
% The damage path is anchored at A0 (template-healthy reference, or the
% nominal loop itself) and passes through every identified damage state
% in order; segment_logs(:, k) = log(Ak./Ak-1) with unwrapped phase.
frequency_rad_s = nominal.margin_frequency_rad_s(:);
n_freq = numel(frequency_rad_s);
mult = zeros(n_freq, 0);
names = {};
lambdas = [];

n_states = numel(damage_states);
segment_logs = zeros(n_freq, n_states);
state_labels = cell(1, n_states);
if n_states > 0
    if isempty(template_healthy_response)
        anchor = nominal.base_open_loop_response(:);
    else
        anchor = template_healthy_response;
    end
    for state_id = 1:n_states
        state_response = ...
            damage_states(state_id).problem.base_open_loop_response(:);
        ratio = state_response./anchor;
        segment_logs(:, state_id) = log(abs(ratio)) ...
            + 1i*unwrap(angle(ratio));
        state_labels{state_id} = damage_states(state_id).label;
        anchor = state_response;
    end

    fractions = config.template_lambda_grid( ...
        config.template_lambda_grid <= 1);
    overshoots = config.template_lambda_grid( ...
        config.template_lambda_grid > 1) - 1;
    lambda_list = [];
    for segment_id = 1:n_states
        lambda_list = [lambda_list, segment_id - 1 + fractions(:).']; %#ok<AGROW>
    end
    lambda_list = [lambda_list, n_states + overshoots(:).'];
    lambda_list = unique(lambda_list(lambda_list > 0));
    warps = [1, config.template_warp_scenarios(:).'];
    warps = unique(warps);
    log_frequency = log(frequency_rad_s);
    for warp = warps
        if warp == 1
            warped_logs = segment_logs;
            warp_suffix = '';
        else
            % Move every template feature (resonances, phase bumps) by
            % the warp factor: evaluate the log-template at w/warp.
            warped_logs = interp1(log_frequency, segment_logs, ...
                log_frequency - log(warp), 'linear', 'extrap');
            warp_suffix = sprintf(', resonance warp x%.3g', warp);
        end
        for lambda = lambda_list
            mult(:, end+1) = exp(pathLogDelta(warped_logs, ...
                lambda)); %#ok<AGROW>
            names{end+1} = [damagePathScenarioName(lambda, n_states, ...
                state_labels), warp_suffix]; %#ok<AGROW>
            lambdas(end+1) = lambda; %#ok<AGROW>
        end
    end
end

for k_scale = config.k_scale_scenarios(:).'
    mult(:, end+1) = k_scale*ones(n_freq, 1); %#ok<AGROW>
    names{end+1} = sprintf('stiffness scale k -> %.3g k', ...
        k_scale); %#ok<AGROW>
    lambdas(end+1) = NaN; %#ok<AGROW>
end
for delay_s = config.extra_delay_scenarios_s(:).'
    mult(:, end+1) = exp(-1i*frequency_rad_s*delay_s); %#ok<AGROW>
    names{end+1} = sprintf('extra delay %.3g ms', ...
        1000*delay_s); %#ok<AGROW>
    lambdas(end+1) = NaN; %#ok<AGROW>
end
if ~isempty(config.hf_gain_scenarios)
    for row = 1:size(config.hf_gain_scenarios, 1)
        gamma = config.hf_gain_scenarios(row, 1);
        corner_rad_s = 2*pi*config.hf_gain_scenarios(row, 2);
        shelf = 1 + (gamma - 1)*frequency_rad_s.^2 ...
            ./(frequency_rad_s.^2 + corner_rad_s^2);
        mult(:, end+1) = shelf; %#ok<AGROW>
        names{end+1} = sprintf(['high-frequency gain x%.3g above ' ...
            '%.3g Hz'], gamma, config.hf_gain_scenarios(row, 2)); %#ok<AGROW>
        lambdas(end+1) = NaN; %#ok<AGROW>
    end
end
assert(~isempty(names), ...
    'optimize_vHS_phase_lead_robust:EmptyScenarioSet', ...
    'The damage scenario set is empty; configure at least one scenario.')
scenarios = struct('mult', mult, 'names', {names}, ...
    'lambdas', lambdas, 'segment_logs', segment_logs, ...
    'n_states', n_states, 'state_labels', {state_labels});
end

function log_delta = pathLogDelta(segment_logs, lambda)
% Complex log of the damage-path multiplier at path coordinate lambda:
% integer lambda = identified state, fractional = geometric
% interpolation inside the segment, beyond the last state = geometric
% extrapolation of the final segment.
n_segments = size(segment_logs, 2);
assert(n_segments > 0, ...
    'optimize_vHS_phase_lead_robust:NoDamagePath', ...
    'pathLogDelta requires at least one damage state.')
full_segments = min(floor(lambda), n_segments);
log_delta = sum(segment_logs(:, 1:full_segments), 2);
fraction = lambda - full_segments;
if fraction > 0
    active = min(full_segments + 1, n_segments);
    log_delta = log_delta + fraction*segment_logs(:, active);
end
end

function name = damagePathScenarioName(lambda, n_states, state_labels)
if lambda > n_states
    name = sprintf('damage path lambda = %.3g (%.3g beyond %s)', ...
        lambda, lambda - n_states, state_labels{end});
elseif abs(lambda - round(lambda)) < 1e-12 && lambda >= 1
    name = sprintf('identified state %s (lambda = %d)', ...
        state_labels{round(lambda)}, round(lambda));
else
    segment_id = min(floor(lambda) + 1, n_states);
    name = sprintf('damage path lambda = %.3g (toward %s)', ...
        lambda, state_labels{segment_id});
end
end

function screen = buildScreenGrid(config, nominal, scenarios)
% Decimated frequency grid so tens of thousands of candidates can be
% screened analytically; shortlisted candidates are re-checked on the
% full grid before they count as feasible.
n_freq = numel(nominal.margin_frequency_rad_s);
take = unique(round(linspace(1, n_freq, ...
    min(config.screen_point_count, n_freq))));
actuator_response = squeeze(freqresp(nominal.PID_H_dc_dm, ...
    nominal.margin_frequency_rad_s(take)));
screen = struct( ...
    'bilinear_s', nominal.margin_bilinear_s(take), ...
    'base_response', nominal.base_open_loop_response(take), ...
    'scenario_mult', scenarios.mult(take, :), ...
    'actuator_response', actuator_response(:), ...
    'frequency_hz', nominal.margin_frequency_rad_s(take)/(2*pi));
end

function weight = j4ProxyWeights(config, nominal)
% Spectrum of the reference interface command, interpolated onto the
% screening grid: candidates that distort the command where the record
% has energy will have worse performance, so this ranks candidates for
% the simulation budget without running simulations.
d_ref_mm = 1000*nominal.d_reference_sample(:);
n_sample = numel(d_ref_mm);
spectrum = abs(fft(d_ref_mm));
half = floor(n_sample/2);
spectrum = movmean(spectrum(1:half), max(3, round(half/2000)));
frequency_hz = (0:half-1).'/(n_sample*nominal.sample_dt);
n_freq = numel(nominal.margin_frequency_rad_s);
take = unique(round(linspace(1, n_freq, ...
    min(config.screen_point_count, n_freq))));
grid_hz = nominal.margin_frequency_rad_s(take)/(2*pi);
weight = interp1(frequency_hz, spectrum, grid_hz, 'linear', 0);
band = grid_hz >= config.j4_proxy_band_hz(1) ...
    & grid_hz <= config.j4_proxy_band_hz(2);
weight(~band) = 0;
weight = weight/max(norm(weight), eps);
end

%% ----------------------------------------------------------------------
%% Analytic NCF machinery (candidate batches and single candidates)
%% ----------------------------------------------------------------------

function response = leadResponseOnGrid(bilinear_s, phase_lead)
phase_lead = normalizePhaseLeadConfig(phase_lead);
s_eq = bilinear_s(:);
if ~phase_lead.enabled
    response = ones(size(s_eq));
    return
end
response = phase_lead.gain*ones(size(s_eq));
for section_id = 1:phase_lead.section_count
    response = response ...
        .*(s_eq + phase_lead.zero_rad_s(section_id)) ...
        ./(s_eq + phase_lead.pole_rad_s(section_id));
end
for notch_id = 1:size(phase_lead.notch_sections, 1)
    w = 2*pi*phase_lead.notch_sections(notch_id, 1);
    zeta_zero = phase_lead.notch_sections(notch_id, 2);
    zeta_pole = phase_lead.notch_sections(notch_id, 3);
    response = response ...
        .*(s_eq.^2 + 2*zeta_zero*w*s_eq + w^2) ...
        ./(s_eq.^2 + 2*zeta_pole*w*s_eq + w^2);
end
end

function ncf = ncfOfResponse(response)
ncf = min(abs(1 + response)./sqrt(2*(1 + abs(response).^2)), [], 1);
end

function robust = robustNcfOfCandidate(problem, phase_lead)
% Full-grid nominal and scenario NCF margins for one candidate.
nominal = problem.nominal;
lead_response = leadResponseOnGrid(nominal.margin_bilinear_s, ...
    phase_lead);
nominal_response = nominal.base_open_loop_response(:).*lead_response;
robust.ncf_nominal = ncfOfResponse(nominal_response);
scenario_ncf = ncfOfResponse(nominal_response ...
    .*problem.scenarios.mult);
[robust.ncf_worst, worst_id] = min(scenario_ncf);
robust.scenario_ncf = scenario_ncf;
robust.worst_scenario_name = problem.scenarios.names{worst_id};
robust.nominal_shortfall = max(0, ...
    problem.config.target_ncf_margin - robust.ncf_nominal);
robust.robust_shortfall = max(0, ...
    problem.config.robust_ncf_target - robust.ncf_worst);
robust.feasible_ncf = robust.nominal_shortfall <= 1e-9 ...
    && robust.robust_shortfall <= 1e-9;
end

function [ncf_nominal, ncf_worst, proxy] = candidatesNcf(problem, x_matrix)
% Vectorized screening on the decimated grid. x_matrix rows follow the
% phaseLeadFromX layout: [log c (N1), log r (N1), log fn (N2),
% log depth (N2), log zeta_pole (N2)]. Returns the nominal NCF, the
% worst scenario NCF and the configured objective proxy for every candidate.
config = problem.config;
n_section = config.phase_lead_section_count;
n_notch = config.notch_section_count;
screen = problem.screen;
s_eq = screen.bilinear_s(:);
base = screen.base_response(:);
mult = screen.scenario_mult;
weight = problem.proxy_weight(:);
n_candidate = size(x_matrix, 1);
ncf_nominal = zeros(n_candidate, 1);
ncf_worst = zeros(n_candidate, 1);
proxy = zeros(n_candidate, 1);
chunk = max(1, floor(4e6/(numel(s_eq)*(1 + size(mult, 2)))));
s_sq = s_eq.^2;
for start_id = 1:chunk:n_candidate
    ids = start_id:min(start_id + chunk - 1, n_candidate);
    log_centers = x_matrix(ids, 1:n_section);
    log_ratios = x_matrix(ids, n_section+1:2*n_section);
    zero_rad = 2*pi*exp(log_centers - log_ratios/2);
    pole_rad = 2*pi*exp(log_centers + log_ratios/2);
    gain = prod(pole_rad./zero_rad, 2).'; % unity DC gain
    lead = repmat(gain, numel(s_eq), 1);
    for section_id = 1:n_section
        lead = lead.*(s_eq + zero_rad(:, section_id).') ...
            ./(s_eq + pole_rad(:, section_id).');
    end
    for notch_id = 1:n_notch
        w = 2*pi*exp(x_matrix(ids, 2*n_section + notch_id)).';
        zeta_pole = exp(x_matrix(ids, ...
            2*n_section + 2*n_notch + notch_id)).';
        zeta_zero = exp(x_matrix(ids, ...
            2*n_section + n_notch + notch_id)).'.*zeta_pole;
        lead = lead.*(s_sq + s_eq*(2*zeta_zero.*w) + ones(size(s_eq))*w.^2) ...
            ./(s_sq + s_eq*(2*zeta_pole.*w) + ones(size(s_eq))*w.^2);
    end
    nominal_response = base.*lead;
    ncf_nominal(ids) = ncfOfResponse(nominal_response);
    worst = inf(1, numel(ids));
    for scenario_id = 1:size(mult, 2)
        worst = min(worst, ncfOfResponse(nominal_response ...
            .*mult(:, scenario_id)));
    end
    ncf_worst(ids) = worst;
    if strcmp(config.objective_metric, 'J2')
        proxy_error = screen.actuator_response.*lead - 1;
    else
        proxy_error = lead - 1;
    end
    proxy(ids) = sqrt(sum((weight.*abs(proxy_error)).^2, 1));
end
end

function phase_lead = phaseLeadFromX(x, n_section, n_notch)
% x = [log_center (N1), log_ratio (N1), log_notch_hz (N2),
%      log_depth (N2, depth = zeta_zero/zeta_pole <= 1),
%      log_zeta_pole (N2)]  (natural logs). Unity DC gain.
x = x(:).';
log_centers = x(1:n_section);
log_ratios = x(n_section+1:2*n_section);
zero_hz = exp(log_centers - log_ratios/2);
pole_hz = exp(log_centers + log_ratios/2);
notch_sections = zeros(n_notch, 3);
for notch_id = 1:n_notch
    frequency_hz = exp(x(2*n_section + notch_id));
    depth = exp(x(2*n_section + n_notch + notch_id));
    zeta_pole = exp(x(2*n_section + 2*n_notch + notch_id));
    notch_sections(notch_id, :) = [frequency_hz, depth*zeta_pole, ...
        zeta_pole];
end
phase_lead = struct('enabled', true, ...
    'gain', prod(pole_hz./zero_hz), ...
    'zero_hz', zero_hz, 'pole_hz', pole_hz, ...
    'notch_sections', notch_sections);
end

function x = xFromPhaseLead(phase_lead)
phase_lead = normalizePhaseLeadConfig(phase_lead);
log_centers = log(phase_lead.center_frequency_hz);
log_ratios = log(phase_lead.pole_hz./phase_lead.zero_hz);
notch = phase_lead.notch_sections;
x = [log_centers, log_ratios, log(notch(:, 1)).', ...
    log(notch(:, 2)./notch(:, 3)).', log(notch(:, 3)).'];
end

%% ----------------------------------------------------------------------
%% Search state, evaluation, ranking
%% ----------------------------------------------------------------------

function state = newRobustState(problem)
state = struct( ...
    'problem', problem, ...
    'config', problem.config, ...
    'best', [], ...
    'history', [], ...
    'sim_count', 0, ...
    'start_time', tic, ...
    'stage', '', ...
    'stage_index', 0, ...
    'stage_total', 0, ...
    'stage_start', tic, ...
    'last_progress_time', -Inf, ...
    'last_checkpoint_time', -Inf, ...
    'screen_result', []);
state.seen = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

function [state, candidate, was_cached] = evaluateRobustLogged(state, ...
        phase_lead_override, stage)
% Full evaluation: closed-loop simulation on the nominal plant plus
% full-grid nominal and scenario NCF margins.
key = robustCandidateKey(phase_lead_override);
was_cached = state.seen.isKey(key);
if was_cached
    candidate = state.seen(key);
    return
end
problem = state.problem;
sim = problem.helpers.evaluate(problem.nominal, phase_lead_override);
sim = addRobustObjectiveMetrics(sim, problem);
robust = robustNcfOfCandidate(problem, phase_lead_override);
feasible = robust.feasible_ncf && sim.metrics.stable ...
    && sim.metrics.stability_margin + 1e-9 ...
        >= problem.config.minimum_stability_margin ...
    && sim.metrics.minimum_damping_shortfall <= 1e-9;
candidate = struct( ...
    'phase_lead', sim.phase_lead, ...
    'metrics', sim.metrics, ...
    'robust', robust, ...
    'feasible', feasible, ...
    'objective', objectiveMetricValue(sim.metrics, problem.config, true), ...
    'shortfall', robust.nominal_shortfall + robust.robust_shortfall ...
        + 10*double(~sim.metrics.stable) ...
        + 10*sim.metrics.minimum_damping_shortfall);
state.seen(key) = candidate;
state.sim_count = state.sim_count + 1;
state.stage_index = state.stage_index + 1;
state.history = [state.history; robustHistoryEntry(stage, ...
    state.sim_count, candidate)];

if isempty(state.best) || robustCandidateBeats(candidate, state.best)
    state.best = candidate;
    if ~strcmp(stage, 'baseline')
        fprintf(['  * new best [%s %d/%d]: %s = %.4g %%, NCF nom = ' ...
            '%.4g, NCF worst = %.4g, feasible = %d | %s\n'], ...
            stage, state.stage_index, ...
            max(state.stage_total, state.stage_index), ...
            objectiveLabel(problem.config), candidate.objective, ...
            candidate.robust.ncf_nominal, ...
            candidate.robust.ncf_worst, candidate.feasible, ...
            robustPhaseLeadShort(candidate.phase_lead))
    end
    state = maybeSaveRobustCheckpoint(state, stage, false);
else
    state = printRobustProgress(state, false);
end
end

function key = robustCandidateKey(phase_lead_override)
phase_lead = normalizePhaseLeadConfig(phase_lead_override);
if ~phase_lead.enabled
    key = 'disabled';
    return
end
key = sprintf('%.6e_', phase_lead.gain, phase_lead.zero_hz, ...
    phase_lead.pole_hz, phase_lead.notch_sections(:).');
end

function better = robustCandidateBeats(a, b)
if a.feasible ~= b.feasible
    better = a.feasible;
    return
end
if a.feasible
    better = a.objective < b.objective;
else
    better = a.shortfall < b.shortfall ...
        || (a.shortfall == b.shortfall && a.objective < b.objective);
end
end

function entry = robustHistoryEntry(stage, trial, candidate)
notch = candidate.phase_lead.notch_sections;
entry = struct( ...
    'Stage', string(stage), ...
    'Trial', trial, ...
    'Feasible', candidate.feasible, ...
    'Objective', candidate.objective, ...
    'J2_percent', candidate.metrics.j2_percent, ...
    'J2_raw_percent', candidate.metrics.j2_raw_percent, ...
    'J4_percent', candidate.metrics.j4_percent, ...
    'J4_raw_percent', candidate.metrics.j4_raw_percent, ...
    'NCF_nominal', candidate.robust.ncf_nominal, ...
    'NCF_worst', candidate.robust.ncf_worst, ...
    'Shortfall', candidate.shortfall, ...
    'Zero_Hz', candidate.phase_lead.zero_hz, ...
    'Pole_Hz', candidate.phase_lead.pole_hz, ...
    'Gain', candidate.phase_lead.gain, ...
    'Notch_Hz', notch(:, 1).', ...
    'NotchZetaZero', notch(:, 2).', ...
    'NotchZetaPole', notch(:, 3).', ...
    'HighFrequencyGain', candidate.phase_lead.high_frequency_gain, ...
    'MaxPhaseLead_deg', candidate.phase_lead.max_phase_lead_deg, ...
    'StabilityMargin', candidate.metrics.stability_margin, ...
    'CoupledMinDamping', candidate.metrics.coupled_min_damping, ...
    'CoupledMinDamping_Hz', candidate.metrics.coupled_min_damping_hz, ...
    'Stable', candidate.metrics.stable, ...
    'EvalSeconds', candidate.metrics.eval_seconds);
end

function sim = addRobustObjectiveMetrics(sim, problem)
if isempty(sim.signals)
    j2_raw_percent = Inf;
else
    fs = 1/problem.nominal.sample_dt;
    [b, a] = butter(6, 20/(fs/2), 'low');
    dm = sim.signals.dm_sample(:);
    dm_filtfilt = filtfilt(b, a, dm - dm(1)) + dm(1);
    dd = sim.signals.dd_sample(:);
    j2_raw_percent = 100*std(dm_filtfilt - dd)/std(dd);
end
sim.metrics.j2_raw_percent = j2_raw_percent;
sim.metrics.j2_percent = round(100*j2_raw_percent)/100;
end

function value = objectiveMetricValue(metrics, config, raw)
suffix = '_percent';
if raw
    suffix = '_raw_percent';
end
value = metrics.([lower(config.objective_metric) suffix]);
end

function label = objectiveLabel(config)
label = upper(config.objective_metric);
end

function text = robustPhaseLeadShort(phase_lead)
if ~phase_lead.enabled
    text = 'disabled';
    return
end
sections = cell(1, phase_lead.section_count);
for section_id = 1:phase_lead.section_count
    if phase_lead.pole_hz(section_id) > phase_lead.zero_hz(section_id)
        kind = 'lead';
    else
        kind = 'lag';
    end
    sections{section_id} = sprintf('%s %.3g->%.3g Hz', kind, ...
        phase_lead.zero_hz(section_id), phase_lead.pole_hz(section_id));
end
for notch_id = 1:size(phase_lead.notch_sections, 1)
    sections{end+1} = sprintf('notch %.3g Hz (zz %.3g/zp %.3g)', ...
        phase_lead.notch_sections(notch_id, 1), ...
        phase_lead.notch_sections(notch_id, 2), ...
        phase_lead.notch_sections(notch_id, 3)); %#ok<AGROW>
end
text = sprintf('%s | HF gain %.3g', strjoin(sections, ', '), ...
    phase_lead.high_frequency_gain);
end

function state = beginRobustStage(state, stage, total)
state.stage = stage;
state.stage_index = 0;
state.stage_total = total;
state.stage_start = tic;
state.last_progress_time = -Inf;
end

function state = printRobustProgress(state, force)
config = state.config;
elapsed_since_print = toc(state.stage_start) - state.last_progress_time;
if ~force && elapsed_since_print < config.progress_interval_seconds
    return
end
elapsed = toc(state.stage_start);
total = max(state.stage_total, state.stage_index);
if isempty(state.best)
    best_text = 'best: none yet';
elseif state.best.feasible
    best_text = sprintf('best %s %.4g %% (NCF nom %.3g / worst %.3g)', ...
        objectiveLabel(config), state.best.objective, ...
        state.best.robust.ncf_nominal, ...
        state.best.robust.ncf_worst);
else
    best_text = sprintf('best (infeasible) shortfall %.4g', ...
        state.best.shortfall);
end
fprintf('  %s %d/%d | elapsed %.0f s | %s\n', state.stage, ...
    state.stage_index, total, elapsed, best_text)
state.last_progress_time = toc(state.stage_start);
end

function state = maybeSaveRobustCheckpoint(state, stage, force)
config = state.config;
if ~config.save_best_checkpoint || isempty(state.best)
    return
end
since_last = toc(state.start_time) - state.last_checkpoint_time;
if ~force && since_last < config.checkpoint_min_interval_seconds
    return
end
if isempty(config.best_checkpoint_file)
    checkpoint_file = fullfile(state.problem.project_root, ...
        'saved_results', 'phase_lead', ...
        'vHS_phase_lead_robust_best_checkpoint.mat');
else
    checkpoint_file = char(config.best_checkpoint_file);
end
best_checkpoint = state.best;
best_checkpoint_stage = string(stage);
best_checkpoint_updated_at = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));
save(checkpoint_file, 'best_checkpoint', 'best_checkpoint_stage', ...
    'best_checkpoint_updated_at')
state.last_checkpoint_time = toc(state.start_time);
end

%% ----------------------------------------------------------------------
%% Stage 1: analytic robust-NCF screening of the section space
%% ----------------------------------------------------------------------

function state = screenStageRobust(state)
config = state.config;
problem = state.problem;
stage_timer = tic;
n_section = config.phase_lead_section_count;
n_notch = config.notch_section_count;
n_sample = config.screen_sample_count;
fprintf(['\n[1/3] Analytic screening: %d candidates x %d sections ' ...
    '+ %d notch(es), %d scenarios\n'], n_sample, n_section, n_notch, ...
    numel(problem.scenarios.names))

rng(config.random_seed);
[lower_bounds, upper_bounds] = xBounds(config);
samples = quasiRandomSamples(n_sample, 2*n_section + 3*n_notch);
x_matrix = lower_bounds + samples.*(upper_bounds - lower_bounds);
x_matrix(:, 1:n_section) = sort(x_matrix(:, 1:n_section), 2);
if n_notch > 1
    notch_cols = 2*n_section + (1:n_notch);
    x_matrix(:, notch_cols) = sort(x_matrix(:, notch_cols), 2);
end
% Always include the pure-lead axis (all sections identical leads, any
% notch at identity depth) so a single-section-style optimum is never
% missed, plus near-identity candidates.
log_center_bounds = log(config.center_frequency_bounds_hz);
log_ratio_bounds = log(config.section_ratio_bounds);
axis_centers = linspace(log_center_bounds(1), log_center_bounds(2), 50).';
axis_ratios = linspace(max(log(1.01), log_ratio_bounds(1)), ...
    log_ratio_bounds(2), 100).';
[axis_center_grid, axis_ratio_grid] = ndgrid(axis_centers, ...
    axis_ratios(1:5:end));
axis_x = [repmat(axis_center_grid(:), 1, n_section), ...
    repmat(axis_ratio_grid(:)/n_section, 1, n_section)];
if n_notch > 0
    identity_notch = repmat([ ...
        repmat(mean(log(config.notch_frequency_bounds_hz)), 1, n_notch), ...
        zeros(1, n_notch), ...           % log depth = 0 -> identity
        zeros(1, n_notch)], ...          % log zeta_pole = 0
        size(axis_x, 1), 1);
    axis_x = [axis_x, identity_notch];
end
x_matrix = [x_matrix; axis_x];

[ncf_nominal, ncf_worst, proxy] = candidatesNcf(problem, x_matrix);
feasible = ncf_nominal + 1e-6 >= config.target_ncf_margin ...
    & ncf_worst + 1e-6 >= config.robust_ncf_target;
fprintf(['      done in %.1f s | analytic-feasible %d/%d (%.2f%%) | ' ...
    'max nominal NCF %.4g | max worst NCF %.4g\n'], toc(stage_timer), ...
    nnz(feasible), numel(feasible), 100*nnz(feasible)/numel(feasible), ...
    max(ncf_nominal), max(ncf_worst))
if ~any(feasible)
    fprintf(['      WARNING: no candidate satisfies both NCF targets ' ...
        'inside the bounds. The search will minimize the shortfall; ' ...
        'consider lowering targets or adding sections.\n'])
end
state.screen_result = struct('x_matrix', x_matrix, ...
    'ncf_nominal', ncf_nominal, 'ncf_worst', ncf_worst, ...
    'proxy', proxy, 'feasible', feasible);
end

function [lower_bounds, upper_bounds] = xBounds(config)
n_section = config.phase_lead_section_count;
n_notch = config.notch_section_count;
lower_bounds = [ ...
    repmat(log(config.center_frequency_bounds_hz(1)), 1, n_section), ...
    repmat(log(config.section_ratio_bounds(1)), 1, n_section), ...
    repmat(log(config.notch_frequency_bounds_hz(1)), 1, n_notch), ...
    repmat(log(config.notch_depth_bounds(1)), 1, n_notch), ...
    repmat(log(config.notch_zeta_pole_bounds(1)), 1, n_notch)];
upper_bounds = [ ...
    repmat(log(config.center_frequency_bounds_hz(2)), 1, n_section), ...
    repmat(log(config.section_ratio_bounds(2)), 1, n_section), ...
    repmat(log(config.notch_frequency_bounds_hz(2)), 1, n_notch), ...
    repmat(log(config.notch_depth_bounds(2)), 1, n_notch), ...
    repmat(log(config.notch_zeta_pole_bounds(2)), 1, n_notch)];
end

function samples = quasiRandomSamples(n_sample, n_dim)
if exist('sobolset', 'file') == 2
    sobol = scramble(sobolset(n_dim, 'Skip', 1), 'MatousekAffineOwen');
    samples = net(sobol, n_sample);
else
    samples = rand(n_sample, n_dim);
end
end

%% ----------------------------------------------------------------------
%% Stage 2: simulate the objective for promising screened candidates
%% ----------------------------------------------------------------------

function state = simStageRobust(state)
config = state.config;
screen = state.screen_result;
n_section = config.phase_lead_section_count;
n_notch = config.notch_section_count;
if any(screen.feasible)
    pool_ids = find(screen.feasible);
    [~, order] = sort(screen.proxy(pool_ids));
    ranked = pool_ids(order);
else
    shortfall = max(0, config.target_ncf_margin - screen.ncf_nominal) ...
        + max(0, config.robust_ncf_target - screen.ncf_worst);
    [~, ranked] = sort(shortfall);
    ranked = ranked(1:min(2000, numel(ranked)));
end
picks = diverseSubset(screen.x_matrix(ranked, :), config.sim_budget, ...
    config.sim_min_log_distance);
seeds = seedPhaseLeads(state.problem);
fprintf(['\n[2/3] Closed-loop simulation of %d seed(s) + %d ' ...
    'shortlisted candidates\n'], numel(seeds), numel(picks))
state = beginRobustStage(state, 'sim', numel(seeds) + numel(picks));
for seed_id = 1:numel(seeds)
    [state, ~] = evaluateRobustLogged(state, seeds{seed_id}, 'sim');
end
for pick_id = 1:numel(picks)
    x = screen.x_matrix(ranked(picks(pick_id)), :);
    [state, ~] = evaluateRobustLogged(state, ...
        phaseLeadFromX(x, n_section, n_notch), 'sim');
end
state = printRobustProgress(state, true);
state = maybeSaveRobustCheckpoint(state, 'sim', true);
end

function seeds = seedPhaseLeads(problem)
% Normalize config.seed_phase_leads entries (structs or saved MAT file
% names) into evaluable overrides; skip entries whose section or notch
% counts do not match the configured search space.
config = problem.config;
seeds = {};
for seed_id = 1:numel(config.seed_phase_leads)
    entry = config.seed_phase_leads{seed_id};
    if ischar(entry) || isstring(entry)
        file_path = char(entry);
        if ~isfile(file_path)
            file_path = fullfile(problem.project_root, ...
                'saved_results', 'phase_lead', char(entry));
        end
        if ~isfile(file_path)
            warning('optimize_vHS_phase_lead_robust:MissingSeedFile', ...
                'Seed phase_lead file not found: %s', char(entry))
            continue
        end
        loaded = load(file_path, 'phase_lead');
        entry = loaded.phase_lead;
    end
    phase_lead = normalizePhaseLeadConfig(entry);
    if phase_lead.section_count ~= config.phase_lead_section_count ...
            || size(phase_lead.notch_sections, 1) ...
                ~= config.notch_section_count
        warning('optimize_vHS_phase_lead_robust:SeedShapeMismatch', ...
            ['Seed %d skipped: it has %d section(s) + %d notch(es) ' ...
            'but the search space is configured for %d + %d.'], ...
            seed_id, phase_lead.section_count, ...
            size(phase_lead.notch_sections, 1), ...
            config.phase_lead_section_count, config.notch_section_count)
        continue
    end
    seeds{end+1} = phaseLeadOverrideOf(phase_lead); %#ok<AGROW>
end
end

function picks = diverseSubset(points, budget, min_distance)
% Greedy pick in ranked order, skipping points too close (1-norm in log
% space) to already-picked ones; backfills with skipped points if the
% budget is not met.
n_point = size(points, 1);
picks = zeros(0, 1);
skipped = zeros(0, 1);
for point_id = 1:n_point
    if numel(picks) >= budget
        break
    end
    if isempty(picks) || all(sum(abs(points(picks, :) ...
            - points(point_id, :)), 2) > min_distance)
        picks(end+1, 1) = point_id; %#ok<AGROW>
    else
        skipped(end+1, 1) = point_id; %#ok<AGROW>
    end
end
missing = budget - numel(picks);
if missing > 0 && ~isempty(skipped)
    picks = [picks; skipped(1:min(missing, numel(skipped)))];
end
end

%% ----------------------------------------------------------------------
%% Stage 3: fmincon polish (simulated objective, analytic NCF
%% constraints, ordered centers and notch frequencies)
%% ----------------------------------------------------------------------

function state = polishStageRobust(state)
config = state.config;
if ~config.use_fmincon_polish
    fprintf('\n[3/3] fmincon polish disabled by config.\n')
    return
end
if exist('fmincon', 'file') ~= 2
    fprintf('\n[3/3] fmincon polish skipped: Optimization Toolbox missing.\n')
    return
end
starts = robustPolishStarts(state);
if isempty(starts)
    fprintf('\n[3/3] fmincon polish skipped: no start points.\n')
    return
end
n_section = config.phase_lead_section_count;
n_notch = config.notch_section_count;
[lower_bounds, upper_bounds] = xBounds(config);
% Keep centers (and notch frequencies) ordered.
n_dim = 2*n_section + 3*n_notch;
order_A = zeros(0, n_dim);
for row = 1:n_section-1
    order_row = zeros(1, n_dim);
    order_row(row) = 1;
    order_row(row+1) = -1;
    order_A(end+1, :) = order_row; %#ok<AGROW>
end
for row = 1:n_notch-1
    order_row = zeros(1, n_dim);
    order_row(2*n_section + row) = 1;
    order_row(2*n_section + row + 1) = -1;
    order_A(end+1, :) = order_row; %#ok<AGROW>
end
order_b = zeros(size(order_A, 1), 1);
if isempty(order_A)
    order_A = [];
    order_b = [];
end
fprintf(['\n[3/3] fmincon polish (%d start(s), simulated %s ' ...
    'objective, analytic NCF constraints)\n'], size(starts, 1), ...
    objectiveLabel(config))
state = beginRobustStage(state, 'polish', ...
    size(starts, 1)*config.polish_max_evaluations);
options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'Display', 'off', ...
    'MaxIterations', config.polish_max_iterations, ...
    'MaxFunctionEvaluations', config.polish_max_evaluations, ...
    'FiniteDifferenceType', 'central');
restore_options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
    'Display', 'off', 'MaxIterations', 250, ...
    'MaxFunctionEvaluations', 2500, 'FiniteDifferenceType', 'central');
for start_id = 1:size(starts, 1)
    x0 = min(max(starts(start_id, :), lower_bounds), upper_bounds);
    try
        % Phase 1 (analytic only, no simulations): an infeasible start
        % (e.g. a warm-start seed that misses a newly added scenario)
        % is first pulled to the nearest feasible point by minimizing
        % the NCF shortfall; minimizing the objective from an infeasible
        % start lets the objective drag the iterate deeper into
        % infeasibility and fmincon stalls there.
        if analyticShortfall(x0) > 0
            x0 = fmincon(@analyticShortfall, x0, order_A, order_b, ...
                [], [], lower_bounds, upper_bounds, [], ...
                restore_options);
        end
        x_optimal = fmincon(@polishObjective, x0, order_A, order_b, ...
            [], [], lower_bounds, upper_bounds, @polishConstraint, ...
            options);
        [state, ~] = evaluateRobustLogged(state, ...
            phaseLeadFromX(x_optimal, n_section, n_notch), 'polish');
    catch err
        fprintf('      fmincon start %d failed: %s\n', start_id, ...
            err.message)
    end
end
state = printRobustProgress(state, true);
state = maybeSaveRobustCheckpoint(state, 'polish', true);

    function objective = polishObjective(x)
    [state, candidate] = evaluateRobustLogged(state, ...
        phaseLeadFromX(x, n_section, n_notch), 'polish');
    objective = candidate.objective;
    if ~isfinite(objective)
        objective = 1e6*(1 + candidate.metrics.max_abs_pole);
    end
    end

    function [inequality, equality] = polishConstraint(x)
    phase_lead = phaseLeadFromX(x, n_section, n_notch);
    robust = robustNcfOfCandidate(state.problem, phase_lead);
    inequality = [ ...
        state.config.target_ncf_margin - robust.ncf_nominal; ...
        state.config.robust_ncf_target - robust.ncf_worst];
    if state.config.minimum_coupled_pole_damping > 0
        % anti-ringing condition on the coupled closed-loop poles (cap
        % the possibly-Inf min damping: fmincon rejects nonfinite
        % constraint values even when satisfied)
        nominal = state.problem.nominal;
        helpers = state.problem.helpers;
        lead = helpers.discrete_siso(buildPhaseLeadFilter( ...
            normalizePhaseLeadConfig(phase_lead), nominal.sample_dt), ...
            nominal.sample_dt);
        loop = helpers.build_closed_loop(nominal, lead);
        damping = coupledPoleDamping(eig(loop.A), nominal.sample_dt, ...
            state.config.coupled_pole_damping_band_hz);
        inequality(end+1, 1) = state.config.minimum_coupled_pole_damping ...
            - min(damping.min_damping, 10);
    end
    equality = [];
    end

    function value = analyticShortfall(x)
    robust = robustNcfOfCandidate(state.problem, ...
        phaseLeadFromX(x, n_section, n_notch));
    value = robust.nominal_shortfall + robust.robust_shortfall;
    end
end

function starts = robustPolishStarts(state)
config = state.config;
history = state.history;
if isempty(history)
    starts = [];
    return
end
enabled = arrayfun(@(entry) entry.Gain > 0, history);
history = history(enabled);
ranking = sortrows([~[history.Feasible].', [history.Objective].', ...
    [history.Shortfall].', (1:numel(history)).'], [1 3 2]);
if any([history.Feasible])
    feasible_rows = find([history.Feasible]);
    [~, order] = sort([history(feasible_rows).Objective]);
    candidates_order = feasible_rows(order);
    % Bonus starts: near-feasible candidates with a better objective
    % than the best feasible one (e.g. a warm-start seed that misses a
    % new, tighter constraint by a hair) are the most promising places
    % for fmincon to restore feasibility cheaply.
    best_feasible_objective = ...
        history(candidates_order(1)).Objective;
    near_rows = find(~[history.Feasible] ...
        & [history.Shortfall] < 0.15 ...
        & [history.Objective] < best_feasible_objective);
    [~, order] = sort([history(near_rows).Objective]);
    candidates_order = [near_rows(order(1:min(2, numel(order)))), ...
        candidates_order];
else
    candidates_order = ranking(:, 4).';
end
n_dim = 2*config.phase_lead_section_count ...
    + 3*config.notch_section_count;
starts = zeros(0, n_dim);
for rank_id = candidates_order
    entry = history(rank_id);
    x = xFromPhaseLead(struct('enabled', true, 'gain', entry.Gain, ...
        'zero_hz', entry.Zero_Hz, 'pole_hz', entry.Pole_Hz, ...
        'notch_sections', [entry.Notch_Hz(:), ...
            entry.NotchZetaZero(:), entry.NotchZetaPole(:)]));
    if isempty(starts) || all(sum(abs(starts - x), 2) > 0.2)
        starts(end+1, :) = x; %#ok<AGROW>
    end
    if size(starts, 1) >= config.polish_start_count
        break
    end
end
end

%% ----------------------------------------------------------------------
%% Finalization: damage-state validation, report, saving, plots
%% ----------------------------------------------------------------------

function result = finalizeRobust(state, baseline, project_root, ...
        total_timer)
config = state.config;
problem = state.problem;
fprintf('\nSearch finished: %d simulations in %.0f s.\n', ...
    state.sim_count, toc(state.start_time))

best = state.best;
if isempty(best) || ~best.phase_lead.enabled
    best = baseline;
end

designs = collectReportDesigns(problem, baseline, best);
report = buildRobustReport(problem, designs);
constraint_summary = robustConstraintSummary(config, problem, best);

fprintf('\n--- Robustness report ---\n')
disp(report.table)
fprintf('\n--- Best constraint summary ---\n')
disp(constraint_summary.table)
if ~best.feasible
    fprintf(['NOTE: the targets (nominal %.4g / robust %.4g) were not ' ...
        'reached inside the bounds; the reported best minimizes the ' ...
        'shortfall. Consider lowering targets or adding sections.\n'], ...
        config.target_ncf_margin, config.robust_ncf_target)
end
fprintf('\nRecommended phase_lead configuration:\nphase_lead = %s;\n', ...
    robustPhaseLeadLiteral(best.phase_lead))

history_table = struct2table(state.history);
history_table = sortrows(history_table, {'Feasible', 'Objective'}, ...
    {'descend', 'ascend'});

saved_path = '';
if config.save_results
    saved_path = saveRobustPhaseLeadFile(project_root, config, ...
        problem.nominal.pid_values, best, baseline, report, history_table);
    fprintf('\nSaved robust phase_lead result = %s\n', saved_path)
end

if config.plot_results
    plotRobustResults(problem, report, state, best, constraint_summary)
end

if config.print_validation_tables && problem.has_damage_states
    best_row = strcmp(report.table.Design, 'best');
    for state_id = 1:numel(problem.damage_states)
        label = matlab.lang.makeValidName( ...
            problem.damage_states(state_id).label);
        metric_field = [objectiveLabel(config) '_' label];
        fprintf(['Identified state %s: best NCF = %.4g, %s = %.4g %%, ' ...
            'stable = %d\n'], problem.damage_states(state_id).label, ...
            report.table.(['NCF_' label])(best_row), ...
            objectiveLabel(config), report.table.(metric_field)(best_row), ...
            report.table.(['Stable_' label])(best_row))
    end
end

fprintf('\nPID gains used:\n')
printPidGains('healthy', problem.nominal.pid_values)

fprintf('\nTotal robust optimizer time: %.0f s (%d simulations)\n', ...
    toc(total_timer), state.sim_count)

result = struct( ...
    'best_phase_lead', best.phase_lead, ...
    'best_metrics', best.metrics, ...
    'best_robust', best.robust, ...
    'constraint_summary', constraint_summary, ...
    'baseline_metrics', baseline.metrics, ...
    'baseline_robust', baseline.robust, ...
    'report', report, ...
    'history_table', history_table, ...
    'config', config, ...
    'sim_count', state.sim_count, ...
    'saved_path', saved_path);
end

function printPidGains(label, pid_values)
fprintf('  %s: P = %.6g, I = %.6g, D = %.6g, N = %.6g\n', ...
    label, pid_values.P, pid_values.I, pid_values.D, ...
    pid_values.derivative_filter_N)
end

function summary = robustConstraintSummary(config, problem, best)
names = ["Nominal NCF margin"; "Robust NCF margin"; ...
    "Coupled-pole damping"; "Stability margin"; ...
    "PID*H_dc_dm NCF margin"];
targets = [config.target_ncf_margin; config.robust_ncf_target; ...
    config.minimum_coupled_pole_damping; config.minimum_stability_margin; ...
    NaN];
actuator_response = squeeze(freqresp(problem.nominal.actuator_open_loop, ...
    problem.nominal.margin_frequency_rad_s));
actual = [best.robust.ncf_nominal; best.robust.ncf_worst; ...
    best.metrics.coupled_min_damping; best.metrics.stability_margin];
actual(end+1, 1) = ncfOfResponse(actuator_response);
enforced = [true; true; true; true; false];
passed = actual >= targets;
passed(~enforced) = true;
summary.table = table(names, targets, actual, enforced, passed, ...
    'VariableNames', {'Constraint', 'Target', 'Achieved', 'Enforced', ...
    'Passed'});
summary.coupled_pole_damping_hz = ...
    best.metrics.coupled_min_damping_hz;
end

function designs = collectReportDesigns(problem, baseline, best)
designs = struct('name', 'baseline', 'phase_lead', ...
    baseline.phase_lead, 'candidate', baseline);
designs(2) = struct('name', 'best', 'phase_lead', best.phase_lead, ...
    'candidate', best);
for file_id = 1:numel(problem.config.compare_phase_lead_files)
    file_name = problem.config.compare_phase_lead_files{file_id};
    file_path = char(file_name);
    if ~isfile(file_path)
        file_path = fullfile(problem.project_root, 'saved_results', ...
            'phase_lead', char(file_name));
    end
    if ~isfile(file_path)
        warning('optimize_vHS_phase_lead_robust:MissingCompareFile', ...
            'Comparison phase_lead file not found: %s', char(file_name))
        continue
    end
    loaded = load(file_path, 'phase_lead');
    [~, short_name] = fileparts(file_path);
    designs(end+1) = struct('name', short_name, ...
        'phase_lead', normalizePhaseLeadConfig(loaded.phase_lead), ...
        'candidate', []); %#ok<AGROW>
end
end

function report = buildRobustReport(problem, designs)
config = problem.config;
helpers = problem.helpers;
scenarios = problem.scenarios;
n_states = scenarios.n_states;
overshoots = config.template_lambda_grid( ...
    config.template_lambda_grid > 1) - 1;
lambda_max = n_states + max([overshoots, 0.15]);
lambda_grid = 0:config.report_lambda_step:lambda_max;
n_design = numel(designs);
rows = cell(n_design, 1);
curves = struct('lambda', lambda_grid, 'ncf', ...
    zeros(n_design, numel(lambda_grid)), 'names', {{designs.name}}, ...
    'n_states', n_states, 'state_labels', {scenarios.state_labels});
frequency_hz = problem.nominal.margin_frequency_rad_s/(2*pi);
distance = struct('frequency_hz', frequency_hz, ...
    'healthy', zeros(numel(frequency_hz), n_design), ...
    'states', zeros(numel(frequency_hz), n_design, max(n_states, 1)), ...
    'state_labels', {scenarios.state_labels});

state_columns = cell(1, 3*n_states);
for design_id = 1:n_design
    design = designs(design_id);
    override = phaseLeadOverrideOf(design.phase_lead);
    if isempty(design.candidate)
        sim = evaluateWithMatchedSections(helpers, problem.nominal, ...
            design.phase_lead);
        sim = addRobustObjectiveMetrics(sim, problem);
        robust = robustNcfOfCandidate(problem, override);
    else
        sim = design.candidate;
        robust = design.candidate.robust;
    end
    lead_response = leadResponseOnGrid( ...
        problem.nominal.margin_bilinear_s, override);
    nominal_response = problem.nominal.base_open_loop_response(:) ...
        .*lead_response;
    distance.healthy(:, design_id) = abs(1 + nominal_response) ...
        ./sqrt(2*(1 + abs(nominal_response).^2));

    if n_states > 0
        for lambda_id = 1:numel(lambda_grid)
            scenario_response = nominal_response.*exp(pathLogDelta( ...
                scenarios.segment_logs, lambda_grid(lambda_id)));
            curves.ncf(design_id, lambda_id) = ...
                ncfOfResponse(scenario_response);
        end
        for state_id = 1:n_states
            state_problem = problem.damage_states(state_id).problem;
            state_response = state_problem.base_open_loop_response(:) ...
                .*lead_response;
            distance.states(:, design_id, state_id) = ...
                abs(1 + state_response) ...
                ./sqrt(2*(1 + abs(state_response).^2));
            state_sim = evaluateWithMatchedSections(helpers, ...
                state_problem, design.phase_lead);
            state_sim = addRobustObjectiveMetrics(state_sim, problem);
            state_columns{3*state_id - 2}(design_id, 1) = ...
                ncfOfResponse(state_response);
            state_columns{3*state_id - 1}(design_id, 1) = ...
                objectiveMetricValue(state_sim.metrics, config, false);
            state_columns{3*state_id}(design_id, 1) = ...
                double(state_sim.metrics.stable);
        end
    else
        curves.ncf(design_id, :) = NaN;
    end
    rows{design_id} = {string(design.name), ...
        objectiveMetricValue(sim.metrics, config, false), robust.ncf_nominal, ...
        robust.ncf_worst, string(robust.worst_scenario_name), ...
        design.phase_lead.high_frequency_gain, ...
        design.phase_lead.max_phase_lead_deg};
end

report_cells = vertcat(rows{:});
report.table = cell2table(report_cells, 'VariableNames', ...
    {'Design', [objectiveLabel(config) '_healthy'], 'NCF_healthy', ...
    'NCF_worst_scenario', ...
    'WorstScenario', 'HighFrequencyGain', 'MaxPhaseLead_deg'});
for state_id = 1:n_states
    label = matlab.lang.makeValidName(scenarios.state_labels{state_id});
    report.table.(['NCF_' label]) = state_columns{3*state_id - 2};
    report.table.([objectiveLabel(config) '_' label]) = ...
        state_columns{3*state_id - 1};
    report.table.(['Stable_' label]) = ...
        logical(state_columns{3*state_id});
end
report.curves = curves;
report.distance = distance;
report.designs = designs;
end

function candidate = evaluateWithMatchedSections(helpers, ...
        state_problem, phase_lead)
% The v2 evaluator normalizes overrides against the configured section
% count; comparison designs may have a different order than the search.
override = phaseLeadOverrideOf(phase_lead);
if ~isempty(override)
    state_problem.config.phase_lead_section_count = ...
        numel(override.zero_hz);
end
candidate = helpers.evaluate(state_problem, override);
end

function override = phaseLeadOverrideOf(phase_lead)
if ~phase_lead.enabled
    override = [];
    return
end
override = struct('enabled', true, 'gain', phase_lead.gain, ...
    'zero_hz', phase_lead.zero_hz, 'pole_hz', phase_lead.pole_hz, ...
    'notch_sections', phase_lead.notch_sections);
end

function text = robustPhaseLeadLiteral(phase_lead)
if ~phase_lead.enabled
    text = '[]';
    return
end
zero_text = strjoin(arrayfun(@(v) sprintf('%.12g', v), ...
    phase_lead.zero_hz, 'UniformOutput', false), ' ');
pole_text = strjoin(arrayfun(@(v) sprintf('%.12g', v), ...
    phase_lead.pole_hz, 'UniformOutput', false), ' ');
text = sprintf(['struct(''enabled'', true, ''gain'', %.12g, ' ...
    '''zero_hz'', [%s], ''pole_hz'', [%s]'], phase_lead.gain, ...
    zero_text, pole_text);
if ~isempty(phase_lead.notch_sections)
    notch_rows = arrayfun(@(row) sprintf('%.12g %.12g %.12g', ...
        phase_lead.notch_sections(row, 1), ...
        phase_lead.notch_sections(row, 2), ...
        phase_lead.notch_sections(row, 3)), ...
        (1:size(phase_lead.notch_sections, 1)).', ...
        'UniformOutput', false);
    text = sprintf('%s, ''notch_sections'', [%s]', text, ...
        strjoin(notch_rows, '; '));
end
text = [text ')'];
end

function saved_path = saveRobustPhaseLeadFile(project_root, config, ...
        pid_values, best, baseline, report, history_table)
phase_lead_dir = fullfile(project_root, 'saved_results', 'phase_lead');
if ~exist(phase_lead_dir, 'dir')
    mkdir(phase_lead_dir)
end
[~, name] = fileparts(char(config.phase_lead_file_name));
saved_path = fullfile(phase_lead_dir, [name '.mat']);

phase_lead = best.phase_lead;
phase_lead_tf = continuousRobustPhaseLeadTf(phase_lead);
metrics = best.metrics;
metrics.ncf_nominal = best.robust.ncf_nominal;
metrics.ncf_worst_scenario = best.robust.ncf_worst;
best_phase_lead = phase_lead;
best_metrics = metrics;
baseline_metrics = baseline.metrics;
recommended_phase_lead_override = phaseLeadOverrideOf(phase_lead);
robust_report_table = report.table;
robust_ncf_lambda_curves = report.curves;
optimization_result_table = history_table;
phase_lead_label = 'robust';
phase_lead_name = [name '.mat'];
created_at = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
save(saved_path, 'phase_lead_tf', 'phase_lead', 'metrics', 'pid_values', ...
    'phase_lead_label', 'phase_lead_name', 'created_at', 'config', ...
    'baseline_metrics', 'best_phase_lead', 'best_metrics', ...
    'recommended_phase_lead_override', 'robust_report_table', ...
    'robust_ncf_lambda_curves', 'optimization_result_table')
saved = load(saved_path, 'phase_lead');
assert(isequaln(saved.phase_lead, phase_lead), ...
    'optimize_vHS_phase_lead_robust:SaveFailed', ...
    'Saved phase_lead file does not match the selected candidate.')
end

function phase_lead_tf = continuousRobustPhaseLeadTf(phase_lead)
% Continuous filter including notch sections; vHS.m consumes exactly
% this transfer function (c2d tustin), so notches flow into the hybrid
% simulation without further changes.
if ~phase_lead.enabled
    phase_lead_tf = tf(1);
    return
end
phase_lead_tf = phase_lead.gain ...
    *tf(poly(-phase_lead.zero_rad_s), poly(-phase_lead.pole_rad_s));
for notch_id = 1:size(phase_lead.notch_sections, 1)
    w = 2*pi*phase_lead.notch_sections(notch_id, 1);
    zeta_zero = phase_lead.notch_sections(notch_id, 2);
    zeta_pole = phase_lead.notch_sections(notch_id, 3);
    phase_lead_tf = phase_lead_tf ...
        *tf([1, 2*zeta_zero*w, w^2], [1, 2*zeta_pole*w, w^2]);
end
end

%% ----------------------------------------------------------------------
%% Plots
%% ----------------------------------------------------------------------

function plotRobustResults(problem, report, state, best, constraint_summary)
colors = robustPlotColors();
figures = gobjects(0);
n_states = report.curves.n_states;

% 1. Target versus achieved values for every hard optimization constraint.
figures(end+1) = plotRobustConstraintSummary(constraint_summary, colors);

% 2. NCF degradation along the damage path.
if n_states > 0
    figures(end+1) = figure('Color', 'w', ...
        'Name', 'robust phase_lead: NCF vs damage fraction');
    hold on
    for design_id = 1:numel(report.designs)
        plot(report.curves.lambda, report.curves.ncf(design_id, :), ...
            'LineWidth', 2, 'Color', designColor(colors, design_id), ...
            'DisplayName', report.curves.names{design_id})
    end
    yline(problem.config.target_ncf_margin, 'k--', 'nominal target', ...
        'HandleVisibility', 'off')
    yline(problem.config.robust_ncf_target, 'k:', 'robust target', ...
        'HandleVisibility', 'off')
    for state_id = 1:n_states
        xline(state_id, 'k-', report.curves.state_labels{state_id}, ...
            'LineWidth', 0.8, 'HandleVisibility', 'off')
    end
    hold off
    grid on
    xlabel(['damage path coordinate \lambda  ' ...
        '(integer = identified state)'])
    ylabel('NCF margin')
    title('NCF margin along the measured damage path')
    legend('Location', 'best', 'Interpreter', 'none')
end

% 3. Phase lead frequency response.
figures(end+1) = figure('Color', 'w', ...
    'Name', 'robust phase_lead: filter response');
frequency_hz = logspace(log10(0.1), log10(200), 800).';
s = 1i*2*pi*frequency_hz;
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
magnitude_axis = nexttile;
hold(magnitude_axis, 'on')
phase_axis = nexttile;
hold(phase_axis, 'on')
for design_id = 1:numel(report.designs)
    phase_lead = report.designs(design_id).phase_lead;
    if ~phase_lead.enabled
        response = ones(size(s));
    else
        response = phase_lead.gain*ones(size(s));
        for section_id = 1:phase_lead.section_count
            response = response ...
                .*(s + phase_lead.zero_rad_s(section_id)) ...
                ./(s + phase_lead.pole_rad_s(section_id));
        end
        for notch_id = 1:size(phase_lead.notch_sections, 1)
            w = 2*pi*phase_lead.notch_sections(notch_id, 1);
            zeta_zero = phase_lead.notch_sections(notch_id, 2);
            zeta_pole = phase_lead.notch_sections(notch_id, 3);
            response = response ...
                .*(s.^2 + 2*zeta_zero*w*s + w^2) ...
                ./(s.^2 + 2*zeta_pole*w*s + w^2);
        end
    end
    color = designColor(colors, design_id);
    semilogx(magnitude_axis, frequency_hz, 20*log10(abs(response)), ...
        'LineWidth', 2, 'Color', color, ...
        'DisplayName', report.curves.names{design_id});
    semilogx(phase_axis, frequency_hz, ...
        unwrap(angle(response))*180/pi, 'LineWidth', 2, ...
        'Color', color, 'DisplayName', report.curves.names{design_id});
end
hold(magnitude_axis, 'off')
hold(phase_axis, 'off')
set([magnitude_axis, phase_axis], 'XScale', 'log')
grid(magnitude_axis, 'on')
grid(phase_axis, 'on')
ylabel(magnitude_axis, 'Magnitude (dB)')
ylabel(phase_axis, 'Phase (deg)')
xlabel(phase_axis, 'Frequency (Hz)')
legend(magnitude_axis, 'Location', 'best', 'Interpreter', 'none')
title(layout, 'Phase lead prefilter G_T frequency response')

% 4. NCF distance-to-critical-point vs frequency (healthy + each state).
figures(end+1) = figure('Color', 'w', ...
    'Name', 'robust phase_lead: NCF distance vs frequency');
layout = tiledlayout(1 + n_states, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
axis_handle = nexttile;
hold(axis_handle, 'on')
for design_id = 1:numel(report.designs)
    semilogx(axis_handle, report.distance.frequency_hz, ...
        report.distance.healthy(:, design_id), 'LineWidth', 1.6, ...
        'Color', designColor(colors, design_id), ...
        'DisplayName', report.curves.names{design_id});
end
hold(axis_handle, 'off')
set(axis_handle, 'XScale', 'log')
grid(axis_handle, 'on')
ylabel(axis_handle, 'd(\omega) healthy')
legend(axis_handle, 'Location', 'best', 'Interpreter', 'none')
for state_id = 1:n_states
    axis_handle = nexttile;
    hold(axis_handle, 'on')
    for design_id = 1:numel(report.designs)
        semilogx(axis_handle, report.distance.frequency_hz, ...
            report.distance.states(:, design_id, state_id), ...
            'LineWidth', 1.6, ...
            'Color', designColor(colors, design_id), ...
            'DisplayName', report.curves.names{design_id});
    end
    hold(axis_handle, 'off')
    set(axis_handle, 'XScale', 'log')
    grid(axis_handle, 'on')
    ylabel(axis_handle, sprintf('d(\\omega) %s', ...
        report.distance.state_labels{state_id}))
end
xlabel(axis_handle, 'Frequency (Hz)')
title(layout, ['NCF distance to the critical point ' ...
    '(margin = curve minimum)'])

% 5. Objective vs worst-scenario NCF scatter of simulated candidates.
history = state.history;
enabled = arrayfun(@(entry) entry.Gain > 0 ...
    && isfinite(entry.Objective), history);
history = history(enabled);
if ~isempty(history)
    figures(end+1) = figure('Color', 'w', ...
        'Name', ['robust phase_lead: ' objectiveLabel(state.config) ...
        ' vs worst-case NCF']);
    feasible_mask = [history.Feasible];
    scatter([history(~feasible_mask).NCF_worst], ...
        [history(~feasible_mask).Objective], 18, colors.red, ...
        'filled', 'MarkerFaceAlpha', 0.45, ...
        'DisplayName', 'infeasible')
    hold on
    scatter([history(feasible_mask).NCF_worst], ...
        [history(feasible_mask).Objective], 22, colors.green, ...
        'filled', 'MarkerFaceAlpha', 0.7, 'DisplayName', 'feasible')
    if best.phase_lead.enabled
        plot(best.robust.ncf_worst, best.objective, ...
            'p', 'MarkerSize', 16, 'MarkerFaceColor', ...
            colors.copperwood, 'MarkerEdgeColor', 'k', ...
            'DisplayName', 'best')
    end
    xline(state.config.robust_ncf_target, 'k:', ...
        'HandleVisibility', 'off')
    hold off
    grid on
    xlabel('worst-scenario NCF margin')
    ylabel([objectiveLabel(state.config) ' (raw, %)'])
    title('Simulated candidates: performance vs damage robustness')
    legend('Location', 'best')
end

exportRobustFigures(problem.config, figures)
end

function figure_handle = plotRobustConstraintSummary(summary, colors)
figure_handle = figure('Color', 'w', ...
    'Name', 'robust phase_lead: constraint summary');
layout = tiledlayout(2, 2, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
constraint_table = summary.table(summary.table.Enforced, :);
for constraint_id = 1:height(constraint_table)
    axis_handle = nexttile;
    target = constraint_table.Target(constraint_id);
    actual = constraint_table.Achieved(constraint_id);
    passed = constraint_table.Passed(constraint_id);
    plotted_actual = actual;
    if ~isfinite(plotted_actual)
        plotted_actual = max(2*target, 1);
    end
    bar_handle = bar(axis_handle, [target, plotted_actual], ...
        'FaceColor', 'flat');
    bar_handle.CData = [0 0 0; ...
        colors.green*double(passed) + colors.red*double(~passed)];
    grid(axis_handle, 'on')
    xticks(axis_handle, [1 2])
    xticklabels(axis_handle, {'target', 'achieved'})
    ylabel(axis_handle, 'margin')
    actual_text = sprintf('%.4g', actual);
    if ~isfinite(actual)
        actual_text = 'Inf (no pole in damping band)';
    end
    if constraint_id == 3 && isfinite(summary.coupled_pole_damping_hz)
        actual_text = sprintf('%s at %.4g Hz', actual_text, ...
            summary.coupled_pole_damping_hz);
    end
    title(axis_handle, sprintf('%s\nactual = %s', ...
        constraint_table.Constraint(constraint_id), actual_text))
end
title(layout, 'Final hard-constraint targets and achieved values')
end

function color = designColor(colors, design_id)
palette = [colors.blue; colors.copperwood; colors.green; ...
    colors.purple; colors.red; 0.3 0.3 0.3];
color = palette(mod(design_id - 1, size(palette, 1)) + 1, :);
end

function exportRobustFigures(config, figures)
if isempty(config.plot_export_dir)
    return
end
if ~exist(config.plot_export_dir, 'dir')
    mkdir(config.plot_export_dir)
end
for figure_id = 1:numel(figures)
    figure_handle = figures(figure_id);
    if ~isgraphics(figure_handle)
        continue
    end
    file_name = lower(regexprep(get(figure_handle, 'Name'), ...
        '[^a-zA-Z0-9]+', '_'));
    exportgraphics(figure_handle, fullfile(config.plot_export_dir, ...
        [file_name '.png']), 'Resolution', 150)
end
end

function colors = robustPlotColors()
colors.green = sscanf('39BF5E', '%2x%2x%2x', [1 3])/255;
colors.blue = sscanf('007CA8', '%2x%2x%2x', [1 3])/255;
colors.copperwood = sscanf('AC6420', '%2x%2x%2x', [1 3])/255;
colors.red = sscanf('901500', '%2x%2x%2x', [1 3])/255;
colors.purple = sscanf('74058A', '%2x%2x%2x', [1 3])/255;
end
