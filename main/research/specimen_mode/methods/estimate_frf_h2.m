function fit = estimate_frf_h2(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
fit = fit_frf_method(D, 'H2', false);
end
