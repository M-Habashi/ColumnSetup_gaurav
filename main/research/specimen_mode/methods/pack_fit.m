function fit = pack_fit(method, p)
% Units: p/output are m [kg], c [N*s/m], k [N/m]; method is unitless text.
fit.method = method;
fit.m = p(1);
fit.c = p(2);
fit.k = p(3);
end
