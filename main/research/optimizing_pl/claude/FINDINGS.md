# Damage-robust phase lead, damage prediction, and online stability

Answers to the three questions, grounded in the actual saved models
(`tf_sp_1_7000`, `tf_sp1_5000`, `sp1_7000`, `sp1_5000`, `pl_sp1_7000`,
`pl_sp1_5000`, `fem_sp1_7000`). Every number below is reproduced by
`run_robust_pl_study.m` in this folder.

---

## TL;DR

1. **Q1 — criterion.** Stop optimizing one specimen / one `H_dc_dm`. Score the
   **worst case over a damage bracket** and make stability a *hard* gate, not a
   soft floor on the nominal: `max_i |pole|_i < 1` and `min_i NCF_i ≥ 0.30–0.35`,
   then minimize the worst-case performance `max_i J4_i`. Use **NCF as the
   primary gate, not GM** — GM is blind to phase and even reported `Inf` on an
   actually-unstable damaged loop. The robust optimum is a *gentle* lead
   (ratio ≈ 2), which neither single-level lead finds.

2. **Q2 — prediction.** Yes, simply. On the **deployed** `H_dc_dm`, damage is
   almost a pure **magnitude gain** `γ ≥ 1` (≈ **2.4×, +7.7 dB**, only ~5° phase
   for 7000→5000) plus a drop of `k_exp` to ~0.75×. This is *multiplicative*, so
   it **extrapolates** (push `γ` up / `k_exp` down) and **transfers to a
   different baseline** `H_dc_dm` (apply `γ` to the new healthy model). The
   grey-box physical parameters do **not** transfer — they are non-identifiable
   here (`Kp` differs by 10⁹× between the two fits).

3. **Q3 — online.** No single PID gain or lead parameter is a monotone stability
   knob — proven below (integral `I` and lead ratio are non-monotone, and lead
   ratio pushes the healthy and damaged plants in **opposite** directions). The
   fix is to add **one external "authority" scalar** that scales the loop gain
   down (monotone: it only pulls the dominant pole inward), and **schedule it
   online** from the margin estimator you already built in
   `research/OSI` (Method 7: `Spk → b`).

---

## The loop

The compensated RTHS path the optimizer must protect is

```
ag → [numerical substructure num_tf] → dd → [phase lead G_T] → dd_lead
        → [actuator loop  T = feedback(C_pid·H_dc_dm, 1)] → dm → force = k_exp·dm ↺
```

