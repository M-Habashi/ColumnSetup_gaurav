function [out, state, info] = fable_osi(varargin)
%FABLE_OSI Online NCF-margin stability indicator (Fable redesign).
%
% Commands:
%   cfg    = fable_osi('config', dt, initial_loop_tf, override)
%   state  = fable_osi('state', cfg)
%   result = fable_osi('run', dd, dm, dt, initial_loop_tf, override)
%   [b, state, info] = fable_osi(dd_step, dm_step, cfg, state)   % step
%
% The step call consumes exactly cfg.step_n samples (cfg.step_s = 0.125 s)
% of dd (loop command) and dm (measured displacement) per call.
%
% TWO-SCALE architecture (fast detection, slow accuracy):
%
%   SLOW path (level, recovery authority) - every 2nd step (0.25 s):
%     1 s Hann segments in a 5 s ring (17 segments, ONE new segment FFT per
%     slow hop), median-aggregated spectra, null-calibrated coherence gate,
%     debiased chordal ST margin, evidence-based residual branch with
%     regime-aware baseline, authority-planning prediction curve.
%
%   FAST path (<= 0.5 s deficit detection) - every step (0.125 s):
%     0.25 s Hann segments in a short ring (span ~0.6 s).
%     * fast ST margin b_f over the slow path's excited bins: trips when
%       b_f falls below BOTH the threshold and fast_st_frac x the slow
%       margin for fast_st_n consecutive steps;
%     * quiet-band burst detector: newest fast segment's undriven-band
%       power as a calibrated log z-score, trips on fast_burst_n
%       consecutive exceedances.
%     Fast trips can only ever REDUCE authority (fable_auth trip path);
%     authority increases always require the slow, accurate margin.
%
% Margin definition (unchanged project quantity):
%   b(w) = |1 + L(w)|/sqrt(2*(1 + |L(w)|^2)) = 1/(sqrt(2)*sqrt(|S|^2+|T|^2))
% minimum over the band, capped at the mathematical ceiling 1/sqrt(2).
% Reported margin = min(slow ST, slow residual, fast ST while tripped),
% NaN when nothing is measurable (never a fabricated "nominal").
%
% All step-mode state is fixed-size numeric, so the step path can be moved
% to a MATLAB Function block / codegen with the usual flattening.
% (control_and_HS/OSI/fable_osi_runtime.m IS that flattening - keep the
% two in sync; test_fable_runtime_equivalence.m asserts they match.)
%
% ------------------------------------------------------------------------
% PER-BRANCH TUNING GUIDE - smoother <-> more aggressive, per branch.
% All knobs live in the config override (3rd/4th argument). Defaults are
% the validated values for the RTHS column rig.
%
%   SLOW ST BRANCH (the accurate margin level)
%     window_s / hop_s     Analysis span and refresh. Longer window =
%                          smoother, laggier margin; shorter = jumpier but
%                          faster to move. hop_s is the refresh cadence.
%     margin_filter_n      Temporal median over this many DISTINCT slow
%                          updates. Bigger = smoother/more constant
%                          selected OSI, adds (n-1)*hop_s/2 of lag.
%     freq_medfilt_n       Median smoothing across neighboring frequency
%                          bins before taking the min. Bigger = fewer
%                          single-bin dips counted as the margin.
%     slow_filt_alpha      EMA weight of the slow-margin tracker used by
%                          the fast path's direction gate. Lower =
%                          steadier reference, slower to follow a level
%                          change.
%     gamma_alpha          False-pass probability of the coherence gate.
%                          Smaller = stricter gate (fewer bins accepted,
%                          less noise in the margin, more "no evidence").
%     input_power_range_db Bins more than this below the in-band input
%                          peak are "unexcited". Smaller (e.g. 30) =
%                          stricter, margin computed on fewer, stronger
%                          bins.
%
%   RESIDUAL BRANCH (quiet-band growth watcher)
%     residual_band_hz     The hazard band it guards. Keep it where the
%                          loop can actually go unstable; widening it into
%                          harmonic-distortion territory causes false
%                          engagement on strong narrowband commands.
%     z_on / z_off         Engage/disengage z thresholds. Raise z_on to
%                          make engagement rarer (fewer false alarms,
%                          later detection); z_off sets the hysteresis.
%     res_on_n             Consecutive hops above z_on to engage. More =
%                          smoother (needs sustained evidence), slower.
%     res_min_growth_db    Minimum absolute growth to engage. Raise to
%                          ignore small quiet-band changes entirely.
%     res_hold_s           How long an unconfirmed engagement may persist
%                          in the hysteresis zone before it expires.
%     sigma0_floor         Floor of the calibrated ln-ratio spread. Raise
%                          to desensitize the z-score globally.
%
%   FAST ST GUARD (FRF-change CUSUM, catches sudden plant changes)
%     fast_st_nu / fast_st_h   CUSUM drift and trip level. The pair sets
%                          speed vs false-alarm rate: LOWER nu or LOWER h
%                          = more aggressive (faster trips, more risk);
%                          raise either to calm it down. h is the main
%                          knob: each unit of h adds roughly one extra
%                          0.125 s step of sustained evidence.
%     fast_babs_offset     A trip also needs b_fast < threshold + offset.
%                          Raise to allow trips further above the target
%                          (more protective), lower toward 0 to trip only
%                          when the fast margin is already at the target.
%     fast_amove_frac      The FRF-change statistic watches the TOTAL
%                          loop, which includes the authority factor. In
%                          closed loop the caller writes the currently
%                          applied authority into state.a_cmd before each
%                          step; the statistic then arms only after the
%                          authority has been steady (moves smaller than
%                          fast_amove_frac relative) for one full analysis
%                          window, so the law's own moves can never read
%                          as plant changes. Replays where the authority
%                          did not act on the plant leave a_cmd = NaN,
%                          which keeps the detector always armed.
%
%   FAST BURST GUARD (quiet-band divergence CUSUM)
%     fast_burst_nu / fast_burst_h   Same speed-vs-false-alarm trade as
%                          the ST CUSUM. A diverging loop produces huge z,
%                          so h can sit high and still trip in ~0.4 s.
%     fast_burst_bands     The guarded sub-bands (rows of [lo hi] Hz).
%                          Fewer rows = cheaper and less sensitive.
%     fast_sig_floor       Floor of the calibrated burst spread. Raise to
%                          desensitize all burst bands.
%
%   REGIME / CALIBRATION (rarely need touching)
%     regime_hops          Sustained excited-set-change hops before a
%                          rebaseline. Larger = more tolerant of slowly
%                          wandering excitation, slower to re-adapt.
%     cal_windows / cal_min_windows / cal_skip_s   Calibration length,
%                          minimum acceptable length, and startup blackout.
%     bl_adapt_tau_s / bl_adapt_max_db   Baseline drift tracking speed and
%                          its hard cap (never raise the cap so far that
%                          real degradation could be absorbed).
% ------------------------------------------------------------------------

