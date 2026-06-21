function k = estimate_slow_k(D)
% Units: D.x [m], D.F [N]; output k [N/m].
p = [D.x ones(size(D.x))] \ D.F;
k = p(1);
end
