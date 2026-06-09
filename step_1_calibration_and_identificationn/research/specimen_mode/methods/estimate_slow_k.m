function k = estimate_slow_k(D)
p = [D.x ones(size(D.x))] \ D.F;
k = p(1);
end
