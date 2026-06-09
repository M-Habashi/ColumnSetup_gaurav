function fit = estimate_mcmc(D, ~)
X = [D.a D.v D.x ones(size(D.x))];
p = mcmc_linear_fit(X, D.F, 1);
fit = pack_fit('MCMC', p);
end
