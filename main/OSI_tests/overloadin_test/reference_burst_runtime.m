function [auth, b_osi, b_st, b_res, b_fast, trip_reason, valid, decision] = ...
    reference_burst_runtime(dd, dm, en, fbls, fblw, fblbins, fblfw, fblfbins, ...
    fblag, fbla)
%FABLE_OSI_RUNTIME Simulink/Speedgoat runtime for the fable OSI + authority.
% Flattened transliteration of OSI_tests/fable/fable_osi.m (estimator) and
% fable_auth.m (target-tracking authority law), in the same wrapping style
% as osi_gain_runtime.m:
%   - called once per base-rate sample (2048 Hz) with SCALAR dd, dm, en
%   - fixed-size arrays only, no varargin command API
%   - all configuration arrives as parameter/constant arrays prepared at
%     compile time by control_and_HS/OSI/prepare_fable_runtime.m
%   - all estimator state lives in persistents inside this function
%   - the authority-law state is a set of SCALAR persistents
%
% Inputs
%   dd, dm   loop command and measured displacement (mm), one sample each
%   en       enable code: 0 shadow (estimate + log, authority forced to
%            a_init), 1 active (authority published), +2 = pause (rings
%            reset, calibration + authority state kept - same contract as
%            osi_gain_runtime)
%   fbls     scalar OSI config vector      - index map in prepare_fable_runtime
%   fblw     slow segment Hann window      (segment_n x 1)
%   fblbins  [freq_hz, fft_bin, keep, res_keep, nominal_curve]  (nf x 5)
%   fblfw    fast segment Hann window      (fast_segment_n x 1)
%   fblfbins [freq_hz, fft_bin, keep, cell_lo, cell_hi, band_id] (nf_fast x 6)
%   fblag    authority-prediction gain grid (n_alpha x 1)
%   fbla     authority-law parameter vector - index map in prepare_fable_runtime
%
% Outputs (held constant between internal 0.125 s steps)
%   auth        authority factor for the "Apply OSI gain" Product
%   b_osi       selected OSI margin (NaN = no evidence yet / warm-up)
%   b_st        slow coherent-branch margin (NaN when unobservable)
%   b_res       residual-branch margin (cap = not engaged)
%   b_fast      fast short-memory margin (NaN when unavailable)
%   trip_reason 0 none, 1 quiet-band burst trip, 2 fast FRF-collapse trip
%   valid       1 when b_osi is real evidence (post warm-up, non-NaN)
%   decision    authority-law decision: 0 hold, 1 down, 2 severe down,
%               3 up, 4 fast trip
%
% TUNING: every knob is documented in the TUNING GUIDE headers of
% fable_osi.m (per-branch smooth vs aggressive) and fable_auth.m (authority
% smoothness, drop speed, recovery speed, anti-flicker gating). Tune with
% OSI_tests/fable/fable_tune_explorer.m, which replays saved records
% through THIS function, so what you see offline is exactly what the
% target will run.
%
% ==========================================================================
% IF THE SPEEDGOAT OVERRUNS (TET too high) - what to change, in order.
% The heavy work is bursty: one 512-pt FFT x2 signals every 0.125 s step,
% plus one 2048-pt FFT x2 signals and the slow pipeline every 0.25 s hop,
% all landing inside a single base-rate tick. Measure TET in shadow mode
% first (worst-case tick must stay < ~50% of the 488 us budget). Then:
%
%  1. CHEAPEST, NO ACCURACY LOSS - scheduling: move this block into a
%     triggered/rate-transition subsystem at a slower rate fed by a
%     buffer, or split the hop work across two consecutive steps (slow
%     FFT on one step, slow statistics on the next). Nothing about the
%     algorithm changes, the burst just stops sharing a tick with the
%     control path. See fable_simulink.md section 4.
%  2. hs.fable_pred_enable = 0: drops the 25-gain x ~99-bin complex
%     prediction grid recomputed every hop. The authority law falls back
%     to pure power-law regulation - slightly deeper sheds and more
%     cautious recovery, safety unchanged.
%  3. fable_osi_override.step_s = 0.25 (with hop_s = 0.25): halves the
%     fast-path rate. Fast-trip latency doubles (~0.25-0.5 s), slow
%     accuracy unchanged.
%  4. fable_osi_override.hop_s = 0.5 (keep window_s = 5): halves the slow
%     FFT + slow-pipeline rate. Regulation reacts ~2x slower; the fast
%     guards still cover sudden collapses.
%  5. fable_osi_override.band_hz = [2 80] (if your loop's critical band
%     allows it): ~20% fewer bins in every per-bin loop and median.
%  6. fable_osi_override.window_s = 4: 13 instead of 17 ring segments in
%     every median across the ring (~25% cheaper aggregation, slightly
%     noisier margin).
%  7. Reduce numel(alpha_grid) (e.g. 13 log-spaced points) if the
%     prediction stays enabled.
%  8. Fewer fast_burst_bands rows (5 -> 3 covering the same span):
%     cheaper burst statistics, coarser localization.
% Do NOT shrink segment_s below 1 s (kills the 1 Hz resolution the
% margins need) or disable the coherence/input gates (they are the false-
% alarm protection, not overhead). The raw sample rings here are already
% circular (no per-tick 2048-sample copy, unlike the m91 runtime).
% ==========================================================================
%
% Equivalence against the desktop implementation is asserted by
% OSI_tests/fable/test_fable_runtime_equivalence.m. Keep this file and
% fable_osi.m/fable_auth.m in sync - any behavioral edit must land in both.

%#codegen

% ---- persistent state -----------------------------------------------------
persistent c ...                 % unpacked config (constants)
    raw_dd raw_dm raw_pos sample_phase ...
    S ...                        % estimator state (fixed-size struct)
    out_b out_bst out_bres out_bfast out_trip out_valid out_dec ...
    au_a au_cont au_bfilt au_below au_above au_cool au_blind ...
    au_latch au_armed au_age au_pretrip ...
    au_shedtgt au_bshedref au_settle au_movage

if isempty(raw_pos)
    c = unpackConfig(fbls, fblw, fblbins, fblfw, fblfbins, fblag);
    raw_dd = zeros(c.segment_n, 1);
    raw_dm = zeros(c.segment_n, 1);
    raw_pos = 0;
    sample_phase = 0;
    S = initState(c);
    out_b = NaN; out_bst = NaN; out_bres = NaN; out_bfast = NaN;
    out_trip = 0; out_valid = 0; out_dec = 0;
    % authority-law state: scalar persistents (fable_auth 'state' fields)
    au_a = fbla(4);        % committed authority (what the loop sees)
    au_cont = fbla(4);     % internally regulated authority
    au_bfilt = NaN;        % EMA-filtered margin
    au_below = 0;          % consecutive low-margin updates
    au_above = 0;          % consecutive healthy updates
    au_cool = 0;           % trip cooldown counter
    au_blind = 0;          % consecutive NaN-margin updates
    au_latch = fbla(3);    % latched recovery ceiling
    au_armed = 1;          % fast-ST trip armed
    au_age = 1e6;          % steps since last trip
    au_pretrip = fbla(4);  % authority before the last trip (for undo)
    au_shedtgt = NaN;      % active sized shed target (NaN = none)
    au_bshedref = NaN;     % margin reading that sized the active shed
    au_settle = 0;         % steps left before the shed may be re-sized
    au_movage = 1e6;       % steps since the committed authority moved
