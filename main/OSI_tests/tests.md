# OSI/Auth-Factor Plots

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
