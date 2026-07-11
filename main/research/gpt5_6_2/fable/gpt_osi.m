function [out, state, info] = gpt_osi(varargin)
%GPT_OSI Continuous two-term online NCF-margin estimate (v2, gpt5_6_2).
%
%   cfg = gpt_osi('config', dt, initial_loop_tf, override)
%   state = gpt_osi('state', cfg)
%   [b, state, info] = gpt_osi(dd_step, dm_step, cfg, state)
%
% Same interface as research/gpt5_6/gpt_osi.  One 0.5 s sliding DFT gives a
% coherent margin b_st and a quiet-band model reading b_res.  v2 replaces
% the stateless quiet-band gain fit with a PERSISTENT loop-gain state rho
% designed around what the osi_calibration_test record (the corrected
% export of the 20260710_1845 run) proved about this rig: the quiet band
% sits on the dm sensor-noise floor during weak drive (no absolute shape
% fit can see a gain edge there), the coherent tap FRF is biased by the
% FEM force-echo wrap (no absolute model fit can be trusted), and once
% excitation stops every channel is blind while damage persists.
%
%   1. CORROBORATED SHAPE FIT.  The 9-bin quiet fit is too noisy to
%      self-gate, so it moves rho only with corroboration: EITHER the
%      coherent driven band reads a gain rise (the original gpt5_6 gate),
%      OR the band power is far above the tracked noise floor AND growing
%      with the command silent (a self-excited ring).  When neither holds
%      the memory HOLDS - the old estimator pulled rho back to 1 here,
%      which erased real damage evidence whenever the band went quiet and
%      re-armed the relaxation oscillation.
%   2. FRF-CHANGE TRIPS (2-step persistence).  A coherence-gated relative
%      change statistic on the driven-band FRF scales rho by the measured
%      loop-gain ratio kappa (up at least 1.5x; releases for repairs).
%      Ratios cancel the tap's multiplicative distortion, so this is the
%      one channel that saw the 1.5x -> 2x diagnostic edge on the real
%      record.  Real changes hold the statistic up for several update
%      steps; every measured false excursion on GDBqFpKb is exactly one
%      step wide, so two consecutive hits are required.  The slow FRF
%      baseline restarts whenever the applied authority moves (the
%      estimator watches the total loop including a) and after every trip.
%   3. SLOW LEAK.  rho relaxes toward 1 with tau rho_relax_s (~150 s): the
%      "careful rise without safety evidence".  Authority creeps back as
%      the memory fades and any re-growth of band power re-pins rho before
%      the loop reaches its stability boundary.
%   4. MEMORY-AWARE IDLE LIMB.  With weak command activity b blends to the
%      rho-model margin instead of the ceiling while damage is remembered,
%      so authority cannot snap back to 1.0 against a still-present 3x gain
%      after the excitation ends.
%   5. RELEASE + GRACE.  A coherently measured gain DROP on the
%      authority-normalized loop (repair / diagnostic restore) releases the
%      memory and opens a short grace window that certifies the recovery
%      sprint the margins alone cannot (the canonical target sits above
%      this plant's healthy margin).
%   6. PATH-VERIFIED RECOVERY MARGIN.  info.full_margin is the minimum
%      chordal margin along the whole authority path a -> min(1, 4a) (the
%      chordal margin is not monotone in gain), from the coherent estimate
%      and - weighted by how much of the band the data does NOT cover -
%      the rho model.

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'config'
            if nargin >= 4, override = varargin{4}; else, override = struct(); end
            out = makeConfig(varargin{2}, varargin{3}, override);
        case 'state'
            out = makeState(varargin{2});
        otherwise
            error('gpt_osi:UnknownCommand', 'Use ''config'', ''state'', or a numeric step call.')
    end
    state = [];
    info = [];
    return
end

[out, state, info] = stepEstimator(varargin{1}, varargin{2}, varargin{3}, varargin{4});
end

function cfg = makeConfig(dt, initial_loop_tf, override)
cfg = struct( ...
    'dt', dt, ...
    'step_s', 0.125, ...
    'segment_s', 0.5, ...
    'memory_s', 0.35, ...
    'margin_s', 0.20, ...
    'residual_s', 1.50, ...
    'warm_s', 2.0, ...
    'band_hz', [2 100], ...
    'line_reject_hz', [58 62], ...
    'residual_band_hz', [28 44], ...
    'power_floor_db', 30, ...
    'quiet_rms', 0.05, ...
    'cap', 1/sqrt(2), ...
    'rho_max', 6.0, ...
    'rho_relax_s', 150, ...
    'fit_ev_ref', 0.25, ...
    'snr_lo', 1.3, ...
    'snr_hi', 2.0, ...
    'snr_ring_lo', 4.0, ...
    'snr_ring_hi', 8.0, ...
    'fast_s', 0.4, ...
    'struct_ref', 0.15, ...
    'floor_rise_s', 60, ...
    'mem_lo', 1.15, ...
    'mem_span', 0.50, ...
    'wrho_span', 0.30, ...
    'trip_gamma', 0.55, ...
    'trip_h', 0.35, ...
    'trip_h_dn', 0.10, ...
    'trip_nu', 0.05, ...
    'trip_cool_s', 1.5, ...
    'trip_arm_s', 1.0, ...
    'trip_astep', 0.03, ...
    'trip_up_min', 1.5, ...
    'trip_up_max', 2.0, ...
    'trip_dn_gate', 0.85, ...
    'trip_dn_min', 0.50, ...
    'trip_dn_cool_s', 0.5, ...
    'grace_s', 6.0, ...
    'slow_tau_s', 4.0);

names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('gpt_osi:UnknownConfigField', 'Unknown parameter: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end

cfg.fs = 1/dt;
cfg.step_n = round(cfg.step_s*cfg.fs);
cfg.segment_n = round(cfg.segment_s*cfg.fs);
assert(cfg.step_n >= 1 && mod(cfg.segment_n, cfg.step_n) == 0, ...
    'segment_s must contain an integer number of step_s blocks')

n = (0:cfg.segment_n-1).';
cfg.window = 0.5 - 0.5*cos(2*pi*n/(cfg.segment_n-1));
f = (0:cfg.segment_n/2)'*cfg.fs/cfg.segment_n;
keep = f >= cfg.band_hz(1) & f <= cfg.band_hz(2);
cfg.bin = find(keep);
cfg.freq_hz = f(keep);
cfg.keep = ~(cfg.freq_hz >= cfg.line_reject_hz(1) & ...
    cfg.freq_hz <= cfg.line_reject_hz(2));
cfg.res_keep = cfg.keep & cfg.freq_hz >= cfg.residual_band_hz(1) & ...
    cfg.freq_hz <= cfg.residual_band_hz(2);

L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.L0 = L0(:);
cfg.nominal_curve = chordal(cfg.L0, cfg.cap);
cfg.nominal = min(cfg.nominal_curve(cfg.keep));
cfg.shape = max(abs(1./(1+cfg.L0)).^2, eps);
% a spectrally FLAT Syy expressed in the qobs = Syy/shape domain: the
% structure test asks whether the band beats this null model
qflat = 1./cfg.shape;
res_tmp = f(keep) >= cfg.residual_band_hz(1) & f(keep) <= cfg.residual_band_hz(2);
cfg.lqflat = log(max(qflat/median(qflat(res_tmp)), eps));
cfg.rho_grid = unique([1, logspace(log10(0.5), log10(cfg.rho_max), 25)]);
cfg.alpha_grid = logspace(0, log10(4), 7);
cfg.spectral_alpha = 1 - exp(-cfg.step_s/cfg.memory_s);
cfg.fast_alpha = 1 - exp(-cfg.step_s/cfg.fast_s);
cfg.margin_alpha = 1 - exp(-cfg.step_s/cfg.margin_s);
cfg.residual_alpha = 1 - exp(-cfg.step_s/cfg.residual_s);
cfg.slow_alpha = 1 - exp(-cfg.step_s/cfg.slow_tau_s);
cfg.power_floor = 10^(-cfg.power_floor_db/10);
cfg.warm_steps = round(cfg.warm_s/cfg.step_s);
cfg.trip_cool_steps = round(cfg.trip_cool_s/cfg.step_s);
cfg.trip_dn_cool_steps = round(cfg.trip_dn_cool_s/cfg.step_s);
cfg.trip_arm_steps = round(cfg.trip_arm_s/cfg.step_s);
cfg.grace_steps = round(cfg.grace_s/cfg.step_s);
end

function state = makeState(cfg)
nf = numel(cfg.freq_hz);
state = struct( ...
    'u', zeros(cfg.segment_n, 1), ...
    'y', zeros(cfg.segment_n, 1), ...
    'samples_in', 0, ...
    'step_count', 0, ...
    'spectral_count', 0, ...
    'Suu', zeros(nf, 1), ...
    'Syy', zeros(nf, 1), ...
    'Syu', complex(zeros(nf, 1)), ...
    'log_rho', 0, ...
    'log_rho_fast', 0, ...
    'noise_floor', Inf, ...
    'Tslow', complex(zeros(nf, 1)), ...
    'Lslow', complex(zeros(nf, 1)), ...
    'gslow', zeros(nf, 1), ...
    'grace', 0, ...
    'd_up_hits', 0, ...
    'd_dn_hits', 0, ...
    'pow_ema', 0, ...
    'med_slow', 0, ...
    'a_ema', 1.0, ...
    'steady_steps', 0, ...
    'armed', false, ...
    'trip_cool', 0, ...
    'a_prev', 1.0, ...
    'b', cfg.cap, ...
    'a_cmd', 1.0);
end

function [b, state, info] = stepEstimator(dd, dm, cfg, state)
dd = dd(:);
dm = dm(:);
if numel(dd) ~= cfg.step_n || numel(dm) ~= cfg.step_n
    error('gpt_osi:StepSize', 'Each call requires exactly %d samples.', cfg.step_n)
end

n = cfg.step_n;
state.u = [state.u(n+1:end); dd];
state.y = [state.y(n+1:end); dm];
state.samples_in = min(cfg.segment_n, state.samples_in+n);
state.step_count = state.step_count+1;

activity = min(1,(rms(state.u)/cfg.quiet_rms)^4);
a_now = min(max(state.a_cmd, 0.02), 1);
Lprior = a_now*activity*cfg.L0;
Tprior = Lprior./(1+Lprior);
b_prior_curve = chordal(Lprior, cfg.cap);
b_prior = min(b_prior_curve(cfg.keep));

if state.samples_in < cfg.segment_n
    state.b = state.b + cfg.margin_alpha*(b_prior-state.b);
    b = state.b;
    info = makeInfo(b_prior, b_prior, b_prior, Tprior, Lprior, ...
        zeros(size(Tprior)), cfg, state, false);
    return
end

Uall = fft(state.u.*cfg.window);
Yall = fft(state.y.*cfg.window);
U = Uall(cfg.bin);
Y = Yall(cfg.bin);
pu = abs(U).^2;
py = abs(Y).^2;
cyu = Y.*conj(U);

if state.spectral_count == 0
    state.Suu = pu;
    state.Syy = py;
    state.Syu = cyu;
else
    q = cfg.spectral_alpha;
    state.Suu = state.Suu + q*(pu-state.Suu);
    state.Syy = state.Syy + q*(py-state.Syy);
    state.Syu = state.Syu + q*(cyu-state.Syu);
end
state.spectral_count = state.spectral_count+1;

gamma2 = min(1, abs(state.Syu).^2./max(state.Suu.*state.Syy, eps));
p_rel = state.Suu/max(max(state.Suu), eps);
leverage = p_rel./(p_rel+cfg.power_floor);
confidence = activity*gamma2.*leverage;
That = state.Syu./max(state.Suu, eps);
Tuse = confidence.*That + (1-confidence).*Tprior;

den = 1-Tuse;
small = abs(den) < 0.02;
den(small) = 0.02*exp(1i*angle(den(small)+eps));
Lhat = Tuse./den;
bcurve = chordal(Lhat, cfg.cap);
bcurve = movmedian(bcurve, 3);
b_st = min(bcurve(cfg.keep));

warm = state.step_count <= cfg.warm_steps;

% ---- residual-band noise floor (leaky minimum of the band median) --------
med_res = median(state.Syy(cfg.res_keep));
if med_res < state.noise_floor
    state.noise_floor = med_res;
else
    state.noise_floor = state.noise_floor*(1 + cfg.step_s/cfg.floor_rise_s);
end
snr = med_res/max(state.noise_floor, eps);
% growth of the band median against its own recent history: a self-excited
% ring GROWS; a decaying post-quake tail is elevated but shrinking and must
% not count as ring evidence
if state.med_slow <= 0, state.med_slow = med_res; end
grow = med_res/max(state.med_slow, eps);
state.med_slow = state.med_slow + (1-exp(-cfg.step_s/3.0))*(med_res - state.med_slow);
w_grow = min(max((grow - 1.2)/0.5, 0), 1);
% Driven, the floor tracks the excitation baseline and small shape growth is
% informative; idle, ambient band power swings +/-3 dB on its own, so only a
% genuine ring (>= ~6 dB) may move rho.
snr_lo = activity*cfg.snr_lo + (1-activity)*cfg.snr_ring_lo;
snr_hi = activity*cfg.snr_hi + (1-activity)*cfg.snr_ring_hi;
w_snr = min(max((snr - snr_lo)/(snr_hi - snr_lo), 0), 1); %#ok<NASGU>

% ---- quiet-band shape fit: corroborated update of the rho state ----------
rho = exp(state.log_rho);
w_lev = (1-mean(leverage(cfg.res_keep)))^2;
% the spectra average over the recent past, so the model family must be
% evaluated at the same era-averaged authority - otherwise the estimator
% reads its own shed as loop-gain growth and ratchets itself down
state.a_ema = state.a_ema + cfg.spectral_alpha*(a_now - state.a_ema);
a_fit = min(max(state.a_ema, 0.02), 1);
w_upd = 0;
w_inst = 0;
log_rho_tgt = state.log_rho;
if ~warm
    qobs = state.Syy./cfg.shape;
    qobs = qobs/max(median(qobs(cfg.res_keep)), eps);
    lq = log(max(qobs(cfg.res_keep), eps));
    % clipped-MEAN log deviation: a median over the ~9 residual bins lets a
    % strongly peaked family member "fit" flat data (it ignores the peak
    % bins entirely) and noise then picks random winners; the mean charges
    % every bin, softly clipped so one contaminated harmonic cannot vote
    % the whole band
    loss = zeros(size(cfg.rho_grid));
    for k = 1:numel(cfg.rho_grid)
        qmod = abs((1+cfg.L0)./(1+a_fit*cfg.rho_grid(k)*cfg.L0)).^2;
        qmod = qmod/max(median(qmod(cfg.res_keep)), eps);
        loss(k) = mean(min(abs(lq - log(max(qmod(cfg.res_keep), eps))), 3));
    end
    [~, kbest] = min(loss);
    rho_best = cfg.rho_grid(kbest);
    loss_cur = interp1(cfg.rho_grid, loss, ...
        min(max(rho, cfg.rho_grid(1)), cfg.rho_grid(end)));
    ev = max(loss_cur - loss(kbest), 0);
    w_fit = 1 - exp(-ev/cfg.fit_ev_ref);
    % The 9-bin quiet fit is too noisy to self-gate, so it moves rho only
    % with corroboration: EITHER the coherent driven band reads a gain
    % rise (the original gpt5_6 gate), OR the band power itself has grown
    % far above the tracked floor (a self-excited ring, which needs no
    % command drive).  When neither holds the memory HOLDS - the old
    % estimator pulled rho back to 1 here, which erased real damage
    % evidence whenever the band went quiet and re-armed the relaxation
    % oscillation.
    wc = confidence.^2;
    Lm = a_fit*cfg.L0;
    rho_drive = real(sum(wc.*conj(Lm).*Lhat))/max(sum(wc.*abs(Lm).^2), eps);
    shape_w = min(max(2*(rho_drive-1), 0), 1);
    % ring evidence demands a truly command-quiet band: driven bursts raise
    % band power and growth together, a self-excited ring does so with the
    % command silent
    w_idle = min(max((0.25 - activity)/0.15, 0), 1);
    w_ring = w_idle*w_grow* ...
        min(max((snr - cfg.snr_ring_lo)/(cfg.snr_ring_hi - cfg.snr_ring_lo), 0), 1);
    w_upd = w_lev*max(shape_w, w_ring)*w_fit;
    state.log_rho = state.log_rho + ...
        cfg.residual_alpha*w_upd*(log(rho_best) - state.log_rho);
    if rho_best > rho
        % fast non-ratcheting read path: the margin READING may follow a
        % decisive fit immediately; the slow memory above stays cautious
        w_inst = w_upd;
        log_rho_tgt = log(rho_best);
    end
end
state.log_rho_fast = state.log_rho_fast + cfg.fast_alpha* ...
    (w_inst*log_rho_tgt + (1-w_inst)*state.log_rho - state.log_rho_fast);

% ---- driven-band FRF-change trip ------------------------------------------
pow_now = mean(state.Suu(cfg.keep));
if state.pow_ema <= 0, state.pow_ema = pow_now; end
regime_ok = pow_now >= 0.125*state.pow_ema && pow_now <= 8*state.pow_ema;
state.pow_ema = state.pow_ema + cfg.slow_alpha*(pow_now - state.pow_ema);
a_steady = abs(log(max(a_now, eps)) - log(max(state.a_prev, eps))) < cfg.trip_astep;
state.a_prev = state.a_prev + 0.5*(a_now - state.a_prev);
good_now = gamma2 > cfg.trip_gamma & cfg.keep & activity > 0.5;
good = good_now & state.gslow > cfg.trip_gamma;
d_stat = 0;
kappa = 1;
trip = 0;
if a_steady && regime_ok && activity > 0.5
    state.steady_steps = state.steady_steps + 1;
else
    state.steady_steps = 0;
    state.armed = false;
end
state.trip_cool = max(state.trip_cool - 1, 0);
just_armed = ~state.armed && state.steady_steps >= cfg.trip_arm_steps;
if just_armed
    % authority or regime just settled: the old baseline mixes eras
    state.armed = true;
    state.Tslow(good_now) = That(good_now);
end
Ln = That./limitDen(1-That)/a_now;   % authority-normalized loop estimate
if ~warm && state.armed && ~just_armed && nnz(good) >= 3
    w = gamma2(good);
    dT = That(good) - state.Tslow(good);
    d_stat = sum(w.*abs(dT).^2)/max(sum(w.*(abs(state.Tslow(good)).^2 + cfg.trip_nu)), eps);
    % release channel: compare the a-normalized loop against its slow
    % baseline.  Dividing by the applied authority makes this immune to
    % the law's own moves, so the baseline survives shed/recover motion
    % and a diagnostic-restore edge stays detectable even when arming
    % only completes after the edge.
    dLn = Ln(good) - state.Lslow(good);
    d_n = sum(w.*abs(dLn).^2)/max(sum(w.*(abs(state.Lslow(good)).^2 + cfg.trip_nu)), eps);
    kappa_n = real(sum(w.*conj(state.Lslow(good)).*Ln(good)))/ ...
        max(sum(w.*abs(state.Lslow(good)).^2), eps);
    % PERSISTENCE: a real loop change holds the statistic up until the
    % slow baseline re-converges (~4 s); single-segment nonstationarity
    % artifacts (measured on GDBqFpKb: all its healthy excursions are
    % exactly one step wide) do not.  Two consecutive hits are required.
    if state.trip_cool == 0 && d_n > cfg.trip_h_dn && kappa_n < cfg.trip_dn_gate ...
            && state.log_rho > 0.1
        % only a held memory can be released - a "release" at rho ~ 1 would
        % merely open an unearned grace window
        state.d_dn_hits = state.d_dn_hits + 1;
    else
        state.d_dn_hits = 0;
    end
    if state.trip_cool == 0 && d_stat > cfg.trip_h
        state.d_up_hits = state.d_up_hits + 1;
    else
        state.d_up_hits = 0;
    end
    if state.d_dn_hits >= 2
        % coherent gain DROP (repair / diagnostic restore): releasing
        % memory is safe at a lower change threshold - a false release is
        % re-corrected by the up channels, a missed one deadlocks recovery
        % (the GDBqFpKb lesson).  A release opens a grace window that
        % certifies the recovery sprint the margins alone cannot (the
        % canonical target sits above this plant's healthy margin).
        kap = min(max(kappa_n, cfg.trip_dn_min), cfg.trip_dn_gate);
        state.log_rho = max(state.log_rho + log(kap), 0);
        state.log_rho_fast = max(state.log_rho_fast + log(kap), 0);
        trip = -1;
        kappa = kappa_n;
        state.grace = cfg.grace_steps;
        state.trip_cool = cfg.trip_dn_cool_steps;
        state.d_dn_hits = 0;
        state.d_up_hits = 0;
        state.Lslow(good) = Ln(good);
        state.Tslow(good) = That(good);
    elseif state.d_up_hits >= 2
        Lf = That(good)./limitDen(1-That(good));
        Ls = state.Tslow(good)./limitDen(1-state.Tslow(good));
        kappa = real(sum(w.*conj(Ls).*Lf))/max(sum(w.*abs(Ls).^2), eps);
        if kappa >= cfg.trip_dn_gate
            % gain rise or unexplained change: conservative up-bump
            kap = min(max(kappa, cfg.trip_up_min), cfg.trip_up_max);
            state.log_rho = min(state.log_rho + log(kap), log(cfg.rho_max));
            state.log_rho_fast = max(state.log_rho_fast + log(kap), 0);
            trip = 1;
            state.grace = 0;
            state.trip_cool = cfg.trip_cool_steps;
            state.Tslow(good) = That(good);
            state.Lslow(good) = Ln(good);
        end
        state.d_up_hits = 0;
    end
end
% slow FRF baselines over the bins the command currently supports
fresh = good_now & state.gslow < 0.05;
state.Tslow(fresh) = That(fresh);
state.Lslow(fresh) = Ln(fresh);
upd = good_now & ~fresh;
state.Tslow(upd) = state.Tslow(upd) + cfg.slow_alpha*(That(upd) - state.Tslow(upd));
state.Lslow(upd) = state.Lslow(upd) + cfg.slow_alpha*(Ln(upd) - state.Lslow(upd));
state.gslow(good_now) = state.gslow(good_now) + cfg.slow_alpha*(1 - state.gslow(good_now));
state.gslow(~good_now) = state.gslow(~good_now)*(1 - 0.25*cfg.slow_alpha);
state.grace = max(state.grace - 1, 0);

% ---- slow leak toward healthy (careful blind rise) -------------------------
state.log_rho = state.log_rho*(1 - cfg.step_s/cfg.rho_relax_s);
rho = min(max(exp(max(state.log_rho, state.log_rho_fast)), ...
    cfg.rho_grid(1)), cfg.rho_max);

% ---- assemble the reading ---------------------------------------------------
if warm
    b_res = b_prior;
    rho_eff = 1;
else
    rho_eff = max(rho, 1);
    b_res_curve = movmedian(chordal(a_now*rho*cfg.L0, cfg.cap), 3);
    b_res = min(b_res_curve(cfg.keep));
end
coh_res = mean(confidence(cfg.res_keep));
w_rho = min(max((rho_eff-1)/cfg.wrho_span, 0), 1);
% a fresh coherent restore-release vouches for the loop for a few seconds:
% during grace the unobserved-band caution is suspended so the certified
% recovery sprint can run (fades over the last second of the window)
grace_w = min(max(state.grace/8, 0), 1);
res_weight = activity*max(w_lev, w_rho*(1-coh_res))*(1-grace_w);
b_evid = b_st - res_weight*max(b_st-b_res, 0);

w_mem = min(max((rho_eff-cfg.mem_lo)/cfg.mem_span, 0), 1);
b_mem_curve = movmedian(chordal(a_now*rho_eff*cfg.L0, cfg.cap), 3);
b_mem = min(b_mem_curve(cfg.keep));
b_idle = cfg.cap - w_mem*(cfg.cap - b_mem);

b_raw = activity*b_evid + (1-activity)*b_idle;
state.b = state.b + cfg.margin_alpha*(b_raw-state.b);
b = min(max(state.b, 0), cfg.cap);
ready = state.step_count*cfg.step_s >= cfg.warm_s;
info = makeInfo(b_st, b_res, b_raw, Tuse, Lhat, confidence, ...
    cfg, state, ready);
info.residual_weight = res_weight;
info.rho = rho;
info.w_mem = w_mem;
info.w_upd = w_upd;
info.snr = snr;
info.trip = trip;
info.d_stat = d_stat;
info.kappa = kappa;

% path-verified full-authority margin along a -> min(1, 4a): the coherent
% estimate always constrains; the rho model constrains in proportion to how
% much of the band the data does NOT directly cover.
alpha_max = min(1/a_now, 4);
full_data = cfg.cap;
full_model = cfg.cap;
for alpha = cfg.alpha_grid
    al = min(alpha, alpha_max);
    c1 = movmedian(chordal(al*Lhat, cfg.cap), 3);
    c2 = movmedian(chordal(al*a_now*rho_eff*cfg.L0, cfg.cap), 3);
    full_data = min(full_data, min(c1(cfg.keep)));
    full_model = min(full_model, min(c2(cfg.keep)));
    if alpha >= alpha_max, break, end
end
coh_keep = mean(confidence(cfg.keep));
w_veto = w_rho*(1-coh_keep);
full = min(full_data, cfg.cap - w_veto*(cfg.cap - full_model));
info.full_margin = full + grace_w*(cfg.cap - full);
info.grace = grace_w;
end

function d = limitDen(d)
small = abs(d) < 0.02;
d(small) = 0.02*exp(1i*angle(d(small)+eps));
end

function info = makeInfo(b_st, b_res, b_raw, T, L, confidence, cfg, state, ready)
info = struct( ...
    'b_st', b_st, ...
    'b_res', b_res, ...
    'b_raw', b_raw, ...
    'T_hat', T, ...
    'L_hat', L(cfg.keep), ...
    'confidence', mean(confidence(cfg.keep)), ...
    'residual_weight', 0, ...
    'full_margin', cfg.nominal, ...
    'rho', 1, ...
    'w_mem', 0, ...
    'w_upd', 0, ...
    'snr', 1, ...
    'trip', 0, ...
    'd_stat', 0, ...
    'kappa', 1, ...
    'grace', 0, ...
    'freq_hz', cfg.freq_hz, ...
    'ready', ready, ...
    'warm_fraction', min(1, state.step_count/max(cfg.warm_steps, 1)));
end

function b = chordal(L, cap)
b = abs(1+L)./sqrt(2*(1+abs(L).^2));
b = min(real(b), cap);
end
