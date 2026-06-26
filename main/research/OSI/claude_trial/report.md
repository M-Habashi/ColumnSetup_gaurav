# Online Stability Indicator (OSI) — Trial Report

**Goal (from `objective.md`).** Build an online, window-based stability
indicator from the NCF margin that detects shrinkage of the closed-loop
stability margin during an experiment, using non-overlapping windows (so a
Kalman filter can be applied to the indicator later). Validate on the `Pvar`
test record over **620 → 770.1 s**, where the `exp_tf` model is assumed correct
at the start and the plant `H_dc_dm` drifts thereafter while the PID stays
fixed. Expected output: **a time series of the estimated margin** in that
window. Five methods were proposed (`proposed_solutions.md`), implemented
(`trial_1..5`), and compared (`run_all_and_compare.m`).

---

## 1. System and data facts established

| Quantity | Value |
|---|---|
| Sampling rate `fs` | 2048 Hz (`dt = 4.8828e-4 s`) |
| Controller `C` (constant, known) | PID `P=0.15, I=20, D=0.0015, N=512`, Forward-Euler |
| Loop | unity feedback, `L = C·H_dc_dm`; `dm = L·e`, `e = dd − dm` |
| Nominal loop-only NCF (repo `custom_stability_margins`) | **0.588**, binding at **≈ 35 Hz** |
| Nominal true 4-block margin `b_{P,C}` (`ncfmargin`) | 0.394 (binds at DC) |
| Gain crossover / closed-loop bandwidth | 1.36 Hz / 1.40 Hz |
| Analysis window | 620–770.1 s, `W = 10 s` non-overlap → **15 indicator samples** |

**Two findings that shaped every method.**
1. The NCF margin is **set at ≈ 35 Hz** (a lightly-damped actuator/specimen
   resonance), not at the low-frequency crossover. The reference `dd` is
   broadband (50 % of its energy below 41 Hz), so 35 Hz is well excited and a
   10 s window resolves it (0.25 Hz bins). The estimator must get the loop
   shape right near 35 Hz — which it does.
2. At the start of the window the measured loop matches the `exp_tf` model to
   within ≈ 5 %, and `rms(dm)` is flat (~0.08) until ≈ 700 s, then climbs and
   triples by 760–770 s (true divergence to −14.6 is just past 770 s). So the
   ground-truth behaviour is: **margin ≈ nominal early, collapsing after
   ~705 s** — exactly what a good indicator must reproduce.

---

## 2. Method comparison

Primary metric = repo loop-only NCF (`min_ω |1+L|/√(2(1+|L|²))` over 1–60 Hz),
so M1/M2/M3/M5 are directly comparable; M4 reports a drift/predicted-margin in
the gap metric. `Detect` = first window where the (raw / Kalman-smoothed)
indicator falls below 0.40 (M4: where ν-gap drift reaches the baseline margin).
`StableStd`/`Jitter` measure noise in the healthy phase (≤ 700 s). Runtime is
for the **whole 150 s record (15 windows)** on R2025b.

| # | Method | Start (nom 0.588) | Stable mean | Stable std | Jitter | End | Detect raw → KF | Runtime | Character |
|---|--------|------:|------:|------:|------:|------:|:--:|------:|---|
| **M1** | Nonparametric H1 (direct `dc→dm`) | 0.571 | 0.554 | 0.029 | 0.025 | 0.035 | **715 → 725 s** | 3.7 s | simple, faithful, mild closed-loop bias |
| **M2** | Parametric per-window (5p/3z `tfest`) | 0.639 | 0.586 | **0.081** | **0.064** | 0.103 | 685 (false) → 735 | 6.5 s | noisy, can over-state margin; gives poles + exact `b_{P,C}` |
| **M3** | **Closed-loop indirect (`dd` instrument)** | **0.581** | **0.570** | **0.020** | **0.009** | 0.088 | **715 → 725 s** | **3.0 s** | **smoothest, least biased, fast** |
| **M4** | Model-reference ν-gap drift (early-warning) | 0.406* | 0.206* | 0.161* | 0.072 | −0.381* | **685 → 685 s** | 6.2 s | earliest warning, coarse, fragile as a margin |
| **M5** | Recursive RLS tracker (256 Hz, λ=0.99) | 0.613 | 0.636 | 0.019 | 0.025 | 0.048 | 725 → 755 s | 2.9 s | smooth but biased-high & laggy; truly online |
| **M6** | **Recursive freq-point Kalman (0.5 s)** | 0.589 | 0.613 | **0.018** | **0.003** | 0.052 | 734 s | 5.4 s¹ | **0.5 s resolution; resolves rapid collapse; fast guardian** |

