function [out, state, info] = fable_osi(varargin)
%FABLE_OSI Online NCF-margin stability indicator (Fable redesign).
%
% Commands:
%   cfg    = fable_osi('config', dt, initial_loop_tf, override)
%   state  = fable_osi('state', cfg)
%   result = fable_osi('run', dd, dm, dt, initial_loop_tf, override)
%   [b, state, info] = fable_osi(dd_hop, dm_hop, cfg, state)   % step
%
% The step call consumes exactly cfg.hop_n new samples of dd (loop command)
% and dm (measured displacement) per call and returns the current margin
% estimate. Internally it keeps a rolling short-time spectral ring buffer:
% ONE new segment FFT per hop (instead of recomputing every segment each
% update), so the per-call cost is fixed and small.
%
% Margin definition (same quantity the project already uses):
%   b(w) = |1 + L(w)| / sqrt(2*(1 + |L(w)|^2)) = 1/(sqrt(2)*sqrt(|S|^2+|T|^2))
% the chordal distance of the loop Nyquist locus to the critical point,
% where T is estimated from the dd -> dm map and S = 1 - T. The reported
% margin is min over frequency, capped at its mathematical ceiling 1/sqrt(2).
%
% Design vs the previous M9.1 estimator:
%   * ST branch: bins gated by a NULL-CALIBRATED coherence threshold
%     (probability alpha of a spurious pass given k_eff independent
%     averages), min over gated bins of the frequency-median-smoothed
%     chordal curve. No percentile/power-law shaping of the margin.
%   * Residual branch reports evidence, not a biased level: per-bin residual
%     ratios are SELF-NORMALIZED by the cross-bin quiet median (immune to
%     broadband intensity changes), converted to robust z-scores against the
%     calibration spread, and the branch only pulls the margin below the cap
%     after z > z_on persists at the same frequency. Then it maps growth to
%     margin with b = b0(w*)/sqrt(growth) (valid near the critical point
%     where |L| ~ 1). No evidence => cap, not a random low number.
%   * Calibration rejects outlier windows (startup/homing transients) instead
%     of blindly using the first seconds of the record.
%   * When nothing is measurable (no input power, baseline not ready) the
%     margin is NaN and info.valid=false - never a fake "nominal".
%   * A fast guard watches the newest segment's quiet-band power against the
%     ring median and trips on sudden divergence (latency ~3 hops) without
%     waiting for the full analysis window.
%   * info carries a predicted margin curve versus a relative loop-gain
%     multiplier (alpha_grid), from the identified loop L = T/(1-T), for the
%     authority law to plan with (see fable_auth).
%
% All step-mode state is fixed-size numeric, so the step path can be moved
% to a MATLAB Function block / codegen with the usual flattening.

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
    'hop_s', 0.25, ...
    'window_s', 5.0, ...
    'gamma_alpha', 0.01, ...       % false-pass prob for coherence gate
    'gamma_quiet', 0.15, ...       % bins above this coherence are not "quiet"
    'input_power_range_db', 35, ...% bins this far below the peak input are unexcited
    'min_bins', 5, ...
    'freq_medfilt_n', 3, ...
    'margin_filter_n', 3, ...
    'cap', 1/sqrt(2), ...
    'threshold', 0.30, ...         % detection flag level (info only)
    'residual_floor', 0.03, ...
    'residual_band_hz', [28 100], ...% hazard band the residual branch guards.
    ...                              % Low-frequency harmonic distortion of a
    ...                              % strong low-band command is narrowband
    ...                              % and tracks excitation level - keep it
    ...                              % out of the instability watch band.
    'cal_skip_s', 10, ...          % ignore this much data before calibrating
    'cal_windows', 80, ...         % accepted calibration windows (hops)
    'cal_reject_factor', 4, ...    % reject window if broadband res off by >4x
    'cal_restart_rejects', 12, ... % consecutive rejects => reference was bad
    'cal_timeout_hops', 600, ...
    'cal_min_windows', 24, ...
    'z_on', 3.5, ...               % residual branch engage threshold
    'z_off', 2.0, ...
    'res_on_n', 3, ...             % consecutive hops above z_on to engage
    'res_match_hz', 3, ...         % same-bin persistence tolerance
    'sigma0_floor', 0.15, ...      % floor of ln-ratio spread
    'bl_adapt_tau_s', 100, ...     % gated slow baseline adaptation
    'bl_adapt_max_db', 3, ...
    'fast_factor', 10, ...         % newest-segment power trip factor
    'fast_n', 3, ...
    'regime_hops', 8, ...          % sustained excited-set change => rebaseline
    'warm_updates', 4, ...
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

