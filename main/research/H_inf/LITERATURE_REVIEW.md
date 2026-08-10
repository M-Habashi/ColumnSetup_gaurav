# H∞ control for pressure-varying RTHS: literature map and novelty audit

**Search date:** 2026-08-09
**Project question:** Can one controller use the identified 7k–5k actuator/specimen family to outperform the current PID while retaining robust stability, command feasibility, and RTHS fidelity?

## Executive decision

The literature supports H∞ as a credible engineering route, but it also closes most broad novelty claims. H∞ loop shaping, mixed-sensitivity synthesis, parametric actuator identification, delay prediction, Kalman filtering, multiplicative-uncertainty analysis, and optimizer-tuned H∞ have all appeared in RTHS.

The strongest **conditional** paper direction is deliberately simple:

> Add one parameter-sensitivity output to an otherwise standard H∞ design so that the controller directly minimizes how much its closed-loop response changes from 7k to 5k. Use the existing specimen model to calculate that sensitivity, retain one fixed controller, and enforce the 2.5 command peak as a separate physical constraint.

This is a single equation-level addition, not a bundle of LPV, μ, prediction, filtering, and learning methods. It would be an RTHS control-method and experimental contribution, not a claim that parameter-sensitivity theory itself is new. It becomes publishable only if it beats a fairly tuned PID and ordinary mixed-sensitivity H∞ on the complete deployed loop and on held-out physical conditions.

## Review method and limits

This is a structured scoping review, not a PRISMA systematic review or a claim of exhaustive coverage. Searches combined `real-time hybrid simulation`, `RTHS`, `pseudodynamic`, `slow hybrid simulation`, `H infinity`, `robust control`, `mixed sensitivity`, `loop shaping`, `actuator compensation`, `parametric uncertainty`, `gain amplification`, `delay`, `LPV`, and `mu synthesis`. Primary publisher pages and papers were preferred. Citation chaining was used around the direct RTHS papers.

The search asks four questions:

1. What H∞ architectures have already been used in RTHS?
2. Which uncertainties were modeled, and which were only tested after design?
3. What is occupied novelty space?
4. What addition is both mathematically explicit and tied to this project's measured failure?

I found little direct peer-reviewed work using H∞ specifically for **slow/quasi-static hybrid simulation**. That is a search finding, not proof that no such paper exists. In slow hybrid simulation, real-time delay is less dominant; equilibrium iteration, force control, friction, drift, and multi-axis coupling become relatively more important. The direct H∞ evidence base is concentrated in RTHS and continuous pseudodynamic testing.

## Local evidence that the design must respect

The local 7k and 5k models are not separated by a small scalar gain change:

| Quantity | 7k | 5k | Change |
|---|---:|---:|---:|
| Identified mass | 44.136 kg | 54.882 kg | +24.35% |
| Identified damping | 34.31 N·s/m | 995.88 N·s/m | ×29.02 |
| Identified stiffness | 7.2006 MN/m | 5.3808 MN/m | −25.27% |
| Natural frequency | 64.29 Hz | 49.83 Hz | −22.48% |
| Damping ratio | 0.000962 | 0.02898 | ×30.11 |

Over the common measured 2–79.75 Hz band, the endpoint command-to-measured-displacement responses differ by 9.27 dB RMS magnitude and 11.66° RMS phase; the saved inner-loop responses differ by 9.83 dB and 19.21°. The pressure/specimen change is therefore frequency dependent.

The two identified state-space endpoints share a normalized companion realization and admit the diagnostic family

\[
A(\theta)=A_7+\theta(A_5-A_7),\qquad
B(\theta)=B,\qquad
C(\theta)=C_7+\theta(C_5-C_7),
\]

with \(\theta=0\) at 7k and \(\theta=1\) at 5k. This is presently an endpoint **secant**, not proof of a one-dimensional physical manifold. Any paper must identify at least one intermediate pressure and reserve another condition as a blind holdout.

## Direct H∞ and robust-control precedents in RTHS