\* M4 values are the predicted-margin `b_{P,Ĥ₁} − δ_ν` (baseline 0.406), not the
loop-only NCF; its diagnostic output is the ν-gap **drift** (0 → 0.96).
¹ M6 runtime is for **298 updates** (≈18 ms each) vs 15 windows for M1–M5; it is
the cheapest *per update* and runs comfortably in real time. M6 uses 0.5 s
updates on a 1.5 s sliding buffer (see `method_6_explained.md`).

**Cross-method agreement (loop-only series).** M1↔M3 correlate at **0.995**;
all four loop-only estimators correlate ≥ 0.88. Independent estimators agreeing
this closely is strong evidence the indicator tracks a real, physical
margin collapse rather than an estimation artifact.

**Figures:** `results/comparison.png` (all loop-only methods incl. M6 + nominal /
0.40 threshold + Kalman-smoothed M3; bottom: M4 drift early-warning);
`results/method6_vs_others.png` (M6 0.5 s vs the 10 s methods + collapse zoom);
`results/all_indicators_overview.png` (signals + all six indicators). Raw
numbers: `results/comparison_table.csv` (+ `_method6.csv`); metrics:
`results/comparison_metrics.csv`; per-method plots: `results/trial_*.png`.

### What each method showed
- **M1 (H1 direct).** Clean trajectory 0.571 → 0.035, knee at 715 s. Reads a
  touch low in the healthy phase (closed-loop bias: output noise leaks into the
  `dc` "input"). Excellent simple baseline.
- **M2 (parametric).** Tracks the trend and uniquely yields closed-loop poles
  and the rigorous `b_{P,C}`, but per-window batch ID on 10 s of noisy
  closed-loop data is the **noisiest** (std 0.081), occasionally **over-states**
  the margin (a poor fit smooths the 35 Hz dip — dangerous for a monitor), and
  **false-alarms at 685 s**. Slowest.
- **M3 (`dd`-instrument).** Using the exogenous reference as an instrument
  removes the closed-loop bias: it starts essentially on the nominal value
  (0.581), is **3–10× smoother** than every other method (jitter 0.009), and
  detects cleanly at 715 s — all at the lowest cost. Best precise estimator.
- **M4 (ν-gap drift).** The only method using the `exp_tf`/start model as a
  baseline. Its drift rises monotonically (0 → 0.96) and crosses the baseline
  margin at **685 s — ~30 s earlier** than the margin methods, giving the
  earliest switch/pause trigger. But the ν-gap integrates model mismatch over
  all frequencies, so as a *numeric margin* it is the noisiest/most fragile;
  use it as a **binary early-warning**, not a precise value.
- **M5 (RLS).** Genuinely online (O(1)/sample) and smooth, but the forgetting
  factor and closed-loop bias make it read **optimistically high** (0.636 vs
  0.588) and detect **late** (725 s raw, 755 s after KF). Good for a continuous
  background tracker; tune λ for the responsiveness/smoothness trade-off.
- **M6 (recursive freq-point Kalman — fast).** Added to answer "make the window
  much smaller / detect within 0.5 s." One Kalman state per TF point, initialised
  from the known model and updated every **0.5 s** with **coherence-adaptive R**
  (see `method_6_explained.md`). It reaches reliability through *temporal* fusion
  rather than in-window averaging, so the window can be tiny. Result: the
  smoothest stable phase of all (jitter 0.003), no start-up false alarm, and —
  the headline — it **resolves the final collapse at 0.5 s** (0.43→0.05 across
  766.2→767.8 s) where the 10 s methods see a single point. Short buffers
  under-resolve the sharp 35 Hz dip (leakage), so it reads slightly optimistic on
  *slow* erosion and flags it a bit later (734 s) — a fast guardian, not a
  precise slow monitor.

**Small-window note.** Methods 1–5 cannot simply shrink to 0.5 s windows — they
rely on Welch averaging *inside* each window, which 1024 samples cannot provide.
Method 6 is the principled way to get 0.5 s resolution: it moves the averaging
*across time* (the Kalman recursion) and uses coherence to weight each noisy
short-window sample. So the answer to "smaller window" is not a parameter change
to M1–M5 but the M6 estimator.

### Kalman post-smoothing
A scalar random-walk KF + RTS smoother (`osi_apply_kf.m`) was applied to the
non-overlapping series. It removes M2's 685 s false alarm and denoises M5, at
the cost of ~one window of lag (M1/M3 detection moves 715 → 725 s). For a
safety monitor the **raw** non-overlapping series of M3 already detects at
715 s; the KF is most valuable for the noisy methods and for one-step-ahead
prediction. This realises the objective's intended downstream KF stage.

