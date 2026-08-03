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