cfg.segment_n = round(cfg.segment_s*cfg.fs);
cfg.hop_n = round(cfg.hop_s*cfg.fs);
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

% Prior loop model: chordal margin curve used ONLY for warm-up context and
% as the residual branch anchor b0(w). Never used to gate authority-up.
L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.nominal_curve = abs(1 + L0(:))./sqrt(2*(1 + abs(L0(:)).^2));
[cfg.nominal, cfg.nominal_index] = min(cfg.nominal_curve);
cfg.nominal_hz = cfg.freq_hz(cfg.nominal_index);

cfg.bl_alpha = cfg.hop_s/cfg.bl_adapt_tau_s;
cfg.n_alpha = numel(cfg.alpha_grid);
end

% ----------------------------------------------------------------- state
function state = makeState(cfg)
state = struct( ...
    'xdd', zeros(cfg.segment_n, 1), ...
    'xdm', zeros(cfg.segment_n, 1), ...
    'samples_in', 0, ...
    'hop_count', 0, ...
    'Suu_seg', zeros(cfg.nf, cfg.n_segment), ...
    'Syy_seg', zeros(cfg.nf, cfg.n_segment), ...
    'Suy_seg', complex(zeros(cfg.nf, cfg.n_segment)), ...
    'seg_count', 0, ...
    'ring_pos', 0, ...
    'update_count', 0, ...
    'cal_res', zeros(cfg.nf, cfg.cal_windows), ...
    'cal_med', zeros(cfg.cal_windows, 1), ...
    'cal_count', 0, ...
    'cal_tries', 0, ...
    'cal_rejects', 0, ...
    'ready', false, ...
    'baseline', ones(cfg.nf, 1), ...
    'baseline0', ones(cfg.nf, 1), ...
    'mu0', zeros(cfg.nf, 1), ...
    'sigma0', cfg.sigma0_floor, ...
    'res_on', false, ...
    'res_count', 0, ...
    'res_freq', NaN, ...
    'exc_ema', 0, ...
    'regime_count', 0, ...
    'fast_count', 0, ...
    'margin_hist', NaN(cfg.margin_filter_n, 1), ...
    'detected', false, ...
    'detect_hop', NaN);
end

% ------------------------------------------------------------------ step
function [b, state, info] = stepHop(dd_hop, dm_hop, cfg, state)
dd_hop = dd_hop(:);
dm_hop = dm_hop(:);
assert(numel(dd_hop) == cfg.hop_n && numel(dm_hop) == cfg.hop_n, ...
    'fable_osi step expects exactly cfg.hop_n samples per call.')

% shift new samples into the raw ring
state.xdd = [state.xdd(cfg.hop_n+1:end); dd_hop];
state.xdm = [state.xdm(cfg.hop_n+1:end); dm_hop];
state.samples_in = state.samples_in + cfg.hop_n;
state.hop_count = state.hop_count + 1;

b = NaN;
info = emptyInfo(cfg, state);

if state.samples_in < cfg.segment_n
    return
end

% one new segment FFT
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

