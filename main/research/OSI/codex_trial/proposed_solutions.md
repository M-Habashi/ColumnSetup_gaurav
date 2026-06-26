# Proposed Online NCF-Margin Indicators

Objective source: `main/research/OSI/objective.md`.

All proposed trials use the test run
`main/saved_results/tests/important/20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat`
over `620 s` to `770.1 s`, the nominal `H_dc_dm` model from
`main/saved_results/exp_tf/20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat`,
and non-overlapping `0.5 s` outer windows. The expected output for every trial
is a time series of estimated NCF margin values.

## Trial 1: Raw Single-Window H1 FRF Margin

Estimate `H_dc_dm` directly from each non-overlapping window using a Hann-windowed
single-window H1 transfer estimate from `dc` to `dm`. Multiply the measured FRF
points by the fixed saved PID frequency response and compute the loop-only NCF
margin as the minimum normalized Nyquist distance.

Strength: simplest and closest to a pure measurement-only online calculation.

Risk: noisy because each outer window contributes only one spectral estimate.

## Trial 2: Welch H1 FRF With Coherence Gate

Within each outer window, estimate `H_dc_dm` with Welch-averaged H1 spectra. Keep
only frequencies with enough `dc` power and acceptable `dc`/`dm` coherence, then
compute the PID-loop NCF margin from the surviving measured FRF points.

Strength: practical online estimator with a direct measurement basis and basic
quality control.

Risk: can drop too many frequencies when excitation is weak, so the minimum
margin may be computed over an incomplete frequency band.

## Trial 3: Welch H2 FRF With Coherence Gate

Use the same non-overlapping windows and spectral quality gates as Trial 2, but
estimate `H_dc_dm` with the H2 transfer estimate. This gives a complementary
noise-bias assumption to H1 and checks whether the margin trend is estimator
sensitive.

Strength: useful comparison when controller-output measurement noise is not
negligible.

Risk: H2 can overestimate gain when output noise dominates, which may produce
conservative or noisy margins.

## Trial 4: Per-Window Stable Parametric TF Fit

Build a coherence-gated window FRF, fit a stable low-order transfer function
with `tfest`, discretize it at the measured sample time, and reuse
`custom_stability_margins` on `PID * H_dc_dm_window`.

Strength: closest to the existing offline NCF workflow and evaluates the full
frequency band through a proper LTI model.

Risk: more computationally expensive and can be sensitive to insufficient
excitation in a short window.

## Trial 5: Nominal-Model-Corrected FRF Margin

Use the saved nominal `H_dc_dm` as the initial model and estimate a windowed
complex multiplicative correction from high-quality measured FRF points. Apply
that correction to the nominal plant response, multiply by the fixed PID, and
compute the NCF margin over the full nominal frequency grid.

Strength: best online candidate when the beginning-of-window model is trusted
and the measurements should update the margin without refitting a full model.

Risk: a scalar correction cannot capture all frequency-dependent dynamics.

## Trial 6: Coherence-Adaptive Complex FRF State Filter

Initialize a fixed grid of discrete `H_dc_dm` frequency-response points from the
trusted nominal model. Each point is an independent complex state with a
random-walk process model. Every `0.5 s` window produces a direct complex FRF
measurement at the FFT-bin frequencies. The measurement noise covariance is
adapted point-by-point from exponentially weighted spectral coherence and input
power, so coherent/high-energy measurements update quickly while weak or
incoherent measurements leave the estimate close to the model.

Strength: fastest online detector in the set; it gives one updated NCF estimate
every `0.5 s` while preserving the known initial model as the prior.

Risk: it currently treats frequencies independently, so it does not enforce a
globally realizable transfer function.
