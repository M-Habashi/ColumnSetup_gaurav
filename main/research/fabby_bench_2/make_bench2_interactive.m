function make_bench2_interactive()
%MAKE_BENCH2_INTERACTIVE Payload for the live parameter panel on the page.
%
%   Writes docs/Sol_osi/bench2_tune.js, which carries everything the browser
%   needs to re-run the canonical sol_osi on the two experimental scenarios
%   while the reader moves a slider.  The estimator itself is ported to
%   JavaScript inside index.html; this function only exports the inputs it
%   cannot recompute there.
%
%   GDBqFpKb replay is an open-loop replay, so both signals are fixed and the
%   whole per-step spectrum (pu, py, cyu) is precomputed here.
%
%   The live scenario closes the loop, so dm depends on the authority the
%   reader's parameters produce and has to be simulated in the browser.  Its
%   OSI input is the recorded reference, which does not depend on authority,
%   so the drive spectrum U is still precomputed and only Y is transformed
%   in the browser.
%
%   Signals that must be shipped at the full 2048 Hz rate (reference, noise)
%   go as int16 with a scale factor: their quantisation step sits ~100x below
%   the 0.06 mm measurement noise, and check_bench2_interactive.js verifies
%   the browser reproduces the MATLAB curves.

here = fileparts(mfilename('fullpath'));
project = fileparts(fileparts(here));
addpath(fullfile(project, 'control_and_HS', 'OSI'), '-begin');
rehash;

