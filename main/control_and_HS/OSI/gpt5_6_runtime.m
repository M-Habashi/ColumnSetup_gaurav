function [auth, b_osi, b_st, b_res, b_fast, trip_reason, valid, ...
    decision, g_armed] = gpt5_6_runtime(dd, dm, en, gpts, gptw, ...
    gptbins, gptrho, gptauth, ~, ~)
%GPT5_6_RUNTIME Time-sliced Simulink/Speedgoat GPT-5.6 implementation.
% Called at 2048 Hz with scalar displacement samples. Each 0.125 s update
% is spread over 32 ticks: window/FFT work occupies four separate ticks,
% spectral work two ticks, and the 25 residual-fit candidates one tick
% each. Outputs publish together at tick 32, well before the next update.

%#codegen
persistent c raw_u raw_y raw_pos samples_in sample_phase step_count ...
    spectral_count Suu Syy Syu log_rho b_state a_state phase W ...
    out_b out_st out_res out_auth out_valid out_dec

PUBLISH_PHASE = 32;
if isempty(raw_pos)
    c = unpackConfig(gpts, gptw, gptbins, gptrho);
    % Two window lengths keep the boundary snapshot intact while new
    % base-rate samples continue arriving during the scheduled pipeline.
    raw_u = zeros(2*c.segment_n, 1);
    raw_y = zeros(2*c.segment_n, 1);
    raw_pos = 0;
    samples_in = 0;
    sample_phase = 0;
    step_count = 0;
    spectral_count = 0;
    Suu = zeros(c.nf, 1);
    Syy = zeros(c.nf, 1);
    Syu = complex(zeros(c.nf, 1));
    log_rho = 0;
    b_state = c.cap;
    a_state = gptauth(9);
    phase = 0;
    W = initWork(c);
    out_b = c.cap;
    out_st = c.cap;
    out_res = c.cap;
    out_auth = gptauth(9);
    out_valid = 0;
    out_dec = 0;
end

pause_enable = en >= 2;
en_active = en;
if pause_enable, en_active = en - 2; end
if pause_enable
    raw_u(:) = 0;
    raw_y(:) = 0;
    raw_pos = 0;
    samples_in = 0;
    sample_phase = 0;
    phase = 0;
    auth = publishedAuth(en_active, out_auth, gptauth(9));
    [b_osi, b_st, b_res, b_fast, trip_reason, valid, decision, g_armed] = ...
        diagnostics(out_b, out_st, out_res, out_valid, out_dec);
    return
end

raw_pos = raw_pos + 1;
if raw_pos > 2*c.segment_n, raw_pos = 1; end
raw_u(raw_pos) = dd;
raw_y(raw_pos) = dm;
samples_in = min(samples_in + 1, c.segment_n);
sample_phase = sample_phase + 1;

if sample_phase >= c.step_n
    sample_phase = 0;
    step_count = step_count + 1;
    W.a_now = min(max(a_state, 0.02), 1);
    W.snap_pos = raw_pos;
    W.do_spectrum = samples_in >= c.segment_n;
    W.best_loss = Inf;
    W.best_rho = gptrho(1);
    W.b_st = W.b_prior;
    W.b_res = W.b_prior;
    W.b_full = c.nominal;
    W.res_weight = 0;
    phase = 1;
