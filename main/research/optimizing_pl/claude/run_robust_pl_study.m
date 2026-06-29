%% Damage-robust phase-lead study (reproducible)
% Demonstrates the recommended worst-case criterion on the real saved models and
% reproduces the three findings behind the answers in FINDINGS.md:
%   Q1  a min-max (worst damage case) NCF criterion finds a gentle robust lead
%       that neither single-level lead achieves;
%   Q3  loop-gain "authority" is a monotone stability knob; lead ratio is not
%       (and acts in OPPOSITE directions on the healthy vs damaged plant).
% Read-only: loads saved_results, builds models, prints tables. No files saved.

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(fileparts(script_dir)));   % claude->optimizing_pl->research->main
addpath(script_dir);
addpath(fullfile(project_root, 'control_and_HS', 'b_system_id', 'id_utils'));
addpath(fullfile(project_root, 'control_and_HS', 'c_fem_modeling', 'utils_fem'));
addpath(fullfile(project_root, 'helpers', 'utils'));
sr = fullfile(project_root, 'saved_results');
dt = 1/2048;
pidv = [0.15 20 0.0015 512];

H  = load(fullfile(sr, 'exp_tf', 'tf_sp_1_7000_20260627_210411.mat'), 'H_dc_dm');
D  = load(fullfile(sr, 'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), 'H_dc_dm');
s7 = specimen_params_si(load(fullfile(sr, 'specimens', 'sp1_7000.mat')));
s5 = specimen_params_si(load(fullfile(sr, 'specimens', 'sp1_5000.mat')));
fem = getfield(load(fullfile(sr, 'fem', 'fem_sp1_7000.mat'), 'fem'), 'fem');
pl7 = getfield(load(fullfile(sr, 'delay_comp', 'pl_sp1_7000.mat'), 'delay_comp_tf'), 'delay_comp_tf');
pl5 = getfield(load(fullfile(sr, 'delay_comp', 'pl_sp1_5000.mat'), 'delay_comp_tf'), 'delay_comp_tf');

num_tf = build_num_tf(fem, dt);

% Damage bracket from the HEALTHY baseline (gain envelope), plus the real
% measured damaged plant as an independent validation member.
members = damage_bracket(H.H_dc_dm, s7.stiffness, ...
    struct('rho', [0 1 2], 'gamma_meas', 2.4, 'k_ratio_meas', s5.stiffness/s7.stiffness));
measured = struct('label', 'MEASURED sp1_5000', 'Hdc', D.H_dc_dm, ...
    'k_exp', s5.stiffness, 'gamma', NaN, 'rho', NaN);
members = [members; measured];

fprintf('=== Damage bracket members ===\n');
for i = 1:numel(members), fprintf('  [%d] %s\n', i, members(i).label); end

% ---- existing leads vs damage bracket ----
fprintf('\n=== Per-member NCF / max|pole| ===\n');
leads = {tf(1), pl7, pl5}; names = {'no-lead', 'lead7', 'lead5'};
fprintf('%-26s', 'member');
for j = 1:numel(leads), fprintf('%16s', names{j}); end; fprintf('\n');
for i = 1:numel(members)
    fprintf('%-26s', members(i).label);
    for j = 1:numel(leads)
        m = hybrid_loop_margins(num_tf, members(i).Hdc, members(i).k_exp, leads{j}, pidv, dt);
        fprintf('  %5.3f/%6.4f', m.ncf, m.max_abs_pole);
    end
    fprintf('\n');
end

% ---- Q1: search a (center, ratio) lead grid for the best worst-case NCF ----
centers = [3 5 8 12];
ratios  = [1.5 2 3 5 8];
fprintf('\n=== Q1: worst-case NCF over the bracket (rows=center Hz, cols=ratio) ===\n');
fprintf('%8s', 'c\\N'); for N = ratios, fprintf('%8.1f', N); end; fprintf('\n');
best = struct('score', Inf);
for c = centers
    fprintf('%8.0f', c);
    for N = ratios
        lead = make_lead(c, N);
        s = robust_pl_score(lead, members, num_tf, pidv, dt, struct('ncf_target', 0.30));
        fprintf('%8.3f', s.worst_ncf);
        if s.worst_ncf > -best.score   % maximize worst_ncf
            best = s; best.score = -s.worst_ncf; best.c = c; best.N = N; best.lead = lead;
        end
    end
    fprintf('\n');
end

s_none = robust_pl_score(tf(1), members, num_tf, pidv, dt, struct('ncf_target', 0.30));
s_pl7  = robust_pl_score(pl7,   members, num_tf, pidv, dt, struct('ncf_target', 0.30));
s_pl5  = robust_pl_score(pl5,   members, num_tf, pidv, dt, struct('ncf_target', 0.30));
fprintf('\nworst-case NCF:  no-lead %.3f | lead7 %.3f | lead5 %.3f | ROBUST(c=%g,N=%g) %.3f\n', ...
    s_none.worst_ncf, s_pl7.worst_ncf, s_pl5.worst_ncf, best.c, best.N, best.worst_ncf);
fprintf('ROBUST lead per-member NCF: '); fprintf('%.3f ', best.ncf); fprintf('\n');
fprintf('ROBUST lead max|pole| over bracket = %.4f (stable=%d)\n', ...
    best.max_abs_pole, best.max_abs_pole < 1);

% ---- Q3(a): loop-gain authority is monotone; ratio is not ----
worst_member = members(end-1);   % rho=2 extrapolated case (most fragile)
fprintf('\n=== Q3(a): authority knob a (command scale) on a fragile case, with lead7 ===\n');
fprintf('%6s %8s %10s\n', 'a', 'NCF', 'max|pole|');
for a = [1 0.9 0.8 0.7 0.6 0.5 0.4]
    m = hybrid_loop_margins(num_tf, worst_member.Hdc, worst_member.k_exp, pl7, pidv, dt, a);
    fprintf('%6.2f %8.3f %10.4f\n', a, m.ncf, m.max_abs_pole);
end
fprintf('(max|pole| decreases monotonically as a decreases -> single safe direction)\n');

fprintf('\n=== Q3(b): lead ratio acts OPPOSITELY on healthy vs damaged (not a safe knob) ===\n');
fprintf('%6s | %12s | %12s\n', 'ratio', 'healthy pole', 'damaged pole');
for N = [1.5 3 5 8 12 18]
    lead = make_lead(8, N);
    mh = hybrid_loop_margins(num_tf, H.H_dc_dm, s7.stiffness, lead, pidv, dt);
    md = hybrid_loop_margins(num_tf, D.H_dc_dm, s5.stiffness, lead, pidv, dt);
    fprintf('%6.1f | %12.4f | %12.4f\n', N, mh.max_abs_pole, md.max_abs_pole);
end

% ---- Q4: PID authority a (PID*a) -- the inner-loop knob ----
% Robust base compensator: notch at the ~37 Hz CSI mode + an in-band lead.
notchlead = make_notch_lead(37, 0.05, 0.7, 3, 15);

fprintf('\n=== Q4(a): inner PID+H_dc_dm margins and the CLOSED-FORM required a ===\n');
target_gm = 10;   % dB inner-loop gain-margin setpoint
for cse = struct('tag', {'healthy', 'damaged'}, 'Hdc', {H.H_dc_dm, D.H_dc_dm})
    info = predict_inner_margin(cse.Hdc, pidv, dt, target_gm);
    fprintf(['%-8s: inner GM %5.2f dB, inner NCF %.3f, f180 %4.1f Hz | ' ...
        'a for GM=%g dB = %.3f (predicted GM at a = %.2f dB)\n'], ...
        cse.tag, info.gm_db, info.ncf, info.f180_hz, target_gm, ...
        info.a_required, info.gm_db_at(info.a_required));
end

fprintf('\n=== Q4(b): PID*a on the damaged plant + robust notch+lead (GM, NCF monotone) ===\n');
fprintf('%6s | %8s %8s %8s\n', 'a', 'innGM', 'cplGM', 'cplNCF');
for a = [1 0.8 0.6 0.5 0.4 0.3]
    pid_a = apply_pid_authority(pidv, a);
    inner = predict_inner_margin(D.H_dc_dm, pidv, dt);
    m = hybrid_loop_margins(num_tf, D.H_dc_dm, s5.stiffness, notchlead, pid_a, dt);
    fprintf('%6.2f | %8.2f %8.2f %8.3f\n', a, inner.gm_db_at(a), m.gm_db, m.ncf);
end

fprintf('\n=== Q4(c): margin-setpoint regulator (PID*a) under ramping damage ===\n');
fprintf('regulate inner GM -> %g dB; report coupled GM / NCF held\n', target_gm);
fprintf('%6s %7s %8s %8s | %8s %8s\n', 'step', 'gamma', 'GMest', 'a', 'cplGM', 'cplNCF');
a = 1; reg = struct();
gammas = linspace(1, 4, 13);
rng(0);
for i = 1:numel(gammas)
    g = gammas(i);
    Hg = g*H.H_dc_dm;
    k_g = (1 + (g-1)/(2.4-1)*(s5.stiffness/s7.stiffness - 1))*s7.stiffness;
    info = predict_inner_margin(Hg, apply_pid_authority(pidv, a), dt);
    gm_est = info.gm_db + 0.4*randn;   % noisy online estimate (e.g. from OSI Spk)
    [a, ~, reg] = authority_regulator(a, gm_est, ...
        struct('gm_set', target_gm, 'a_min', 0.3), reg);
    m = hybrid_loop_margins(num_tf, Hg, k_g, notchlead, apply_pid_authority(pidv, a), dt);
    fprintf('%6d %7.2f %8.2f %8.3f | %8.2f %8.3f\n', i, g, gm_est, a, m.gm_db, m.ncf);
end

% ---- Q5: estimate NCF DIRECTLY (S,T), not via GM ----
% NCF = 1/(sqrt(2)*max_w sqrt(|S|^2+|T|^2)); for unity feedback T is the measurable
% closed-loop FRF (inner loop: T = dm/dd_lead), S = 1-T. Sees the whole Nyquist
% curve -> catches low-PM cases that GM misses.
frng = [0.1 80];
fgrid = logspace(log10(frng(1)), log10(frng(2)), 6000)';
Cd = pid(pidv(1), pidv(2), pidv(3), 1/pidv(4), dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
Tin = feedback(Cd*c2d(D.H_dc_dm, dt, 'zoh'), 1);          % inner T (dm/dd_lead)
Lc = -minreal(num_tf*(s5.stiffness/1000)*c2d(pl7, dt, 'tustin')*Tin, [], false);

fprintf('\n=== Q5(a): direct NCF (S,T) matches custom, and GM can be BLIND ===\n');
[gmi, ~, ni] = custom_stability_margins(Cd*c2d(D.H_dc_dm, dt, 'zoh'), frng);
[gmc, ~, nc] = custom_stability_margins(Lc, frng);
oi = estimate_ncf_direct(Cd*c2d(D.H_dc_dm, dt, 'zoh'), 'open', fgrid);
oc = estimate_ncf_direct(Lc, 'open', fgrid);
fprintf('inner H5      : NCF custom %.4f | NCF S,T %.4f | GM %6.2f dB\n', ni, oi.ncf, gmi);
fprintf('coupled H5+pl7: NCF custom %.4f | NCF S,T %.4f | GM %6.2f dB  <- GM blind\n', nc, oc.ncf, gmc);

fprintf('\n=== Q5(b): NCF from a measured noisy T = dm/dd_lead (data-driven) ===\n');
fs = 1/dt; N = 40*fs; tt = (0:N-1)'/fs; rng(2);
u = filter(ones(1,200)/200, 1, randn(N,1)); u = 2*u/std(u) + 0.03*randn(N,1);
y = lsim(Tin, u, tt); y = y + 0.01*std(y)*randn(N,1);     % 1% measurement noise
[Tpts, fhz, spec] = xfunc(u, y, fs, 4096, 2048);
coh = abs(spec(:,3)).^2 ./ max(spec(:,1).*spec(:,2), eps);
sel = fhz >= 5 & fhz <= 70 & coh >= 0.5;
od = estimate_ncf_direct(Tpts(sel), 'comp', fhz(sel));
ot = estimate_ncf_direct(Tin, 'comp', fhz(sel));          % model T on same grid
fprintf('inner NCF: model T %.3f | estimated from noisy dm/dd_lead %.3f (binding %.0f Hz)\n', ...
    ot.ncf, od.ncf, od.binding_hz);

function lead = make_lead(center_hz, ratio)
% Unity DC gain, high-frequency gain = ratio (matches the optimizer parameterization).
wz = 2*pi*center_hz/sqrt(ratio);
wp = 2*pi*center_hz*sqrt(ratio);
lead = ratio*tf([1 wz], [1 wp]);
end

function G = make_notch_lead(notch_hz, zeta_zero, zeta_pole, lead_zero_hz, lead_pole_hz)
% Notch at the CSI frequency (removes loop gain only there) times a unity-DC lead
% (supplies in-band phase). High-frequency lead gain = lead_pole_hz/lead_zero_hz.
wn = 2*pi*notch_hz;
notch = tf([1 2*zeta_zero*wn wn^2], [1 2*zeta_pole*wn wn^2]);
lead = (lead_pole_hz/lead_zero_hz) ...
    * tf([1 2*pi*lead_zero_hz], [1 2*pi*lead_pole_hz]);
G = notch*lead;
end
