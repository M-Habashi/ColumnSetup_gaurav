# Fable OSI — redesigned online stability indicator + target-tracking authority

A redesign of the NCF-based online stability indicator (OSI) and the
authority-factor PID adaptation, validated against the experimental
records in `saved_results/tests/important` and a ground-truth closed-loop
simulator — plus the flattened Speedgoat runtime that executes it on the
target, proven **bitwise-identical** to the desktop implementation.

**Read `fable_report.html` for the math, design rationale, and the
original 3-record validation.** For Simulink/Speedgoat adoption see
`fable_simulink.md`.

## The authority law (rewritten 2026-07)

`fable_auth` now REGULATES the margin onto a target OSI (default
**0.55**, `target` parameter):

* margin ≥ target → authority recovers to and holds `a_max` (= 1);
* margin < target → sized multiplicative shed until the margin returns
  to the target; severe deficits and fast-guard trips act within one
  0.125 s step;
* sheds are sized ONCE per estimator settle (`down_settle_s`) so the
  estimator's window lag can never compound one dip into a slam;
* a commit gate (`min_step`) quantizes authority moves against flicker;
* recovery speed is tunable (`up_rate`, `up_prop`, `up_hold_s`) and is
  deliberately latched after hard events (`latch_*`);
* the fast FRF-change guard is armed only while the applied authority has
  been steady (`fable_osi` `a_cmd` contract + the law's
  `self_move_gate_s`), so the law can never trip on its own motion.

Every knob is documented in the **TUNING GUIDE** headers of
`fable_auth.m` (authority: smoothness, drop speed, recovery speed,
gating) and `fable_osi.m` (per-branch: smoother ↔ more aggressive).

## Files

| File | Purpose |
|---|---|
| `fable_osi.m` | The estimator. `config` / `state` / `step` / `run` commands. Per-branch tuning guide in the header. |
| `fable_auth.m` | Target-tracking authority law (`params` / `state` / step). Scalar state. Tuning guide in the header. |
| `../../control_and_HS/OSI/fable_osi_runtime.m` | **The Speedgoat runtime**: flattened MATLAB Function body (`%#codegen`), per-sample scalar I/O, fixed-size persistents, config as parameter arrays. Header documents what to change if the target overruns (TET). |
| `../../control_and_HS/OSI/prepare_fable_runtime.m` | Builds/flattens the parameter arrays (`fbls, fblw, fblbins, fblfw, fblfbins, fblag, fbla`) for the block; index maps documented inside. |
| `test_fable_runtime_equivalence.m` | Asserts runtime ↔ desktop **bitwise** equivalence (synthetic + records). Run after ANY change to the three files above. |
| `fable_tune_explorer.m` | **Interactive tuning**: replays a selectable record through the exact runtime; linked plots of dm / all OSI branches + selected margin / authority; pass `'osi'`/`'auth'` override structs to tune. |
| `fable_synthetic_suite.m` | Closed-loop ground-truth scenario library (10 scenarios incl. gradual softening, damage→repair, starts-damaged→improves, regime change, transient pulse) with a **pluggable method interface** — drop in a future method via `fable_synthetic_suite('template')`. |
| `run_fable_synthetic_checks.m` | The original 5-scenario ground-truth validation (0.5 s authority-response requirement). |
| `run_fable_osi_tests.m` | 3-record replay vs the current implementation + offline reference. Caches under `results/` — delete `replay_*.mat` after changing the estimator or the law. |
| `fable_report.html` | Full report (open in a browser). |
| `fable_simulink.md` | Simulink/Speedgoat adoption steps + staged hardware verification protocol. |

## Run

```matlab
addpath(fullfile(project_root, 'OSI_tests', 'fable'))
test_fable_runtime_equivalence(2);      % runtime == desktop, bitwise
checks  = run_fable_synthetic_checks;   % ground-truth closed-loop validation
suite   = fable_synthetic_suite;        % 10-scenario suite (target 0.55)
results = run_fable_osi_tests;          % 3-record replay + comparison
fable_tune_explorer;                    % pick a record, tune interactively
```

## Validation status (2026-07-02, all PASS)

* **Runtime equivalence**: bitwise (`max|diff| = 0`) on all 3 records +
  synthetic path-coverage stream.
* **Legacy ground-truth checks**: 5/5 — authority moves **0.500 s** after
  excited-band damage, 1.5 s for quiet-band-only damage (information
  limit), margin defended, zero false adaptation/trips.
* **New 10-scenario suite (target 0.55)**: 10/10 — tracks the target on a
  damaged start (median |b_true − target| = 0.036), full authority
  **9.2 s** after the plant heals (nothing latched), deliberate latched
  recovery after trips, bounded reaction + recovery on an exogenous
  pulse, regime switch survives with authority ≥ 0.85.
* **3-record replay (target 0.50, refreshed 2026-07-02)**: false-low
  0.6% / 6.3% / 0% (current impl: 44% / 7% / 64%), median error vs
  reference 0.021 / 0.013 / 0.023, the genuine 1749 instability picked
  up at the first update after onset (margin crosses 0.50 at t = 248 s).
  A target this close to the rig's healthy scatter costs healthy
  authority: 1749 sheds on two transient margin dips (full authority 45%
  of the healthy window) and 1930's burst guard trips 3× on EQ phase
  transitions (min a 0.37, full authority 5%). At the earlier 0.30
  target all three records held full authority with zero trips.
