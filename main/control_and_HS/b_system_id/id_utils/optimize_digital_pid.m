function [controller, open_loop, closed_loop, results] = optimize_digital_pid( ...
    plant, dt, derivative_filter_N, freq_range_hz, initial_gains, constraints)
%OPTIMIZE_DIGITAL_PID Minimize settling time subject to PID constraints.
% Gains use the parallel discrete PID form with Forward Euler integration
% and derivative filtering, matching the controller in the Simulink model.

    x0 = log(initial_gains);
    lower_bounds = log([1e-4, 1e-3, 1e-8]);
    upper_bounds = log([10, 1000, 1]);
    if constraints.max_d_gain > 0
        upper_bounds(3) = log(constraints.max_d_gain);
    end
    options = optimoptions('fmincon', 'Algorithm', 'sqp', ...
        'Display', 'final', 'MaxIterations', 100, ...
        'MaxFunctionEvaluations', 600);
    x = fmincon(@settling_time, x0, [], [], [], [], ...
        lower_bounds, upper_bounds, ...
        @margin_constraints, options);

    gains = exp(x);
    controller = build_controller(gains);
    open_loop = controller*plant;
    closed_loop = feedback(open_loop, 1);
    [results.gm_db, results.pm_deg, results.ncf_margin] = ...
        custom_stability_margins(open_loop, freq_range_hz);
    results.gains = gains;
    results.step_info = stepinfo(closed_loop);

    function cost = settling_time(x_current)
        gains_current = exp(x_current);
        system_current = feedback(build_controller(gains_current)*plant, 1);
        dominant_pole_magnitude = max(abs(pole(system_current)));
        if dominant_pole_magnitude < 1
            cost = -4*dt/log(dominant_pole_magnitude);
        else
            cost = 1e6 + dominant_pole_magnitude;
        end
    end

    function [c, ceq] = margin_constraints(x_current)
        gains_current = exp(x_current);
        loop_current = build_controller(gains_current)*plant;
        system_current = feedback(loop_current, 1);
        [gm_current, pm_current] = custom_stability_margins( ...
            loop_current, freq_range_hz);

        c = max(abs(pole(system_current))) - 0.9999;
        if constraints.gm_db > 0
            c(end+1, 1) = finite_margin_constraint(constraints.gm_db, gm_current);
        end
        if constraints.pm_deg > 0
            c(end+1, 1) = finite_margin_constraint(constraints.pm_deg, pm_current);
        end
        if constraints.overshoot_percent > 0
            info = stepinfo(system_current);
            c(end+1, 1) = info.Overshoot - constraints.overshoot_percent;
        end
        if constraints.max_d_gain > 0
            c(end+1, 1) = gains_current(3) - constraints.max_d_gain;
        end
        ceq = [];
    end

    function value = finite_margin_constraint(required, actual)
        if isinf(actual)
            value = -1;
        else
            value = required - actual;
        end
    end

    function digital_pid = build_controller(gains)
        digital_pid = pid(gains(1), gains(2), gains(3), ...
            1/derivative_filter_N, dt, 'IFormula', 'ForwardEuler', ...
            'DFormula', 'ForwardEuler');
    end
end
