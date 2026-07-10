function out = gpt5_6(command, varargin)
%GPT5_6 Offline GPT 5.6 OSI and authority-factor replay.
%   cfg = gpt5_6('config', dt, initial_loop_tf, override)
%   out = gpt5_6('run', t, u_osi, dm, dt, initial_loop_tf, override, a)
%   The optional a is the authority that acted during an open-loop replay.

switch lower(command)
    case 'config'
        override = optional(varargin, 3, struct());
        out = struct('osi', osiConfig(varargin{1}, varargin{2}, ...
            fieldOr(override, 'osi', struct())), ...
            'auth', authParams(fieldOr(override, 'auth', struct())));
        out.auth.dt_update = out.osi.step_s;
    case 'run'
        out = runReplay(varargin{:});
    otherwise
        error('gpt5_6:UnknownCommand', 'Use ''config'' or ''run''.')
end
end

function out = runReplay(t, u, dm, dt, initial_loop_tf, override, a_acted)
% Units: t [s], u/dm [mm], dt [s], a_acted/auth_factor [-].
if nargin < 6 || isempty(override), override = struct(); end
if nargin < 7, a_acted = []; end
cfg = gpt5_6('config', dt, initial_loop_tf, override);
state = struct('osi', osiState(cfg.osi), 'auth', struct('a', cfg.auth.a_init));
n = min([numel(t), numel(u), numel(dm)]);
n_step = floor(n/cfg.osi.step_n);
out = struct('tc', NaN(n_step, 1), 'b', NaN(n_step, 1), ...
    'b_st', NaN(n_step, 1), 'b_res', NaN(n_step, 1), ...
    'b_raw', NaN(n_step, 1), 'b_full', NaN(n_step, 1), ...
    'residual_weight', NaN(n_step, 1), 'auth_factor', NaN(n_step, 1), ...
    'cfg', cfg);
for k = 1:n_step
    ii = (k - 1)*cfg.osi.step_n + (1:cfg.osi.step_n);
    if isempty(a_acted)
        state.osi.a_cmd = state.auth.a;
    else
        state.osi.a_cmd = a_acted(ii(1));
    end
    [out.b(k), state.osi, info] = osiStep(u(ii), dm(ii), cfg.osi, state.osi);
    [state.auth.a, auth_info] = authStep(out.b(k), info.full_margin, ...
        info.residual_weight, state.auth, cfg.auth);
    out.tc(k) = t(ii(end));
    out.b_st(k) = info.b_st;
    out.b_res(k) = info.b_res;
    out.b_raw(k) = info.b_raw;
    out.b_full(k) = info.full_margin;
    out.residual_weight(k) = info.residual_weight;
    out.auth_factor(k) = auth_info.a_target;
end
end

function cfg = osiConfig(dt, initial_loop_tf, override)
cfg = struct('dt', dt, 'step_s', 0.125, 'segment_s', 0.5, ...
    'memory_s', 0.35, 'margin_s', 0.20, 'residual_s', 1.50, ...
    'warm_s', 2.0, 'band_hz', [2 100], 'line_reject_hz', [58 62], ...
    'residual_band_hz', [28 44], 'power_floor_db', 30, ...
    'quiet_rms', 0.05, 'cap', 1/sqrt(2));
cfg = applyOverride(cfg, override, 'gpt5_6:UnknownOsiParameter');
cfg.fs = 1/dt;
cfg.step_n = round(cfg.step_s*cfg.fs);
cfg.segment_n = round(cfg.segment_s*cfg.fs);
assert(cfg.step_n >= 1 && mod(cfg.segment_n, cfg.step_n) == 0, ...
    'segment_s must contain an integer number of step_s blocks')