and the loop transfer function whose margins matter (this is exactly the
optimizer's `num_delay_comp_exp` object) is

```
L = − num_tf · (k_exp/1000) · G_T · feedback(C_pid · H_dc_dm, 1)
```

Damage enters in **two** places: inside `H_dc_dm` (the MTS inner loop "feels" the
softer specimen) **and** through `k_exp` (the force-feedback gain).

---

## Evidence (all from the real files)

**Specimen (SI).** healthy `m=44.1, c=34.3, k=7.20e6`; damaged
`m=54.9, c=996, k=5.38e6`; `k_damaged/k_healthy = 0.747`.

**Damage on the deployed `H_dc_dm` is a near-pure gain.** Over 1–20 Hz,
`|H5|−|H7| = +8.0 dB` with only `+4.9°` phase. A single scalar fit gives

| band | best `γ` | residual |
|---|---|---|
| 0.5–40 Hz | 2.42 (+7.7 dB) | 0.55 dB |
| 5–30 Hz | 2.40 (+7.6 dB) | **0.23 dB** |
| 5–45 Hz | 2.50 (+8.0 dB) | 0.93 dB |

**The surrogate `γ·H_dc_dm` reproduces the damaged loop margins** (so it is good
enough to *design* against):

| case | actual H5 | surrogate `2.5·H7`, `k_exp=k5` |
|---|---|---|
| no-lead NCF | 0.375 | 0.378 |
| lead5 NCF | 0.300 | 0.300 |
| lead7 NCF | 0.246 (pole 1.011 → unstable) | 0.111 (captures the collapse) |

**The grey-box physics model does NOT transfer.** The identified actuator/inner
parameters that should be hardware constants instead jump between the two fits:
`a2 ×2.1, beta2 ×3.3, Ki ×5.5`, and **`Kp` from 1.0e13 to 1.1e4 (×1e-9)**. Also
the `H_dc_dm` that vHS actually uses differs from the saved parametric
`H_dc_dm_param` by **5.2 dB** RMS on the healthy case. ⇒ predict damage with the
*multiplicative* model, not the physical parameters.

**No single lead is robust.** Per-member NCF / `max|pole|` over the bracket built
from the healthy baseline (plus the real measured damaged plant):

| member | no-lead | lead7 | lead5 |
|---|---|---|---|
| ρ=0 healthy | 0.256 / 0.9999 | 0.300 / 0.9998 | 0.286 / 0.9999 |
| ρ=1 (γ2.4,k75%) | 0.373 / 0.9999 | 0.083 / **1.004** | 0.307 / 0.9998 |
| ρ=2 (γ3.8,k49%) | 0.482 / 0.9998 | 0.259 / **1.010** | 0.268 / 0.9998 |
| measured sp1_5000 | 0.375 / 0.9999 | 0.246 / **1.011** | 0.300 / 0.9998 |

`lead7` (tuned on healthy, NCF 0.300 there) **destabilizes every damaged case**.
GM is misleading: on the unstable `H5+lead7` it returns `Inf`.

---

## Q1 — the best optimization criterion

### What is wrong with the current one
`scoreVhsPhaseLead` minimizes `J4` on **one** plant and adds a *soft* penalty if
the *nominal* `num_delay_comp_exp` NCF `< 0.3`. Optimizing on healthy yields
`lead7`, which is **unstable** on the damaged specimen. A single-plant objective
cannot see that.

### Recommended criterion (min–max, lexicographic)

Evaluate every candidate `G_T` on a **damage bracket** `𝒟` (see Q2 /
`damage_bracket.m`) and use:

```
feasible(G_T)  ⇔  max_{i∈𝒟} |pole|_i ≤ 1 − δ        (hard, δ ≈ 0.005–0.02)
                  AND  min_{i∈𝒟} NCF_i ≥ b_target    (b_target = 0.30–0.35)

among feasible:  minimize  max_{i∈𝒟} J4_i   (+ small·mean_i J4_i  tie-break)
```

As a single differentiable score for the grid + `fmincon`:

```
score =  max_i J4_i  +  0.25·mean_i J4_i
       +  w_ncf · max(0, b_target − min_i NCF_i)^2
       +  w_pole· max(0, max_i |pole|_i − (1−δ))         % hard barrier
```

This is implemented in `robust_pl_score.m` (stability part) and demonstrated by
the grid search in `run_robust_pl_study.m`.

### Why NCF, not GM, as the gate
For the loop-only NCF margin `b`, classical margins are *guaranteed*:
`GM ≥ (1+b)/(1−b)` and `PM ≥ 2·asin(b)`. So `b = 0.30 ⇒ GM ≥ 5.4 dB and
PM ≥ 35°` **simultaneously** — one number bounds both. Your experimental floor
"NCF 0.3 *or* GM 7" is consistent with this (NCF 0.3 already buys ~5–7 dB GM).
GM alone misses phase and goes blind on unstable loops. **Keep NCF as primary;
keep `max|pole|<1` as the hard gate; treat GM ≥ 7 as a secondary check.**

### What it finds
Searching a (center, ratio) lead grid for the best **worst-case** NCF:

```
worst-case NCF:  no-lead 0.256 | lead7 0.083 | lead5 0.268 | ROBUST(c≈12,N≈2) 0.296
```

The robust optimum is a **gentle lead (ratio ≈ 2)**, stable on all members
(`max|pole| 0.9999`). Aggressive leads (ratio ≥ 5) collapse the worst case to
0.01–0.08. Note the *healthy* member becomes the binding one (0.296) — to clear
0.35 everywhere with margin you must **co-tune the PID** (lower `I`; see Q3-d),
i.e. extend the optimizer to search `(G_T, I)` jointly against the same bracket.

### "Even further excess damage remains stable"
Because `𝒟` includes extrapolated members (`γ` up, `k_exp` down) **beyond** the
specimen you measured, a design that is feasible on `𝒟` is certified for damage
you have not yet tested — this is multiplicative-uncertainty robust design, not
curve-fitting to two specimens. Push `rho_max` until the worst-case feasibility
just holds to read off the damage level your compensator can survive.

---

## Q2 — predicting damage on `H_dc_dm`

**Yes.** The defensible, transferable model is multiplicative:

```
H_damaged(s) ≈ γ · H_healthy(s),   γ = γ(damage) ≥ 1   (γ ≈ 2.4 for 7000→5000)
k_exp(damage) = scale · k_healthy   (scale ≈ 0.75)
```

- **Predict further excess damage:** parameterize both by one damage coordinate
  `ρ` (`damage_bracket.m`): `γ(ρ)=1+ρ(γ_meas−1)`, `k(ρ)=1+ρ(k_ratio−1)`. `ρ>1`
  extrapolates. With only two calibration points treat this as an *envelope to
  design against*, not a point prediction — and recalibrate `γ` as you collect
  more damage levels (or estimate it online; see Q3).
- **Different initial `H_dc_dm`:** the law is *relative*, so it transfers. Identify
  the new healthy `H0` once, then bracket damage as `γ·H0`. (Absolute pole/zero
  locations and the grey-box params do **not** transfer.)
- **Why not the grey-box `(m,c,k)` route:** structurally it should let you swap
  the specimen and keep the actuator block — but the identification here is
  ill-conditioned (Kp varies 10⁹×; freezing healthy actuator params + damaged
  `(m,c,k)` predicted the damaged FRF to only 4.8 dB / 24° — worse in phase than
  doing nothing). If you want the physics route to work, constrain the fit:
  identify `{a2,a3,β1,β2,Kp,Ki}` once on a richly-excited healthy test and
  **fix** them, re-fitting only `(m,c,k)` per specimen, with regularization.

---

## Q3 — online stability with ONE monotone knob

### Why PID / lead knobs are not monotone (measured)
- **Integral `I`** (healthy plant, P,D fixed): NCF `0.642 (I=2) → 0.256 (I=20) →
  0.029 (I=160)` — monotone *down* in robustness as you raise `I`, while too-low
  `I` loses force-tracking authority (a performance-driven instability the linear
  margin misses). `I` sits between two failure modes — exactly your experience.
- **Lead ratio** (center 8 Hz): on the **healthy** plant NCF peaks near ratio 5
  then falls; on the **damaged** plant `max|pole|` rises monotonically
  `0.9998 → 1.027` as ratio grows. The same knob helps one plant and destabilizes
  the other. There is no shared monotone direction.

### A knob that is monotone by construction
Add a single scalar **authority** `a ∈ (0,1]` (or `κ = 1−a` that you *increase*)
that scales the whole actuator command / loop gain:

```
dd_to_actuator = a · G_T · dd        (lower a ⇒ lower loop gain)
```

Measured on a fragile case, `max|pole|` falls **monotonically** as `a` drops:

```
a:        1.00   0.90   0.80   0.70   0.60   0.50
max|pole|:1.010  1.008  1.006  1.004  1.002  0.9997   → crosses into stable
```

Rationale: at `a→0` the closed loop tends to the (stable) open-loop poles of
`num_tf`, `T`, and `G_T`; raising `a` is a root-locus that pushes the dominant
branch out. Reducing `a` only pulls it back in. It is the same axis damage moves
along (damage ≈ raising an effective gain `γ`), so `a` is the natural antidote:
hold `a·γ ≈ const`. (NCF itself dips during the transition, so **track
`max|pole|` / the resonance margin, not raw NCF, as the monotone indicator.**)
For the high-frequency/delay side, a command **low-pass whose corner you lower**
is an equally monotone alternative.

Cost: `a<1` trades force-tracking performance for stability — which is exactly
what you want from a safety knob.

### Close the loop with your OSI work
You already have an **output-only** online margin estimate in
`research/OSI` (Method 7): `Spk = sqrt(peakPSD/floorPSD of dm)` ≈ `‖S‖∞`, and
`b ≈ b_nom · Sref/Spk` provably tracks the true loop NCF (`proof3`). Use it
directly:

```
estimate b̂(t) from dm  →  if b̂ < b_alarm (e.g. 0.30):  raise κ (lower a)
                          else slowly relax κ toward 0
```

This is one knob, guaranteed direction, driven by a validated online margin —
far safer than retuning `P`/`I` live. `Spk` also *measures* the effective `γ`
(damage), so it doubles as the online recalibration signal for Q2.

---

## Where the instability lives (~37 Hz) and predicting it

The recurring ~35 Hz is **not** the specimen mode and **not** a numerical mode.
It is the **actuator inner-loop −180° phase frequency** — where the closed MTS
loop `T = feedback(C_pid·H_dc_dm, 1)` finishes inverting the command:

```
∠T = −180°:   healthy 37.4 Hz ,  damaged 40.0 Hz
specimen mode sqrt(k/m)/2pi:  healthy 64 Hz ,  damaged 50 Hz   (higher; not it)
coupled unstable pole (H5+lead7):  42.4 Hz, |z|=1.011
```

At that frequency the actuator output is 180° out of phase, so closing the
force-feedback loop (`k_exp·…`) reinforces it — a control–structure-interaction
(CSI) resonance. It behaves like an **effective loop delay** `τ_eff ≈ 13 ms`
(`f₁₈₀ ≈ 1/(2·τ_eff)`), set by the servo-hydraulics + inner MTS loop + sampling.

**What moves it (from sweeps):**

| change | effect on the ~37 Hz frequency |
|---|---|
| specimen `k` / damage `γ` | barely moves (37→40 Hz); it changes the **gain** at 37 Hz (whether you cross), not the frequency |
| outer `P` | raises the coupled crossover toward 37 Hz as loop gain grows (P=1 → 33 Hz binds) |
| outer `I` | **U-shaped**: low `I` lets the 37 Hz actuator mode bind; high `I` makes a low-freq integrator mode bind → instability from **both** sides |
| transport delay | small here (gain-limited), but adds to `τ_eff` when the HF mode is active |

So: **frequency is set by the actuator (`H_dc_dm` + PID); damage/`k_exp`/lead set
the gain there, i.e. whether it goes unstable.**

**Predicting it for a new experiment** (you identify `H_dc_dm` anyway):

```
f_inst  ≈ frequency where  ∠feedback(C_pid·H_dc_dm, 1) = −180°      (one line)
onset   = |L(j2π f_inst)| = 1/GM ,  L = −num_tf·(k_exp/1000)·G_T·feedback(C_pid·H_dc_dm,1)
```

You cannot get `f_inst` from `k, P, I` alone — `k` only shifts it a few Hz and `P,I`
move *which* mode binds. But given the identified `H_dc_dm`, `f_inst` is
predictable and stable across experiments, and the phase-lead should put its
phase peak **near `f_inst`** while keeping the ratio modest (extra gain at
`f_inst` is what destabilizes the damaged plant). Caution: as the specimen
softens, its mode (64→50 Hz) descends **toward** the ~40 Hz actuator crossover,
so heavy damage also risks mode coalescence near 40 Hz.

## Low-pass at the highest mode vs a higher-order (notch+lead) compensator

Structural modes are **2.4, 8.7, 18.1 Hz**; the instability is the ~37 Hz
actuator CSI mode. A low-pass with corner in the gap (~25 Hz) is the intuitive
fix, but measured over the damage bracket (worst-case NCF) with a true
time-domain performance metric `J4` (floor-1 RMS error vs reference, %):

| compensator | worst NCF | max\|pole\| | J4 healthy | J4 damaged |
|---|---|---|---|---|
| none | 0.256 | 0.9999 | 88 | 48 |
| **LP @ 25 Hz** | **0.225** | 0.9999 | **100** | **56** |
| plain lead `pl7` | 0.083 | **1.011** (unstable) | 15 | — (blows up) |
| notch@37 + lead(z6,p18) | 0.298 | 0.9999 | 73 | 36 |
| **notch@37 + lead(z3,p15)** | **0.320** | 0.9999 | **49** | **17** |
| notch@37 + lead(z2,p12) | 0.251 | 0.9998 | 34 | 5 |
| lead-lag roll-off (z5,p15,r30) | 0.282 | 0.9999 | 69 | 32 |

**A plain low-pass is the wrong tool — it hurts both axes.** It cuts gain
*broadband*, so it adds phase **lag** in the structural band (−5° @2.4 Hz,
−22° @10 Hz). That lag (i) is an effective delay → worse RTHS tracking
(J4 88→100%), and (ii) erodes the **2.4 Hz mode margin, which is what actually
binds the worst case** → NCF 0.256→0.225. The low-pass only pays off when the
37 Hz CSI mode is the binding one (heavy damage, or after an aggressive lead
pushed the crossover up to 37) — i.e. as a damage-triggered emergency roll-off
scheduled by the OSI margin, **not** as a fixed performance filter.

**A higher-order lead is the right tool — decisively.** The first-order lead is
too blunt: it buys in-band phase but pays with +17 dB of gain at 37 Hz, which is
exactly what destabilizes the damaged plant. A **notch at the CSI frequency +
an in-band lead** *decouples the two jobs*:
- the **notch** removes loop gain **only at ~37 Hz** (−10 to −14 dB there),
  preserving in-band phase (unlike the broadband low-pass);
- the **lead** supplies the in-band phase that performance and the 37 Hz phase
  margin need.

`notch@37 + lead(z3,p15)` gives **worst-case NCF 0.320 (clears your 0.30 floor),
stable across the whole bracket, and J4 49%/17%** — most of the aggressive
lead's performance without its fragility. Pushing more in-band lead (z2, z1.5)
keeps improving `J4` (down to ~5%) but walks off the robustness cliff
(NCF < 0.30): there is a real performance–robustness frontier, with the knee
around `notch@37 + lead(z3,p15)`. This is the 2-pole/2-zero family you already
started (`fem3_ncf4_2p2z.mat`) — optimize **that** structure with the min-max
damage-bracket criterion, not a first-order lead.

Practical notes: center the notch at `f_inst` (the actuator −180° frequency) and
make it wide enough to cover the damage drift (37→~42 Hz) or schedule it; a
sharp notch can ring, so the smooth lead-lag roll-off (NCF 0.282) is a gentler
alternative. The residual ceiling on worst-case NCF is set by the **2.4 Hz mode
(a PID job — lower `I`)**, so co-tune `I` with the compensator.

## Scheduling the authority scalar: good performance before AND after damage?

Short answer: **only if you schedule it (one fixed value can't do both), and only
if you blend toward a *robust* controller rather than toward nothing.**

Healthy wants full authority (`a=1`, J4 15%); but at `a=1` the damaged plant is
unstable, so after damage you must drop `a`. Three ways to apply the scalar,
measured (J4 = floor-1 error %, `pole_D` = damaged pole radius):

**A) command scale `a·G_T`** (scales the whole command → *under-drives* the
specimen): damaged needs `a≈0.2` for `NCF≥0.3` → **J4_damaged ≈ 43%**. Costly,
because it biases the displacement amplitude.

**B) blend toward no-lead `(1−a)+a·G_T`** (unity DC, no amplitude bias): damaged
`a≈0.2` → J4 28%, `a=0` (no lead) → J4 48%. Better than A.

