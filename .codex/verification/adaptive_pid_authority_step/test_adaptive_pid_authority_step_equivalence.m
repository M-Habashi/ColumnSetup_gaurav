function test_adaptive_pid_authority_step_equivalence()
%TEST_ADAPTIVE_PID_AUTHORITY_STEP_EQUIVALENCE Verify scalar step matches original law.

script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(fileparts(script_dir)));
main_dir = fullfile(repo_root, 'main');
step_dir = fullfile(main_dir, 'research', 'adaptive_PID', 'codex');
addpath(step_dir);
addpath(fullfile(step_dir, 'params'));

cfg = adaptive_pid_config();
tol = 5e-15;
rng(9137);

sequences = buildMarginSequences(step_dir);
[max_abs_error_seq, max_case_seq, n_steps_seq] = runSequenceTests(sequences, cfg);
[max_abs_error_rand, max_case_rand, n_steps_rand] = runRandomStateTests(cfg);

max_abs_error = max(max_abs_error_seq, max_abs_error_rand);
assert(max_abs_error <= tol, ...
    'adaptive_pid_authority_step mismatch: max abs error %.17g > %.17g', ...
    max_abs_error, tol);

result = struct();
result.test = 'adaptive_pid_authority_step_equivalence';
result.tolerance = tol;
result.max_abs_error = max_abs_error;
result.max_sequence_error = max_abs_error_seq;
result.max_random_state_error = max_abs_error_rand;
result.max_sequence_case = max_case_seq;
result.max_random_state_case = max_case_rand;
result.sequence_steps = n_steps_seq;
result.random_state_steps = n_steps_rand;
result.created = datetime('now');
save(fullfile(script_dir, 'adaptive_pid_authority_step_equivalence.mat'), ...
    'result');

fprintf('adaptive_pid_authority_step equivalence passed.\n');
fprintf('  sequence steps:      %d\n', n_steps_seq);
fprintf('  random state steps:  %d\n', n_steps_rand);
fprintf('  max abs error:       %.17g\n', max_abs_error);
fprintf('  tolerance:           %.17g\n', tol);
end

function sequences = buildMarginSequences(step_dir)
base = [0.58 0.57 0.56 0.54 0.56 0.59 0.62 0.61];
severe = [0.59 0.58 0.07 0.18 0.32 0.42 0.50 0.57 0.61];
moderate = [0.58 0.49 0.49 0.51 0.48 0.48 0.55 0.58];
dropout = [0.58 NaN 0.57 Inf 0.49 0.49 -Inf 0.60];
thresholds = [0.500 0.495 0.494 0.380 0.379 0.381 0.535 0.536];
recovery = [0.07 0.12 0.18 0.24 0.31 0.39 0.48 0.55 0.62 0.70];
random_like = 0.54 + 0.08*randn(1, 600);
random_like(25:30:end) = 0.47;
random_like(26:30:end) = 0.47;
random_like(80:90:end) = 0.12;
random_like(150:175:end) = NaN;
sequences = {base, severe, moderate, dropout, thresholds, recovery, ...
    random_like};
result_file = fullfile(step_dir, 'results', 'adaptive_pid_result.mat');
if exist(result_file, 'file')
    S = load(result_file, 'result');
    for i = 1:numel(S.result.adaptive)
        sequences{end + 1} = S.result.adaptive(i).ncf_m91(:).'; %#ok<AGROW>
    end
end
end

function [max_abs_error, max_case, n_steps] = runSequenceTests(sequences, cfg)
max_abs_error = 0;
max_case = 0;
n_steps = 0;
for i = 1:numel(sequences)
    margins = sequences{i};
    state_ref = initialReferenceState(cfg);
    authority_ref = 1;
    authority_new = 1;
    margin_filtered = cfg.target_margin;
    margin_guarded = cfg.target_margin;
    above_count = 0;
    below_count = 0;
    for k = 1:numel(margins)
        [authority_ref, state_ref, down_ref] = originalReferenceUpdate( ...
            authority_ref, state_ref, margins(k), cfg);
        [authority_new, margin_filtered, margin_guarded, ...
            above_count, below_count, down_new] = callStepFunction( ...
            margins(k), authority_new, margin_filtered, margin_guarded, ...
            above_count, below_count, cfg);

        values_ref = [authority_ref, state_ref.margin_filtered, ...
            state_ref.margin_guarded, state_ref.above_count, ...
            state_ref.below_count, down_ref];
        values_new = [authority_new, margin_filtered, margin_guarded, ...
            above_count, below_count, down_new];
        err = max(abs(values_ref - values_new));
        if err > max_abs_error
            max_abs_error = err;
            max_case = 1000*i + k;
        end
        n_steps = n_steps + 1;
    end
end
end

