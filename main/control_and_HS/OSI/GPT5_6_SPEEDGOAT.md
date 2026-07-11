# GPT-5.6 Speedgoat runtime

`gpt5_6_runtime.m` is the real-time implementation of the desktop
`research/gpt5_6/gpt_osi.m` and `gpt_auth.m` algorithms. The main script
builds its fixed-size parameters with `prepare_gpt5_6_runtime.m`.

## Scheduling

The base rate is 2048 Hz (488.28 us per tick). A GPT update begins every
256 ticks and publishes 32 ticks later:

- phase 1: snapshot-boundary command window and prior calculation;
- phases 2 and 4: separate 1024-point command and response FFTs;
- phase 5: spectral update and coherent margin;
- phase 6: quiet-band observation normalization;
- phases 7-31: one residual-fit gain candidate per tick;
- phase 32: residual/full margin, authority update, and atomic publish.

Do not combine the FFTs or the 25 fit candidates into one phase. The
previous FABLE overload was caused by placing a full spectral pipeline on
one base-rate tick. Keep at least 30% measured TET margin after any runtime,
configuration, or surrounding-model change.

## Verification order

1. Compare the scheduled output at tick `k*step_n + 32` with the desktop
   `gpt_osi` + `gpt_auth` output for update `k`.
2. Compile `gpt5_6_runtime.m` with all parameter arrays as
   `coder.Constant` values.
3. Update the diagram and run `slbuild('model_ColumnSetup_00')` from a fully
   initialized `main_ColumnSetup.m` workspace.
4. Load the application, enable `osi_gain_enable_initial`, and run on target
   for at least 120 s while retaining the maximum `tg.ModelStatus.TETInfo`.
5. Require no target error/early stop and
   `TETMax <= 0.70*(1/2048)`.

The 2026-07-10 acceptance run lasted 125 s: TETMax 78.50 us, TETAvg
53.79 us, 83.9% margin, and zero overloads.
