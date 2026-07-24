# sol_osi

Canonical estimator based on GPT-5.6.4. It keeps the existing coherent branch,
rho fit, chordal-margin calculation, and authority law, but changes the quiet
branch in two ways:

1. The first three non-overlapping 0.5 s active windows form a per-frequency
   healthy reference. Later quiet spectra are compared with this fixed
   reference instead of normalizing every window by itself.
2. The existing idle residual-memory weight uses a gain of 32 so persistent
   quiet evidence continues to affect the selected OSI when excitation fades.
   The amplified memory releases when corrected power falls below 0.6 of the
   healthy reference and re-engages only after it rises above 1.4.
3. When corrected quiet-band power exceeds 4 times the healthy reference, the
   existing rho-fit floor rises smoothly by at most 0.28. This affects only
   unusually strong level growth, such as the highlighted 35 Hz event.

Retained settings:

- `reference_level_beta = 0`
- `fit_floor = 0.10`
- `residual_memory_gain = 32`
- `memory_release_ratio = 0.6`
- `memory_reengage_ratio = 1.4`
- `level_fit_start_ratio = 4.0`
- `level_fit_gain = 0.28`
- residual fit band: 28–44 Hz
- overall OSI band: 2–100 Hz

Validated results:

- highlighted selected OSI: mean 0.30120, maximum 0.34775, 100% below 0.35
- highlighted quiet OSI: 0.30059
- canonical suite: 10/10
- fabby_score_1: 92.733892
- fabby_score_2: 57.928097
- all seven hard benchmark gates pass
- unstable time: 0.00 s
- tail authority: 0.660, below the 0.736 stability limit
- GDB recovery to 0.95: 13.5 s, then held through record end
- GDB recovery score: 38.24
- composite score: 74.09

The recovery hysteresis is intentionally wide: it requires strong evidence of
restoration before releasing memory, then requires clear renewed growth before
re-engaging it.

The main implementation is `control_and_HS/OSI/sol_osi.m`.
Use `run_sol_osi_record` for the highlighted-record comparison and
`run_sol_osi_benchmark` for the complete Fabby Benchmark.

Deployment note: the estimator must be initialized after pause, or its healthy
reference state must be reset when pause ends. The time-sliced implementation
is in `control_and_HS/OSI/gpt5_6_runtime.m`; its legacy filename is retained so
the existing Simulink model does not require an `.slx` edit.
