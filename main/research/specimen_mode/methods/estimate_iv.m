function fit = estimate_iv(D, ~)
X = [D.a D.v D.x ones(size(D.x))];
Z = [D.ac D.vc D.xc ones(size(D.xc))];
p = pinv(Z' * X) * (Z' * D.F);
fit = pack_fit('Instrumental Variable', p);
end
