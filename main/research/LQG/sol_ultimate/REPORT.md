# Baseline audit and a publishable robust-LQG direction

Date: 2026-08-04

## Decision

The strongest defensible direction supported by the present repository is a **fixed pressure-coordinate robust LQGI** controller. This is an RTHS application hypothesis, not a new species of LQG.

The idea is deliberately narrow:

> Identify and independently validate one physical coordinate for pressure loss; design one fixed observer-integrator-controller against that family; and certify the complete deployed RTHS loop with a common-Lyapunov guaranteed-cost test.

This is preferable to an adaptive LQG for the present data. Only two operating-point models are currently available, the existing broadband record is not a clean identification record, and closed-loop online identification would be vulnerable to bias and loss of excitation. A fixed controller has no convergence transient, parameter drift, or online matrix optimization. Adaptive LQG plus an online least-squares predictor has also already been demonstrated in physical RTHS, so adaptation is not an unoccupied novelty claim.

The recommendation is evidence-based but conditional. The local results establish the baseline failure, the need for integral regulation, and the strength of the classical comparator. They do **not** establish that the pressure family is one-dimensional or that the proposed fixed controller outperforms existing integral LQG in a complete RTHS. Those are the central identification and experimental tests the paper must pass.

**Current status:** the pressure-coordinate robust LQGI is a mathematically specified research hypothesis, not yet a demonstrated improved controller. No new robust gains have been synthesized in this study, no common-\(P\) feasibility problem has been solved for the complete loop, and no physical RTHS has been run. With only 5k and 7k models, their half-difference is a **secant**, not a tangent, and any two points define a line. “Publishable” below means an RTHS/control-application contribution could become publishable if the stated identification, synthesis, and falsification gates succeed. The present evidence does not support a new general control-theory claim.

## What the current baseline actually is

The saved controller is continuous-time full-state LQR, not LQG. Its law is

\[
u=-Kx+\bar N r,
\qquad
Q=q_y C_7^\mathsf{T}C_7,
\qquad R=r_u,
\]

with no observer, Kalman gain, innovation, or noise covariance. The saved design is

\[
q_y=45.9076418,\quad r_u=1,\quad \bar N=7.17304072,
\]

\[
K=[0.5733403,\ 1.0917937,\ 1.4900728,\ 1.1462676,\ 0.3752297,\ 0.0306940].
\]

The tuning objective is effectively nominal 7k step overshoot. It does not penalize the 5k response, broadband error, command effort, measurement noise, delay, or the RTHS force/FEM loop. See [design_lqr_baseline.m](main/research/LQG/design_lqr_baseline.m) and [build_lqr_state_space_models.m](main/research/LQG/build_lqr_state_space_models.m).

## Results that constrain the research idea

### 1. The demonstrated failure is regulation, not state-feedback stability

| Controller/model | Final value | Error from unit target | Overshoot | Settling time | Peak command per unit reference |
|---|---:|---:|---:|---:|---:|
| Saved PID, 7k | 0.9954 | -0.46% | approximately 0% | approximately 0.470 s | not exported consistently |
| Full-state LQR, 7k | 1.0000 | 0% | 8.49% | 0.0240 s | 7.173 |
| Saved PID, 5k | 0.9844 | -1.56% | approximately 0% | approximately 0.238 s | not exported consistently |
| Same full-state LQR on 5k | **6.7666** | **+576.66%** | 23.44% about the wrong final value | 0.0505 s about the wrong final value | 7.173 |

The 5k overshoot and settling values in the original result are computed around 6.7666, not around the desired value 1. They therefore conceal the actual failure.

The required static precompensators are

\[
\bar N_{7k}=7.17304,\qquad \bar N_{5k}=1.06007.
\]

The same feedback gain stabilizes both full-state endpoint models and every sampled affine interpolant. The worst continuous-time spectral abscissa in that sweep was \(-60.43\ \mathrm{s}^{-1}\). Thus a new robust state-feedback gain alone would solve a problem the current data do not show. The first necessary change is the internal model for robust output regulation.

### 2. Turning the saved LQR into an ordinary LQG does not repair it

The audit in [analyze_lqg_baseline.m](main/research/LQG/sol_ultimate/analyze_lqg_baseline.m) adds a nominal 7k Kalman observer and sweeps

\[
q_w/r_v=10^{-8},\ldots,10^{12}
\]

