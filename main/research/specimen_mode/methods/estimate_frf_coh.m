function fit = estimate_frf_coh(D, ~)
fit = fit_frf_method(D, 'H1', true);
fit.method = 'FRF Coherence Weighted';
end