elseif phase > 0
    ph = phase;
    phase = phase + 1;
    if ph >= PUBLISH_PHASE, phase = 0; end

    if ph == 1
        [W.wu, mean_u2] = windowedTail(raw_u, W.snap_pos, c.window);
        W.activity = min(1, (sqrt(mean_u2)/c.quiet_rms)^4);
        W.Lprior = W.a_now*W.activity*c.L0;
        W.Tprior = W.Lprior./(1 + W.Lprior);
        W.b_prior = minMasked(chordal(W.Lprior, c.cap), c.keep);
        W.b_st = W.b_prior;
        W.b_res = W.b_prior;
    elseif ph == 2
        if W.do_spectrum
            U = fft(W.wu);
            W.U = U(c.bin);
        end
    elseif ph == 3
        if W.do_spectrum
            [W.wy, ~] = windowedTail(raw_y, W.snap_pos, c.window);
        end
    elseif ph == 4
        if W.do_spectrum
            Y = fft(W.wy);
            W.Y = Y(c.bin);
        end
    elseif ph == 5
        if W.do_spectrum
            pu = abs(W.U).^2;
            py = abs(W.Y).^2;
            cyu = W.Y.*conj(W.U);
            if spectral_count == 0
                Suu = pu; Syy = py; Syu = cyu;
            else
                Suu = Suu + c.spectral_alpha*(pu - Suu);
                Syy = Syy + c.spectral_alpha*(py - Syy);
                Syu = Syu + c.spectral_alpha*(cyu - Syu);
            end
            spectral_count = spectral_count + 1;
            W.p_rel = Suu/max(max(Suu), eps);
            W.leverage = W.p_rel./(W.p_rel + c.power_floor);
            gamma2 = min(1, abs(Syu).^2./max(Suu.*Syy, eps));
            W.confidence = W.activity*gamma2.*W.leverage;
            That = Syu./max(Suu, eps);
            Tuse = W.confidence.*That + (1 - W.confidence).*W.Tprior;
            den = 1 - Tuse;
            for i = 1:c.nf
                if abs(den(i)) < 0.02
                    den(i) = 0.02*exp(1i*angle(den(i) + eps));
                end
            end
            W.Lhat = Tuse./den;
            W.b_st = minMasked(movMedian3(chordal(W.Lhat, c.cap)), c.keep);
        end
    elseif ph == 6
        if W.do_spectrum && step_count > c.warm_steps
            W.qobs = Syy./c.shape;
            W.qobs = W.qobs/max(medianMasked(W.qobs, c.res_keep), eps);
        end
    elseif ph >= 7 && ph < 7 + c.nrho
        if W.do_spectrum && step_count > c.warm_steps
            k = ph - 6;
            qmod = abs((1 + c.L0)./(1 + W.a_now*gptrho(k)*c.L0)).^2;
            qmod = qmod/max(medianMasked(qmod, c.res_keep), eps);
            err = abs(log(max(W.qobs, eps)) - log(max(qmod, eps)));
            loss = medianMasked(err, c.res_keep);
            if loss < W.best_loss
                W.best_loss = loss;
                W.best_rho = gptrho(k);
            end
        end
    elseif ph == PUBLISH_PHASE
        if W.do_spectrum
            if step_count > c.warm_steps
                weights = W.confidence.^2;
                Lmodel = W.a_now*c.L0;
                rho_drive = real(sum(weights.*conj(Lmodel).*W.Lhat))/ ...
                    max(sum(weights.*abs(Lmodel).^2), eps);
                shape_weight = min(max(2*(rho_drive - 1), 0), 1);
                rho_target = 1 + shape_weight*(W.best_rho - 1);
                log_rho = log_rho + c.residual_alpha* ...
                    (log(rho_target) - log_rho);
                W.b_res = minMasked(movMedian3(chordal( ...
                    W.a_now*exp(log_rho)*c.L0, c.cap)), c.keep);
            end
            W.res_weight = W.activity* ...
                (1 - meanMasked(W.leverage, c.res_keep))^2;
            b_evid = W.b_st - W.res_weight*max(W.b_st - W.b_res, 0);
            b_raw = W.activity*b_evid + (1 - W.activity)*c.cap;
            full_curve = movMedian3(chordal(min(1/W.a_now, 4)*W.Lhat, c.cap));
            W.b_full = minMasked(full_curve, c.keep);
        else
            b_raw = W.b_prior;
        end
        b_state = min(max(b_state + c.margin_alpha*(b_raw - b_state), 0), c.cap);
        a_old = a_state;
        a_state = authorityStep(b_state, W.b_full, W.res_weight, a_state, gptauth);
        out_b = b_state;
        out_st = W.b_st;
        out_res = W.b_res;
        out_auth = a_state;
        out_valid = double(step_count >= c.warm_steps);
        out_dec = double(a_state > a_old) + 2*double(a_state < a_old);
    end
end

auth = publishedAuth(en_active, out_auth, gptauth(9));
[b_osi, b_st, b_res, b_fast, trip_reason, valid, decision, g_armed] = ...
    diagnostics(out_b, out_st, out_res, out_valid, out_dec);
end

