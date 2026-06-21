function fit = estimate_iv(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
X = [D.a D.v D.x ones(size(D.x))];
Z = [D.ac D.vc D.xc ones(size(D.xc))];
p = pinv(Z' * X) * (Z' * D.F);
fit = pack_fit('Instrumental Variable', p);
end
