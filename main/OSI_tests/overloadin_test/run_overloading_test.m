function report = run_overloading_test()
%RUN_OVERLOADING_TEST Predict Speedgoat CPU fit of fable_osi_runtime, no target.
%
% Compiles the CURRENT control_and_HS/OSI/fable_osi_runtime.m and the frozen
% pre-fix reference_burst_runtime.m to host MEX (same codegen route as the
% target build, parameters compile-time constant), streams a 90 s worst-case
% signal through both sample-by-sample, and times every base-rate call.
%
% The host->target scale factor is calibrated from MEASURED target runs
% (2026-07-03, .codex/verification/overloading_fix):
%   - pre-fix burst runtime: host 793 us <-> target 780 us (overload), an
%     average k of ~0.91, BUT the per-phase scaling is uneven - the slow
%     2048-pt FFT phase measured ~110 us on host vs ~220 us OSI-share on
%     target (k ~2.0), i.e. host FFT/sort primitives are relatively faster
%     than the QNX target's.
%   - so the prediction deliberately applies the WORST observed per-phase
%     scale, K_PHASE = 2.1, to the worst host phase:
%       predicted = base(57 us) + 2.1 * host_worst_phase_p90.
%     For the shipped time-sliced runtime this predicts ~330 us; the
%     measured target worst tick is 270 us steady / 297 us during a
%     calibration finalize - the prediction is conservative by design.
%
% PASS criterion: predicted worst tick < 75% of the 488 us budget (366 us).
% The pre-fix runtime predicts ~1700 us and fails loudly. Use this test
% before any target run whenever fable_osi_runtime.m or its configuration
% changes; re-anchor the constants if the target hardware changes.
%
% Returns (and prints) a report struct with per-phase-index timing so you
% can see which pipeline phase dominates and how much margin is left for
% new calculations.

TARGET_BUDGET_US = 488.28;      % 1/2048 s base rate
TARGET_OVERLOAD_TETMAX_US = 780.24;   % measured, pre-fix, 2026-07-03
TARGET_BASE_TET_US = 57.2;      % measured TETAvg with the OSI idle
K_PHASE = 2.1;                  % worst measured per-phase host->target scale
PASS_FRACTION = 0.75;           % predicted worst tick under 75% of budget

here = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(here));
addpath(here)
addpath(fullfile(projectFolder, 'OSI_tests', 'fable'))
addpath(genpath(fullfile(projectFolder, 'helpers')))
addpath(genpath(fullfile(projectFolder, 'control_and_HS', 'OSI')))

% ---- config (same as the real preparation) --------------------------------
dt = 1/2048;
hs = struct('exp_tf_file', fullfile(projectFolder, 'saved_results', ...
    'exp_tf', 'tf_sp1_5000_20260627_233333.mat'), ...
    'target_outer_ncf', 0.55, 'osi_gain_min', 0.08, ...
    'osi_gain_initial', 1.0);
setup = prepare_fable_runtime(projectFolder, dt, hs);

% ---- worst-case stream: every code path (same recipe as the equivalence
% test): broadband excitation, mid-record FRF collapse (fast trip), growing
% quiet-band tone (burst + residual engagement), 90 s -> two calibrations
rng(11, 'twister')
fs = 1/dt;
T = 90;
N = round(T*fs);
t = (1:N)'*dt;
E = load(hs.exp_tf_file);
H = E.H_dc_dm;
if get(H, 'Ts') == 0, H = c2d(H, dt, 'zoh'); end
dd = randn(N, 1);
X = fft(dd);
f = (0:N-1)'*fs/N;
f = min(f, fs - f);
X(~(f >= 2 & f <= 100)) = 0;
dd = real(ifft(X));
dd = 0.2*dd/rms(dd);
dm = lsim(ss(H), dd, t) + 0.02*randn(N, 1);
dm(t > 55) = 1.8*dm(t > 55);
grow = t > 75;
dm(grow) = dm(grow) + 0.15*exp((t(grow) - 75)/8).*sin(2*pi*35*t(grow));

% ---- build host MEXes ------------------------------------------------------
workDir = fullfile(here, 'mex_build');
if ~exist(workDir, 'dir'), mkdir(workDir), end
oldDir = cd(workDir);
cleanupObj = onCleanup(@() cd(oldDir));
args = {0, 0, 0, coder.Constant(setup.fbls), coder.Constant(setup.fblw), ...
    coder.Constant(setup.fblbins), coder.Constant(setup.fblfw), ...
    coder.Constant(setup.fblfbins), coder.Constant(setup.fblag), ...
    coder.Constant(setup.fbla)};
