function fit = estimate_lse(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
X = [D.a D.v D.x ones(size(D.x))];
p = X \ D.F;
fit = pack_fit('LSE', p);
end
