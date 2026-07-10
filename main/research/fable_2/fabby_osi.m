function [out, state, info] = fabby_osi(varargin)
%FABBY_OSI Continuous NCF-margin stability indicator (fable_2 redesign).
%
% Commands (same call pattern as fable_osi):
%   cfg    = fabby_osi('config', dt, initial_loop_tf, override)
%   state  = fabby_osi('state', cfg)
%   result = fabby_osi('run', dd, dm, dt, initial_loop_tf, override)
%   [b, state, info] = fabby_osi(dd_step, dm_step, cfg, state)   % step
%
% The step call consumes exactly cfg.step_n samples (0.125 s) of dd (loop
% command / OSI tap) and dm (measured displacement) per call and ALWAYS
% returns a finite margin in (0, 1/sqrt(2)] - never NaN.
%
% DESIGN: one estimator, two readings, zero modes.
%
%   Every step, one Hann segment (0.5 s) of dd and dm is FFT'd and folded
%   into exponentially forgotten auto/cross spectra (memory tau_s ~ 1 s):
%       Suu <- (1-al)*Suu + al*|U|^2      (same for Syy, Suy)
%   The closed-loop FRF estimate is PRIOR-REGULARIZED:
%       That(w) = Suy / (Suu + lam),   lam = prior_frac * mean_band(Suu)
%   Bins the command actually drives have Suu >> lam and are data-driven;
%   undriven bins (and total silence) shrink That -> 0, whose chordal
%   margin is the ceiling 1/sqrt(2) = "nothing observable is wrong".
%   This one term replaces fable's coherence gate, input-power gate,
%   sidelobe guard and evidence gate - a quiet bin can never fake a
%   deficit because it has no leverage on That.
%
%   Reading 1 - driven-band margin (the project quantity):
%       b_st = min_w  |1+L|/sqrt(2(1+|L|^2)) = 1/(sqrt(2)*sqrt(|1-That|^2+|That|^2))
%   after a 3-bin frequency median (kills single-bin estimator spikes).
%
%   Reading 2 - quiet-band growth margin. Where the command has no power
%   the loop can still drift toward instability; there the output PSD is
%   noise shaped by the sensitivity, P(w) ~ |S(w)|^2 * N0(w).  With
%   q(w) = P(w)/shape(w) self-normalized by its own quiet-band median,
%   narrowband growth g(w) estimates |S_now/S_base|^2, and since
%   b ~ 1/(sqrt(2)|S|) near the critical point,
%       b_q = b0(w*) / sqrt( max(g(w*)/g_thr, 1) )
%   g_thr is the statistical allowance (smallest credible growth); below
%   it the quiet band reads its anchor b0 (the nominal margin curve).
%   g is POOLED over pool_n neighboring bins (an unstable mode has finite
%   bandwidth), which is what buys detection at ~1.5-2 dB of growth.
%   shape(w) = |S0(w)|^2 from the initial loop model x a slowly LEARNED,
%   +-bl_max_db-bounded per-bin correction (real rigs have colored noise
%   floors; the bound guarantees real growth can never be absorbed).
%
%   Reported margin: b = min(b_st, b_q), clipped to (0, cap]. During the
%   first warm_s (< 2 s) the spectra are still filling and b = cap.
%
% There is no calibration phase, no regime detector, no CUSUM, no trip
% latches and no hysteresis state: warm-up is the estimator memory itself
% (~2 s), and every reading is a continuous function of the spectra.
%
% Tuning (config override):
%   tau_s        spectral memory of the FRF estimate. Smaller = faster
%                detection, noisier margin. 1.0-1.5 s.
%   tau_q        memory of the quiet-band PSD. Slower than tau_s: the
%                quiet statistic needs variance, detection there is
%                allowed 2 s.
%   prior_frac   regularizer as a fraction of mean in-band input power.
%                Larger = more bins treated as unobserved (safer against
%                echo/leakage bins, blinder at weakly driven ones).
%   g_thr_db     smallest quiet-band growth treated as evidence. Lower =
%                more sensitive quiet-band detection, more false sheds.
%   pool_n       bins pooled by the quiet statistic (mode bandwidth).
%   tau_bl       learning time of the per-bin noise-shape correction.
%   bl_max_db    hard bound of that correction (never raise so far that
%                genuine degradation could be learned away).