fprintf('codegen: current runtime ...\n')
codegen('-o', 'fable_osi_runtime_timed', ...
    fullfile(projectFolder, 'control_and_HS', 'OSI', ...
    'fable_osi_runtime.m'), '-args', args);
fprintf('codegen: pre-fix reference ...\n')
codegen('-o', 'reference_burst_runtime_timed', ...
    fullfile(here, 'reference_burst_runtime.m'), '-args', args);

% ---- time both --------------------------------------------------------------
fprintf('timing: current runtime ...\n')
[us_new, step_n] = timeStream(@fable_osi_runtime_timed, dd, dm, ...
    setup.fbls, setup.fblw, setup.fblbins, setup.fblfw, setup.fblfbins, ...
    setup.fblag, setup.fbla);
clear fable_osi_runtime_timed
fprintf('timing: pre-fix reference ...\n')
us_ref = timeStream(@reference_burst_runtime_timed, dd, dm, ...
    setup.fbls, setup.fblw, setup.fblbins, setup.fblfw, setup.fblfbins, ...
    setup.fblag, setup.fbla);
clear reference_burst_runtime_timed

% ---- per-phase-index statistics (robust to host OS scheduling spikes) ------
% phase index = ticks since the last step boundary (0..step_n-1)
stat_new = phaseStats(us_new, step_n);
stat_ref = phaseStats(us_ref, step_n);
host_worst_new = max(stat_new.p90);
host_worst_ref = max(stat_ref.p90);

k_avg = (TARGET_OVERLOAD_TETMAX_US - TARGET_BASE_TET_US)/host_worst_ref;
k = K_PHASE;
predicted_worst_us = TARGET_BASE_TET_US + k*host_worst_new;
pass = predicted_worst_us < PASS_FRACTION*TARGET_BUDGET_US;

% ---- report -----------------------------------------------------------------
fprintf('\n================ overloading test ================\n')
fprintf('host worst OSI tick (p90 of worst phase):\n')
fprintf('  pre-fix reference : %8.1f us  (target-measured: %.0f us, overload)\n', ...
    host_worst_ref, TARGET_OVERLOAD_TETMAX_US)
fprintf('  current runtime   : %8.1f us\n', host_worst_new)
fprintf('host->target scale: average k = %.3f, applied per-phase k = %.2f\n', ...
    k_avg, k)
fprintf('predicted target worst tick = %.1f us  (budget %.1f us, pass < %.1f us)\n', ...
    predicted_worst_us, TARGET_BUDGET_US, PASS_FRACTION*TARGET_BUDGET_US)
fprintf('predicted headroom for new calculations = %.1f us/tick\n', ...
    PASS_FRACTION*TARGET_BUDGET_US - predicted_worst_us)
[~, order] = sort(stat_new.p90, 'descend');
fprintf('heaviest pipeline phases (current runtime, host us):\n')
for i = 1:min(8, numel(order))
    pi_ = order(i);
    fprintf('  phase %3d: median %7.1f  p90 %7.1f  max %7.1f\n', ...
        stat_new.index(pi_), stat_new.med(pi_), stat_new.p90(pi_), ...
        stat_new.mx(pi_))
end
if pass, verdict = 'PASS'; else, verdict = 'FAIL'; end
fprintf('OVERLOADING_TEST %s\n', verdict)

report = struct('pass', pass, 'predicted_worst_us', predicted_worst_us, ...
    'budget_us', TARGET_BUDGET_US, 'pass_fraction', PASS_FRACTION, ...
    'host_worst_new_us', host_worst_new, ...
    'host_worst_ref_us', host_worst_ref, 'k', k, ...
    'stat_new', stat_new, 'stat_ref', stat_ref, 'step_n', step_n);
save(fullfile(here, 'overloading_test_report.mat'), 'report')
assert(pass, 'Predicted target worst tick %.1f us exceeds %.1f us.', ...
    predicted_worst_us, PASS_FRACTION*TARGET_BUDGET_US)
end

% ==========================================================================
function [us, step_n] = timeStream(fh, dd, dm, fbls, fblw, fblbins, ...
    fblfw, fblfbins, fblag, fbla)
N = numel(dd);
us = zeros(N, 1);
step_n = round(fbls(3));
for i = 1:N
    tt = tic;
    fh(dd(i), dm(i), 1, fbls, fblw, fblbins, fblfw, fblfbins, fblag, fbla);
    us(i) = 1e6*toc(tt);
end
end

function s = phaseStats(us, step_n)
% group tick times by position within the 256-tick step frame
n = floor(numel(us)/step_n)*step_n;
M = reshape(us(1:n), step_n, []);   % step_n x n_steps
s = struct('index', (0:step_n-1)', ...
    'med', median(M, 2), ...
    'p90', prctile(M, 90, 2), ...
    'mx', max(M, [], 2));
end
