function out = fable_kmc(x, F, fs, cfg)
% FABLE_KMC  Causal spectral errors-in-variables tracker of specimen k, m, c.
%
%   out = fable_kmc(x, F, fs, cfg)
%
% Units: x [m], F [N], fs [Hz]; theta columns are m [kg], c [N*s/m],
% k [N/m], h0 [N/m] (hysteretic quadrature, loss factor eta = h0/k).
%
% Pipeline per hop (every cfg.hop_s seconds):
%   1. FFT the newest cfg.seg_s Hann segment of x and F (no time-domain
%      differentiation anywhere - d/dt is exact multiplication by jw).
%   2. Update exponentially forgotten auto/cross spectra with memory
%      cfg.mem_s (smoothing happens at the sufficient-statistic level).
%   3. Debias the FRF per bin with the quiet-period displacement noise
%      floor: H = Sxf/(Sxx - Nxx). This removes the attenuation bias that
%      displacement noise puts on any regression of F on x.
%   4. Keep only informative bins (band, SNR, coherence, resonance guard).
%   5. Robust (Huber IRLS) information-weighted fit of
%      H(w) = k - m*w^2 + 1i*(h0 + c*w), each bin weighted by the inverse
%      variance of its FRF estimate, with relative ridge priors pulling
%      weakly observable parameters toward their previous values.
%
% out fields: t [s], theta [n x 4], sigma [n x 4] (1-sigma), status
% (0 = acquiring, 1 = tracking, 2 = hold), nbins, neff, eta, k_direct
% (nonparametric low-band k diagnostic), f, cfg.

x = x(:);
F = F(:);
n = numel(x);

nseg = 2*floor(round(cfg.seg_s*fs)/2);
nhop = max(1, round(cfg.hop_s*fs));
hop_s = nhop/fs;
win = hann(nseg, 'periodic');
psd_norm = 1/(fs*sum(win.^2));
nbin = nseg/2 + 1;
f = (0:nbin-1)'*fs/nseg;
w_ang = 2*pi*f;

Nxx = quiet_noise_floor(x, fs, cfg, nseg);

lambda = exp(-hop_s/cfg.mem_s);
indep = min(1, 2*hop_s/cfg.seg_s);
Sxx = zeros(nbin, 1);
Sff = zeros(nbin, 1);
Sxf = complex(zeros(nbin, 1));
w1 = 0;
w2 = 0;

% Fast (short-memory) spectra: only used to detect that the slow set has
% gone stale after an abrupt plant change (fast coherent, slow not).
lambda_f = exp(-hop_s/cfg.mem_fast_s);
Sxx_f = zeros(nbin, 1);
Sff_f = zeros(nbin, 1);
Sxf_f = complex(zeros(nbin, 1));
w1f = 0;

noise_end = round(cfg.noise_s*fs);
hop_ends = (noise_end + nseg):nhop:n;
nh = numel(hop_ends);

npar = 4;
theta = nan(nh, npar);
sigma = nan(nh, npar);
status = zeros(nh, 1);
nbins = zeros(nh, 1);
neff_log = zeros(nh, 1);
k_direct = nan(nh, 1);

band = f >= cfg.band_hz(1) & f <= cfg.band_hz(2);
snr_min = 10^(cfg.snr_min_db/10);
prior_rel = cfg.prior_rel(:);
if ~cfg.fit_h0
    prior_rel(4) = 1e12;   % freeze h0 at 0
end

initialized = false;
theta_prev = zeros(npar, 1);
sigma_prev = zeros(npar, 1);
hold_start = NaN;
adapted = false(nh, 1);
z_change = nan(nh, 1);
last_adapt = -inf;
alpha_out = 0;
if cfg.smooth_s > 0
    alpha_out = 1 - exp(-hop_s/cfg.smooth_s);
end