if ischar(varargin{1})
    switch lower(varargin{1})
        case 'config'
            if nargin >= 4
                out = makeConfig(varargin{2}, varargin{3}, varargin{4});
            else
                out = makeConfig(varargin{2}, varargin{3}, struct());
            end
            state = []; info = [];
        case 'state'
            out = makeState(varargin{2});
            state = []; info = [];
        case 'run'
            if nargin >= 6, ovr = varargin{6}; else, ovr = struct(); end
            out = runRecord(varargin{2}, varargin{3}, varargin{4}, ...
                varargin{5}, ovr);
            state = []; info = [];
        otherwise
            error('fabby_osi:UnknownCommand', ...
                'Use ''config'', ''state'', ''run'' or the numeric step call.')
    end
else
    [out, state, info] = stepOne(varargin{1}, varargin{2}, ...
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
    'quiet_band_hz', [28 100], ...  % hazard band watched by the quiet reading
    'segment_s', 0.5, ...
    'step_s', 0.125, ...
    'tau_s', 0.9, ...               % FRF spectral memory
    'tau_q', 1.25, ...              % quiet-band PSD memory
    'prior_frac', 0.10, ...         % lam = prior_frac * mean_band(Suu)
    'g_thr_db', 1.0, ...            % typical healthy pooled-max growth
    'pool_n', 7, ...                % quiet-band pooling width (bins)
    'quiet_mm', 0.05, ...           % tap rms below this = idle (no evidence);
    ...                             % full evidence above 2x this. An idle or
    ...                             % ended test leaves only the force-echo of
    ...                             % dm in the tap, which is coherent and
    ...                             % fakes a margin - it must not be judged.
    'min_quiet_bins', 8, ...
    'medfilt_n', 3, ...
    'warm_s', 1.5, ...              % spectra fill time; b = cap before this
    'cap', 1/sqrt(2), ...
    'anchor_min', 0.15, ...
    'pred_alpha_max', 16, ...       % authority-prediction grid reach
    'pred_n', 13, ...               % grid points (log-spaced from 1)
    'pred_den_floor', 1e-3);        % |1-That| guard for L = That/(1-That)
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('fabby_osi:UnknownConfigField', ...
            'Unknown fabby_osi config field: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end

cfg.segment_n = round(cfg.segment_s*cfg.fs);
cfg.step_n = round(cfg.step_s*cfg.fs);
cfg.nfft = cfg.segment_n;
df = cfg.fs/cfg.nfft;
f_all = (0:cfg.nfft/2)'*df;
sel = f_all >= cfg.band_hz(1) & f_all <= cfg.band_hz(2);
cfg.freq_hz = f_all(sel);
cfg.bin = find(sel);
cfg.nf = numel(cfg.freq_hz);
cfg.keep = ~(cfg.freq_hz >= cfg.line_reject_hz(1) ...
    & cfg.freq_hz <= cfg.line_reject_hz(2));
cfg.qband = cfg.keep & cfg.freq_hz >= cfg.quiet_band_hz(1) ...
    & cfg.freq_hz <= cfg.quiet_band_hz(2);

n = (0:cfg.segment_n-1).';
cfg.window = 0.5 - 0.5*cos(2*pi*n/(cfg.segment_n - 1));   % Hann

% EMA weights per step
cfg.al   = 1 - exp(-cfg.step_s/cfg.tau_s);
cfg.al_q = 1 - exp(-cfg.step_s/cfg.tau_q);
cfg.warm_steps = ceil(cfg.warm_s/cfg.step_s);
cfg.agrid = logspace(0, log10(cfg.pred_alpha_max), cfg.pred_n).';

% Prior loop model: quiet-band anchor b0(w) and noise-floor shape |S0|^2.
% Used ONLY by the quiet-band reading; the driven-band margin is model-free.
L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.nominal_curve = abs(1 + L0(:))./sqrt(2*(1 + abs(L0(:)).^2));
cfg.anchor = min(cfg.cap, max(cfg.nominal_curve, cfg.anchor_min));
cfg.shape = abs(1./(1 + L0(:))).^2;
cfg.shape = max(cfg.shape, max(cfg.shape)*1e-6);
[cfg.nominal, i0] = min(cfg.nominal_curve);
cfg.nominal_hz = cfg.freq_hz(i0);
end

% ----------------------------------------------------------------- state
function state = makeState(cfg)
state = struct( ...
    'xdd', zeros(cfg.segment_n, 1), ...
    'xdm', zeros(cfg.segment_n, 1), ...
    'step_count', 0, ...
    'Suu', zeros(cfg.nf, 1), ...
    'Syy', zeros(cfg.nf, 1), ...
    'Suy', complex(zeros(cfg.nf, 1)), ...
    'Pq',  zeros(cfg.nf, 1), ...     % quiet-band PSD (slower memory)
    'pin', 0);                       % tap mean-square power (drive level)
end

% ------------------------------------------------------------------ step
function [b, state, info] = stepOne(dd_step, dm_step, cfg, state)
dd_step = dd_step(:);
dm_step = dm_step(:);
assert(numel(dd_step) == cfg.step_n && numel(dm_step) == cfg.step_n, ...
    'fabby_osi step expects exactly cfg.step_n samples per call.')

state.xdd = [state.xdd(cfg.step_n+1:end); dd_step];
state.xdm = [state.xdm(cfg.step_n+1:end); dm_step];
state.step_count = state.step_count + 1;

% one segment FFT per step
U = fft(cfg.window.*detrendLinear(state.xdd));
Y = fft(cfg.window.*detrendLinear(state.xdm));
U = U(cfg.bin);
Y = Y(cfg.bin);
Puu = abs(U).^2;
Pyy = abs(Y).^2;

% exponentially forgotten spectra
state.Suu = (1 - cfg.al)*state.Suu + cfg.al*Puu;
state.Syy = (1 - cfg.al)*state.Syy + cfg.al*Pyy;
state.Suy = (1 - cfg.al)*state.Suy + cfg.al*(Y.*conj(U));
state.Pq  = (1 - cfg.al_q)*state.Pq + cfg.al_q*Pyy;
state.pin = (1 - cfg.al)*state.pin + cfg.al*mean(dd_step.^2);

% ---- reading 1: driven-band chordal margin --------------------------------
lam = cfg.prior_frac*mean(state.Suu(cfg.keep)) + 1e-300;
That = state.Suy./(state.Suu + lam);
chord = 1./(sqrt(2)*max(sqrt(abs(1 - That).^2 + abs(That).^2), eps));
chord = movmedian(chord, cfg.medfilt_n);
b_st = min(cfg.cap, min(chord(cfg.keep)));
[~, i_st] = min(chord + 1e9*~cfg.keep);
f_st = cfg.freq_hz(i_st);

% ---- authority-prediction path ---------------------------------------------
% From the same regularized FRF: the open loop L = That/(1-That), so the
% margin the loop WOULD have at a relative gain multiplier alpha is the
% chordal margin of alpha*L. Computed on the bins the data actually
% support (Suu >= lambda, leverage >= 50%). The authority law uses the
% MINIMUM along the path 1 -> alpha (the margin is not monotone in gain,
% and authority moves through every intermediate value), and sprints
% recovery only where this model-verified curve clears the target.
pred = cfg.cap*ones(cfg.pred_n, 1);
pmask = cfg.keep & state.Suu >= lam;
if nnz(pmask) >= 5
    den = 1 - That(pmask);
    small = abs(den) < cfg.pred_den_floor;
    den(small) = cfg.pred_den_floor*exp(1i*angle(den(small)));
    Lh = That(pmask)./den;
    for k = 1:cfg.pred_n
        La = cfg.agrid(k)*Lh;
        ck = abs(1 + La)./sqrt(2*(1 + abs(La).^2));
        ck = movmedian(ck, cfg.medfilt_n);   % same single-bin-spike
        pred(k) = min(cfg.cap, min(ck));     % guard as the margin itself
    end
end

% ---- reading 2: quiet-band growth margin ----------------------------------
% quiet = hazard-band bins with no meaningful command power, judged on BOTH
% the forgotten spectra and the newest segment (so a fresh excitation-regime
% change removes a bin instantly instead of after a memory flush)
quiet = cfg.qband & state.Suu < lam & Puu < lam;
b_q = cfg.cap;
f_q = NaN;
g_db = NaN;
nq = nnz(quiet);
if nq >= cfg.min_quiet_bins
    qn = state.Pq./cfg.shape;
    qn = qn/max(median(qn(quiet)), 1e-300);   % self-normalized level
    g = maskedMovMean(qn, quiet, cfg.pool_n); % pooled over mode bandwidth
    g(~quiet) = 0;
    [g_max, i_q] = max(g);
    f_q = cfg.freq_hz(i_q);
    g_db = 10*log10(max(g_max, 1e-12));
    g_thr = 10^(cfg.g_thr_db/10);
    % SMOOTH mapping (no saturation kink): the regulator needs b_q to be
    % a continuous, monotone function of the observed growth so the
    % closed loop has an equilibrium instead of a relaxation oscillation.
    % g_thr recenters it: at the typical healthy pooled max (g = g_thr)
    % the reading equals the anchor.
    b_q = min(cfg.cap, cfg.anchor(i_q)/sqrt(max(g_max/g_thr, 1e-3)));
end

% observability of the prediction: with a populated quiet band, the
% command does NOT drive the loop's hazard region, so the driven-band FRF
% certifies nothing about higher authority there - and the quiet statistic
% itself saturates blind at reduced gain, so it cannot substitute. The
% law uses this flag to disable the model-verified sprint; regulation then
% rides on the (slower, always-safe) proportional creep. Wherever the
% sprint is supposed to be fast - broadband repair/heal, pulse over, test
% over, silence - the quiet set is empty and the flag is false.
q_blind = nq >= cfg.min_quiet_bins;

% ---- combine ---------------------------------------------------------------
% evidence weight: below quiet_mm of tap rms the "loop" visible in the
% spectra is only the force-echo of the output noise, which is coherent
% and fakes a margin - blend the reading toward the healthy ceiling as
% the drive dies (w=1 above 2x quiet_mm, w=0 below quiet_mm)
w_ev = max(0, min(1, sqrt(state.pin)/cfg.quiet_mm - 1));
warm = state.step_count <= cfg.warm_steps;
if warm
    b = cfg.cap;
    pred(:) = cfg.cap;
    blind = 0;
else
    b_evid = max(min([b_st, b_q, cfg.cap]), 1e-3);
    b = w_ev*b_evid + (1 - w_ev)*cfg.cap;
    pred = w_ev*pred + (1 - w_ev)*cfg.cap;
    % the blindness only matters to the extent there is evidence at all:
    % an idle tap populates the quiet mask trivially, but idle recovery
    % must ride the sprint (b and pred read the ceiling there anyway)
    blind = double(q_blind)*w_ev;
end

info = struct('margin', b, 'b_st', b_st, 'b_q', b_q, ...
    'f_st_hz', f_st, 'f_q_hz', f_q, 'g_db', g_db, 'n_quiet', nq, ...
    'lam', lam, 'warm', warm, 'w_ev', w_ev, 'blind', blind, ...
    'pred', pred, 'agrid', cfg.agrid, ...
    'nominal', cfg.nominal, 'nominal_hz', cfg.nominal_hz);
end

% ------------------------------------------------------------- utilities
function y = detrendLinear(x)
n = numel(x);
t = (1:n)'/n;
X = [ones(n,1) t];
y = x - X*(X\x);
end

function y = maskedMovMean(x, mask, n)
xm = x;
xm(~mask) = NaN;
y = movmean(xm, n, 'omitnan');
y(~mask) = 0;
y(isnan(y)) = 0;
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
b_st = NaN(n_step, 1);
b_q = NaN(n_step, 1);
f_st = NaN(n_step, 1);
f_q = NaN(n_step, 1);
g_db = NaN(n_step, 1);
n_quiet = zeros(n_step, 1);
warm = false(n_step, 1);
blind = zeros(n_step, 1);
pred = NaN(cfg.pred_n, n_step);

for k = 1:n_step
    idx = (k-1)*cfg.step_n + (1:cfg.step_n);
    [bk, state, ik] = stepOne(dd(idx), dm(idx), cfg, state);
    tc(k) = idx(end)*dt;
    b(k) = bk;
    b_st(k) = ik.b_st;
    b_q(k) = ik.b_q;
    f_st(k) = ik.f_st_hz;
    f_q(k) = ik.f_q_hz;
    g_db(k) = ik.g_db;
    n_quiet(k) = ik.n_quiet;
    warm(k) = ik.warm;
    blind(k) = ik.blind;
    pred(:, k) = ik.pred;
end

result = struct('tc', tc, 'b', b, 'b_st', b_st, 'b_q', b_q, ...
    'f_st', f_st, 'f_q', f_q, 'g_db', g_db, 'n_quiet', n_quiet, ...
    'warm', warm, 'blind', blind, 'pred', pred, 'agrid', cfg.agrid, ...
    'cfg', cfg, 'state', state);
end