% a bin is excited only with BOTH significant coherence and real input
% power: an isolated false-coherence bin at a quiet frequency would
% otherwise read |M| = huge and nuke the margin to zero.
pow_floor = max(Suu(cfg.keep))*10^(-cfg.input_power_range_db/10);
has_input = Suu > max(pow_floor, tiny);
excited = cfg.keep & g2raw > cfg.gamma_gate & has_input;
% the residual branch watches only frequencies the COMMAND DOES NOT DRIVE:
% where the input has power, closed-loop health is the ST branch's job, and
% partially-coherent leakage there is not evidence of instability.
quiet = cfg.res_keep & ~has_input & g2raw < cfg.gamma_quiet;

state.update_count = state.update_count + 1;

% ---- excitation-regime change detector -----------------------------------
% The set of command-driven bins changing (test phase started/stopped) is
% an exogenous, observable event that legitimately moves the quiet-bin
% output floor: instability grows quiet-bin power but cannot change which
% bins the command drives. On a sustained change, recollect the residual
% baseline; the ST branch keeps running throughout.
ne = nnz(excited);
if state.ready
    if abs(ne - state.exc_ema) > max(4, 0.6*state.exc_ema)
        state.regime_count = state.regime_count + 1;
    else
        state.regime_count = 0;
        state.exc_ema = (1 - 0.05)*state.exc_ema + 0.05*ne;
    end
    if state.regime_count >= cfg.regime_hops
        state.ready = false;
        state.cal_count = 0;
        state.cal_tries = 0;
        state.cal_rejects = 0;
        state.res_on = false;
        state.res_count = 0;
        state.regime_count = 0;
        state.exc_ema = ne;
    end
else
    state.exc_ema = ne;
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

% ---- fast guard ----------------------------------------------------------
guard_bins = quiet;
if any(guard_bins)
    p_new = sum(state.Syy_seg(guard_bins, state.ring_pos));
    p_med = median(sum(state.Syy_seg(guard_bins, :), 1));
    if p_new > cfg.fast_factor*max(p_med, tiny)
        state.fast_count = state.fast_count + 1;
    else
        state.fast_count = 0;
    end
else
    state.fast_count = 0;
end
fast_trip = state.fast_count >= cfg.fast_n;

% ---- combine and filter --------------------------------------------------
b_raw = min(b_st, b_res);           % NaN-propagating min: min(NaN,x)=x
if isnan(b_st) && isnan(b_res)
    b_raw = NaN;
end
b_raw = min(b_raw, cfg.cap);

state.margin_hist = [state.margin_hist(2:end); b_raw];
hist = state.margin_hist(~isnan(state.margin_hist));
if isempty(hist) || state.update_count <= cfg.warm_updates
    b = NaN;
else
    b = median(hist);
end

valid = ~isnan(b);
if valid && ~state.detected && b < cfg.threshold
    state.detected = true;
    state.detect_hop = state.hop_count;
end

% ---- authority-planning curve: margin vs relative loop-gain multiplier ---
pred_bins = excited;
d = 1 - M;
bad = abs(d) < cfg.pred_denom_floor;
d(bad) = cfg.pred_denom_floor*exp(1i*angle(d(bad)));
Lhat = M./d;
pred_margin = NaN(cfg.n_alpha, 1);
pred_valid = false;
if st_valid
    Lb = Lhat(pred_bins);
    for k = 1:cfg.n_alpha
        La = cfg.alpha_grid(k)*Lb;
        ck = abs(1 + La)./sqrt(2*(1 + abs(La).^2));
        pred_margin(k) = min(cfg.cap, min(ck));
    end
    pred_valid = true;
end

info = fillInfo(cfg, state, b, b_st, b_res, f_st, f_res, z_max, ...
    nnz(excited), st_valid, fast_trip, pred_margin, pred_valid, valid);
% is the binding constraint inside the coherently observed band? (then the
% authority-planning curve covers it; otherwise the deficit is residual-
% driven and the prediction is blind to it)
info.st_binding = st_valid && (isnan(b_res) || b_st <= b_res);
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

