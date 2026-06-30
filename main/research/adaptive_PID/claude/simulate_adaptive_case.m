function out = simulate_adaptive_case(c, method, ctx, cfg)
%SIMULATE_ADAPTIVE_CASE Closed-loop adaptive-PID run for one case + one method.
% Healthy->damaged JUMP at cfg.switch_s. The inner actuator loop is stepped sample
% by sample (the plant is strictly proper, D=0, so there is no algebraic loop). The
% controller is a fixed-structure PID (separate P/I/D branches) plus a one-pole
% low-pass and a band-pass-subtract notch; the METHOD only moves time-varying SCALAR
% gains (a, g_I, alpha, depth) on those fixed blocks, so every state is continuous as
% the controller adapts. Online M9.1 (canonical OSI m91_adaptive_margin, STEP mode)
% reads dd_lead/dm each window; margin_law moves the knob to hold the margin >= target.
%
% Healthy and damaged dynamics are both run as live states and cross-faded at the
% jump (state-continuous splice, same idea as make_damage_th).
%
% out fields: tc, m91 (online NCF estimate), true (analytic NCF of the live loop),
%   a, gI, fc, depth, binding (M9.1 binding freq), knob, dd_lead, dm, t, switch_s,
%   bnom, b_static_damaged, route.

dt = ctx.dt; fs = round(1/dt);
N  = round(cfg.dur_s*fs) + 1;
t  = (0:N-1).'/fs;
sw = cfg.switch_s;
is_base = strcmp(method.kind,'baseline');

% ---- shared excitation: broadband command + output disturbance + tiny sensor noise
rng(cfg.seed);
[bb,ab] = butter(4, cfg.cmd_band_hz/(fs/2), 'bandpass');
dd_lead = filter(bb,ab, randn(N,1));
dd_lead = dd_lead/std(dd_lead)*cfg.cmd_std_mm;
dist    = ctx.sigma*randn(N,1);
mnoise  = (cfg.meas_noise_fr*cfg.cmd_std_mm)*randn(N,1);

% ---- crossfade weight (0 healthy -> 1 damaged) at the jump --------------------
wc = double(t>=sw); rmp = abs(t-sw)<=cfg.crossfade_s/2;
wc(rmp) = 0.5*(1+sin(pi*(t(rmp)-sw)/cfg.crossfade_s));

% ---- controller branches: healthy (C0) and damaged (case) --------------------
bh = pid_branches(c.pidh, dt);          % healthy controller (nominal)
bd = pid_branches(c.pidd, dt);          % damaged-phase controller (case)

% ---- plants: healthy Hh (always) and damaged base c.H, + optional input delay -
[Ahh,Bhh,Chh] = ssdata(ss(ctx.Hh));
[Ahc,Bhc,Chc] = ssdata(ss(c.H));
Ldel = c.delay_samples;

% ---- analytic frequency grid + precomputed branch/plant FRFs (damaged) --------
fg = (2:0.5:120).'; wg = 2*pi*fg;
Pf = c.pidd(1) + 0*wg;                                  % P branch FRF (constant)
If = frf(bd.Ai,bd.Bi,bd.Ci,bd.Di,wg,dt);               % integral branch FRF
Df = frf(bd.Ad,bd.Bd,bd.Cd,bd.Dd,wg,dt);               % derivative branch FRF
Hcf = squeeze(freqresp(ss(c.H),wg)) .* exp(-1i*wg*dt*Ldel);   % damaged plant (+delay)
ncf_of = @(L) min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
bnom   = ncf_of(squeeze(freqresp(ctx.C0*ctx.Hh, wg)));  % healthy nominal margin
b_static_damaged = ncf_of((Pf+If+Df).*Hcf);             % damaged loop, no adaptation

% ---- M9.1 online (canonical OSI function, STEP mode) -------------------------
L0  = ctx.C0*ctx.Hh;
cfg9 = m91_adaptive_margin('config', dt, L0, cfg.m91);
st9  = m91_adaptive_margin('state',  cfg9);
win_n = cfg9.window_n;
hop_n = round(cfg9.window_hop_s*fs);

% ---- state ------------------------------------------------------------------
xHh = zeros(size(Ahh,1),1);  xHc = zeros(size(Ahc,1),1);
xIh = zeros(size(bh.Ai,1),1); xDh = zeros(size(bh.Ad,1),1);
xIc = zeros(size(bd.Ai,1),1); xDc = zeros(size(bd.Ad,1),1);
xLP = 0; zb1 = 0; zb2 = 0;                              % low-pass + notch band-pass states
dbuf = zeros(max(Ldel,1),1); dptr = 1;                 % delay line for damaged plant input
dm_log = zeros(N,1);

% actuation (held constant within a hop) and latch ----------------------------
g = nominal_g();
knob = 0;
lat = struct('armed',false,'act',false,'route','none','f_notch',NaN, ...
             'bpb',[1 0 0],'bpa',[1 0 0]);
bpb = lat.bpb; bpa = lat.bpa;

