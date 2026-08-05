# LQG Investigation

This folder is the isolated workspace for studying how a linear-quadratic-Gaussian controller changes the behavior of the column system. All LQG code, configurations, derived data, plots, reports, and results belong here. Canonical repository data outside this folder are read-only inputs.

## Canonical assets

`lqg_assets.m` exposes the source paths without duplicating the large MAT files.

| Asset | Source |
|---|---|
| 7k identified actuator/specimen system | `saved_results/exp_tf/tf_sp1_7000_20260627_210411.mat` |
| 5k identified actuator/specimen system | `saved_results/exp_tf/tf_sp1_5000_20260627_233333.mat` |
| 7k specimen | `saved_results/specimens/sp1_7000.mat` |
| 5k specimen | `saved_results/specimens/sp1_5000.mat` |
| Measured broadband command record, when available locally | `saved_results/tests/important/20260617_1731_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat` |

The measured broadband record lives under the ignored `saved_results/tests` tree. The baseline study should therefore also support deterministic synthetic broadband excitation so it remains reproducible from tracked assets alone.

## Initial test cases

`lqg_test_cases.m` defines two starting cases:

1. `healthy_broadband`: the 7k system and specimen remain active under 2--100 Hz broadband excitation.
2. `sudden_drop`: the system and specimen switch together from 7k to 5k at 45 s under the same broadband excitation.

Generated outputs belong in `results/`.

## Closed-loop response plots

Open `plot_lqg_closed_loop_bode.html` to compare the saved PID responses with the live LQR design. The page includes linked magnitude and phase plots on a linear 0.1--100 Hz axis, a unit-step response, and direct `qy` / `ru` inputs. Scroll to zoom and drag with the middle mouse button to pan. Run `export_lqg_bode_data.m` to regenerate the saved PID curves and `design_lqr_baseline.m` to regenerate the LQR models, gain table, and browser data.

## LQR state-space models

Run `refit_7k_six_state.m` to produce the six-state 7k refit. Then run `build_lqr_state_space_models.m` to realize the 7k and 5k `H_dc_dm` transfer functions in the same normalized controllable-companion coordinates. Both realizations are controllable and observable, and their transfer-function reproduction errors are at machine precision. The derived models and verification table are saved as one top-level `result` struct in `results/lqr_state_space_models.mat`.

## LQR baseline

`design_lqr_baseline.m` minimizes the 7k output overshoot using

```matlab
Q = qy*(C'*C);
R = ru;
```

The baseline is `qy = 45.9076418` and `ru = 1`, with

```text
K = [0.573340285 1.09179370 1.49007275 1.14626758 0.375229691 0.0306940036]
Nbar = 7.17304072
```

The 7k response has 8.49% overshoot and a 0.0240 s settling time. Applying the identical `K` and `Nbar` to the 5k model remains stable, with 23.44% overshoot, a 0.0505 s settling time, and a final value of 6.7666. Because only the ratio `qy/ru` changes the LQR gain in this formulation, the two browser inputs represent one effective tuning degree of freedom. Zero overshoot is not attainable by changing this ratio alone; exact zero-overshoot tracking will require reference shaping or a prefilter in a later step.
