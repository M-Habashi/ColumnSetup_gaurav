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

A bin with neither makes **no claim**: it reads `cap`, which cannot drag a
minimum down.

```matlab
detected = min(max((rho-1)/(cfg.rho_detect-1), 0), 1);
w_st     = confidence;
w_res    = (1-confidence).*detected;
b_bin    = w_st.*b_st_curve + w_res.*b_rho_curve + (1-w_st-w_res)*cfg.cap;
b_raw    = min(b_bin(cfg.keep));          % the worst frequency governs
```

Three statements: weight, weight, worst-of. The `min` is now the chordal
definition applied where it belongs — after the per-frequency estimate is
formed, not before.

**The idle case stops being a special case.** Quiet means every `c(f)` is
zero, so a loop that still matches its commissioning has `w_st = w_res = 0`
everywhere, reads `cap`, and asks for no authority change. A bin that did
detect damage keeps reporting it. The `activity*... + (1-activity)*...` mux,
`b_evid`, `b_idle`, `w_mem`, `rho_memory` and the `memory_released` latch are
all gone — not replaced, deleted.

### Why an unsupported bin must read `cap`, not the prior

The first version of this fusion used `w_st = c`, `w_res = 1−c` with no
`cap` term. It fails, and the failure is worth recording: `min` over a blend
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
| `residual_memory_gain` (21.75) | `rho_detect` = 1.50 |
| `memory_release_ratio` (0.6) | `rho_recover_s` = 2.0 (renamed from `rho_leak_s`) |
| `memory_reengage_ratio` (1.4) | |
| `rho_leak_s` (8.0) | |
| state `memory_released` (latch) | |

`residual_weight` is now reported as **0**. It exists so an authority law can
widen its guard when a reading mixes measured and inferred evidence; here
every bin's claim is already weighted by its own evidence and an unsupported
bin claims nothing, so there is no leftover global uncertainty to guard. This
was measured, not assumed — feeding the honest inferred share to
`gpt5_6_4_auth` costs composite (75.0 → 74.7) because the widened guard
mostly blocks recovery.

## Fabby Benchmark

`gpt5_6_4_auth`, method defaults everywhere, one parameter set.

| | `sol_osi_simplified` | `sol_osi_simplified_5` |
|---|---|---|
| all seven gates | PASS | PASS |
| fabby_score_1 | 93.0 | 91.7 |
| fabby_score_2 | 59.6 | 55.6 |
| S3 detection | 80.0 | 80.0 |
| S4 smoothness | 85.9 | 79.8 |
| S5 gdb recovery | 49.3 | **67.6** |
| **composite** | **73.6** | **75.0** |
| G4 tail max a (limit 0.736) | 0.715 | 0.707 |

Suite 10/10, `emu unstable 0.00 s`. The trade is real and worth naming: v5
gives up some live-scenario tracking and smoothness, and buys back GDB
recovery (14.8 s → 8.5 s) and a wider G4 margin than the baseline's.

Both `rho_detect` and `rho_recover_s` sit near a G4 cliff — anything that
speeds recovery eventually lets authority return before the diagnostic gain
does. `rho_recover_s = 2.0, rho_detect = 1.75` scores 75.5 but fails G3/G4.
The baseline sits on the same cliff (tail 0.715 against a 0.736 limit); this
is the benchmark's shape, not a weakness peculiar to v5.

## Run it

```matlab
result = run_sol_osi_simplified_5_benchmark;      % full scorecard
comparison = compare_sol_osi_5;                   % v5 vs the baseline
```