function [max_abs_error, max_case, n_steps] = runRandomStateTests(cfg)
max_abs_error = 0;
max_case = 0;
n_steps = 5000;
for k = 1:n_steps
    margin = 0.62 + 0.22*randn();
    if mod(k, 37) == 0
        margin = 0.05 + 0.25*rand();
    elseif mod(k, 53) == 0
        margin = 0.45 + 0.05*rand();
    elseif mod(k, 71) == 0
        margin = NaN;
    end

    authority = cfg.authority_gain.a_min ...
        + (cfg.authority_gain.a_max - cfg.authority_gain.a_min)*rand();
    state_ref = initialReferenceState(cfg);
    margin_filtered0 = rand();
    margin_guarded0 = rand();
    above_count0 = randi([0 30]) - 1;
    below_count0 = randi([0 6]) - 1;
    state_ref.margin_filtered = margin_filtered0;
    state_ref.margin_guarded = margin_guarded0;
    state_ref.above_count = above_count0;
    state_ref.below_count = below_count0;

    [authority_ref, state_ref, down_ref] = originalReferenceUpdate( ...
        authority, state_ref, margin, cfg);
    [authority_new, margin_filtered, margin_guarded, above_count, ...
        below_count, down_new] = callStepFunction(margin, authority, ...
        margin_filtered0, margin_guarded0, above_count0, below_count0, cfg);

    values_ref = [authority_ref, state_ref.margin_filtered, ...
        state_ref.margin_guarded, state_ref.above_count, ...
        state_ref.below_count, down_ref];
    values_new = [authority_new, margin_filtered, margin_guarded, ...
        above_count, below_count, down_new];
    err = max(abs(values_ref - values_new));
    if err > max_abs_error
        max_abs_error = err;
        max_case = k;
    end
end
end

function state = initialReferenceState(cfg)
state = struct('margin_filtered', cfg.target_margin, ...
    'margin_guarded', cfg.target_margin, 'above_count', 0, ...
    'below_count', 0);
end

function [authority, state, down_confirmed] = originalReferenceUpdate( ...
        authority, state, margin, cfg)
down_confirmed = 0;
if ~isfinite(margin)
    return
end
p = cfg.authority_gain;
state.margin_filtered = (1 - p.margin_filter_alpha)*state.margin_filtered ...
    + p.margin_filter_alpha*margin;
is_low = margin < cfg.target_margin - p.down_deadband;
if is_low
    state.below_count = state.below_count + 1;
else
    state.below_count = 0;
end
down_confirmed = double(is_low && (margin <= p.down_immediate_margin ...
    || state.below_count >= p.down_confirm_n));
severe_low = is_low && margin <= p.down_immediate_margin;

if severe_low && margin < state.margin_guarded
    state.margin_guarded = margin;
elseif margin >= state.margin_guarded
    state.margin_guarded = min(margin, ...
        state.margin_guarded + p.margin_guard_up_rate);
elseif down_confirmed ~= 0 || margin >= cfg.target_margin
    state.margin_guarded = max(margin, ...
        state.margin_guarded - p.margin_guard_down_rate);
end

if down_confirmed ~= 0
    desired = authority*(max(margin, 0.05)/cfg.target_margin)^p.power;
    desired = max(p.a_min, min(p.a_max, desired));
    candidate = (1 - p.smooth_down)*authority + p.smooth_down*desired;
    authority = max(candidate, authority - p.down_rate);
    state.above_count = 0;
elseif is_low
    state.above_count = 0;
elseif state.margin_guarded > cfg.target_margin + p.up_deadband
    state.above_count = state.above_count + 1;
    hold_n = max(1, round(p.up_hold_s/cfg.m91_override.update_interval_s));
    if state.above_count >= hold_n
        authority = min(p.a_max, authority + p.up_rate);
    end
else
    state.above_count = 0;
end
authority = max(p.a_min, min(p.a_max, authority));
end

function [authority_next, margin_filtered_next, margin_guarded_next, ...
        above_count_next, below_count_next, down_confirmed] = ...
        callStepFunction(margin, authority, margin_filtered, margin_guarded, ...
        above_count, below_count, cfg)
p = cfg.authority_gain;
[authority_next, margin_filtered_next, margin_guarded_next, ...
    above_count_next, below_count_next, down_confirmed] = ...
    adaptive_pid_authority_step(margin, authority, margin_filtered, ...
    margin_guarded, above_count, below_count, cfg.target_margin, ...
    cfg.m91_override.update_interval_s, p.a_min, p.a_max, ...
    p.down_deadband, p.down_rate, p.down_immediate_margin, ...
    p.down_confirm_n, p.up_deadband, p.power, p.smooth_down, ...
    p.up_rate, p.up_hold_s, p.margin_guard_up_rate, ...
    p.margin_guard_down_rate, p.margin_filter_alpha);
end
