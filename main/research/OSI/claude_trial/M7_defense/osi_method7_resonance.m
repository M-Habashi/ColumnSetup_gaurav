function out = osi_method7_resonance(ctx, cfg)
%OSI_METHOD7_RESONANCE Output-only closed-loop resonance / sensitivity-peak NCF.
%
% Why this method. At the binding ~35 Hz mode the open-loop FRF dm/dc is a
% tautology when the input does not excite 35 Hz: e = dd - dm ~ -dm there, so
% dm/dc ~ -1/C and L = C*H ~ -1 REGARDLESS of the true margin -- the FRF methods
% cannot see it (the 1749 low-frequency-input case). But the *closed-loop*
% 35 Hz resonance grows as the margin shrinks and is amplified by internal
% disturbance/noise, so it is plainly visible in dm ALONE. This method reads it.
%
% Estimate, per window, the resonance amplification
%       Spk = sqrt( max_PSD(dm, peak_band) / median_PSD(dm, floor_band) )
% which approximates the peak sensitivity ||S||_inf ~ 1/min|1+L|. The loop-only
% NCF near the binding mode is b ~ min|1+L|/sqrt(2(1+|L|^2)) ~ const/Spk, so with
% the "model correct at the beginning" assumption the map is calibrated at start:
%       b(t) = b_nom * Spk_ref / Spk(t),   Spk_ref = median(Spk over first calib_s)
% where b_nom is the model's loop-only NCF over the binding band. Input-agnostic:
% works for broadband (1731) and low-frequency (1749) inputs alike.
%
% Output: struct with tc, ncf (b), nominal (b_nom), threshold, detect_time, Spk.

    fs = ctx.fs;
    fb = logspace(log10(cfg.m7_binding_band(1)), log10(cfg.m7_binding_band(2)), 2000).';
    b_nom = osi_ncf_looponly(squeeze(freqresp(ctx.C*ctx.H0d, 2*pi*fb)));  % binding NCF (~0.588)

    buf = cfg.m7_buf;  Nbuf = round(buf*fs);
    nfft = 2^nextpow2(round(2*fs));  seg = min(2048, Nbuf);  ov = round(seg/2);
    win = hann(seg);
    tend = (cfg.t_start + buf) : cfg.m7_hop : cfg.t_end;
    nW = numel(tend);  tc = tend.' - buf/2;

    Spk = nan(nW,1);
    for k = 1:nW
        i1 = find(ctx.t >= tend(k) - buf, 1);
        y = detrend(ctx.dm(i1:i1+Nbuf-1));
        [pp, ff] = pwelch(y, win, ov, nfft, fs);
        peak = max(pp(ff >= cfg.m7_peak_band(1)  & ff <= cfg.m7_peak_band(2)));
        flr  = median(pp(ff >= cfg.m7_floor_band(1) & ff <= cfg.m7_floor_band(2)));
        Spk(k) = sqrt(peak / max(flr, eps));
    end
    Spk = medfilt1(Spk, cfg.m7_medfilt);

    Sref = median(Spk(tc < cfg.t_start + cfg.m7_calib_s), 'omitnan');
    ncf  = min(b_nom * Sref ./ Spk, cfg.m7_cap);

    below = ncf < cfg.ncf_threshold;
    hit = find(movsum(below, [cfg.m7_detect_consec-1, 0]) >= cfg.m7_detect_consec, 1);
    detect_time = NaN; if ~isempty(hit), detect_time = tc(hit); end

    out = struct('tc', tc, 'ncf', ncf, 'nominal', b_nom, 'threshold', cfg.ncf_threshold, ...
        'detect_time', detect_time, 'Spk', Spk, 'Sref', Sref);
end
