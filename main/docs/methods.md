# Specimen Mode Parameter Estimation Methods

Goal: estimate `m`, `c`, and `k` from the measured specimen data.

At this point, do not manually filter any signal. We want to compare which methods handle noise and bias better.

Data use:
- Use the chirp and BLWN data files separately for estimation.
- Use the noise file only when a method needs noise-level information, such as scaled TSE.
- Use the slow sine data file for validation. Since it is slow, `k` can be estimated accurately and used as a validation reference.

Methods to try:

1. LSE least square estimate
2. TSE total least square estimate
3. Scaled TSE
4. FRF H1
5. FRF H2
6. FRF Hv
7. FRF weighted with coherence
8. Twice-integrated form:

```matlab
m*x + c*int(x) + k*int(int(x)) = int(int(F)) + initial-condition terms
```

9. Instrumental Variable Regression
10. MCMC
11. MCMC2