| Work | What was designed | Uncertainty / imperfection treated | Validation | Novelty consequence here |
|---|---|---|---|---|
| [Gawthrop et al. (2007)](https://doi.org/10.1002/stc.174) | Robust real-time substructuring compensators for under-damped systems | Delay and deliberately increased uncertainty | Laboratory substructuring | Robust stability under delay/uncertainty is an established RTHS objective. |
| [Gao, Castaneda & Dyke (2013)](https://doi.org/10.1002/eqe.2246) | H∞ loop-shaped actuator motion controller | Unmodeled dynamics and actuator/specimen uncertainty | Physical RTHS with a steel-frame substructure | “H∞ loop shaping for RTHS” is not novel. |
| [Phillips & Spencer (2013)](https://doi.org/10.1061/(ASCE)ST.1943-541X.0000606) | Model-based feedforward–feedback actuator control | Computation, communication, actuator delay and lag | RTHS actuator studies | Any new design must compare against strong model-based compensation, not PID alone. |
| [Qian et al. (2014)](https://doi.org/10.1016/j.ymssp.2014.03.001) | Parametric servo-hydraulic actuator identification followed by H∞ design | Specimen mass/stiffness combinations and inner-loop gain | Identified RTHS actuator configurations | “Use a parametric actuator/specimen model for H∞” alone is already occupied. |
| [Ou et al. (2015)](https://doi.org/10.1002/eqe.2479) | Robust integrated actuator control: H∞ loop-shaping feedback, LQE, and feedforward | Noise, residual delay, lag, and plant variation | Slow 2500-kN and small fast actuator; physical RTHS | H∞ + estimator + feedforward is established. |
| [Ning et al. (2017)](https://jvs.sjtu.edu.cn/EN/Y2017/V36/I15/57) | Inner-loop mixed-sensitivity H∞ control | Nonlinear actuator/specimen dynamics and time delay | Numerical and physical SDOF RTHS | Inner-loop mixed sensitivity is established. |
| [Ning et al. (2019)](https://doi.org/10.1016/j.ymssp.2019.05.038) | Mixed-sensitivity H∞ plus polynomial extrapolation and adaptive/Kalman displacement reconstruction | Parameter error, high-frequency dynamics, delay, disturbance and noise | Virtual RTHS benchmark | Predictor/filter additions are not enough for novelty. |
| [Ning (2021)](https://doi.org/10.3390/sym13050840) | RTHS-specific mixed-sensitivity H∞ and weight study | Nonlinearity, delay, uncertainty, noise | Numerical and physical sinusoid/earthquake tests | Weight selection and mixed-sensitivity formulation are occupied. |
| [Botelho et al. (2022)](https://doi.org/10.1002/stc.3017) | MIMO robust stability and performance analysis | Actuator dynamics represented as multiplicative uncertainty | Multi-actuator experimental data | Multiplicative-uncertainty certification is established. |
| [Condori Uribe et al. (2023)](https://doi.org/10.3389/fbuil.2023.1270996) | Multi-axial RTHS benchmark and reference controllers | Coupling, actuator limitations, delay and implementation effects | Physical multi-actuator frame/coupler system | Evaluation must cover coupling and the deployed loop, not an isolated SISO plant. |
| [Xie et al. (2025)](https://doi.org/10.1002/eer2.70003) | H∞ loop shaping plus polynomial extrapolation | Multi-axial delay and actuator interaction | Multi-axial RTHS | The same robust-predictive combination now extends to multi-axis tests. |
| [Chen et al. (2026)](https://doi.org/10.1155/stc/8053214) | PSO-optimized robust H∞ using frequency-domain amplitude/delay indices | Parameter perturbations, nonlinear specimen, single and dual actuators; command-demand penalty | Numerical and laboratory RTHS | “Smart/AI optimization of H∞ weights” and a simple command penalty are occupied claims. |

The result is important: a new paper cannot rely on the controller acronym. It needs a new problem formulation, a physically meaningful uncertainty description, and stronger experimental evidence.

## What uncertainty should mean in this project

Nominal H∞ synthesis is not automatically robust to every physical change. The uncertainty must be inside the generalized plant or certified afterward.

### 1. Correlated specimen/pressure coordinate

Preserve the fact that pressure drives correlated changes in \(A\), \(C\), and the identified \((m,c,k)\) parameters. In an LFT description, repeated occurrences of one real scalar must remain the same block:

\[
\Delta_{\mathrm{phys}}=\delta_\theta I_r,\qquad |\delta_\theta|\le 1.
\]

Replacing this one repeated real parameter by unrelated complex blocks discards known physics and can be unnecessarily conservative.

### 2. Gain amplification

If the remaining amplitude error is approximately static and measured, use

\[
g=g_0(1+\rho_g\delta_g),\qquad |\delta_g|\le1,
\]

as a repeated real-gain block. If gain and phase vary together, use a disk/gain-phase uncertainty. A static gain block is inadequate for the local data by itself because the measured mismatch is frequency dependent.

### 3. Residual dynamic uncertainty

After removing the physics-parametric family, fit a stable envelope to the remaining FRF error:

\[
G_a(s,\theta)=G_{a0}(s,\theta)\left[1+W_m(s)\Delta_m(s)\right],
\qquad \|\Delta_m\|_\infty\le1.
\]

For output multiplicative uncertainty, \(\|W_mT\|_\infty<1\) is the small-gain robust-stability condition. Near nominal plant zeros, use an additive envelope rather than dividing by a nearly zero response. Fitting \(W_m\) before subtracting the known 7k–5k trend double-counts the specimen effect.

### 4. Delay and jitter

For \(\tau=\tau_0+\delta_\tau\), the relative delay error magnitude is

\[
\left|e^{-j\omega\delta_\tau}-1\right|
=2\left|\sin\left(\frac{\omega\delta_\tau}{2}\right)\right|.
\]

A stable rational \(W_\tau\) should majorize the worst allowed delay error. A low-order Padé approximation alone is not a robustness certificate. Time-varying delay also needs a stated rate/jitter model; RTHS stability with time-varying delay is a separate literature stream.

### 5. Saturation, rate limits, and noise

Saturation is nonlinear and cannot be certified by an ordinary linear H∞ norm. Include command and rate channels during synthesis, then test the saturated nonlinear loop and anti-windup explicitly. Measurement noise belongs in a separate exogenous input channel so aggressive tracking cannot hide noise amplification.

A useful structured block is therefore

\[
\Delta=\operatorname{diag}
\left(\delta_\theta I_r,\ \delta_g I_q,\ \Delta_m(s),\ \Delta_\tau(s)\right),
\]

with the real and dynamic blocks kept distinct. Mixed-\(\mu\) analysis should report upper and lower bounds and a worst-case perturbation, not only a nominal H∞ value.

## Established synthesis choices

### Mixed sensitivity

For a one-degree-of-freedom loop,

\[
S=(I+GK)^{-1},\qquad T=GK(I+GK)^{-1},
\]

and the classical objective is

\[
\min_K\left\|
\begin{bmatrix}
W_eS\\W_uKS\\W_TT
\end{bmatrix}
\right\|_\infty.
\]

\(W_e\) shapes low-frequency tracking/disturbance rejection, \(W_u\) shapes command and roll-off, and \(W_T\) covers high-frequency uncertainty/noise. This is necessary background, not the proposed novelty.

The current tracker may contain a precompensator or two-degree-of-freedom feedforward path. If

\[
u=K_r r-K_y y,
\]

then

\[
\frac{u}{r}=(I+K_yG)^{-1}K_r,
\qquad
\frac{y}{r}=G(I+K_yG)^{-1}K_r.
\]

The feedforward block must be included in the generalized plant. A reference response that already contains a precompensator is not a loop-break complementary sensitivity and should not be used to reconstruct the design loop by \(T/(1-T)\).

### Polytopic fixed controller

For an affine plant family and full-state feedback, common-quadratic vertex LMIs can certify the whole convex hull. That certificate can be conservative, and the familiar state-feedback LMI must not be presented as an arbitrary output-feedback solution. If the realization is not affine or a common storage function is not used, endpoint tests alone are not a continuous-family certificate.

### LPV / gain scheduling

If a reliable pressure or stiffness estimate becomes available, an LPV controller can exploit it:

\[
K(\theta)=\sum_i\alpha_i(\theta)K_i,
\qquad \alpha_i\ge0,\quad \sum_i\alpha_i=1.
\]

This requires estimator error and parameter-rate bounds. Naively interpolating independently designed controllers does not guarantee stability. Because supply pressure is not currently logged as a dependable scheduling signal, a fixed shared controller is the safer first paper. LPV H∞ should be a later benchmark or extension.

### Structured H∞ and μ synthesis

For mixed real specimen/gain blocks and residual dynamics, D–K iteration is a practical baseline. It is heuristic and nonconvex, can increase controller order, and does not promise a global optimum. A low-order structured controller can instead be tuned against active worst-case scenarios, followed by independent \(\mu\) certification. Those algorithms are established; the project contribution must lie in the RTHS formulation and evidence.

## Novelty claim audit

| Candidate claim | Status | Why |
|---|---|---|
| First H∞ controller for RTHS | **Blocked** | Gao 2013 and later work. |
| First mixed-sensitivity H∞ RTHS | **Blocked** | Ning 2017/2021. |
| First H∞ + predictor/filter | **Blocked** | Ou 2015, Ning 2019, Xie 2025. |
| First parametric actuator/specimen H∞ | **Blocked** | Qian 2014. |
| First multiplicative-uncertainty RTHS robustness study | **Blocked** | Botelho 2022. |
| First intelligently optimized H∞ weights | **Blocked** | Chen 2026 uses PSO and frequency-domain evaluation. |
| First multi-model/LPV/structured H∞ method | **Blocked as theory** | Mature robust-control literature. |
| Physics-structured continuous-family RTHS synthesis | **Conditional** | Must go beyond endpoint gridding and Qian 2014, and validate the physical parameterization. |
| Explicit closed-loop parameter-sensitivity channel | **Primary hypothesis** | One added output directly targets the measured 7k–5k drift. Sensitivity shaping is known broadly; novelty would be its stiff-specimen RTHS formulation and physical validation. |
| PID-relative performance weight | **Useful alternative, not part of the primary idea** | A standard weight can be fitted to the PID error envelope. Keep it as a comparison experiment rather than adding another flagship mechanism. |
| H∞ plus a hard 2.5 step-command constraint | **Required engineering constraint, not novelty by itself** | H∞ bounds induced energy gain, not pointwise step peaks; Chen 2026 already uses a command penalty and time-domain-constrained H∞ is established. |

## Proposed formulation: one new term

### A. Shared full-loop model

Let \(P(\theta,\Delta)\) include the numerical substructure, actuator/specimen model, sensors, sample/hold, filters, delay, precompensator/feedforward path, and the shared controller. Use the measured 7k and 5k models for synthesis and at least one intermediate condition for identification plus another for blind validation.

Define the deployed reference-to-displacement map \(T_K(s,\theta)\), tracking error

\[
E_K(s,\theta)=1-T_K(s,\theta),
\]

and reference-to-command map \(U_K(s,\theta)\). These definitions remain correct for a two-degree-of-freedom loop and do not rely on false open-loop reconstruction.

### B. Standard baseline channels

For the first study, keep only the channels needed to make the comparison fair:

\[
z_{\mathrm{base}}=
\begin{bmatrix}
W_eE_K\\
W_uU_K
\end{bmatrix}r.
\]

These are standard H∞ channels and are not presented as novelty. Rate or noise weights should be added only if a measured failure requires them, not because a larger generalized plant looks more sophisticated.

### C. The proposed parameter-sensitivity channel

Let

\[
G_\theta(s)=\frac{\partial G(s,\theta)}{\partial\theta}.
\]

For

\[
G=C(sI-A)^{-1}B+D,
\]

the derivative is available analytically from the identified parametric model:

\[
G_\theta=
C_\theta R_sB
+CR_sA_\theta R_sB
+CR_sB_\theta
+D_\theta,
\qquad R_s=(sI-A)^{-1}.
\]

For the two-degree-of-freedom law \(u=K_rr-K_yy\), define

\[
S_o=(I+GK_y)^{-1},\qquad
S_i=(I+K_yG)^{-1},qquad
T_K=S_oGK_r.
\]

The exact closed-loop parameter derivative is

\[
\boxed{
\frac{\partial T_K}{\partial\theta}
=S_oG_\theta S_iK_r
}
\]

and the only proposed new performance output is

\[
z_\theta=
W_\theta(s)
\frac{\partial T_K(s,\theta)}{\partial\theta}r.
\]

This term is physically interpretable: it measures the movement of the closed-loop displacement response per unit movement along the identified 7k–5k specimen coordinate. It is also mathematically tied to endpoint uniformity because

\[
T_K(s,1)-T_K(s,0)
=\int_0^1\frac{\partial T_K(s,\theta)}{\partial\theta}\,d\theta,
\]

so suppressing the derivative across the interval bounds how far the two endpoint responses can separate. The ordinary tracking term prevents the trivial solution in which both responses are equally poor.

### D. Minimal objective

One fixed, low-order controller is synthesized from

\[
\min_{K\in\mathcal K_q}
\sup_{\theta\in[0,1]}
\left\|
\begin{bmatrix}
W_eE_K\\
W_uU_K\\
\lambda W_\theta\dfrac{\partial T_K}{\partial\theta}
\end{bmatrix}
\middle/r
\right\|_\infty.
\]

There is one design question: does \(\lambda>0\) improve worst-condition tracking and response consistency without consuming unacceptable command? Compare \(\lambda=0\) against a small sweep of \(\lambda\); do not add more mechanisms until that question is answered.

The PID is used to set the success threshold, not as another proposed controller component. Calculate \(T_{PID}\) with the same plant, precompensator, delay, filters, and limits, and require the final H∞ design to improve the declared time- and frequency-domain metrics at 7k, 5k, and a blind intermediate condition.

### E. The 2.5 command requirement

H∞ does **not** hard-limit a step command. Keep command shaping in the generalized plant, but impose the time-domain constraint separately:

\[
g_u(K)=
\max_{\theta\in[0,1],\,t\in[0,T]}
|u_{step}(t;\theta,K)|-2.5\le0.
\]

If the numerical feasibility tolerance is accepted as \(10^{-2}\), report it explicitly as

\[
g_u(K)\le10^{-2},
\]

while retaining 2.5 as the engineering target. Do not rename a 2.51 command as a 2.5 result. Plot both raw and saturated command, include rate limits and anti-windup, and validate with the actual nonlinear saturation.

## Two alternative one-term ideas—not to be combined initially

If the sensitivity channel fails, test one alternative at a time:

1. **PID-envelope weight.** Set the ordinary tracking weight from a stable rational fit to the worst PID error envelope. This asks H∞ to beat a clear benchmark, but it is less directly tied to the specimen physics.
2. **Physics-scaled bandwidth weight.** Move the tracking-weight break frequency with \(\omega_n(\theta)=\sqrt{k_{eff}(\theta)/m_{eff}(\theta)}\). This requests constant dimensionless performance around the moving physical mode, but it needs a reliable parameter measurement if used online.

Neither alternative should be stacked with the primary sensitivity term until its independent effect is understood.

## Recommended paper package

### Baselines

1. Current project PID, unchanged.
2. Nominal 7k mixed-sensitivity H∞.
3. The same fixed H∞ objective with \(\lambda=0\).
4. The proposed objective with \(\lambda>0\).

### Tests

- Identified 7k and 5k endpoints.
- At least two intermediate pressures: one model-building condition and one blind holdout.
- Slow drift and a sudden 7k→5k change.
- Gain amplification, phase error, residual dynamics, delay bias, time-varying jitter, sensor noise, and coupling.
- Step, sine sweep/multisine, and unseen earthquake records.
- Linear and saturated simulations before physical tests.
- Complete Speedgoat/RTHS implementation, not plant-only simulation.

### Metrics

- Worst-condition tracking error and frequency-domain PID-dominance ratio.
- Cross-condition response spread.
- Raw command peak, saturated command peak, rate, and time near saturation.
- Robust H∞ gain and mixed-\(\mu\) upper/lower bounds.
- Disk gain/phase margins and worst-case perturbation.
- Existing project RTHS fidelity metrics, timing/jitter, and controller order/runtime.
- Results per condition plus the worst condition; never report only the mean.

### Falsification gates

Stop or reposition the paper if any of these occurs:

1. Intermediate FRFs reject the proposed physical parameter family.
2. The proposed controller does not beat a fairly tuned PID on both endpoints and the blind holdout.
3. Improvement disappears when the same 2.5 command and rate limits are applied.
4. Robustness exists only in a reduced plant and fails in the deployed RTHS loop.
5. The parameter-sensitivity channel provides no measurable advantage over the identical objective with \(\lambda=0\).

## Bottom line

H∞ is not a magic replacement for LQG, and a generic H∞ controller is unlikely to be publishable here. The cleanest research hypothesis is one extra output: penalize the derivative of the complete closed-loop response with respect to the measured specimen coordinate. It is simple, calculable from the existing parametric model, and directly targets the 7k–5k failure. The PID comparison, command constraint, and uncertainty tests are validation requirements—not extra novelty mechanisms.

## Foundational robust-control sources

- [Doyle, Glover, Khargonekar & Francis (1989), state-space H∞ solutions](https://doi.org/10.1109/9.29425)
- [Glover & McFarlane (1989), normalized-coprime-factor loop shaping](https://doi.org/10.1109/9.29424)
- [Packard & Doyle (1993), structured singular value](https://doi.org/10.1016/0005-1098(93)90175-S)
- [Apkarian & Gahinet (1995), gain-scheduled H∞](https://doi.org/10.1109/9.384219)
- [Gahinet, Apkarian & Chilali (1996), parameter-dependent Lyapunov functions](https://doi.org/10.1109/9.486646)
- [Scherer, Gahinet & Chilali (1997), multiobjective output-feedback LMIs](https://doi.org/10.1109/9.599969)
- [Apkarian, Dao & Noll (2015), parametric robust structured control](https://doi.org/10.1109/TAC.2015.2396644)
- [Apkarian & Noll (2018), structured H∞ control](https://doi.org/10.1002/rnc.4073)
