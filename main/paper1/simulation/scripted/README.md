# Scripted v-RTHS runtime

Run `scripted_main.m`. It reproduces the active `vRTHS_2024` execution path
using only MATLAB `.m` code at runtime: no model is loaded and no `.slx` file
is required.

The requested user parameters are at the top of `scripted_main.m`. The
controller section exposes bandwidth and phase-margin pairs `bw_a`/`pm_a`,
`bw_b`/`pm_b`, and `bw_c`/`pm_c`; bandwidths are in rad/s and phase margins
are in degrees. `start_c` selects controller `'A'`, `'B'`, or `'C'`.
`switch_on` enables (`1`) or disables (`0`) event-driven A/B switching. With
switching enabled, Controller A switches to B when A's independently evaluated
NCF crosses downward through `b_th`. While B is active, both controllers' NCFs
continue to be evaluated; the model switches back to A only after A's NCF stays
above `b_th_2` continuously for `switch_back_hold` seconds (2 seconds by
default). If A later crosses `b_th` again, it switches to B again, so the cycle
can repeat. Controller C is outside this switching path and remains selected
when `start_c = 'C'`.

`simulation_case` selects the four paper scenarios: Case I is the undamaged
linear specimen with Controller A, Case II is the undamaged linear specimen
with Controller B, Case III retains Controller A while the nonlinear specimen
degrades toward instability, and Case IV enables the A-to-B switching strategy
for the same degrading nonlinear specimen.

The current modified-model tradeoff pair uses Controller A at `70 rad/s`
and `70 deg`, and Controller B at `55 rad/s` and `55 deg`. With the shared
phase lead, A provides the higher-performance response while its NCF curve
collapses near `alpha = 0.27`; B has the larger NCF reserve and retains a
nonzero margin down to `alpha = 0`. B's nominal J4 exceeds A by `6.90`
percentage points, satisfying the minimum five-point separation.
Together with the shared retuned phase lead, the verified nonlinear J4 values
are `19.36%` for A and `26.26%` for B, while the sampled effective damping is
`6.41%` for A and `6.15%` for B.

`consider_damage` selects no damage (`0`), the legacy prescribed stiffness
profile (`1`), or degrading Bouc-Wen hysteresis (`2`). `alpha_start`
selects the initial specimen and reference stiffness ratio from `0` to `1`;
its default is `1`. In legacy mode only, `alpha_min` selects the final degraded
specimen stiffness ratio and cannot exceed `alpha_start`. The intermediate
plateau is `min(0.75, alpha_start)`, and the transition timing is unchanged.

The degrading Bouc-Wen settings follow the specimen section in
`scripted_main.m`. `post_yield_ratio` is the force equation's residual ratio
rho (default `0.3`), `u_y` is the equivalent yield displacement (default
`23 mm`), `n` is the transition exponent (default `4`), and `sigma` sets
the beta/gamma split (default `0.769230769230769`). The code derives
`beta_b = sigma/u_y^n` and `gamma_b = (1-sigma)/u_y^n`, giving
`2.74881368074e-6 mm^-4` and `8.24644104221e-7 mm^-4` at the defaults.
Strength and stiffness degradation use `delta_nu = 0.05 mm^-2` and
`delta_eta = 0.05 mm^-2`. `reference_delta_nu` and
`reference_delta_eta`, listed immediately below them in `scripted_main.m`,
set the same two coefficients independently for the reference model. If a
programmatic caller omits either reference option, it inherits the matching
specimen coefficient. The exponent `q` (default `6`) weights the
damage-driving work by proximity to yield so linear-range motion contributes
smoothly less. `lse_window` sets the trailing least-squares stiffness-estimation
window in seconds (default `1 s`). These settings are inert in modes `0` and
`1`; `alpha_min` configures only legacy mode.

The phase-lead section immediately after the Bouc-Wen parameters exposes
`lead_gain`, `lead_zero`, and `lead_pole` for
`G_lead(s) = lead_gain*(s + lead_zero)/(s + lead_pole)`. Frequencies are in
rad/s. The retuned modified-model defaults are `31.6431547`,
`49.3502225 rad/s`, and `1657.846121 rad/s`; older programmatic
calls continue to receive the original parameter set when `modified = 0`.

The logged controller search is split into reproducible stages:
`scripted_search_ncf_tradeoff_controller_grid` records the complete NCF curve
grid, `scripted_search_ncf_tradeoff_seed_trials` runs the broad nonlinear
pair comparison, and `scripted_search_ncf_tradeoff_refinement` records the
nearby performance boundary. Acceptance uses a minimum five-percentage-point
J4 difference, not a relative multiplier. Their CSV/MAT logs are written under
`Results/ncf_performance_tradeoff_search`.