n = (0:cfg.segment_n-1).';
cfg.window = 0.5 - 0.5*cos(2*pi*n/(cfg.segment_n-1));
f = (0:cfg.segment_n/2)'*cfg.fs/cfg.segment_n;
cfg.bin = find(f >= cfg.band_hz(1) & f <= cfg.band_hz(2));
cfg.freq_hz = f(cfg.bin);
cfg.keep = ~(cfg.freq_hz >= cfg.line_reject_hz(1) & cfg.freq_hz <= cfg.line_reject_hz(2));
cfg.res_keep = cfg.keep & cfg.freq_hz >= cfg.residual_band_hz(1) & cfg.freq_hz <= cfg.residual_band_hz(2);
assert(any(cfg.keep) && any(cfg.res_keep), 'The selected OSI bands contain no usable bins.')
cfg.L0 = squeeze(freqresp(initial_loop_tf, 2*pi*cfg.freq_hz));
cfg.L0 = cfg.L0(:);
cfg.nominal_curve = chordal(cfg.L0, cfg.cap);
cfg.nominal = min(cfg.nominal_curve(cfg.keep));
cfg.shape = max(abs(1./(1+cfg.L0)).^2, eps);
cfg.rho_grid = logspace(log10(0.5), log10(6), 25);
cfg.spectral_alpha = 1-exp(-cfg.step_s/cfg.memory_s);
cfg.margin_alpha = 1-exp(-cfg.step_s/cfg.margin_s);
cfg.residual_alpha = 1-exp(-cfg.step_s/cfg.residual_s);
cfg.power_floor = 10^(-cfg.power_floor_db/10);
cfg.warm_steps = round(cfg.warm_s/cfg.step_s);
end

function state = osiState(cfg)
nf = numel(cfg.freq_hz);
state = struct('u', zeros(cfg.segment_n, 1), 'y', zeros(cfg.segment_n, 1), ...
    'samples_in', 0, 'step_count', 0, 'spectral_count', 0, ...
    'Suu', zeros(nf, 1), 'Syy', zeros(nf, 1), ...
    'Syu', complex(zeros(nf, 1)), 'log_rho', 0, 'b', cfg.cap, 'a_cmd', 1);
end

function [b, state, info] = osiStep(u, y, cfg, state)
u = u(:); y = y(:);
assert(numel(u) == cfg.step_n && numel(y) == cfg.step_n, ...
    'Each OSI update must have exactly %d samples.', cfg.step_n)
n = cfg.step_n;
state.u = [state.u(n+1:end); u];
state.y = [state.y(n+1:end); y];
state.samples_in = min(cfg.segment_n, state.samples_in+n);
state.step_count = state.step_count+1;
activity = min(1, (rms(state.u)/cfg.quiet_rms)^4);
a_now = min(max(state.a_cmd, 0.02), 1);
Lprior = a_now*activity*cfg.L0;
Tprior = Lprior./(1+Lprior);
b_prior = min(chordal(Lprior, cfg.cap).*cfg.keep + cfg.cap*(~cfg.keep));
if state.samples_in < cfg.segment_n
    state.b = state.b + cfg.margin_alpha*(b_prior-state.b);
    b = state.b;
    info = makeInfo(b_prior, b_prior, b_prior, Tprior, Lprior, zeros(size(Tprior)), cfg, state);
    return
end
U = fft(state.u.*cfg.window); U = U(cfg.bin);
Y = fft(state.y.*cfg.window); Y = Y(cfg.bin);
pu = abs(U).^2; py = abs(Y).^2; cyu = Y.*conj(U);
if state.spectral_count == 0
    state.Suu = pu; state.Syy = py; state.Syu = cyu;
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
den = 1-Tuse; small = abs(den) < 0.02;
den(small) = 0.02*exp(1i*angle(den(small)+eps));
Lhat = Tuse./den;
bcurve = movmedian(chordal(Lhat, cfg.cap), 3);
b_st = min(bcurve(cfg.keep));
if state.step_count <= cfg.warm_steps
    b_res = b_prior;
