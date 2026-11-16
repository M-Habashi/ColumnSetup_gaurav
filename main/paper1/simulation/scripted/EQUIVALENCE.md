# Equivalence record

> **Intentional scripted-model changes:** the current scripted runtime
> recalculates experimental damping after the modified 30% mass increase and
> uses unity actuator command gain instead of the benchmark's `1.0261`
> calibration. It also rebuilds the fixed reference system at the requested
> `alpha_start` stiffness. Damage modes now evolve the reference during time
> simulation, and degrading Bouc-Wen hysteresis is available as mode 2. The
> Bouc-Wen alpha/NCF path now uses its measured force-displacement moving-LSE
> stiffness estimate. The historical equivalence results below predate those
> changes and are retained
> only as a record of the earlier implementation.

Validation was performed in MATLAB R2025b against the current
`vRTHS_2024` model at 4096 Hz.

- Default full run: 168,674 samples; time grid exact.
- Rounded J metrics match exactly: `[0 13.93 15.52 35.53 22.60 29.14 29.31 16.13 16.22]`.
- Maximum absolute default-run differences: measured displacement
  `1.21431e-17`, nine-channel numerical response `6.30163e-13`, actuator
  force `3.63798e-11`, indicator `5.55112e-16`, reference response
  `2.55795e-13`.
- Original controller (`modified=0`) also matches all rounded metrics and
  has maximum errors `1.43115e-17`, `4.98268e-13`, and `4.77485e-11` for
  displacement, numerical response, and force respectively.
- Damage-enabled output matches the committed full-run fixture's rounded
  metrics exactly, including the threshold event and beta blend transition.
- Cases 1–4 pass both controller-mode smoke tests.

These differences are many orders of magnitude below the requested 0.1%.

## Alternate sampling frequencies

The nominal modified/no-damage case was also run in both implementations at
2048 and 1024 Hz. Same-rate scripted-versus-Simulink normalized signal errors
remain below `1e-10%` at both rates.

- 2048 Hz is stable, but it is not dynamically equivalent to the 4096 Hz
  baseline. Closed-loop response RMS differences are several percent and the
  rounded J metrics change from
  `[0 13.93 15.52 35.53 22.60 29.14 29.31 16.13 16.22]` to
  `[0 13.94 15.30 37.38 22.81 30.26 30.43 16.53 16.61]`.
- 1024 Hz is numerically/closed-loop unstable in both implementations. The
  actuator first exceeds 8900 at 0.7392578125 seconds and measured
  displacement first exceeds 0.1 m at 1.1337890625 seconds.

These alternate-rate findings concern response sensitivity and stability;
they do not indicate a scripted-versus-Simulink equivalence failure.

## Runtime optimization validation

The allocation-light RK4 hot path was compared directly with its pre-change
damage-enabled 4096 Hz output. `t`, `X_m`, all `Num_resp` channels,
`Force_act`, `alpha`, `indicator`, `beta`, `Ref_Resp`, and J1--J9 were
bit-identical. The 4096 Hz golden self-test still passes, and the optimized
2048 Hz run matches Simulink with maximum normalized RMS/peak errors of
`2.59e-12%` and `5.08e-12%` respectively.

On the validation machine, one warmed full engine run changed from 10.631 to
10.101 seconds (about 5% faster). Display downsampling changed a warmed
full-result plot/export from 6.972 to 3.459 seconds (about 2.0x faster) and
reduced the eight plotted traces to 14,187 total vertices. All displacement
extrema and all 3,372 indicator transition timestamps were retained. Timing
depends on MATLAB graphics state and hardware; the numerical equivalence
checks are deterministic.
