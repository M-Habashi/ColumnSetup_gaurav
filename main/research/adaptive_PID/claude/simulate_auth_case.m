function out = simulate_auth_case(c, ctx, cfg, adapt)
%SIMULATE_AUTH_CASE Closed-loop test of the canonical auth_stability_gain law for one case.
% Healthy->damaged JUMP at cfg.switch_s. The inner actuator loop is stepped sample by
% sample (the plant is strictly proper, D=0, so there is no algebraic loop). The
% controller is a fixed-structure PID (separate P/I/D branches). The ONLY adaptation is a
% single authority scalar a in [a_min, a_max] applied after the PID (dc = a*pid_out):
%   * adapt = true  -> a is driven by the canonical codegen law auth_stability_gain, fed by
%                      the online OSI margin m91_adaptive_margin (STEP mode), updated every
%                      cfg.update_interval_s seconds.
%   * adapt = false -> a is frozen at a_max (the no-adaptation baseline).
%
% Healthy and damaged dynamics are both run as live states and cross-faded at the jump
% (state-continuous splice, same idea as the other adaptive-PID simulators).
%
% out fields: tc, m91 (online NCF estimate), true (analytic NCF of the live loop), a
%   (authority), binding (M9.1 binding freq), down (auth law's down_confirmed flag),
%   t, dd_lead, dm, switch_s, bnom, b_static_damaged, update_interval_s, id, adapt.

dt = ctx.dt; fs = round(1/dt);
N  = round(cfg.dur_s*fs) + 1;
t  = (0:N-1).'/fs;
sw = cfg.switch_s;

% ---- shared excitation: broadband command + output disturbance + tiny sensor noise --
rng(cfg.seed);
[bb,ab] = butter(4, cfg.cmd_band_hz/(fs/2), 'bandpass');
dd_lead = filter(bb,ab, randn(N,1));
dd_lead = dd_lead/std(dd_lead)*cfg.cmd_std_mm;
dist    = ctx.sigma*randn(N,1);
mnoise  = (cfg.meas_noise_fr*cfg.cmd_std_mm)*randn(N,1);

% ---- crossfade weight (0 healthy -> 1 damaged) at the jump --------------------------
wc = double(t>=sw); rmp = abs(t-sw)<=cfg.crossfade_s/2;
wc(rmp) = 0.5*(1+sin(pi*(t(rmp)-sw)/cfg.crossfade_s));

% ---- controller branches: healthy (C0) and damaged (case) --------------------------
bh = pid_branches(c.pidh, dt);          % healthy controller (nominal)
bd = pid_branches(c.pidd, dt);          % damaged-phase controller (case)

% ---- plants: healthy Hh (always) and damaged base c.H, + optional input delay -------
[Ahh,Bhh,Chh] = ssdata(ss(ctx.Hh));
[Ahc,Bhc,Chc] = ssdata(ss(c.H));
Ldel = c.delay_samples;

% ---- analytic frequency grid + precomputed branch/plant FRFs (damaged) --------------
fg = (2:0.5:120).'; wg = 2*pi*fg;
Pf  = c.pidd(1) + 0*wg;                                 % P branch FRF (constant)
If  = frf(bd.Ai,bd.Bi,bd.Ci,bd.Di,wg,dt);              % integral branch FRF
Df  = frf(bd.Ad,bd.Bd,bd.Cd,bd.Dd,wg,dt);              % derivative branch FRF
Hcf = squeeze(freqresp(ss(c.H),wg)) .* exp(-1i*wg*dt*Ldel);   % damaged plant (+delay)
ncf_of = @(L) min(abs(1+L)./sqrt(2*(1+abs(L).^2)));
bnom   = ncf_of(squeeze(freqresp(ctx.C0*ctx.Hh, wg)));  % healthy nominal margin
b_static_damaged = ncf_of((Pf+If+Df).*Hcf);             % damaged loop, no adaptation

% ---- M9.1 online (canonical OSI function, STEP mode) at update_interval_s ------------
L0   = ctx.C0*ctx.Hh;
m91_over = cfg.m91; m91_over.update_interval_s = cfg.update_interval_s;
cfg9 = m91_adaptive_margin('config', dt, L0, m91_over);
st9  = m91_adaptive_margin('state',  cfg9);
win_n = cfg9.window_n;
hop_n = cfg9.update_interval_n;                          % caller hop = OSI update interval

% ---- state --------------------------------------------------------------------------
xHh = zeros(size(Ahh,1),1);  xHc = zeros(size(Ahc,1),1);
xIh = zeros(size(bh.Ai,1),1); xDh = zeros(size(bh.Ad,1),1);
xIc = zeros(size(bd.Ai,1),1); xDc = zeros(size(bd.Ad,1),1);
dbuf = zeros(max(Ldel,1),1); dptr = 1;                  % delay line for damaged plant input
dm_log = zeros(N,1);

% ---- authority + auth_stability_gain state (initial values per its docstring) -------
L = cfg.law;
authority = L.a_max;                                    % nominal authority
mfilt  = L.target_margin;                               % margin_filtered  init
mguard = L.target_margin;                               % margin_guarded   init
above_c = 0; below_c = 0;

% ---- series storage -----------------------------------------------------------------
hop_samples = win_n:hop_n:N;
nH = numel(hop_samples);
S = struct('tc',nan(nH,1),'m91',nan(nH,1),'true',nan(nH,1),'a',nan(nH,1), ...
   'binding',nan(nH,1),'down',nan(nH,1));
hk = 0;
next_hop = win_n;

% ---- main sample loop ---------------------------------------------------------------
for n = 1:N
    w = wc(n);
    dm = (1-w)*(Chh*xHh) + w*(Chc*xHc) + dist(n) + mnoise(n);
    dm_log(n) = dm;
    e = dd_lead(n) - dm;

    % healthy controller (nominal) and damaged-phase controller, blended by the crossfade
    uIh = bh.Ci*xIh + bh.Di*e;  uDh = bh.Cd*xDh + bh.Dd*e;
    pid_h = bh.P*e + uIh + uDh;
    uIc = bd.Ci*xIc + bd.Di*e;  uDc = bd.Cd*xDc + bd.Dd*e;
    pid_c = bd.P*e + uIc + uDc;
    pid_out = (1-w)*pid_h + w*pid_c;

    dc = authority * pid_out;                           % the ONLY adaptation knob

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

    % ---- online M9.1 + authority update at each OSI update hop -----------------------
    if n == next_hop
        idx = n-win_n+1:n;
        [margin, st9, info] = m91_adaptive_margin(dd_lead(idx), dm_log(idx), cfg9, st9);
        binding = info.f_st_hz;                          % phase-aware S,T binding (or NaN)
        if ~isfinite(binding), binding = info.f_residual_hz; end

        down_conf = 0;
        if adapt
            % canonical codegen-safe law: one margin sample -> next authority + states
            [authority, mfilt, mguard, above_c, below_c, down_conf] = auth_stability_gain( ...
                margin, authority, mfilt, mguard, above_c, below_c, ...
                L.target_margin, L.update_interval_s, L.a_min, L.a_max, ...
                L.down_deadband, L.down_rate, L.down_immediate_margin, L.down_confirm_n, ...
                L.up_deadband, L.power_law, L.smooth_down, L.up_rate, L.up_hold_s, ...
                L.margin_guard_up_rate, L.margin_guard_down_rate, L.margin_filter_alpha);
        end

        % analytic NCF of the CURRENT live loop (healthy pre-jump, damaged after)
        if w < 0.5
            true_ncf = bnom;
        else
            Leff = authority * (Pf + If + Df) .* Hcf;
            true_ncf = ncf_of(Leff);
        end

        hk = hk+1;
        S.tc(hk)=t(n); S.m91(hk)=margin; S.true(hk)=true_ncf;
        S.a(hk)=authority; S.binding(hk)=binding; S.down(hk)=down_conf;

        next_hop = next_hop + hop_n;
        if next_hop > N, next_hop = N + 1; end
    end
end

out = S;
out.t = t; out.dd_lead = dd_lead; out.dm = dm_log;
out.switch_s = sw; out.bnom = bnom; out.b_static_damaged = b_static_damaged;
out.update_interval_s = cfg9.update_interval_actual_s;
out.id = c.id; out.adapt = adapt;
end

% ===================== local helpers =================================================
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
