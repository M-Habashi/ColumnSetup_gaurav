# OSI candidate benchmark

One call evaluates a proposed OSI + authority law against every test that has
mattered in this project, prints a scorecard, and saves
`results/<label>_benchmark.mat`:

```matlab
cd research/osi_benchmark
addpath('../my_method_folder')
result = run_osi_benchmark(@my_osi, @my_auth, 'my_label');
```

Reference scorecards for the committed candidates are produced by
`benchmark_candidates.m`.

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
   - gpt5_6_4's record replay ended at a = 0.888 with the diagnostic gain
     still 3 (g·a = 2.66, past the computed instability boundary 2.25) and
     its open-loop criterion counted that as a pass.
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
| G2 | fabby score > 92 | `research/fable_2/fabby_score`: signed error of the TRUE margin (known plant blend) vs the ideal margin, unsafe side ×3; the >92 gate is the level the previous accepted method set |
| G3 | 0 s with g·a ≥ g_crit in the closed-loop live scenario | g_crit is **computed at runtime** by bisection on `isstable(feedback(g·C·H5k, 1))` (≈2.25 for the identified 5k model) — the linear stability boundary, not an opinion |
| G4 | max a ≤ g_crit/3 for t ≥ 66 s | after the excitation ends the record's diagnostic gain is still 3, so any a above g_crit/3 is inside the unstable region; this is the exact failure that ended the 2026-07-10 test |
| G5 | no GDB idle shed (t < 44 s) | the record is physically healthy and undriven there; any shed is a false positive by definition |
| G6 | GDB quake deficit flagged ≤ 2 s | at quake onset the true margin (0.344 for gain 1 on the 5k model) is below the canonical target 0.55; 2 s is the project's established detection requirement |
| G7 | no NaN in b or a anywhere | continuity is a hard runtime requirement on the Speedgoat |

## Scores (0–100 each; composite = mean, reported only if all gates pass)

| Score | Formula | Factual anchor |
|---|---|---|
| S1 fabby | existing metric, unchanged | ground-truth margins from the identified models |
| S2 emu tracking | fabby's formula on the closed-loop live scenario: e = b_true − b\*, b\* = max(target, b_true(a=1, g)), unsafe ×3, score = 100·(1 − mean(w·\|e\|)/0.10) | b_true is computed from the identified model and the applied g·a at every step — the ground truth the method cannot see |
| S3 detection | fraction of the five diagnostic-gain **rises** (34.01, 37.70, 44.96 s live; 50.2, 56.5 s GDB) where the reading is ≤ b_healthy − 0.04 within 2 s. b_healthy = the method's own median reading in the healthy driven window (33–34 s live, 46.5–50 s GDB). A reading already below threshold counts at latency 0 | the 0.04-drop criterion is the canonical harness's established detection rule; measuring against the method's *own* healthy read makes the test estimator-agnostic; pre-depressed readings are correct readings, not misses |
| S4 smoothness | 100·(1 − travel/travel_live), travel = Σ\|Δa\| over 45–63 s | travel_live is the measured authority travel of the failed live run over the same window — the factual "this was unacceptable" baseline |
| S5 gdb recovery | linear: 3 s → 100, ≥20 s → 0, from the gain-restore edge (75.47 s) to a ≥ 0.95 held to record end | 3 s is the canonical recovery requirement; 20 s is the post-restore window the record physically offers; never-recovering scores 0 |

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