at 161 logarithmically spaced values.

| Result | 7k | Mismatched 5k plant |
|---|---:|---:|
| Stable observer-based loops | 161/161 | 86/161 |
| Stable final-value range | 1.0000 | **2.4117 to 3.6845** |
| Stable spectral-abscissa range | -60.43 to -60.17 s\(^{-1}\) | -59.43 to -1.12 s\(^{-1}\) |
| Measurement-noise-to-command \(H_2\) range | \(1.65\times10^{-8}\) to \(5.06\times10^5\) | \(1.65\times10^{-8}\) to 151.6 before instability |

The last stable 5k point is near \(q_w/r_v=421.7\); at 562.3 a pole moves to \(+3.26\ \mathrm{s}^{-1}\). The apparently best 5k final value occurs at \(10^{-8}\), where \(\lVert L\rVert_2=1.49\times10^{-5}\): the estimator has nearly stopped using the measurement. Covariance tuning therefore trades measurement use against mismatch and noise, but never restores unit regulation.

This eliminates “tune the Kalman covariances harder” as a research contribution.

### 3. Classical integral LQG is a strong step-response comparator

[analyze_lqgi_comparator.m](main/research/LQG/sol_ultimate/analyze_lqgi_comparator.m) implements a discrete 2048 Hz nominal observer and one error-integrator state. The integral penalty was swept over 129 values. The selected design is the fastest worst-endpoint 2% settling result satisfying at both endpoints:

- overshoot no greater than 10%;
- stability; and
- peak command no greater than the saved LQR command jump.

| Metric | 7k | 5k |
|---|---:|---:|
| Final value | **1.0000** | **1.0000** |
| Overshoot | 0% | 4.65% |
| 2% settling | 0.1299 s | 0.0596 s |
| Peak command per unit reference | 2.3548 | 1.0216 |
| Measurement-noise-to-command \(H_2\) | 0.2450 | 0.2031 |
| Deterministic closed-loop radius | 0.9841 | 0.9758 |

The integral weight is 56,234 and the integral gain is -219.38 under the script's sign convention. This controller completely removes the endpoint DC error and reduces the nominal command peak by 67% relative to the saved LQR.

It is not the proposed novelty. It is the minimum credible baseline that the proposed method must beat.

It is not a globally optimized robust-LQGI design: the script fixes the estimator ratio and state weight, then sweeps only the integral weight. The eventual paper must tune LQGI under the same performance/noise constraints used for the proposed pressure-coordinate controller so the comparison is fair.

Its 2-80 Hz RMS \(\lvert1-T\rvert\) is 1.057 at 7k and 1.184 at 5k. The corresponding saved-PID values are about 1.038 and 1.145. Therefore a successful step response is not evidence of broadband superiority; the proposed controller must improve the complete RTHS result, not merely duplicate LQGI regulation.

### 3a. Integral-state LQG already exists in physical RTHS

An acronym-only search is misleading because the direct precedents call their controllers “LQG” or “ALQG,” not LQGI.

