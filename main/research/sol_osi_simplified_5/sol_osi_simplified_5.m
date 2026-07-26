function [out, state, info] = sol_osi_simplified_5(varargin)
%SOL_OSI_SIMPLIFIED_5 Per-frequency evidence fusion of the two OSI branches.
%   cfg = sol_osi_simplified_5('config', dt, initial_loop_tf, override)
%   state = sol_osi_simplified_5('state', cfg)
%   [b, state, info] = sol_osi_simplified_5(dd, dm, cfg, state)
%
%   Identical to sol_osi_simplified up to the point where both branch
%   margins exist.  From there it replaces the scalar evidence-fusion block
%   (res_weight / b_evid / memory_gain / w_mem / b_idle / activity mux, and
%   its 21.75 memory gain plus 0.6/1.4 release latch) with both branches
%   kept as curves over frequency and three statements per bin:
%
%     1. w_st(f)  = c(f)                    identified margin is believable
%                                           where the loop is visible;
%        w_res(f) = (1-c(f))*d(f)           the rho model is believable where
%                                           the observation detected a
%                                           deviation clearing the resolution
%                                           of the rho fit itself.
%     2. b(f) = w_st*b_st + w_res*b_rho + (1-w_st-w_res)*b_prior
%           A bin with neither kind of evidence falls back to the current
%           authority-scaled commissioning prior.
%     3. b = min_f b(f)
%           The worst frequency governs, as the chordal/NCF definition says.
%           The min now runs after the per-frequency estimate is formed
%           rather than before, so it no longer combines margins taken at
%           different frequencies.
%
%   Idle stops being a special case: quiet means every c(f) is zero, so a
%   loop still matching its commissioning reads its prior, while a bin that
%   detected damage keeps reporting it.  Recovery needs no
%   latch either -- the observation branch is the only one carrying memory,
%   and it forgets on one criterion (observed power no longer above the
%   healthy reference) with one time constant, rho_recover_s.

persistent eta_A_override benchmark_override

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'config'
            override = struct();
            if ~isempty(benchmark_override), override = benchmark_override; end
            if nargin >= 4, override = mergeStruct(override, varargin{4}); end
            if ~isempty(eta_A_override), override.eta_A = eta_A_override; end
            out = makeConfig(varargin{2}, varargin{3}, override);
        case 'state'
            out = makeState(varargin{2});
        case 'set_eta'
            eta_A_override = varargin{2};
            out = eta_A_override;
        case 'set_override'
            benchmark_override = varargin{2};
            out = benchmark_override;
        otherwise
            error('sol_osi_simplified_5:UnknownCommand', ...
                ['Use ''config'', ''state'', ''set_eta'', ''set_override'', ' ...
                'or a numeric step call.'])
    end
    state = [];
    info = [];
    return
end

[out, state, info] = stepEstimator(varargin{1}, varargin{2}, ...
    varargin{3}, varargin{4});
end

function cfg = makeConfig(dt, initial_loop_tf, override)
cfg = struct( ...
    'dt', dt, ...
    'step_s', 0.125, ...
    'segment_s', 0.5, ...
    'memory_s', 0.25, ...
    'margin_s', 0.25, ...
    'residual_s', 1.00, ...
    'warm_s', 2.0, ...
    'band_hz', [2 100], ...
    'line_reject_hz', [58 62], ...
    'power_floor_db', 30, ...
    'fit_floor', 0.10, ...
    'eta_A', 0.0575, ...
    'hard_activity_gain', 0.80, ...
    'detector_max', 1.95, ...  % ceiling on the fast drive-ratio kick on rho
    'rho_recover_s', 0.4, ...  % the one recovery time constant
    'rho_detect', 1.75, ...    % rho resolution: below this a bin saw little
    'no_evidence_prior', true, ...
    'reference_level_beta', 0.50, ...
    'level_fit_gain', 0.28, ...
    'level_fit_start_ratio', 4.0, ...
    'cap', 1/sqrt(2));
cfg = applyOverride(cfg, override);

cfg.fs = 1/dt;
cfg.step_n = round(cfg.step_s*cfg.fs);
cfg.segment_n = round(cfg.segment_s*cfg.fs);
assert(cfg.step_n >= 1 && mod(cfg.segment_n, cfg.step_n) == 0, ...
    'segment_s must contain an integer number of step_s blocks')

