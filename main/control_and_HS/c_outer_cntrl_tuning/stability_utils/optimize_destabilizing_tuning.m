function tuning = optimize_destabilizing_tuning(transfer_sys, reduced_transfer_sys, analog_cntrlr, opts)
%OPTIMIZE_DESTABILIZING_TUNING Minimize nominal settling time and force reduced-loop instability.
% Units: transfer functions/controllers are dimensionless; decision vector
% is [phase margin deg, bandwidth Hz]; settling-time outputs are s.

    if nargin < 4
        opts = struct();
    end

    defaults = struct( ...
        'x0', [70, 40], ...
        'lb', [30, 1], ...
        'ub', [85, 200], ...
        'num_random_starts', 6);
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

    optim_opts = optimoptions('fmincon', ...
        'Display', 'off', ...
        'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 300, ...
        'MaxIterations', 80);

    best_feasible.f = inf;
    best_feasible.x = [];
    best_fallback.f = inf;
    best_fallback.x = opts.x0;
    best_fallback.violation = inf;
    n_starts = size(seeds, 1);

    fprintf('\n%% ========================================\n');
    fprintf('%% Destabilizing Optimization\n');
    fprintf('%% ========================================\n');
    fprintf('%% Optimization Progress: 000%%');
    warning_state = warning;
    warning('off', 'all');
    cleanup_warnings = onCleanup(@() warning(warning_state));
    for i = 1:n_starts
        x0 = min(max(seeds(i, :), opts.lb), opts.ub);
        [x_try, f_try, exitflag_try] = fmincon( ...
            @(x)objective(x, transfer_sys, analog_cntrlr), ...
            x0, [], [], [], [], opts.lb, opts.ub, ...
            @(x)specific_constraint(x, transfer_sys, reduced_transfer_sys, analog_cntrlr), optim_opts);
        [c_try, ~] = specific_constraint(x_try, transfer_sys, reduced_transfer_sys, analog_cntrlr);
        candidate_feasible = exitflag_try > 0 && isfinite(f_try) ...
            && f_try < 1e6 && all(c_try <= 1e-6);
        if candidate_feasible && f_try < best_feasible.f
            best_feasible.f = f_try;
            best_feasible.x = x_try;
        end
        constraint_violation = sum(max(c_try, 0).^2);
        fallback_is_better = constraint_violation < best_fallback.violation ...
            || (constraint_violation == best_fallback.violation && f_try < best_fallback.f);
        if all(isfinite(x_try)) && isfinite(f_try) && fallback_is_better
            best_fallback.f = f_try;
            best_fallback.x = x_try;
            best_fallback.violation = constraint_violation;
        end
        pct = floor(i / n_starts * 100);
        fprintf('\b\b\b\b%3d%%', pct);
    end
    clear cleanup_warnings
    fprintf('\n');

    if isempty(best_feasible.x)
        best = best_fallback;
        found_solution = false;
        warning(['No feasible destabilizing tuning was found. Returning the ' ...
            'best candidate and marking it as infeasible.']);
    else
        best = best_feasible;
        found_solution = true;
    end

    [analog_cl, digital_cntrlr, digital_cl] = build_loops(best.x, transfer_sys, analog_cntrlr);
    analog_cl_r = feedback(analog_cntrlr * reduced_transfer_sys, 1);
    digital_cl_r = feedback(digital_cntrlr * analog_cl_r, 1);
    info_a = stepinfo(analog_cl);
    info_d = stepinfo(digital_cl);
    [c_final, ~] = specific_constraint(best.x, transfer_sys, reduced_transfer_sys, analog_cntrlr);

    tuning.x = best.x;
    tuning.analog_cntrlr = analog_cntrlr;
    tuning.digital_cntrlr = digital_cntrlr;
    tuning.analog_cl = analog_cl;
    tuning.digital_cl = digital_cl;
    tuning.reduced_analog_cl = analog_cl_r;
    tuning.reduced_digital_cl = digital_cl_r;
    tuning.cost = best.f;
    tuning.analog_settling_time = info_a.SettlingTime;
    tuning.digital_settling_time = info_d.SettlingTime;
    tuning.settling_time = info_d.SettlingTime;
    tuning.found_solution = found_solution;
    tuning.constraint_values = c_final;
    tuning.reduced_max_real_pole = max(real(pole(digital_cl_r)));
    tuning.reduced_is_unstable = ~isstable(digital_cl_r);

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

function [c, ceq] = specific_constraint(x, transfer_sys, reduced_transfer_sys, analog_cntrlr)
% Units: x is [deg, Hz]; constraint outputs are normalized dimensionless values.
    ceq = [];
    try
        [analog_cl, digital_cntrlr, digital_cl] = build_loops(x, transfer_sys, analog_cntrlr);
        analog_cl_r = feedback(analog_cntrlr * reduced_transfer_sys, 1);
        digital_cl_r = feedback(digital_cntrlr * analog_cl_r, 1);
        info_a = stepinfo(analog_cl);
        info_d = stepinfo(digital_cl);
        peak_a = info_a.Peak;
        peak_d = info_d.Peak;
        max_real_pole_r = max(real(pole(digital_cl_r)));
        c = [peak_a - 1.2; peak_d - 1.2; 1e-6 - max_real_pole_r];
        if ~all(isfinite(c))
            c = [1; 1; 1];
        end
    catch
        c = [1; 1; 1];
    end
end

function [analog_cl, digital_cntrlr, digital_cl] = build_loops(x, transfer_sys, analog_cntrlr)
% Units: x is [deg, Hz]; transfer functions/controllers are dimensionless.
    analog_cl = feedback(analog_cntrlr * transfer_sys, 1);
    opts_d = pidtuneOptions('PhaseMargin', x(1));
    [digital_cntrlr, ~] = pidtune(analog_cl, 'PI', x(2), opts_d);
    digital_cl = feedback(digital_cntrlr * analog_cl, 1);
end
