# SOL-OSI course module

`index.html` is a self-contained lesson page (no CDN, no external assets) that
derives the SOL-OSI stability-margin estimator and its authority regulator
step by step, for a graduate course. Open it directly in any browser.

Structure: 10 scroll-revealed sections with hand-set HTML equations, five
interactive figures (Nyquist/chordal explorer, EWMA, confidence blend, rho-fit
loss, authority simulation), five toggleable multiple-choice checks, and
collapsible MATLAB panels quoting `control_and_HS/OSI/sol_osi.m` and
`control_and_HS/OSI/gpt5_6_4_auth.m` with line numbers.

## Data provenance

All charts use the real 7k loop, embedded as the `SOL` constant in the page
script. `l0_data.json` is the raw export, generated with MATLAB from the
canonical record:

- record: `saved_results/tests/gpt5_6_tests/20260710_1845_plNew_authON_oscillations_unstableAtEnd.mat`
- controller: `pid(0.15, 20, 0.0015, 1/512, dt)` ForwardEuler, `dt = 1/2048 s`
- plant: `model.H_dc_dm` from the record's `dependencies.exp_tf`
- grid: `cfg.freq_hz` exactly as built by `sol_osi('config', dt, C*H, struct())`

To regenerate after a plant or PID change: rebuild `C*H`, evaluate
`freqresp` on `cfg.freq_hz`, and paste the arrays into the `SOL` constant in
`index.html` (fields `f`, `L0re/L0im`, `Hre/Him`, `Cre/Cim`, `keep`,
`resKeep`, `nominal`, `cap`).

## Maintenance notes

- Code panels quote `sol_osi.m` by line number; re-check them if that file
  is edited.
- The authority simulation uses the defaults in `gpt5_6_4_auth.m`
  (target 0.55); the deployed RTHS config overrides `target_outer_ncf = 0.45`
  (noted in the page).