E = load(fullfile(project, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E.pid_values;
G = load(fullfile(project, 'saved_results', 'tests', 'tsting_osi', ...
    'GDBqFpKb.mat'));
Lv = load(fullfile(project, 'saved_results', 'tests', 'gpt5_6_tests', ...
    'osi_calibration_test.mat'));

r = G.result;
dt = r.dt;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H5 = ss(c2d(E.H_dc_dm, dt, 'zoh'));
L0tf = C*H5;
cfg = sol_osi('config', dt, L0tf, struct());

%% ---- static configuration --------------------------------------------------
out.cfg = struct( ...
    'dt', dt, 'fs', cfg.fs, 'step_s', cfg.step_s, 'step_n', cfg.step_n, ...
    'segment_n', cfg.segment_n, 'cap', cfg.cap, ...
    'reference_stride', cfg.reference_stride, ...
    'freq_hz', cfg.freq_hz(:)', 'keep', double(cfg.keep(:)'), ...
    'L0re', real(cfg.L0(:))', 'L0im', imag(cfg.L0(:))', ...
    'shape', cfg.shape(:)', 'rho_grid', cfg.rho_grid(:)', ...
    'window', f32(cfg.window));

out.defaults = struct( ...
    'memory_s', cfg.memory_s, 'margin_s', cfg.margin_s, ...
    'residual_s', cfg.residual_s, 'warm_s', cfg.warm_s, ...
    'power_floor_db', cfg.power_floor_db, 'fit_floor', cfg.fit_floor, ...
    'eta_A', cfg.eta_A, 'hard_activity_gain', cfg.hard_activity_gain, ...
    'detector_max', cfg.detector_max, 'rho_recover_s', cfg.rho_recover_s, ...
    'rho_detect', cfg.rho_detect, ...
    'no_evidence_prior', double(cfg.no_evidence_prior), ...
    'reference_level_beta', cfg.reference_level_beta, ...
    'level_fit_gain', cfg.level_fit_gain, ...
    'level_fit_start_ratio', cfg.level_fit_start_ratio);

prm = gpt5_6_4_auth('params', struct('dt_update', cfg.step_s, 'target', 0.30));
out.auth = prm;

%% ---- GDBqFpKb replay: everything precomputable -----------------------------
fprintf('GDB replay spectra...\n');
tap = r.u_osi(:); dm = r.dm(:); t = r.t(:); gain = r.Results(:, 21);
n = floor(min([numel(t), numel(tap), numel(dm)])/cfg.step_n);
[pu, py, cre, cim, urms] = stepSpectra(tap, dm, n, cfg);
out.tests.gdb_replay = struct('mode', 'open', 'n', n, ...
    't', round(t((1:n)'*cfg.step_n), 4)', ...
    'gain', gain((1:n)'*cfg.step_n)', 'urms', f32(urms), ...
    'pu', f32(pu), 'py', f32(py), 'cre', f32(cre), 'cim', f32(cim));

%% ---- live closed loop: simulated in the browser ----------------------------
fprintf('live scenario inputs...\n');
rec = Lv.result;
tL = rec.t(:); ref = rec.u_osi(:); gainL = rec.Results(:, 21);
N = numel(tL);
rng(3, 'twister');
noise = 0.06*randn(N, 1);
blk = cfg.step_n; nU = floor(N/blk);

% the drive spectrum does not depend on authority
[puL, ~, ~, ~, urmsL, Ure, Uim] = stepSpectra(ref, zeros(N, 1), nU, cfg);

[Ap, Bp, Cp] = ssdata(H5);
[Ac, Bc, Cc, Dc] = ssdata(ss(C));
f = (1:100)';
L5f = squeeze(freqresp(L0tf, 2*pi*f));

out.tests.live_closed_loop = struct('mode', 'closed', 'n', nU, 'N', N, ...
    't', round(tL((1:nU)'*blk), 4)', ...
    'gain', gainL((1:nU)'*blk)', 'urms', f32(urmsL), ...
    'pu', f32(puL), 'ure', f32(Ure), 'uim', f32(Uim), ...
    'ref', i16(ref), 'noise', i16(noise), 'gain_full', rle(gainL), ...
    'Ap', Ap(:)', 'Bp', Bp(:)', 'Cp', Cp(:)', 'np', size(Ap, 1), ...
    'Ac', Ac(:)', 'Bc', Bc(:)', 'Cc', Cc(:)', 'Dc', Dc, ...
    'nc', size(Ac, 1), 'dc_sat', 10, ...
    'L5fre', real(L5f(:))', 'L5fim', imag(L5f(:))');

%% ---- write -----------------------------------------------------------------
out.generated_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
outfile = fullfile(project, 'docs', 'Sol_osi', 'bench2_tune.js');
fid = fopen(outfile, 'w');
fwrite(fid, ['window.BENCH2_TUNE = ' jsonencode(out) ';']);
fclose(fid);
d = dir(outfile);
fprintf('wrote %s (%.0f kB)\n', outfile, d.bytes/1024);
end

%% ===========================================================================
function [pu, py, cre, cim, urms, Ure, Uim] = stepSpectra(u, y, n, cfg)
% Per-update windowed spectra, row-major [step][bin], exactly as the
% estimator's own sliding buffer would see them.
nb = numel(cfg.bin);
pu = zeros(n, nb); py = zeros(n, nb); cre = zeros(n, nb); cim = zeros(n, nb);
Ure = zeros(n, nb); Uim = zeros(n, nb); urms = zeros(n, 1);
bu = zeros(cfg.segment_n, 1); by = zeros(cfg.segment_n, 1);
m = cfg.step_n;
for k = 1:n
    ii = (k-1)*m+(1:m);
    bu = [bu(m+1:end); u(ii)];
    by = [by(m+1:end); y(ii)];
    urms(k) = rms(bu);
    U = fft(bu.*cfg.window); U = U(cfg.bin);
    Y = fft(by.*cfg.window); Y = Y(cfg.bin);
    pu(k, :) = abs(U).^2;
    py(k, :) = abs(Y).^2;
    cyu = Y.*conj(U);
    cre(k, :) = real(cyu); cim(k, :) = imag(cyu);
    Ure(k, :) = real(U); Uim(k, :) = imag(U);
end
end

function s = f32(x)
% row-major float32, base64
v = single(reshape(x.', 1, []));
s = matlab.net.base64encode(typecast(v, 'uint8'));
end

function out = i16(x)
% int16 with a scale factor; the quantisation step is ~1e-4 of full scale
sc = max(abs(x(:)));
if sc == 0, sc = 1; end
q = int16(round(x(:)'/sc*32767));
out = struct('scale', sc/32767, 'data', ...
    matlab.net.base64encode(typecast(q, 'uint8')));
end

function out = rle(x)
% run-length encoding for the piecewise-constant diagnostic gain
x = x(:);
idx = [1; find(diff(x) ~= 0)+1];
out = struct('idx', (idx-1)', 'val', x(idx)', 'n', numel(x));
end
