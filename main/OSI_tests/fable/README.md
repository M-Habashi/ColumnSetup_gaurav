# Fable OSI — redesigned online stability indicator + adaptive authority

A redesign of the NCF-based online stability indicator (OSI) and the
authority-factor PID adaptation, built and validated against the three
experimental records in `saved_results/tests/important` and a
ground-truth closed-loop simulator.

**Read `fable_report.html` for the full math, design rationale, and results.**

## Files

| File | Purpose |
|---|---|
| `fable_osi.m` | The estimator. `config` / `state` / `step` / `run` commands. Step mode consumes `cfg.hop_n` samples per call and does ONE segment FFT per hop (rolling STFT ring). |
| `fable_auth.m` | Supervisory authority law (`params` / `state` / step). Scalar state, codegen-friendly. |
| `run_fable_synthetic_checks.m` | Ground-truth validation: sample-accurate closed loop (PID x identified plant) with computable true margin. 5 scenarios, PASS/FAIL. |
| `run_fable_osi_tests.m` | Replay on the 3 records + faithful replay of the current implementation + offline reference margin. Figures, metrics, caches under `results/`. |
| `fable_report.html` | The report (open in a browser). |
| `fable_simulink.md` | Simulink/Speedgoat adoption steps + staged hardware verification protocol. |

## Run

```matlab
addpath(fullfile(project_root, 'OSI_tests', 'fable'))
checks  = run_fable_synthetic_checks;   % ground-truth closed-loop validation
results = run_fable_osi_tests;          % 3-record replay + comparison
```

`run_fable_osi_tests` caches per-record replays in `results/replay_*.mat`;
delete those to force recomputation after changing the estimator.

## Key numbers (healthy operation / events, target = 0.30)

| Record | false-low (fable / current) | fast false trips | time at full authority | median err vs reference |
|---|---|---|---|---|
| 20260617_1731 | 0.0% / 20.6% | 0 | 100% / 30% | 0.021 / 0.142 |
| 20260617_1749 | 0.3% / 0.0% | 0 | 92% / 100% | 0.013 / 0.059 |
| 20260630_1930 | 0.0% / 18.1% | 0 | 100% / 60% | 0.023 / 0.319 |

Speed (two-scale fast path, CUSUM change detection): in the closed-loop
ground-truth scenarios the **authority moves 0.5 s after plant damage**
when the command excites the critical band, 1.5 s when it does not
(information limit — see report §3.6). On 1749 the genuine end-of-record
instability is flagged 1.5 s after growth onset (current: 14.7 s).

For Simulink/Speedgoat adoption steps and the staged hardware test
protocol, see `fable_simulink.md`.