end

pause_enable = en >= 2;
en_act = en;
if pause_enable
    en_act = en - 2;
end

if pause_enable
    % pause contract (same as osi_gain_runtime): reset the data rings and
    % transient statistics; KEEP the calibrated baseline/mu/sigma, the
    % regime memory and the authority state. If calibration had not
    % finished, restart its collection cleanly on resume.
    raw_dd(:) = 0;
    raw_dm(:) = 0;
    raw_pos = 0;
    sample_phase = 0;
    S.samples_in = 0;
    S.step_count = 0;
    S.hop_count = 0;
    S.Suu_seg(:) = 0;
    S.Syy_seg(:) = 0;
    S.Suy_seg(:) = complex(0);
    S.seg_count = 0;
    S.ring_pos = 0;
    S.fSuu(:) = 0;
    S.fSyy(:) = 0;
    S.fSuy(:) = complex(0);
    S.fseg_count = 0;
    S.fring_pos = 0;
    S.p_in_ema = NaN;
    S.cus_st = 0;
    S.cus_burst(:) = 0;
    S.slow_hist(:) = NaN;
    if ~S.ready
        S.cal_count = 0;
        S.cal_tries = 0;
        S.cal_rejects = 0;
        S.cal_d_count = 0;
    end
    if en_act ~= 0
        auth = au_a;
    else
        auth = fbla(4);
    end
    b_osi = out_b; b_st = out_bst; b_res = out_bres; b_fast = out_bfast;
    trip_reason = out_trip; valid = out_valid; decision = out_dec;
    return
end

% ---- per-sample: write into the circular raw rings ------------------------
raw_pos = raw_pos + 1;
if raw_pos > c.segment_n
    raw_pos = 1;
end
raw_dd(raw_pos) = dd;
raw_dm(raw_pos) = dm;
S.samples_in = min(S.samples_in + 1, 1e9);
sample_phase = sample_phase + 1;

if sample_phase >= c.step_n
    % ================= one fable step (every 0.125 s) ====================
    sample_phase = 0;
    S.step_count = S.step_count + 1;

    % the authority applied during the samples of this step is the law's
    % previous committed output au_a: the FRF-change statistic arms only
    % after it has been steady for a full analysis window (a_cmd contract
    % of fable_osi)
    if ~isnan(S.a_prev_cmd) ...
            && abs(au_a - S.a_prev_cmd) ...
            > c.fast_amove_frac*max(S.a_prev_cmd, 0.01)
        S.a_stable_steps = 0;
    else
        S.a_stable_steps = min(S.a_stable_steps + 1, 1e6);
    end
    S.a_prev_cmd = au_a;

    b = NaN;
    bf_k = NaN;
    trip_k = 0;
    recal_k = false;

    if S.samples_in >= c.fast_segment_n
        % ---- fast segment FFT (every step) ------------------------------
        xu = unwrapTail(raw_dd, raw_pos, c.segment_n, c.fast_segment_n);
        xy = unwrapTail(raw_dm, raw_pos, c.segment_n, c.fast_segment_n);
        Uf = fft(c.fast_window.*detrendLinearRt(xu));
        Yf = fft(c.fast_window.*detrendLinearRt(xy));
        Ufb = Uf(c.fast_bin);
        Yfb = Yf(c.fast_bin);
        S.fring_pos = mod(S.fring_pos, c.fast_ring_n) + 1;
        S.fSuu(:, S.fring_pos) = abs(Ufb).^2;
        S.fSyy(:, S.fring_pos) = abs(Yfb).^2;
        S.fSuy(:, S.fring_pos) = Yfb.*conj(Ufb);
        S.fseg_count = min(S.fseg_count + 1, c.fast_ring_n);

        % ---- slow spectral hop (every steps_per_hop-th step) ------------
        if mod(S.step_count, c.steps_per_hop) == 0 ...
                && S.samples_in >= c.segment_n
            xdd_seg = unwrapTail(raw_dd, raw_pos, c.segment_n, c.segment_n);
            xdm_seg = unwrapTail(raw_dm, raw_pos, c.segment_n, c.segment_n);
            S = slowHopRt(c, S, xdd_seg, xdm_seg);
        end

        % ---- fast statistics (every step) --------------------------------
        [bf_k, trip_k, S] = fastPathRt(c, S);

        % ---- combine ------------------------------------------------------
        b = S.sb_b;
        if S.update_count <= c.warm_updates
            b = NaN;
        end
        if trip_k == 2 && ~isnan(b)      % fast ST trip: show the dive
            b = min(b, bf_k);
        end

        recal_k = S.recal_pending;
        S.recal_pending = false;
    end

    valid_k = ~isnan(b);
    st_binding_k = S.sb_stvalid && (isnan(S.sb_res) || S.sb_st <= S.sb_res);

    % ---- authority law (scalar persistents) ------------------------------
    [au_a, au_cont, au_bfilt, au_below, au_above, au_cool, au_blind, ...
        au_latch, au_armed, au_age, au_pretrip, au_shedtgt, ...
        au_bshedref, au_settle, au_movage, dec_k] = fableAuthStep( ...
        b, S.sb_stvalid, trip_k, bf_k, S.sb_pred, ...
        S.sb_predvalid && c.pred_enable ~= 0, c.alpha_grid, ...
        st_binding_k, recal_k, fbla, ...
        au_a, au_cont, au_bfilt, au_below, au_above, au_cool, au_blind, ...
        au_latch, au_armed, au_age, au_pretrip, au_shedtgt, ...
        au_bshedref, au_settle, au_movage);
    if en_act == 0
        % shadow mode: the law's authority is pinned to a_init so a later
        % enable starts from a known value (same contract as the m91
        % runtime); counters/latches keep evolving for the logs
        au_a = fbla(4);
        au_cont = fbla(4);
    end

    % ---- hold outputs until the next step --------------------------------
    out_b = b;
    out_bst = S.sb_st;
    out_bres = S.sb_res;
    out_bfast = bf_k;
    out_trip = trip_k;
    out_valid = double(valid_k);
    out_dec = dec_k;
end

