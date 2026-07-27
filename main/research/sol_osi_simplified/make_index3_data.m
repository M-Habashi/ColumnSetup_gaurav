function make_index3_data
%MAKE_INDEX3_DATA Generate SOL-OSI traces for the docs/Sol_osi/index3 page.
%
% Gradual 7k -> 5k softening (the fabby-suite gradual_softening scenario),
% run through the CLOSED inner loop with the canonical sol_osi estimator.
% Two excitation bands (high / low) x two authority modes (monitor-only /
% adaptive) -> four cases.  Writes docs/Sol_osi/index3_data.json.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(here, '-begin');
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin');

%% ---- models (identical setup to fable_synthetic_suite) --------------------
dt = 1/2048;
E7 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
E5 = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E5.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H7 = ss(c2d(E7.H_dc_dm, dt, 'zoh'));
H5 = ss(c2d(E5.H_dc_dm, dt, 'zoh'));
fgrid = (1:100)';
L7 = squeeze(freqresp(C*H7, 2*pi*fgrid));
L5 = squeeze(freqresp(C*H5, 2*pi*fgrid));
nominal_tf = C*H7;

target   = 0.55;
noise_std = 0.05;
cmd_rms   = 0.15;

% gradual softening: healthy (7k) until 60 s, linear blend to damaged (5k)
% by 100 s (these two marks become the vertical dashed lines on the page).
dur_s = 120;
lam_t = [60 100];
lam_v = [0 1];

% high band brackets the damage-sensitive resonance (coherent branch sees
% the shift); low band sits below it (damage invisible to the command band,
% the residual/quiet-band evidence must catch it).
bands = struct('high', [20 60], 'low', [2 10]);

specs = { ...
    'high_monitor', bands.high, false; ...
    'low_monitor',  bands.low,  false; ...
    'high_adapt',   bands.high, true;  ...
    'low_adapt',    bands.low,  true};

data = struct();
data.meta = struct('target', target, 'lam_t', lam_t, 'dur_s', dur_s, ...
    'dt', dt, 'b7', min(chordalv(L7)), 'b5', min(chordalv(L5)), ...
    'band_high', bands.high, 'band_low', bands.low);

for c = 1:size(specs, 1)
    name = specs{c, 1};
    band = specs{c, 2};
    adapt = specs{c, 3};
    fprintf('=== %-14s band [%g %g] adapt=%d ===\n', name, band, adapt);
    s = runCase(dt, C, H7, H5, L7, L5, nominal_tf, band, adapt, ...
        target, noise_std, cmd_rms, dur_s, lam_t, lam_v);
    data.(name) = s;
    fprintf('   b_est %.3f->%.3f  a_end %.3f  b_true_end %.3f\n', ...
        s.b_est(find(~isnan(s.b_est), 1)), s.b_est(end), ...
        s.a(end), s.b_true(end));
end

outfile = fullfile(project, 'docs', 'Sol_osi', 'index3_data.json');
fid = fopen(outfile, 'w');
fwrite(fid, jsonencode(data));
fclose(fid);
fprintf('\nwrote %s\n', outfile);
end

% ==========================================================================
function s = runCase(dt, C, H7, H5, L7, L5, nominal_tf, band, adapt, ...
        target, noise_std, cmd_rms, dur_s, lam_t, lam_v)
rng(7, 'twister')                       % same seed as the suite
fs = 1/dt;
N = round(dur_s*fs);
t = (1:N)'*dt;

dd = bandNoise(N, fs, band)*cmd_rms;
v = noise_std*randn(N, 1);

cfg = sol_osi('config', dt, nominal_tf, struct());
prm = gpt5_6_4_auth('params', ...
    struct('target', target, 'dt_update', cfg.step_s));
ost = sol_osi('state', cfg);
ast = gpt5_6_4_auth('state', prm);

[Ac, Bc, Cc, Dc] = ssdata(ss(C));
[A7, B7, C7] = ssdata(H7);
[A5, B5, C5] = ssdata(H5);
xc = zeros(size(Ac, 1), 1);
x7 = zeros(size(A7, 1), 1);
x5 = zeros(size(A5, 1), 1);

blkN = cfg.step_n;
nU = floor(N/blkN);
tc = NaN(nU, 1); bE = NaN(nU, 1); bT = NaN(nU, 1); aU = NaN(nU, 1);
dm = zeros(N, 1);
a = 1;
ku = 0; blk_i = 0;
dd_blk = zeros(blkN, 1); dm_blk = zeros(blkN, 1);

for k = 1:N
    lam = lambdaAt(lam_t, lam_v, t(k));
    y = (1 - lam)*(C7*x7) + lam*(C5*x5);
    dm(k) = y + v(k);
    e = dd(k) - dm(k);
    u = Cc*xc + Dc*e;
    xc = Ac*xc + Bc*e;
    dck = a*u;                          % monitor-only: a stays 1
    x7 = A7*x7 + B7*dck;
    x5 = A5*x5 + B5*dck;

    blk_i = blk_i + 1;
    dd_blk(blk_i) = dd(k);
    dm_blk(blk_i) = dm(k);
    if blk_i == blkN
        blk_i = 0; ku = ku + 1;
        ost.a_cmd = a;                  % closed authority the OSI just saw
        [b, ost, oi] = sol_osi(dd_blk, dm_blk, cfg, ost);
        [a_new, ast] = gpt5_6_4_auth(b, oi.full_margin, ...
            oi.residual_weight, ast, prm);
        if adapt
            a = min(max(a_new, 0), 1);
        else
            a = 1;                      % disconnected: authority not updated
        end
        tc(ku) = t(k); bE(ku) = b; aU(ku) = a;
        La = a*((1 - lam)*L7 + lam*L5);
        bT(ku) = min(abs(1 + La)./sqrt(2*(1 + abs(La).^2)));
    end
end

% decimate the raw signals for the web plot (keep amplitude, drop density)
stride = round(N/2000);
idx = 1:stride:N;
s = struct('band', band, 'adapt', adapt, ...
    't_sig', round(t(idx), 4), ...
    'dd', round(dd(idx), 5), 'dm', round(dm(idx), 5), ...
    'tc', round(tc, 4), 'b_est', round(bE, 4), ...
    'b_true', round(bT, 4), 'a', round(aU, 4));
end

% ==========================================================================
function lam = lambdaAt(xt, xv, t)
if t <= xt(1)
    lam = xv(1);
elseif t >= xt(end)
    lam = xv(end);
else
    lam = xv(1) + (xv(2) - xv(1))*(t - xt(1))/(xt(2) - xt(1));
end
end

function x = bandNoise(N, fs, band)
w = randn(N, 1);
X = fft(w);
f = (0:N-1)'*fs/N;
f = min(f, fs - f);
x = real(ifft(X.*(f >= band(1) & f <= band(2))));
x = x/rms(x);
end

function b = chordalv(L)
b = min(real(abs(1+L)./sqrt(2*(1+abs(L).^2))), 1/sqrt(2));
end
