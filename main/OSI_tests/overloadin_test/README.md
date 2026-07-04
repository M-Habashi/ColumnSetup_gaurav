# Overloading test (Speedgoat CPU fit, no target needed)

Background: on 2026-07-03 the pre-fix fable OSI runtime overloaded the
Speedgoat base rate (`Overload limit (0) exceeded in 0.000488281s`,
TETMax 780 us) as soon as the indicator started evaluating after
pause->resume. The fix time-slices the OSI work across base-rate ticks
(see the header of `control_and_HS/OSI/fable_osi_runtime.m` and
`main/simulink_changes.md`).

## Files

- `run_overloading_test.m` - **run this before any target run whenever
  `fable_osi_runtime.m` or its configuration changes.** Compiles the
  current runtime and the frozen pre-fix reference to host MEX, streams a
  90 s worst-case signal (broadband + FRF collapse + growing quiet-band
  tone: every code path incl. two calibrations and trips), times every
  base-rate call, and maps the worst host tick onto target microseconds
  with a scale factor calibrated against the measured overload
  (pre-fix: 793 us host vs 780 us target, k = 0.91).
  PASS = predicted worst target tick < 50% of the 488 us budget.
  Prints the per-phase cost table so you can see where tick headroom goes
  when adding new calculations.
- `reference_burst_runtime.m` - frozen copy of the pre-fix (single-burst)
  runtime, used for the calibration baseline and A/B comparisons. Do not
  edit.
- `run_overload_fix_comparison.m` - replays the 10 synthetic closed-loop
  scenarios (`fable_synthetic_suite`) and the three saved hardware records
  through BOTH implementations and writes the figures + metrics used by
  `report.html`.
- `report.html` - the overloading-fix report (reproduction evidence, fix,
  TET numbers, 10 + 3 case comparison).

## Limits

The host predictor assumes the rest of the model (control path, hybrid
simulation, TSE, I/O) keeps its measured ~50 us base cost. If you add load
OUTSIDE the OSI block, re-measure on target (TETInfo in
`tg.ModelStatus.TETInfo` is polled live without the profiler).
