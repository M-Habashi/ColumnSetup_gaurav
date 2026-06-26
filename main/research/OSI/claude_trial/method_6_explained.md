# Method 6 — Recursive Frequency-Point Kalman Filter (detailed)

A fast (0.5 s) online NCF-margin estimator that starts from the known model and
maintains **one Kalman filter per transfer-function point**, with the
**measurement noise R driven by the per-point coherence**.

---

## 1. Why the other methods cannot just use a 0.5 s window

Methods 1–5 get their reliability from **averaging inside each window** (Welch
with several sub-segments → a low-variance FRF and a usable coherence). A 0.5 s
window at `fs = 2048 Hz` is only 1024 samples: you get at most a couple of
sub-segments, the coherence is essentially undefined, and a single-window FRF is
far too noisy to read a stability margin from. Shrinking the window therefore
destroys the very averaging those methods depend on.

**Method 6 moves the averaging from *inside one window* to *across windows in
time*.** It keeps a running estimate of each TF point and fuses each new
(noisy, short-window) measurement into it with a Kalman filter. Reliability now
comes from temporal fusion, so the update window can be small and fast. The
catch — short windows have poor frequency resolution and individual snapshots
can be junk — is handled by making the Kalman **measurement noise adapt to the
coherence**, so bad measurements are automatically down-weighted or ignored.

---

## 2. State: one complex point per frequency

Pick a small grid of discrete frequencies bracketing the binding ~35 Hz
resonance,

```
f_i = 10, 11, ..., 58 Hz      (nf = 49 points)
```

The state is the complex plant transfer function at each point,
`H_i = H_dc_dm(j2πf_i)`. Each `H_i` is tracked by its **own scalar complex
Kalman filter** (49 independent filters). The model is a **random walk**, which
makes no assumption about *how* the plant drifts — only that it can:

```
H_i[k] = H_i[k-1] + w_i[k],     w_i ~ CN(0, Q_i)      (state / process)
z_i[k] = H_i[k]   + v_i[k],     v_i ~ CN(0, R_i[k])   (measurement)
```

