function fit = estimate_frf_hv(D, ~)
% Units: D uses m, m/s, m/s^2, N; fit uses kg, N*s/m, N/m.
fit = fit_frf_method(D, 'Hv', false);
end