if en_act ~= 0
    auth = au_a;
else
    auth = fbla(4);
end
b_osi = out_b;
b_st = out_bst;
b_res = out_bres;
b_fast = out_bfast;
trip_reason = out_trip;
valid = out_valid;
decision = out_dec;
end

% ==========================================================================
% config / state
% ==========================================================================
function c = unpackConfig(fbls, fblw, fblbins, fblfw, fblfbins, fblag)
c = struct( ...
    'dt', fbls(1), 'fs', fbls(2), 'step_n', fbls(3), ...
    'steps_per_hop', fbls(4), 'segment_n', fbls(5), 'n_segment', fbls(6), ...
    'k_eff', fbls(7), 'gamma_gate', fbls(8), 'gamma_quiet', fbls(9), ...
    'input_power_range_db', fbls(10), 'sidelobe_db', fbls(11), ...
    'min_bins', fbls(12), 'freq_medfilt_n', fbls(13), ...
    'margin_filter_n', fbls(14), 'slow_filt_alpha', fbls(15), ...
    'cap', fbls(16), 'threshold', fbls(17), 'residual_floor', fbls(18), ...
    'cal_skip_s', fbls(19), 'cal_windows', fbls(20), ...
    'cal_reject_factor', fbls(21), 'cal_restart_rejects', fbls(22), ...
    'cal_timeout_hops', fbls(23), 'cal_min_windows', fbls(24), ...
    'z_on', fbls(25), 'z_off', fbls(26), 'res_on_n', fbls(27), ...
    'res_hold_hops', fbls(28), 'res_min_growth_db', fbls(29), ...
    'res_match_hz', fbls(30), 'sigma0_floor', fbls(31), ...
    'bl_alpha', fbls(32), 'bl_adapt_max_db', fbls(33), ...
    'regime_hops', fbls(34), 'warm_updates', fbls(35), ...
    'fast_segment_n', fbls(36), 'fast_ring_n', fbls(37), ...
    'fast_min_bins', fbls(38), 'fast_st_nu', fbls(39), ...
    'fast_st_h', fbls(40), 'fast_burst_nu', fbls(41), ...
    'fast_burst_h', fbls(42), 'fast_babs_offset', fbls(43), ...
    'fast_pin_lo', fbls(44), 'fast_pin_hi', fbls(45), ...
    'fast_pin_alpha', fbls(46), 'fast_sig_floor', fbls(47), ...
    'fast_d_sig_floor', fbls(48), 'n_burst_bands', fbls(49), ...
    'n_alpha', fbls(50), 'pred_denom_floor', fbls(51), ...
    'hop_s', fbls(52), 'nf', fbls(53), 'nf_fast', fbls(54), ...
    'pred_enable', fbls(55), 'fast_amove_frac', fbls(56), ...
    'amove_hold', fbls(57), ...
    'freq_hz', fblbins(:, 1), 'bin', fblbins(:, 2), ...
    'keep', fblbins(:, 3) ~= 0, 'res_keep', fblbins(:, 4) ~= 0, ...
    'nominal_curve', fblbins(:, 5), 'window', fblw(:), ...
    'fast_freq_hz', fblfbins(:, 1), 'fast_bin', fblfbins(:, 2), ...
    'fast_keep', fblfbins(:, 3) ~= 0, 'fast_cell_lo', fblfbins(:, 4), ...
    'fast_cell_hi', fblfbins(:, 5), 'fast_band_id', fblfbins(:, 6), ...
    'fast_window', fblfw(:), 'alpha_grid', fblag(:));
end

function S = initState(c)
nf = size(c.freq_hz, 1);
nff = size(c.fast_freq_hz, 1);
nseg = round(c.n_segment);
ncal = round(c.cal_windows);
nb = round(c.n_burst_bands);
na = round(c.n_alpha);
nring = round(c.fast_ring_n);
S = struct( ...
    'samples_in', 0, 'step_count', 0, 'hop_count', 0, ...
    'Suu_seg', zeros(nf, nseg), 'Syy_seg', zeros(nf, nseg), ...
    'Suy_seg', complex(zeros(nf, nseg)), ...
    'seg_count', 0, 'ring_pos', 0, 'update_count', 0, ...
    'cal_res', zeros(nf, ncal), 'cal_med', zeros(ncal, 1), ...
    'cal_pf', zeros(nb, ncal), 'cal_d', zeros(4*ncal, 1), ...
    'cal_d_count', 0, 'cal_count', 0, 'cal_tries', 0, 'cal_rejects', 0, ...
    'ready', false, ...
    'baseline', ones(nf, 1), 'baseline0', ones(nf, 1), ...
    'mu0', zeros(nf, 1), 'sigma0', c.sigma0_floor, ...
    'mu_pf', zeros(nb, 1), 'mu_pf0', zeros(nb, 1), ...
    'sig_pf', 1e6*ones(nb, 1), ...
    'mu_d', 0, 'mu_d0', 0, 'sig_d', 1e6, ...
    'res_on', false, 'res_count', 0, 'res_age', 0, 'res_freq', NaN, ...
    'regime_mask', false(nf, 1), 'regime_count', 0, 'sb_ndiff', 0, ...
    'recal_pending', false, ...
    'slow_hist', NaN(round(c.margin_filter_n), 1), ...
    'sb_b', NaN, 'sb_st', NaN, 'sb_res', NaN, 'sb_fst', NaN, ...
    'sb_fres', NaN, 'sb_zmax', NaN, 'sb_stvalid', false, 'sb_nexc', 0, ...
    'sb_predvalid', false, 'sb_pred', NaN(na, 1), ...
    'sb_excited', false(nf, 1), 'sb_quiet', false(nf, 1), ...
    'sb_qpmask', false(nf, 1), ...
    'sb_Tsf', complex(zeros(nff, 1)), 'sb_Tsf_valid', false(nff, 1), ...
    'b_slow_filt', NaN, ...
    'fSuu', zeros(nff, nring), 'fSyy', zeros(nff, nring), ...
    'fSuy', complex(zeros(nff, nring)), ...
    'fseg_count', 0, 'fring_pos', 0, 'p_in_ema', NaN, ...
    'cus_st', 0, 'cus_burst', zeros(nb, 1), ...
    'a_prev_cmd', NaN, 'a_stable_steps', 1e6);
end

% ==========================================================================
% slow pipeline (transliterated from fable_osi.m slowHop)
% ==========================================================================
function S = slowHopRt(c, S, xdd_seg, xdm_seg)
S.hop_count = S.hop_count + 1;

