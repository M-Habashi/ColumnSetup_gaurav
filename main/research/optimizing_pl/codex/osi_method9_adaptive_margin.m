function out = osi_method9_adaptive_margin(ctx, cfg)
%OSI_METHOD9_ADAPTIVE_MARGIN Phase-aware adaptive NCF estimator.
%
% M9 fuses two estimates on one frequency grid instead of assuming a fixed
% resonance band:
%   1) excited bins: direct closed-loop S,T NCF from T = dm/dd_lead and S = 1-T;
%   2) unexcited bins: residual output spectrum normalized by the healthy start.
%
% The S,T branch is absolute and phase-aware. The residual branch is the
% output-only fallback, but it searches the full configured band and subtracts
% the command-correlated part of the output through the coherence.

fs = ctx.fs;
f9 = (cfg.m9_band(1):cfg.m9_df:cfg.m9_band(2)).';
nf = numel(f9);
L0 = squeeze(freqresp(ctx.C*ctx.H0d, 2*pi*f9));
dist0 = abs(1 + L0)./sqrt(2*(1 + abs(L0).^2));
[nominal, nominal_idx] = min(dist0);

Nbuf = round(cfg.m9_buf*fs);
Lsub = cfg.m9_Lsub;
hsub = cfg.m9_hsub;
win = hann(Lsub);
starts = 1:hsub:(Nbuf - Lsub + 1);
n_d = numel(starts);
E = exp(-1j*2*pi*(0:Lsub-1).' * f9.' / fs);

tend = (cfg.t_start + cfg.m9_buf):cfg.m9_hop:cfg.t_end;
nW = numel(tend);
tc = tend.' - cfg.m9_buf/2;

That = nan(nf, nW);
gam2 = nan(nf, nW);
pin = nan(nf, nW);
pres = nan(nf, nW);
pyy = nan(nf, nW);

