function [out, state, info] = gpt_osi(varargin)
%GPT_OSI Continuous, two-term online NCF-margin estimate.
%
%   cfg = gpt_osi('config', dt, initial_loop_tf, override)
%   state = gpt_osi('state', cfg)
%   [b, state, info] = gpt_osi(dd_step, dm_step, cfg, state)
%
% The estimator uses one 0.5 s sliding DFT.  Its coherent term estimates
% T = dm/dd and evaluates the normalized-coprime-factor chordal margin
%
%   b(w) = 1 / sqrt(2*(|1-T(w)|^2 + |T(w)|^2)).
%
% A quiet-band model fit covers frequencies that the command does not
% excite.  It fits one positive loop-gain multiplier from the normalized
% output-spectrum shape, then evaluates the NCF margin of a*rho*L0.  The
% coherent driven-band gain continuously decides how much of that fit is
% supported.  Weak command activity blends the final reading to the finite
% NCF ceiling, so displacement feedthrough cannot become false evidence.

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
    'cap', 1/sqrt(2));

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
cfg.rho_grid = logspace(log10(0.5), log10(6), 25);
cfg.spectral_alpha = 1 - exp(-cfg.step_s/cfg.memory_s);
cfg.margin_alpha = 1 - exp(-cfg.step_s/cfg.margin_s);
cfg.residual_alpha = 1 - exp(-cfg.step_s/cfg.residual_s);
cfg.power_floor = 10^(-cfg.power_floor_db/10);
cfg.warm_steps = round(cfg.warm_s/cfg.step_s);
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

if state.step_count <= cfg.warm_steps
    b_res = b_prior;
else
    % Fit one positive loop-gain multiplier from the SHAPE of the quiet
    % output spectrum.  Normalization by the band median removes unknown
    % noise intensity; retaining the nominal phase makes the prediction
    % authority-aware through |1+a*rho*L0|^{-2}.
    qobs = state.Syy./cfg.shape;
    qobs = qobs/max(median(qobs(cfg.res_keep)), eps);
    loss = zeros(size(cfg.rho_grid));
    for k = 1:numel(cfg.rho_grid)
        qmod = abs((1+cfg.L0)./(1+a_now*cfg.rho_grid(k)*cfg.L0)).^2;
        qmod = qmod/max(median(qmod(cfg.res_keep)), eps);
        loss(k) = median(abs(log(max(qobs(cfg.res_keep), eps))- ...
            log(max(qmod(cfg.res_keep), eps))));
    end
    [~, kbest] = min(loss);
    w = confidence.^2;
    Lmodel = a_now*cfg.L0;
    rho_drive = real(sum(w.*conj(Lmodel).*Lhat))/ ...
        max(sum(w.*abs(Lmodel).^2), eps);
    shape_weight = min(max(2*(rho_drive-1), 0), 1);
    rho_target = 1+shape_weight*(cfg.rho_grid(kbest)-1);
    state.log_rho = state.log_rho+cfg.residual_alpha* ...
        (log(rho_target)-state.log_rho);
    rho = exp(state.log_rho);
    b_res_curve = movmedian(chordal(a_now*rho*cfg.L0, cfg.cap), 3);
    b_res = min(b_res_curve(cfg.keep));
end

% The quiet-band model is informative only when the experiment is active
% and that band has little command leverage.  Both factors are continuous
% evidence weights, not mode gates.
res_weight = activity*(1-mean(leverage(cfg.res_keep)))^2;
b_evid = b_st-res_weight*max(b_st-b_res, 0);
b_raw = activity*b_evid+(1-activity)*cfg.cap;
state.b = state.b + cfg.margin_alpha*(b_raw-state.b);
b = min(max(state.b, 0), cfg.cap);
ready = state.step_count*cfg.step_s >= cfg.warm_s;
info = makeInfo(b_st, b_res, b_raw, Tuse, Lhat, confidence, ...
    cfg, state, ready);
info.residual_weight = res_weight;
alpha_recovery = min(1/a_now, 4);
full_curve = movmedian(chordal(alpha_recovery*Lhat, cfg.cap), 3);
info.full_margin = min(full_curve(cfg.keep));
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
    'freq_hz', cfg.freq_hz, ...
    'ready', ready, ...
    'warm_fraction', min(1, state.step_count/max(cfg.warm_steps, 1)));
end

function b = chordal(L, cap)
b = abs(1+L)./sqrt(2*(1+abs(L).^2));
b = min(real(b), cap);
end
