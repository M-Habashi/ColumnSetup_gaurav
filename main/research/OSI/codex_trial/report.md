# Online Stability Indicator Trial Report

Objective: build an online NCF-margin indicator using non-overlapping moving
windows over the useful test interval `620 s` to `770.1 s`.

## Common Setup

- Test file:
  `main/saved_results/tests/important/20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat`
- Nominal model file:
  `main/saved_results/exp_tf/20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat`
- Signal path: measured controller output `dc` to measured displacement `dm`
- PID: loaded from the nominal model file and kept fixed
- NCF band: `0.1 Hz` to `80 Hz`
- Outer window: `0.5 s`, non-overlapping
- Window centers: `620.25 s` to `769.75 s`, 300 total estimates
- Nominal PID + `H_dc_dm` NCF baseline: `0.5879`

Every trial writes a complete result set in its own folder:

- `trial_#/run_trial_#.m`
- `trial_#/trial_#_results.mat`
- `trial_#/trial_#_results.csv`
- `trial_#/trial_#_margin.png`

For Trials 2, 3, 5, and 6, `RawNCFMargin` stores the immediate 0.5 s margin
measurement and `NCFMargin` stores the causal confidence-smoothed indicator used
for plotting and decisions. The smoother starts from the nominal margin and uses
a small gain scaled by coherence and valid point count. This preserves the
0.5 s update rate without letting one bad frequency bin dominate the decision.

## Comparison

Early mean is the average of the first 10 half-second estimates. Late mean is
the average of the last 10 half-second estimates.

| Trial | Method | First | Last | Min | Early mean | Late mean | Drop | Assessment |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | Raw single-window H1 FRF | 0.0025 | 0.0168 | 0.0006 | 0.2751 | 0.1634 | 0.1117 | Complete but too noisy for 0.5 s decisions. |
| 2 | Smoothed Welch H1 FRF | 0.5537 | 0.4318 | 0.4306 | 0.5076 | 0.4439 | 0.0637 | Informative direct-measurement trend; shows late margin loss. |
| 3 | Smoothed Welch H2 FRF | 0.5546 | 0.3730 | 0.3699 | 0.4970 | 0.3948 | 0.1022 | Informative conservative trend; strongest direct FRF warning. |
| 4 | Stable per-window `tfest` model | 0.2383 | 0.7029 | 0.0029 | 0.3697 | 0.5825 | -0.2128 | Complete but not reliable at this window length. |
| 5 | Smoothed nominal-model correction | 0.5880 | 0.4562 | 0.4562 | 0.5707 | 0.5246 | 0.0461 | Informative model-anchored scalar trend; smooth but less frequency-specific. |
| 6 | FRF state filter + smoothed margin | 0.5864 | 0.4504 | 0.4504 | 0.5697 | 0.4547 | 0.1150 | Best high-rate online candidate; smooth and model-anchored. |

## Recommendation

Use Trial 6 as the primary high-rate online stability indicator.

Trial 6 best matches the revised objective because it updates every `0.5 s`,
keeps the trusted nominal model as the prior, and uses coherence/input power to
control how much each frequency point is allowed to move. The current tuning is
intentionally smooth: it reports a gradual drop from the nominal neighborhood to
about `0.42` late in the run. Increase `processRelSigma` or reduce the
measurement-noise scales in `trial_6/run_trial_6.m` for faster but noisier
detection.

Use Trial 2 and Trial 3 as direct-FRF companion checks. Trial 5 is a useful
model-correction sanity check. If Trial 6 and at least one direct FRF method
drop together, that is stronger evidence of a real stability-margin shrinkage
than any single estimator.

Do not use Trial 4 for online decisions at `0.5 s` resolution. It is complete,
but per-window parametric fitting is slow and the margin curve is dominated by
fit variability.
