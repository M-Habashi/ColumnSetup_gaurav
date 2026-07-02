function cfg = fable_kmc_config()
% FABLE_KMC_CONFIG  Tunable parameters for the fable spectral k/m/c tracker.
%
% The estimator works entirely in the frequency domain: it keeps an
% exponentially forgotten set of cross-spectra between displacement x and
% force F, forms a per-bin noise-debiased FRF  H(w) = F/X, and fits the
% specimen model
%
%     H(w) = k - m*w^2 + 1i*(h0 + c*w)
%
% by robust, information-weighted least squares at every hop. h0 [N/m] is a
% frequency-flat quadrature (hysteretic/structural damping) term; the loss
% factor is eta = h0/k. Measured records on this rig show |h0| ~ 0.4e6 N/m,
% so omitting it (pure viscous model) corrupts the damping estimate.
%
% ------------------------- TIME/FREQUENCY KNOBS -------------------------
% seg_s   Segment length [s] of each Hann-windowed FFT. Sets the frequency
%         resolution df = 1/seg_s. Longer segments resolve the fit band
%         more finely but respond slower and need longer records.
%         Range 1..4 s. Default 2.
cfg.seg_s = 2;

% hop_s   Update cadence [s]. A new estimate is produced every hop. Smaller
%         hops give a denser track at slightly more compute; they do NOT
%         reduce smoothing (mem_s does that). Range 0.1..1. Default 0.25.
cfg.hop_s = 0.25;

% mem_s   Exponential memory [s] of the spectral averages - THE main
%         smoothness/tracking trade-off. The spectra (and hence the
%         parameter track) forget with time constant mem_s: larger =
%         smoother and more accurate under stationary excitation, smaller =
%         faster reaction to genuine stiffness change. A stiffness step is
%         ~63% absorbed after mem_s seconds. Range 4..30. Default 10.
cfg.mem_s = 10;

% noise_s Seconds of quiet (zero-command) data at the start of the record
%         used to measure per-bin sensor noise floors Nxx(f), Nff(f).
%         The floors debias the FRF (H = Sxf/(Sxx-Nxx)) and drive the SNR
%         gate. Matches the project convention of 2 s quiet starts.
cfg.noise_s = 2;

% ----------------------------- FIT BAND ---------------------------------
% band_hz  [f_lo f_hi] fit band [Hz]. f_lo excludes drift/DC leakage;
%          f_hi bounds how much mass curvature (m*w^2) information is used.
%          On this rig the x->F coherence is high to ~55 Hz and the
%          resonance sits near 58-64 Hz; k information lives at the low
%          end, m information at the high end. Default [2 50].
cfg.band_hz = [2 50];

% coh_min  Per-bin magnitude-squared coherence gate. Bins below it carry
%          little information and are dropped. Range 0.7..0.95. Default 0.85.
cfg.coh_min = 0.85;

% snr_min_db  Per-bin displacement SNR gate [dB] vs the quiet-period noise
%          floor. Bins the command does not actually excite are dropped, so
%          band-limited excitation (e.g. 2-7 Hz sines) automatically
%          shrinks the working band instead of polluting the fit.
%          Range 6..20. Default 10.
cfg.snr_min_db = 10;

% guard_frac  Resonance guard: bins where |H| < guard_frac * median|H| of
%          the currently selected bins are excluded. Near the specimen
%          resonance |H| -> 0 and small model errors explode; this keeps
%          the fit on the well-modelled side while still following sudden
%          stiffness drops (the reference is per-hop, not the tracked k).
%          Range 0.2..0.5. Default 0.3.
cfg.guard_frac = 0.3;

% n_min    Minimum number of selected bins to attempt a fit; below it the
%          estimator holds the last value (status = 2). Default 6.
cfg.n_min = 6;

% ------------------------ ROBUSTNESS / PRIORS ---------------------------
% huber_k  Huber threshold (in standardized-residual sigmas) of the IRLS
%          robust reweighting. Bins whose residual exceeds huber_k sigmas
%          (local resonances, harmonic distortion, transients) get bounded
%          influence. Smaller = more aggressive outlier rejection.
%          Range 1.5..4. Default 2.5.
cfg.huber_k = 2.5;

% irls_iters  Number of Huber reweighting passes after the initial WLS fit.
%          0 disables robustification. Default 2.
cfg.irls_iters = 2;

% prior_rel  [m c k h0] dimensionless ridge strengths pulling each
%          parameter toward its previous value, RELATIVE to the data
%          information about that parameter (Lambda_jj = prior_rel_j *
%          diag(A'WA)_jj). 0 = pure data; 1 = data and history weighted
%          equally; >>1 = parameter effectively frozen. This is what keeps
%          the weakly observable m, c, h0 smooth when the excitation band
%          momentarily stops informing them, WITHOUT damping the k track
%          (k prior is kept near zero so stiffness stays data-driven).
%          Default [0.5 2 0.02 0.5].
cfg.prior_rel = [0.5 2 0.02 0.5];

% fit_h0   Include the hysteretic quadrature term h0. Set false to force a
%          pure viscous model (h0 = 0) for comparisons; expect c to absorb
%          the flat quadrature and become band-dependent. Default true.
cfg.fit_h0 = true;

% ---------------------- FAST ADAPTATION ON CHANGE -----------------------
% The spectral memory mem_s smooths, but a genuine abrupt stiffness change
% would otherwise take ~mem_s seconds to absorb. When the fit residual
% suddenly becomes inconsistent with its own recent history (the averaged
% spectra mix two regimes), the old statistics are discounted once so new
% data dominates. Power-level changes alone do not trigger this - the FRF
% shape, not the excitation intensity, drives the residual.
%
% adapt_enable  Master switch for the innovation-triggered discount.
cfg.adapt_enable = true;

% adapt_ratio   Trigger threshold on the pooled fast-vs-slow FRF distance
%          (median standardized squared difference, ~chi-square scaled;
%          out.z_change logs it). Healthy stationary records sit near 0.2
%          with excursions to ~1.4; genuine plant changes reach 3+.
%          Larger = more conservative (fewer resets). Range 2..8. Default 3.
cfg.adapt_ratio = 3;

% adapt_discount  Multiplier applied to the accumulated spectra on trigger.
%          0.25 means the old data keeps 25% weight, i.e. tracking speeds
%          up ~4x for one memory span. Range 0.1..0.5. Default 0.25.
cfg.adapt_discount = 0.25;

% adapt_cooldown_s  Minimum time between discounts, letting the statistics
%          re-form before another reset is allowed. Default 5.
cfg.adapt_cooldown_s = 5;

% mem_fast_s  Memory [s] of a secondary short spectra set used only for
%          change detection: if the newest data is coherent (fast set)
%          while the slow average is not, the slow statistics are stale
%          after an abrupt plant change and get discounted. Should be a
%          small multiple of seg_s. Default 3.
cfg.mem_fast_s = 3;

% ------------------------- OUTPUT CONDITIONING --------------------------
% smooth_s  Optional extra first-order smoothing [s] applied to the output
%          parameter track. 0 disables it (default): the spectral memory
%          already smooths at the sufficient-statistic level, which is the
%          right place; use this only to polish plots.
cfg.smooth_s = 0;

% min_neff  Minimum effective number of independent segment averages before
%          the first estimate is issued (controls startup transient).
%          Default 3.
cfg.min_neff = 3;
end
