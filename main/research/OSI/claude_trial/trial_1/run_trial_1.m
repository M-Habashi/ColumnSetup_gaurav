%% Trial 1 -- Method 1: Nonparametric spectral (H1), direct
% Per non-overlapping window: estimate the plant FRF Hhat = P_dc,dm / P_dc,dc
% (Welch H1) from the measured command dc and response dm, multiply by the
% KNOWN discrete PID to form the loop Lhat = C*Hhat, and take the loop-only NCF
% margin. Output: a time series of the estimated NCF margin over 620-770.1 s.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

ncf = nan(ctx.nW, 1);
for k = 1:ctx.nW
    idx = ctx.t >= ctx.edges(k) & ctx.t < ctx.edges(k+1);
    [H, f, coh] = osi_window_frf(ctx.dc(idx), ctx.dm(idx), ctx.fs, cfg);
    sel = f >= cfg.band(1) & f <= cfg.band(2) & coh >= cfg.coh_min;
    L = squeeze(freqresp(ctx.C, 2*pi*f(sel))) .* H(sel);   % Lhat = C(jw) * Hhat(jw)
    ncf(k) = osi_ncf_looponly(L);
end

result = struct('tag', 'trial_1', ...
    'method', 'Method 1 - Nonparametric H1 (direct dc->dm)', ...
    'tc', ctx.tc, 'ncf', ncf, 'nominal', ctx.nom_ncf);
osi_report_series(result, cfg);
