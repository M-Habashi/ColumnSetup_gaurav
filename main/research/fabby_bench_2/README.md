# Fabby Bench 2

Fabby Bench 2 uses two targets:

- The synthetic ten-case suite retains its original `0.55` target for both
  the authority controller and ground-truth scoring.
- The experimental `osi_calibration_test` and `GDBqFpKb` cases use a `0.30`
  authority/regulation target.

This isolates the experimental commissioning-margin issue without weakening
the synthetic damage tests. The original benchmark defaults and scenario
files are not modified.

It compares:

1. `control_and_HS/OSI/sol_osi_v1.m` (former production implementation)
2. `control_and_HS/OSI/sol_osi.m` (current implementation)

`sol_osi` is the accepted simplified V6 formulation. It uses the current
authority-scaled commissioning prior for unsupported bins and reports the
second-smallest retained bin so one isolated low residual does not govern.

Run:

```matlab
comparison = compare_fabby_bench_2();
```

The full results and summary table are saved under `results/`.
