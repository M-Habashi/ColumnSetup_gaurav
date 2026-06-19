function p = mcmc_linear_fit(X, y, seed)
rng(seed)

n = min(size(X, 1), 5000);
idx = round(linspace(1, size(X, 1), n));
X = X(idx, :);
y = y(idx);

p0 = X \ y;
r = y - X * p0;
sigma2 = mean(r.^2);
C = sigma2 * pinv(X' * X);
R = chol(C + 1e-12 * eye(size(C)), 'lower');

n_step = 3000;
burn = 1000;
p_now = p0;
ll_now = -0.5 / sigma2 * sum((y - X * p_now).^2);
samples = zeros(n_step - burn, numel(p0));
j = 1;

for i = 1:n_step
    p_try = p_now + R * randn(size(p_now));
    ll_try = -0.5 / sigma2 * sum((y - X * p_try).^2);
    if log(rand) < ll_try - ll_now
        p_now = p_try;
        ll_now = ll_try;
    end
    if i > burn
        samples(j, :) = p_now;
        j = j + 1;
    end
end

p = mean(samples, 1)';
end