U = fft(c.window.*detrendLinearRt(xdd_seg));
Y = fft(c.window.*detrendLinearRt(xdm_seg));
Ub = U(c.bin);
Yb = Y(c.bin);
S.ring_pos = mod(S.ring_pos, c.n_segment) + 1;
S.Suu_seg(:, S.ring_pos) = abs(Ub).^2;
S.Syy_seg(:, S.ring_pos) = abs(Yb).^2;
S.Suy_seg(:, S.ring_pos) = Yb.*conj(Ub);
S.seg_count = min(S.seg_count + 1, c.n_segment);
if S.seg_count < c.n_segment
    return
end

% robust aggregation over the ring (median across segments)
Suu = median(S.Suu_seg, 2);
Syy = median(S.Syy_seg, 2);
Suy = complex(median(real(S.Suy_seg), 2), median(imag(S.Suy_seg), 2));

tiny = max(max(Suu), 1)*1e-14;
M = Suy./max(Suu, tiny);
g2raw = min(abs(Suy).^2./max(Suu.*Syy, tiny^2), 1);
g2 = max(0, (c.k_eff*g2raw - 1)/(c.k_eff - 1));
res = Syy.*max(1 - g2, c.residual_floor);

% excited/quiet classification (coherence + input power + sidelobe gates)
pow_floor = maxMasked(Suu, c.keep)*10^(-c.input_power_range_db/10);
has_input = Suu > max(pow_floor, tiny);
local_max = movMaxRt(Suu, 7);
not_leak = Suu > local_max*10^(-c.sidelobe_db/10);
excited = c.keep & g2raw > c.gamma_gate & has_input & not_leak;
quiet = c.res_keep & ~has_input & g2raw < c.gamma_quiet;

S.update_count = S.update_count + 1;
S.sb_excited = excited;
S.sb_quiet = quiet;
S.sb_qpmask = c.res_keep & ~has_input;

% ---- excitation-regime change detector -----------------------------------
hi_mask = has_input & c.keep;
S.sb_ndiff = 0;
if S.ready
    nref = sum(double(S.regime_mask));
    ndiff = sum(double(xor(hi_mask, S.regime_mask)));
    S.sb_ndiff = ndiff;
    if ndiff > max(6, 0.5*nref)
        S.regime_count = S.regime_count + 1;
    else
        S.regime_count = 0;
    end
    if S.regime_count >= c.regime_hops
        S.ready = false;
        S.cal_count = 0;
        S.cal_tries = 0;
        S.cal_rejects = 0;
        S.cal_d_count = 0;
        S.res_on = false;
        S.res_count = 0;
        S.regime_count = 0;
        S.regime_mask = hi_mask;
        S.cus_st = 0;
        S.cus_burst(:) = 0;
        S.p_in_ema = NaN;
        S.recal_pending = true;
    end
else
    S.regime_mask = hi_mask;
end

% ---- residual calibration (initial and after a regime change) -----------
t_now = S.hop_count*c.hop_s;
if ~S.ready && t_now >= c.cal_skip_s
    S.cal_tries = S.cal_tries + 1;
    med_new = medianMasked(res, c.keep);
    accept = S.cal_count == 0;
    if ~accept
        med_ref = medianFirstN(S.cal_med, S.cal_count);
        accept = med_new < c.cal_reject_factor*med_ref ...
            && med_new > med_ref/c.cal_reject_factor;
    end
    if accept
        S.cal_count = S.cal_count + 1;
        S.cal_res(:, S.cal_count) = res;
        S.cal_med(S.cal_count) = med_new;
        S.cal_pf(:, S.cal_count) = fastQuietPowerRt(c, S, S.sb_qpmask);
        S.cal_rejects = 0;
    else
        S.cal_rejects = S.cal_rejects + 1;
        if S.cal_rejects >= c.cal_restart_rejects
            S.cal_count = 0;
            S.cal_rejects = 0;
        end
    end
    done = S.cal_count >= c.cal_windows ...
        || (S.cal_tries >= c.cal_timeout_hops ...
        && S.cal_count >= c.cal_min_windows);
    if done
        S = finalizeCalibrationRt(c, S, quiet);
    end
end

% ---- ST branch ------------------------------------------------------------
st = sqrt(abs(1 - M).^2 + abs(M).^2);
chord = 1./(sqrt(2)*max(st, eps));
chord_s = maskedMovMedianRt(chord, excited, c.freq_medfilt_n);
n_exc = sum(double(excited));
if n_exc >= c.min_bins
    scan = chord_s;
    scan(~excited) = NaN;
    [b_st_k, i_st] = min(scan);        % min skips NaN
    f_st = c.freq_hz(i_st);
    st_valid = true;
else
    b_st_k = NaN;
    f_st = NaN;
    st_valid = false;
end

% ---- residual branch (only with a baseline for the current regime) ------
if S.ready
    [b_res_k, f_res, z_max, S] = residualBranchRt(c, S, res, quiet);
else
    b_res_k = NaN;
    f_res = NaN;
    z_max = NaN;
end

% ---- authority-planning curve: margin vs relative loop-gain multiplier ---
pred_margin = NaN(round(c.n_alpha), 1);
pred_valid = false;
if st_valid && c.pred_enable ~= 0
    Lb = complex(zeros(size(M)));
    for i = 1:numel(M)
        di = 1 - M(i);
        if abs(di) < c.pred_denom_floor
            di = c.pred_denom_floor*exp(1i*angle(di));
        end
        Lb(i) = M(i)/di;
    end
    for k = 1:round(c.n_alpha)
        bmin = Inf;
        for i = 1:numel(M)
            if excited(i)
                La = c.alpha_grid(k)*Lb(i);
                ck = abs(1 + La)/sqrt(2*(1 + abs(La)^2));
                if ck < bmin
                    bmin = ck;
                end
            end
        end
        pred_margin(k) = min(c.cap, bmin);
    end
    pred_valid = true;
end

% cache for the fast path / outputs
S.sb_st = b_st_k;
S.sb_res = b_res_k;
S.sb_fst = f_st;
S.sb_fres = f_res;
S.sb_zmax = z_max;
S.sb_stvalid = st_valid;
S.sb_nexc = n_exc;
S.sb_pred = pred_margin;
S.sb_predvalid = pred_valid;

% slow FRF projected onto the fast grid (fast FRF-change reference)
for i = 1:size(c.fast_freq_hz, 1)
    acc = complex(0, 0);
    cnt = 0;
    for j = round(c.fast_cell_lo(i)):round(c.fast_cell_hi(i))
        if excited(j)
            acc = acc + M(j);
            cnt = cnt + 1;
        end
    end
    if cnt > 0
        S.sb_Tsf(i) = acc/cnt;
        S.sb_Tsf_valid(i) = true;
    else
        S.sb_Tsf(i) = complex(0, 0);
        S.sb_Tsf_valid(i) = false;
    end
end

