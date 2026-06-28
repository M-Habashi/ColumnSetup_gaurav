# optimizing_pl / claude

Damage-robust phase-lead analysis for the RTHS column test.

**Read [`FINDINGS.md`](FINDINGS.md)** — it answers the three questions
(robust optimization criterion, predicting damage on `H_dc_dm`, and an online
monotone stability knob) with numbers taken from the real saved models.

## Run

```matlab
% from anywhere; it resolves project paths itself
run(fullfile('main','research','optimizing_pl','claude','run_robust_pl_study.m'))
```

Read-only: it loads `main/saved_results`, builds the models, and prints the
per-damage-case margins, the worst-case lead grid, and the monotonicity demos.
Nothing is saved.

## Key results (reproduced by the script)

- Damage 7000→5000 ≈ a pure gain `γ ≈ 2.4` (+7.7 dB, ~5° phase) on the deployed
  `H_dc_dm`, plus `k_exp → 0.75×`.
- The healthy-tuned lead (`pl_sp1_7000`) is **unstable** on every damaged case
  (`max|pole| > 1`); no single lead keeps `NCF ≥ 0.30` on both levels.
- A min–max (worst-damage-case) NCF criterion selects a **gentle lead
  (ratio ≈ 2)** that stays stable across the whole damage bracket.
- Loop-gain "authority" is a **monotone** stability knob (pole radius only
  decreases); PID `I` and lead ratio are **not** (and ratio acts oppositely on
  the healthy vs damaged plant).
