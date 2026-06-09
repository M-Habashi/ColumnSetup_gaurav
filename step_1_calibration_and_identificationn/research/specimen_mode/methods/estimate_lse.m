function fit = estimate_lse(D, ~)
X = [D.a D.v D.x ones(size(D.x))];
p = X \ D.F;
fit = pack_fit('LSE', p);
end
