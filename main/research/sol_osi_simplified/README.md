# SOL-OSI Simplified

This folder contains the approved research-only simplified SOL-OSI. It remains
separate from the production implementation in `control_and_HS/OSI`.

## Activity

The estimator uses a hard binary activity gate:

```matlab
A = double(rms(u) > eta_A);
eta_A = 0.0575;
activation_weight = 0.80*A;
```

Using the clean quiet-record estimate `sigma_noise_u = 0.012657`, the selected
threshold is approximately `4.54*sigma_noise_u`.

There is no filtered activity state. `activation_weight` changes immediately
between `0` and `0.80`; the constant factor has no memory or transition ramp.
The calibrated final-margin response time is `margin_s = 0.08`.

## Residual inference

The healthy output-power reference is the pointwise median of the first three
non-overlapping 0.5 s windows:

```matlab
Phi_yy_ref = median(abs(Y_ref).^2, 2);
q_obs = Phi_yy ./ max(Phi_yy_ref, eps);
```

The estimator separates the frequency sets:

- `Omega`: all usable 2–100 Hz bins, excluding 58–62 Hz. Each bin independently
  selects its best loop scale `rho_best(omega)`.
- `Q`: the 28–44 Hz quiet set. It supplies the scalar reference ratio used by
  memory hysteresis and the leverage used to weight residual evidence; it does
  not restrict the `rho` fit.

The residual margin is calculated from the frequency-dependent stored scale:

```matlab
b_res = minMasked(movmedian( ...
    chordal(alpha*rho.*L0, cap), 3), keep);
```

The moving median uses three adjacent frequency bins, not three time windows.
The calibrated dynamics are:

```matlab
residual_s = 0.84;
rho_leak_s = 8.0;
residual_memory_gain = 21.75;
```

## Fabby Benchmark result

| Evaluator | Implemented | Simplified |
|---|---:|---:|
| Fabby 1 | 92.733890 | 93.026280 |
| Fabby 2 | 57.928097 | 59.589202 |
| S3 detection | 100.000000 | 80.000000 |
| S4 highlighted subset | 81.550273 | 85.860001 |
| S5 recovery | 38.235294 | 49.264706 |
| Composite | 74.089511 | 73.548038 |

The simplified estimator passes all seven gates. Its GDB recovery latency is
`11.625 s`, and its maximum tail authority is `0.71493`.

Run the canonical benchmark with:

```matlab
result = run_sol_osi_simplified_benchmark;
```

Sweep the hard-activity threshold with:

```matlab
result = run_sol_osi_simplified_sweep;
```

Sweep the calibrated residual dynamics with:

```matlab
result = run_sol_osi_simplified_parameter_sweep;
```