n = (0:cfg.segment_n-1).';
cfg.window = 0.5-0.5*cos(2*pi*n/(cfg.segment_n-1));
f = (0:cfg.segment_n/2)'*cfg.fs/cfg.segment_n;
cfg.bin = find(f >= cfg.band_hz(1) & f <= cfg.band_hz(2));
cfg.freq_hz = f(cfg.bin);
cfg.keep = ~(cfg.freq_hz >= cfg.line_reject_hz(1) & ...
    cfg.freq_hz <= cfg.line_reject_hz(2));
cfg.rho_fit_keep = cfg.keep;
cfg.reference_keep = cfg.keep;
assert(any(cfg.rho_fit_keep) && any(cfg.reference_keep), ...
    'The selected OSI bands contain no usable bins.')

cfg.L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.L0 = cfg.L0(:);
cfg.nominal_curve = chordal(cfg.L0, cfg.cap);
cfg.nominal = min(cfg.nominal_curve.*cfg.keep+cfg.cap*(~cfg.keep));
cfg.shape = max(abs(1./(1+cfg.L0)).^2, eps);
cfg.rho_grid = logspace(log10(0.5), log10(6), 25);
cfg.spectral_alpha = 1-exp(-cfg.step_s/cfg.memory_s);
cfg.margin_alpha = 1-exp(-cfg.step_s/cfg.margin_s);
cfg.residual_alpha = 1-exp(-cfg.step_s/cfg.residual_s);
cfg.drive_alpha = 1-exp(-cfg.step_s/cfg.warm_s);
cfg.recover_alpha = 1-exp(-cfg.step_s/cfg.rho_recover_s);
cfg.power_floor = 10^(-cfg.power_floor_db/10);
cfg.warm_steps = round(cfg.warm_s/cfg.step_s);
cfg.reference_stride = cfg.segment_n/cfg.step_n;
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
    'q_ref_samples', zeros(nf, 3), ...
    'q_ref', zeros(nf, 1), ...
    'q_ref_count', 0, ...
    'reference_ratio', 1, ...
    'log_rho', zeros(nf, 1), ...
    'rho_drive', 1, ...
    'ratio_prev', 0, ...
    'b', cfg.cap, ...
    'a_cmd', 1.0);
end

function [b, state, info] = stepEstimator(dd, dm, cfg, state)
dd = dd(:);
dm = dm(:);
if numel(dd) ~= cfg.step_n || numel(dm) ~= cfg.step_n
    error('sol_osi_simplified_5:StepSize', ...
        'Each call requires exactly %d samples.', cfg.step_n)
end

n = cfg.step_n;
state.u = [state.u(n+1:end); dd];
state.y = [state.y(n+1:end); dm];
state.samples_in = min(cfg.segment_n, state.samples_in+n);
state.step_count = state.step_count+1;

activity = double(rms(state.u) > cfg.eta_A);
activation_weight = cfg.hard_activity_gain*activity;
a_now = min(max(state.a_cmd, 0.02), 1);
Lprior = a_now*cfg.L0;
Tprior = Lprior./(1+Lprior);
b_prior_curve = chordal(Lprior, cfg.cap);
b_prior = minMasked(b_prior_curve, cfg.keep);

if state.samples_in < cfg.segment_n
    state.b = state.b+activity*cfg.margin_alpha*(b_prior-state.b);
    b = state.b;
    info = makeInfo(b_prior, cfg.cap, b_prior, Tprior, Lprior, ...
        zeros(size(Tprior)), activity, 0, 1, cfg.nominal, cfg, state);
    return
end

Uall = fft(state.u.*cfg.window);
Yall = fft(state.y.*cfg.window);
U = Uall(cfg.bin);
Y = Yall(cfg.bin);
pu = abs(U).^2;
py = abs(Y).^2;
cyu = Y.*conj(U);
if state.q_ref_count < 3 && mod(state.step_count, cfg.reference_stride) == 0
    state.q_ref_count = state.q_ref_count+1;
    state.q_ref_samples(:, state.q_ref_count) = py;
    if state.q_ref_count == 3
        state.q_ref = median(state.q_ref_samples, 2);
    end
