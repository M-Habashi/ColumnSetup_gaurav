# Damage-robust phase_lead optimization recommendation

## Summary

The phase_lead optimizer should not optimize one selected specimen or one selected
`H_dc_dm` model. Use an ensemble objective and score the worst damage case. The
minimum acceptable constraints should be evaluated on the coupled hybrid loop

```text
L_i = -num_tf_i * (k_i/1000) * G_T * feedback(C_pid * H_i, 1)
```

where `G_T` is the phase_lead and each case `i` represents one plausible damage
state.

Recommended hard feasibility checks:

```text
min_i NCF_i >= 0.35 to 0.40
min_i GM_i_dB >= 7
max_i abs(z_pole_i) < 1
max_i peak_command_ratio_i <= command_limit
```

Use `0.35` or `0.40` as the optimization target even if the observed minimum
experimental stability threshold is `0.30`, because the identified damage model is
only an approximation.

Recommended score after feasibility:

```text
score =
    max_i(J4_i)
  + 0.25*mean_i(J4_i)
  + w_ncf*max(0, ncf_target - min_i(NCF_i))^2
  + w_gm*max(0, gm_target_db - min_i(GM_i_dB))^2
  + w_cmd*max(0, max_i(peak_command_ratio_i) - command_limit)^2
```

The important change from the current optimizer is that `min_i(NCF_i)`,
`min_i(GM_i_dB)`, and `max_i(J4_i)` are computed over all damage cases, not only
over the selected `specimen_file` and selected `H_dc_dm` file.

## Damage ensemble

Start with these measured endpoint and mismatch cases:

```text
1. healthy H, healthy k:  tf_sp_1_7000_20260627_210411.mat + sp1_7000.mat
2. damaged H, damaged k:  tf_sp1_5000_20260627_233333.mat + sp1_5000.mat
3. damaged H, healthy k:  tf_sp1_5000_20260627_233333.mat + sp1_7000.mat
4. healthy H, damaged k:  tf_sp_1_7000_20260627_210411.mat + sp1_5000.mat
```

Then add extrapolated damage cases, because the real specimen can degrade beyond
`sp1_5000.mat`. Two practical envelopes are:

```text
gain envelope: H_gamma = gamma * H_healthy, gamma in [1, gamma_max]

measured-shape envelope:
H_rho = H_healthy * (1 + rho*(H_damaged/H_healthy - 1)),
k_rho = k_healthy + rho*(k_damaged - k_healthy)
```

Use the gain envelope first because it is simple, stable as a transfer-function
model, and matches the observed "damage behaves like increased P gain" behavior.
Use the measured-shape envelope as a frequency-response margin check, not as a
blind physical prediction.

## What the saved models show

Read-only MATLAB inspection of the two saved `H_dc_dm` models gave:

```text
H_damaged/H_healthy median magnitude:
  1 to 20 Hz:   about 2.38
  20 to 45 Hz:  about 2.74
  45 to 80 Hz:  about 3.20

Best scalar fit over 0.1 to 80 Hz:
  H_damaged ~= 2.425 * H_healthy
  complex RMS fit error ~= 15.8 percent

Actuator open-loop C_pid*H margins:
  healthy: GM = 16.38 dB, NCF = 0.588
  damaged: GM = 6.88 dB, NCF = 0.344

Specimen stiffness:
  sp1_7000: 7.2006e6 N/m
  sp1_5000: 5.3808e6 N/m
  damaged/healthy = 0.747
```

So yes, damage can be approximated as a gain increase, but not exactly. The
damaged model also has frequency-dependent magnitude and phase changes. A scalar
gain-only model is useful as a conservative envelope; it is not a physical law.

Current saved phase_leads do not dominate across all cases. For example, using
the coupled loop `-num*k*G_T*feedback(C_pid*H,1)`:

```text
healthy H, healthy k:
  no lead NCF 0.256
  pl5000  NCF 0.286
  pl7000  NCF 0.300

damaged H, damaged k:
  no lead NCF 0.375
  pl5000  NCF 0.300
  pl7000  NCF 0.246

damaged H, healthy k:
  no lead NCF 0.326
  pl5000  NCF 0.178
  pl7000  NCF 0.314
```

This is the main reason the optimizer should use a robust/worst-case ensemble
criterion instead of selecting one model and improving that one model.

## Predicting damage effect on `H_dc_dm`

With only healthy and partially damaged identified models, prediction of future
excess damage is an extrapolation, not a guaranteed model. The defensible model is
an uncertainty envelope:

```text
H_actual(s) in {H_healthy(s) * W_damage(s, rho)}
```

where `W_damage` can be:

```text
scalar gain: W = gamma
measured ratio: W = 1 + rho*(H_damaged/H_healthy - 1)
```

For a different initial `H_dc_dm`, apply the learned multiplicative change to the
new baseline:

```text
H_pred_new = H0_new * W_damage
```

This can predict the direction of margin loss and create a robust design
envelope. It cannot guarantee the exact future damaged transfer function unless
more damage levels are identified and the trend is validated.

## Online stability improvement

Do not try to make live stability depend on increasing only `P`, only `I`, or only
phase_lead ratio. These are not monotonic stability knobs. Increasing integral
action can destabilize one mode while helping another, and increasing phase_lead
also increases high-frequency gain and can reduce margin in another damage case.

The safer online strategy is:

```text
1. Estimate an online stability indicator from measurements.
2. If estimated NCF falls below an alarm threshold, move toward a prevalidated
   safer command path.
3. Use one scalar safety knob s in [0, 1]:

   dd_to_actuator = (1 - s)*G_performance*dd + s*G_safe*dd

   where G_safe is no lead, a low-gain lead, or a prevalidated conservative
   filter.
```

Increasing `s` is then a monotonic move toward the conservative controller by
construction. It is still necessary to precompute margins for a grid of `s` values
and all damage cases, but this is much more controllable than retuning `P` and
`I` online.

If a single direct gain knob is needed, define it as a safety attenuation:

```text
dd_to_actuator = G_T*dd / (1 + s),  s >= 0
```

This sacrifices tracking performance, but it moves the coupled loop toward lower
feedback gain and is the most interpretable emergency stabilizing knob. Use it as
a fallback or pause-before-instability action, not as the normal performance
optimizer.
