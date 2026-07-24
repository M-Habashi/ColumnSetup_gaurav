# OSI/Auth-Factor Plots

The project's combined OSI + authority acceptance test is officially called
the **Fabby Benchmark**. Run it through
`research/osi_benchmark/run_osi_benchmark.m`; the scripts below are supporting
plots and focused replays.

For the redesigned indicator + authority law (Fable), see `fable/README.md`
and `fable/fable_report.html`:

```matlab
addpath(fullfile(pwd, 'OSI_tests', 'fable'))
checks  = run_fable_synthetic_checks;   % closed-loop ground-truth validation
results = run_fable_osi_tests;          % 3-record replay vs current impl
```

This folder has one offline plot runner:

```matlab
addpath(fullfile(pwd, 'OSI_tests'))
results = run_current_osi_auth_factor_cases;
```

To test Method 9.3, the median+slew research law formerly called
`m92_slew`, run:

```matlab
addpath(fullfile(pwd, 'OSI_tests'))
results93 = run_osi_9_3_auth_factor_cases;
```

It processes exactly these three saved records:

- `saved_results/tests/important/20260617_1731_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat`
- `saved_results/tests/important/20260617_1749_sp1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat`
- `saved_results/tests/important/20260630_1930_testing_OSI.mat`

For each file, it recomputes OSI/auth-factor from `dd` and `dm` using the
current implementation. It ignores any OSI values already saved in the record.

Each output figure has two linked-x subplots:

1. `dm` versus time.
2. OSI S/T branch, OSI residual branch, selected OSI, and `auth_factor`.

Figures are written to `OSI_tests/figures`.
