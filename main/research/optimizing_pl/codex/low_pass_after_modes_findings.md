# Low-pass filter after structural modes

## Structural mode target

For `fem_sp1_7000.mat`, the modal frequencies are:

```text
Reference FEM:                 2.4220, 8.7496, 18.1401 Hz
Numerical-substructure floor:  2.3426, 8.4787, 17.7728 Hz
```

So "after the highest structural mode" means a cutoff above about `17.8 Hz`.
The tested cutoffs were:

```text
1.10x mode = 19.55 Hz
1.25x mode = 22.22 Hz
1.50x mode = 26.66 Hz
2.00x mode = 35.55 Hz
2.50x mode = 44.43 Hz
3.00x mode = 53.32 Hz
```

First- and second-order low-pass filters with DC gain 1 were added to
`robust_vhs_phase_lead_optimization.m` and evaluated in the same robust ensemble.
The updated `robust_vhs_phase_lead_result.mat` contains these rows.

## Verified low-pass results

| Candidate | min NCF | min GM dB | max pole | max J4 % | max command ratio | worst NCF case |
|---|---:|---:|---:|---:|---:|---|
| 1st order, fc 35.55 Hz | 0.2334 | 7.211 | 0.99991 | 96.233 | 0.998 | healthy H, healthy k |
| 2nd order, fc 44.43 Hz | 0.2297 | 7.018 | 0.99992 | 97.521 | 1.000 | healthy H, healthy k |
| 1st order, fc 26.66 Hz | 0.2264 | 7.036 | 0.99992 | 98.903 | 0.996 | healthy H, healthy k |
| 2nd order, fc 53.32 Hz | 0.2341 | 6.177 | 0.99991 | 95.928 | 1.000 | healthy H, healthy k |
| 1st order, fc 44.43 Hz | 0.2378 | 5.944 | 0.99991 | 94.634 | 0.999 | healthy H, healthy k |
| 1st order, fc 22.22 Hz | 0.2209 | 6.629 | 0.99992 | 101.040 | 0.994 | healthy H, healthy k |
| 2nd order, fc 35.55 Hz | 0.2232 | 6.238 | 0.99992 | 99.958 | 1.000 | healthy H, healthy k |
| 1st order, fc 19.55 Hz | 0.2166 | 6.393 | 0.99992 | 102.770 | 0.993 | healthy H, healthy k |
| 1st order, fc 53.32 Hz | 0.2407 | 5.129 | 0.99991 | 93.573 | 0.999 | healthy H, healthy k |
| 2nd order, fc 26.66 Hz | 0.2124 | 5.248 | 0.99992 | 104.150 | 1.000 | healthy H, healthy k |
| 2nd order, fc 22.22 Hz | 0.2039 | 4.672 | 0.99992 | 107.620 | 1.000 | healthy H, healthy k |
| 2nd order, fc 19.55 Hz | 0.1969 | 4.330 | 0.99993 | 110.530 | 1.000 | healthy H, healthy k |

## Interpretation

A low-pass cutoff just after the highest structural mode is technically possible,
but in this current setup it is not enough by itself. It improves neither the
robust NCF target nor the response metric compared with the verified authority
solution:

```text
Best authority solution:
  min NCF = 0.3677
  min GM = 7.435 dB
  max J4 = 72.288 %

Best low-pass-only result:
  min NCF = 0.2407
  min GM = 5.129 dB
  max J4 = 93.573 %
```

The reason is phase lag. Even though the low-pass attenuates content above the
structural modes, its phase lag begins before the cutoff. When the cutoff is close
to the third mode, it distorts the structural response and worsens `J4`. When the
cutoff is moved higher to reduce lag, it no longer attenuates enough of the
dangerous actuator/resonance band to recover the robust margin.

## Practical takeaway

Use a low-pass only if the dangerous frequency is clearly above the structural
band and the cutoff can be placed with enough separation:

```text
fc >= 2 to 3 times highest structural mode
```

For this model, that means `35.5-53.3 Hz`. Those filters were stable, but still
did not meet the `NCF >= 0.35` robust target.

If the specific problem is around `35 Hz`, a notch or band-limited attenuation is
more appropriate than a broad low-pass:

```text
A_safe(z) ~= 1 below 18 Hz
A_safe(z) < 1 near the dangerous band
A_safe(z) ~= 1 again where possible above the band
```

That preserves the structural modes better than a low-pass while directly
reducing the problematic frequency content.