**C) blend two *good* controllers `(1−a)·[notch+lead] + a·[aggressive lead]`** —
the best:

| `a` | J4 healthy | J4 damaged | pole_H | pole_D |
|---|---|---|---|---|
| **1.0** (use when healthy) | **15%** | unstable | 0.9998 | 1.011 |
| 0.6 | 23% | unstable | 0.9998 | 1.001 |
| 0.4 | 30% | 3% | 0.9998 | 0.9998 |
| **0.0** (use when damaged) | 49% | **17%** | 0.9999 | 0.9998 (NCF 0.342) |

So **schedule `a=1` before damage, `a→0` after**: you get **J4 ≈ 15% healthy and
≈ 17% damaged, both with safe margin** — "good performance before and after" from
one scheduled scalar, *because the two endpoints are both good designs*.

Caveats that decide whether this is safe in practice:
1. **No single fixed `a` works** — healthy needs `a=1`, damaged needs `a≤0.4`.
   You must change it online (which is the premise of the question).
2. **The transition passes through an unstable band on the damaged plant**
   (`a=0.6–0.8` give `pole_D>1`). `pole_D` is monotone in `a` (lower `a` =
   safer), and lowering `a` is *always* safe when healthy — but if damage hits
   while `a=1` you are already unstable, so you must drop `a` **decisively and
   fast**, triggered by the OSI Method-7 margin, not creep it down.
