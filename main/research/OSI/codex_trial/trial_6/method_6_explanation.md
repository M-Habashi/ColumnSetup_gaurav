# Trial 6: Coherence-Adaptive Complex FRF State Filter

This method starts from the trusted nominal `H_dc_dm` model and updates only a
fixed set of complex transfer-function points. Each frequency point is treated
as one independent complex state:

```text
x_j(k) = H_dc_dm(e^(i*w_j), time k)
```

where `j` is the frequency index and `k` is the 0.5 s online update index.

## State Model

The state evolves as a random walk:

```text
x_j(k|k-1) = x_j(k-1|k-1)
P_j(k|k-1) = P_j(k-1|k-1) + Q_j
```

This says the actuator/specimen dynamics are expected to move gradually, but
there is no assumed parametric shape for that movement. The process covariance
`Q_j` controls how fast each frequency point is allowed to move away from the
nominal model.

## Measurement Model

Every 0.5 s window produces one direct complex FRF measurement. The
implementation tracks `4:4:80 Hz`; this avoids the 2 Hz FFT bin because a
0.5 s window contains only one 2 Hz cycle, making that point too fragile for
fast online margin decisions.

```text
z_j(k) = FFT(dm)_j / FFT(dc)_j
```

The measurement equation is:

```text
z_j(k) = x_j(k) + v_j(k)
```

The measurement is noisy because the 0.5 s window is short. Instead of trusting
all frequency points equally, the method computes an adaptive measurement
variance `R_j(k)`.

## Adaptive Measurement Noise From Coherence

A single 0.5 s FFT segment cannot produce meaningful ordinary coherence by
itself. To get a usable online confidence value, Trial 6 keeps exponentially
weighted running spectra at every frequency:

```text
Suu_j(k) = (1-a) Suu_j(k-1) + a |U_j(k)|^2
Syy_j(k) = (1-a) Syy_j(k-1) + a |Y_j(k)|^2
Syu_j(k) = (1-a) Syu_j(k-1) + a Y_j(k) conj(U_j(k))
```

Then the online coherence estimate is:

```text
gamma_j^2(k) = |Syu_j(k)|^2 / (Suu_j(k) Syy_j(k))
```

The measurement noise increases when coherence is poor and when the input
energy at that frequency is weak:

```text
R_j(k) = scale_j * (R_floor + R_coh + R_power)
R_coh  = c_coh^2 * (1 - gamma_j^2) / (gamma_j^2 + epsilon)
R_power = c_power^2 / max(relative_input_power, floor)
```

So a coherent, strongly excited point gets a larger Kalman gain and can move the
state quickly. A weak or incoherent point gets a small gain, so the estimate
stays close to the previous state and the nominal model.

## Complex Kalman Update

The scalar Kalman gain is applied to the complex residual:

```text
K_j(k) = P_j(k|k-1) / (P_j(k|k-1) + R_j(k))
x_j(k|k) = x_j(k|k-1) + K_j(k) * (z_j(k) - x_j(k|k-1))
P_j(k|k) = (1 - K_j(k)) P_j(k|k-1)
```

This is equivalent to applying the same confidence to the real and imaginary
parts of the transfer-function point.

## NCF Indicator

After every 0.5 s update, the fixed PID frequency response is multiplied by
the current filtered transfer-function points:

```text
L_j(k) = PID(e^(i*w_j)) * x_j(k|k)
```

The online NCF indicator is the minimum normalized Nyquist distance over the
tracked frequency grid:

```text
NCF(k) = min_j |1 + L_j(k)| / sqrt(2 * (1 + |L_j(k)|^2))
```

This gives one margin estimate every 0.5 s while still using the trusted
nominal model as the prior.

## Decision Smoothing

The raw state-filter margin is saved as `RawNCFMargin`. The plotted and
decision-facing `NCFMargin` is a causal confidence-smoothed version initialized
at the nominal margin. Its update gain is small and is scaled by average
coherence plus valid point count. This keeps the `0.5 s` update rate but avoids
switching decisions from one noisy half-second estimate.
