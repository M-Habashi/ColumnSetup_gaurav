# SOL-OSI Simplified 5 — per-frequency evidence fusion

Research-only. Everything up to the point where both branch margins exist is
byte-for-byte the same as `research/sol_osi_simplified`. What changed is the
block that turned those branches into the reported `b`, plus the recovery rule.

## What was wrong with the old block

```matlab
res_weight  = activation_weight*(1-mean(leverage(quiet_keep)))^2;
b_evid      = b_st - res_weight*max(b_st-b_res, 0);
memory_gain = residual_memory_gain;              % 21.75
if state.memory_released, memory_gain = 1; end   % latch, hysteresis 0.6/1.4
rho_memory  = median(rho(keep));
w_mem       = min(max(memory_gain*(rho_memory-1), 0), 1);
b_idle      = cap - w_mem*(cap - b_res);
b_raw       = activity*b_evid + (1-activity)*b_idle;
```

By this point `b_st` and `b_res` had already been collapsed to scalars by
`min` over frequency. So the block combines two margins taken at *different
frequencies*, which is not a quantity with a meaning — a chordal margin is
defined per frequency, and the loop's margin is the worst of them. Everything
after that is compensation: a squared leverage term, a gain of 21.75 needed
only because `rho_memory` is a median over the whole band and a localized
deviation barely moves a median, and a two-threshold latch to undo the gain
when it is wrong.

## What replaces it

Keep both branches as curves over frequency, and let each bin state what its
own evidence supports. Two kinds of evidence exist at a bin, and each pays for
the claim it makes:

- **`c(f) = activity · γ²(f) · leverage(f)`** — already computed. The loop is
  directly visible at this bin, so the identified margin `b_st(f)` is worth
  believing.
- **`d(f) = sat((ρ(f)−1)/(ρ_detect−1))`** — the observed power moved far
  enough from the healthy reference to clear the resolution of the ρ fit
  itself, so the ρ-corrected model `b_ρ(f)` is worth believing.

A bin with neither falls back to the current authority-scaled commissioning
prior.

```matlab
detected = min(max((rho-1)/(cfg.rho_detect-1), 0), 1);
w_st     = confidence;
w_res    = (1-confidence).*detected;
b_bin    = w_st.*b_st_curve + w_res.*b_rho_curve ...
         + (1-w_st-w_res).*b_prior_curve;
b_raw    = min(b_bin(cfg.keep));          % the worst frequency governs
```

Three statements: weight, weight, worst-of. The `min` is now the chordal
definition applied where it belongs — after the per-frequency estimate is
formed, not before.

**The idle case stops being a special case.** Quiet means every `c(f)` is
zero, so a loop that still matches its commissioning has `w_st = w_res = 0`
everywhere and reads its commissioning prior. A bin that did
detect damage keeps reporting it. The `activity*... + (1-activity)*...` mux,
`b_evid`, `b_idle`, `w_mem`, `rho_memory` and the `memory_released` latch are
all gone — not replaced, deleted.

### Unsupported-bin fallback

The first version of this fusion used `w_st = c`, `w_res = 1−c` with no
separate fallback term. It fails, and the failure is worth recording: `min`
over a blend
*self-selects* the bins where `c ≈ 0`, because those are the ones the blend
leaves lowest. The identified branch then never governs and the reading is
just the noise of the ρ fit at unexcited bins — measured on the live
scenario, `b` tracked `b_res` to three decimals while `b_st` sat 0.25 higher
and unused. Charging each branch for its own evidence is what fixes it.

## Recovery

Only the observation branch carries memory, so it is the only thing that has
to forget. The memory exists because the observed power stood above the
healthy reference, so it decays whenever that is no longer true:

```matlab
forgetting = double(state.reference_ratio < 1);
state.log_rho = state.log_rho*(1-cfg.recover_alpha*forgetting);
```

One criterion, one time constant, and it covers both cases the old code
handled separately: quiet (no drive, nothing to sustain the memory) and
driven-after-repair (power back at the healthy reference). This replaces the
`(1-activity)` blind leak *and* the `memory_release_ratio` / 
`memory_reengage_ratio` hysteresis latch.

## Parameters