3. Authority scheduling is a **performance-recovery layer on top of a robust
   base**, not a substitute for one. If you do not trust online detection, just
   run the notch+lead always (J4 49%/17%, both safe, no switching risk); schedule
   `a→1` only to *buy back* healthy performance (15%) when margin is ample.

## The inner PID+H_dc_dm loop IS the 37 Hz weak point — scale the PID (`PID·a`)

The ~37 Hz is the **inner tracking loop** `T = feedback(C_pid·H_dc_dm, 1)`
reaching −180°. Damage (×γ on `H_dc_dm`) directly erodes its gain margin:

| plant | inner GM | f₋₁₈₀ | peak‖T‖ | inner loop |
|---|---|---|---|---|
| healthy | **16.4 dB** | 37.4 Hz | 0.82 | stable |
| damaged (meas) | **6.9 dB** | 40.0 Hz | 0.96 | stable (fragile) |
| γ=3.8·H7 | 4.8 dB | 37.4 Hz | 1.47 | resonant |
| → inner loop **unstable at γ ≥ 6.6** | | | | |

Damaged inner GM (6.9 dB) ≈ your experimental **"GM of 7"** stability threshold —
i.e. that floor is the *inner-loop* gain margin, and damage pushes you onto it.
At the measured damage the inner loop is still stable; the instability we saw
(plain lead, damaged) is the outer loop tipping over **at the inner loop's
37 Hz weak point**, with the lead's +17 dB gain there as the trigger. Under heavy
damage (γ≥6.6) the inner loop fails on its own and no outer-path trick helps.

