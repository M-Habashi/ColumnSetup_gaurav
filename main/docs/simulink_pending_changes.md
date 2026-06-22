# Pending Simulink changes for the official specimen estimator

Replace the unscaled `Online TSE Estimator` implementation in
`model_ColumnSetup_00.slx` with the same windowed noise-whitened TLS method
used by `TLS_scaled.m` and `create_specimen_mat.m`.

## Official parameters

- Noise acquisition: first 2 s after the target starts
- TLS window: 0.1 s
- Displacement/force filter: causal second-order Butterworth, 30 Hz
- TLS calculation stride: 64 samples
- Minimum demeaned force RMS: 20 N
- KF relative process-noise scale: 1
- KF relative measurement-noise scale: 1
- LSE fallback: disabled; hold the last KF state instead

At `dt = 1/2048 s`, use a fixed TLS buffer of
`round(0.1/dt) = 205` samples. Fixed sizes are required for MATLAB Function
code generation.

## Required signal processing

1. Convert measured displacement to metres before the estimator.
2. Do not use the measured acceleration channel.
3. Apply the same causal 30 Hz Butterworth filter to displacement and force.
4. Calculate velocity and acceleration from backward differences of filtered
   displacement.
5. During the first 2 s, accumulate the standard deviations of filtered
   `[a, v, x, F]`. Do not produce parameter estimates during this period.
6. Remove each TLS window's column means and divide the columns by the four
   stored noise standard deviations.
7. Apply SVD to the whitened `[a, v, x, F]` matrix. Transform the smallest
   right singular vector back with the noise scales and calculate
   `[m; c; k] = -q(1:3)/q(4)`.

## Window acceptance and KF

- Calculate a dense TLS candidate every 64 samples.
- Reject the window when `rms(F - mean(F)) <= 20 N`, the result is nonfinite,
  mass is nonpositive, or stiffness is nonpositive.
- Do not route rejected windows to LSE.
- Only assimilate a candidate when its endpoint is at least 205 samples after
  the previous assimilated endpoint. Overlapping candidates may be logged but
  must not be treated as independent KF measurements.
- Initialize the KF state from the first accepted TLS candidate. Do not use
  fixed initial specimen parameters.
- At initialization, set the parameter scale to `abs([m; c; k])` and use
  `P = R = diag(parameter_scale.^2)` and
  `Q = diag(parameter_scale.^2)`.
- For later accepted candidates, use
  `P = P + Q*0.1`, `K = P/(P + R)`,
  `theta = theta + K*(theta_tls - theta)`, and
  `P = (eye(3) - K)*P`.

## Outputs and verification

Keep the existing `m_hat`, `c_hat`, and `k_hat` outputs. Replace the current
fallback output meaning with a status that distinguishes noise acquisition,
low excitation/rejected TLS, overlapping candidate not assimilated, and KF
assimilation.

Before a target run, verify that the embedded implementation matches
`windowed_noise_whitened_tls.m` sample-for-sample on one saved record. Then run
the physical verification workflow and compare the logged online parameters
against the offline result from the same record.