function c = unpackConfig(s, w, bins, rho)
c = struct('dt', s(1), 'fs', s(2), 'step_n', round(s(3)), ...
    'segment_n', round(s(4)), 'spectral_alpha', s(5), ...
    'margin_alpha', s(6), 'residual_alpha', s(7), ...
    'power_floor', s(8), 'quiet_rms', s(9), 'cap', s(10), ...
    'warm_steps', round(s(11)), 'nf', round(s(12)), ...
    'nominal', s(13), 'nrho', round(s(14)), 'window', w, ...
    'bin', round(bins(:, 1)), 'keep', bins(:, 2) ~= 0, ...
    'res_keep', bins(:, 3) ~= 0, ...
    'L0', complex(bins(:, 4), bins(:, 5)), 'shape', bins(:, 6), ...
    'rho', rho);
end

function W = initWork(c)
W = struct('a_now', 1, 'activity', 0, 'Lprior', complex(zeros(c.nf, 1)), ...
    'Tprior', complex(zeros(c.nf, 1)), 'b_prior', c.cap, ...
    'do_spectrum', false, 'wu', zeros(c.segment_n, 1), ...
    'wy', zeros(c.segment_n, 1), 'U', complex(zeros(c.nf, 1)), ...
    'Y', complex(zeros(c.nf, 1)), 'p_rel', zeros(c.nf, 1), ...
    'leverage', zeros(c.nf, 1), 'confidence', zeros(c.nf, 1), ...
    'Lhat', complex(zeros(c.nf, 1)), 'qobs', zeros(c.nf, 1), ...
    'best_loss', Inf, 'best_rho', 1, 'snap_pos', 0, 'b_st', c.cap, ...
    'b_res', c.cap, 'b_full', c.nominal, 'res_weight', 0);
end

function [y, mean_square] = windowedTail(x, pos, w)
n = numel(w);
ring_n = numel(x);
y = zeros(n, 1);
sum_square = 0;
for i = 1:n
    j = pos - n + i;
    if j <= 0, j = j + ring_n; end
    value = x(j);
    y(i) = value*w(i);
    sum_square = sum_square + value*value;
end
mean_square = sum_square/n;
end

function y = chordal(L, cap)
y = min(real(abs(1 + L)./sqrt(2*(1 + abs(L).^2))), cap);
end

function y = movMedian3(x)
y = x;
n = numel(x);
for i = 2:n-1
    y(i) = median3(x(i-1), x(i), x(i+1));
end
if n > 1
    y(1) = (x(1) + x(2))/2;
    y(n) = (x(n-1) + x(n))/2;
end
end

function y = median3(a, b, c)
y = a + b + c - min(a, min(b, c)) - max(a, max(b, c));
end

function y = medianMasked(x, mask)
buf = inf(numel(x), 1);
n = 0;
for i = 1:numel(x)
    if mask(i)
        n = n + 1;
        buf(n) = x(i);
    end
end
buf = sort(buf);
h = floor(n/2);
if mod(n, 2) == 1
    y = buf(h + 1);
else
    y = (buf(h) + buf(h + 1))/2;
end
end

function y = minMasked(x, mask)
y = Inf;
for i = 1:numel(x)
    if mask(i) && x(i) < y, y = x(i); end
end
end

function y = meanMasked(x, mask)
y = 0;
n = 0;
for i = 1:numel(x)
    if mask(i), y = y + x(i); n = n + 1; end
end
y = y/max(n, 1);
end

function a = authorityStep(b, b_full, rw, a, p)
a0 = min(max(a, p(7)), p(8));
rw = min(max(rw, 0), 1);
b_ref = p(1) + p(2)*(1 + rw);
e_raw = b - b_ref;
e = sign(e_raw)*max(abs(e_raw) - p(3)*(1 + rw), 0);
headroom = 1/sqrt(2) - b_ref;
coherent = min(1, max(0, (0.60 - rw)/0.40));
full_safe = min(1, max(0, (b_full - p(1))/p(2)));
rate = p(4)*sqrt(a0)*(1 + coherent*full_safe*p(5)* ...
    (max(e, 0)/headroom)^2);
a_free = exp(min(max(log(a0) + rate*p(10)*e, log(p(7))), log(p(8))));
a = a0 + min(max(a_free - a0, -p(6)), p(6));
end

function a = publishedAuth(en, a_state, a_init)
if en ~= 0, a = a_state; else, a = a_init; end
end

function [b, bst, bres, bfast, trip, valid, decision, armed] = ...
    diagnostics(b, bst, bres, valid, decision)
bfast = NaN;
trip = 0;
armed = valid;
end