end
if state.spectral_count == 0
    state.Suu = pu;
    state.Syy = py;
    state.Syu = cyu;
else
    q = cfg.spectral_alpha;
    state.Suu = state.Suu+q*(pu-state.Suu);
    state.Syy = state.Syy+q*(py-state.Syy);
    state.Syu = state.Syu+q*(cyu-state.Syu);
end
state.spectral_count = state.spectral_count+1;

%% ---- branch 1: identification ---------------------------------------------
gamma2 = min(1, abs(state.Syu).^2./max(state.Suu.*state.Syy, eps));
p_rel = state.Suu/max(max(state.Suu), eps);
leverage = p_rel./(p_rel+cfg.power_floor);
confidence = activity*gamma2.*leverage;
That = state.Syu./max(state.Suu, eps);
Tuse = confidence.*That+(1-confidence).*Tprior;
den = 1-Tuse;
small = abs(den) < 0.02;
den(small) = 0.02*exp(1i*angle(den(small)+eps));
Lhat = Tuse./den;
b_st_curve = movmedian(chordal(Lhat, cfg.cap), 3);
full_coherent = minMasked(movmedian(chordal(min(1/a_now, 4)*Lhat, ...
    cfg.cap), 3), cfg.keep);

%% ---- branch 2: observation -------------------------------------------------
rho_best = ones(size(cfg.L0));
drive_ratio = 1;
if state.step_count > cfg.warm_steps
    qobs = state.Syy./cfg.shape;
    if state.q_ref_count == 3
        qobs = state.Syy./max(state.q_ref, eps);
        state.reference_ratio = median(qobs(cfg.reference_keep));
        qobs = qobs/max(median(qobs(cfg.reference_keep))^ ...
            cfg.reference_level_beta, eps);
    else
        qobs = qobs/max(median(qobs(cfg.reference_keep)), eps);
    end
    loss = inf(numel(cfg.L0), numel(cfg.rho_grid));
    for k = 1:numel(cfg.rho_grid)
        qmod = abs((1+cfg.L0)./(1+a_now*cfg.rho_grid(k)*cfg.L0)).^2;
        if state.q_ref_count == 3
            qmod = qmod/max(median(qmod(cfg.reference_keep))^ ...
                cfg.reference_level_beta, eps);
        else
            qmod = qmod/max(median(qmod(cfg.reference_keep)), eps);
        end
        loss(cfg.rho_fit_keep, k) = abs( ...
            log(max(qobs(cfg.rho_fit_keep), eps))- ...
            log(max(qmod(cfg.rho_fit_keep), eps)));
    end
    [~, kbest] = min(loss, [], 2);
    rho_values = cfg.rho_grid(:);
    rho_best(cfg.rho_fit_keep) = rho_values(kbest(cfg.rho_fit_keep));
    weights = confidence.^2;
    Lmodel = a_now*cfg.L0;
    rho_drive = real(sum(weights.*conj(Lmodel).*Lhat))/ ...
        max(sum(weights.*abs(Lmodel).^2), eps);
    rho_drive = max(rho_drive, eps);
    % Fast-detector kick: clamped, and gated on two consecutive hot
    % updates (min with the previous excursion) so a single noisy
    % 0.125 s window cannot yank the authority; real edges hold for
    % 2+ updates and pass with one update of extra latency.
    raw_kick = max(rho_drive/state.rho_drive-1, 0);
    kick = min(min(raw_kick, state.ratio_prev), cfg.detector_max-1);
    state.ratio_prev = raw_kick;
    drive_ratio = 1+activation_weight*kick;
    state.rho_drive = state.rho_drive+cfg.drive_alpha* ...
        (rho_drive-state.rho_drive);
    coherent_weight = min(max(2*(rho_drive-1), 0), 1);
    level_weight = max(1-cfg.level_fit_start_ratio/ ...
        max(state.reference_ratio, eps), 0);
    effective_fit_floor = cfg.fit_floor+cfg.level_fit_gain*level_weight;
    shape_weight = coherent_weight+effective_fit_floor*activity* ...
        (1-coherent_weight);
    rho_target = 1+shape_weight*(rho_best-1);
    dlog_rho = log(rho_target)-state.log_rho;
    alpha_rho = activity*cfg.residual_alpha;
    state.log_rho = state.log_rho+alpha_rho*dlog_rho;
