function theta = noise_whitened_tls(a, v, x, F, noise_scale)
% Estimate [m; c; k] from F = m*a + c*v + k*x using whitened TLS.
Z = [a(:), v(:), x(:), F(:)];
Z = Z - mean(Z, 1);
[~, ~, V] = svd(Z ./ noise_scale(:)', 0);
q = V(:, end) ./ noise_scale(:);
theta = -q(1:3)/q(4);
end
