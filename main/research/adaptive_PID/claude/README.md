# Adaptive PID via the M9.1 online NCF margin

Make the inner actuator-loop PID **adaptive**: read the normalized-coprime-factor (NCF)
stability margin online with the canonical OSI estimator **M9.1**
(`control_and_HS/OSI/m91_adaptive_margin.m`, used in its `step` runtime mode — *not* a
re-implementation), and adjust the controller to keep that margin **at/above a target
(default 0.50)**. The penalty is **asymmetric**: being below target is corrected fast and
hard; performance is given back only slowly and only once comfortably above target
("accept higher, highly penalize lower").

Everything tunable lives in **`adaptive_config.m`** (the parametric file): `b_target`,
the asymmetric law gains, the per-method actuation bounds, the damage scenario, and the
M9.1 overrides.

## The loop and the scenario

Inner loop (per `vHS`): `dc = a·F·C·(dd_lead − dm)`, `dm = H_dc_dm·dc + disturbance`.
The adaptive parameter sits **after the PID and before `H_dc_dm`** (the authority gain
`a`), plus optional controller-shaping blocks (integral scale, low-pass, notch).

Each case is a **healthy → damaged JUMP** at `t = switch_s` (same convention as the OSI
`damage_jump` work): M9.1 calibrates on the healthy prefix, the margin drops at the jump,
and the adaptive law restores it. The loop is stepped **sample-by-sample** with fixed
dynamic sub-blocks and **time-varying scalar gains** (the plant is strictly proper, so the
state stays continuous as the controller adapts). The analytic "true" NCF of the live loop
is logged alongside the M9.1 estimate at every window.

The 5 cases (`optimizing_pl/claude/osi_test_cases.m`), each a different margin-loss
mechanism and binding frequency:

| case | mechanism | true NCF (baseline) | binds at |
|------|-----------|:---:|:---:|
| C1 | healthy reference | 0.59 | 35 Hz |
| C2 | gain damage (7000→5000 specimen) | 0.34 | 38 Hz |
| C3 | excess gain (3.8× plant) | 0.25 | 36 Hz |
| C4 | integral-driven (10× I) | 0.09 | 20 Hz |
| C5 | phase-lag (160-sample delay) | 0.31 | 2.5 Hz |

## The 5 adaptive methods

All share the asymmetric law (`margin_law.m`); they differ in how the normalized knob maps
to the controller and whether they use M9.1's **binding frequency** (`f_st`).

1. **M1 — Authority gain reduction** `a` (the suggested idea). Scale P, I, D uniformly.
   Universal, monotone, sign-safe. The workhorse.
2. **M2 — Integral-branch detuning** `g_I`. Best for the *integral-driven* mechanism (C4).
   Self-gates **off** unless `f_st` confirms a low-frequency resonance (it has the wrong
   sign for high-band damage), so it is a safe specialist.
3. **M3 — Adaptive low-pass roll-off** `f_c`. Frequency-selective gain cut for *high-band
   gain damage* (C2/C3). Self-gates **off** unless `f_st` confirms a high resonance.
4. **M4 — Frequency-scheduled detuning.** Use `f_st` to pick the *cheap* targeted knob
   (integral for an observable mid-low resonance, else authority); if that knob saturates
   without moving M9.1, **fall back to authority**. Universal + minimal intervention.
5. **M5 — Authority + adaptive notch.** Place a notch at `f_st`, deepen it first, then add
   authority. On resonant cases the notch claws back margin so far less uniform gain is
   sacrificed (bandwidth-preserving); where there is no observable resonance it is pure
   authority.

**Key robustness rule:** `f_st` (the phase-aware S,T-branch binding) is the *reliable*
frequency. When it is `NaN` — the dangerous mode is **not frequency-observable** (e.g.
C5's 2.5 Hz delay dip sits at the band edge) — the safe action is **uniform authority**,
never a targeted one. This is what keeps M3 from wrongly low-passing C5.

## Results (converged true NCF margin; `*` = ≥ target 0.50)

| case | baseline | M1 auth | M2 integ | M3 LP | M4 sched | M5 auth+notch |
|------|:---:|:---:|:---:|:---:|:---:|:---:|
| C1 | 0.59* | 0.59* | 0.59* | 0.59* | 0.59* | 0.59* |
| C2 | 0.34  | 0.61* | 0.34  | 0.54* | 0.67* | 0.64* |
| C3 | 0.25  | 0.65* | 0.25  | 0.47  | 0.65* | 0.64* |
| C4 | 0.09  | 0.63* | 0.60* | 0.09  | 0.63* | 0.59* |
| C5 | 0.31  | 0.66* | 0.31  | 0.31  | 0.66* | 0.66* |

- **M1, M4, M5 are universal** — they hold the true margin ≥ 0.5 on every mechanism.
- **M2 (C4) and M3 (C2)** are clean specialists: they fix their mechanism and **safely
  no-op** (never harm) elsewhere, gated by `f_st`.
- **No false adaptation on C1** (the parameter never moves on the healthy reference).
- **M9.1 conservatism:** on the low-frequency cases C4/C5 the *estimate* saturates near
  0.5 even at full safe authority (it reads 0.15 vs true 0.31 at C5 baseline). Targeting
  0.5 on the estimate therefore yields a **true** margin of ~0.6 — a built-in safety
  factor that is exactly the "highly penalize lower" behavior requested.

## Files

| file | role |
|------|------|
| `adaptive_config.m` | **all tunable parameters** (target, law, bounds, scenario, M9.1) |
| `adaptive_methods.m` | declarative spec of the 5 methods |
| `margin_law.m` | the asymmetric knob update |
| `simulate_adaptive_case.m` | sample-accurate adaptive closed loop + online M9.1 |
| `load_adaptive_ctx.m` | loads the 5-case battery + PID parameters |
| `run_adaptive_study.m` | **entry point** — runs everything, makes the figures |
| `results/method_M*.png` | per-method: adapted parameter (top) + NCF margin with vs without (bottom), all 5 cases |
| `results/scorecard.png` | converged margin by case and method (true + M9.1) |
| `results/adaptive_results.mat` | all series for reproducibility |

## Run

```matlab
addpath(genpath(fullfile(project_root,'control_and_HS','OSI')))   % canonical M9.1
results = run_adaptive_study();                       % defaults
results = run_adaptive_study(struct('b_target',0.55)) % change the target, etc.
```
