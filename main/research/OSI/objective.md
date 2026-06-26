# Objective

- Build an online stability indicator based on the NCF margin.
- Use a window-based approach, where each time step picks a moving window for evaluation.
- Use non-overlapping windows so a Kalman filter can be applied to the resulting indicator later.
- Work mainly with the PID + `H_dc_dm` system model inside `exp_tf\20260617_1708_sp_1_ori_P30_I30_D0001_Po_015_Io_20_Do_00015_20260623_174918.mat`.
- Test the theory first on `20260617_1731_sp_1_ori_Pvar_I30_D0001_Po_015_Io_20_Do_00015.mat`, using the useful-data window from `620 s` to `770.1 s`.
- The working assumption is that the `exp_tf` model is correct at the beginning of the window. As time progresses after `620 s`, the actual `H_dc_dm` changes while the PID gains remain constant. This change is experimental and affects only `dm`; so far, the model has not been updated based on it. This change makes the system more susceptible to instability.
- The goal is to find an NCF-based indicator that can detect this stability-margin shrinkage from measurements, allowing decisions during the experiment based on this indicator, such as switching to another controller or pausing the experiment.
- Check the NCF margin implementation in `main\control_and_HS\b_system_id\id_utils\custom_stability_margins.m` so it can be reused or extended for the online stability indicator.

## Expected Output

- A time series of the estimated margin in the specified window.
