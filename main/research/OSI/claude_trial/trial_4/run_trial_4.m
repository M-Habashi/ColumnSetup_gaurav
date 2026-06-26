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
opt.SearchOptions.MaxIterations = 20;   % bounded cost for many short windows
t0 = tic;
fits = cell(ctx.nW, 1);
for k = 1:ctx.nW
    idx = ctx.grid.idx{k};
    [H, f, coh, P] = osi_window_frf(ctx.dc(idx), ctx.dm(idx), ctx.fs, cfg);
    sel = osi_select_bins(f, coh, P, cfg);
    if nnz(sel) < cfg.tf_np + cfg.tf_nz, continue, end   % too few FRF points to fit
    g = idfrd(reshape(H(sel), 1, 1, []), 2*pi*f(sel), 0, 'FrequencyUnit', 'rad/s');
    try
        fits{k} = c2d(tfest(g, cfg.tf_np, cfg.tf_nz, opt), ctx.dt, 'zoh');
    catch err
        fprintf('window %d (%.1f s) fit failed: %s\n', k, ctx.tc(k), err.message);
    end
end

% Baseline = the most stable early well-excited fit (max true margin), so a
% single bad fit cannot poison the reference.
early = find(~cellfun(@isempty, fits) & ctx.tc >= cfg.t_start + 3 & ctx.tc <= cfg.t_start + 30);
bcand = nan(numel(early),1);
for j = 1:numel(early)
    try, bcand(j) = ncfmargin(fits{early(j)}, ctx.C); catch, end
end
drift = nan(ctx.nW, 1);
if isempty(early) || all(isnan(bcand))
    b0idx = []; bbase = NaN;          % no viable parametric fit at all
else
    [bbase, jb] = max(bcand);  b0idx = early(jb);  base = fits{b0idx};
end

if isempty(b0idx) || ~(bbase > 0.05)
    % Parametric model unusable at this window size -> method not applicable.
    bbase = ctx.nom_bexact;  bpred = nan(ctx.nW,1);  drift_s = nan(ctx.nW,1);
    fprintf(['Method 4 NOTE: per-window 5p/3z fits are not reliable at the ' ...
        '%s window (too few FRF points); ν-gap drift is not computed.\n'], osi_window_label(cfg));
else
    for k = 1:ctx.nW
        if ~isempty(fits{k})
            try, [~, drift(k)] = gapmetric(base, fits{k}); catch, end
        end
    end
    mw = 3; if strcmp(cfg.win_mode,'sliding'), mw = 9; end   % heavier median on the fast grid
    drift_s = medfilt1(fillmissing(drift,'previous'), mw);
    drift_s(1:b0idx) = 0;                 % held at baseline before it is established
    bpred   = bbase - drift_s;            % predicted remaining NCF margin
end

result = struct('tag', 'trial_4', ...
    'method', sprintf('Method 4 - Model-reference nu-gap drift [%s]', osi_window_label(cfg)), ...
    'tc', ctx.tc, 'ncf', bpred, 'nominal', bbase, 'threshold', 0, 'runtime', toc(t0));
result.extra = struct('name', {'nu-gap drift'}, 'data', {drift_s});
osi_report_series(result, cfg);
fprintf('baseline b_{P,Hhat_1} = %.4f\n', bbase);