**Initialisation from the known model** (the objective's "model correct at the
beginning"): `H_i[0] = H0(f_i)` from the `exp_tf` file, with a small initial
covariance `P_i[0] = (ρ·|H0_i|)²`, `ρ = 0.05` (we trust the model at `t = 0`).

## 3. Measurement: a short-window H1 point + its coherence

Every `m6_hop = 0.5 s` take the most recent `m6_buf = 1.5 s` of `dc` and `dm`
(a sliding buffer — fast updates, but enough data to resolve 35 Hz), split it
into `n_d ≈ 11` Hann sub-segments, and evaluate the spectra **exactly at each
`f_i`** with a DTFT matrix (no bin smearing). For each point:

```
z_i      = S_dc,dm(f_i) / S_dc,dc(f_i)                       (H1 estimate)
γ_i²     = |S_dc,dm|² / (S_dc,dc · S_dm,dm)                  (coherence)
γ_i²     ← max(0, (n_d·γ_i² − 1)/(n_d − 1))                  (small-sample bias removal)
```

## 4. The key idea — adaptive R from coherence

The random (noise-induced) error of an H1 transfer-function estimate is a
classic result (Bendat & Piersol). Its **normalized random error** is

```
ε_i = sqrt( (1 − γ_i²) / (2 · n_d · γ_i²) )
```

so the variance of the complex measurement is `(ε_i·|H_i|)²`. Method 6 uses
exactly this as the Kalman measurement noise, plus a small floor:

```
R_i[k] = ε_i² · |z_i|²  +  r_floor · |H_i|²
```

Interpretation:
* **High coherence** (the frequency is well excited, low noise) → `ε_i` small →
  `R_i` small → the Kalman gain is large → the state follows the measurement.
* **Low coherence** (poorly excited / noisy) → `ε_i` large → `R_i` large → the
  gain is ~0 → the state ignores that snapshot and keeps its current value.

This is what lets tiny, individually-unreliable 0.5 s measurements be used
safely: the filter automatically trusts each point only as much as its coherence
justifies. A hard **gate** (`γ_i² ≥ 0.5`) additionally skips updates on
points the short window simply cannot see, so noise can never inject a spurious
near-`(−1)` loop point.

## 5. Process noise R vs Q — the tracking knob

`Q_i = q_rel · |H_i|²` (with `q_rel = 0.02`) is the random-walk process noise.
It sets how fast a point may move: the steady-state Kalman gain rises with
`Q_i/R_i`, so `q_rel` is effectively the **tracking bandwidth / forgetting
time**. Large enough to follow the real drift (and the violent final collapse),
small enough that the stable phase stays smooth.

## 6. Kalman update (per point, per snapshot)

```
% measurement update (only for gated-in points)
K_i = P_i / (P_i + R_i)
H_i = H_i + K_i (z_i − H_i)
P_i = (1 − K_i) P_i
% covariance prediction for the next step  (Q AFTER the update → gentle start)
P_i = P_i + Q_i
```

Putting the `Q` prediction *after* the update means the very first update uses
the small prior `P0` and is gentle (no start-up overshoot).

## 7. From the points to a margin

With the known PID `C` evaluated at the grid, the loop point is `L_i = C(f_i)·H_i`,
and the indicator is a **robust low percentile** of the normalized loop
distance (not the raw min, which a single noisy point could dominate; the true
binding feature spans several adjacent points, so a 5th-percentile still
captures it while rejecting isolated spikes):

```
b[k] = prctile_5 ( |1 + L_i| / sqrt(2(1 + |L_i|²)) )
```

A short **median filter** (3 taps) on `b[k]` is the operational indicator, and
detection is declared when it stays below the 0.40 threshold for
`m6_detect_consec = 5` consecutive snapshots (2.5 s sustained), which rejects
transients while still firing fast.

## 8. Practical guards (learned from the data)
* **Warm-up.** The objective's window opens at 620 s but strong excitation only
  begins ~622 s; the filter is **frozen and the indicator held at nominal for
  the first ≈3 s** so the weakly-excited start cannot corrupt the state.
* **Bias-corrected coherence** removes the few-average upward bias that would
  otherwise let noise pass the gate.

## 9. Algorithm (one line per step)

```
init  H = H0(f_grid),  P = (0.05|H0|)^2
for each 0.5 s snapshot k:
    buffer  = last 1.5 s of (dc, dm)
    [z, γ²] = welch_point_FRF_and_coherence(buffer, f_grid)   % exact-freq DTFT
    if k <= warmup:  report nominal;  continue                % freeze
    R   = (1-γ²)/(2 n_d γ²) .* |z|²  +  r_floor|H|²
    upd = γ² >= 0.5
    K = P./(P+R);  H(upd) += K(upd).*(z(upd)-H(upd));  P = (1-K).P
    P += q_rel |H|^2
    b[k] = prctile5( |1+C·H| / sqrt(2(1+|C·H|^2)) )
report  median3(b),   detect if < 0.40 for 5 consecutive snapshots
```

## 10. Results on the test record (620–770.1 s)

| Quantity | Value |
|---|---|
| Update period / samples | **0.5 s / 298** (vs 10 s / 15 for M1–M5) |
| Start value | 0.589 (= nominal; warm-up hold) — **no start-up false alarm** |
| Stable-phase mean ± std | 0.613 ± **0.018** (smoothest of all methods) |
| Min before 705 s | 0.567 — **no false alarm during the healthy phase** |
| Detection (5×0.5 s < 0.40) | 733.8 s |
| Final collapse | **resolved at 0.5 s**: 0.43 → 0.05 across 766.2 → 767.8 s |

The defining result is the collapse: the 10 s methods see the final divergence
as a single point (they cannot say *when* or *how fast*), whereas Method 6 traces
the whole 0.43→0.05 drop in ~1.5 s (`results/method6_vs_others.png`, bottom).

## 11. Strengths, limitations, when to use
**Strengths.** 0.5 s time resolution and update latency; O(nf) per snapshot
(trivially real-time); the smoothest stable-phase output of any method; starts
exactly on the nominal value; uniquely resolves rapid collapses.

**Limitations.** Short buffers under-resolve the sharp 35 Hz dip (spectral
leakage), so the stable-phase margin reads slightly **optimistic** (≈0.61 vs the
0.57 of the accurate dd-instrument) and, with the conservative 5-sample rule, it
flags the *slow* erosion a little later than the 10 s methods (734 s vs 715 s).
It is a **fast guardian against sudden collapse**, complementary to — not a
replacement for — the accurate slow monitor (M3).

**Recommended use.** Run Method 6 as the high-rate trip alongside Method 3 as the
accurate slow estimate: M6 catches fast events within ~0.5–1.5 s; M3 gives the
precise margin for slow decisions.

## 12. Possible extensions
* **Adaptive Q** (innovation-driven): keep `Q` small while stable (less bias)
  and open it up when innovations spike (faster tracking of sudden change) —
  would remove most of the slow-phase bias without losing collapse speed.
* **dd-instrument measurement** (cfg switch): lower bias in the stable phase, at
  the cost of missing the collapse (the reference stops driving the loop once it
  self-oscillates), so it is *not* used by default for a detector.
* **Recursive coherence** (exponentially-weighted spectra) to allow an even
  shorter buffer while keeping a reliable coherence for R.

Implementation: `common/osi_method6_kf.m`; runner `trial_6/run_trial_6.m`;
parameters in `common/osi_config.m` (the `m6_*` fields).
