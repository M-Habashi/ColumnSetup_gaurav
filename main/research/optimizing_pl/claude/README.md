# optimizing_pl / claude

Damage-robust phase_lead analysis for the RTHS column test.

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
- The instability is the **inner PID+H_dc_dm loop** at its ~37 Hz −180° point.
  Scaling the PID by `a` (`PID·a`) is the right authority knob — its inner gain
  margin is **closed form**, `GM_dB(a)=GM_dB(1)−20log10(a)`, so the required `a`
  for a target margin needs no search (`predict_inner_margin.m`).
- Because the margin-vs-`a` map has a fixed sign, you can **regulate `a` online**
  from a margin-error setpoint (`authority_regulator.m`); demoed holding coupled
  NCF 0.32–0.43 under damage ramping γ:1→4.
- **NCF can be estimated directly** (not via GM, which is blind to low phase
  margin): `NCF = 1/(√2·max_ω √(|S|²+|T|²))`, and `T = dm/dd_lead` is a measurable
  closed-loop FRF, `S = 1−T` (`estimate_ncf_direct.m`). Recovered NCF 0.345 vs
  true 0.344 from a noisy time history; catches the GM=∞-but-fragile case.
- Packaged as **OSI Method 8** (`osi_method8_ncf_direct.m`) and compared beside
  M6 & M7 on the damage-jump benchmark (3 input bands, seed ensemble):
  `run_osi_ncf_direct_compare.m` → `results/osi_method8_vs_m6_m7.png`. M8 reads
  the *true* NCF (0.59→0.37), never false-collapses (unlike M6 in the low band),
  but needs binding-band excitation to detect (no-dither cost) — output-only M7
  remains the low-band backstop.