for h = 1:nh
    i2 = hop_ends(h);
    seg = (i2 - nseg + 1):i2;
    X = fft(win.*(x(seg) - mean(x(seg))));
    Y = fft(win.*(F(seg) - mean(F(seg))));
    X = X(1:nbin);
    Y = Y(1:nbin);

    Sxx = lambda*Sxx + (1 - lambda)*(abs(X).^2)*psd_norm;
    Sff = lambda*Sff + (1 - lambda)*(abs(Y).^2)*psd_norm;
    Sxf = lambda*Sxf + (1 - lambda)*(conj(X).*Y)*psd_norm;
    w1 = lambda*w1 + (1 - lambda);
    w2 = lambda^2*w2 + (1 - lambda)^2;

    Sxx_f = lambda_f*Sxx_f + (1 - lambda_f)*(abs(X).^2)*psd_norm;
    Sff_f = lambda_f*Sff_f + (1 - lambda_f)*(abs(Y).^2)*psd_norm;
    Sxf_f = lambda_f*Sxf_f + (1 - lambda_f)*(conj(X).*Y)*psd_norm;
    w1f = lambda_f*w1f + (1 - lambda_f);

    Pxx = Sxx/w1;
    Pff = Sff/w1;
    Pxf = Sxf/w1;
    neff = max(1, (w1^2/w2)*indep);
    neff_log(h) = neff;

    coh = abs(Pxf).^2 ./ max(Pxx.*Pff, realmin);
    snr = Pxx./max(Nxx, realmin);
    H = Pxf./max(Pxx - Nxx, 0.25*Pxx);

    sel = band & snr > snr_min & coh > cfg.coh_min & isfinite(H);
    if any(sel)
        h_ref = median(abs(H(sel)));   % per-hop level, follows sudden k drops
    else
        h_ref = 0;
    end
    sel = sel & abs(H) > cfg.guard_frac*h_ref;
    nbins(h) = nnz(sel);

    % Regime-change detection: pooled fast-vs-slow FRF distance. When the
    % newest data (fast set) disagrees with the slow average far beyond
    % the fast set's own noise level, the plant changed - discount the
    % slow statistics so tracking accelerates. Power changes alone do not
    % move H, so excitation-level swings cannot trigger this.
    t_now = (i2 - 1)/fs;
    if cfg.adapt_enable
        Pxx_f = Sxx_f/max(w1f, realmin);
        Pff_f = Sff_f/max(w1f, realmin);
        Pxf_f = Sxf_f/max(w1f, realmin);
        coh_f = abs(Pxf_f).^2./max(Pxx_f.*Pff_f, realmin);
        pre = band & snr > snr_min & coh_f > cfg.coh_min;
        neff_f = max(1, (cfg.mem_fast_s/cfg.seg_s));
        if nnz(pre) >= cfg.n_min
            Hf = Pxf_f./max(Pxx_f, realmin);
            var_f = abs(Hf(pre)).^2.*(1 - coh_f(pre))./max(coh_f(pre), eps)/(2*neff_f);
            z = abs(Hf(pre) - H(pre)).^2./max(var_f, realmin);
            z_change(h) = median(z);
        end
        trigger = z_change(h) > cfg.adapt_ratio ...
            && (t_now - last_adapt) > cfg.adapt_cooldown_s;
        if trigger && initialized
            Sxx = Sxx*cfg.adapt_discount;
            Sff = Sff*cfg.adapt_discount;
            Sxf = Sxf*cfg.adapt_discount;
            w1 = w1*cfg.adapt_discount;
            w2 = w2*cfg.adapt_discount^2;
            last_adapt = t_now;
            adapted(h) = true;
        end
    end

    can_fit = nbins(h) >= cfg.n_min && neff >= cfg.min_neff;
    if can_fit
        wv = w_ang(sel);
        g2 = coh(sel);
        Hs = H(sel);
        var_bin = abs(Hs).^2 .* (1 - g2)./max(g2, eps)/(2*neff);
        wt = 1./max(var_bin, realmin);

        A = [-wv.^2, zeros(size(wv)), ones(size(wv)), zeros(size(wv));
             zeros(size(wv)), wv, zeros(size(wv)), ones(size(wv))];
        b = [real(Hs); imag(Hs)];
        wrow = [wt; wt];

        if ~initialized
            theta_prev = plain_wls(A, b, wrow);
            theta_prev(1) = max(theta_prev(1), 0);
            theta_prev(3) = max(theta_prev(3), 1);
        end

        [th, sg] = ridge_huber_fit(A, b, wrow, theta_prev, prior_rel, ...
            cfg.huber_k, cfg.irls_iters);
        th(1) = max(th(1), 0);
        th(3) = max(th(3), 1);

        if alpha_out > 0 && initialized
            th = theta_prev + alpha_out*(th - theta_prev);
        end
        theta_prev = th;
        sigma_prev = sg;
        initialized = true;
        hold_start = NaN;
        status(h) = 1;

        lo = sel & f <= min(10, cfg.band_hz(2));
        if nnz(lo) >= 3
            k_direct(h) = median(real(H(lo)));
        end
    elseif initialized
        status(h) = 2;
        if isnan(hold_start)
            hold_start = h;
        end
        sigma_prev_h = sigma_prev*sqrt(1 + (h - hold_start)*hop_s/cfg.mem_s);
        theta(h, :) = theta_prev';
        sigma(h, :) = sigma_prev_h';
        continue
    else
        status(h) = 0;
        continue
    end

    theta(h, :) = theta_prev';
    sigma(h, :) = sigma_prev';
