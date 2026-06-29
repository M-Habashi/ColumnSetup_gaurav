function out = osi_method9_adaptive_margin(ctx, cfg)
%OSI_METHOD9_ADAPTIVE_MARGIN M9.1 phase-aware adaptive NCF estimator.
%
% M9.1 fuses only branches 2 and 3 on one frequency grid:
%   2) excited bins: direct closed-loop S,T NCF from T = dm/dd_lead and S = 1-T;
%   3) residual output spectrum normalized by the healthy start.
%
% The S,T branch is absolute and phase-aware. The residual branch is the
% output-only fallback; it normally searches the input-quiet remainder of the
% configured band. A full-band residual early-warning path can be enabled when
% it agrees with the direct S,T branch frequency. Branch 1's known-mode
% peak/floor proxy is intentionally not used.

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
seg_idx = (0:Lsub-1).' + starts;
nfft = 2^nextpow2(max(Lsub, round(fs/cfg.m9_df)));
bins = round(f9*nfft/fs) + 1;

tend = (cfg.t_start + cfg.m9_buf):cfg.m9_hop:cfg.t_end;
nW = numel(tend);
tc = tend.' - cfg.m9_buf/2;
i1s = round((tend - cfg.m9_buf - ctx.t(1))*fs) + 1;

That = nan(nf, nW);
gam2 = nan(nf, nW);
pin = nan(nf, nW);
pres = nan(nf, nW);
pyy = nan(nf, nW);

for k = 1:nW
    idx = i1s(k):i1s(k)+Nbuf-1;
    u = ctx.dd_lead(idx);
    y = ctx.dm(idx);
    U = fft(win.*detrend(u(seg_idx)), nfft, 1);
    Y = fft(win.*detrend(y(seg_idx)), nfft, 1);
    U = U(bins,:);
    Y = Y(bins,:);
    wseg = segmentWeights(n_d, cfg.m9_bootstrap_strength);
    Suu = abs(U).^2*wseg;
    Syy = abs(Y).^2*wseg;
    Suy = (Y.*conj(U))*wseg;
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

q_ref = median(local_prctile(ratio(:, cal_mask), cfg.m9_res_prctile), 'omitnan');
if ~isfinite(q_ref) || q_ref <= 0
    q_ref = 1;
end

ncf_res = nan(nW,1);
ncf_res_early = nan(nW,1);
ncf_st = nan(nW,1);
f_res = nan(nW,1);
f_res_early = nan(nW,1);
f_st = nan(nW,1);
n_excited = zeros(nW,1);
n_quiet = zeros(nW,1);

for k = 1:nW
    excited = pin(:,k) >= max(pin(:,k), [], 'omitnan') - cfg.input_power_range_db;
    keep = excited & gam2(:,k) >= cfg.m9_gamma_min & freq_keep;
    n_excited(k) = nnz(keep);
    quiet_keep = freq_keep & ~keep;
    n_quiet(k) = nnz(quiet_keep);

    q_scan = ratio(:,k);
    q_scan(~quiet_keep) = NaN;
    [q_now, iq] = max(q_scan, [], 'omitnan');
    if isempty(q_now) || ~isfinite(q_now) || q_now <= 0
        q_now = q_ref;
        iq = nominal_idx;
    end
    f_res(k) = f9(iq);
    ncf_res(k) = min(cfg.m9_cap, nominal*sqrt(q_ref/max(q_now, q_ref)));

    if cfg.m9_residual_early_all_bins
        q_scan = ratio(:,k);
        q_scan(~freq_keep) = NaN;
        [q_now, iq] = max(q_scan, [], 'omitnan');
        if isempty(q_now) || ~isfinite(q_now) || q_now <= 0
            q_now = q_ref;
            iq = nominal_idx;
        end
        f_res_early(k) = f9(iq);
        ncf_res_early(k) = min(cfg.m9_cap, nominal*sqrt(q_ref/max(q_now, q_ref)));
    end

    if k > cfg.m9_nwarm && nnz(keep) >= cfg.m9_min_bins
        T = That(keep,k);
        S = 1 - T;
        st = sqrt(abs(S).^2 + abs(T).^2);
        st_hi = prctile(st, cfg.m9_st_prctile);
        [~, ist] = min(abs(st - st_hi));
        ftmp = f9(keep);
        f_st(k) = ftmp(ist);
        ncf_hat = 1/(sqrt(2)*max(st_hi, eps));
        if ncf_hat < nominal
            ncf_hat = nominal*(ncf_hat/nominal)^cfg.m9_st_power;
        end
        ncf_st(k) = min(cfg.m9_cap, ncf_hat);
    else
        ncf_st(k) = cfg.m9_cap;
        f_st(k) = NaN;
    end

    if isfinite(f_st(k)) && ncf_st(k) > cfg.m9_res_early_st_gate_frac*nominal ...
            && ncf_st(k) < nominal
        ncf_floor = cfg.m9_res_early_st_floor_frac*ncf_st(k);
        if isfinite(f_res(k)) && abs(f_st(k) - f_res(k)) <= cfg.m9_res_early_match_hz
            ncf_res(k) = max(ncf_res(k), ncf_floor);
        end
        if cfg.m9_residual_early_all_bins && isfinite(f_res_early(k)) ...
                && abs(f_st(k) - f_res_early(k)) <= cfg.m9_res_early_match_hz
            ncf_early = max(ncf_res_early(k), ncf_floor);
            if ncf_early < ncf_res(k)
                ncf_res(k) = ncf_early;
                f_res(k) = f_res_early(k);
            end
        end
    end
end

ncf_raw = min([ncf_st, ncf_res], [], 2, 'omitnan');
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
    'ncf_residual', ncf_res, 'ncf_residual_early', ncf_res_early, ...
    'ncf_st', ncf_st, ...
    'nominal', nominal, 'threshold', cfg.ncf_threshold, ...
    'detect_time', detect_time, 'f9', f9, ...
    'f_residual', f_res, 'f_residual_early', f_res_early, ...
    'f_st', f_st, 'n_excited', n_excited, ...
    'n_quiet', n_quiet, 'q_ref', q_ref, 'nominal_hz', f9(nominal_idx));
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

function w = segmentWeights(n, strength)
if strength <= 0
    w = ones(n, 1);
    return
end
w = -log(max(rand(n, 1), realmin));
w = 1 + strength*(w/mean(w) - 1);
w = max(w, 0);
w = n*w/sum(w);
end
