%% Trial 4 -- Method 4: Model-reference nu-gap drift / early-warning
% This is the only method that uses the "model correct at the beginning"
% assumption. Per window fit a 5p/3z plant Hhat_k. Measure the Vinnicombe
% nu-gap to the FIRST-window baseline Hhat_1 (self-referencing cancels the
% common per-window estimation bias):  delta_k = nu-gap(Hhat_1, Hhat_k).
% Robust-stability theorem: the loop stays stable while delta_k < b_{P,Hhat_1},
% so the predicted remaining margin is  bpred_k = b_{P,Hhat_1} - delta_k
% (median-of-3 robustified). Alarm when delta_k -> b_{P,Hhat_1} (bpred -> 0).
% Output: predicted-margin time series + drift early-warning (620-770.1 s).

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

opt = tfestOptions('Display', 'off', 'EnforceStability', true);
fits = cell(ctx.nW, 1);
for k = 1:ctx.nW
    idx = ctx.t >= ctx.edges(k) & ctx.t < ctx.edges(k+1);
    [H, f, coh] = osi_window_frf(ctx.dc(idx), ctx.dm(idx), ctx.fs, cfg);
    sel = f >= cfg.band(1) & f <= cfg.band(2) & coh >= cfg.coh_min;
    g = idfrd(reshape(H(sel), 1, 1, []), 2*pi*f(sel), 0, 'FrequencyUnit', 'rad/s');
    try
        fits{k} = c2d(tfest(g, cfg.tf_np, cfg.tf_nz, opt), ctx.dt, 'zoh');
    catch err
        fprintf('window %d (%.1f s) fit failed: %s\n', k, ctx.tc(k), err.message);
    end
end

base  = fits{1};
bbase = ncfmargin(base, ctx.C);          % achieved margin at the validated start
drift = nan(ctx.nW, 1);
for k = 1:ctx.nW
    if ~isempty(fits{k})
        [~, drift(k)] = gapmetric(base, fits{k});     % nu-gap to baseline
    end
end
drift_s = medfilt1(drift, 3);            % robustify isolated bad fits
bpred   = bbase - drift_s;               % predicted remaining NCF margin

result = struct('tag', 'trial_4', ...
    'method', 'Method 4 - Model-reference nu-gap drift (early-warning)', ...
    'tc', ctx.tc, 'ncf', bpred, 'nominal', bbase, 'threshold', 0);
result.extra = struct('name', {'nu-gap drift'}, 'data', {drift_s});
osi_report_series(result, cfg);
fprintf('baseline b_{P,Hhat_1} = %.4f ; alarm when nu-gap drift reaches it.\n', bbase);
