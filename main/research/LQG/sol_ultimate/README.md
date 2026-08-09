# `sol_ultimate`

This folder audits the existing LQR/LQG work and develops the evidence for a simple robust-controller research direction.

The defensible direction is a **fixed pressure-coordinate robust LQGI**: one observer-controller, one error-integrator state, and one experimentally validated scalar coordinate for pressure loss. The current 7k/5k difference is only a secant between two models; it is not evidence by itself that the plant family is one-dimensional. At least one additional pressure model and one held-out condition are required.

The literature audit also found direct integral-LQG RTHS precedents in [Zhang et al. (2022)](https://doi.org/10.6052/j.issn.1000-4750.2021.01.0023) and [Condori Uribe et al. (2023)](https://doi.org/10.3389/fbuil.2023.1270996). Therefore neither integral LQG nor adaptive integral-LQG-plus-prediction is the novelty. A publishable RTHS contribution must instead establish the pressure coordinate experimentally, use one fixed controller, certify the complete deployed loop, and beat those baselines under fair broadband and physical-RTHS tests.

Open the [interactive HTML report](main/research/LQG/sol_ultimate/LQG_web/index.html) for the concise visual argument, linked 7k/5k step responses, and closed-loop Bode magnitude/phase plots. Read [REPORT.md](main/research/LQG/sol_ultimate/REPORT.md) for the full evidence, mathematics, literature boundary, and falsification plan.

The report loads its article components with JavaScript. Serve `LQG_web` through a local HTTP server instead of opening `index.html` directly from the filesystem.

## Reproduce the numerical audit

Open and run:

```matlab
run_sol_ultimate_study
```

The runner executes:

- `analyze_source_evidence`: saved PID, endpoint FRF, and identified-parameter evidence;
- `analyze_lqg_baseline`: nominal Kalman-observer covariance sweep on 7k and 5k;
- `analyze_endpoint_tangent_margin`: endpoint-secant mean-square diagnostic and reduced computation (legacy filename); and
- `analyze_lqgi_comparator`: the classical integral-LQG benchmark that any proposed controller must beat.

The generated MAT files each contain one top-level `result` struct. No physical actuator or Speedgoat workflow is run.

To regenerate the HTML report's plotted data from the saved MATLAB models, run:

```matlab
design_lqr_ncf_match
design_lqri_ncf_match
generate_html_report_data
```

The first two functions design the Section 04 LQR and Section 05 LQRI by matching the loop-only normalized NCF measure used by `custom_stability_margins` to the nominal PID result. The LQRI design uses MATLAB's built-in `lqi` function. PID unit-step limits provide Bryson-normalized starting weights for independent logarithmic grids, followed by an unbounded positive refinement that minimizes logarithmic departure from the Bryson scaling under the exact NCF constraint. The generator writes `html_report_plot_data.mat` with one top-level `result` struct and refreshes `LQG_web/data/report-plot-data.js` for the component-based report.