**Scaling the PID by `a` (`a·C_pid`) is the right authority knob — and better
than scaling the command/lead.** On the damaged plant with the (unstable) plain
lead, matched `a`:

| `a` | `PID·a`: NCF / pole / **J4_D** | command `G_T·a`: NCF / pole / **J4_D** |
|---|---|---|
| 1.0 | 0.246 / 1.011 / unstable | 0.246 / 1.011 / unstable |
| 0.6 | 0.104 / **0.9998** / **4.4%** | 0.027 / 1.001 / unstable |
| 0.4 | 0.324 / 0.9998 / **20%** | 0.159 / 0.9998 / 27% |
| 0.2 | 0.496 / 0.9998 / 46% | 0.419 / 0.9998 / 43% |

`PID·a` stabilizes the damaged+lead case at `a=0.6` with **J4 4.4%** (command
scale is still unstable there), and clears a safe NCF (0.324) at `a=0.4` with
J4 20%. Why it wins: the **integrator keeps closed-loop DC gain = 1 for any
`a>0`**, so reducing `a` lowers loop gain (suppresses the 37 Hz peak: ‖T‖
0.96→0.90→0.80) and restores the inner GM **without under-driving the
specimen** — it costs *bandwidth*, not *amplitude*. Lowering `a` is always safe
on the healthy plant (inner GM only grows).