---

## 3. Recommendation

> **Use Method 3 (`dd`-instrument loop-only NCF, 10 s) as the accurate primary
> indicator and Method 6 (recursive freq-point Kalman, 0.5 s) as the fast trip,
> with Method 4 as a complementary early-warning, Method 1 as a fallback, and the
> scalar Kalman filter for smoothing/prediction — a two-rate monitor.**

Rationale: M3 is the most accurate (starts on the nominal margin), by far the
smoothest 10 s estimate, and the statistically correct estimator for closed-loop
data; M6 adds the **fast (0.5 s) layer** the smaller-window request needs.
Concretely:

1. **Accurate slow indicator — M3.** Per non-overlapping 10 s window compute
   `Ĥ = S_{dd,dm}/S_{dd,dc}`, `L̂ = C·Ĥ`, loop-only NCF. Warn when it crosses
   **0.40**; it does so at 715 s, ~55 s before divergence.
2. **Fast trip — M6.** Run the recursive freq-point Kalman filter at **0.5 s**
   updates in parallel. It is the only method that resolves a *rapid* collapse
   within ~0.5–1.5 s (the 10 s methods cannot), so it is the safety trip for
   sudden onset; M3 confirms the precise level.
3. **Early-warning — M4.** Model-reference ν-gap drift; trigger when drift →
   baseline margin (685 s here). Earliest but coarse — use it to *arm*.
4. **Smoothing — KF.** Feed M3's series through `osi_apply_kf` for a denoised
   estimate and a one-step-ahead prediction.
5. **Robustness guard.** If `dd` excitation collapses (once the loop
   self-oscillates), fall back to **M1**, which needs no instrument. M1↔M3 agree
   at 0.995 when `dd` is healthy. (M6 already uses `dc→dm`, so it stays valid
   through the collapse — the reason it, not M3, resolves the final divergence.)

M5 is recommended only as a low-rate background tracker (lag); M2 only where
physical poles or the exact `b_{P,C}` are needed offline, not as a live trigger.

---

## 4. How to reproduce

From MATLAB (R2025b; Control System, System Identification, Robust Control,
Signal Processing toolboxes):

```matlab
cd main/research/OSI/claude_trial
run trial_1/run_trial_1.m      % each trial prints its series and saves results/
run trial_2/run_trial_2.m      % ... trial_3, trial_4, trial_5 ...
run trial_6/run_trial_6.m      % Method 6: fast 0.5 s recursive-Kalman indicator
run run_all_and_compare.m      % runs all six, compares, Kalman-smooths, plots
run show_all_indicators.m      % 8-panel overview (signals + M1..M6 + collapse zoom)
```

`run_all_and_compare.m` writes `results/comparison.png`,
`method6_vs_others.png`, `comparison_table*.csv`, `comparison_metrics.csv`,
`comparison_results.mat`. Shared settings live in `common/osi_config.m` (window
length, band, FFT, RLS/KF parameters, the `m6_*` Method-6 parameters, the 0.40
threshold).

### File map
```
claude_trial/
  proposed_solutions.md      five base methods (theory)
  method_6_explained.md      Method 6 in detail (fast recursive-Kalman indicator)
  report.md                  this report
  common/                    shared helpers (config, data, NCF, Welch FRF, KF, M6 core, plot)
  trial_1 .. trial_6/        one runnable implementation per method
  show_all_indicators.m      8-panel overview figure
  run_all_and_compare.m      runs all six + builds comparison
  results/                   per-trial .mat/.png + comparison outputs
```

---

## 5. Limitations & next steps
- **No absolute ground truth** for the drifting margin; validation rests on
  (a) start ≈ nominal, (b) the physically-observed collapse, and (c) 0.99
  cross-method agreement. A controlled simulation with a known time-varying
  plant would give a quantitative error.
- **Window length `W = 10 s`** trades time-resolution against FRF quality
  (15 samples). `cfg.W = 5 s` doubles resolution at higher variance; worth a
  sweep. The binding 35 Hz feature is well resolved at both.
- **Band `[1, 60] Hz`**: low frequencies are unresolved in short windows, but
  the binding feature is at 35 Hz so this is not limiting here; revisit if drift
  ever produces a new low-frequency mechanism.
- **M4/ν-gap** would benefit from a fixed, regularised low-order fit and longer
  windows, or from a nonparametric gap restricted to the gain-weighted band.
- **Next:** wire M3 + KF into the live HS loop with the 0.40 trigger and the M4
  early-warning, and add the controller-switch/pause action the objective asks
  for.
