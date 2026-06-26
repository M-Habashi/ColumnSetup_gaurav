%% Trial 2 -- Method 2: Parametric per-window model identification
% Per non-overlapping window: fit a continuous rational plant Hhat(s) (5p/3z,
% matching the exp_tf structure) to the Welch FRF with tfest+EnforceStability
% (same route as sys_id.m), discretise (c2d, zoh), form Lhat = C*Hhat, and
% report BOTH the loop-only NCF margin and the rigorous 4-block ncfmargin
% b_{P,C}. Output: time series of the estimated NCF margin over 620-770.1 s.

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

opt = tfestOptions('Display', 'off', 'EnforceStability', true);
opt.SearchOptions.MaxIterations = 20;   % bounded cost for many short windows
t0 = tic;
ncf    = nan(ctx.nW, 1);   % loop-only NCF (comparable across methods)
bexact = nan(ctx.nW, 1);   % rigorous 4-block b_{P,C}
for k = 1:ctx.nW
    idx = ctx.grid.idx{k};
    [H, f, coh] = osi_window_frf(ctx.dc(idx), ctx.dm(idx), ctx.fs, cfg);
    sel = f >= cfg.band(1) & f <= cfg.band(2) & coh >= cfg.coh_min;
    g = idfrd(reshape(H(sel), 1, 1, []), 2*pi*f(sel), 0, 'FrequencyUnit', 'rad/s');
    try
        Hc  = tfest(g, cfg.tf_np, cfg.tf_nz, opt);
        Hd  = c2d(Hc, ctx.dt, 'zoh');
        L   = squeeze(freqresp(ctx.C*Hd, 2*pi*cfg.fgrid));
        ncf(k)    = osi_ncf_looponly(L);
        bexact(k) = ncfmargin(Hd, ctx.C);
    catch err
        fprintf('window %d (%.1f s) fit failed: %s\n', k, ctx.tc(k), err.message);
    end
end
ncf    = osi_warmup_hold(ncf, ctx.tc, cfg, ctx.nom_ncf);       % held over weak start
bexact = osi_warmup_hold(bexact, ctx.tc, cfg, ctx.nom_bexact);

result = struct('tag', 'trial_2', ...
    'method', sprintf('Method 2 - Parametric per-window ID (5p/3z tfest) [%s]', osi_window_label(cfg)), ...
    'tc', ctx.tc, 'ncf', ncf, 'nominal', ctx.nom_ncf, 'runtime', toc(t0));
result.extra = struct('name', {'b_exact(P,C)'}, 'data', {bexact});
osi_report_series(result, cfg);
