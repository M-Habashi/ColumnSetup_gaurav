# Fabby Benchmark — the one place to test an OSI method

**Fabby Benchmark** is the official name of the combined OSI + authority
evaluation used by this project.

Every test an OSI + authority candidate must face runs from ONE call in this
folder. It prints a scorecard with two fabby scores plus three auxiliary
scores, checks seven hard gates, and saves `results/<label>_benchmark.mat`.
Nothing else in the repo needs to be run to evaluate a method.

## How to test (step by step)

1. Put your method on the path (a folder with your two functions):

   ```matlab
   cd research/osi_benchmark
   addpath('../my_method_folder')
   ```

2. Run the benchmark:

   ```matlab
   result = run_osi_benchmark(@my_osi, @my_auth, 'my_label');
   ```

3. Read the scorecard. A method is acceptable only when **all seven gates
   PASS**; the composite (mean of the five scores) is reported only then.
   Compare against the reference scorecards produced by
   `benchmark_candidates.m`.

4. Do not hand-run the suite, the emulation, or the GDB replay separately to
   quote numbers — this harness is the canonical wiring of all three (that's
   what "one place" means). The per-test targets are read from each record's
   own `hs` configuration, never from your code.

What the one call runs, in order:

| Part | Data | Produces |
|---|---|---|
| Canonical 10-case synthetic suite | `OSI_tests/fable/fable_synthetic_suite` (seeds `rng(7)`) | G1, G2, **fabby_score_1** |
| Closed-loop live scenario | `saved_results/tests/gpt5_6_tests/osi_calibration_test.mat` | G3, G4, **fabby_score_2**, S3, S4 |
| GDBqFpKb replay | `saved_results/tests/tsting_osi/GDBqFpKb.mat` | G5, G6, S3, S5 |

## Interface contract

The method is a pair of functions with the `gpt_osi`/`gpt_auth` convention:

```matlab
cfg  = my_osi('config', dt, initial_loop_tf, struct())
ost  = my_osi('state', cfg)                    % must expose ost.a_cmd
[b, ost, info] = my_osi(dd_blk, dm_blk, cfg, ost)
     % info must provide: full_margin, residual_weight, ready
prm  = my_auth('params', struct('target',T,'a_min',A,'dt_update',cfg.step_s))
ast  = my_auth('state', prm)
[a, ast] = my_auth(b, info.full_margin, info.residual_weight, ast, prm)
```

## The three rules (each learned the hard way)

1. **Closed loop.** The live-scenario test feeds the candidate's own authority
   back into the plant; the harness writes the applied `a` into `ost.a_cmd`
   before every step and the estimator must use it. Open-loop replays hide
   feedback failure modes — two documented cases in this repo:
   - the original gpt5_6 "recovered in 2.75 s" on GDBqFpKb open-loop; closed
     on the live scenario the same mechanism (prior collapse at idle →
     `full_margin` reads 0.71 → blind slam to a = 1) put the loop 13.4 s
     inside the unstable region and destroyed the actuator command;
   - an early gpt5_6_4 record replay ended at a = 0.888 with the diagnostic
     gain still 3 (g·a = 2.66, past the computed instability boundary 2.25)
     and its open-loop criterion counted that as a pass.
2. **One parameter set.** Method defaults everywhere. The per-test `target`
   and `a_min` are read from each record's own `hs` configuration — they are
   facts of the test, not knobs. A per-record "calibration profile" voids the
   validation (this repo has two precedents of shadow-tuned replays being
   retracted).
3. **The corrected record only.** The live scenario is
   `saved_results/tests/gpt5_6_tests/osi_calibration_test.mat`. Other exports
   of the 2026-07-10 18:45 run log `dc` **after** the diagnostic gain (their
   dc equals g × the correct dc — verified exactly, diverging at the first
   edge 34.014 s). A method that reads that signal "detects" the gain by
   reading the test's own knob; gpt5_6_3 was discarded for exactly this.
   A candidate may consume **only `u_osi` and `dm`** (plus the `a_cmd`
   feedback). Any additional signal must be argued for separately and must
   exist with correct semantics on the Speedgoat.

## Hard gates (all measurable facts; every gate must PASS)

| Gate | Definition | Factual basis |
|---|---|---|
| G1 | canonical suite 10/10 | `OSI_tests/fable/fable_synthetic_suite`, the project's established scenario set and criteria |
| G2 | fabby_score_1 > 90 | minimum accepted suite-estimation score |
| G3 | 0 s with g·a ≥ g_crit in the closed-loop live scenario | g_crit is **computed at runtime** by bisection on `isstable(feedback(g·C·H5k, 1))` (≈2.21 for the identified 5k model) — the linear stability boundary, not an opinion |
| G4 | max a ≤ g_crit/3 for t ≥ 66 s | after the excitation ends the record's diagnostic gain is still 3, so any a above g_crit/3 is inside the unstable region; this is the exact failure that ended the 2026-07-10 test |
| G5 | no GDB idle shed (t < 44 s) | the record is physically healthy and undriven there; any shed is a false positive by definition |
| G6 | GDB quake deficit flagged ≤ 2 s | at quake onset the true margin (0.344 for gain 1 on the 5k model) is below the canonical target 0.55; 2 s is the project's established detection requirement |
| G7 | no NaN in b or a anywhere | continuity is a hard runtime requirement on the Speedgoat |

## Scores (0–100 each; composite = mean, reported only if all gates pass)

Both fabby scores use the same formula — signed error of the true margin
against an ideal, unsafe side ×3, score = 100·(1 − mean(w·|e|)/0.10) — but on
different questions:

| Score | What it measures | Formula anchor |
|---|---|---|
| **fabby_score_1** | *Estimation*: does the method read the margin correctly? Runs on the 10 synthetic suite cases where the true plant blend is known | ground-truth margins from the identified models (`research/fable_2/fabby_score`) |
| **fabby_score_2** | *Regulation*: does the method hold the loop at the right margin in closed loop? Runs on the rebuilt 2026-07-10 live scenario; e = b_true − b\*, with b\* = max(target, b_true(a=1, g)) computed from the identified model and the applied g·a at every step — ground truth the method cannot see. **Per-sample saturated**: each update loses at most its own share of the 0.10 scale, so a bounded unstable stretch costs its duration rather than zeroing the score — the score stays informative even when G3/G4 fail (the gates, not this score, condemn instability) | same error metric, closed-loop `osi_calibration_test.mat` |
| S3 detection | fraction of the five diagnostic-gain **rises** (34.01, 37.70, 44.96 s live; 50.2, 56.5 s GDB) where the reading is ≤ b_healthy − 0.04 OR the authority responds (a ≤ 0.98·a_pre) within 2 s. b_healthy = the method's own median reading in the healthy driven window (33–34 s live, 46.5–50 s GDB); a reading already below threshold counts at latency 0 | the 0.04-drop criterion is the canonical harness's established detection rule; measuring against the method's *own* healthy read makes the test estimator-agnostic |
| S4 smoothness | 100·(1 − travel/travel_live), travel = Σ\|Δa\| over 45–63 s | travel_live = 2.24, the measured authority travel of the failed live run over the same window — the factual "this was unacceptable" baseline |
| S5 gdb recovery | linear: 3 s → 100, ≥20 s → 0, from the gain-restore edge (75.47 s) to a ≥ 0.95 held to record end | 3 s is the canonical recovery requirement; 20 s is the post-restore window the record physically offers; never-recovering scores 0 |

## Reference scorecards (2026-07-12, per-sample-saturated fabby_score_2)

| Candidate | Gates | fabby_score_1 | fabby_score_2 | Composite |
|---|---|---|---|---|
| gpt5_6_2 (fable) | ALL PASS | 94.0 | 52.5 | 68.9 |
| gpt5_6_4 (no leak, as promoted 2026-07-12) | ALL PASS | 92.3 | 58.4 | 72.6 |
| merged tuning, rho_leak_s = 150 s | ALL PASS | 92.4 | 61.9 | 73.6 |
| merged tuning, rho_leak_s = 40 s | ALL PASS | 92.4 | 57.7 | 72.8 |
| merged tuning, rho_leak_s = 10 s (shipped default) | **G3/G4 FAIL** | 92.4 | 54.3 | gated out (73.1) |
| **sol_osi_v1 (healthy reference + hysteresis + level fit)** | ALL PASS | 92.7 | 57.9 | **74.1** |
| gpt5_6 baseline | **G3/G4 FAIL** | 94.8 | 43.3 | gated out (73.1) |

sol_osi_v1 (control_and_HS/OSI/sol_osi_v1.m, 2026-07-12 update) was the
composite leader. It is the only candidate that passes the stability gates
WITH the fast 10 s leak (tail a 0.660 < 0.736: its 32x idle memory gain
keeps b_idle pinned to the rho model while the memory decays), the only one
to detect all five gain rises (S3 = 100, including the 37.70 s edge every
other method missed), and — new in rev 2 — its memory-release hysteresis
(release below 0.6x the healthy reference, re-engage above 1.4x) restores
GDB recovery (13.5 s, S5 38.2; rev 1 never recovered, S5 = 0, composite
66.2). Its level-dependent fit activates only above 4x healthy corrected
power and keeps the highlighted maximum at 0.347753. Remaining weaknesses:
recovery is still its lowest score (13.5 s vs
the 3 s requirement), the healthy reference is captured blind in the first
1.5 s (no activity gate), and the record offers only ~14 s of held-gain quiet
so longer holds are unexercised. The time-sliced runtime is now ported in
control_and_HS/OSI/sol_osi_v1_runtime.m.

The hard-activity investigation is retained in `research/sol_osi_simplified`.
The approved simplified estimator is now the canonical
`control_and_HS/OSI/sol_osi.m`; it uses the direct gate
`A = double(rms(u) > eta_A)` with `eta_A = 0.0575` (approximately
`4.54 sigma_noise_u`), per-frequency evidence fusion, and a second-smallest
retained-bin reduction. Its Fabby Bench 2 composite is `80.63`.

The baseline row shows why the gates exist: its would-be composite matches
the shipped default's, but it spends 13+ s inside the unstable region — the
composite ranks only gate-passing methods.

The shipped 10 s leak fails the held-gain stability gates by an accepted,
documented decision (see `main_ColumnSetup.m`); it is safe only for tests
where the fault/diagnostic gain is removed before the excitation stops.

## Notes for method authors

- Determinism: the suite seeds `rng(7)` and the emulation `rng(3)` internally.
  Your method must not depend on random numbers.
- The GDB replay runs at the method's default parameters (canonical target
  0.55); the live scenario runs at the recorded 0.35 / a_min 0.2. Both come
  from the harness, never from you.
- Known information limits, so you don't chase ghosts: on this tap
  (`u_osi`/`dm`) the quiet band sits at the sensor-noise floor during weak
  drive, the coherent FRF is force-echo biased (absolute fits read gain ≈3
  when healthy), and at deep shed (a ≈ 0.15–0.35) healthy and damaged loops
  are observationally near-identical — the GDB restore edge is invisible
  there (measured: the a-normalized loop ratio stays ≈1 across it). S3/S5
  reward what is physically extractable; G3/G4 punish pretending to know
  more than the signals contain.
- Result `.mat` files saved before 2026-07-12 use the old score field names
  (`S1_fabby`, `S2_emu_tracking`); new runs save `fabby_score_1` and
  `fabby_score_2`.