if ischar(varargin{1})
    switch lower(varargin{1})
        case 'config'
            if nargin >= 4
                out = makeConfig(varargin{2}, varargin{3}, varargin{4});
            else
                out = makeConfig(varargin{2}, varargin{3}, struct());
            end
            state = [];
            info = [];
        case 'state'
            out = makeState(varargin{2});
            state = [];
            info = [];
        case 'run'
            if nargin >= 6
                override = varargin{6};
            else
                override = struct();
            end
            out = runRecord(varargin{2}, varargin{3}, varargin{4}, ...
                varargin{5}, override);
            state = [];
            info = [];
        otherwise
            error('fable_osi:UnknownCommand', ...
                'Use ''config'', ''state'', ''run'' or the numeric step call.')
    end
else
    [out, state, info] = stepHop(varargin{1}, varargin{2}, ...
        varargin{3}, varargin{4});
end
end

% ---------------------------------------------------------------- config
function cfg = makeConfig(dt, initial_loop_tf, override)
cfg = struct( ...
    'dt', dt, ...
    'fs', 1/dt, ...
    'band_hz', [2 100], ...
    'line_reject_hz', [58 62], ...
    'segment_s', 1.0, ...
    'hop_s', 0.25, ...             % slow spectral hop (one slow FFT each)
    'step_s', 0.125, ...           % step-call cadence (fast path cadence)
    'window_s', 5.0, ...
    'gamma_alpha', 0.01, ...       % false-pass prob for coherence gate
    'gamma_quiet', 0.15, ...       % bins above this coherence are not "quiet"
    'input_power_range_db', 35, ...% bins this far below the peak input are unexcited
    'sidelobe_db', 25, ...         % bins this far below a +-3 Hz neighbor are
    ...                            % window-leakage, not excitation (Hann first
    ...                            % sidelobe is -31 dB and LEAKS COHERENTLY)
    'min_bins', 5, ...
    'freq_medfilt_n', 3, ...
    'margin_filter_n', 3, ...
    'slow_filt_alpha', 0.2, ...    % EMA weight of the slow-margin tracker
    ...                            % (fast-path direction-gate reference)
    'cap', 1/sqrt(2), ...
    'threshold', 0.30, ...         % detection / fast-trip margin level
    'residual_floor', 0.03, ...
    'residual_band_hz', [28 100], ...% hazard band the residual branch guards.
    ...                              % Low-frequency harmonic distortion of a
    ...                              % strong low-band command is narrowband
    ...                              % and tracks excitation level - keep it
    ...                              % out of the instability watch band.
    'cal_skip_s', 10, ...          % ignore this much data before calibrating
    'cal_windows', 80, ...         % accepted calibration windows (slow hops)
    'cal_reject_factor', 4, ...    % reject window if broadband res off by >4x
    'cal_restart_rejects', 12, ... % consecutive rejects => reference was bad
    'cal_timeout_hops', 600, ...
    'cal_min_windows', 24, ...
    'z_on', 4.0, ...               % residual branch engage threshold
    'z_off', 2.0, ...
    'res_on_n', 4, ...             % consecutive slow hops above z_on to engage
    'res_hold_s', 5, ...           % engagement expires unless z_on re-confirms
    'res_min_growth_db', 3, ...    % engagement also needs this much growth
    'res_match_hz', 3, ...         % same-bin persistence tolerance
    'sigma0_floor', 0.15, ...      % floor of ln-ratio spread
    'bl_adapt_tau_s', 100, ...     % gated slow baseline adaptation
    'bl_adapt_max_db', 3, ...
    'regime_hops', 8, ...          % sustained excited-set change => rebaseline
    'regime_quiet_mm', 0.05, ...   % newest-segment dd RMS below this freezes
    ...                            % the regime detector: silence carries no
    ...                            % input-support information, so a paused/
    ...                            % ended test phase must not throw away a
    ...                            % valid calibration (0 disables the freeze)
    'warm_updates', 4, ...         % slow updates before margin is reported
    ...                            % ---- fast path ----
    'fast_segment_s', 0.25, ...    % fast segment length (0.25 s -> 4 Hz bins)
    'fast_ring_n', 3, ...          % fast segments aggregated (~0.5 s memory)
    'fast_min_bins', 3, ...
    ...                            % fast trips use CUSUM quickest-change
    ...                            % detectors: sustained moderate z shifts
    ...                            % accumulate and cross within a few steps,
    ...                            % isolated healthy spikes decay
    'fast_st_nu', 1.25, ...        % FRF-change CUSUM drift
    'fast_st_h', 4.5, ...          % FRF-change CUSUM trip level
    'fast_burst_nu', 1.0, ...      % burst CUSUM drift
    'fast_burst_h', 6.0, ...       % burst CUSUM trip level (a 1-2 segment
    ...                            % ring-down after a command step gains ~4;
    ...                            % sustained growth crosses in 3-6 steps)
    'fast_babs_offset', 0.10, ...  % FRF trip also needs b_fast < threshold+this
    'fast_amove_frac', 0.02, ...   % authority moves above this (relative)
    ...                            % disarm the FRF-change statistic for one
    ...                            % analysis window (see state.a_cmd)
    'fast_pin_lo', 0.25, ...       % newest-segment input power must stay
    'fast_pin_hi', 4.0, ...        % within [lo,hi] x its ~3 s EMA: a fading
    ...                            % or bursting COMMAND mimics change evidence
    'fast_pin_alpha', 0.04, ...    % EMA update per 0.125 s step
    'fast_burst_bands', [28 44; 44 60; 62 78; 78 94; 94 100], ...
    'fast_sig_floor', 0.20, ...    % floor of ln burst-power spread
    'fast_d_sig_floor', 0.30, ...  % floor of ln FRF-change spread
    'alpha_grid', logspace(log10(0.05), log10(20), 25).', ...
    'pred_denom_floor', 1e-3);

