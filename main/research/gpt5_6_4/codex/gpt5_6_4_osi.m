function [out, state, info] = gpt5_6_4_osi(varargin)
%GPT5_6_4_OSI Continuous two-branch NCF-margin estimator.
%   cfg = gpt5_6_4_osi('config', dt, initial_loop_tf, override)
%   state = gpt5_6_4_osi('state', cfg)
%   [b, state, info] = gpt5_6_4_osi(dd, dm, cfg, state)

if ischar(varargin{1}) || isstring(varargin{1})
    switch lower(char(varargin{1}))
        case 'config'
            override = struct();
            if nargin >= 4, override = varargin{4}; end
            out = makeConfig(varargin{2}, varargin{3}, override);
        case 'state'
            out = makeState(varargin{2});
        otherwise
            error('gpt5_6_4_osi:UnknownCommand', ...
                'Use ''config'', ''state'', or a numeric step call.')
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
    'margin_s', 0.15, ...
    'residual_s', 0.50, ...
    'warm_s', 2.0, ...
    'band_hz', [2 100], ...
    'line_reject_hz', [58 62], ...
    'residual_band_hz', [28 44], ...
    'power_floor_db', 30, ...
    'fit_floor', 0.175, ...
    'quiet_rms', 0.06, ...
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
cfg.res_keep = cfg.keep & cfg.freq_hz >= cfg.residual_band_hz(1) & ...
    cfg.freq_hz <= cfg.residual_band_hz(2);
assert(any(cfg.keep) && any(cfg.res_keep), ...
    'The selected OSI bands contain no usable bins.')

cfg.L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.L0 = cfg.L0(:);
cfg.nominal = min(chordal(cfg.L0, cfg.cap).*cfg.keep+cfg.cap*(~cfg.keep));
cfg.shape = max(abs(1./(1+cfg.L0)).^2, eps);
cfg.rho_grid = logspace(log10(0.5), log10(6), 25);
cfg.spectral_alpha = 1-exp(-cfg.step_s/cfg.memory_s);
cfg.margin_alpha = 1-exp(-cfg.step_s/cfg.margin_s);
cfg.residual_alpha = 1-exp(-cfg.step_s/cfg.residual_s);
cfg.drive_alpha = 1-exp(-cfg.step_s/cfg.warm_s);
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
    'drive', 0, ...
    'Suu', zeros(nf, 1), ...
    'Syy', zeros(nf, 1), ...
    'Syu', complex(zeros(nf, 1)), ...
    'log_rho', 0, ...
    'rho_drive', 1, ...
    'b', cfg.cap, ...
    'a_cmd', 1.0);
end

function [b, state, info] = stepEstimator(dd, dm, cfg, state)
dd = dd(:);
dm = dm(:);
if numel(dd) ~= cfg.step_n || numel(dm) ~= cfg.step_n
    error('gpt5_6_4_osi:StepSize', ...
        'Each call requires exactly %d samples.', cfg.step_n)
end

n = cfg.step_n;
state.u = [state.u(n+1:end); dd];
state.y = [state.y(n+1:end); dm];
state.samples_in = min(cfg.segment_n, state.samples_in+n);
state.step_count = state.step_count+1;

activity = min(1, (rms(state.u)/cfg.quiet_rms)^4);
state.drive = state.drive+cfg.drive_alpha*(activity-state.drive);
a_now = min(max(state.a_cmd, 0.02), 1);
Lprior = a_now*cfg.L0;
Tprior = Lprior./(1+Lprior);
b_prior = minMasked(chordal(Lprior, cfg.cap), cfg.keep);

if state.samples_in < cfg.segment_n
    state.b = state.b+activity*cfg.margin_alpha*(b_prior-state.b);
    b = state.b;
    info = makeInfo(b_prior, b_prior, b_prior, Tprior, Lprior, ...
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
b_st = minMasked(movmedian(chordal(Lhat, cfg.cap), 3), cfg.keep);
full_coherent = minMasked(movmedian(chordal(min(1/a_now, 4)*Lhat, ...
    cfg.cap), 3), cfg.keep);

rho_best = 1;
drive_ratio = 1;
if state.step_count > cfg.warm_steps
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
    rho_best = cfg.rho_grid(kbest);
    weights = confidence.^2;
    Lmodel = a_now*cfg.L0;
    rho_drive = real(sum(weights.*conj(Lmodel).*Lhat))/ ...
        max(sum(weights.*abs(Lmodel).^2), eps);
    rho_drive = max(rho_drive, eps);
    drive_ratio = 1+state.drive*max(rho_drive/state.rho_drive-1, 0);
    state.rho_drive = state.rho_drive+cfg.drive_alpha* ...
        (rho_drive-state.rho_drive);
    coherent_weight = min(max(2*(rho_drive-1), 0), 1);
    shape_weight = coherent_weight+cfg.fit_floor*activity* ...
        (1-coherent_weight);
    rho_target = 1+shape_weight*(rho_best-1);
    dlog_rho = log(rho_target)-state.log_rho;
    alpha_rho = activity*cfg.residual_alpha;
    state.log_rho = state.log_rho+alpha_rho*dlog_rho;
end
rho = exp(state.log_rho)*drive_ratio;
b_res = minMasked(movmedian(chordal(a_now*rho*cfg.L0, cfg.cap), 3), ...
    cfg.keep);

res_weight = state.drive*(1-mean(leverage(cfg.res_keep)))^2;
b_evid = b_st-res_weight*max(b_st-b_res, 0);
w_mem = min(max(rho-1, 0), 1);
b_idle = cfg.cap-w_mem*(cfg.cap-b_res);
b_raw = activity*b_evid+(1-activity)*b_idle;
state.b = state.b+cfg.margin_alpha*(b_raw-state.b);
b = min(max(state.b, 0), cfg.cap);

info = makeInfo(b_st, b_res, b_raw, Tuse, Lhat, confidence, activity, ...
    res_weight, rho_best, full_coherent, cfg, state);
end

function info = makeInfo(b_st, b_res, b_raw, T, L, confidence, activity, ...
        residual_weight, rho_best, full_margin, cfg, state)
info = struct( ...
    'b_st', b_st, ...
    'b_res', b_res, ...
    'b_raw', b_raw, ...
    'T_hat', T, ...
    'L_hat', L(cfg.keep), ...
    'confidence', mean(confidence(cfg.keep)), ...
    'activity', activity, ...
    'residual_weight', residual_weight, ...
    'rho', exp(state.log_rho), ...
    'rho_best', rho_best, ...
    'full_margin', full_margin, ...
    'freq_hz', cfg.freq_hz, ...
    'ready', state.step_count*cfg.step_s >= cfg.warm_s);
end

function cfg = applyOverride(cfg, override)
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i})
        error('gpt5_6_4_osi:UnknownConfigField', ...
            'Unknown parameter: %s', names{i})
    end
    cfg.(names{i}) = override.(names{i});
end
end

function b = chordal(L, cap)
b = min(real(abs(1+L)./sqrt(2*(1+abs(L).^2))), cap);
end

function y = minMasked(x, mask)
y = min(x(mask));
end
