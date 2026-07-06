function rths_echo_mechanism_figs
%RTHS_ECHO_MECHANISM_FIGS Mechanism evidence figures for the echo diagnosis.
% Companion to rths_echo_diagnosis.m; everything is computed on the
% reference stable run important/20260625_1740_RTHS_02.mat.
%
%   Fig 1  zero-lag echo, visible to the eye: 1 s of >25 Hz dd overlaid on
%          the reconstructed echo G_lead(iff*fm), plus the cross-
%          correlation (peak at lag 0 = instantaneous feedthrough, not the
%          ~15-25 ms forward actuator path).
%   Fig 2  the spectral mechanism at one slow window (t = 95 s): input
%          spectrum + coherence + per-bin chordal margin, corrupted vs
%          cleaned, with the excited-bin gates and the model overlays.
%   Fig 3  the estimated FRF M on the complex plane: corrupted M collapses
%          toward the inverse feedthrough -1/c, cleaned M returns to the
%          model closed-loop T.

here = fileparts(mfilename('fullpath'));
proj = fileparts(fileparts(fileparts(here)));
addpath(fullfile(proj, 'OSI_tests', 'fable'))
figDir = fullfile(here, 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir), end

ink = [11 11 11]/255; muted = [120 118 112]/255; grid_c = [225 224 217]/255;
blue = [42 120 214]/255; red = [204 74 59]/255; aqua = [27 175 122]/255;
violet = [74 58 167]/255; yellow = [237 161 0]/255;

% ---- load record + prior model -------------------------------------------
R = load(fullfile(proj, 'saved_results', 'tests', 'important', ...
    '20260625_1740_RTHS_02.mat'));
r = R.result;
fs = 1/r.dt;
E = load(fullfile(proj, 'saved_results', 'exp_tf', ...
    'tf_sp1_5000_20260627_233333.mat'));
