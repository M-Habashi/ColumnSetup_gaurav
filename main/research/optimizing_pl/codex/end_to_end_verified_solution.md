# End-to-end verified solution for damage-robust vHS phase_lead

## What was verified

The executable study is:

```text
research/optimizing_pl/codex/robust_vhs_phase_lead_optimization.m
```

It was run successfully offline in MATLAB. It evaluated:

```text
918 phase_lead candidates
19 healthy/damaged/further-damaged frequency-domain cases
33 selected candidates x 13 rational full-record time-domain cases
```

Outputs:

```text
robust_vhs_phase_lead_result.mat
robust_vhs_phase_lead_report.md
robust_vhs_phase_lead_summary.png
```

No Speedgoat or physical workflow was run.

## Main conclusion

A static phase_lead alone is not the robust solution. With the damage envelope
expanded beyond the two measured endpoints, the best no-authority candidate is
`no lead`, and it still fails the robustness target:

```text
alpha = 1 best case: no lead
min NCF = 0.1846
min GM = 3.410 dB
max pole = 0.999907
worst case = measured-shape rho 2, predicted k
```

The best verified end-to-end candidate is essentially an authority reduction:

```text
dd_to_actuator = 0.6 * G_tiny * dd

G_tiny:
  center = 3 Hz
  ratio = 1.05
  zero = 2.9277 Hz
  pole = 3.07409 Hz
```

Its verified robust margins are:

```text
min NCF = 0.3677
min GM = 7.435 dB
max coupled pole = 0.999866
max full-record J4 = 72.288 %
worst margin case = measured-shape rho 2, predicted k
```

Pure saved phase_leads are not robust over this envelope:

```text
pl_sp1_5000, alpha 1:
  min NCF = 0.0514
  min GM = 0.935 dB
  max pole = 1.002172
  worst case = 1.15*damaged H, healthy k

pl_sp1_7000, alpha 1:
  min NCF = 0.0029
  min GM = 2.251 dB
  max pole = 1.028860
  worst case = scalar H gain 2, predicted k
```

So the production answer is not "find a more aggressive phase_lead". The answer
is to split the problem:

```text
1. Offline: design against an ensemble using worst-case NCF/GM/pole constraints.
2. Online: add one authority scalar a(t) that can only move toward safer command
   authority when damage grows.
```

## Q1: best optimization criterion

Use the coupled vHS loop for every damage case `i`:

```text
A_i(z) = feedback(C_pid(z) * H_i(z), 1)
L_i(z) = -N(z) * (k_i/1000) * G_T(z) * A_i(z)
```

where `N(z)` is the numerical substructure force-to-`dd` model.

Hard gates:

```text
max_i abs(z_pole_i) < 1
min_i NCF_i >= 0.30 absolute floor
min_i NCF_i >= 0.35 preferred design floor
min_i GM_i >= 7 dB
max_i peak_command_ratio_i <= 1.25
```

Then minimize:

```text
score =
    max_i(J4_i)
  + 0.15*max_i(response_nrmse_i)
  + 0.02*max_i(tracking_nrmse_i)
  + margin_shortfall_penalties
```

The important change from `optimize_vHS_phase_lead_min_ncf.m` is that every
margin and every response metric is computed over the damage ensemble, not one
selected `specimen_file` and one selected `H_dc_dm`.

## Q2: predicting damage effect on `H_dc_dm`

The measured 7000-to-5000 damage is well represented as multiplicative actuator
gain plus stiffness loss:

```text
H_damaged ~= 2.4247 * H_healthy
complex RMS fit error over 0.1-80 Hz = 15.756 %
k_damaged/k_healthy = 0.7473
```

Use this as an uncertainty envelope:

```text
gamma(rho) = 1 + rho*(2.4247 - 1)
k_scale(rho) = 1 + rho*(0.7473 - 1)
H_rho = gamma(rho) * H0
k_rho = k_scale(rho) * k0
```

`rho = 0` is healthy, `rho = 1` is the measured 5000 state, and `rho > 1` is
excess damage. For a different initial `H_dc_dm`, use that new healthy `H0` and
apply the same multiplicative envelope.

Do not put `H5000/H7000` directly into a time-domain block. Use the scalar gain
model for rational time-domain simulations and use measured-shape frequency
responses for margin screening.

## Q3: online stability enhancement

Do not tune `P`, `I`, or phase_lead ratio live as the safety action. Those
directions are not monotonic across the damage cases.

Use one online authority scalar:

```text
dd_to_actuator = a(t) * G_T(z) * dd
```

or, equivalently, define a safety knob `kappa = 1 - a` and increase `kappa` when
the margin indicator degrades.

The verified table for the best candidate shows the direction:

```text
scale 1.00: min NCF 0.3677, min GM 7.435 dB
scale 0.90: min NCF 0.4016, min GM 8.350 dB
scale 0.70: min NCF 0.4708, min GM 10.533 dB
scale 0.50: min NCF 0.5407, min GM 13.456 dB
```

## Notch option

A focused notch-filter study was added:

```text
notch_filter_study.m
notch_filter_study_report.md
notch_filter_study_result.mat
notch_filter_study_summary.png
```

The tested notch form was:

```text
A(s) = (s^2 + 2*zeta_z*w0*s + w0^2)/(s^2 + 2*zeta_p*w0*s + w0^2)
```

with unity DC/high-frequency gain and attenuation at `w0` equal to
`zeta_z/zeta_p`.

Result:

```text
No filter:
  min NCF = 0.1846
  min GM = 3.410 dB
  max J4 = 88.340 %

Best notch-only:
  center = 38 Hz
  depth = 0.35
  zeta_pole = 0.08
  min NCF = 0.2537
  min GM = 7.232 dB
  max J4 = 89.096 %

Authority 0.6 only:
  min NCF = 0.3834
  min GM = 7.847 dB
  max J4 = 73.097 %

Best notch + authority:
  alpha = 0.6
  center = 42 Hz
  depth = 0.8
  zeta_pole = 0.08
  min NCF = 0.3981
  min GM = 9.071 dB
  max J4 = 73.181 %
```

Interpretation: notch-only helps compared with no filter, but it does not meet
the `NCF >= 0.35` robust target. Notch plus authority scaling gives a modest
margin improvement over scalar authority alone with nearly the same performance.
So the useful version is:

```text
dd_to_actuator = alpha * A_notch(z) * dd
```

not notch-only.

Use online OSI to decide when to move `a(t)`:

```text
estimated NCF >= 0.45: slowly relax a -> nominal
estimated NCF < 0.40 sustained: reduce a using a prevalidated table
estimated NCF < 0.30-0.35 or resonance trip: set a = a_min and pause/ramp down
stroke/force/velocity/saturation trip: ignore estimator and pause/ramp down
```

Method 7 from `research/OSI` is the right always-on monitor because it uses the
closed-loop resonance in `dm` and does not require the command to excite the
binding frequency.

## Production implementation path

Inside the real optimizer, make these changes:

```text
1. Build a damage ensemble of (H_i, k_i), using measured endpoints and
   extrapolated multiplicative damage.
2. Replace single-case NCF/GM/pole metrics with min_i/max_i ensemble metrics.
3. Simulate full-record time response for the measured/scalar rational members.
4. Keep measured-shape cases frequency-domain only.
5. Add the authority scalar a as a separate online safety block, not as PID
   retuning.
```

The verified script in this folder is the reference implementation for those
changes.