Practical notes:
1. Scale **all** gains together (`a·P, a·I, a·D`) to keep the PID shape and just
   slide the gain-crossover down.
2. As `a` drops, the inner **dominant pole moves toward z=1 — that is a slow,
   stable mode, not instability.** Use **peak‖T‖ / inner GM (or the OSI Spk)** as
   the inner-loop robustness indicator, not `max|pole|`. Don't go below ~0.3–0.4
   (bandwidth/tracking collapses: J4 46% at `a=0.2`).
3. This unifies with the OSI: **`Spk` reads the 37 Hz inner resonance ≈ the
   inner sensitivity peak ≈ inner GM**, and `PID·a` is the knob to hold inner
   GM ≥ 7 dB online. Prefer `PID·a` over the lead/command scalar as the primary
   authority knob; keep the notch+lead as the fixed structure underneath.

## Predicting the required authority, estimating NCF, and regulating it online

### The required `a` is closed form (no search)
Scaling the PID by `a` (`a·C_pid`) scales the inner open loop `L = a·C_pid·H_dc_dm`
**uniformly at every frequency**, so the phase — hence the ~37 Hz −180° crossover —
is unchanged and the inner gain margin is exact:

```
GM_dB(a) = GM_dB(1) − 20·log10(a)        (predicted = actual to 0.01 dB)
⇒  a_required = 10^((GM_dB(1) − GM_target)/20)
```

Verified (`predict_inner_margin.m`): healthy inner GM 16.4 dB, damaged 6.9 dB;
to hold a **10 dB** inner GM the damaged plant needs **a = 0.698** (and the model
returns exactly 10.0 dB there). The damaged inner GM (6.9 dB) ≈ your experimental
**"GM of 7"** floor — i.e. the floor *is* the inner-loop gain margin. The inner
loop alone goes unstable at γ ≥ 6.6 (≈2.7× the measured damage).

### Can we estimate NCF from this? Yes — two complementary ways
1. **Inner NCF tracks inner GM 1:1.** The inner loop has a single binding
   resonance (37 Hz), so its NCF and GM carry the same information (measured):

   | inner GM | 6.9 | 8.8 | 11.3 | 14.8 | 17.3 dB |
   |---|---|---|---|---|---|
   | inner NCF | 0.34 | 0.42 | 0.49 | 0.57 | 0.60 |

   So an online inner-GM (or OSI `Spk`) estimate gives inner NCF directly, and the
   analytic bound `b ≤ (g−1)/(g+1)`, `g=10^(GM_dB/20)` (in `predict_inner_margin`)
   brackets it. `Spk ≈ ‖S_inner‖∞` is itself an NCF-type peak-sensitivity reading,
   so **your OSI Method 7 already estimates this margin output-only.**
2. **Coupled NCF is regulated indirectly.** It is *not* a pure function of inner
   GM (it also depends on the lead and which mode binds), but with the robust
   **notch+lead** base it is **monotone in `a`** (no unstable dip): on the damaged
   plant `cplNCF` rises 0.342→0.440 and `cplGM` 11.9→23 dB as `a`:1→0.3. So pick
   the inner-GM setpoint that was validated (offline, over the damage bracket) to
   keep coupled NCF ≥ target, then hold that setpoint online.

### Is closing a loop on the margin error a good idea? Yes — with guards
Updating `a` from the margin error `e = GM_set − GM_est` (an integral/supervisory
regulator, `authority_regulator.m`) is sound **specifically because the
margin-vs-`a` map has a fixed, known sign** (lower `a` ⇒ higher GM, monotone and
closed form). The integral correction can never chase the wrong direction — unlike
retuning `P`, `I`, or the lead ratio, whose sign flips. Demonstrated under damage
ramping γ:1→4 with a noisy (±0.4 dB) estimate: `a` walks 1.0→0.65 and the coupled
loop is held at **NCF 0.32–0.43, GM ≥ 16 dB** throughout, no oscillation.

This is the principled version of "drop `a` decisively, recover slowly." The
guards are what make it safe, and they are not optional:
- **Asymmetric gains** `k_down ≫ k_up`: lose margin (damage) fast, recover
  performance slowly.
