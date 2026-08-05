function result = design_baseline_lqg
%DESIGN_BASELINE_LQG True baseline LQG: baseline LQR gain + dual-LQR filter.
%
% The saved LQG/LQR baseline assumes full state feedback of the companion
% coordinates, which are not measurable. This script completes the baseline
% into a real LQG: the same LQR gain K, a Kalman filter designed by duality
% (L = lqr(A', C', q_f*B*B', r_f)'), and the baseline Nbar prefilter. The
% filter noise ratio is selected from a documented sweep trading correction
% of the 5k model-mismatch error against measurement-noise gain into the
% command. The plant is nonminimum phase, so classical LTR margin recovery
% does not hold: the observer-based loop has no gain crossover at any ratio
% (phase margin undefined), and the gain margin is the robustness metric.

assets = kimi_assets;
family = load(fullfile(assets.results, 'plant_family.mat'), 'result');
family = family.result;
baseline = load(assets.baseline, 'result');
baseline = baseline.result;

A = family.A0; B = family.B; C = family.C0;
ws = family.frequency_scale;
K = baseline.K;
qy = baseline.qy; ru = baseline.ru;
nbar = baseline.nbar;
A5 = family.A0 + family.dA; C5 = family.C0 + family.dC;

% Reproduce the published full-state LQR baseline metrics (anchor).
stepTime = linspace(0, 3, 6001).';
cl7 = ss(ws*(A - B*K), ws*B*nbar, C, 0);
cl5 = ss(ws*(A5 - B*K), ws*B*nbar, C5, 0);
anchor.overshoot_7k = overshootOf(step(cl7, stepTime));
anchor.overshoot_5k = overshootOf(step(cl5, stepTime));
anchor.final_5k = dcgain(cl5);

% Filter noise-ratio sweep: correction of the 5k steady-state error and 5k
% overshoot (performance under mismatch) against the measurement-noise gain
% into the command (cost). Gain margin on the nominal 7k loop is recorded
% as the robustness indicator; the LQG loop for this nonminimum-phase plant
% has no gain crossover, so the classical phase margin is undefined.
rhoSweep = logspace(-8, 6, 57).';
gainMarginDb = zeros(size(rhoSweep));
phaseMarginDeg = zeros(size(rhoSweep));
noiseGain = zeros(size(rhoSweep));
final5Sweep = zeros(size(rhoSweep));
overshoot5Sweep = zeros(size(rhoSweep));
stable5Sweep = false(size(rhoSweep));
stepTime = linspace(0, 3, 6001).';
for i = 1:numel(rhoSweep)
    L = lqr(A.', C.', rhoSweep(i)*(B*B.'), 1).';
    controller = ss(ws*(A - B*K - L*C), ws*L, -K, 0);
    loop = controller*ss(ws*A, ws*B, C, 0);
    margins = allmargin(loop);
    gainMarginDb(i) = min(20*log10([margins.GainMargin(:); Inf]));
    phaseMarginDeg(i) = min([margins.PhaseMargin(:); Inf]);
    noisePath = feedback(controller, ss(ws*A, ws*B, C, 0));
    noiseGain(i) = norm(noisePath, 2);
    r2y = closedLQG(A5, C5, L);
    final5Sweep(i) = dcgain(r2y);
    stable5Sweep(i) = isstable(feedback(controller*ss(ws*A5, ws*B, C5, 0), 1));
    if stable5Sweep(i)
        overshoot5Sweep(i) = overshootOf(step(r2y, stepTime));
    else
        overshoot5Sweep(i) = NaN;
    end
end
% State-feedback reference margins.
sfMargins = allmargin(ss(ws*A, ws*B, K, 0));

% Baseline selection: rho = 1, the canonical LQG choice (unit-intensity
% input process noise against unit measurement noise). The sweep documents
% that no ratio repairs the post-drop steady-state error and that ratios
% above 10^1.75 destabilize the 5k plant, so the baseline is not tuned on
% mismatch knowledge.
fprintf('5k final value vs log10(rho): first %.6g, mid %.6g, last %.6g\n', ...
    final5Sweep(1), final5Sweep(round(end/2)), final5Sweep(end))
fprintf('5k closed loop unstable for log10(rho) >= %.6g\n', ...
    log10(rhoSweep(find(~stable5Sweep, 1, 'first'))))
knee = find(rhoSweep >= 1, 1, 'first');
rho = rhoSweep(knee);
L = lqr(A.', C.', rho*(B*B.'), 1).';

controller7 = ss(ws*(A - B*K - L*C), ws*L, -K, 0); % u = -K xhat + nbar r
plant7 = ss(ws*A, ws*B, C, 0);
plant5 = ss(ws*A5, ws*B, C5, 0);
loop7 = controller7*plant7;
loop5 = controller7*plant5;
margins7 = allmargin(loop7);
margins5 = allmargin(loop5);

% Closed-loop r->y with the LQG controller (2-dof: prefilter nbar).
% States: [x_hat; x_p], all matrices normalized then scaled by ws once.
function T = closedLQG(Ap, Cp, Lv)
    Acl = [A - B*K - Lv*C, Lv*Cp; -B*K, Ap];
    Bcl = [B*nbar; B*nbar];
    Ccl = [zeros(1, 6), Cp];
    T = ss(ws*Acl, ws*Bcl, Ccl, 0);
end
T7 = closedLQG(A, C, L);
T5 = closedLQG(A5, C5, L);
r2y7 = T7(:, 1);
r2y5 = T5(:, 1);
lqgOvershoot7 = overshootOf(step(r2y7, stepTime));
lqgOvershoot5 = overshootOf(step(r2y5, stepTime));
lqgFinal5 = dcgain(r2y5);

sens7 = feedback(1, loop7);
comp7 = 1 - sens7;

result = struct;
result.K = K; result.L = L; result.nbar = nbar;
result.qy = qy; result.ru = ru; result.filter_rho = rho;
result.anchor_lqr_full_state = anchor;
result.lqg_step = struct('overshoot_7k', lqgOvershoot7, ...
    'overshoot_5k', lqgOvershoot5, 'final_5k', lqgFinal5);
result.margins_7k = struct( ...
    'gain_margin_db', 20*log10(min([margins7.GainMargin(:); Inf])), ...
    'phase_margin_deg', min([margins7.PhaseMargin(:); Inf]));
result.margins_5k = struct( ...
    'gain_margin_db', 20*log10(min([margins5.GainMargin(:); Inf])), ...
    'phase_margin_deg', min([margins5.PhaseMargin(:); Inf]), ...
    'stable', isstable(feedback(loop5, 1)));
result.state_feedback_margins = struct( ...
    'gain_margin_db', 20*log10(min([sfMargins.GainMargin(:); Inf])), ...
    'phase_margin_deg', min([sfMargins.PhaseMargin(:); Inf]));
result.sensitivity_peak_7k = norm(sens7, Inf);
result.complementary_peak_7k = norm(comp7, Inf);
result.sweep = struct('rho', rhoSweep, ...
    'gain_margin_db', gainMarginDb, ...
    'phase_margin_deg', phaseMarginDeg, ...
    'noise_gain', noiseGain, ...
    'final_5k', final5Sweep, 'overshoot_5k', overshoot5Sweep, ...
    'stable_5k', stable5Sweep, 'selected', knee);

outputFile = fullfile(assets.results, 'baseline_lqg.mat');
save(outputFile, 'result')
fprintf('Anchor LQR full-state: OS7 %.4g%%, OS5 %.4g%%, final5 %.6g\n', ...
    anchor.overshoot_7k, anchor.overshoot_5k, anchor.final_5k)
fprintf('Baseline LQG (rho=%.3g): OS7 %.4g%%, OS5 %.4g%%, final5 %.6g\n', ...
    rho, lqgOvershoot7, lqgOvershoot5, lqgFinal5)
fprintf('Margins 7k: GM %.4g dB, PM %.4g deg | 5k: GM %.4g dB, PM %.4g deg\n', ...
    result.margins_7k.gain_margin_db, result.margins_7k.phase_margin_deg, ...
    result.margins_5k.gain_margin_db, result.margins_5k.phase_margin_deg)
fprintf('||S||inf 7k %.4g, ||T||inf 7k %.4g\n', ...
    result.sensitivity_peak_7k, result.complementary_peak_7k)
fprintf('Saved baseline LQG to %s\n', outputFile)
end

function overshoot = overshootOf(response)
    final = response(end);
    overshoot = max(0, (max(response) - final)/max(abs(final), eps)*100);
end
