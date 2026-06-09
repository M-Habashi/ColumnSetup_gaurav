function fit = pack_fit(method, p)
fit.method = method;
fit.m = 1000 * p(1);
fit.c = p(2);
fit.k = p(3);
end