end

out.t = (hop_ends(:) - 1)/fs;
out.theta = theta;
out.sigma = sigma;
out.status = status;
out.nbins = nbins;
out.neff = neff_log;
out.eta = theta(:, 4)./max(theta(:, 3), realmin);
out.k_direct = k_direct;
out.adapted = adapted;
out.z_change = z_change;
out.f = f;
out.cfg = cfg;
end

function theta = plain_wls(A, b, wrow)
% Unpenalized weighted least squares (initialization only).
Aw = A.*wrow;
theta = (Aw'*A)\(Aw'*b);
if ~all(isfinite(theta))
    theta = zeros(size(A, 2), 1);
    theta(3) = median(b(1:round(end/2)));
end
end

function [theta, sigma] = ridge_huber_fit(A, b, wrow, theta_prev, prior_rel, huber_k, irls_iters)
% Information-weighted fit with relative ridge priors and Huber IRLS.
% Units: A/b rows are N/m; theta is [kg, N*s/m, N/m, N/m].
hw = ones(size(b));
theta = theta_prev;
for it = 0:irls_iters
    wr = wrow.*hw;
    Aw = A.*wr;
    N = Aw'*A;
    dN = max(diag(N), max(diag(N))*1e-12);
    Lam = diag(prior_rel.*dN);
    theta = (N + Lam)\(Aw'*b + Lam*theta_prev);

    if it < irls_iters
        e = (A*theta - b).*sqrt(wrow);
        s = 1.4826*median(abs(e - median(e)));
        if s <= 0
            break
        end
        z = abs(e)/s;
        hw = min(1, huber_k./max(z, eps));
    end
end

e = (A*theta - b).*sqrt(wrow.*hw);
dof = max(numel(b) - size(A, 2), 1);
sig2_scale = (e'*e)/dof;
C = sig2_scale*inv(N + Lam); %#ok<MINV>
sigma = sqrt(max(diag(C), 0));
end

function Nxx = quiet_noise_floor(x, fs, cfg, nseg)
% Per-bin displacement noise PSD from the quiet start, Welch-averaged with
% short segments, interpolated to the analysis grid and frequency-smoothed.
% Only the displacement floor is needed - it is what biases the FRF.
% Units: x [m]; output is a PSD on the nseg/2+1 bin grid.
nq = min(round(cfg.noise_s*fs), numel(x));
nseg_q = 2*floor(nseg/8);
hop_q = floor(nseg_q/2);
win_q = hann(nseg_q, 'periodic');
norm_q = 1/(fs*sum(win_q.^2));
nbin_q = nseg_q/2 + 1;
fq = (0:nbin_q-1)'*fs/nseg_q;

Pq_x = zeros(nbin_q, 1);
cnt = 0;
for i1 = 1:hop_q:(nq - nseg_q + 1)
    seg = i1:(i1 + nseg_q - 1);
    Xq = fft(win_q.*(x(seg) - mean(x(seg))));
    Pq_x = Pq_x + abs(Xq(1:nbin_q)).^2*norm_q;
    cnt = cnt + 1;
end
if cnt == 0
    Pq_x = ones(nbin_q, 1)*realmin;
else
    Pq_x = Pq_x/cnt;
end

nbin = nseg/2 + 1;
fgrid = (0:nbin-1)'*fs/nseg;
Nxx = interp1(fq, movmedian(Pq_x, 5), fgrid, 'linear', 'extrap');
Nxx = max(Nxx, realmin);
end