% series storage --------------------------------------------------------------
hop_samples = win_n:hop_n:N;
nH = numel(hop_samples);
S = struct('tc',nan(nH,1),'m91',nan(nH,1),'true',nan(nH,1),'a',nan(nH,1), ...
   'gI',nan(nH,1),'fc',nan(nH,1),'depth',nan(nH,1),'binding',nan(nH,1),'knob',nan(nH,1));
hk = 0;
next_hop = win_n;

lawcfg = cfg; lawcfg.knob_max = method.knob_max;
if strcmp(method.kind,'schedule'), lawcfg.knob_max = 1; end   % schedule dwells before fallback
dwell_cnt = 0;

% ---- main sample loop -------------------------------------------------------
for n = 1:N
    w = wc(n);
    dm = (1-w)*(Chh*xHh) + w*(Chc*xHc) + dist(n) + mnoise(n);
    dm_log(n) = dm;
    e = dd_lead(n) - dm;

    % healthy controller (nominal gains)
    uIh = bh.Ci*xIh + bh.Di*e;  uDh = bh.Cd*xDh + bh.Dd*e;
    pid_h = bh.P*e + uIh + uDh;
    % damaged controller (method branch gains)
    uIc = bd.Ci*xIc + bd.Di*e;  uDc = bd.Cd*xDc + bd.Dd*e;
    pid_c = g.gP*(bd.P*e) + g.gI*uIc + g.gD*uDc;
    pid_out = (1-w)*pid_h + w*pid_c;

    % one-pole low-pass (alpha=1 => identity, transparent to the other methods)
    xLP = xLP + g.alpha*(pid_out - xLP);
    lp = xLP;
    % notch = lp - depth*bandpass(lp)   (depth=0 => identity)
    if g.depth ~= 0
        y = bpb(1)*lp + zb1;
        zb1 = bpb(2)*lp - bpa(2)*y + zb2;
        zb2 = bpb(3)*lp - bpa(3)*y;
        notch = lp - g.depth*y;
    else
        notch = lp;
    end
    dc = g.a * notch;

    % plant updates (both live); damaged input may be delayed (C5)
    xHh = Ahh*xHh + Bhh*dc;
    if Ldel > 0
        dc_d = dbuf(dptr); dbuf(dptr) = dc; dptr = dptr+1; if dptr>Ldel, dptr=1; end
    else
        dc_d = dc;
    end
    xHc = Ahc*xHc + Bhc*dc_d;
    % controller state updates
    xIh = bh.Ai*xIh + bh.Bi*e;  xDh = bh.Ad*xDh + bh.Bd*e;
    xIc = bd.Ai*xIc + bd.Bi*e;  xDc = bd.Ad*xDc + bd.Bd*e;

    % ---- online M9.1 + adaptation at each window hop --------------------------
    if n == next_hop
        idx = n-win_n+1:n;
        [margin, st9, info] = m91_adaptive_margin(dd_lead(idx), dm_log(idx), cfg9, st9);
        fst = info.f_st_hz;                       % phase-aware S,T binding -- RELIABLE, or NaN
        binding = fst;                            % (NaN here means the dangerous mode is not
        if ~isfinite(binding), binding = info.f_residual_hz; end   % frequency-observable)

        % latch route / notch placement at the first fully-damaged alarm
        if ~is_base && ~lat.armed && t(n) > sw + cfg9.window_s && isfinite(margin) ...
                && margin < cfg.b_target
            lat.armed = true;
            % Gate/route on the RELIABLE S,T binding fst. When fst is NaN the dangerous
            % mode is not frequency-observable (e.g. C5's 2.5 Hz delay dip at the band
            % edge), so the safe action is uniform authority -- never a targeted one.
            obs = isfinite(fst);
            switch method.kind
                case 'integral',  lat.act = obs && fst <  cfg.f_split_hz;   % confirmed low-band
                case 'lowpass',   lat.act = obs && fst >= cfg.f_split_hz;    % confirmed high-band
                case 'schedule'
                    if obs && fst >= cfg.f_low_obs_hz && fst < cfg.f_split_hz
                        lat.route = 'integral';     % observable mid-low resonance (C4)
                    else
                        lat.route = 'auth';         % high-band gain, or unobservable (C5) -> authority
                    end
                    lat.act = true;
                case 'auth_notch'
                    lat.act = true;
                    if obs                          % place the notch only at a real resonance
                        lat.f_notch = max(2.5,min(110,fst));
                        f1 = max(1.5, lat.f_notch*(1-cfg.notch_halfbw));
                        f2 = min(118, lat.f_notch*(1+cfg.notch_halfbw));
                        [bpb,bpa] = butter(1,[f1 f2]/(fs/2),'bandpass');
                        lat.bpb = bpb; lat.bpa = bpa;
                    else
                        lat.f_notch = NaN;          % no observable mode -> pure authority ladder
                    end
                otherwise, lat.act = true;     % authority: always
            end
        end

        % schedule method: dwell at the integral cap before enabling the authority fallback,
        % so a slow-but-working integral response (e.g. C4) is not over-ridden prematurely
        if strcmp(method.kind,'schedule')
            if lat.armed && isfinite(margin) && margin < cfg.b_target && knob >= 0.98
                dwell_cnt = dwell_cnt + 1;
            end
            if dwell_cnt >= cfg.fallback_dwell, lawcfg.knob_max = 2; else, lawcfg.knob_max = 1; end
        end

        % update knob (skip baseline)
        if ~is_base
            knob = margin_law(knob, margin, lawcfg);
            g = actuate(method.kind, knob, lat, cfg, dt);
        end

        % analytic NCF of the CURRENT live loop (healthy pre-jump, damaged after)
        if w < 0.5
            true_ncf = bnom;
        else
            BPf = ones(size(wg));
            if isfinite(lat.f_notch), BPf = frf_tf(lat.bpb,lat.bpa,wg,dt); end
            LPf = g.alpha ./ (1-(1-g.alpha)*exp(-1i*wg*dt));
            Cm  = g.gP*Pf + g.gI*If + g.gD*Df;
            Leff = g.a * (LPf .* (1 - g.depth*BPf)) .* Cm .* Hcf;
            true_ncf = ncf_of(Leff);
        end

        hk = hk+1;
        S.tc(hk)=t(n); S.m91(hk)=margin; S.true(hk)=true_ncf;
        S.a(hk)=g.a; S.gI(hk)=g.gI; S.depth(hk)=g.depth; S.binding(hk)=binding;
        S.fc(hk)=alpha_to_fc(g.alpha,dt); S.knob(hk)=knob;

        next_hop = next_hop + hop_n;
        if next_hop > N, next_hop = N + 1; end
    end