end
% Recovery.  The observation branch is the only one carrying memory, so it
% is the only one that has to forget.  One criterion does it: the memory
% exists because the observed output power stood above the healthy
% reference, so it decays whenever that is no longer true -- while quiet,
% and equally while driven after a repair.  This is the only recovery
% constant in the estimator.
forgetting = double(state.reference_ratio < 1);
state.log_rho = state.log_rho*(1-cfg.recover_alpha*forgetting);
rho = exp(state.log_rho)*drive_ratio;

%% ---- fusion: per bin, then worst bin ---------------------------------------
b_rho_curve = movmedian(chordal(a_now*rho.*cfg.L0, cfg.cap), 3);
% Two independent kinds of evidence exist at every bin, and each one has to
% pay for the claim it makes:
%   c(f) - the loop is directly visible here (drive energy and coherence),
%          so the identified margin is worth believing;
%   d(f) - the observed power has moved far enough from the healthy
%          reference to clear the resolution of the rho fit itself, so the
%          rho-corrected model is worth believing.
% A bin with neither kind of evidence falls back to the current
% authority-scaled commissioning prior. Quiet is therefore an ordinary
% case: every c is zero, an undamaged loop reads its prior, and a bin that
% detected damage keeps reporting it until the recovery criterion forgets.
detected = min(max((rho-1)/(cfg.rho_detect-1), 0), 1);
w_st = confidence;
w_res = (1-confidence).*detected;
no_evidence_curve = cfg.cap*ones(size(b_prior_curve));
if cfg.no_evidence_prior
    no_evidence_curve = b_prior_curve;
end
b_bin = w_st.*b_st_curve+w_res.*b_rho_curve+ ...
    (1-w_st-w_res).*no_evidence_curve;
keep_idx = find(cfg.keep);
[b_raw, governing_local] = min(b_bin(cfg.keep));
governing_bin = keep_idx(governing_local);
state.b = state.b+cfg.margin_alpha*(b_raw-state.b);
b = min(max(state.b, 0), cfg.cap);

info = makeInfo(minMasked(b_st_curve, cfg.keep), ...
    minMasked(b_rho_curve, cfg.keep), b_raw, Tuse, Lhat, confidence, ...
    activity, w_res(governing_bin), rho_best, full_coherent, cfg, state);
info.direct_fraction = w_st(governing_bin);
info.fallback_fraction = 1-w_st(governing_bin)-w_res(governing_bin);
info.governing_freq_hz = cfg.freq_hz(governing_bin);
end

function info = makeInfo(b_st, b_res, b_raw, T, L, confidence, activity, ...
        residual_weight, rho_best, full_margin, cfg, state)
if isscalar(rho_best)
    rho_best = rho_best*ones(size(cfg.L0));
end
info = struct( ...
    'b_st', b_st, ...
    'b_res', b_res, ...
    'b_raw', b_raw, ...
    'T_hat', T, ...
    'L_hat', L(cfg.keep), ...
    'confidence', mean(confidence(cfg.keep)), ...
    'activity', activity, ...
    'residual_weight', residual_weight, ...
    'rho', median(exp(state.log_rho(cfg.keep))), ...
    'rho_best', median(rho_best(cfg.keep)), ...
    'rho_curve', exp(state.log_rho), ...
    'rho_best_curve', rho_best, ...
    'full_margin', full_margin, ...
    'reference_ratio', state.reference_ratio, ...
    'freq_hz', cfg.freq_hz, ...
    'ready', state.step_count*cfg.step_s >= cfg.warm_s);
end

function cfg = applyOverride(cfg, override)
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('sol_osi_simplified_5:UnknownConfigField', ...
            'Unknown parameter: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end
end

function out = mergeStruct(out, extra)
names = fieldnames(extra);
for i = 1:numel(names)
    out.(names{i}) = extra.(names{i});
end
end

function b = chordal(L, cap)
b = min(real(abs(1+L)./sqrt(2*(1+abs(L).^2))), cap);
end

function y = minMasked(x, mask)
y = min(x(mask));
end