pv = E.pid_values;
C = pid(pv.P, pv.I, pv.D, 1/pv.derivative_filter_N, r.dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
H = E.H_dc_dm; if get(H, 'Ts') == 0, H = c2d(H, r.dt, 'zoh'); end
L0 = C*H;
E7 = load(fullfile(proj, 'saved_results', 'exp_tf', ...
    'tf_sp1_7000_20260627_210411.mat'));
H7 = E7.H_dc_dm; if get(H7, 'Ts') == 0, H7 = c2d(H7, r.dt, 'zoh'); end
pv7 = E7.pid_values;
C7 = pid(pv7.P, pv7.I, pv7.D, 1/pv7.derivative_filter_N, r.dt, ...
    'IFormula', 'ForwardEuler', 'DFormula', 'ForwardEuler');
L07 = C7*H7;

PL = load(fullfile(proj, 'saved_results', 'phase_lead', 'fem3_ncf3.mat'));
Gd = c2d(PL.phase_lead_tf, r.dt, 'tustin');
[nb, na] = tfdata(Gd, 'v');
iff = r.hs.interface_from_force;
echo = filter(nb, na, 1000*iff*r.fm);
s_ec = 0.920;                             % fitted in rths_echo_diagnosis
dd_clean = r.dd - s_ec*echo;

% ======================= FIG 1: the echo in the raw data ==================
[bh, ah] = butter(4, 25/(fs/2), 'high');
ix = r.t >= 45 & r.t < 110;
ddh = filtfilt(bh, ah, r.dd); ech = filtfilt(bh, ah, echo);
zoom_ix = r.t >= 80 & r.t < 81;

fig = figure('Color', 'w', 'Position', [40 40 1150 420], 'Visible', 'off');
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile;
hold(ax, 'on')
plot(ax, r.t(zoom_ix), ddh(zoom_ix), '-', 'Color', ink, 'LineWidth', 1.0)
plot(ax, r.t(zoom_ix), s_ec*ech(zoom_ix), '-', 'Color', red, ...
    'LineWidth', 1.0)
legend(ax, {'dd  (>25 Hz part)', ...
    '0.92 x G_{lead}(iff \cdot fm)   (reconstructed echo)'}, ...
    'Location', 'northeast', 'Box', 'off', 'FontSize', 9)
xlabel(ax, 'time (s)'), ylabel(ax, 'mm')
title(ax, 'dd''s high-frequency content IS the force echo', ...
    'Color', ink, 'FontSize', 10)
styleAx(ax, grid_c, muted, ink)

ax = nexttile;
[cx, lg] = xcorr(ddh(ix), ech(ix), 80, 'coeff');
hold(ax, 'on')
stem(ax, 1000*lg/fs, cx, '.', 'Color', blue)
xline(ax, 0, ':', 'Color', muted)
[~, im] = max(abs(cx));
plot(ax, 1000*lg(im)/fs, cx(im), 'o', 'Color', red, 'MarkerFaceColor', ...
    red, 'MarkerSize', 6)
text(ax, 2, double(cx(im)), sprintf('  peak %.2f @ %.1f ms  (zero lag)', ...
    cx(im), 1000*lg(im)/fs), 'Color', ink, 'FontSize', 9)
xlabel(ax, 'lag (ms)   [forward actuator path would peak at ~15-25 ms]')
ylabel(ax, 'corr(dd_{>25Hz}, echo_{>25Hz})')
title(ax, 'instantaneous: FEM D-term, not the plant', 'Color', ink, ...
    'FontSize', 10)
styleAx(ax, grid_c, muted, ink)
exportgraphics(fig, fullfile(figDir, 'mech_1_zero_lag_echo.png'), ...
    'Resolution', 140)
close(fig)

% =========== FIG 2 + 3: spectral autopsy of one slow window ===============
cfg = fable_osi('config', r.dt, L0, struct());
[Suu, ~, Suy, g2raw, M] = slowWindow(cfg, r.dd, r.dm, r.t, 95);
[Suc, ~, Suyc, g2c, Mc] = slowWindow(cfg, dd_clean, r.dm, r.t, 95);
f = cfg.freq_hz;

chord = @(Mv) 1./(sqrt(2)*max(sqrt(abs(1 - Mv).^2 + abs(Mv).^2), eps));
excited = excitedMask(cfg, Suu, g2raw);
excited_c = excitedMask(cfg, Suc, g2c);

T0 = squeeze(freqresp(feedback(L0, 1), 2*pi*f));
T7 = squeeze(freqresp(feedback(L07, 1), 2*pi*f));
b_model5 = abs(1 + squeeze(freqresp(L0, 2*pi*f))) ...
    ./sqrt(2*(1 + abs(squeeze(freqresp(L0, 2*pi*f))).^2));
b_model7 = abs(1 + squeeze(freqresp(L07, 2*pi*f))) ...
    ./sqrt(2*(1 + abs(squeeze(freqresp(L07, 2*pi*f))).^2));

fig = figure('Color', 'w', 'Position', [40 40 1150 780], 'Visible', 'off');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax = nexttile;   % input spectra
hold(ax, 'on')
pk = max(Suu(cfg.keep));
plot(ax, f, 10*log10(Suu/pk), '-', 'Color', red, 'LineWidth', 1.0)
plot(ax, f, 10*log10(Suc/pk), '-', 'Color', ink, 'LineWidth', 1.0)
yline(ax, -cfg.input_power_range_db, ':', 'Color', muted, ...
    'LineWidth', 1)
text(ax, 70, -cfg.input_power_range_db + 2, ...
    'input-power gate (-35 dB): echo passes it', 'Color', muted, ...
    'FontSize', 8)
legend(ax, {'S_{uu} of dd (as wired: echo floods 20-100 Hz)', ...
    'S_{uu} of cleaned tap (only genuine excitation left)'}, ...
    'Location', 'northeast', 'Box', 'off', 'FontSize', 8)
ylabel(ax, 'input power (dB rel. peak)')
title(ax, sprintf(['RTHS\\_02, slow window ending t = 95 s: why the ' ...
    'gates cannot reject the echo bins']), 'Color', ink, 'FontSize', 10)
styleAx(ax, grid_c, muted, ink)
xlim(ax, [2 100])

ax = nexttile;   % coherence
hold(ax, 'on')
plot(ax, f, g2raw, '-', 'Color', red, 'LineWidth', 1.0)
plot(ax, f, g2c, '-', 'Color', [ink 0.55], 'LineWidth', 0.8)
yline(ax, cfg.gamma_gate, ':', 'Color', muted, 'LineWidth', 1)
text(ax, 63, 0.08, ...
    'coherence gate (dotted): the echo is fully coherent, so it passes', ...
    'Color', muted, 'FontSize', 8)
legend(ax, {'\gamma^2 dd-dm (echo keeps it high everywhere)', ...
    '\gamma^2 cleaned tap-dm'}, 'Location', 'northwest', 'Box', 'off', ...
    'FontSize', 8)
ylabel(ax, 'coherence \gamma^2')
styleAx(ax, grid_c, muted, ink)
xlim(ax, [2 100]), ylim(ax, [0 1.05])

ax = nexttile;   % per-bin chordal margin
hold(ax, 'on')
plot(ax, f, min(b_model7, 1/sqrt(2)), '--', 'Color', [aqua 0.9], ...
    'LineWidth', 1.2)
plot(ax, f, min(b_model5, 1/sqrt(2)), '--', 'Color', [violet 0.7], ...
    'LineWidth', 1.0)
% NOTE: cap BEFORE masking - min(NaN, cap) returns cap, which would
% silently re-materialize every gated-out bin at 0.707
ch = min(chord(M), 1/sqrt(2));   ch(~excited) = NaN;
chc = min(chord(Mc), 1/sqrt(2)); chc(~excited_c) = NaN;
plot(ax, f, ch, 'o-', 'Color', [red 0.75], ...
    'LineWidth', 0.9, 'MarkerSize', 2.5)
plot(ax, f, chc, 'o-', 'Color', ink, 'LineWidth', 1.4, ...
    'MarkerSize', 5, 'MarkerFaceColor', ink)
legend(ax, {'model margin curve  C{\cdot}H_{7000} (healthy plant)', ...
    'model margin curve  C{\cdot}H_{5000} (degraded plant)', ...
    'measured, dd as wired  (only bins passing the gates)', ...
    'measured, cleaned tap'}, 'Location', 'southeast', 'Box', 'off', ...
    'FontSize', 8)
xlabel(ax, 'frequency (Hz)')
ylabel(ax, 'chordal NCF margin b(\omega)')
styleAx(ax, grid_c, muted, ink)
xlim(ax, [2 100]), ylim(ax, [0 0.75])
exportgraphics(fig, fullfile(figDir, 'mech_2_spectral_autopsy.png'), ...
    'Resolution', 140)
close(fig)

% ---- FIG 3: complex plane ------------------------------------------------
fig = figure('Color', 'w', 'Position', [40 40 640 560], 'Visible', 'off');
ax = axes(fig);
hold(ax, 'on')
th = linspace(0, 2*pi, 200);
plot(ax, 0.5 + 0.5*cos(th), 0.5*sin(th), ':', 'Color', muted)
sel = excited & f >= 20 & f <= 100;
selc = excited_c;
hM = plot(ax, real(M(sel)), imag(M(sel)), 'o', 'Color', red, ...
    'MarkerFaceColor', red, 'MarkerSize', 4);
hMc = plot(ax, real(Mc(selc)), imag(Mc(selc)), 'o', 'Color', ink, ...
    'MarkerFaceColor', ink, 'MarkerSize', 4);
hT = plot(ax, real(T7), imag(T7), '-', 'Color', aqua, 'LineWidth', 1.4);
plot(ax, real(T0), imag(T0), '-', 'Color', violet, 'LineWidth', 1.0)
annotation(fig, 'arrow', [0.62 0.38], [0.62 0.55], 'Color', yellow, ...
    'LineWidth', 1.6)
text(ax, -1.9, 0.85, ['echo-dominated bins are dragged off the model' ...
    newline 'curve toward the negative-real echo limit'], ...
    'Color', ink, 'FontSize', 9)
legend(ax, [hM hMc hT], {'M estimated from dd (bins 20-100 Hz)', ...
    'M estimated from cleaned tap', ...
    'model T(\omega) - where healthy bins should sit'}, ...
    'Location', 'southwest', 'Box', 'off', 'FontSize', 9)
xlabel(ax, 'Re M'), ylabel(ax, 'Im M')
title(ax, ['closed-loop bias drags the estimated FRF away from the ' ...
    'true inner-loop T'], 'Color', ink, 'FontSize', 10)
axis(ax, 'equal')
xlim(ax, [-2.4 1.6]), ylim(ax, [-1.4 1.4])
styleAx(ax, grid_c, muted, ink)
exportgraphics(fig, fullfile(figDir, 'mech_3_complex_plane.png'), ...
    'Resolution', 140)
close(fig)

fprintf('mechanism figures written to %s\n', figDir);
end

% ==========================================================================
function [Suu, Syy, Suy, g2, M] = slowWindow(cfg, dd, dm, t, t_end)
fs = 1/cfg.dt;
i_end = find(t <= t_end, 1, 'last');
K = cfg.n_segment;
Suu_seg = zeros(cfg.nf, K); Syy_seg = zeros(cfg.nf, K);
Suy_seg = complex(zeros(cfg.nf, K));
for s = 1:K
    i2 = i_end - (K - s)*cfg.hop_n;
    i1 = i2 - cfg.segment_n + 1;
    xu = dd(i1:i2); xy = dm(i1:i2);
    U = fft(cfg.window.*dtl(xu(:))); Y = fft(cfg.window.*dtl(xy(:)));
    U = U(cfg.bin); Y = Y(cfg.bin);
    Suu_seg(:, s) = abs(U).^2;
    Syy_seg(:, s) = abs(Y).^2;
    Suy_seg(:, s) = Y.*conj(U);
end
Suu = median(Suu_seg, 2); Syy = median(Syy_seg, 2);
Suy = complex(median(real(Suy_seg), 2), median(imag(Suy_seg), 2));
tiny = max(max(Suu), 1)*1e-14;
M = Suy./max(Suu, tiny);
g2 = min(abs(Suy).^2./max(Suu.*Syy, tiny^2), 1);
end

function m = excitedMask(cfg, Suu, g2raw)
tiny = max(max(Suu), 1)*1e-14;
pow_floor = max(Suu(cfg.keep))*10^(-cfg.input_power_range_db/10);
has_input = Suu > max(pow_floor, tiny);
local_max = movmax(Suu, 7);
not_leak = Suu > local_max*10^(-cfg.sidelobe_db/10);
m = cfg.keep & g2raw > cfg.gamma_gate & has_input & not_leak;
end

function y = dtl(x)
n = numel(x);
X = [ones(n, 1) (1:n)'/n];
y = x - X*(X\x);
end

function styleAx(ax, grid_c, muted, ink)
grid(ax, 'on')
set(ax, 'GridColor', grid_c, 'GridAlpha', 1, 'Box', 'off', ...
    'XColor', muted, 'YColor', muted, 'FontSize', 9, 'Layer', 'top')
ax.YLabel.Color = ink;
ax.XLabel.Color = ink;
end