| Publication | Controller evidence | Validation | Consequence |
|---|---|---|---|
| [Zhang et al., 2022](https://doi.org/10.6052/j.issn.1000-4750.2021.01.0023) | \(\dot\xi=x_{com}-x_m\), \(y_{Gc}=-K\hat X+k_I\xi\), full-order Kalman observer; a least-squares ATS predictor updates online | Physical 1024 Hz train-bridge RTHS for three bridge stiffness cases | Blocks a broad “first adaptive integral LQG in RTHS” claim. More precisely, its LQGI gains are fixed while the feedforward predictor adapts. |
| [Condori Uribe et al., 2023](https://doi.org/10.3389/fbuil.2023.1270996) | Eqs. 32–36 add \(\dot z_{err}=\eta_{ns}-\eta_m\), apply LQR to the augmented plant, and estimate unavailable plant states with a Kalman filter | Physical two-actuator maRTHS on a steel-frame/coupler system | This is an exact nominal LQGI architecture even though the paper labels it LQG. |
| [Aguila et al., 2024](https://doi.org/10.3389/fbuil.2024.1384235) and [Calayir et al., 2025](https://doi.org/10.3390/act14110525) | Reuse the Condori integral-state LQG as a reference controller while evaluating adaptive compensation | Virtual maRTHS studies | Confirm that this architecture is now a benchmark baseline, not an open novelty claim. |

The proposed work therefore cannot claim the first LQGI/LQRI, the first integral-state LQG, or the first adaptive LQG in RTHS. These papers make the classical LQGI comparator in this folder more important, not less.

### 4. The measured uncertainty is large but highly structured

| Identified quantity | 7k | 5k | Change |
|---|---:|---:|---:|
| Mass | 44.136 kg | 54.882 kg | +24.35% |
| Damping | 34.31 N s/m | 995.88 N s/m | x29.02 |
| Stiffness | \(7.2006\times10^6\) N/m | \(5.3808\times10^6\) N/m | -25.27% |
| Natural frequency | 64.29 Hz | 49.83 Hz | -22.48% |
| Damping ratio | 0.000962 | 0.02898 | x30.11 |

Over the common measured 2-79.75 Hz grid, the two endpoint \(H_{dc,dm}\) responses differ by 9.27 dB RMS and 11.66 degrees RMS. The saved inner-loop \(H_{dd,dm}\) responses differ by 9.83 dB RMS and 19.21 degrees RMS. These values are regenerated by [analyze_source_evidence.m](main/research/LQG/sol_ultimate/analyze_source_evidence.m). This is not a small scalar-gain perturbation.

Both endpoint models are expressed in the same normalized companion coordinates. In continuous time, their dynamics difference is one companion-row direction and their output difference is one row direction. They are driven by the **same physical operating change**, so treating these differences as independent uncertainty blocks discards a plausible correlation. However, matrix differences are coordinate-dependent, and two endpoints cannot validate a one-dimensional family. A joint grey-box realization or an input-output validation across additional pressures is mandatory.

After exact zero-order-hold discretization, the endpoint **secant** has small numerical tails rather than exact rank two. The computed closed-loop diagnostics show:

| Loop | Approximation | Captured secant energy | Relative secant error | Error in mean-square margin |
|---|---:|---:|---:|---:|
| Ordinary observer loop | rank 1 | 98.085% | 13.84% | 0.232% |
| Ordinary observer loop | rank 2 | 99.999% | 0.265% | 0.220% |
| Ordinary observer loop | rank 3 | approximately 100% | \(1.16\times10^{-6}\) | \(1.13\times10^{-6}\) |
| Integral observer loop | rank 1 | 99.893% | 3.276% | 17.8% |
| Integral observer loop | rank 2 | 99.989% | 1.069% | 7.07% |
| Integral observer loop | rank 3 | approximately 100% | \(2.93\times10^{-7}\) | \(6.47\times10^{-7}\) |

The integral result is an important warning: singular-value energy alone is not a safe robustness criterion. Rank three, not rank two, is needed for a margin-accurate discrete integral model. The method should choose reduced order by convergence of the certified margin.

The numerically evaluated ordinary-LQG secant margin is 2.7331 endpoint-half-ranges; the selected LQGI margin is 2.2450. These are RMS stochastic secant scalings, not deterministic endpoint-coverage guarantees. They show that the current endpoint models are already comfortably stable under the tested interpretations. The proposed paper must therefore demonstrate better **robust performance**, noise/effort trade-off, and full-RTHS fidelity—not claim that the baseline endpoints cannot be stabilized.

## Why the obvious alternatives were rejected

| Candidate | Local evidence | Novelty boundary | Decision |
|---|---|---|---|
| Retune \(Q/R\) or use LQG/LTR | Does not create an internal model; ordinary LQG sweep never fixes 5k regulation | Robust LQG/LTR is already established in RTHS | Reject as main idea |
| Integral LQG | Solves the demonstrated DC failure cleanly | Already used in physical RTHS in 2022 and 2023 | Keep as hard comparator |
| Scalar adaptive prefilter | Could correct DC gain but not the measured frequency-dependent magnitude/phase shift | Adaptive feedforward, ATS, RLS and fixed-feedback adaptive prefilters are established | Reject as flagship; optional benchmark |
| Two-model switching or pressure scheduling | Practical if pressure is measured | Multiple-model and gain-scheduled LQG are established; switching requires bumplessness/hysteresis proofs | Possible engineering fallback |
| EKF/UKF plant adaptation | Can estimate time-varying coefficients | Already active in RTHS; adds excitation, bias, and convergence problems | Reject for this two-endpoint data set |
| \(H_\infty\) plus predictor plus filter | Mature robust route | Already published in RTHS and violates the requested conceptual simplicity | Comparator only |
| Generic multiplicative-noise LQG | Correctly couples estimation and control | Multiplicative-noise output-feedback control and coupled Riccati/policy iteration are old | Do not claim generic novelty |
| **Fixed pressure-coordinate robust LQGI** | Matches the regulation failure and the hypothesis that pressure drives correlated plant changes | Potential novelty is experimental validation of that physical coordinate and a complete deployed-loop certificate—not LQGI, multiplicative noise, or low-rank analysis | **Develop conditionally** |

Relevant prior art includes robust LQG/LTR for RTHS ([Zhou et al., 2019](https://doi.org/10.1016/j.ymssp.2019.106260)), adaptive integral-state LQG plus prediction ([Zhang et al., 2022](https://doi.org/10.6052/j.issn.1000-4750.2021.01.0023)), nominal integral-state LQG in maRTHS ([Condori Uribe et al., 2023](https://doi.org/10.3389/fbuil.2023.1270996)), robust integrated \(H_\infty\)/LQE/feedforward control ([Ou et al., 2015](https://doi.org/10.1002/eqe.2479)), adaptive model-reference RTHS control ([Najafi and Spencer, 2019](https://doi.org/10.1016/j.ymssp.2019.06.023)), Kalman-based online delay adaptation ([Ning et al., 2020](https://doi.org/10.3390/app10207101)), and recent EKF/UKF plant compensation ([Frontiers, 2024](https://doi.org/10.3389/fbuil.2024.1477804)).

The control-theory boundary is equally important. One shared stochastic scalar multiplying structured directions in \(A\), \(B\), and \(C\) already appears in [Bernstein, 1987](https://doi.org/10.1109/TAC.1987.1104517). Fixed-order output feedback with multiplicative noise was developed by [Bernstein and Haddad, 1987](https://doi.org/10.1080/00207178708933884), and modern policy iteration solves the coupled output-feedback problem ([Gravell et al., 2022](https://doi.org/10.1109/CDC51059.2022.9993098)). Mean-square spectral-radius tests, low-dimensional uncertainty-channel reductions, and common-\(P\) polytopic certificates are also established theory. A defensible paper must not present any of those ingredients as new.

## Proposed method: fixed pressure-coordinate robust LQGI

### 1. One uncertainty coordinate

After identifying at least three pressure conditions in one common state basis, fit an affine pressure family. The current two-model diagnostic defines only the midpoint and endpoint secant

\[
A_0=\frac{A_7+A_5}{2},\qquad A_1=\frac{A_7-A_5}{2},
\]

with the same definitions for \(B_0,B_1,C_0,C_1\). Use

\[
\begin{aligned}
x_{k+1} &= A_0x_k+B_0u_k
+\gamma\xi_k(A_1x_k+B_1u_k)+w_k,\\
y_k &= C_0x_k+\gamma\xi_k C_1x_k+v_k.
\end{aligned}
\]

The essential modeling hypothesis is that the **same scalar** \(\xi_k\) multiplies every secant term. This preserves the fact that one operating change caused all matrix changes. Independent \(\Delta A\), \(\Delta B\), and \(\Delta C\) noises would invent combinations that were not observed. It becomes evidence only if additional pressure models lie near this family within identification uncertainty.

Two interpretations are used, with different proof obligations:

- \(\xi=\rho\in[-1,1]\) is a frozen or slowly varying operating coordinate. Deterministic endpoint/common-Lyapunov certification covers this case.
- \(\xi_k\) is zero-mean, unit-variance, independent multiplicative noise. This is an optional offline design surrogate that penalizes repeated excursions along the measured secant; it is not a claim that hydraulic pressure is white noise and it is not the deterministic robustness certificate.

The scale \(\gamma=1\) corresponds to the current endpoint half-range. Larger \(\gamma\) is a transparent robustness reserve.

### 2. One integral state and one fixed observer-controller

Use

\[
\begin{aligned}
\hat x_{k+1} &= A_0\hat x_k+B_0u_k
+L(y_k-C_0\hat x_k),\\
\eta_{k+1} &= \eta_k+T_s(r_k-y_k),\\
u_k &= -K\hat x_k-k_I\eta_k.
\end{aligned}
\]

The integrator is not a novelty claim; it is required by the internal-model principle and by the measured +576.7% failure of the nominal precompensator. If the closed loop is internally stable and unsaturated, a constant equilibrium satisfies \(r-y=0\), so constant reference and input-disturbance errors are rejected.

The controller remains fixed online. Its real-time work is one observer update, one scalar integral update, and one dot product.

### 3. Couple estimator and regulator during design

For \(z=[x^\mathsf{T},\hat x^\mathsf{T},\eta]^\mathsf{T}\), the homogeneous closed loop is

\[
z_{k+1}=(M_0+\gamma\xi_kM_1)z_k,
\]

where

\[
M_0=
\begin{bmatrix}
A_0&-B_0K&-B_0k_I\\
LC_0&A_0-B_0K-LC_0&-B_0k_I\\
-T_sC_0&0&1
\end{bmatrix},
\]

\[
M_1=
\begin{bmatrix}
A_1&-B_1K&-B_1k_I\\
LC_1&0&0\\
-T_sC_1&0&0
\end{bmatrix}.
\]

Because \(L\) appears in \(M_1\), estimator aggressiveness changes robustness. Classical LQG separation is therefore not the right design argument under this uncertainty.

Select \(K,k_I,L\) together by minimizing the steady quadratic cost

\[
J=\lim_{N\rightarrow\infty}\frac1N
\mathbf E\sum_{k=0}^{N-1}
\left(z_k^\mathsf{T}Q_z z_k+u_k^\mathsf{T}R u_k\right),
\]

under the single-coordinate stochastic surrogate, subject to the deterministic certificate below. Experimental residuals, not arbitrary tuning, should set the additive process/measurement covariance. Initialize the fixed-order search with the stable LQGI comparator. This is a nonconvex fixed-order output-feedback optimization; unless a stronger result is proved, only local stationary-point and retained-feasibility claims are defensible.

For a fixed policy, evaluate the cost with the generalized Lyapunov pair

\[
P=Q_c+M_0^\mathsf{T}PM_0+\gamma^2M_1^\mathsf{T}PM_1,
\]

\[
\Sigma=M_0\Sigma M_0^\mathsf{T}
+\gamma^2M_1\Sigma M_1^\mathsf{T}+W.
\]

After the process- and measurement-noise input matrices are defined, an exact policy differential is

\[
dJ=\operatorname{tr}(dQ_c\Sigma)
+2\operatorname{tr}(PM_0\Sigma\,dM_0^\mathsf{T})
+2\gamma^2\operatorname{tr}(PM_1\Sigma\,dM_1^\mathsf{T})
+\operatorname{tr}(P\,dW).
\]

The last term is required because measurement-noise injection depends on \(L\). A line-searched update that retains the certificates below gives a compact offline synthesis algorithm. No generic unstructured uncertainty blocks are introduced.

## Mathematical certificates

### Mean-square secant diagnostic

For independent zero-mean unit-variance \(\xi_k\), the fixed controller is mean-square stable if and only if

\[
\rho\!\left(M_0\otimes M_0+\gamma^2M_1\otimes M_1\right)<1,
\]

equivalently, if there is \(P\succ0\) satisfying

\[
M_0^\mathsf{T}PM_0+\gamma^2M_1^\mathsf{T}PM_1-P\prec0.
\]

This yields a scalar RMS stochastic secant radius \(\gamma_{ms}\), rather than a collection of unrelated gain/phase-margin numbers. It does not, by itself, guarantee worst-case performance for a frozen operating point. The spectral-radius test is established multiplicative-noise theory and is retained here as a diagnostic, not a novelty claim.

### Frozen-parameter guaranteed-cost certificate

For the method to deserve the word “robust,” use more than endpoint pole locations. In regulator coordinates, define a weighted performance output

\[
e_k=E_\rho z_k
=\begin{bmatrix}
\sqrt{q_e}(r_k-y_k)\\
\sqrt{q_\eta}\eta_k\\
\sqrt{r_u}u_k
\end{bmatrix}.
\]

Require one \(P_g\succ0\) at both endpoints:

\[
M_\pm^\mathsf{T}P_gM_\pm-P_g
+E_\pm^\mathsf{T}E_\pm\prec0.
\]

This is a common guaranteed-cost condition. For zero additive disturbance,

\[
\sum_{k=0}^{\infty}\lVert e_k\rVert^2
<z_0^\mathsf{T}P_gz_0.
\]

For a frozen endpoint driven by white additive noise of covariance \(W_\pm\), it also bounds the stationary stage cost by \(\operatorname{tr}(P_gW_\pm)\). Because both \(M_\rho\) and \(E_\rho\) are affine in the same scalar coordinate, the stacked quadratic form

\[
\begin{bmatrix}M_\rho\\E_\rho\end{bmatrix}^{\!\mathsf{T}}
\begin{bmatrix}P_g&0\\0&I\end{bmatrix}
\begin{bmatrix}M_\rho\\E_\rho\end{bmatrix}-P_g
\]

is matrix convex in \(\rho\). A common endpoint solution therefore certifies the entire affine interval. The proposed synthesis should minimize the common cost bound while retaining a mean-square secant reserve. This feasibility/optimization problem has **not** yet been solved in the current scripts.

### Low-rank radius identity

Let \(M_1=UV^\mathsf{T}\) have rank \(r\), and assume \(\rho(M_0)<1\). Define

\[
G=(V\otimes V)^\mathsf{T}
\left[I-M_0\otimes M_0\right]^{-1}
(U\otimes U).
\]

At the positive-map stability boundary, the matrix determinant lemma gives

\[
\boxed{\gamma_{ms}=\frac{1}{\sqrt{\rho(G)}}}.
\]

The identity is exact for an exact factorization \(M_1=UV^\mathsf{T}\). The full covariance operator has order \(n_z^2\); the reduced operator has order \(r^2\). At MATLAB's numerical-rank tolerance, the current secants have rank six. The resulting 36 by 36 calculation agrees with the direct 144 by 144 ordinary-loop radius to \(2.8\times10^{-11}\), and with the direct 169 by 169 integral-loop radius to \(6.4\times10^{-11}\). These are a posteriori numerical agreements, not analytical approximation bounds. A separately margin-validated rank-three approximation would use only a 9 by 9 operator.

This reduction is computationally useful but is **not** a defensible control-theory novelty. Structured mean-square stability radii and uncertainty-channel reductions are established, including [Bamieh and Filo, 2020](https://doi.org/10.1109/TAC.2020.2970393) and [Chen et al., 2024](https://doi.org/10.1109/TAC.2024.3362700). Keep the calculation as an implementation aid and reproducibility check, not as a headline theorem.

### Frozen endpoint and interval certificate

The multiplicative-noise result does not by itself certify a fixed 5k condition. Require a common \(P_d\succ0\) such that

\[
M_+^\mathsf{T}P_dM_+-P_d\prec0,
\qquad
M_-^\mathsf{T}P_dM_--P_d\prec0,
\]

where \(M_\pm=M_0\pm\gamma M_1\).

For every affine \(M(\rho)\) between the endpoints, matrix convexity gives

\[
M(\rho)^\mathsf{T}P_dM(\rho)
\preceq
\lambda M_+^\mathsf{T}P_dM_+
+(1-\lambda)M_-^\mathsf{T}P_dM_-,
\]

so the same \(P_d\) certifies the whole interval. The actual discrete delay, numerical-substructure coupling, and any fixed actuator filters must be inside \(M_\pm\) before this is presented as an RTHS stability theorem.

## How it fits the actual RTHS architecture

The live repository loop is not just the identified \(d_c\to d_m\) transfer function. Its effective signal path is

\[
f_m\rightarrow\texttt{step\_HS}\rightarrow d_n
\rightarrow G_T(z)\rightarrow d_d
\rightarrow(d_d-d_m)\rightarrow C
\rightarrow 2a_{OSI}\rightarrow\operatorname{sat}_{\pm70\,\mathrm{mm}}
\rightarrow d_c\rightarrow\text{actuator/specimen}\rightarrow(d_m,f_m).
\]

The numerical FEM is advanced from measured force in [step_HS.m](main/control_and_HS/d_HS/utils_HS/step_HS.m). The file-log order is `dd, dc, dm, fm, am, ...` in [main_ColumnSetup.m](main/main_ColumnSetup.m). Full/reference FEM responses are produced by offline replay in [compare_hs_response_to_reference.m](main/control_and_HS/d_HS/utils_HS/compare_hs_response_to_reference.m), not as independent live measurements.

Consequently, the endpoint margins computed in this folder certify only the identified applied-command-to-displacement loop. A publishable full-loop certificate must augment \(M_0,M_1\) with the numerical-substructure states, the measured-force path and its direct \(f_m\to d_n\) feedthrough, the phase lead, and fixed implementation delays. The current simplified `vHS.m` force closure is useful for development but is not a substitute for dynamic or hysteretic physical-force validation.

The natural implementation point is the current varying-PID controller block. Its two inputs are `dd-dm` and `dd`, so it can reconstruct `dm` and implement the fixed observer/integrator at \(T_s=1/2048\) s.

One correction is mandatory before claiming that the controller mathematics matches the experiment. The current controller output is multiplied by a fixed factor 2, then by time-varying SOL-OSI authority, then saturated. Either:

1. make the external gain unity, absorb all fixed scaling into the plant/controller definition, and retain SOL-OSI only as a monitor during the formal pressure-coordinate LQGI experiment; or
2. feed the post-authority, post-saturation applied command `dc` back to the observer and an anti-windup law.

Otherwise the observer assumes input \(u_k\) while the plant receives \(2a_k u_k\), and neither the LTI common-\(P\) proof nor the stated multiplicative-secant surrogate certifies the deployed loop. The first option gives the cleanest paper.

Other implementation facts that must enter the validation model are:

- base rate 2048 Hz, or 0.48828125 ms;
- a Tustin-discretized phase-lead block currently placed between raw \(d_n\) and `dd`;
- downstream displacement saturation at \(\pm70\) mm and no explicit command-rate limiter;
- no separately modeled pure-delay block—the identified plant and phase lead currently carry the latency representation; and
- supply pressure is not logged as a hardware channel, which further favors a fixed robust design over pressure scheduling.

The paper must also choose its regulated signal explicitly. The live controller currently receives phase-led `dd`, while the accepted RTHS metrics compare \(d_m\) with replayed raw \(d_n\). Either route raw \(d_n\) to the pressure-coordinate LQGI or include \(G_T(z)\) in the generalized plant and distinguish actuator tracking of `dd` from RTHS interface tracking of \(d_n\).

## What is plausibly novel

The defensible novelty claim is **not** “a new robust LQG,” “a new multiplicative-noise LQG,” “LQG with integral action,” a new low-rank mean-square radius, or a new endpoint common-\(P\) test. Those claims are precluded by the prior art.

A defensible claim, if the remaining experiments succeed, is:

1. At least three independently identified pressure conditions establish that one pressure coordinate explains the correlated plant change within identification uncertainty; one condition is held out.
2. A single fixed integral output-feedback controller uses no pressure measurement, model switch, or online identifier.
3. One common guaranteed-cost certificate covers the **complete deployed RTHS loop**, including numerical substructure, force feedback, phase lead, delay, scaling, observer, and integrator.
4. Physical RTHS tests show a worst-case improvement over the published integral-LQG and adaptive-LQG baselines at comparable command and noise levels.

A suitable working title is:

> **Fixed pressure-coordinate integral LQG with complete-loop certification for pressure-loss-resilient real-time hybrid simulation**

For an RTHS or control-application journal, this experimentally established model/controller/certificate package may be sufficient. It is not presently a theory-journal contribution: the controller architecture, multiplicative-noise formulation, low-rank computation, and common-\(P\) reasoning are established. A theory-focused control submission would require a genuinely new special-structure synthesis result, not a renamed combination of these ingredients.

## Required validation and falsification tests

### Gate 1: validate the one-coordinate model before controller synthesis

Acquire at least three pressure conditions in a common grey-box state basis. Fit the coordinate without one intermediate condition, preferably 6k, and use that condition only as a holdout. Test

\[
(A(\rho),B(\rho),C(\rho))
\approx(A_0+\rho A_1,B_0+\rho B_1,C_0+\rho C_1).
\]

Compare the affine-family residual with the independent identification residual in both state-space and input-output frequency response. If the holdout model lies materially outside that residual, the one-coordinate paper premise is false and the method should not be pursued in this form.

The supported identification band is approximately 0.125-79.75 Hz. Controller claims should therefore use 2-80 Hz unless new identification supports a wider band.

### Gate 2: compare against methods that can actually solve the local problem

Use identical noise, delay, saturation, rate, initialization, and reference records for:

1. saved PID;
2. nominal realizable LQG;
3. the classical LQGI comparator in this folder;
4. published-style RLQG/LTR;
5. the Zhang et al. ALQG architecture (fixed integral-state LQG plus adaptive ATS prediction);
6. the Condori et al. integral-state LQG benchmark;
7. scalar \(a_0\)-only ATS/adaptive prefilter;
8. oracle pressure-scheduled LQGI as a performance upper benchmark; and
9. the proposed fixed pressure-coordinate robust LQGI.

The original full-state LQR may remain as a diagnostic, but it is not an implementable fair comparator.

### Gate 3: measure actuator performance and complete-RTHS fidelity

Actuator metrics should include:

- normalized RMS and peak \(d_m-d_n\) tracking error;
- frequency-dependent gain, phase, and equivalent delay over 2-80 Hz;
- command RMS/peak, command rate, and saturation fraction;
- measurement-noise-to-command amplification; and
- abrupt-switch recovery and estimator transient.

RTHS metrics should include:

- \(d_m-d_n\) at the interface;
- numerical versus reference floor errors \(x1_n-x1_r\), \(x2_n-x2_r\), and \(x3_n-x3_r\);
- interface error \(d_m-d_r\), plus \(d_n-d_r\) as a diagnostic separating numerical and actuator contributions;
- measured-force consistency and any available reference-interface force error; and
- energy injected at the interface, especially during the pressure transition.

The repository's accepted metrics are already defined as: delay between \(d_n\) and \(d_m\) (J1), normalized RMS and peak tracking errors (J2-J3), normalized floor errors (J4-J6), and normalized mean-square \(d_m-d_r\) error (J7) in [validation_metrics.m](main/results_analysis/validation_metrics.m). Retain these for continuity.

However, the current J1-J3/J7 processing uses a zero-phase 20 Hz low-pass on \(d_m\). Those values cannot support a 2-80 Hz controller claim. Add raw-band magnitude/phase/coherence metrics, command total variation and saturation dwell, \(\sum f_m\Delta d_m\), post-excitation command RMS, and pressure-switch recovery.

Use unseen ground motions and specimen cases, an abrupt 7k-to-5k transition, slow drift, repeated noise realizations, observer-initialization errors, the actual 2048 Hz implementation, measured computation delay/jitter, and the actuator limits.

Match virtual and live metadata explicitly. At present, the live setup and `vHS.m` have different default earthquake intensity and time-scale settings, and the simplified virtual force closure does not reproduce dynamic or hysteretic specimen force. Results obtained under those defaults are not directly comparable.

### Gate 4: predefine failure

The pressure-coordinate robust-LQGI idea should be rejected or reframed if any of the following occurs:

- the holdout pressure model is not represented by the single coordinate within identification uncertainty;
- it does not improve worst-case full-RTHS accuracy over both classical LQGI and RLQG/LTR at comparable command/noise levels;
- the common certificate fails when delay and the numerical substructure are included;
- the improvement exists only for a unit step and disappears for 2-80 Hz or seismic records; or
- saturation, fallback logic, or estimator transients dominate the claimed benefit.

No physical Speedgoat or actuator workflow was run for this study. The current numerical evidence concerns the identified actuator/control-plant models and saved data only.

## Reproducibility

Run [run_sol_ultimate_study.m](main/research/LQG/sol_ultimate/run_sol_ultimate_study.m) from its folder. It regenerates one combined MAT file with a single top-level `result` struct.

| File | Purpose |
|---|---|
| [analyze_source_evidence.m](main/research/LQG/sol_ultimate/analyze_source_evidence.m) | Saved PID, measured endpoint mismatch, identification support, and physical-parameter evidence |
| [analyze_lqg_baseline.m](main/research/LQG/sol_ultimate/analyze_lqg_baseline.m) | Realizable nominal-observer sweep and mismatch/noise audit |
| [analyze_endpoint_tangent_margin.m](main/research/LQG/sol_ultimate/analyze_endpoint_tangent_margin.m) | Endpoint-secant mean-square diagnostic and reduced computation; filename retained for reproducibility |
| [analyze_lqgi_comparator.m](main/research/LQG/sol_ultimate/analyze_lqgi_comparator.m) | Classical integral-LQG comparator, frequency metrics, and secant diagnostic |
| [sol_ultimate_study.mat](main/research/LQG/sol_ultimate/sol_ultimate_study.mat) | Combined numerical results |

All five MATLAB scripts pass `checkcode` as of the report date. The combined MAT contains the source evidence, baseline LQG audit, endpoint-secant audit, and LQGI comparator under one top-level `result` struct. The common guaranteed-cost synthesis remains future work rather than a result hidden in that file.
