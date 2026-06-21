function fit = estimate_mcmc(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
X = [D.a D.v D.x ones(size(D.x))];
p = mcmc_linear_fit(X, D.F, 1);
fit = pack_fit('MCMC', p);
end
