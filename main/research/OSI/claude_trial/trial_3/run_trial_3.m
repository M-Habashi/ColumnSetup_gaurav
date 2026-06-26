%% Trial 3 -- Method 3: Closed-loop indirect, instrument-variable (dd)
% In closed loop the command dc is correlated with output noise, so the direct
% H1 estimate (Method 1) is biased. Using the exogenous reference dd as an
% instrument removes that bias:
%     Hhat(jw) = S_dd,dm(w) / S_dd,dc(w)         (ratio of cross-spectra)
% Then Lhat = C*Hhat and the loop-only NCF margin. Coherence of dd->dc gates
% the kept bins. Output: time series of the estimated NCF margin (620-770.1 s).

this_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(this_dir, '..', 'common'));
cfg = osi_config();
ctx = osi_load_context(cfg);

ncf = nan(ctx.nW, 1);
for k = 1:ctx.nW
    idx = ctx.t >= ctx.edges(k) & ctx.t < ctx.edges(k+1);
    dd = ctx.dd(idx); dc = ctx.dc(idx); dm = ctx.dm(idx);
    [~, f, ~, Pddm] = osi_window_frf(dd, dm, ctx.fs, cfg);   % Pddm(:,3) = S_dd,dm
    [~, ~, ~, Pddc] = osi_window_frf(dd, dc, ctx.fs, cfg);   % Pddc(:,3) = S_dd,dc
    coh_dc = abs(Pddc(:,3)).^2 ./ max(Pddc(:,1).*Pddc(:,2), eps);
    Hind = Pddm(:,3) ./ Pddc(:,3);                           % instrument-variable plant
    sel = f >= cfg.band(1) & f <= cfg.band(2) & coh_dc >= cfg.coh_min;
    L = squeeze(freqresp(ctx.C, 2*pi*f(sel))) .* Hind(sel);
    ncf(k) = osi_ncf_looponly(L);
end

result = struct('tag', 'trial_3', ...
    'method', 'Method 3 - Closed-loop indirect / dd-instrument', ...
    'tc', ctx.tc, 'ncf', ncf, 'nominal', ctx.nom_ncf);
osi_report_series(result, cfg);
