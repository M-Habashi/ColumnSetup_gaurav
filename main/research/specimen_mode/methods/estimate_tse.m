function fit = estimate_tse(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
X = [D.a D.v D.x ones(size(D.x)) D.F];
[~, ~, V] = svd(X, 0);
q = V(:, end);
p = -q(1:end-1) / q(end);
fit = pack_fit('TSE', p);
end