else
    qobs = state.Syy./cfg.shape;
    qobs = qobs/max(median(qobs(cfg.res_keep)), eps);
    loss = zeros(size(cfg.rho_grid));
    for k = 1:numel(cfg.rho_grid)
        qmod = abs((1+cfg.L0)./(1+a_now*cfg.rho_grid(k)*cfg.L0)).^2;
        qmod = qmod/max(median(qmod(cfg.res_keep)), eps);
        loss(k) = median(abs(log(max(qobs(cfg.res_keep), eps))-log(max(qmod(cfg.res_keep), eps))));
    end
    [~, kbest] = min(loss);
    w = confidence.^2; Lmodel = a_now*cfg.L0;
    rho_drive = real(sum(w.*conj(Lmodel).*Lhat))/max(sum(w.*abs(Lmodel).^2), eps);
    rho_target = 1+min(max(2*(rho_drive-1), 0), 1)*(cfg.rho_grid(kbest)-1);
    state.log_rho = state.log_rho + cfg.residual_alpha*(log(rho_target)-state.log_rho);
    b_res = min(movmedian(chordal(a_now*exp(state.log_rho)*cfg.L0, cfg.cap), 3).*cfg.keep + cfg.cap*(~cfg.keep));
end
res_weight = activity*(1-mean(leverage(cfg.res_keep)))^2;
b_raw = activity*(b_st-res_weight*max(b_st-b_res, 0))+(1-activity)*cfg.cap;
state.b = state.b + cfg.margin_alpha*(b_raw-state.b);
b = min(max(state.b, 0), cfg.cap);
info = makeInfo(b_st, b_res, b_raw, Tuse, Lhat, confidence, cfg, state);
info.residual_weight = res_weight;
full_curve = movmedian(chordal(min(1/a_now, 4)*Lhat, cfg.cap), 3);
info.full_margin = min(full_curve(cfg.keep));
end

function [a, info] = authStep(b, b_full, residual_weight, state, prm)
a0 = min(max(state.a, prm.a_min), prm.a_max);
b_ref = prm.target + prm.guard*(1+min(max(residual_weight, 0), 1));
e_raw = b-b_ref;
e = sign(e_raw)*max(abs(e_raw)-prm.deadband*(1+min(max(residual_weight, 0), 1)), 0);
headroom = 1/sqrt(2)-b_ref;
coherent = min(1, max(0, (0.60-residual_weight)/0.40));
full_safe = min(1, max(0, (b_full-prm.target)/prm.guard));
rate = prm.rate*sqrt(a0)*(1+coherent*full_safe*prm.up_boost*(max(e,0)/headroom)^2);
a_free = exp(min(max(log(a0)+rate*prm.dt_update*e, log(prm.a_min)), log(prm.a_max)));
a = a0 + min(max(a_free-a0, -prm.max_step), prm.max_step);
info = struct('a_target', a, 'margin_error', e_raw, 'regulated_error', e, 'rate', rate);
end

function prm = authParams(override)
prm = struct('target', 0.55, 'guard', 0.02, 'deadband', 0.008, ...
    'rate', 5.0, 'up_boost', 400.0, 'max_step', 0.15, ...
    'a_min', 0.08, 'a_max', 1.0, 'a_init', 1.0, 'dt_update', 0.125);
prm = applyOverride(prm, override, 'gpt5_6:UnknownAuthParameter');
end

function info = makeInfo(b_st, b_res, b_raw, T, L, confidence, cfg, state)
info = struct('b_st', b_st, 'b_res', b_res, 'b_raw', b_raw, ...
    'T_hat', T, 'L_hat', L(cfg.keep), 'confidence', mean(confidence(cfg.keep)), ...
    'residual_weight', 0, 'full_margin', cfg.nominal, ...
    'freq_hz', cfg.freq_hz, 'ready', state.step_count*cfg.step_s >= cfg.warm_s);
end

function cfg = applyOverride(cfg, override, error_id)
names = fieldnames(override);
for i = 1:numel(names)
    if ~isfield(cfg, names{i}), error(error_id, 'Unknown parameter: %s', names{i}), end
    cfg.(names{i}) = override.(names{i});
end
end

function value = fieldOr(s, name, default)
if isfield(s, name), value = s.(name); else, value = default; end
end

function value = optional(args, index, default)
if numel(args) >= index, value = args{index}; else, value = default; end
end

function b = chordal(L, cap)
b = min(real(abs(1+L)./sqrt(2*(1+abs(L).^2))), cap);
end
