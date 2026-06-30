function out = osi_method8_ncf_direct(ctx, cfg)
%OSI_METHOD8_NCF_DIRECT Direct NCF margin from the closed-loop S,T (no GM step).
%
% A new OSI indicator. Instead of identifying the open-loop FRF and reading a gain
% margin (which is blind to a low phase margin), it estimates the inner closed-loop
% complementary sensitivity directly and converts it to the loop-only NCF margin
% with the exact identity
%
%   b(w) = |1+L|/sqrt(2(1+|L|^2)) = 1/(sqrt(2)*sqrt(|S(jw)|^2 + |T(jw)|^2))
%   NCF  = min_w b(w) = 1/(sqrt(2)*max_w sqrt(|S|^2 + |T|^2))
%
% Because it uses |S| and |T| at EVERY frequency it sees the whole Nyquist curve,
% so it catches a near-(-1) approach at the gain crossover (low PM) that a gain
% margin misses. It needs no dither and no model inversion:
%   - T is the measurable closed-loop FRF from the command to the output. For the
%     inner actuator loop that is T = dm/dd_lead (both already logged).
%   - assuming UNITY feedback, S = 1 - T  (the user-accepted assumption).
%
% Conditioning note vs the open-loop FRF methods (M1/M6): those estimate the plant
% dm/dc, which under feedback lock at ~35 Hz collapses to the tautology -1/C and
% FALSE-alarms when the input does not excite 35 Hz. M8 uses T = dm/dd_lead with
% the EXOGENOUS command dd_lead, so an unexcited binding bin simply has low
% coherence and is gated out -- M8 never false-collapses. The price of "no dither"
% is that, like the FRF methods, M8 can only SEE the 35 Hz collapse when the
% command actually excites 35 Hz (high/mixed bands); under a purely low-frequency
% input it is blind-but-safe there, whereas output-only M7 still detects.
%
% Inputs : ctx with fields fs, t, dd_lead (inner-loop command), dm, C, H0d;
%          cfg with m8_* fields (band, df, buf, hop, Lsub, hsub, gamma_min,
%          prctile_hi, medfilt, nwarm, detect_consec), input_power_range_db,
%          ncf_threshold.
% Output : struct with tc, ncf, ncf_raw, nominal, threshold, detect_time, f8.

    fs = ctx.fs;
    f8 = (cfg.m8_band(1):cfg.m8_df:cfg.m8_band(2)).';  nf = numel(f8);
    nom = osi_ncf_looponly(squeeze(freqresp(ctx.C*ctx.H0d, 2*pi*f8)));  % model NCF (ref line)

    Nbuf = round(cfg.m8_buf*fs);
    Lsub = cfg.m8_Lsub;  hsub = cfg.m8_hsub;  win = hann(Lsub);
    starts = 1:hsub:(Nbuf-Lsub+1);  n_d = numel(starts);
    E = exp(-1j*2*pi*(0:Lsub-1).' * f8.' / fs);          % exact-frequency DTFT matrix

    tend = (cfg.t_start + cfg.m8_buf) : cfg.m8_hop : cfg.t_end;
    nW = numel(tend);  tc = tend.';   % causal timestamp = window-end time (look-back only)
    ncf_raw = nan(nW, 1);

    for k = 1:nW
        i1 = find(ctx.t >= tend(k) - cfg.m8_buf, 1);
        idx = i1:i1+Nbuf-1;
        u = ctx.dd_lead(idx);  y = ctx.dm(idx);          % command -> output
        Suu = zeros(nf,1);  Syy = Suu;  Suy = Suu;
        for s = starts
            Us = ((win .* detrend(u(s:s+Lsub-1))).' * E).';
            Ys = ((win .* detrend(y(s:s+Lsub-1))).' * E).';
            Suu = Suu + abs(Us).^2;  Syy = Syy + abs(Ys).^2;  Suy = Suy + Ys.*conj(Us);
        end
        That = Suy ./ max(Suu, eps);                      % closed-loop FRF T = dm/dd_lead
        gam2 = min(abs(Suy).^2 ./ max(Suu.*Syy, eps), 1);
        gam2 = max(0, (n_d*gam2 - 1) / (n_d - 1));        % small-sample bias correction
        pin = 10*log10(Suu + eps);                        % command power per bin
        excited = pin >= max(pin) - cfg.input_power_range_db;
        keepb = (gam2 >= cfg.m8_gamma_min) & excited;     % gate unexcited / low-coherence bins
        if k > cfg.m8_nwarm && nnz(keepb) >= 3
            Tk = That(keepb);  Sk = 1 - Tk;               % unity feedback: S = 1 - T
            st = sqrt(abs(Sk).^2 + abs(Tk).^2);           % = 1/(sqrt(2)*b(w))
            ncf_raw(k) = 1/(sqrt(2)*prctile(st, cfg.m8_prctile_hi));  % robust min-distance
        else
            ncf_raw(k) = nom;                             % hold model during warm-up
        end
    end

    ncf = movmedian(ncf_raw, [cfg.m8_medfilt-1, 0]);   % TRAILING median (backward only)
    ncf(1:min(cfg.m8_nwarm, nW)) = nom;

    below = ncf < cfg.ncf_threshold;  below(isnan(ncf)) = false;
    hit = find(movsum(below, [cfg.m8_detect_consec-1, 0]) >= cfg.m8_detect_consec, 1);
    detect_time = NaN;  if ~isempty(hit), detect_time = tc(hit); end

    out = struct('tc', tc, 'ncf', ncf, 'ncf_raw', ncf_raw, 'nominal', nom, ...
        'threshold', cfg.ncf_threshold, 'detect_time', detect_time, 'f8', f8);
end
