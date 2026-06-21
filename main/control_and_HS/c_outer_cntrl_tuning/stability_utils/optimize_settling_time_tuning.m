function tuning = optimize_settling_time_tuning(transfer_sys, analog_cntrlr, opts)
%OPTIMIZE_SETTLING_TIME_TUNING Multi-start digital tuning for minimum settling time.
% Units: transfer functions/controllers are dimensionless; decision vector
% is [phase margin deg, bandwidth Hz]; settling-time outputs are s.

    if nargin < 3
        opts = struct();
    end

    defaults = struct( ...
        'x0', [70, 40], ...
        'lb', [30, 1], ...
        'ub', [85, 200], ...
        'num_random_starts', 6, ...
        'use_cache', false, ...
        'cache_context', struct());
    names = fieldnames(defaults);
    for i = 1:numel(names)
        if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
            opts.(names{i}) = defaults.(names{i});
        end
    end

    seeds = [opts.x0; ...
        45 30; ...
        60 60; ...
        70 100; ...
        80 140];
    seeds = [seeds; opts.lb + rand(opts.num_random_starts, 2) .* (opts.ub - opts.lb)];

    cache_spec = local_build_cache_spec(transfer_sys, analog_cntrlr, opts);
    if opts.use_cache
        [cache_hit, cached_tuning, cache_file] = tuning_cache('load', cache_spec);
        if cache_hit
            fprintf('\n%% Using cached settling-time tuning: %s\n', cache_file);
            tuning = cached_tuning;
            return;
        end
    end

    optim_opts = optimoptions('fmincon', ...
        'Display', 'off', ...
        'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 300, ...
        'MaxIterations', 80);

    best.f = inf;
    best.x = opts.x0;
    n_starts = size(seeds, 1);

    fprintf('\n%% ========================================\n');
    fprintf('%% Settling-Time Optimization\n');
    fprintf('%% ========================================\n');
    fprintf('%% Optimization Progress: 000%%');
    warning_state = warning;
    warning('off', 'all');
    cleanup_warnings = onCleanup(@() warning(warning_state));
    for i = 1:n_starts
        x0 = min(max(seeds(i, :), opts.lb), opts.ub);
        [x_try, f_try] = fmincon(@(x)objective(x, transfer_sys, analog_cntrlr), ...
            x0, [], [], [], [], opts.lb, opts.ub, ...
            @(x)overshoot_constraint(x, transfer_sys, analog_cntrlr), optim_opts);
        if f_try < best.f
            best.f = f_try;
            best.x = x_try;
        end
        pct = floor(i / n_starts * 100);
        fprintf('\b\b\b\b%3d%%', pct);
    end
    clear cleanup_warnings
    fprintf('\n');

    [analog_cl, digital_cntrlr, digital_cl] = build_loops(best.x, transfer_sys, analog_cntrlr);
    tuning.x = best.x;
    tuning.analog_cntrlr = analog_cntrlr;
    tuning.digital_cntrlr = digital_cntrlr;
    tuning.analog_cl = analog_cl;
    tuning.digital_cl = digital_cl;
    info_a = stepinfo(analog_cl);
    info_d = stepinfo(digital_cl);
    tuning.cost = best.f;
    tuning.analog_settling_time = info_a.SettlingTime;
    tuning.digital_settling_time = info_d.SettlingTime;
    tuning.settling_time = info_d.SettlingTime;

    if opts.use_cache
        cache_file = tuning_cache('save', cache_spec, tuning);
        fprintf('%% Saved settling-time tuning cache: %s\n', cache_file);
    end
end

function f = objective(x, transfer_sys, analog_cntrlr)
% Units: x is [deg, Hz]; transfer functions are dimensionless; f is s.
    try
        [analog_cl, ~, digital_cl] = build_loops(x, transfer_sys, analog_cntrlr);
        [~, info_a] = evalc('stepinfo(analog_cl)');
        [~, info_d] = evalc('stepinfo(digital_cl)');
        ts_a = info_a.SettlingTime;
        ts_d = info_d.SettlingTime;
        f = ts_a^2 + ts_d^2;
        if ~isfinite(ts_a) || ~isfinite(ts_d) || ts_a <= 0 || ts_d <= 0 || ~isstable(analog_cl) || ~isstable(digital_cl)
            f = 1e6;
        end
    catch
        f = 1e6;
    end
end

function [c, ceq] = overshoot_constraint(x, transfer_sys, analog_cntrlr)
% Units: x is [deg, Hz]; constraint outputs are normalized dimensionless values.
    ceq = [];
    try
        [analog_cl, ~, digital_cl] = build_loops(x, transfer_sys, analog_cntrlr);
        peak_a = stepinfo(analog_cl).Peak;
        peak_d = stepinfo(digital_cl).Peak;
        c = [peak_a - 1.2; peak_d - 1.2];
        if ~all(isfinite(c))
            c = [1; 1];
        end
    catch
        c = [1; 1];
    end
end

function [analog_cl, digital_cntrlr, digital_cl] = build_loops(x, transfer_sys, analog_cntrlr)
% Units: x is [deg, Hz]; transfer functions/controllers are dimensionless.
    analog_cl = feedback(analog_cntrlr * transfer_sys, 1);
    opts_d = pidtuneOptions('PhaseMargin', x(1));
    [digital_cntrlr, ~] = pidtune(analog_cl, 'PI', x(2), opts_d);
    digital_cl = feedback(digital_cntrlr * analog_cl, 1);
end

function cache_spec = local_build_cache_spec(transfer_sys, analog_cntrlr, opts)
% Units: transfer functions are dimensionless; cached tuning settings retain their units.
    cache_spec = struct( ...
        'kind', 'settling_time_tuning', ...
        'context', opts.cache_context, ...
        'transfer_sys', local_tf_signature(transfer_sys), ...
        'analog_controller', local_tf_signature(analog_cntrlr), ...
        'tuning_config', struct( ...
            'x0', opts.x0, ...
            'lb', opts.lb, ...
            'ub', opts.ub, ...
            'num_random_starts', opts.num_random_starts));
end

function signature = local_tf_signature(sys)
% Units: sys is dimensionless; output signature stores its coefficient units unchanged.
    sys_ss = ss(sys);
    [A, B, C, D] = ssdata(sys_ss);
    signature = struct('A', A, 'B', B, 'C', C, 'D', D, 'Ts', sys_ss.Ts);
end
