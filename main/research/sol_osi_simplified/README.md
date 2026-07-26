# SOL-OSI Simplified

This folder contains the single research-only simplified SOL-OSI estimator.
It is the method previously evaluated as V6; the numbered name has been
retired now that this is the accepted simplified method. The implemented
estimator remains separate in `control_and_HS/OSI`.

## Formulation

The estimator keeps the identified and residual margins as curves over
frequency. At each retained frequency bin it forms

```matlab
w_st = confidence;
w_res = (1-confidence).*detected;
b_bin = w_st.*b_st_curve + w_res.*b_rho_curve + ...
    (1-w_st-w_res).*b_prior_curve;
```

The retained bin values are then sorted and the second-smallest value is
reported:

```matlab
[b_sorted, order] = sort(b_bin(cfg.keep));
b_raw = b_sorted(2);
governing_local = order(2);
```

This is the only change from the accepted V5 formulation. It trims one
isolated low-frequency-bin residual instead of allowing that single bin to
govern the full estimate.

## Fabby Bench 2

With the synthetic target at 0.55 and the experimental target at 0.30, the
canonical result is:

| Metric | Simplified |
|---|---:|
| All gates pass | true |
| Fabby score 1 | 92.94 |
| Fabby score 2 | 62.48 |
| Detection | 60.00 |
| Smoothness | 87.73 |
| GDB recovery | 100.00 |
| Composite | 80.63 |
| Indicator jitter | 1.95 |
| Unstable time | 0 s |
| Tail maximum authority | 0.503 |

Run the two-method comparison from `research/fabby_bench_2`:

```matlab
comparison = compare_fabby_bench_2();
```

For focused estimator studies:

```matlab
result = run_sol_osi_simplified_benchmark;
result = run_sol_osi_simplified_sweep;
result = run_sol_osi_simplified_parameter_sweep;
```