`scripted_search_ab_phase_lead_ncf` is the resumable end-to-end retuner for
Controller A, Controller B, and their shared phase lead. It reuses the PI grid,
requires Controller A's NCF at `alpha = 1` to be at least `0.25`, screens the
complete sampled loop over degraded alpha wherever A can be active, screens B
over the full configured degradation grid, and then runs A-only, B-only, and
switched nonlinear earthquake trials. Checkpoints, CSV logs, a comparison
report, and the selected `scripted_main` assignments are written under
`Results/ab_phase_lead_ncf_search`. Call the function with `false` to restart a
checkpoint deliberately.

The constitutive equations are implemented as
`F_BW = K0*(post_yield_ratio*d + (1-post_yield_ratio)*z)`,
`zdot = (d_dot - nu*beta_b*abs(d_dot)*z*abs(z)^(n-1) -
nu*gamma_b*d_dot*abs(z)^n)/eta`, and
`Edot = (abs(z)/u_y)^q*z*d_dot`, with
`nu = 1 + delta_nu*E` and `eta = 1 + delta_eta*E`. The runtime stores `z`
in metres and `E` in square metres, converts all millimetre-based parameters
accordingly, and constrains accumulated work to be nonnegative and `eta` to
be at least one. Both the specimen and its matched reference counterpart have
independent `z` and `E` states. At each 4096 Hz major sample, the scheduler
uses the equivalent displacement-increment update for `z` and trapezoidal
update for `E`; both values are held during the RK4 minor stages. This matches
the stable realization used by the established Bouc-Wen branch.

With damage disabled, the specimen remains at `alpha_start`. The reference is
rebuilt at `K_N + alpha_start K_E` and remains fixed. During time simulation,
legacy degradation and degrading Bouc-Wen hysteresis are both applied to the
specimen and to the reference substructure. Outside time simulation, the
linear reference, controller calculations, NCF, and coupled-damping report use
`alpha_start`; they never substitute `alpha_min` or a Bouc-Wen tangent.
Standalone commands that explicitly sweep user-selected frozen stiffnesses
remain independent diagnostic studies.

