%% Trial 1 -- Method 1: Nonparametric spectral (H1), direct
% Per non-overlapping window: estimate the plant FRF Hhat = P_dc,dm / P_dc,dc
% (Welch H1) from the measured command dc and response dm, multiply by the
% KNOWN discrete PID to form the loop Lhat = C*Hhat, and take the loop-only NCF
% margin. Output: a time series of the estimated NCF margin over 620-770.1 s.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

t0 = tic;
ncf = nan(ctx.nW, 1);
for k = 1:ctx.nW
    idx = ctx.grid.idx{k};
    [H, f, coh, P] = osi_window_frf(ctx.dc(idx), ctx.dm(idx), ctx.fs, cfg);
    sel = osi_select_bins(f, coh, P, cfg);                 % band + coherence + power gate
    L = squeeze(freqresp(ctx.C, 2*pi*f(sel))) .* H(sel);   % Lhat = C(jw) * Hhat(jw)
    ncf(k) = osi_ncf_looponly(L);
end
ncf = osi_warmup_hold(ncf, ctx.tc, cfg, ctx.nom_ncf);      % held over weak start

result = struct('tag', 'trial_1', ...
    'method', sprintf('Method 1 - Nonparametric H1 (direct dc->dm) [%s]', osi_window_label(cfg)), ...
    'tc', ctx.tc, 'ncf', ncf, 'nominal', ctx.nom_ncf, 'runtime', toc(t0));
osi_report_series(result, cfg);
