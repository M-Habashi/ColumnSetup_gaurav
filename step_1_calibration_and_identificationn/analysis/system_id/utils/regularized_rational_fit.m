function [num, den, info] = regularized_rational_fit(h, w, nb, na, lambda, weights, opts)
%REGULARIZED_RATIONAL_FIT Scaled iterative ridge fit for H(jw) = B(jw)/A(jw).

    if nargin < 5 || isempty(lambda), lambda = 1e-6; end
    if nargin < 6 || isempty(weights), weights = ones(size(w)); end
    if nargin < 7, opts = struct(); end
    if ~isfield(opts, 'max_iterations'), opts.max_iterations = 25; end
    if ~isfield(opts, 'tolerance'), opts.tolerance = 1e-8; end
    if ~isfield(opts, 'phase_weight'), opts.phase_weight = 0.35; end
    if ~isfield(opts, 'solver_display'), opts.solver_display = 'off'; end
    if ~isfield(opts, 'reference_response'), opts.reference_response = []; end
    if ~isfield(opts, 'reference_weight'), opts.reference_weight = 0; end

    h = h(:); w = w(:); weights = weights(:);
    ws = max(abs(w)); if ws == 0, ws = 1; end
    q = 1i * w / ws;
    den_q = [1, zeros(1, na)];
    x = zeros(nb + na + 1, 1);

    num_cols = q .^ (nb:-1:0);
    den_cols = q .^ (na-1:-1:0);
    rhs = h .* q .^ na;

    for k = 1:opts.max_iterations
        sk = weights ./ max(abs(polyval(den_q, q)), eps);
        A = [num_cols, -h .* den_cols];
        Ar = [real(sk .* A); imag(sk .* A); sqrt(lambda) * eye(size(A, 2))];
        br = [real(sk .* rhs); imag(sk .* rhs); zeros(size(A, 2), 1)];
        x_new = lsqminnorm(Ar, br);
        if norm(x_new - x) <= opts.tolerance * max(1, norm(x_new)), x = x_new; break; end
        x = x_new;
        den_q = [1, x(nb+2:end).'];
    end

    refine_opts = optimoptions('lsqnonlin', 'Display', opts.solver_display, ...
        'MaxIterations', 500, 'MaxFunctionEvaluations', 2e4, ...
        'StepTolerance', 1e-12, 'FunctionTolerance', 1e-12);
    x = lsqnonlin(@(v)fit_error(v, q, h, nb, lambda, weights, opts), ...
        x, [], [], refine_opts);

    num_q = x(1:nb+1).';
    den_q = [1, x(nb+2:end).'];
    num = real(num_q .* ws .^ (na-nb:na));
    den = real(den_q .* ws .^ (0:na));
    info = struct('iterations', k, 'frequency_scale', ws, 'lambda', lambda);
end

function r = fit_error(x, q, h, nb, lambda, weights, opts)
    num_q = x(1:nb+1).';
    den_q = [1, x(nb+2:end).'];
    h_fit = polyval(num_q, q) ./ polyval(den_q, q);
    r = [weights .* (log10(abs(h_fit) + eps) - log10(abs(h) + eps)); ...
        opts.phase_weight * weights .* ((unwrap(angle(h_fit)) - unwrap(angle(h))) / pi); ...
        sqrt(lambda) * x];
    if opts.reference_weight > 0 && ~isempty(opts.reference_response)
        h_ref = opts.reference_response(:);
        r = [r; opts.reference_weight * weights .* (log10(abs(h_fit) + eps) - log10(abs(h_ref) + eps)); ...
            opts.reference_weight * opts.phase_weight * weights .* ((unwrap(angle(h_fit)) - unwrap(angle(h_ref))) / pi)];
    end
    r(~isfinite(r)) = 1e6;
end