`fs` is the RTHS sampling frequency in Hz (default `4096`). It determines the
simulation step and the Tustin discretization of the phase-lead and original
PI controllers. Results are saved to the repository's `Results` directory;
the original MAT fields are retained and `BoucWen` (specimen/reference `z` in
metres), `BoucWen_energy` (specimen/reference `E` in square millimetres), and
`Restoring_force` (specimen/reference nonlinear-spring force), and
`LSE_stiffness` (the Bouc-Wen specimen's rolling stiffness estimate in N/m)
are added.
In Bouc-Wen mode, `alpha` is the causal moving-window least-squares slope of
the measured specimen force-displacement relation, normalized by `k_e` and
clamped to `[0.001, 1]`. The centered fit `F = k*d + c` rejects a constant
force offset. Alpha starts at `alpha_start`; estimation begins only after the
complete `lse_window` has a displacement standard deviation of at least 5% of
`u_y`. If excitation later falls below that threshold, the estimator holds
its last valid alpha and stiffness. The online NCF indicator uses this
estimated-or-held alpha, so the last plot panel shows the same alpha/NCF pair
used by the switching logic. Modes `0` and `1` retain their existing alpha
paths. The indicator plot uses the just-completed trial and therefore does
not stop for the original file-selection prompt.

After each completed `scripted_run`, the exact A/B/C controller gains and run
options are saved to `Results/scripted_last_run_configuration.mat`. The `ncf`
command loads this snapshot before sweeping alpha, so its curves use the same
controllers as the last completed simulation rather than copied constants.

For the modified benchmark, the 30% experimental-mass increase preserves the
specified experimental damping ratio by recalculating `c_e` and `CE(1,1)`.
The scripted actuator command path uses unity gain; the original benchmark's
`1.0261` laboratory calibration factor is intentionally not applied. Each
`scripted_run` prints and returns an A/B/C small-signal table containing NCF
and coupled damping at `alpha_start` only. Coupled damping freezes the
executed sampled loop at that initial stiffness while retaining its constant
viscous damping. NCF retains the existing `ncf.m` convention, which preserves
the nominal damping ratio as stiffness changes. A second table reports each
PI controller's P gain, I gain, lowest unity-gain crossover bandwidth, and
phase margin at that crossover. It also reports the maximum absolute PI
controller output, interpreted by the servo model as a displacement demand
and reported in millimetres, from matching saved pure-controller simulations.
The `tables` Habashi command only loads these saved maxima; it does not run
the simulation. Missing A/B/C runs are reported as `NaN`.

Run the Habashi command `lyap('A','C')` to test controllers A and C for a
common quadratic Lyapunov function. Any distinct A/B/C pair is accepted, for
example `lyap('A','B')` or `lyap('B','C')`. As in the original
`Lyp_switching_boundary.m`, it uses the reduced continuous tracking loop and
sweeps frozen specimen stiffness from `alpha = 1` to `0` in increments of
`0.05`. The specimen damping coefficient remains at its executed constant
value. This standalone command only constructs linear matrices and solves
LMIs; it does not run a time simulation. It returns the trace-normalized
common matrix at the lowest feasible grid value. This command intentionally
shadows Control System Toolbox `lyap` while `scripted` is first on the path.

Controller C is generated by `custom_pi_tune`. The current `scripted_main`
settings use `target_ncf_c = 0.40` and `target_ncf_c_alpha = 1`. The latter
independently selects the frozen stiffness ratio where that NCF target and
coupled damping are evaluated. The tuner accepts an absolute NCF error of
`0.01`, enforces a minimum local tracking bandwidth of `20 rad/s`, and
maximizes the first sampled coupled-mode damping. It uses a logarithmic gain
survey followed by log-gain Nelder-Mead refinement.
Controller A and B continue to use bandwidth/phase-margin
`pidtune` settings.

Computational blocks are separated into `blk_*.m` files. Pure routing and UI
blocks (ports, Goto/From, buses, displays, scopes, and terminators) are named
signals in `scripted_engine.m`; they have no numerical operation to execute.
The ode4 scheduler executes the allocation-light `scripted_rhs_hot.m`; the
block-by-block `scripted_rhs.m` remains alongside it as the readable reference
mapping. Both implement the same equations and evaluation order.

The indicator figure reduces copied display vectors with a min/max envelope
budget based on the 6.27-inch output width. Endpoints, displacement extrema,
and alpha/indicator plateau transitions are retained. This affects only figure
vertices; saved simulation arrays and evaluation metrics remain full-rate. Its
first three panels also show 0.20-second peak envelopes of the instantaneous
absolute J4, J5, and J6 displacement errors in millimetres on fixed right-hand
axes. The envelope bridges rapid error zero crossings so the indicators read
as continuous filled bands rather than isolated triangular peaks.
For Case IV, enabling the indicator plot also creates a separate specimen hysteresis figure
from the internal displacement and restoring-force histories. The loop uses the
Bouc-Wen branch's zero-centered five-tick styling and is exported beside the
indicator SVG with the suffix `_scripted_hysteresis.svg`. Its force-displacement
trace is drawn at 50% opacity so overlapping cycles remain distinguishable.
Other paper cases export only the indicator figure. Programmatic callers can pass `false` as the third argument to
`blk_plot_indicator` when only the indicator SVG should be exported.

For exact runner compatibility, additional perturbed simulations execute but
their evaluation/save stage retains the nominal signals. This mirrors the
existing `F3_simulation.m` `EQ_input` guard when `num_add > 0`.

`scripted_self_test.m` is intentionally fixed at `fs = 4096` and checks the
deterministic scheduler, parameter invariants, and robustness table.
`scripted_damage_self_test.m` checks mode selection and validation, the exact
Bouc-Wen equation and stiffness mapping, both nonlinear reference paths,
analysis isolation at `alpha_start`, and readable/hot RHS equivalence. Other
sampling frequencies should be validated against a matching Simulink run.

The online NCF indicator is a slow task. At the default `fs = 4096 Hz`, it
runs once every 100 major samples, or at `40.96 Hz`, rather than at every RTHS
integration step. Each update uses 10,000 logarithmically spaced frequencies
from `0.1` to `10,000 rad/s`. The active/blended controller and Controllers A
and B are evaluated independently over that shared grid, for three margins and
30,000 frequency-controller pairs per slow update. Run the Habashi command
`scripted_benchmark_indicator_runtime` to measure one margin and the complete
three-margin slow task against its `100/fs` deadline. The command records the
host and MATLAB version and labels its results as host timings; a Speedgoat or
Simulink Real-Time claim still requires measurement with the deployed target
profiler.

Run `scripted_sample_rate_study.m` to execute the nominal model in both
Simulink and the scripted engine at 4096, 2048, and 1024 Hz. The study saves
compact comparison tables under `Results/sample_rate_study`; the full raw MAT
outputs are reproducible and intentionally excluded from Git.
