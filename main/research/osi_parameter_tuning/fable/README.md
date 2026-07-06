# RTHS force-echo diagnosis — why the OSI collapses when the numerical loop closes

**Open `rths_echo_report.html` in a browser for the full story, figures and
validation.** (Self-contained; `rths_echo_report_template.html` + the
PowerShell inline step in the report footer scripts regenerate it.)

## TL;DR

The 3-DOF FEM numerical substructure has a direct feedthrough
`dd = C*x + interface_from_force*fm` (iff = -5.22e-8 m/N). Through the
fem3_ncf3 phase lead (HF gain 8) this puts a ZERO-LAG copy of ~ -0.23*dm
into `dd` at all frequencies. Above the top FEM mode (18.5 Hz) that echo IS
`dd`, so the OSI's cross-spectral FRF estimate measures the inverse outer
feedback path instead of the inner loop -> chordal margin 0.1-0.3 at bins
the gates cannot reject (echo is coherent AND stronger than the genuine
2-10 Hz EQ bins). Classic closed-loop identification bias; no estimator
parameter can fix it. BLWN/open-loop tests were always fine because
injected broadband power swamps the echo.

**Fix (one gain + one sum, estimator untouched):** feed the OSI's command
tap the strictly-proper FEM output only:
`u_osi = G_T(dd_fem - iff*fm) = G_T(C*x)`; the actuator keeps the full dd.

Validated on RTHS_02: median margin 0.29 -> 0.66, time below target
98% -> 6%, full authority 0% -> 76%, zero trips, and the genuine
instability record still detects (b < 0.1 at the event).

**Start-of-test drop** (the ~5 s biased dip right after the numerical loop
engages, plus idle-loop false margins): handled by `fable_evidence_gate.m`
- an excitation-evidence arming gate in front of the authority law. While
the (cleaned) command tap has not carried excitation (2 s RMS > 0.05 mm)
continuously for 6 s, the law receives b = NaN and HOLDS (its designed
no-evidence path); an abrupt excitation fade blanks the margin 4 s (stale
window). Fast trips are never gated. Results: RTHS_02 onset authority
0.08 -> 1.00 (full-a 78% -> 90%); the no-excitation record's authority
never moves (38% -> 100% full); warmed-up genuine events shed on time
(-0.5 s); a cold-start event (3 s after engagement) sheds ~11 s later -
information limit, rig interlocks are the backstop there.

## Files

| File | Purpose |
|---|---|
| `rths_echo_report.html` | The report (open this). |
| `fix_rths_echo_plan.md` | Speedgoat implementation plan: echo-free OSI tap (active ONLY when the signal generator's multiport switch selects the RTHS port), evidence gate in the runtime (diffs, fbla 32-36), window_s analysis (keep 5.0 s), staged verification. |
| `numerical_ncf_plan.md` | Outer-loop (numerical closed loop) NCF plan: vHS fixes (dynamic interface impedance Z=k+cs+ms^2, authority propagated to the outer loop) + online b_out by wrapping the estimator's per-bin T-hat with the known FEM/lead/k (publish-only stage first). |
| `rths_echo_diagnosis.m` | 10-record pipeline: echo detector/classifier (zero-lag test), baseline + fixed replays of the unchanged fable OSI + authority law, metrics, per-record figures. |
| `rths_echo_mechanism_figs.m` | Figs 1-3: zero-lag proof, spectral autopsy at t=95 s, complex-plane bias plot (RTHS_02). |
| `fable_evidence_gate.m` | Excitation-evidence arming gate (params/state/step; codegen-friendly scalar state). |
| `run_evidence_gate_validation.m` | Gate validation on 5 records + theta/arm_s sweep (figures gate_*.png). |
| `results/rths_echo_diagnosis.mat` | All replay traces + detector outputs. |
| `results/evidence_gate_validation.mat` | Gated vs ungated authority traces + sweep. |
| `results/echo_metrics.json` | Metrics table used by the report. |
| `figures/*.png` | All figures. |

## Run

```matlab
addpath research/osi_parameter_tuning/fable
rths_echo_mechanism_figs
out = rths_echo_diagnosis();          % ~5 min, loads ~2 GB of records
```

Caveats that matter when reading replays: offline echo reconstruction needs
one fitted scale (~0.92; records only store post-lead dd) and an engagement
gate; the Simulink wiring fix needs neither. Metrics are computed on the
engaged span. Two records (rising_emergency, no_inst_butindicators_jump)
ran with the live authority collapsed / no tracking and cannot be made to
look healthy offline - the runs themselves were casualties of the bug.