- **Slow vs the estimation window + deadband + rate limit**: the margin estimate
  (`Spk`) is windowed/noisy; adapt slower than the window and ignore small errors,
  or you regulate noise.
- **Hold on dropout**: with weak excitation the margin is unobservable — freeze
  `a`, never relax blindly.
- **Saturate** `a∈[a_min,a_max]` with clamping (anti-windup); `a_min≈0.3` keeps
  enough bandwidth that tracking does not collapse (J4 blows up below ~0.3).
- **Run it on a robust base** (notch+lead) so the `a`-path is monotone (no
  transition through the unstable dip that a plain aggressive lead creates).

Caveat: this regulates a *linearized* margin around the current operating point;
it is a supervisory layer, not a substitute for the offline worst-case design.
Keep the bracket-feasible notch+lead underneath; let the regulator buy back
performance (raise `a`) only when the measured margin is comfortably above set.

## Estimating NCF directly (not via GM) — GM is blind to low phase margin

You are right that GM→NCF is unsafe: GM only inspects the −180° crossing, so a
Nyquist curve that swings near −1 at the **gain** crossover (low PM) gives a low
NCF while GM stays large. Measured proof on the real loop:

```
coupled H5 + lead7 :  GM = Inf dB   but   NCF = 0.246   (loop is actually fragile)
```

GM says "infinite margin"; NCF (and the pole radius) correctly flag it. So
estimate NCF **directly**, from the whole Nyquist curve.

### The identity that makes NCF directly measurable
With `S = 1/(1+L)` (sensitivity) and `T = L/(1+L)` (complementary sensitivity):

```
b(ω) = |1+L|/sqrt(2(1+|L|²)) = 1 / ( sqrt(2)·sqrt(|S(jω)|² + |T(jω)|²) )
NCF  = min_ω b(ω) = 1 / ( sqrt(2) · max_ω sqrt(|S(jω)|² + |T(jω)|²) )
```

Verified exact against `custom_stability_margins` (0.3438 vs 0.3438 inner;
0.2461 vs 0.2461 coupled). Because it uses `|S|` and `|T|` at **every** frequency
it captures the low-PM / near-−1 approach a gain margin misses — `|S|` peaks
wherever the loop nears −1, at the gain crossover or anywhere else.

### Why this is *directly* measurable online (no GM, no open-loop inversion)
For unity feedback, `T` is the **closed-loop FRF from command to output**. For the
inner actuator loop that is exactly `T = dm/dd_lead`, which you already log, and
`S = 1 − T`. Closed-loop FRFs are bounded and well-conditioned even at modest
coherence (unlike inverting to the open loop). So:

```
1. estimate T̂(jω) = dm/dd_lead over the binding band (e.g. xfunc)
2. Ŝ = 1 − T̂
3. NCF = 1/(sqrt(2)·max_ω sqrt(|Ŝ|² + |T̂|²))          (estimate_ncf_direct.m, kind='comp')
```

Demonstrated from a **noisy** `dm/dd_lead` time history (1% measurement noise):
estimated NCF **0.345 vs true 0.344**, binding at 39 Hz. (Coherence at 35–45 Hz
must be adequate; the earthquake is low-frequency, so add a **small command
dither** to excite the ~37 Hz binding band if operating data is too weak there —
a few % of the command suffices and does not perturb the test.)

### Inner vs coupled
- **Inner NCF** (`T = dm/dd_lead`) needs no probe — it is the loop where damage
  bites and the 37 Hz lives, and it is the cleanest online reading. Best default.
- **Coupled NCF** is the true RTHS margin. Its `T` is the closed-loop transfer of
  the *coupled* loop; estimate it by a small **dither at the dd command node** and
  the loop-FRF ratio (same `estimate_ncf_direct`, `kind='open'` on the measured
  `L_c`, or `kind='comp'` on the measured coupled `T`). Use the inner NCF as the
  fast indicator and the coupled NCF as the periodic check.

### Use it to regulate `a` on NCF error directly
The authority regulator can now key off **measured NCF** instead of GM:
`e = NCF_set − NCF_est`, with the sign flipped (lower `a` ⇒ higher NCF). NCF is
the better regulated variable precisely because it is not fooled by low PM. Keep
the same guards (asymmetric, deadband, rate-limit, hold-on-dropout, saturation).
`Spk` from OSI Method 7 reads the resonant `|T|` peak; the full `sqrt(|S|²+|T|²)`
reading here is its low-PM-aware generalization.

## OSI Method 8: direct S,T NCF as an online indicator (vs M6, M7)

