function fit = estimate_tse(D, ~)
X = [D.a D.v D.x ones(size(D.x)) D.F];
[~, ~, V] = svd(X, 0);
q = V(:, end);
p = -q(1:end-1) / q(end);
fit = pack_fit('TSE', p);
end
