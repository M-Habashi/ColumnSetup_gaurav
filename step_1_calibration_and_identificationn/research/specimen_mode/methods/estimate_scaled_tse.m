function fit = estimate_scaled_tse(D, noiseD)
X = [D.a D.v D.x ones(size(D.x)) D.F];

noiseX = [noiseD.a noiseD.v noiseD.x ones(size(noiseD.x)) noiseD.F];
scale = std(noiseX, 0, 1);
scale(4) = 1;
scale(scale == 0) = 1;

[~, ~, V] = svd(X ./ scale, 0);
q = V(:, end) ./ scale';
p = -q(1:end-1) / q(end);
fit = pack_fit('Scaled TSE', p);
end
