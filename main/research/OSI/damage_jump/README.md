# OSI test: healthy → damaged `H_dc_dm` jump (low-band input)

A synthetic 20 s time history for testing the online stability indicators (OSI)
against a **mid-experiment specimen damage event**, and a run of **Method 7** on
it. The record uses the **undamaged** `H_dc_dm` for the first 10 s and the
**damaged** `H_dc_dm` for the last 10 s; everything else (PID, phase lead, FEM /
reference excitation) is held fixed, so the only thing that changes at `t = 10 s`
is the specimen damage — exactly the partition `vHS.m` uses to simulate damage.

## What changes at the jump, and what does not

| Quantity | First 10 s (healthy) | Last 10 s (damaged) |
|---|---|---|
| `H_dc_dm` (actuator + specimen) | `tf_sp_1_7000_20260627_210411.mat` | `tf_sp1_5000_20260627_233333.mat` |
| specimen `k` | 7.20e6 N/m (`sp1_7000`) | 5.38e6 N/m (`sp1_5000`) |
| **PID** | `P=0.15, I=20, D=0.0015, N=512` | *same* |
| **phase lead** `G_T` | `pl_sp1_5000.mat` | *same* |
| **input / reference** | 20 s of the low-band 1749 `dd` | *same* |

Effect on the inner actuator loop `L = C·H_dc_dm` (the loop Method 7 is calibrated
to): the loop-only NCF margin drops **0.588 → 0.344** (it crosses the 0.40
"acceptable" line), the peak sensitivity `‖S‖∞` grows **1.19 → 1.86**, and the
binding resonance shifts **35 → 39 Hz**. This is the user's stated mechanism —
specimen degradation acting like a higher MTS P-gain inside `H_dc_dm`.

## How the record is built (`make_damage_th.m`)

The closed loop is driven, per the `vHS.m` signal path, in output-disturbance
form (the channel through which the closed-loop resonance shows up in `dm`):

```
dd      : recorded numerical-substructure reference  (20 s of the 1749 low-band dd)
dd_lead : G_T(dd)                                     (phase lead, same both halves)
dm      = T·dd_lead + S·d        T = C·H/(1+C·H),  S = 1/(1+C·H)
dc      = PID·(dd_lead − dm)
fm      = k·dm
```

- `d` is broadband output disturbance (sensor/process noise + nonlinearity) at the
  model's identified level `source_noise_std ≈ 0.069 mm`. It is what excites the
  35–39 Hz resonance *from inside the loop* — the resonance the **input never
  probes** (the 1749 `dd` has ~0 % energy above 10 Hz). The result is independent
  of the disturbance amplitude (the indicator is a spectral ratio).
- The healthy and damaged loops are each simulated over the full span and **spliced
  at `t = 10 s`** with a 0.1 s raised-cosine crossfade (state continuity). The
  first 3 s are a discarded warm-up so the loop starts at steady state.

**Why the inner actuator loop (not the full hybrid FEM loop):** Method 7's
calibration target `b_nom` is literally the inner loop-only NCF of `C·H_dc_dm`
(`osi_method7_resonance.m` line 24), and the binding 35 Hz mode is an
actuator/specimen phenomenon, not a FEM one. The healthy inner NCF (0.588) matches
`b_nom` exactly, so the inner loop is the consistent and faithful test bed. Note
that with a low-band input the open-loop FRF `dm/dc` is a **tautology** at 35 Hz
here too (both the reference and the disturbance drive `dc = −C·dm` there), so the
FRF methods 1–6 are blind and Method 7 (output-only) is the right tool.

## How to run

```matlab
cd main/research/OSI/damage_jump
make_damage_th     % builds data/damage_th.mat (+ data/damage_th_record.png)
run_osi7           % runs Method 7, writes results/osi7_damage.png + .mat
osi7_robustness    % optional: 20-seed detection statistics + results/osi7_robustness.png
```

## Result

Published `osi_method7_resonance.m`, unchanged. Bands retuned for this record:
peak `[25 42]`, floor `[55 75]` Hz (the damaged resonance at 39 Hz contaminates
the field-default floor `[42 58]`; the synthetic disturbance has no 60 Hz line, so
a clean high-frequency floor is used), 5 s buffer, 0.5 s hop, calibrated on the
first 7.5 s.

```
healthy-phase b : 0.590 ± 0.011        (matches the model nominal 0.588)
damaged-phase b : 0.402 ± 0.051        (true loop-only NCF = 0.344)
relative alarm  (b < 0.80·b_nom = 0.47): 20/20 seeds, ~2 s after the jump   <-- robust
absolute alarm  (b < 0.40)             : 13/20 seeds                        <-- marginal
```

**Method 7 works:** the indicator sits on the nominal margin in the healthy half
and drops cleanly after the jump, tracking the true degradation (0.588 → 0.344).
The healthy/damaged separation (0.59 vs 0.40) is ~5× the noise on the estimate.

**On the threshold:** Method 7 returns a *start-calibrated, relative* margin (see
`../claude_trial/M7.md` §5). For this mild degradation the true degraded margin
(0.344) sits **right at** the absolute 0.40 design line, and the sensitivity-peak
proxy maps it to ~0.40 ± 0.05 — so the absolute-0.40 alarm is only ~50/50 per
realisation by construction. The sound, robust decision for a relative indicator
is a **drop from the calibrated nominal**: `b < 0.80·b_nom` fires on every seed,
~2 s after the damage. That latency is set by the 5 s buffer straddling the jump.

## Files

```
make_damage_th.m       build the synthetic record
run_osi7.m             run Method 7 on it (the deliverable figure)
osi7_robustness.m      detection statistics over disturbance seeds
data/damage_th.mat     the record: t, dd, dd_lead, dc, dm, fm, fs, dt, switch_time, meta
data/damage_th_record.png   record + spectrogram (resonance brightening after 10 s)
results/osi7_damage.png      Method 7 margin time series
results/osi7_damage_result.mat
results/osi7_robustness.png  20-seed ensemble
```

The record is a drop-in for the other OSI trials: it exposes the same
`t, dd, dc, dm, fs` fields, so Methods 1–6 can be pointed at `data/damage_th.mat`
to confirm they are blind at 35 Hz under this low-band input (the case Method 7
was created for).