end

out = S;
out.t = t; out.dd_lead = dd_lead; out.dm = dm_log;
out.switch_s = sw; out.bnom = bnom; out.b_static_damaged = b_static_damaged;
out.route = lat.route; out.f_notch = lat.f_notch; out.id = c.id; out.method = method.id;

% ===================== local helpers =========================================
    function g = nominal_g()
        g = struct('gP',1,'gI',1,'gD',1,'alpha',1,'depth',0,'a',1);
    end
end

% ---- module-level helpers (shared) ------------------------------------------
function g = actuate(kind, knob, lat, cfg, dt) %#ok<INUSD>
g = struct('gP',1,'gI',1,'gD',1,'alpha',1,'depth',0,'a',1);
switch kind
    case 'authority'
        g.a = 1 - knob*(1-cfg.a_min);
    case 'integral'
        if lat.armed && lat.act, g.gI = 1 - knob*(1-cfg.gI_min); end
    case 'lowpass'
        if lat.armed && lat.act, g.alpha = 1 - knob*(1-cfg.alpha_min); end
    case 'schedule'
        % knob 0..1 drives the scheduled targeted knob; knob 1..2 adds authority
        % fallback (used only when the targeted knob did not move M9.1 to target).
        kA = min(knob,1); kB = max(knob-1,0);
        if lat.armed && strcmp(lat.route,'integral')
            g.gI = 1 - (1-cfg.gI_min)*kA*(1-kB);  % detune in stage A, RESTORE in fallback
            g.a  = 1 - kB*(1-cfg.a_min);          % authority fallback when integral is unobservable
        elseif lat.armed
            g.a  = 1 - kA*(1-cfg.a_min);
        end
    case 'auth_notch'
        if lat.armed && isfinite(lat.f_notch)
            kn = min(knob,1); ka = max(knob-1,0);   % notch-first (0..1) then authority (1..2)
            g.depth = kn*cfg.depth_max;
            g.a = 1 - ka*(1-cfg.a_min);
        else                                        % no observable resonance: pure authority
            g.a = 1 - min(knob/2,1)*(1-cfg.a_min);  % spread authority over the full 0..2 knob
        end
end
end

function br = pid_branches(p, dt)
% Decompose a [P I D N] PID into separate forward-Euler branch state-spaces.
P=p(1); I=p(2); D=p(3); Nf=p(4);
mk = @(pp,ii,dd) ss(pid(pp,ii,dd,1/Nf,dt,'IFormula','ForwardEuler','DFormula','ForwardEuler'));
[br.Ai,br.Bi,br.Ci,br.Di] = ssdata(mk(0,I,0));
[br.Ad,br.Bd,br.Cd,br.Dd] = ssdata(mk(0,0,D));
br.P = P;
end

function H = frf(A,B,C,D,wg,dt)
% FRF of a (small) discrete state-space at radian freqs wg.
H = zeros(numel(wg),1); z = exp(1i*wg*dt); n = size(A,1);
if n==0, H = D*ones(numel(wg),1); return; end
I = eye(n);
for k=1:numel(wg)
    H(k) = C*((z(k)*I - A)\B) + D;
end
end

function H = frf_tf(b,a,wg,dt)
z = exp(1i*wg*dt);
num = b(1) + b(2)*z.^-1 + b(3)*z.^-2;
den = a(1) + a(2)*z.^-1 + a(3)*z.^-2;
H = num./den;
end

function fc = alpha_to_fc(alpha, dt)
% Equivalent -3 dB cutoff of the one-pole y+=alpha*(u-y); alpha=1 -> "off".
if alpha >= 0.999, fc = NaN; else, fc = -log(1-alpha)/(2*pi*dt); end
end
