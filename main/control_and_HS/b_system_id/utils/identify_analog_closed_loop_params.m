function out = identify_analog_closed_loop_params(discrete_tf_estimate, fit_config)
%IDENTIFY_ANALOG_CLOSED_LOOP_PARAMS Fit analog closed-loop physical parameters.
% Units: input/output transfer responses are dimensionless; frequency is
% rad/s or Hz; mass is kg, damping is N*s/m, and stiffness is N/m.

    %% Prepare target response and fit configuration
    if nargin < 2, fit_config = struct(); end
    c = defaults(fit_config);
    y = discrete_tf_estimate.tf_points(:);
    w = discrete_tf_estimate.freq_rad(:);
    c.frequency_weight = frequency_weight(w, c);
    fields = {'a1b0','a2','a3','beta1','beta2','Kp','Ki'};
    lb = log10([c.a1b0_bounds(1); c.a2_bounds(1); c.a3_bounds(1); c.beta1_bounds(1); c.beta2_bounds(1); c.Kp_bounds(1); c.Ki_bounds(1)]);
    ub = log10([c.a1b0_bounds(2); c.a2_bounds(2); c.a3_bounds(2); c.beta1_bounds(2); c.beta2_bounds(2); c.Kp_bounds(2); c.Ki_bounds(2)]);
    x0 = log10(cellfun(@(f)c.initial_params.(f), fields)).';
    known = log10([ ...
        2.1283e13, 4.2297e6, 3.3, 425, 9.9976e4, 1.0, 0.01; ...
        2.1283e13, 4.2297e6, 10, 200, 8e4, 1.5, 0.01; ...
        1e13, 1e7, 30, 100, 2e5, 2.0, 0.1; ...
        5e13, 1e6, 1.0, 600, 5e4, 0.5, 0.01]);
    starts = [x0.'; known; lb.' + rand(c.num_random_starts, numel(lb)) .* (ub - lb).'];
    starts = min(max(starts, lb.'), ub.');

    %% Solve nonlinear least-squares problem from multiple starting points
    opts = optimoptions('lsqnonlin', 'Display', c.solver_display, ...
        'MaxFunctionEvaluations', c.max_function_evaluations, ...
        'MaxIterations', c.max_iterations, ...
        'StepTolerance', c.step_tolerance, ...
        'FunctionTolerance', c.function_tolerance);
    problem = createOptimProblem('lsqnonlin', 'objective', @(x)err(x, w, y, c), ...
        'x0', x0, 'lb', lb, 'ub', ub, 'options', opts);
    [x, resnorm, exitflag, solver_output, solutions] = run( ...
        MultiStart('Display', c.display, 'MaxTime', c.max_time), ...
        problem, CustomStartPointSet(starts));

    %% Build identified model and fit-quality metrics
    p = pack(10 .^ x);
    p.mass = c.mass; p.damping = c.damping; p.stiffness = c.stiffness;
    [num, den] = model_poly(p, c);
    fit_resp = freqs(num, den, w);
    mag_target_db = 20 * log10(abs(y) + eps);
    mag_fit_db = 20 * log10(abs(fit_resp) + eps);
    phase_target_deg = unwrap(angle(y)) * 180 / pi;
    phase_fit_deg = unwrap(angle(fit_resp)) * 180 / pi;

    out = struct('identified_params', p, 'parametric_cl', tf(num, den), ...
        'freq_hz', discrete_tf_estimate.freq_hz, 'freq_rad', w, ...
        'fit_resp', fit_resp, 'resnorm', resnorm, 'exitflag', exitflag, ...
        'output', solver_output, 'solutions', solutions, ...
        'mag_target_db', mag_target_db, 'mag_fit_db', mag_fit_db, ...
        'phase_target_deg', phase_target_deg, 'phase_fit_deg', phase_fit_deg, ...
        'rms_mag_db', rms(mag_fit_db - mag_target_db), ...
        'rms_phase_deg', rms(phase_fit_deg - phase_target_deg));
end

function r = err(x, w, y, c)
    % Units: w is rad/s; y, model response, weights, and residual are dimensionless.
    % Compare model and measured response in magnitude and phase.
    [num, den] = model_poly(pack(10 .^ x), c);
    h = freqs(num, den, w);
    in_band = w >= 2 * pi * c.fit_band_hz(1) & w <= 2 * pi * c.fit_band_hz(2);
    mw = ones(size(w)); mw(in_band) = c.magnitude_weight;
    fw = c.frequency_weight;
    r = [fw .* mw .* (log10(abs(h) + eps) - log10(abs(y) + eps)); ...
        c.phase_weight * fw .* mw .* ((unwrap(angle(h)) - unwrap(angle(y))) / pi)];
    r(~isfinite(r)) = 1e6;
end

function fw = frequency_weight(w, c)
    % Units: w is rad/s; c frequency fields are Hz; fw is dimensionless.
    if c.frequency_weight_exponent == 0
        fw = ones(size(w(:)));
        return
    end

    f = max(w(:) / (2 * pi), c.frequency_weight_floor_hz);
    fw = f .^ (-c.frequency_weight_exponent);
    fw = fw / mean(fw);
end

function p = pack(v)
    % Store the optimized parameter vector in named fields.
    % Units: coefficient units follow the continuous-time polynomial; gains are dimensionless.
    p = struct('a1b0', v(1), 'a2', v(2), 'a3', v(3), 'beta1', v(4), ...
        'beta2', v(5), 'Kp', v(6), 'Ki', v(7), 'a1', v(1), 'b1', v(4), 'b2', v(5));
end

function [num, den] = model_poly(p, c)
    % Assemble the analog closed-loop transfer-function polynomials.
    % Units: c mass is kg, damping N*s/m, stiffness N/m; output TF is dimensionless.
    m = c.mass; d = c.damping; k = c.stiffness;
    num = [p.Kp * p.a1b0, p.Ki * p.a1b0];
    den = [m, ...
        d + p.a3*m + p.beta1*m, ...
        p.a2 + k + p.a3*d + p.beta1*d + p.beta2*m + p.a3*p.beta1*m, ...
        p.a2*p.beta1 + p.beta2*d + p.a3*k + p.beta1*k + p.a3*p.beta1*d + p.a3*p.beta2*m, ...
        p.a2*p.beta2 + p.beta2*k + p.a3*p.beta2*d + p.a3*p.beta1*k, ...
        p.Kp*p.a1b0 + p.a3*p.beta2*k, ...
        p.Ki*p.a1b0];
end

function c = defaults(c)
    % Fill solver and parameter settings used by the nonlinear fit.
    % Units: mass kg, damping N*s/m, stiffness N/m, frequency Hz; other settings unitless.
    d = struct('mass',38, 'damping',416, 'stiffness',0, ...
        'fit_band_hz',[0.5,40], 'magnitude_weight',3, 'phase_weight',0.35, ...
        'frequency_weight_exponent',0, 'frequency_weight_floor_hz',0.5, ...
        'num_random_starts',5, 'max_time',Inf, 'display','off', 'solver_display','off', ...
        'max_function_evaluations',4e4, 'max_iterations',2000, ...
        'step_tolerance',1e-12, 'function_tolerance',1e-12, ...
        'initial_params',struct('a1b0',2.1283e13,'a2',4.2297e6,'a3',3.3,'beta1',425,'beta2',9.9976e4,'Kp',1.5,'Ki',0.03), ...
        'a1b0_bounds',[1e10,1e16], 'a2_bounds',[1e3,1e10], 'a3_bounds',[1e-2,1e3], ...
        'beta1_bounds',[1e-2,1e4], 'beta2_bounds',[1e1,1e7], 'Kp_bounds',[1e-6,1e3], 'Ki_bounds',[1e-6,1e3]);
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(c, f{i}) || isempty(c.(f{i})), c.(f{i}) = d.(f{i}); end
    end
end