Net: 22 tunable parameters → 20, and one state field removed.

| Removed | Added |
|---|---|
| `residual_memory_gain` (21.75) | `rho_detect` = 1.75 |
| `memory_release_ratio` (0.6) | `rho_recover_s` = 0.4 (renamed from `rho_leak_s`) |
| `memory_reengage_ratio` (1.4) | |
| `rho_leak_s` (8.0) | |
| state `memory_released` (latch) | |

`residual_weight` reports `w_res` at the frequency bin that governs `b_raw`.
The accompanying `direct_fraction`, `fallback_fraction`, and
`governing_freq_hz` fields expose the full provenance of that result. The
authority law may use `residual_weight` to widen its guard, but that policy is
separate from reporting the inferred share honestly.

## Fabby Bench 2

Fabby Bench 2 retains the synthetic target of `0.55` and uses `0.30` for the
experimental live and GDB records.

| | `sol_osi` | `simplified` | `simplified_5` |
|---|---:|---:|---:|
| all seven gates | FAIL | FAIL | **PASS** |
| synthetic score | 92.7 | 93.0 | 91.9 |
| experimental score | 60.9 | 66.2 | 65.5 |
| S3 detection | 100.0 | 60.0 | 60.0 |
| S4 smoothness | 77.9 | 84.8 | 87.0 |
| S5 GDB recovery | 100.0 | 100.0 | 100.0 |
| raw composite | 86.3 | 80.8 | **80.9** |
| indicator jitter | 4.22 | 5.49 | **1.98** |
| unstable time | 0.25 s | 2.00 s | **0.00 s** |
| G4 tail max `a` | 0.743 | 0.806 | **0.443** |

`indicator jitter` is a reported fact, not a score:
`1000*median|b(k)-2b(k-1)+b(k-2)|` pooled over every update of every test. The
second difference makes it a noise measure rather than a penalty on
responsiveness (a ramp has none, a step contributes only at its edge) and the
median discards those few edges. It is kept out of the composite on purpose: a
clean trace can always be bought with output filtering, and S3 detection is
where that gets paid for, so the two are meant to be read together.

The raw composites of the first two methods are gated out. V5 is the only
method with zero unstable time and an end-hold authority below the `0.736`
limit. The reference ratio now uses the full retained 2–100 Hz band except
58–62 Hz.

## Retune, 2026-07-25

The first tune (`residual_s = 0.84`, `reference_level_beta = 0.26`) passed every
gate but was the most conservative of the three methods and the slowest to give
authority back: on the GDB replay it rode the `a_min = 0.20` floor and took
6.9 s to return to 0.95 after the diagnostic gain was restored.

The cause was not the memory. Instrumenting the replay shows `rho` back at 1.01
within a second of the restore while `a` crawls up for six more — the regulator
was climbing out of a shed that was too deep to begin with. And that shed rested
on false evidence: on this record the drive itself gets louder during the shake,
so observed power rises for a reason that has nothing to do with loop growth,
and the level term of the `rho` fit reads it as damage.

Two constants, no equation changed:

| | was | now | why |
|---|---:|---:|---|
| `residual_s` | 0.84 | **1.00** | slower `rho` attack, so a transient is not committed to memory |
| `reference_level_beta` | 0.26 | **0.50** | divides more of the observed level out, leaving the fit reading shape |

| GDB replay | before | after |
|---|---:|---:|
| authority floor | 0.200 | **0.592** |
| authority at 70 s | 0.275 | **1.000** |
| recovery after restore | 6.9 s | **0.0 s** |

Nothing was traded for it: all seven gates still pass, the composite rises from
73.5 to 80.6, `tail_max_a` improves from 0.571 to 0.443, and the live edges that
are detected are detected faster (0.24/0.42 s → 0.11/0.17 s).

`residual_s` was screened over 0.9–3.0 against `reference_level_beta` over
0.26–0.65. Parts of that grid fail G3/G4 on the live scenario — `residual_s`
1.5–2.0 at `beta` 0.26–0.50 goes unstable — so `residual_s = 1.0` was chosen
because every `beta` in the screened range passes there, which puts the
operating point inside a safe region rather than on its edge.

