# Paper 1

**An Online Stability Indicator for Real-Time Hybrid Simulation Emphasizing Physical Substructure Degradation** — M. Gomaa, E. D. Patino, J. N. Villamizar, J. W. Condori Uribe, and S. J. Dyke.

Public package: https://github.com/M-Habashi/ColumnSetup_gaurav/tree/master/main/paper1

Repository folder: `main/paper1/`. Start with this README; no repository-wide search is needed.

## Direct entry points

| Need | File relative to this folder |
| --- | --- |
| Read the paper, including equations and references | [manuscript/paper1.md](manuscript/paper1.md) |
| Original clean manuscript and embedded figures | [manuscript/paper1.docx](manuscript/paper1.docx), [PDF](manuscript/paper1.pdf) |
| MATLAB scripts for the methodology and paper figures | [figures/README.md](figures/README.md) — figure-to-script map and publication source copies |
| Calculate critical degradation and oscillation frequency | [simulation/scripted/theoretical.m](simulation/scripted/theoretical.m) |
| Original derivation script and plots of the equation terms | [simulation/Stability Analysis/theoritical_alpha.m](simulation/Stability%20Analysis/theoritical_alpha.m) |
| Run one virtual RTHS case | [simulation/scripted/scripted_main.m](simulation/scripted/scripted_main.m) |
| Run all four paper cases and save settings/results | [simulation/scripted/scripted_run_all_paper_cases.m](simulation/scripted/scripted_run_all_paper_cases.m) |
| Model parameters, controllers, and required inputs | [simulation/scripted/scripted_build_trial.m](simulation/scripted/scripted_build_trial.m) |
| NCF, delay/gain margins, and switching analysis | `simulation/scripted/ncf.m`, `margins.m`, `lyap.m` |
| Original mass/stiffness sensitivity study | [simulation/Stability Analysis/Figure_5_sensitivity_parallel_solver.m](simulation/Stability%20Analysis/Figure_5_sensitivity_parallel_solver.m) |
| Detailed runtime documentation and block mapping | [simulation/scripted/README.md](simulation/scripted/README.md), [BLOCK_MAP.md](simulation/scripted/BLOCK_MAP.md), [EQUIVALENCE.md](simulation/scripted/EQUIVALENCE.md) |
| Saved Cases I–IV, settings, and evaluation summaries | [simulation/Results/](simulation/Results/) — batch `paper_rerun_20260902_121057` |

## Critical degradation equation

The manuscript's Sections 3 and 3.1 separate the degradation-dependent specimen from the rest of the transfer system:

\[
Y(s)=G_{a3}(s)\left[G_{a2}(s)+C_{\mathrm{in}}(s)G_{a1}(s)(C_{\mathrm{out}}(s)+1)\right],
\]

\[
CE(s,\alpha)=ms^2+2\zeta\sqrt{m\alpha k}\,s+\alpha k+Y(s)=0.
\]

Here `alpha` is the residual stiffness fraction (`1` = healthy), `m` is specimen mass, `k` is initial stiffness, and `zeta` is the assumed damping ratio. At the stability boundary, set `s = j*omega_cr`. The scalar frequency equation used by `theoretical.m` is

\[
\frac{m\omega^2}{k}-\frac{\operatorname{Re}Y(j\omega)}{k}
-\frac{[\operatorname{Im}Y(j\omega)]^2}{4\zeta^2\omega^2mk}=0,
\qquad
\alpha_{\mathrm{cr}}=\frac{[\operatorname{Im}Y(j\omega_{\mathrm{cr}})]^2}
{4\zeta^2\omega_{\mathrm{cr}}^2mk}.
\]

`f_cr = omega_cr/(2*pi)` converts rad/s to Hz. This calculation predicts the onset of instability and its oscillation frequency; it does not predict a finite response-peak amplitude or the time at which a particular experiment reaches that degradation level.

The copied implementation retains the original root branch near `282.2 rad/s`. For a different plant/controller, inspect all candidate roots, the unsquared imaginary equation, and `0 < alpha <= 1` before identifying the first stability loss. The theoretical calculation uses the continuous-time model; the simulation uses sampled controller dynamics. See the source files for these distinct damping/discretization assumptions.

## MATLAB use

From a clone, set MATLAB's current folder to `main/paper1/simulation/scripted` and open the selected entry-point file before running it.

```matlab
% Open theoretical.m, then calculate without running a time simulation:
r = theoretical;
omega_cr = r.omega_cr;
alpha_cr = r.alpha_cr;
f_cr = omega_cr/(2*pi);
```

`theoretical` uses the included `../Results/scripted_last_run_configuration.mat`; if absent, it uses the fallback settings in its source. A completed simulation updates that configuration. Open and run `scripted_main.m` for a selected case, or open `scripted_run_all_paper_cases.m` and call `batch = scripted_run_all_paper_cases;` for all four. Run `habashi` to list analysis/plot commands.

Requirements: MATLAB and Control System Toolbox for the scripted calculation/runtime; Robust Control Toolbox for the NCF/LMI workflows that use its functions; Optimization Toolbox for `fmincon`-based studies; Parallel Computing Toolbox for the original parallel sensitivity study. Simulink is needed only for the included legacy `.slx` workflow. Optional target-specific scripts have additional Speedgoat/SLRT requirements. The primary scripted simulation does not load Simulink or require physical hardware. Commands named `step`, `bode`, and `lyap` in `scripted/` intentionally shadow toolbox names.

Required building cases, saved controller models, plant data, and El Centro/Kobe/Morgan input records are included under `simulation/`. Results are written to `simulation/Results/`. Archived MAT metadata may contain original absolute paths; use the corresponding local filenames in that folder, or regenerate a batch before running commands that consume its saved path records. The legacy `Stability Analysis/` scripts expect variables from the legacy simulation workspace; use `scripted/theoretical.m` for the packaged entry point.

## Snapshot provenance

Packaged on 2026-11-16. Manuscript files are unchanged copies of `aab paper1/writing/submit/Paper Submit 03/SCHM_Main_Manuscript_Rev2.docx` and `.pdf`. Markdown and its media were extracted from that DOCX; equations retain MathML converted from native Word equations. The DOCX/PDF are the authoritative typeset sources.

Simulation source is copied from `aab paper1/modified BM of V23`, branch `scripted`, commit `344ac84af88045a83be95ba631f5bd75dd2963f1`. All tracked simulation/analysis source and input files are included. Publication MATLAB figure-source copies and the figure manifest come from `aab paper1/writing/submit/Paper Submit 02/figures/`. One saved four-case batch, its settings/evaluation files, and the analysis configuration/cache files are retained. Duplicate historical runs, temporary files, build caches, review correspondence, and Git metadata are omitted. Saved outputs and current source are separate snapshots; this packaging operation did not rerun simulations or tests or establish a new numerical match to the manuscript.