for k = 1:nW
    i1 = find(ctx.t >= tend(k) - cfg.m9_buf, 1);
    idx = i1:i1+Nbuf-1;
    u = ctx.dd_lead(idx);
    y = ctx.dm(idx);
    Suu = zeros(nf,1);
    Syy = Suu;
    Suy = Suu;
    for s = starts
        Us = ((win.*detrend(u(s:s+Lsub-1))).' * E).';
        Ys = ((win.*detrend(y(s:s+Lsub-1))).' * E).';
        Suu = Suu + abs(Us).^2;
        Syy = Syy + abs(Ys).^2;
        Suy = Suy + Ys.*conj(Us);
    end
    That(:,k) = Suy./max(Suu, eps);
    g2 = min(abs(Suy).^2./max(Suu.*Syy, eps), 1);
    gam2(:,k) = max(0, (n_d*g2 - 1)/(n_d - 1));
    pin(:,k) = 10*log10(Suu + eps);
    pyy(:,k) = Syy;
    pres(:,k) = Syy.*max(1 - gam2(:,k), cfg.m9_residual_floor);
end

cal_mask = tc < cfg.t_start + cfg.m9_calib_s;
if ~any(cal_mask)
    cal_mask(1:min(cfg.m9_nwarm, nW)) = true;
end
pres0 = median(pres(:, cal_mask), 2, 'omitnan');
pres0 = max(pres0, median(pres0(isfinite(pres0) & pres0 > 0), 'omitnan')*1e-6);

freq_keep = f9 >= cfg.m9_band(1) & f9 <= cfg.m9_band(2) ...
    & ~(f9 >= cfg.m9_line_reject(1) & f9 <= cfg.m9_line_reject(2));
ratio = pres./pres0;
ratio(~freq_keep,:) = NaN;
for k = 1:nW
    ratio(:,k) = movmedian(ratio(:,k), cfg.m9_freq_medfilt, 'omitnan');
end

peak_mask = modelPeakMask(f9, dist0, nominal_idx, nominal, cfg);
floor_low = max(f9(peak_mask)) + cfg.m9_floor_gap_hz;
floor_high = floor_low + cfg.m9_floor_width_hz;
model_freq_keep = f9 >= cfg.m9_band(1) & f9 <= cfg.m9_band(2);
floor_candidates = model_freq_keep & ~peak_mask & f9 >= floor_low & f9 <= floor_high;
if nnz(floor_candidates) < cfg.m9_min_bins
    floor_candidates = model_freq_keep & ~peak_mask & f9 > max(f9(peak_mask)) + cfg.m9_floor_gap_hz;
end
floor_mask = floor_candidates;
Spk_model = sqrt(max(pyy(peak_mask,:), [], 1)./max(median(pyy(floor_mask,:), 1, 'omitnan'), eps));
Sref_model = median(Spk_model(cal_mask), 'omitnan');
ncf_model = min(cfg.m9_cap, nominal*Sref_model./max(Spk_model(:), eps));

q_ref = median(local_prctile(ratio(:, cal_mask), cfg.m9_res_prctile), 'omitnan');
if ~isfinite(q_ref) || q_ref <= 0
    q_ref = 1;
end

ncf_res = nan(nW,1);
ncf_st = nan(nW,1);
ncf_wide = nan(nW,1);
f_res = nan(nW,1);
f_st = nan(nW,1);
n_excited = zeros(nW,1);

for k = 1:nW
    [q_now, iq] = max(ratio(:,k), [], 'omitnan');
    if isempty(q_now) || ~isfinite(q_now) || q_now <= 0
        q_now = q_ref;
        iq = nominal_idx;
    end
    f_res(k) = f9(iq);
    ncf_res(k) = min(cfg.m9_cap, nominal*sqrt(q_ref/max(q_now, q_ref)));
    if peak_mask(iq)
        ncf_wide(k) = cfg.m9_cap;
    else
        ncf_wide(k) = ncf_res(k);
    end

    excited = pin(:,k) >= max(pin(:,k), [], 'omitnan') - cfg.input_power_range_db;
    keep = excited & gam2(:,k) >= cfg.m9_gamma_min & freq_keep;
    n_excited(k) = nnz(keep);
    if k > cfg.m9_nwarm && nnz(keep) >= cfg.m9_min_bins
        T = That(keep,k);
        S = 1 - T;
        st = sqrt(abs(S).^2 + abs(T).^2);
        st_hi = prctile(st, cfg.m9_st_prctile);
        [~, ist] = min(abs(st - st_hi));
        ftmp = f9(keep);
        f_st(k) = ftmp(ist);
        ncf_st(k) = 1/(sqrt(2)*max(st_hi, eps));
    else
        ncf_st(k) = cfg.m9_cap;
        f_st(k) = NaN;
    end
end

ncf_raw = min([ncf_model(:), ncf_st, ncf_wide], [], 2, 'omitnan');
ncf = medfilt1(ncf_raw, cfg.m9_medfilt, 'omitnan', 'truncate');
ncf(1:min(cfg.m9_nwarm, nW)) = nominal;

below = ncf < cfg.ncf_threshold;
below(isnan(below)) = false;
hit = find(movsum(below, [cfg.m9_detect_consec-1, 0]) >= cfg.m9_detect_consec, 1);
detect_time = NaN;
if ~isempty(hit)
    detect_time = tc(hit);
end

out = struct('tc', tc, 'ncf', ncf, 'ncf_raw', ncf_raw, ...
    'ncf_residual', ncf_res, 'ncf_st', ncf_st, ...
    'ncf_model', ncf_model(:), 'ncf_wide', ncf_wide, ...
    'nominal', nominal, 'threshold', cfg.ncf_threshold, ...
    'detect_time', detect_time, 'f9', f9, ...
    'f_residual', f_res, 'f_st', f_st, 'n_excited', n_excited, ...
    'q_ref', q_ref, 'nominal_hz', f9(nominal_idx), ...
    'model_peak_band', [min(f9(peak_mask)) max(f9(peak_mask))]);
end

function y = local_prctile(x, p)
y = nan(1, size(x,2));
for k = 1:size(x,2)
    v = x(:,k);
    v = v(isfinite(v));
    if ~isempty(v)
        y(k) = prctile(v, p);
    end
end
end

function peak_mask = modelPeakMask(f, dist0, idx, nominal, cfg)
level = cfg.m9_model_dist_factor*nominal;
lo = idx;
hi = idx;
while lo > 1 && dist0(lo-1) <= level
    lo = lo - 1;
end
while hi < numel(dist0) && dist0(hi+1) <= level
    hi = hi + 1;
end
peak_mask = false(size(f));
peak_mask(lo:hi) = true;
if nnz(peak_mask) < cfg.m9_min_bins
    peak_mask = abs(f - f(idx)) <= cfg.m9_min_peak_half_width_hz;
end
end
