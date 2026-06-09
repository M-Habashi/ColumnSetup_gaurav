function fit = estimate_mcmc2(D, ~)
ix = cumtrapz(D.t, D.x);
iix = cumtrapz(D.t, ix);
iiF = cumtrapz(D.t, cumtrapz(D.t, D.F));

X = [D.x ix iix ones(size(D.x)) D.t];
p = mcmc_linear_fit(X, iiF, 2);
fit = pack_fit('MCMC2', p);
end