% temporal median over DISTINCT slow updates (kills one-window artifacts)
b_slow = min(b_st_k, b_res_k);
if isnan(b_st_k) && isnan(b_res_k)
    b_slow = NaN;
else
    b_slow = min(b_slow, c.cap);
end
nh = numel(S.slow_hist);
S.slow_hist(1:nh-1) = S.slow_hist(2:nh);
S.slow_hist(nh) = b_slow;
S.sb_b = medianMasked(S.slow_hist, ~isnan(S.slow_hist));

if ~isnan(b_slow)
    if isnan(S.b_slow_filt)
        S.b_slow_filt = b_slow;
    else
        S.b_slow_filt = (1 - c.slow_filt_alpha)*S.b_slow_filt ...
            + c.slow_filt_alpha*b_slow;
    end
end
end

% ==========================================================================
% fast path (transliterated from fable_osi.m fastPath)
% ==========================================================================
function [b_fast, trip_reason, S] = fastPathRt(c, S)
b_fast = NaN;
trip_reason = 0;
if S.update_count <= c.warm_updates || S.fseg_count < c.fast_ring_n
    S.cus_st = 0;
    S.cus_burst(:) = 0;
    return
end

nff = size(c.fast_freq_hz, 1);
exc_f = false(nff, 1);
for i = 1:nff
    e = false;
    for j = round(c.fast_cell_lo(i)):round(c.fast_cell_hi(i))
        if S.sb_excited(j)
            e = true;
        end
    end
    exc_f(i) = e && c.fast_keep(i);
end

% ---- fast ST margin + pooled FRF-change statistic ------------------------
d_raw = NaN;
if S.sb_stvalid
    Suu = median(S.fSuu, 2);
    Suy = complex(median(real(S.fSuy), 2), median(imag(S.fSuy), 2));
    tiny = max(max(Suu), 1)*1e-14;
    pow_floor = maxMasked(Suu, c.fast_keep) ...
        *10^(-c.input_power_range_db/10);
    local_max = movMaxRt(Suu, 3);
    mask = exc_f & Suu > max(pow_floor, tiny) ...
        & Suu > local_max*10^(-c.sidelobe_db/10);
    if sum(double(mask)) >= c.fast_min_bins
        Mf = Suy./max(Suu, tiny);
        chord = 1./(sqrt(2)*max(sqrt(abs(1 - Mf).^2 + abs(Mf).^2), eps));
        chord = maskedMovMedianRt(chord, mask, c.freq_medfilt_n);
        chord(~mask) = NaN;
        b_fast = min(c.cap, min(chord));
    end
    % newest-segment FRF deviation, gated by steady command power
    Suu1 = S.fSuu(:, S.fring_pos);
    p_in_new = sum(Suu1.*double(c.fast_keep));
    pin_ok = isfinite(S.p_in_ema) && S.p_in_ema > 0 ...
        && p_in_new >= c.fast_pin_lo*S.p_in_ema ...
        && p_in_new <= c.fast_pin_hi*S.p_in_ema;
    if p_in_new > 0
        if ~isfinite(S.p_in_ema)
            S.p_in_ema = p_in_new;
        else
            S.p_in_ema = (1 - c.fast_pin_alpha)*S.p_in_ema ...
                + c.fast_pin_alpha*p_in_new;
        end
    end
    if pin_ok && S.a_stable_steps >= c.amove_hold
        Suy1 = S.fSuy(:, S.fring_pos);
        tiny1 = max(max(Suu1), 1)*1e-14;
        pf1 = maxMasked(Suu1, c.fast_keep)*10^(-c.input_power_range_db/10);
        lm1 = movMaxRt(Suu1, 3);
        m1 = exc_f & Suu1 > max(pf1, tiny1) ...
            & Suu1 > lm1*10^(-c.sidelobe_db/10) & S.sb_Tsf_valid;
        if sum(double(m1)) >= c.fast_min_bins
            M1 = Suy1./max(Suu1, tiny1);
            dev = abs(M1 - S.sb_Tsf).^2 ...
                ./max(abs(S.sb_Tsf).^2, 1e-12);
            d_raw = medianMasked(dev, m1);
        end
    end
end

% collect the healthy spread of the statistic during calibration
if ~S.ready
    if isfinite(d_raw) && d_raw > 0 && S.cal_d_count < numel(S.cal_d)
        S.cal_d_count = S.cal_d_count + 1;
        S.cal_d(S.cal_d_count) = log(d_raw);
    end
    S.cus_st = 0;
    S.cus_burst(:) = 0;
    return
end

% suspected or nascent excitation-regime transition: stand down
if S.regime_count > 0 || S.sb_ndiff >= 4
    S.cus_st = 0.9*S.cus_st;
    S.cus_burst = 0.9*S.cus_burst;
    return
end

% CUSUM on the FRF-change z
z_d = NaN;
if isfinite(d_raw) && d_raw > 0
    z_d = (log(d_raw) - S.mu_d)/S.sig_d;
end
if isfinite(z_d)
    S.cus_st = max(0, S.cus_st + z_d - c.fast_st_nu);
    if abs(z_d) < 1.5
        S.mu_d = min(max((1 - c.bl_alpha/2)*S.mu_d ...
            + (c.bl_alpha/2)*log(max(d_raw, eps)), ...
            S.mu_d0 - 0.7), S.mu_d0 + 0.7);
    end
else
    S.cus_st = 0.9*S.cus_st;
end
st_trip = S.cus_st > c.fast_st_h ...
    && isfinite(b_fast) && isfinite(S.b_slow_filt) ...
    && b_fast < S.b_slow_filt ...
    && b_fast < c.threshold + c.fast_babs_offset;
if st_trip
    S.cus_st = 0;   % edge semantics: re-accumulate for a new trip
end

% ---- fast quiet-band burst (calibrated sub-band levels, newest segment) --
burst_trip = false;
if sum(double(S.sb_qpmask)) > 0
    p_new = fastQuietPowerRt(c, S, S.sb_qpmask);
    nb = round(c.n_burst_bands);
    lim = c.bl_adapt_max_db*log(10)/10;
    for j = 1:nb
        if p_new(j) > 0 && S.sig_pf(j) < 1e5
            zj = (log(p_new(j)) - S.mu_pf(j))/S.sig_pf(j);
            S.cus_burst(j) = max(0, S.cus_burst(j) + zj - c.fast_burst_nu);
            if abs(zj) < 1.5
                mu_new = (1 - c.bl_alpha/2)*S.mu_pf(j) ...
                    + (c.bl_alpha/2)*log(p_new(j));
                S.mu_pf(j) = min(max(mu_new, ...
                    S.mu_pf0(j) - lim), S.mu_pf0(j) + lim);
            end
        else
            S.cus_burst(j) = 0.9*S.cus_burst(j);
        end
    end
    for j = 1:nb
        if S.cus_burst(j) > c.fast_burst_h
            burst_trip = true;
        end
    end
    if burst_trip
        S.cus_burst(:) = 0;
    end
