function out = osi_method6_kf(ctx, cfg)
%OSI_METHOD6_KF Recursive frequency-point Kalman filter for the NCF margin.
%
% Idea (Method 6). Start from the KNOWN model H0 and place one complex Kalman
% state on each of a few discrete transfer-function points H_i = H(j2*pi*f_i),
% i = 1..nf, on a grid that brackets the binding ~35 Hz resonance. Every
% m6_hop seconds (default 0.5 s) take a SHORT sliding analysis buffer, form a
% single-snapshot H1 measurement z_i and the coherence gamma_i^2 at each f_i,
% and fuse the measurement into the state with a Kalman update whose
% measurement noise R_i is ADAPTIVE in the coherence:
%
%   random error of an H1 point (Bendat & Piersol):
%       eps_i^2 = (1 - gamma_i^2) / (2 * n_d * gamma_i^2)
%   measurement noise (variance of the complex point):
%       R_i = eps_i^2 * |z_i|^2 + R_floor * |H_i|^2
%
% Scalar complex Kalman update per point (state transition = identity, i.e. a
% random walk; process noise Q_i lets the point drift to track the plant):
%       K_i = P_i / (P_i + R_i)
%       H_i <- H_i + K_i (z_i - H_i)
%       P_i <- (1 - K_i) P_i          % measurement update
%       P_i <- P_i + Q_i,  Q_i = q_rel |H_i|^2     % predict next step
%
% Low-coherence points are gated out (no update) so noise cannot corrupt the
% state. The margin each snapshot is a robust (low-percentile) statistic of the
% normalized loop distance over the points, L_i = C(f_i) H_i:
%       b = prctile_p ( |1+L_i| / sqrt(2(1+|L_i|^2)) ).
%
% Why this answers "smaller window / faster detection": reliability comes from
% temporal fusion across snapshots (the Kalman recursion), not from averaging
% inside one long window, so the update window can be small (0.5 s here) while
% the estimate stays stable. The coherence-adaptive R is what makes the tiny,
% noisy per-snapshot measurements safe to use.
%
% Inputs : ctx (from osi_load_context), cfg (from osi_config).
% Output : struct with tc (centers), ncf (median-filtered margin), ncf_raw,
%          nominal, threshold, detect_time, f6, and a coherence diagnostic.

    fs = ctx.fs; dt = ctx.dt;
    % --- discrete TF-point grid bracketing the binding resonance ---
    f6  = (cfg.m6_band(1):cfg.m6_df:cfg.m6_band(2)).';  nf = numel(f6);
    Cf6  = squeeze(freqresp(ctx.C,   2*pi*f6));         % known PID at the points
    H0_6 = squeeze(freqresp(ctx.H0d, 2*pi*f6));         % nominal plant (state init)

    dist   = @(L) abs(1+L) ./ sqrt(2*(1+abs(L).^2));
    margin = @(L) prctile(dist(L), cfg.m6_prctile);
    nom6   = margin(Cf6 .* H0_6);

    % --- buffering / sub-segment setup ---
    Nbuf = round(cfg.m6_buf * fs);
    Lsub = cfg.m6_Lsub;  hsub = cfg.m6_hsub;  win = hann(Lsub);
    starts = 1:hsub:(Nbuf - Lsub + 1);  n_d = numel(starts);
    E = exp(-1j*2*pi*(0:Lsub-1).' * f6.' / fs);         % exact-frequency DTFT matrix

    % --- snapshot times (buffer END, stepped by hop) ---
    tend = (cfg.t_start + cfg.m6_buf) : cfg.m6_hop : cfg.t_end;
    nW   = numel(tend);   tc = tend.' - cfg.m6_buf/2;

    % --- Kalman state (one complex point per frequency) ---
    H = H0_6;                            % start from the known model
    P = (cfg.m6_P0_rel * abs(H0_6)).^2;  % small initial covariance (trust model)
    ncf_raw  = nan(nW, 1);
    coh35    = nan(nW, 1);               % coherence near 35 Hz, for diagnostics
    [~, i35] = min(abs(f6 - 35));

    for k = 1:nW
        i1 = find(ctx.t >= tend(k) - cfg.m6_buf, 1);
        idx = i1:i1+Nbuf-1;
        x = ctx.dc(idx);  y = ctx.dm(idx);
        Sxx = zeros(nf,1); Syy = Sxx; Sxy = Sxx;
        for s = starts
            Xs = ((win .* detrend(x(s:s+Lsub-1))).' * E).';
            Ys = ((win .* detrend(y(s:s+Lsub-1))).' * E).';
            Sxx = Sxx + abs(Xs).^2;  Syy = Syy + abs(Ys).^2;  Sxy = Sxy + Ys.*conj(Xs);
        end
        z    = Sxy ./ max(Sxx, eps);
        gam2 = min(abs(Sxy).^2 ./ max(Sxx.*Syy, eps), 1);
        gam2 = max(0, (n_d*gam2 - 1) / (n_d - 1));        % small-sample bias correction
        coh35(k) = gam2(i35);

        if k > cfg.m6_nwarm                                % freeze during weak warm-up
            eps2 = (1 - gam2) ./ (2*n_d*max(gam2, 1e-2));
            R = eps2 .* abs(z).^2 + cfg.m6_R_floor_rel * abs(H).^2;
            pdc = 10*log10(Sxx + eps);                     % input power per point
            excited = pdc >= max(pdc) - cfg.input_power_range_db;
            upd = (gam2 >= cfg.m6_gamma_min) & excited;    % gate low-confidence / unexcited points
            K = zeros(nf,1);  K(upd) = P(upd) ./ (P(upd) + R(upd));
            H = H + K.*(z - H);                            % measurement update
            P = (1 - K).*P;
            P = P + cfg.m6_q_rel * abs(H).^2;              % predict next step
            ncf_raw(k) = margin(Cf6 .* H);
        else
            ncf_raw(k) = nom6;                             % hold model during warm-up
        end
    end

    ncf = medfilt1(ncf_raw, cfg.m6_medfilt);
    ncf(1:cfg.m6_nwarm) = nom6;

    % sustained-below-threshold detection
    below = ncf < cfg.ncf_threshold;
    run_c = movsum(below, [cfg.m6_detect_consec-1, 0]);
    hit = find(run_c >= cfg.m6_detect_consec, 1);
    detect_time = NaN;  if ~isempty(hit), detect_time = tc(hit); end

    out = struct('tc', tc, 'ncf', ncf, 'ncf_raw', ncf_raw, 'nominal', nom6, ...
        'threshold', cfg.ncf_threshold, 'detect_time', detect_time, ...
        'f6', f6, 'coh35', coh35, 'n_d', n_d);
end