An alternative with `rho_detect = 2.5` is less conservative still (floor 0.765)
and also passes every gate, but it scores 80.1, reacts to the edges later, and
lets the true margin fall further (`b_true_min` 0.161 against 0.198), so it was
not taken.

### Second pass: indicator jitter

Taking the worst of forty-seven per-frequency estimates is an order statistic,
so this formulation buys its per-bin honesty with a noisier trace. The output
filter is where that gets paid back: **`margin_s` 0.08 → 0.25 s**.

| | before | after |
|---|---:|---:|
| indicator jitter | 4.54 | **1.98** |
| composite | 80.6 | **80.9** |
| S3 detection | 60 | 60 |
| S5 GDB recovery | 100 | 100 |
| `tail_max_a` | 0.443 | 0.443 |
| all seven gates | PASS | PASS |

Jitter more than halves and lands well under the production estimator's 4.22,
with nothing given up — the detection that survives no longer depends on the
fast filter once the first two constants stopped manufacturing false evidence.
Note this would not have been free before that: screened against the old
`residual_s`/`beta`, `margin_s = 0.15` already cost S3 detection 60 → 40.

`margin_s = 0.35` fails G1 (a synthetic case), so 0.25 was taken rather than
0.30 — both of its neighbours, 0.20 and 0.30, pass. `memory_s` is a second
smoothing lever but a worse one: 0.40 drops `fabby_score_1` to 90.96 against
the G2 line of 90, and 0.60 fails it outright.

### Why it settles lower than the other two on the damage cases

On `gradual_softening` v5 settles at `a = 0.401` where both other methods hold
`0.436`, leaving the true margin at 0.5703 against a 0.55 target (they leave
0.5593). This looks like over-conservatism and it is, but **it is not reachable
by tuning** — eleven overrides were screened (`rho_detect`, `fit_floor`,
`level_fit_gain`, `power_floor_db`, `residual_s`) and every one of them left
the settled authority at 0.4007. Two things cause it, in roughly equal parts:

1. **The widened guard.** v5 reports `residual_weight = w_res` at the governing
   bin — the honest inferred share of its own reading — and `gpt5_6_4_auth`
   answers by widening `b_ref` from `target+0.02` to `target+0.02(1+w_res)`.
   Where the other two report ~0, v5 regulates to a higher `b`, so it sheds
   more. This is a policy, not an estimate.
2. **The `min` over 47 bins**, an order statistic biased low. On the damage
   cases v5's estimator bias is −0.0021 (gradual_softening), −0.0037
   (damage_step_broadband), −0.0053 (damage_then_repair) where the other two
   sit at +0.0038. This part is structural to the formulation.

Softening (1) was measured, by scaling the reported share:

| reported share | `a` end | tail_max_a (limit 0.736) | fabby_1 | composite | gates |
|---:|---:|---:|---:|---:|:--|
| ×1.00 (shipped) | 0.401 | **0.443** | 91.86 | 80.88 | PASS |
| ×0.75 | 0.404 | 0.605 | 91.81 | 80.84 | PASS |
| ×0.50 | 0.409 | 0.615 | 91.60 | 80.37 | PASS |
| ×0.25 | 0.414 | 0.926 | 91.24 | 80.02 | **FAIL** G3, G4 |
| ×0.00 | 0.418 | 0.935 | 90.87 | 79.43 | **FAIL** G3, G4 |

The trade is bad and was declined: halving the guard closes under a quarter of
the gap to 0.436 while spending most of the headroom to the G4 limit, and both
the estimation score and the composite fall. **The widened guard is the same
mechanism that makes v5 the only method passing G3 and G4** — it is not an
incidental cost of the design, it is the design working.

Note also that v5 is not uniformly more conservative: it beats the production
estimator on `damage_step_lowband` (76.9 vs 66.7), `starts_damaged_improves`
(92.6 vs 91.9) and `regime_change_healthy` (99.8 vs 97.0). Over the ten cases
it trades rather than loses (91.86 vs 92.73).

`docs/Sol_osi/index.html` runs this estimator in the browser against both
experimental records, so these constants and eleven others can be moved
directly against the data.

## Run it

```matlab
comparison = compare_fabby_bench_2;
```