names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('fable_osi:UnknownConfigField', ...
            'Unknown fable_osi config field: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end

% ---- slow grid ----
cfg.segment_n = round(cfg.segment_s*cfg.fs);
cfg.hop_n = round(cfg.hop_s*cfg.fs);
cfg.step_n = round(cfg.step_s*cfg.fs);
cfg.steps_per_hop = round(cfg.hop_n/cfg.step_n);
assert(abs(cfg.steps_per_hop*cfg.step_n - cfg.hop_n) < 1, ...
    'hop_s must be an integer multiple of step_s')
cfg.nfft = cfg.segment_n;
cfg.n_segment = round((cfg.window_s - cfg.segment_s)/cfg.hop_s) + 1;
assert(cfg.n_segment >= 4, 'window_s too short for segment_s/hop_s')

df = cfg.fs/cfg.nfft;
f_all = (0:cfg.nfft/2)'*df;
sel = f_all >= cfg.band_hz(1) & f_all <= cfg.band_hz(2);
cfg.freq_hz = f_all(sel);
cfg.bin = find(sel);                     % FFT bin indices (1-based)
cfg.nf = numel(cfg.freq_hz);
cfg.keep = ~(cfg.freq_hz >= cfg.line_reject_hz(1) ...
    & cfg.freq_hz <= cfg.line_reject_hz(2));
cfg.res_keep = cfg.keep & cfg.freq_hz >= cfg.residual_band_hz(1) ...
    & cfg.freq_hz <= cfg.residual_band_hz(2);

n = (0:cfg.segment_n-1).';
cfg.window = 0.5 - 0.5*cos(2*pi*n/(cfg.segment_n - 1));   % Hann

% Effective number of independent averages for overlapped Hann segments
% (Welch): k_eff = K / (1 + 2*sum_{m}(1-m/K) rho_m^2),
% rho_m = window overlap correlation at lag m*hop.
K = cfg.n_segment;
w = cfg.window;
denom = sum(w.^2);
rho2 = zeros(K-1, 1);
for m = 1:K-1
    lag = m*cfg.hop_n;
    if lag < cfg.segment_n
        rho = sum(w(1:end-lag).*w(1+lag:end))/denom;
    else
        rho = 0;
    end
    rho2(m) = rho^2;
end
cfg.k_eff = K/(1 + 2*sum((1 - (1:K-1)'/K).*rho2));
% Null-calibrated coherence gate: under H0 (no true relation), the sample
% coherence with k independent averages satisfies P(g2 > z) = (1-z)^(k-1).
cfg.gamma_gate = 1 - cfg.gamma_alpha^(1/(max(cfg.k_eff, 2) - 1));

% ---- fast grid ----
cfg.fast_segment_n = round(cfg.fast_segment_s*cfg.fs);
cfg.fast_nfft = cfg.fast_segment_n;
dff = cfg.fs/cfg.fast_nfft;
ff_all = (0:cfg.fast_nfft/2)'*dff;
self = ff_all >= cfg.band_hz(1) & ff_all <= cfg.band_hz(2);
cfg.fast_freq_hz = ff_all(self);
cfg.fast_bin = find(self);
cfg.nf_fast = numel(cfg.fast_freq_hz);
cfg.fast_keep = ~(cfg.fast_freq_hz >= cfg.line_reject_hz(1) ...
    & cfg.fast_freq_hz <= cfg.line_reject_hz(2));
nfseg = (0:cfg.fast_segment_n-1).';
cfg.fast_window = 0.5 - 0.5*cos(2*pi*nfseg/(cfg.fast_segment_n - 1));
% projection cells: fast bin i covers slow bins within [f_i-dff/2, f_i+dff/2)
cfg.fast_cell_lo = zeros(cfg.nf_fast, 1);
cfg.fast_cell_hi = zeros(cfg.nf_fast, 1);
for i = 1:cfg.nf_fast
    lo = find(cfg.freq_hz >= cfg.fast_freq_hz(i) - dff/2, 1, 'first');
    hi = find(cfg.freq_hz < cfg.fast_freq_hz(i) + dff/2, 1, 'last');
    if isempty(lo), lo = 1; end
    if isempty(hi), hi = cfg.nf; end
    cfg.fast_cell_lo(i) = lo;
    cfg.fast_cell_hi(i) = hi;
end

% Prior loop model: chordal margin curve used ONLY for warm-up context and
% as the residual branch anchor b0(w). Never used to gate authority-up.
L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.nominal_curve = abs(1 + L0(:))./sqrt(2*(1 + abs(L0(:)).^2));
[cfg.nominal, cfg.nominal_index] = min(cfg.nominal_curve);
cfg.nominal_hz = cfg.freq_hz(cfg.nominal_index);

% fast burst sub-band ids on the fast grid (0 = not in any band)
cfg.n_burst_bands = size(cfg.fast_burst_bands, 1);
cfg.fast_band_id = zeros(cfg.nf_fast, 1);
for j = 1:cfg.n_burst_bands
    inb = cfg.fast_freq_hz >= cfg.fast_burst_bands(j, 1) ...
        & cfg.fast_freq_hz <= cfg.fast_burst_bands(j, 2) & cfg.fast_keep;
    cfg.fast_band_id(inb) = j;
end

cfg.res_hold_hops = max(1, round(cfg.res_hold_s/cfg.hop_s));
cfg.bl_alpha = cfg.hop_s/cfg.bl_adapt_tau_s;
cfg.n_alpha = numel(cfg.alpha_grid);
% steps of steady authority required before the FRF-change statistic is
% armed (one full slow analysis window: everything the slow reference and
% the ring remember must have been produced at the current authority)
cfg.amove_hold = round(cfg.window_s/cfg.step_s);
end

% ----------------------------------------------------------------- state
function state = makeState(cfg)
state = struct( ...
    'xdd', zeros(cfg.segment_n, 1), ...
    'xdm', zeros(cfg.segment_n, 1), ...
    'samples_in', 0, ...
    'step_count', 0, ...
    'hop_count', 0, ...
    'Suu_seg', zeros(cfg.nf, cfg.n_segment), ...
    'Syy_seg', zeros(cfg.nf, cfg.n_segment), ...
    'Suy_seg', complex(zeros(cfg.nf, cfg.n_segment)), ...
    'seg_count', 0, ...
    'ring_pos', 0, ...
    'update_count', 0, ...
    'cal_res', zeros(cfg.nf, cfg.cal_windows), ...
    'cal_med', zeros(cfg.cal_windows, 1), ...
    'cal_pf', zeros(cfg.n_burst_bands, cfg.cal_windows), ...
    'cal_d', zeros(4*cfg.cal_windows, 1), ...
    'cal_d_count', 0, ...
    'cal_count', 0, ...
    'cal_tries', 0, ...
    'cal_rejects', 0, ...
    'ready', false, ...
    'baseline', ones(cfg.nf, 1), ...
    'baseline0', ones(cfg.nf, 1), ...
    'mu0', zeros(cfg.nf, 1), ...
    'sigma0', cfg.sigma0_floor, ...
    'mu_pf', zeros(cfg.n_burst_bands, 1), ...
    'mu_pf0', zeros(cfg.n_burst_bands, 1), ...
    'sig_pf', 1e6*ones(cfg.n_burst_bands, 1), ...
    'mu_d', 0, ...
    'mu_d0', 0, ...
    'sig_d', 1e6, ...
    'res_on', false, ...
    'res_count', 0, ...
    'res_age', 0, ...
    'res_freq', NaN, ...
    'regime_mask', false(cfg.nf, 1), ...
    'regime_count', 0, ...
    'sb_ndiff', 0, ...
    'recal_pending', false, ...
    'slow_hist', NaN(cfg.margin_filter_n, 1), ...
    'detected', false, ...
    'detect_step', NaN, ...
    ... % cached slow results (refreshed every slow hop)
    'sb_b', NaN, ...
    'sb_st', NaN, 'sb_res', NaN, 'sb_fst', NaN, 'sb_fres', NaN, ...
    'sb_zmax', NaN, 'sb_stvalid', false, 'sb_nexc', 0, ...
    'sb_predvalid', false, 'sb_pred', [], ...
    'sb_excited', [], 'sb_quiet', [], 'sb_qpmask', [], ...
    'sb_Tsf', [], 'sb_Tsf_valid', [], ...
    'b_slow_filt', NaN, ...
    ... % fast path
    'fSuu', zeros(cfg.nf_fast, cfg.fast_ring_n), ...
    'fSyy', zeros(cfg.nf_fast, cfg.fast_ring_n), ...
    'fSuy', complex(zeros(cfg.nf_fast, cfg.fast_ring_n)), ...
    'fseg_count', 0, ...
    'fring_pos', 0, ...
    'p_in_ema', NaN, ...
    'cus_st', 0, ...
    'cus_burst', zeros(cfg.n_burst_bands, 1), ...
    ... % externally applied authority (closed loop: caller writes a_cmd
    ... % before each step; NaN = authority does not act on the plant)
    'a_cmd', NaN, ...
    'a_prev_cmd', NaN, ...
    'a_stable_steps', 1e6);
state.sb_pred = NaN(cfg.n_alpha, 1);
state.sb_excited = false(cfg.nf, 1);
state.sb_quiet = false(cfg.nf, 1);
state.sb_qpmask = false(cfg.nf, 1);
state.sb_Tsf = complex(zeros(cfg.nf_fast, 1));
state.sb_Tsf_valid = false(cfg.nf_fast, 1);
end

% ------------------------------------------------------------------ step
function [b, state, info] = stepHop(dd_step, dm_step, cfg, state)
dd_step = dd_step(:);
dm_step = dm_step(:);
assert(numel(dd_step) == cfg.step_n && numel(dm_step) == cfg.step_n, ...
    'fable_osi step expects exactly cfg.step_n samples per call.')

% shift new samples into the raw ring (long enough for a slow segment)
state.xdd = [state.xdd(cfg.step_n+1:end); dd_step];
state.xdm = [state.xdm(cfg.step_n+1:end); dm_step];
state.samples_in = state.samples_in + cfg.step_n;
state.step_count = state.step_count + 1;

% track the stability of the externally applied authority (see the
% fast_amove_frac note in the tuning guide): the FRF-change statistic is
% only armed after a_cmd has been steady for a full analysis window
if ~isnan(state.a_cmd) && ~isnan(state.a_prev_cmd) ...
        && abs(state.a_cmd - state.a_prev_cmd) ...
        > cfg.fast_amove_frac*max(state.a_prev_cmd, 0.01)
    state.a_stable_steps = 0;
else
    state.a_stable_steps = min(state.a_stable_steps + 1, 1e6);
end
state.a_prev_cmd = state.a_cmd;

b = NaN;
if state.samples_in < cfg.fast_segment_n
    info = fillInfo(cfg, state, NaN, false, NaN, false, 0);
    info.z_fast = NaN;
    info.regime_recal = false;
    return
end

% ---- fast segment FFT (every step) --------------------------------------
xu = state.xdd(end-cfg.fast_segment_n+1:end);
xy = state.xdm(end-cfg.fast_segment_n+1:end);
Uf = fft(cfg.fast_window.*detrendLinear(xu));
Yf = fft(cfg.fast_window.*detrendLinear(xy));
Uf = Uf(cfg.fast_bin);
Yf = Yf(cfg.fast_bin);
state.fring_pos = mod(state.fring_pos, cfg.fast_ring_n) + 1;
state.fSuu(:, state.fring_pos) = abs(Uf).^2;
state.fSyy(:, state.fring_pos) = abs(Yf).^2;
state.fSuy(:, state.fring_pos) = Yf.*conj(Uf);
state.fseg_count = min(state.fseg_count + 1, cfg.fast_ring_n);

% ---- slow spectral hop (every steps_per_hop-th step) ---------------------
if mod(state.step_count, cfg.steps_per_hop) == 0 ...
        && state.samples_in >= cfg.segment_n
    state = slowHop(cfg, state);
end

% ---- fast statistics (every step, once the slow path is running) --------
[b_fast, fast_trip, trip_reason, z_fast, state] = fastPath(cfg, state);

% ---- combine -------------------------------------------------------------
% slow component: median over the last margin_filter_n DISTINCT slow
% updates (computed in slowHop); fast dips bypass that median only when a
% persistence-gated trip is active
b = state.sb_b;
if state.update_count <= cfg.warm_updates
    b = NaN;
end
if trip_reason == 2 && ~isnan(b)           % fast ST trip: show the dive
    b = min(b, b_fast);
end

valid = ~isnan(b);
if valid && ~state.detected && b < cfg.threshold
    state.detected = true;
    state.detect_step = state.step_count;
end

info = fillInfo(cfg, state, b, valid, b_fast, fast_trip, trip_reason);
info.z_fast = z_fast;
% one-shot flag: a regime recalibration was just confirmed. The authority
% law uses it to UNDO a fast trip that fired during the transition onset
% (the trip was the regime change, not the plant).
info.regime_recal = state.recal_pending;
state.recal_pending = false;
end

% ---------------------------------------------------------- slow pipeline
function state = slowHop(cfg, state)
state.hop_count = state.hop_count + 1;

U = fft(cfg.window.*detrendLinear(state.xdd));
Y = fft(cfg.window.*detrendLinear(state.xdm));
U = U(cfg.bin);
Y = Y(cfg.bin);
state.ring_pos = mod(state.ring_pos, cfg.n_segment) + 1;
state.Suu_seg(:, state.ring_pos) = abs(U).^2;
state.Syy_seg(:, state.ring_pos) = abs(Y).^2;
state.Suy_seg(:, state.ring_pos) = Y.*conj(U);
state.seg_count = min(state.seg_count + 1, cfg.n_segment);
if state.seg_count < cfg.n_segment
    return
end

% robust aggregation over the ring (median across segments)
Suu = median(state.Suu_seg, 2);
Syy = median(state.Syy_seg, 2);
Suy = complex(median(real(state.Suy_seg), 2), ...
    median(imag(state.Suy_seg), 2));

tiny = max(max(Suu), 1)*1e-14;
M = Suy./max(Suu, tiny);
g2raw = min(abs(Suy).^2./max(Suu.*Syy, tiny^2), 1);
g2 = max(0, (cfg.k_eff*g2raw - 1)/(cfg.k_eff - 1));
res = Syy.*max(1 - g2, cfg.residual_floor);

% a bin is excited only with significant coherence, real input power, AND
% no leakage taint: an isolated false-coherence bin at a quiet frequency
% would read |M| = huge and nuke the margin to zero, and a bin sitting
% >sidelobe_db below a +-3 Hz neighbor is the segment window's own
% (coherent!) leakage of a strong band edge, not excitation.
pow_floor = max(Suu(cfg.keep))*10^(-cfg.input_power_range_db/10);
has_input = Suu > max(pow_floor, tiny);
local_max = movmax(Suu, 7);
not_leak = Suu > local_max*10^(-cfg.sidelobe_db/10);
excited = cfg.keep & g2raw > cfg.gamma_gate & has_input & not_leak;
% the residual branch watches only frequencies the COMMAND DOES NOT DRIVE:
% where the input has power, closed-loop health is the ST branch's job, and
% partially-coherent leakage there is not evidence of instability.
quiet = cfg.res_keep & ~has_input & g2raw < cfg.gamma_quiet;

state.update_count = state.update_count + 1;
state.sb_excited = excited;
state.sb_quiet = quiet;
% burst-power mask: only the STABLE conditions (input support), so the
% band membership does not wobble with per-window coherence and inflate
% the calibrated spread of the burst statistic
state.sb_qpmask = cfg.res_keep & ~has_input;

% ---- excitation-regime change detector -----------------------------------
% The support of the COMMAND's input power changing (test phase
% started/stopped/moved band) is an exogenous, observable event that
% legitimately moves the quiet-bin output floor: instability grows
% quiet-bin power but cannot change which bins the command drives. The
% detector keys on the input-power mask (has_input), which is coherence-
% independent and therefore stable, unlike the excited set. On a sustained
% change, recollect the residual baseline; the ST branch keeps running.
hi_mask = has_input & cfg.keep;
state.sb_ndiff = 0;
% a segment with no real command power carries no input-support
% information (the relative pow_floor turns pure noise into a random
% mask): FREEZE the detector there instead of rebaselining on silence,
% so a paused or ended test phase keeps its calibration/warm-up
seg_quiet = cfg.regime_quiet_mm > 0 ...
    && sqrt(mean(state.xdd.^2)) < cfg.regime_quiet_mm;
if seg_quiet
    % keep regime_mask, regime_count and ready exactly as they are
elseif state.ready
    nref = nnz(state.regime_mask);
    ndiff = nnz(xor(hi_mask, state.regime_mask));
    state.sb_ndiff = ndiff;
    if ndiff > max(6, 0.5*nref)
        state.regime_count = state.regime_count + 1;
    else
        state.regime_count = 0;
    end
    if state.regime_count >= cfg.regime_hops
        state.ready = false;
        state.cal_count = 0;
        state.cal_tries = 0;
        state.cal_rejects = 0;
        state.cal_d_count = 0;
        state.res_on = false;
        state.res_count = 0;
        state.regime_count = 0;
        state.regime_mask = hi_mask;
        state.cus_st = 0;
        state.cus_burst(:) = 0;
        state.p_in_ema = NaN;
        state.recal_pending = true;
    end
else
    state.regime_mask = hi_mask;
end

% ---- residual calibration (initial and after a regime change) -----------
t_now = state.hop_count*cfg.hop_s;
if ~state.ready && t_now >= cfg.cal_skip_s
    state.cal_tries = state.cal_tries + 1;
    med_new = median(res(cfg.keep));
    accept = state.cal_count == 0;
    if ~accept
        med_ref = median(state.cal_med(1:state.cal_count));
        accept = med_new < cfg.cal_reject_factor*med_ref ...
            && med_new > med_ref/cfg.cal_reject_factor;
    end
    if accept
        state.cal_count = state.cal_count + 1;
        state.cal_res(:, state.cal_count) = res;
        state.cal_med(state.cal_count) = med_new;
        % fast-path burst calibration sample: newest fast segment's
        % undriven sub-band powers (what the burst detector watches)
        state.cal_pf(:, state.cal_count) = ...
            fastQuietPower(cfg, state, state.sb_qpmask);
        state.cal_rejects = 0;
    else
        % a startup transient (e.g. actuator homing) can poison the
        % first reference; if everything since then is rejected, the
        % reference was the outlier - start over
        state.cal_rejects = state.cal_rejects + 1;
        if state.cal_rejects >= cfg.cal_restart_rejects
            state.cal_count = 0;
            state.cal_rejects = 0;
        end
    end
    done = state.cal_count >= cfg.cal_windows ...
        || (state.cal_tries >= cfg.cal_timeout_hops ...
        && state.cal_count >= cfg.cal_min_windows);
    if done
        state = finalizeCalibration(cfg, state, quiet);
    end
end

% ---- ST branch ----------------------------------------------------------
st = sqrt(abs(1 - M).^2 + abs(M).^2);
chord = 1./(sqrt(2)*max(st, eps));
chord_s = maskedMovMedian(chord, excited, cfg.freq_medfilt_n);
if nnz(excited) >= cfg.min_bins
    scan = chord_s;
    scan(~excited) = NaN;
    [b_st, i_st] = min(scan);          % min skips NaN
    f_st = cfg.freq_hz(i_st);
    st_valid = true;
else
    b_st = NaN;
    f_st = NaN;
    st_valid = false;
end

% ---- residual branch (only with a baseline for the current regime) ------
if state.ready
    [b_res, f_res, z_max, state] = residualBranch(cfg, state, res, quiet);
else
    b_res = NaN;
    f_res = NaN;
    z_max = NaN;
end

% ---- authority-planning curve: margin vs relative loop-gain multiplier ---
pred_margin = NaN(cfg.n_alpha, 1);
pred_valid = false;
if st_valid
    d = 1 - M;
    bad = abs(d) < cfg.pred_denom_floor;
    d(bad) = cfg.pred_denom_floor*exp(1i*angle(d(bad)));
    Lb = M(excited)./d(excited);
    for k = 1:cfg.n_alpha
        La = cfg.alpha_grid(k)*Lb;
        ck = abs(1 + La)./sqrt(2*(1 + abs(La).^2));
        pred_margin(k) = min(cfg.cap, min(ck));
    end
    pred_valid = true;
end

% cache for the fast path / info
state.sb_st = b_st;
state.sb_res = b_res;
state.sb_fst = f_st;
state.sb_fres = f_res;
state.sb_zmax = z_max;
state.sb_stvalid = st_valid;
state.sb_nexc = nnz(excited);
state.sb_pred = pred_margin;
state.sb_predvalid = pred_valid;

% slow FRF projected onto the fast grid (reference for the fast
% FRF-change statistic): per fast cell, mean of M over its excited bins
for i = 1:cfg.nf_fast
    binsel = false(cfg.nf, 1);
    binsel(cfg.fast_cell_lo(i):cfg.fast_cell_hi(i)) = true;
    binsel = binsel & excited;
    if any(binsel)
        state.sb_Tsf(i) = mean(M(binsel));
        state.sb_Tsf_valid(i) = true;
    else
        state.sb_Tsf(i) = 0;
        state.sb_Tsf_valid(i) = false;
    end
end

% temporal median over DISTINCT slow updates (kills one-window artifacts)
b_slow = min(b_st, b_res);
if isnan(b_st) && isnan(b_res)
    b_slow = NaN;
else
    b_slow = min(b_slow, cfg.cap);
end
state.slow_hist = [state.slow_hist(2:end); b_slow];
hist = state.slow_hist(~isnan(state.slow_hist));
if isempty(hist)
    state.sb_b = NaN;
else
    state.sb_b = median(hist);
end

if ~isnan(b_slow)
    if isnan(state.b_slow_filt)
        state.b_slow_filt = b_slow;
    else
        state.b_slow_filt = (1 - cfg.slow_filt_alpha)*state.b_slow_filt ...
            + cfg.slow_filt_alpha*b_slow;
    end
end
end

% -------------------------------------------------------------- fast path
function [b_fast, fast_trip, trip_reason, z_pf, state] = fastPath(cfg, state)
b_fast = NaN;
fast_trip = false;
trip_reason = 0;
z_pf = NaN;
if state.update_count <= cfg.warm_updates ...
        || state.fseg_count < cfg.fast_ring_n
    state.cus_st = 0;
    state.cus_burst(:) = 0;
    return
end

% masks projected from the slow path onto the fast grid
exc_f = false(cfg.nf_fast, 1);
for i = 1:cfg.nf_fast
    exc_f(i) = any(state.sb_excited(cfg.fast_cell_lo(i):cfg.fast_cell_hi(i)));
end
exc_f = exc_f & cfg.fast_keep;

% ---- fast ST margin + pooled FRF-change statistic ------------------------
% The chordal margin from ~0.5 s of data is too noisy to separate a real
% deficit from its own floor - but the FRF DISPLACEMENT pooled across all
% observed bins concentrates: d = median_bins |T_new - T_slow|^2/|T_slow|^2
% jumps by an order of magnitude on a plant change. It is computed on the
% NEWEST segment alone (one segment of latency, the pooling supplies the
% averaging), z-scored against its own calibrated healthy spread, and
% guarded by direction (fast margin below the slow one), so a
% margin-improving change does not trip.
d_raw = NaN;
if state.sb_stvalid
    % ring-median fast margin (for reporting, direction and trip sizing)
    Suu = median(state.fSuu, 2);
    Suy = complex(median(real(state.fSuy), 2), ...
        median(imag(state.fSuy), 2));
    tiny = max(max(Suu), 1)*1e-14;
    pow_floor = max(Suu(cfg.fast_keep)) ...
        *10^(-cfg.input_power_range_db/10);
    local_max = movmax(Suu, 3);
    mask = exc_f & Suu > max(pow_floor, tiny) ...
        & Suu > local_max*10^(-cfg.sidelobe_db/10);
    if nnz(mask) >= cfg.fast_min_bins
        Mf = Suy./max(Suu, tiny);
        chord = 1./(sqrt(2)*max(sqrt(abs(1 - Mf).^2 + abs(Mf).^2), eps));
        chord = maskedMovMedian(chord, mask, cfg.freq_medfilt_n);
        chord(~mask) = NaN;
        b_fast = min(cfg.cap, min(chord));
    end
    % newest-segment FRF deviation - but only while the COMMAND itself is
    % steady: a fading or bursting input (test phase ending, EQ lull)
    % makes the single-segment FRF garbage, which is not evidence of a
    % plant change. The reference is a ~3 s EMA of the newest-segment
    % in-band input power.
    Suu1 = state.fSuu(:, state.fring_pos);
    p_in_new = sum(Suu1(cfg.fast_keep));
    pin_ok = isfinite(state.p_in_ema) && state.p_in_ema > 0 ...
        && p_in_new >= cfg.fast_pin_lo*state.p_in_ema ...
        && p_in_new <= cfg.fast_pin_hi*state.p_in_ema;
    if p_in_new > 0
        if ~isfinite(state.p_in_ema)
            state.p_in_ema = p_in_new;
        else
            state.p_in_ema = (1 - cfg.fast_pin_alpha)*state.p_in_ema ...
                + cfg.fast_pin_alpha*p_in_new;
        end
    end
    if pin_ok && state.a_stable_steps >= cfg.amove_hold
        Suy1 = state.fSuy(:, state.fring_pos);
        tiny1 = max(max(Suu1), 1)*1e-14;
        pf1 = max(Suu1(cfg.fast_keep))*10^(-cfg.input_power_range_db/10);
        lm1 = movmax(Suu1, 3);
        m1 = exc_f & Suu1 > max(pf1, tiny1) ...
            & Suu1 > lm1*10^(-cfg.sidelobe_db/10) & state.sb_Tsf_valid;
        if nnz(m1) >= cfg.fast_min_bins
            M1 = Suy1./max(Suu1, tiny1);
            dev = abs(M1(m1) - state.sb_Tsf(m1)).^2 ...
                ./max(abs(state.sb_Tsf(m1)).^2, 1e-12);
            d_raw = median(dev);
        end
    end
end

% collect the healthy spread of the statistic during calibration
if ~state.ready
    if isfinite(d_raw) && d_raw > 0 ...
            && state.cal_d_count < numel(state.cal_d)
        state.cal_d_count = state.cal_d_count + 1;
        state.cal_d(state.cal_d_count) = log(d_raw);
    end
    state.cus_st = 0;
    state.cus_burst(:) = 0;
    return
end

% suspected or NASCENT excitation-regime transition (the input-support
% mask is moving): the spectra are mixing two regimes, which mimics
% change evidence - stand down until it resolves
if state.regime_count > 0 || state.sb_ndiff >= 4
    state.cus_st = 0.9*state.cus_st;
    state.cus_burst = 0.9*state.cus_burst;
    return
end

% CUSUM on the FRF-change z: sustained moderate shifts accumulate and
% cross within a few 0.125 s steps; isolated healthy spikes decay
z_d = NaN;
if isfinite(d_raw) && d_raw > 0
    z_d = (log(d_raw) - state.mu_d)/state.sig_d;
end
if isfinite(z_d)
    state.cus_st = max(0, state.cus_st + z_d - cfg.fast_st_nu);
    % gated drift tracking of the healthy FRF-change level
    if abs(z_d) < 1.5
        state.mu_d = min(max((1 - cfg.bl_alpha/2)*state.mu_d ...
            + (cfg.bl_alpha/2)*log(max(d_raw, eps)), ...
            state.mu_d0 - 0.7), state.mu_d0 + 0.7);
    end
else
    state.cus_st = 0.9*state.cus_st;
end
% trip needs the accumulated change evidence AND a margin-degrading
% direction AND an absolutely-concerning fast margin (a change BACK to
% healthy after an event, or a benign FRF shift at safe margins, is not
% grounds to shed)
st_trip = state.cus_st > cfg.fast_st_h ...
    && isfinite(b_fast) && isfinite(state.b_slow_filt) ...
    && b_fast < state.b_slow_filt ...
    && b_fast < cfg.threshold + cfg.fast_babs_offset;
if st_trip
    state.cus_st = 0;   % edge semantics: re-accumulate for a new trip
end

% ---- fast quiet-band burst (calibrated sub-band levels, newest segment) --
burst_trip = false;
if any(state.sb_qpmask)
    p_new = fastQuietPower(cfg, state, state.sb_qpmask);
    zj = NaN(cfg.n_burst_bands, 1);
    live = p_new > 0 & state.sig_pf < 1e5;
    zj(live) = (log(p_new(live)) - state.mu_pf(live))./state.sig_pf(live);
    if any(live)
        z_pf = max(zj(live));
    end
    lim = cfg.bl_adapt_max_db*log(10)/10;
    for j = 1:cfg.n_burst_bands
        if live(j)
            % per-band CUSUM
            state.cus_burst(j) = max(0, ...
                state.cus_burst(j) + zj(j) - cfg.fast_burst_nu);
            % gated ultra-slow drift tracking, bounded +-3 dB
            if abs(zj(j)) < 1.5
                mu_new = (1 - cfg.bl_alpha/2)*state.mu_pf(j) ...
                    + (cfg.bl_alpha/2)*log(p_new(j));
                state.mu_pf(j) = min(max(mu_new, ...
                    state.mu_pf0(j) - lim), state.mu_pf0(j) + lim);
            end
        else
            state.cus_burst(j) = 0.9*state.cus_burst(j);
        end
    end
    if any(state.cus_burst > cfg.fast_burst_h)
        burst_trip = true;
        state.cus_burst(:) = 0;
    end
end

fast_trip = st_trip || burst_trip;
if st_trip
    trip_reason = 2;
elseif burst_trip
    trip_reason = 1;
end
end

function p = fastQuietPower(cfg, state, qpmask)
% undriven-band power of the NEWEST fast segment, per burst sub-band,
% using the (stable) input-support mask from the slow path
q_f = true(cfg.nf_fast, 1);
for i = 1:cfg.nf_fast
    cell = qpmask(cfg.fast_cell_lo(i):cfg.fast_cell_hi(i));
    q_f(i) = ~isempty(cell) && all(cell);
end
q_f = q_f & cfg.fast_keep;
p = zeros(cfg.n_burst_bands, 1);
if state.fseg_count > 0
    for j = 1:cfg.n_burst_bands
        sel = q_f & cfg.fast_band_id == j;
        if nnz(sel) >= 2
            p(j) = sum(state.fSyy(sel, state.fring_pos));
        end
    end
end
end

% ------------------------------------------------------- residual branch
function [b_res, f_res, z_max, state] = residualBranch(cfg, state, res, quiet)
b_res = cfg.cap;
f_res = NaN;
z_max = NaN;
if ~any(quiet)
    state.res_count = 0;
    return
end

ratio = res./state.baseline;
q_med = median(ratio(quiet));
normq = ratio/max(q_med, eps);
z = (log(max(normq, eps)) - state.mu0)/state.sigma0;
z = maskedMovMedian(z, quiet, cfg.freq_medfilt_n);
zq = z;
zq(~quiet) = -Inf;
[z_max, i_res] = max(zq);
f_res = cfg.freq_hz(i_res);

% engage / disengage with same-frequency persistence. Engagement must be
% RE-CONFIRMED: z hovering in the hysteresis zone [z_off, z_on] holds it
% only for res_hold_s, so a one-off transient cannot depress the margin
% for the rest of the test.
if z_max > cfg.z_on ...
        && z_max*state.sigma0 >= cfg.res_min_growth_db*log(10)/10 ...
        && (~isfinite(state.res_freq) ...
        || abs(f_res - state.res_freq) <= cfg.res_match_hz)
    state.res_count = min(state.res_count + 1, cfg.res_on_n);
    state.res_age = 0;
elseif z_max < cfg.z_off
    state.res_count = max(state.res_count - 1, 0);
else
    state.res_age = state.res_age + 1;
    if state.res_age > cfg.res_hold_hops
        state.res_count = max(state.res_count - 1, 0);
    end
end
state.res_freq = f_res;

if ~state.res_on && state.res_count >= cfg.res_on_n
    state.res_on = true;
elseif state.res_on && state.res_count <= 0
    state.res_on = false;
end

if state.res_on
    % engaged: map the FULL residual power growth to margin. Near the
    % critical point output PSD ~ |S|^2 * noise and b ~ 1/|S|, so
    % b ~ b0/sqrt(growth). The z-gate only decides WHEN this is evidence,
    % never discounts the growth itself.
    growth = exp(max(z_max, 0)*state.sigma0);
    anchor = min(cfg.cap, max(cfg.nominal_curve(i_res), 0.10));
    b_res = max(0.05, anchor/sqrt(max(growth, 1)));
else
    % healthy: gated ultra-slow baseline adaptation (bounded to +-max_db)
    if z_max < 1.5
        bl_new = (1 - cfg.bl_alpha)*state.baseline + cfg.bl_alpha*res;
        lim = 10^(cfg.bl_adapt_max_db/10);
        bl_new = min(max(bl_new, state.baseline0/lim), state.baseline0*lim);
        state.baseline(quiet) = bl_new(quiet);
    end
end
end

% -------------------------------------------------- calibration finalize
function state = finalizeCalibration(cfg, state, quiet)
nc = state.cal_count;
cal = state.cal_res(:, 1:nc);
baseline = median(cal, 2);
baseline = max(baseline, median(baseline(cfg.keep))*1e-6);
state.baseline = baseline;
state.baseline0 = baseline;

% per-bin location and pooled spread of the self-normalized ln ratios
logq = zeros(cfg.nf, nc);
for k = 1:nc
    ratio = cal(:, k)./baseline;
    qbins = quiet;
    if ~any(qbins)
        qbins = cfg.res_keep;
    end
    q_med = median(ratio(qbins));
    logq(:, k) = log(max(ratio/max(q_med, eps), eps));
end
state.mu0 = median(logq, 2);
dev = abs(logq - state.mu0);
state.sigma0 = max(cfg.sigma0_floor, ...
    1.4826*median(dev(cfg.res_keep, :), 'all'));

% fast burst statistics from the collected newest-segment sub-band powers
for j = 1:cfg.n_burst_bands
    pf = state.cal_pf(j, 1:nc);
    pf = pf(pf > 0);
    if numel(pf) >= 8
        lpf = log(pf);
        state.mu_pf(j) = median(lpf);
        state.sig_pf(j) = max(cfg.fast_sig_floor, ...
            1.4826*median(abs(lpf - state.mu_pf(j))));
    else
        state.mu_pf(j) = 0;
        state.sig_pf(j) = 1e6;   % band unusable: disarmed
    end
end
state.mu_pf0 = state.mu_pf;
state.cus_burst(:) = 0;

% fast FRF-change statistics from the collected healthy samples
nd = state.cal_d_count;
if nd >= 16
    ld = state.cal_d(1:nd);
    state.mu_d = median(ld);
    state.sig_d = max(cfg.fast_d_sig_floor, ...
        1.4826*median(abs(ld - state.mu_d)));
else
    state.mu_d = 0;
    state.sig_d = 1e6;    % no usable calibration: fast-ST path disarmed
end
state.mu_d0 = state.mu_d;
state.cal_d_count = 0;
state.cus_st = 0;
state.ready = true;
end

% ------------------------------------------------------------- utilities
function y = detrendLinear(x)
n = numel(x);
t = (1:n)'/n;
X = [ones(n,1) t];
y = x - X*(X\x);
end

function y = maskedMovMedian(x, mask, n)
xm = x;
xm(~mask) = NaN;
y = movmedian(xm, n, 'omitnan');
y(~mask) = x(~mask);
bad = isnan(y) & mask;
y(bad) = x(bad);
end

function info = fillInfo(cfg, state, b, valid, b_fast, fast_trip, ...
    trip_reason)
info = struct('margin', b, 'valid', valid, ...
    'ncf_st', state.sb_st, 'st_valid', state.sb_stvalid, ...
    'f_st_hz', state.sb_fst, 'n_excited', state.sb_nexc, ...
    'ncf_res', state.sb_res, 'f_res_hz', state.sb_fres, ...
    'z_max', state.sb_zmax, 'res_on', state.res_on, ...
    'b_fast', b_fast, 'fast_trip', fast_trip, ...
    'trip_reason', trip_reason, ...
    'baseline_ready', state.ready, ...
    'pred_margin', state.sb_pred, 'pred_valid', state.sb_predvalid, ...
    'alpha_grid', cfg.alpha_grid, ...
    'nominal', cfg.nominal, 'nominal_hz', cfg.nominal_hz, ...
    'detected', state.detected, 'detect_step', state.detect_step);
% is the binding constraint inside the coherently observed band? (then the
% authority-planning curve covers it; otherwise the deficit is residual-
% driven and the prediction is blind to it)
info.st_binding = state.sb_stvalid ...
    && (isnan(state.sb_res) || state.sb_st <= state.sb_res);
end

% -------------------------------------------------------------- batch run
function result = runRecord(dd, dm, dt, initial_loop_tf, override)
cfg = makeConfig(dt, initial_loop_tf, override);
state = makeState(cfg);
dd = dd(:);
dm = dm(:);
n_step = floor(min(numel(dd), numel(dm))/cfg.step_n);

tc = NaN(n_step, 1);
b = NaN(n_step, 1);
valid = false(n_step, 1);
b_st = NaN(n_step, 1);
b_res = NaN(n_step, 1);
b_fast = NaN(n_step, 1);
f_st = NaN(n_step, 1);
f_res = NaN(n_step, 1);
z_max = NaN(n_step, 1);
n_excited = zeros(n_step, 1);
st_valid = false(n_step, 1);
res_on = false(n_step, 1);
fast_trip = false(n_step, 1);
trip_reason = zeros(n_step, 1);
regime_recal = false(n_step, 1);
pred_valid = false(n_step, 1);
pred_margin = NaN(cfg.n_alpha, n_step);

for k = 1:n_step
    idx = (k-1)*cfg.step_n + (1:cfg.step_n);
    [bk, state, ik] = stepHop(dd(idx), dm(idx), cfg, state);
    tc(k) = idx(end)*dt;
    b(k) = bk;
    valid(k) = ik.valid;
    b_st(k) = ik.ncf_st;
    b_res(k) = ik.ncf_res;
    b_fast(k) = ik.b_fast;
    f_st(k) = ik.f_st_hz;
    f_res(k) = ik.f_res_hz;
    z_max(k) = ik.z_max;
    n_excited(k) = ik.n_excited;
    st_valid(k) = ik.st_valid;
    res_on(k) = ik.res_on;
    fast_trip(k) = ik.fast_trip;
    trip_reason(k) = ik.trip_reason;
    regime_recal(k) = ik.regime_recal;
    pred_valid(k) = ik.pred_valid;
    pred_margin(:, k) = ik.pred_margin;
end

result = struct('tc', tc, 'b', b, 'valid', valid, ...
    'b_st', b_st, 'b_res', b_res, 'b_fast', b_fast, ...
    'f_st', f_st, 'f_res', f_res, ...
    'z_max', z_max, 'n_excited', n_excited, 'st_valid', st_valid, ...
    'res_on', res_on, 'fast_trip', fast_trip, ...
    'trip_reason', trip_reason, 'regime_recal', regime_recal, ...
    'pred_valid', pred_valid, 'pred_margin', pred_margin, ...
    'alpha_grid', cfg.alpha_grid, 'cfg', cfg, 'state', state);
end