end

if st_trip
    trip_reason = 2;
elseif burst_trip
    trip_reason = 1;
end
end

function p = fastQuietPowerRt(c, S, qpmask)
% undriven-band power of the NEWEST fast segment, per burst sub-band
nff = size(c.fast_freq_hz, 1);
nb = round(c.n_burst_bands);
p = zeros(nb, 1);
if S.fseg_count <= 0
    return
end
q_f = false(nff, 1);
for i = 1:nff
    ok = true;
    for j = round(c.fast_cell_lo(i)):round(c.fast_cell_hi(i))
        if ~qpmask(j)
            ok = false;
        end
    end
    q_f(i) = ok && c.fast_keep(i);
end
for j = 1:nb
    cnt = 0;
    acc = 0;
    for i = 1:nff
        if q_f(i) && round(c.fast_band_id(i)) == j
            cnt = cnt + 1;
            acc = acc + S.fSyy(i, S.fring_pos);
        end
    end
    if cnt >= 2
        p(j) = acc;
    end
end
end

% ==========================================================================
% residual branch (transliterated from fable_osi.m residualBranch)
% ==========================================================================
function [b_res, f_res, z_max, S] = residualBranchRt(c, S, res, quiet)
b_res = c.cap;
f_res = NaN;
z_max = NaN;
if sum(double(quiet)) == 0
    S.res_count = 0;
    return
end

ratio = res./S.baseline;
q_med = medianMasked(ratio, quiet);
normq = ratio/max(q_med, eps);
z = (log(max(normq, eps)) - S.mu0)/S.sigma0;
z = maskedMovMedianRt(z, quiet, c.freq_medfilt_n);
zq = z;
zq(~quiet) = -Inf;
[z_max, i_res] = max(zq);
f_res = c.freq_hz(i_res);

% engage / disengage with same-frequency persistence + re-confirmation
if z_max > c.z_on ...
        && z_max*S.sigma0 >= c.res_min_growth_db*log(10)/10 ...
        && (~isfinite(S.res_freq) ...
        || abs(f_res - S.res_freq) <= c.res_match_hz)
    S.res_count = min(S.res_count + 1, c.res_on_n);
    S.res_age = 0;
elseif z_max < c.z_off
    S.res_count = max(S.res_count - 1, 0);
else
    S.res_age = S.res_age + 1;
    if S.res_age > c.res_hold_hops
        S.res_count = max(S.res_count - 1, 0);
    end
end
S.res_freq = f_res;

if ~S.res_on && S.res_count >= c.res_on_n
    S.res_on = true;
elseif S.res_on && S.res_count <= 0
    S.res_on = false;
end

if S.res_on
    % engaged: map the FULL residual power growth to margin
    growth = exp(max(z_max, 0)*S.sigma0);
    anchor = min(c.cap, max(c.nominal_curve(i_res), 0.10));
    b_res = max(0.05, anchor/sqrt(max(growth, 1)));
else
    % healthy: gated ultra-slow baseline adaptation (bounded +-max_db)
    if z_max < 1.5
        lim = 10^(c.bl_adapt_max_db/10);
        for i = 1:numel(res)
            if quiet(i)
                bl_new = (1 - c.bl_alpha)*S.baseline(i) + c.bl_alpha*res(i);
                bl_new = min(max(bl_new, S.baseline0(i)/lim), ...
                    S.baseline0(i)*lim);
                S.baseline(i) = bl_new;
            end
        end
    end
end
end

% ==========================================================================
% calibration finalize (transliterated from fable_osi.m)
% ==========================================================================
function S = finalizeCalibrationRt(c, S, quiet)
nc = round(S.cal_count);
nf = size(c.freq_hz, 1);
ncal = round(c.cal_windows);

