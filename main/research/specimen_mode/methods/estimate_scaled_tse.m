function fit = estimate_scaled_tse(D, noiseD)
% Units: D/noiseD use m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
noiseX = [noiseD.a noiseD.v noiseD.x ones(size(noiseD.x)) noiseD.F];
scale = std(noiseX, 0, 1);
scale(scale == 0) = 1;
theta = noise_whitened_tls(D.a, D.v, D.x, D.F, scale([1 2 3 5]));
fit = pack_fit('Scaled TSE', [theta; 0]);
end
