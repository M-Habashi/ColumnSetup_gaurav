# Invfreq Fit Fix Plan

Goal: make `tf_fit` follow reliable FRF points robustly across saved files, without confusing the generic rational fit with the physical parametric model.

## Current Problem

- File: `analysis/system_id/fromDataToParametric.m`
- Current code fits with:
  - `nn = 1`, `nm = 6`
  - forced DC point: `H(0) = 1`
  - all `f >= 0.1 Hz` points passed to `invfreqs`
  - weights set to `0` for `f > max_freq_hz`
- Main bug: zero-weight out-of-band rows still enter the `invfreqs` linear system and caused badly scaled / nearly singular solves in MATLAB R2020b.
- Conceptual issue: unconstrained `1/6` `invfreqs` is too flexible for data that does not identify six denominator poles.
- Data issue: not all saved files excite `0.1-40 Hz` well. Newer `id_*` files had reliable/coherent bins only up to roughly `18-24 Hz`.

## Evidence From Read-Only Tests

Using `xfunc(dd, dm, fs, 2^14, 2^13)`:

| File | Reliable Band | Current Fit Error | Masked `1/2` Fit Error |
|---|---:|---:|---:|
| `BLWN_01.mat` | `0.25-40 Hz` | `4.08 dB, 59.3 deg` | `0.39 dB, 2.45 deg` |
| `id_1_20260602_1752_config.mat` | `0.125-18.5 Hz` | `16.5 dB, 80.9 deg` | `0.07 dB, 0.42 deg` |
| `id_2_20260602_1756_config.mat` | `0.125-18.6 Hz` | `28.5 dB, 9.6 deg` | `0.09 dB, 0.39 deg` |
| `id_3_20260602_1801_config.mat` | `0.125-23.6 Hz` | `14.8 dB, 40.5 deg` | `0.10 dB, 0.52 deg` |

## Step 1: Remove Zero-Weight Rows

Diff target: `fromDataToParametric.m`, `Get Continuous Transfer-Function Fit from invfreqs`.

Change:

```matlab
fit_idx = freq_hz_all >= tf_estimate_config.f_lim(1);
tf_fit_points = [1; tf_points_all(fit_idx)];
tf_fit_freq_hz = [0; freq_hz_all(fit_idx)];
tf_fit_weight = double(tf_fit_freq_hz <= tf_estimate_config.f_lim(2));
```

To concept:

```matlab
fit_idx = freq_hz_all >= tf_estimate_config.f_lim(1) & ...
          freq_hz_all <= tf_estimate_config.f_lim(2);
tf_fit_points = [1; tf_points_all(fit_idx)];
tf_fit_freq_hz = [0; freq_hz_all(fit_idx)];
tf_fit_weight = ones(size(tf_fit_freq_hz));
```

Why: points outside the fit band should not be present at all. This fixes the immediate numerical conditioning bug.

Verify: run script on `BLWN_01.mat`; blue curve should follow black points much closer.

## Step 2: Add Reliability Mask From `xfunc` Spectra

Diff target:

- `fromDataToParametric.m`
- `analysis/system_id/utils/xfunc.m` already returns `P = [Pxx,Pyy,Pxy]`; no need to rewrite estimator.

Change xfunc call:

```matlab
[tf_points, freq_hz] = xfunc(...);
```

To:

```matlab
[tf_points, freq_hz, spectra] = xfunc(...);
```

Compute:

```matlab
coherence = abs(spectra(:,3)).^2 ./ max(spectra(:,1).*spectra(:,2), eps);
input_power_db = 10*log10(spectra(:,1) + eps);
```

Recommended mask:

```matlab
band_idx = freq_hz_all >= f_min & freq_hz_all <= f_max;
reliable_idx = band_idx & ...
    coherence >= 0.8 & ...
    input_power_db >= max(input_power_db(band_idx)) - 40;
```

Why: only fit bins where the command had meaningful energy and the input-output FRF estimate is coherent.

Keep compact. Do not add elaborate edge-case handling unless needed.

## Step 3: Lower Generic `invfreqs` Order

Diff target: `tf_estimate_config` in `fromDataToParametric.m`.

Change:

```matlab
'nn', 1, ...
'nm', 6, ...
```

Recommended:

```matlab
'nn', 1, ...
'nm', 2, ...
```

Alternative if a little more flexibility is needed:

```matlab
'nm', 3
```

Why: `tf_fit` is a generic rational display/initial model. The physical sixth-order structure belongs in `tf_parametric`, where the model terms are constrained. Unconstrained `1/6` can invent poorly identified poles.

## Step 4: Keep Physical Parametric Fit Separate

Do not replace `identify_analog_closed_loop_params` with generic `invfreqs`.

Reason:

- `tf_parametric` encodes the actual analog closed-loop structure.
- `tf_fit` should be a smooth rational reference fit to reliable FRF points.
- A good `tf_fit` does not need the same order as the physical model.

## Step 5: Plot Diagnostics Compactly

Diff target: `plot_transfer_function_model_comparison.m` or local plotting data passed from main script.

Optional additions:

- plot reliable FRF points normally
- plot rejected points lighter/gray if useful
- print:
  - selected reliable band
  - number of fitted points
  - RMS magnitude and phase error for `tf_fit`

Avoid large UI/plot refactor.

## Step 6: Validation Order

1. Run read-only fit on `BLWN_01.mat`.
2. Confirm `tf_fit` follows points over `0.25-40 Hz`.
3. Run on all `analysis/system_id/datafiles/*.mat`.
4. Report one compact table:
   - file
   - reliable band
   - fitted point count
   - `tf_fit` RMS magnitude error
   - `tf_fit` RMS phase error
5. Only after MATLAB-code edits are final, ask before physical/visual inspection if needed by AGENTS.md.

## Preferred Final Shape

Minimal robust solution:

- remove zero-weight rows
- use reliability mask
- set `invfreqs` order to `1/2`
- keep parametric fit as the physical model
- add compact printed metrics

This is conceptually sound because the fit only uses identifiable frequency-response samples and does not estimate unnecessary high-order dynamics from weak or incoherent data.