% baseline = per-bin median over the accepted windows
baseline = zeros(nf, 1);
for i = 1:nf
    baseline(i) = medianFirstN(S.cal_res(i, :).', nc);
end
bl_med = medianMasked(baseline, c.keep);
for i = 1:nf
    baseline(i) = max(baseline(i), bl_med*1e-6);
end
S.baseline = baseline;
S.baseline0 = baseline;

% per-bin location and pooled spread of the self-normalized ln ratios
logq = zeros(nf, ncal);
anyq = sum(double(quiet)) > 0;
for k = 1:nc
    ratio = S.cal_res(:, k)./baseline;
    if anyq
        q_med = medianMasked(ratio, quiet);
    else
        q_med = medianMasked(ratio, c.res_keep);
    end
    logq(:, k) = log(max(ratio/max(q_med, eps), eps));
end
for i = 1:nf
    S.mu0(i) = medianFirstN(logq(i, :).', nc);
end
% pooled MAD over the residual-band bins x windows
devbuf = zeros(nf*ncal, 1);
cnt = 0;
for k = 1:nc
    for i = 1:nf
        if c.res_keep(i)
            cnt = cnt + 1;
            devbuf(cnt) = abs(logq(i, k) - S.mu0(i));
        end
    end
end
S.sigma0 = max(c.sigma0_floor, 1.4826*medianFirstN(devbuf, cnt));

% fast burst statistics from the collected newest-segment sub-band powers
nb = round(c.n_burst_bands);
pfbuf = zeros(ncal, 1);
for j = 1:nb
    np = 0;
    for k = 1:nc
        if S.cal_pf(j, k) > 0
            np = np + 1;
            pfbuf(np) = log(S.cal_pf(j, k));
        end
    end
    if np >= 8
        mu = medianFirstN(pfbuf, np);
        for k = 1:np
            pfbuf(k) = abs(pfbuf(k) - mu);
        end
        S.mu_pf(j) = mu;
        S.sig_pf(j) = max(c.fast_sig_floor, ...
            1.4826*medianFirstN(pfbuf, np));
    else
        S.mu_pf(j) = 0;
        S.sig_pf(j) = 1e6;   % band unusable: disarmed
    end
end
S.mu_pf0 = S.mu_pf;
S.cus_burst(:) = 0;

% fast FRF-change statistics from the collected healthy samples
nd = round(S.cal_d_count);
if nd >= 16
    mu = medianFirstN(S.cal_d, nd);
    dbuf = zeros(numel(S.cal_d), 1);
    for k = 1:nd
        dbuf(k) = abs(S.cal_d(k) - mu);
    end
    S.mu_d = mu;
    S.sig_d = max(c.fast_d_sig_floor, 1.4826*medianFirstN(dbuf, nd));
else
    S.mu_d = 0;
    S.sig_d = 1e6;    % no usable calibration: fast-ST path disarmed
end
S.mu_d0 = S.mu_d;
S.cal_d_count = 0;
S.cus_st = 0;
S.ready = true;
end

% ==========================================================================
% authority law (transliterated from fable_auth.m; all-scalar state)
% ==========================================================================
function [a_out, a_cont, b_filt, below_n, above_n, trip_cool, blind_hops, ...
    a_latch, trip_armed, trip_age, a_pre_trip, a_shed_tgt, b_shed_ref, ...
    shed_settle, move_age, decision] = fableAuthStep( ...
    b, valid_up, trip_reason, b_fast, pred_margin, pred_valid, ...
    alpha_grid, st_binding, regime_recal, pa, ...
    a_out, a_cont, b_filt, below_n, above_n, trip_cool, blind_hops, ...
    a_latch, trip_armed, trip_age, a_pre_trip, a_shed_tgt, b_shed_ref, ...
    shed_settle, move_age)
% pa index map (see prepare_fable_runtime):
%  1 target  2 a_min  3 a_max  4 a_init  5 dt_update  6 filt_alpha
%  7 down_deadband  8 down_confirm_n  9 down_power  10 down_rate
% 11 sev_frac  12 sev_down_rate  13 up_deadband  14 up_hold_s
% 15 up_rate  16 up_rate_blind  17 up_prop  18 min_step  19 use_pred
% 20 pred_guard  21 pred_floor_frac  22 trip_drop  23 trip_power
% 24 trip_cool_s  25 trip_undo_s  26 latch_relax  27 latch_decay_tau_s
% 28 down_settle_s  29 re_shed_delta  30 self_move_gate_s  31 self_move_frac
target = pa(1); a_min = pa(2); a_max = pa(3);
dt_up = pa(5); filt_alpha = pa(6);

decision = 0;
a_entry = a_out;
trip_age = min(trip_age + 1, 1e6);

% --- trip undo: regime recalibration right after a fast trip --------------
if regime_recal && trip_age <= round(pa(25)/dt_up)
    a_cont = max(a_cont, a_pre_trip);
    a_latch = a_max;
    trip_cool = 0;
    trip_armed = 1;
    a_cont = min(max(a_cont, a_min), a_max);
    a_out = a_cont;
    move_age = moveAge(move_age, a_out, a_entry, pa);
    return
end

% --- fast trips: act immediately ------------------------------------------
if trip_reason == 1
    if trip_age > round(pa(24)/dt_up)
        a_pre_trip = a_cont;
    end
    trip_age = 0;
    a_cont = max(a_min, a_cont*pa(22));
    trip_cool = round(pa(24)/dt_up);
    trip_armed = 0;
    above_n = 0;
    below_n = 0;
    decision = 4;
    a_cont = min(max(a_cont, a_min), a_max);
    a_latch = min(a_latch, max(pa(26)*a_cont, 2*a_min));
    a_out = a_cont;
    move_age = moveAge(move_age, a_out, a_entry, pa);
    return
elseif trip_reason == 2 && trip_armed ~= 0 ...
        && move_age >= round(pa(30)/dt_up)
    % honor the FRF-change trip only when the committed authority has
    % been steady: the estimator watches the total loop (incl. a), so the
    % law's own moves would otherwise read as a plant change and self-trip
    a_pre_trip = a_cont;
    trip_age = 0;
    r = pa(22);
    if isfinite(b_fast)
        r = min(pa(22), (max(b_fast, 0.05)/target)^pa(23));
    end
    a_cont = max(a_min, a_cont*r);
    trip_cool = round(pa(24)/dt_up);
    trip_armed = 0;
    above_n = 0;
    decision = 4;
    a_cont = min(max(a_cont, a_min), a_max);
    a_latch = min(a_latch, max(pa(26)*a_cont, 2*a_min));
    a_out = a_cont;
    move_age = moveAge(move_age, a_out, a_entry, pa);
    return
end

if trip_cool > 0
    trip_cool = trip_cool - 1;
    if trip_cool == 0
        trip_armed = 1;
    end
end

% --- no evidence: hold ------------------------------------------------------
if isnan(b)
    blind_hops = blind_hops + 1;
    above_n = 0;
    move_age = moveAge(move_age, a_out, a_entry, pa);
    return
end
blind_hops = 0;

% --- smoothness filter on the regulated margin -----------------------------
if isnan(b_filt)
    b_filt = b;
else
    b_filt = (1 - filt_alpha)*b_filt + filt_alpha*b;
end

severe = b < pa(11)*target;
low = min(b, b_filt) < target - pa(7);
if low
    below_n = below_n + 1;
else
    below_n = 0;
end

% --- predicted safe authorities (contiguous safe interval around alpha=1) --
a_pred_dn = NaN;
a_pred_up = NaN;
if pred_valid && pa(19) ~= 0
    thr = target + pa(20);
    na = numel(alpha_grid);
    i1 = 1;
    dbest = abs(alpha_grid(1) - 1);
    for k = 2:na
        if abs(alpha_grid(k) - 1) < dbest
            dbest = abs(alpha_grid(k) - 1);
            i1 = k;
        end
    end
    j = i1;
    while j >= 1 && ~(pred_margin(j) >= thr)
        j = j - 1;
    end
    if j >= 1
        a_pred_dn = alpha_grid(j)*a_cont;
    else
        a_pred_dn = alpha_grid(1)*a_cont;
    end
    if pred_margin(i1) >= thr
        j = i1;
        while j < na && pred_margin(j+1) >= thr
            j = j + 1;
        end
        if j < na && pred_margin(j) > pred_margin(j+1) + 1e-12
            % interpolate the alpha where the prediction crosses thr
            frac = (pred_margin(j) - thr) ...
                /(pred_margin(j) - pred_margin(j+1));
            alpha_b = alpha_grid(j) ...
                + frac*(alpha_grid(j+1) - alpha_grid(j));
        else
            alpha_b = alpha_grid(j);
        end
        a_pred_up = alpha_b*a_cont;
    else
        a_pred_up = a_cont;
    end
end

if shed_settle > 0
    shed_settle = shed_settle - 1;
end

commit = false;
if severe || below_n >= pa(8)
    % ---------------- confirmed deficit: shed authority -----------------
    if severe
        b_size = b;
    else
        b_size = b_filt;
    end
    % size the shed ONCE per estimator settle (down_settle_s) or on fresh
    % lower evidence (re_shed_delta): the margin estimate lags the loop,
    % so re-deriving a multiplicative shed from the same stale reading
    % every step would compound one dip into a slam to the floor
    fresh = isnan(b_shed_ref) || b_size < b_shed_ref - pa(29);
    if fresh || shed_settle <= 0
        a_pl = a_cont*(max(b_size, 0.02)/target)^pa(9);
        a_tgt = min(a_pl, a_cont);
        if st_binding && ~isnan(a_pred_dn) && a_pred_dn < a_cont
            a_tgt = max(a_tgt, pa(21)*a_pred_dn);
        end
        a_shed_tgt = a_tgt;
        b_shed_ref = b_size;
        shed_settle = max(1, round(pa(28)/dt_up));
    end
    if severe
        rate = pa(12);
        decision = 2;
        commit = true;
    else
        rate = pa(10);
        decision = 1;
    end
    a_cont = min(a_cont, max(a_shed_tgt, a_cont - rate*dt_up));
    if ~st_binding
        trip_cool = max(trip_cool, round(pa(24)/dt_up));
        a_latch = min(a_latch, max(pa(26)*a_cont, 2*a_min));
    end
    above_n = 0;
elseif b_filt >= target + pa(13) && trip_cool <= 0 && a_cont < a_max
    % ---------------- healthy: hold-gated recovery ----------------------
    a_shed_tgt = NaN;
    b_shed_ref = NaN;
    above_n = above_n + 1;
    hold_n = max(1, round(pa(14)/dt_up));
    if above_n >= hold_n
        if valid_up
            rate = pa(15);
        else
            rate = pa(16);
        end
        surplus = max(0, b_filt - target - pa(13));
        rate = rate*(1 + pa(17)*surplus/target);
        a_cap = min(a_max, a_latch);
        if ~isnan(a_pred_up)
            % climb up to (not past) the interpolated safe boundary; the
            % pred_guard slack + up_deadband hysteresis are the standoff
            a_cap = min(a_cap, max(a_pred_up, a_cont));
        end
        a_cont = min(a_cap, a_cont + rate*dt_up);
        decision = 3;
    end
else
    above_n = 0;
    if ~low
        a_shed_tgt = NaN;
        b_shed_ref = NaN;
    end
end

% the latched ceiling forgets slowly
a_latch = a_latch + (a_max - a_latch)*dt_up/pa(27);

a_cont = min(max(a_cont, a_min), a_max);

% --- anti-flicker commit gate ----------------------------------------------
if commit ...
        || abs(a_cont - a_out) >= pa(18) ...
        || (a_cont <= a_min + 1e-12 && a_out > a_min) ...
        || (a_cont >= a_max - 1e-12 && a_out < a_max)
    a_out = a_cont;
end
move_age = moveAge(move_age, a_out, a_entry, pa);
end

function move_age = moveAge(move_age, a_out, a_entry, pa)
% age of the last material committed-authority move (self-motion gate)
if abs(a_out - a_entry) > pa(31)*max(a_entry, pa(2))
    move_age = 0;
else
    move_age = min(move_age + 1, 1e6);
end
end

% ==========================================================================
% codegen-safe utilities (bit-compatible with the desktop implementations)
% ==========================================================================
function seg = unwrapTail(ring, pos, ring_n, want_n)
% last want_n samples ending at ring(pos), oldest first
seg = zeros(want_n, 1);
for i = 1:want_n
    j = pos - want_n + i;
    if j <= 0
        j = j + ring_n;
    end
    seg(i) = ring(j);
end
end

function y = detrendLinearRt(x)
n = numel(x);
t = (1:n)'/n;
X = [ones(n, 1) t];
y = x - X*(X\x);
end

function m = maxMasked(x, mask)
% max(x(mask)) - order-independent, so a loop matches the vector op
m = -Inf;
for i = 1:numel(x)
    if mask(i) && x(i) > m
        m = x(i);
    end
end
end

function y = movMaxRt(x, n)
% centered moving max, window n (odd), shrinking endpoints = movmax(x, n)
half = floor(n/2);
N = numel(x);
y = x;
for i = 1:N
    lo = i - half;
    if lo < 1
        lo = 1;
    end
    hi = i + half;
    if hi > N
        hi = N;
    end
    m = x(lo);
    for j = lo+1:hi
        if x(j) > m
            m = x(j);
        end
    end
    y(i) = m;
end
end

function m = medianFirstN(buf, cnt)
% median(buf(1:cnt)) via a +Inf-padded fixed-size sort. The even-count
% average replicates MATLAB's median/meanof EXACTLY (overflow-safe
% midpoint unless the signs differ or a value is infinite) so the runtime
% stays bitwise-identical to the desktop implementation.
if cnt <= 0
    m = NaN;
    return
end
tmp = inf(numel(buf), 1);
for i = 1:cnt
    tmp(i) = buf(i);
end
s = sort(tmp);
h = floor(cnt/2);
if mod(cnt, 2) == 1
    m = s(h+1);
else
    a = s(h);
    b = s(h+1);
    if sign(a) ~= sign(b) || isinf(a) || isinf(b)
        m = (a + b)/2;
    else
        m = a + (b - a)/2;
    end
end
end

function m = medianMasked(x, mask)
% median(x(mask)) without variable-size arrays
n = numel(x);
buf = zeros(n, 1);
cnt = 0;
for i = 1:n
    if mask(i)
        cnt = cnt + 1;
        buf(cnt) = x(i);
    end
end
m = medianFirstN(buf, cnt);
end

function y = maskedMovMedianRt(x, mask, n)
% = maskedMovMedian in fable_osi.m: median over the masked values inside a
% centered length-n window (n odd, shrinking endpoints); unmasked
% positions and empty windows fall back to the raw value
N = numel(x);
y = x;
half = floor(n/2);
wbuf = zeros(round(n), 1);
for i = 1:N
    if ~mask(i)
        continue
    end
    lo = i - half;
    if lo < 1
        lo = 1;
    end
    hi = i + half;
    if hi > N
        hi = N;
    end
    cnt = 0;
    for j = lo:hi
        if mask(j) && ~isnan(x(j))
            cnt = cnt + 1;
            wbuf(cnt) = x(j);
        end
    end
    if cnt > 0
        y(i) = medianWindowRt(wbuf, cnt);
    end
end
end

function m = medianWindowRt(buf, cnt)
% median(buf(1:cnt)) with MOVMEDIAN's even-count averaging, which differs
% from median()'s: (a+b)/2 when the signs differ or a value is infinite,
% otherwise the midpoint anchored at the SMALLER-MAGNITUDE middle value.
% (Established by exhaustive fuzzing against the builtin - do not "fix".)
tmp = inf(numel(buf), 1);
for i = 1:cnt
    tmp(i) = buf(i);
end
s = sort(tmp);
h = floor(cnt/2);
if mod(cnt, 2) == 1
    m = s(h+1);
else
    a = s(h);
    b = s(h+1);
    if sign(a) ~= sign(b) || isinf(a) || isinf(b)
        m = (a + b)/2;
    elseif abs(a) <= abs(b)
        m = a + (b - a)/2;
    else
        m = b + (a - b)/2;
    end
end
end