% engage / disengage with same-frequency persistence
if z_max > cfg.z_on ...
        && (~isfinite(state.res_freq) ...
        || abs(f_res - state.res_freq) <= cfg.res_match_hz)
    state.res_count = min(state.res_count + 1, cfg.res_on_n);
elseif z_max < cfg.z_off
    state.res_count = max(state.res_count - 1, 0);
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

function info = emptyInfo(cfg, state)
info = fillInfo(cfg, state, NaN, NaN, NaN, NaN, NaN, NaN, 0, false, ...
    false, NaN(cfg.n_alpha, 1), false, false);
end

function info = fillInfo(cfg, state, b, b_st, b_res, f_st, f_res, ...
    z_max, n_excited, st_valid, fast_trip, pred_margin, pred_valid, valid)
info = struct('margin', b, 'valid', valid, ...
    'ncf_st', b_st, 'st_valid', st_valid, 'f_st_hz', f_st, ...
    'n_excited', n_excited, ...
    'ncf_res', b_res, 'f_res_hz', f_res, 'z_max', z_max, ...
    'res_on', state.res_on, ...
    'fast_trip', fast_trip, ...
    'baseline_ready', state.ready, ...
    'pred_margin', pred_margin, 'pred_valid', pred_valid, ...
    'alpha_grid', cfg.alpha_grid, ...
    'nominal', cfg.nominal, 'nominal_hz', cfg.nominal_hz, ...
    'detected', state.detected, 'detect_hop', state.detect_hop, ...
    'st_binding', false);
end

% -------------------------------------------------------------- batch run
function result = runRecord(dd, dm, dt, initial_loop_tf, override)
cfg = makeConfig(dt, initial_loop_tf, override);
state = makeState(cfg);
dd = dd(:);
dm = dm(:);
n_hop = floor(min(numel(dd), numel(dm))/cfg.hop_n);

tc = NaN(n_hop, 1);
b = NaN(n_hop, 1);
valid = false(n_hop, 1);
b_st = NaN(n_hop, 1);
b_res = NaN(n_hop, 1);
f_st = NaN(n_hop, 1);
f_res = NaN(n_hop, 1);
z_max = NaN(n_hop, 1);
n_excited = zeros(n_hop, 1);
st_valid = false(n_hop, 1);
res_on = false(n_hop, 1);
fast_trip = false(n_hop, 1);
pred_valid = false(n_hop, 1);
pred_margin = NaN(cfg.n_alpha, n_hop);

for k = 1:n_hop
    idx = (k-1)*cfg.hop_n + (1:cfg.hop_n);
    [bk, state, ik] = stepHop(dd(idx), dm(idx), cfg, state);
    tc(k) = idx(end)*dt;
    b(k) = bk;
    valid(k) = ik.valid;
    b_st(k) = ik.ncf_st;
    b_res(k) = ik.ncf_res;
    f_st(k) = ik.f_st_hz;
    f_res(k) = ik.f_res_hz;
    z_max(k) = ik.z_max;
    n_excited(k) = ik.n_excited;
    st_valid(k) = ik.st_valid;
    res_on(k) = ik.res_on;
    fast_trip(k) = ik.fast_trip;
    pred_valid(k) = ik.pred_valid;
    pred_margin(:, k) = ik.pred_margin;
end

result = struct('tc', tc, 'b', b, 'valid', valid, ...
    'b_st', b_st, 'b_res', b_res, 'f_st', f_st, 'f_res', f_res, ...
    'z_max', z_max, 'n_excited', n_excited, 'st_valid', st_valid, ...
    'res_on', res_on, 'fast_trip', fast_trip, ...
    'pred_valid', pred_valid, 'pred_margin', pred_margin, ...
    'alpha_grid', cfg.alpha_grid, 'cfg', cfg, 'state', state);
end