Packaged the direct-NCF estimator as a new OSI indicator and ran it **unchanged
beside the published Method 6 (open-loop FRF Kalman) and Method 7 (output
resonance)** on the same `research/OSI/damage_jump` benchmark: the healthy→damaged
`H_dc_dm` jump (7000→5000 at t=10 s) under the **3 input cases** (high-band 1731,
low-band 1749, mixed), over the same **per-seed disturbance ensemble** (`rng(s)`,
10 seeds) the M7 robustness study uses. No dither; unity feedback assumed.
`T = dm/dd_lead`, `S = 1−T`, `NCF = 1/(√2·max_ω √(|S|²+|T|²))`.

Result (true loop-only NCF 0.588 healthy → 0.344 damaged):

| case | M6 open-loop FRF | M7 output reson. | **M8 direct S,T** |
|---|---|---|---|
| high-band | 0.591→0.364 detects | 0.587→0.354 (10/10) | **0.591→0.372 detects (10/10)** |
| low-band | **0.227→0.002 FALSE COLLAPSE** | 0.587→0.415 (10/10) | **0.588→0.600 blind-but-safe (0/10)** |
| mixed | 0.591→0.364 detects | 0.587→0.354 (10/10) | **0.591→0.372 detects (10/10)** |

What M8 adds, and its limit:
- **Reads the *true* NCF absolutely** (0.591≈0.588 healthy, 0.372≈0.344 damaged) —
  no calibration, no model, unlike M7's relative `Spk` map. And it is the
  low-PM-aware reading (uses the whole Nyquist curve, see the S,T section above).
- **Never false-collapses.** In the low band the open-loop FRF (M6/M1) hits the
  feedback-lock tautology `dm/dc → −1/C` and alarms even when healthy (0.227, and
  →0.002 "damaged"). M8 uses the *exogenous* command `dd_lead`, so an unexcited
  35 Hz bin is just low-coherence and gated out — M8 holds at the true ~0.59.
- **Cost of "no dither":** like every FRF method, M8 can only *see* the 35 Hz
  collapse when the command excites 35 Hz (high/mixed). Under a purely
  low-frequency input it is blind there (0/10) — safe, but only **output-only M7
  detects** in that case. So M8 complements M7: M8 for an accurate, low-PM-aware,
  false-alarm-proof margin whenever the band is excited; M7 as the output-only
  backstop when it is not. Figure: `results/osi_method8_vs_m6_m7.png`.

(These OSI files live here in `optimizing_pl/claude` and call the OSI methods
read-only; they can be moved into `research/OSI` as `osi_method8` / `trial_8` if
you want M8 folded into `run_all_and_compare`/`show_all_indicators`.)

## Files in this folder

| file | purpose |
|---|---|
| `FINDINGS.md` | this document |
| `damage_bracket.m` | multiplicative-`γ` + `k_exp` damage ensemble from a healthy baseline (Q2) |
| `hybrid_loop_margins.m` | NCF / GM / pole radius of the coupled RTHS loop for one (plant, lead) |
| `robust_pl_score.m` | worst-case (min–max) criterion over the bracket (Q1) |
| `predict_inner_margin.m` | inner PID+H_dc_dm GM/NCF and the **closed-form `a`** for a target GM |
| `estimate_ncf_direct.m` | NCF straight from an FRF via `S,T` (no GM step); takes measured `T=dm/dd_lead` |
| `osi_method8_ncf_direct.m` | the same estimator as an OSI indicator (windowed, gated, `ctx`/`cfg` interface) |
| `run_osi_ncf_direct_compare.m` | runs M8 beside M6 & M7 on the 3 input cases / seed ensemble → `results/osi_method8_vs_m6_m7.png` |
| `apply_pid_authority.m` | scale PID by the authority `a` (`PID·a`) |
| `authority_regulator.m` | one margin-error update of `a` (asymmetric, deadband, rate-limit, hold-on-dropout) |
| `build_num_tf.m` | numerical-substructure `force→dd` model (mirrors vHS internals) |
| `run_robust_pl_study.m` | reproduces every table above (incl. Q4 `PID·a` + regulator) |

### Folding the criterion into the real optimizer
`optimize_vHS_phase_lead.m` only needs three localized edits (kept out of this
folder because the instructions limit edits here):
1. `prepareVhsPhaseLeadProblem`: build a list of `(num_tf or k_exp, PID_H_dc_dm)`
   members from `damage_bracket` instead of the single loaded model.
2. `evaluateVhsPhaseLead` / `numDelayCompExpMetrics`: compute NCF, GM, `max|pole|`
   for **each** member; simulate `J4` per member.
3. `scoreVhsPhaseLead` / `candidateMeetsMinimums`: replace nominal NCF and
   stability with `min_i NCF_i`, `max_i |pole|_i`, and `max_i J4_i` per the score
   above.
