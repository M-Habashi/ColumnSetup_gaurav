# Literature Review: OSI and Authority-Factor Adaptation

Date: 2026-07-01

## Local method being compared

The current implementation is a code-generation-safe online margin estimator plus a scalar PID authority update:

- `control_and_HS/OSI/m91_adaptive_margin.m` estimates an online normalized-coprime-factor (NCF) margin from `dd` and `dm` windows.
- Branch 2 uses coherent command/measurement spectra: `T = dm/dd`, `S = 1 - T`, then a phase-aware `S/T` NCF estimate.
- Branch 3 uses residual output evidence when the command does not excite the dangerous band. The residual spectrum is `Syy * max(1 - gamma^2, residual_floor)`, normalized by a healthy calibration baseline, then mapped to a conservative margin proxy.
- The selected OSI margin is the lower of the direct `S/T` branch and residual branch.
- `control_and_HS/OSI/auth_stability_gain.m` uses the OSI margin to reduce or restore a scalar authority factor on the PID loop. It does not identify a full plant online and does not rely on a precomputed PID scheduling surface.
- `control_and_HS/OSI/osi_gain_runtime.m` is fixed-size, scalar-sample, and Speedgoat/Simulink Real-Time compatible. It uses `dd` and `dm` by default and does not require measured force `fm`.

The main comparison question was whether related work combines:

1. Online indication of changing/stability-threatening behavior.
2. Online controller updating based on that change.
3. Poorly known or changing dynamics.
4. No known PID schedule ahead of time.
5. Excitation too narrow for full online identification.
6. A residual-output method like the current OSI residual branch.

## Short answer

I did not find a paper that matches all six conditions in the same implementation.

The closest structural/RTHS relatives split into three families:

- Online stability indicators: they monitor stability risk, but usually do not close the loop by adjusting controller authority.
- Adaptive actuator compensation/control: they update tracking controllers or delay compensators online, but use tracking error, delay estimation, adaptive inverse models, MPC, or plant learning rather than an NCF stability indicator with residual-output fallback.
- Online model updating in hybrid simulation: they update physical/numerical model parameters using UKF, constrained UKF, explicit fitting, EGO, or neural networks. These are close in spirit to "system dynamics are changing", but they do not update PID authority and usually require a parameterized model family.

The residual branch in the current implementation appears more distinctive. Related papers often use residuals in the generic sense of tracking error, Kalman innovation, model-prediction error, or energy imbalance. I did not find a structural RTHS paper using the same idea: frequency-local residual output power after removing command-correlated output by coherence, used as a fallback stability margin when the excitation is not rich enough for full identification.

## Most related papers

Legend for "Residual method":

- `Same? no`: not the current spectral residual-output method.
- `Related residual`: uses tracking error, model residual, Kalman innovation, or energy imbalance, but not the current residual branch.
- `Closest`: conceptually close to residual/error-driven adaptation, but still technically different.

| # | Paper | Structural/RTHS? | How the system is changing | What it does | Similarity to ours | Main difference | Residual method? | Tried here? Worth trying? |
|---|---|---:|---|---|---|---|---|---|
| 1 | Galmez and Fermandois, 2020, "Online Stability Analysis for Real-Time Hybrid Simulation Testing" ([DOI](https://doi.org/10.3389/fbuil.2020.00134)) | Yes | RTHS stability changes as delay, compensation, and physical-substructure uncertainty inject or dissipate energy. | Develops an online stability indicator for RTHS using energy methods to detect instability during the test. | Very close on online indication and safety monitoring. | It is a monitor, not an online controller-authority update law. It uses energy/work logic rather than S/T NCF plus residual-output spectra. | Related residual: energy imbalance, not our residual branch. | Not tried; worth trying as an offline diagnostic and possible secondary authority cap. It could catch energy growth that the frequency OSI misses. |
| 2 | Maghareh et al., 2017, "Predictive stability indicator: a novel approach to configuring a real-time hybrid simulation" ([DOI](https://doi.org/10.1002/eqe.2775)) | Yes | Closed-loop stability sensitivity changes with partitioning, actuator dynamics, delay, and compensation choice. | Uses a predictive stability indicator to configure RTHS partitioning/control before execution. | Close to the idea of a stability margin that protects RTHS. | Predictive/offline configuration rather than online authority update. | Same? no. | Not applicable as an online improvement; worth using as a paper baseline or pre-test design check. |
| 3 | Maghareh, Dyke, and Silva, 2020, "A Self-tuning Robust Control System for nonlinear real-time hybrid simulation" ([DOI](https://doi.org/10.1002/eqe.3260)) | Yes | Transfer-system and physical-substructure dynamics are uncertain, nonlinear, and nonstationary, including failure-like behavior. | Uses a robust nonlinear control layer plus an adaptation layer that learns the control plant at runtime. | One of the closest controller-update papers: uncertain nonlinear RTHS, online adaptation, and no simple fixed schedule. | It adapts a robust/sliding-mode control framework by learning the control plant, not a scalar PID authority from an OSI margin. | Related residual: learning/model error, not our spectral residual. | Not tried; not a near-term replacement. Worth mining for slow adaptation/robustness ideas, but too large a controller change for the current Speedgoat path. |
| 4 | Aguila et al., 2024, "Conditional adaptive time series compensation and control design for multi-axial real-time hybrid simulation" ([DOI](https://doi.org/10.3389/fbuil.2024.1384235)) | Yes | Multi-axial transfer-system coupling, delay, boundary-condition dynamics, and noise change the tracking behavior. | Combines PID or MPC with conditional adaptive time series compensation and inverse decoupling for multi-axial RTHS. | Online controller/compensator adaptation with PID in the loop. | Focuses on tracking and coupling compensation, not stability-margin-to-authority scheduling. Parameters are tuned through sensitivity studies. | Related residual: tracking error/time-series compensation. | Not tried; worth trying only if tracking delay is a dominant error source. Best use is a tracking-control baseline, not a replacement for OSI. |
| 5 | Shangguan et al., 2024, "Adaptive sliding-mode delay compensation for real-time hybrid simulations with multiple actuators" ([DOI](https://doi.org/10.3389/fbuil.2024.1393710)) | Yes | Multi-actuator coupling and each actuator's residual delay vary during the test. | Uses MIMO sliding-mode control plus adaptive discrete-model delay compensation. | Similar because controller parameters change online as the transfer system changes. | Targets actuator delay/coupling, not an OSI stability margin. It identifies/update discrete loading-system parameters. | Related residual: residual delay, not output residual power. | Not tried; not useful for the current single-axis authority problem unless the setup moves to multi-actuator control. |
| 6 | Palacio-Betancur and Gutierrez Soto, 2019, "Adaptive tracking control for real-time hybrid simulation of structures subjected to seismic loading" ([DOI](https://doi.org/10.1016/j.ymssp.2019.106345)) | Yes | Actuator/specimen tracking dynamics change under seismic commands and nonlinear physical-substructure interaction. | Adaptive tracking control for RTHS under seismic loading. | Similar online adjustment under earthquake-like excitation. | Tracking-error objective, not stability-margin indication or scalar authority. | Related residual: tracking error. | Not tried; worth trying as a simple comparison baseline or secondary guard because it is closer to existing PID practice than full model updating. |
| 7 | Wang et al., 2019, "High performance compensation using an adaptive strategy for real-time hybrid simulation" ([DOI](https://doi.org/10.1016/j.ymssp.2019.106262)) | Yes | Loading-system delay/tracking dynamics change with operating condition and specimen interaction. | Adaptive compensation strategy for high-performance RTHS tracking. | Similar online adaptation and practical RTHS focus. | Controller compensation is driven by delay/tracking performance, not NCF margin under poor excitation. | Related residual: tracking/delay error. | Not tried; worth trying only if measured `dm` tracking lag is limiting OSI results. It is less directly tied to stability than our authority law. |
| 8 | Ning et al., 2023, "A Novel Model-Based Adaptive Feedforward-Feedback Control Method for Real-Time Hybrid Simulation considering Additive Error Model" ([DOI](https://doi.org/10.1155/2023/5550580)) | Yes | Servo-control closed-loop behavior is nonlinear/time-varying, producing additive model error relative to the nominal model. | Adds an adaptive additive-error model to model-based feedforward-feedback RTHS control. | Similar because it updates compensation when the test system differs from the nominal model. | Requires a model-based control structure and additive error representation; not a no-full-ID OSI authority factor. | Related residual: additive model error. | Not tried; potentially worth trying offline as an error-model augmentation, but probably too heavy for first target implementation. |
| 9 | Chen, Ricles, and Guo, 2012, "Improved Adaptive Inverse Compensation Technique for Real-Time Hybrid Simulation" ([DOI](https://doi.org/10.1061/%28ASCE%29EM.1943-7889.0000450)) | Yes | Servo-hydraulic phase and amplitude errors vary with actuator dynamics, nonlinearities, and specimen interaction. | Adapts inverse compensation parameters to reduce actuator phase/amplitude errors. | Similar online update using measured actuator performance. | It adapts compensation for tracking, not PID authority based on a stability indicator. | Related residual: tracking phase/amplitude error. | Not tried; worth trying as a compact benchmark if phase lag is the main practical problem. It may improve tracking but will not replace the residual OSI claim. |
| 10 | Chae, Kazemibidokhti, and Ricles, 2013, "Adaptive Time Series Compensator for Delay Compensation of Servo-Hydraulic Actuator Systems for Real-Time Hybrid Simulation" ([DOI](https://doi.org/10.1002/eqe.2294)) | Yes | Servo-hydraulic delay evolves with command history and physical specimen response. | Uses adaptive time-series compensation for servo-hydraulic delay. | Similar because it avoids a fixed compensation choice and updates online from data. | Needs enough tracking history for time-series compensation; not a stability-margin monitor. | Related residual: tracking/history error. | Not tried; worth trying in offline replay as a tracking compensator baseline, especially if it can be kept fixed-size/codegen-safe. |
| 11 | Ou et al., 2015, "Robust integrated actuator control: experimental verification and real-time hybrid-simulation implementation" ([DOI](https://doi.org/10.1002/eqe.2479)) | Yes | Actuator/control-plant dynamics are uncertain and affected by experimental interaction. | Robust integrated actuator control for RTHS. | Similar practical RTHS controller robustness goal. | Robust controller design rather than online OSI-triggered PID authority adaptation. | Same? no. | Not tried; not a direct result-improvement candidate unless the project is ready for a controller redesign. Useful as a robustness benchmark. |
| 12 | Phillips and Spencer, 2013, "Model-Based Feedforward-Feedback Actuator Control for Real-Time Hybrid Simulation" ([DOI](https://doi.org/10.1061/%28ASCE%29ST.1943-541X.0000606)) | Yes | Mainly treats known actuator dynamics/model mismatch rather than large online change. | Model-based feedforward-feedback actuator control for RTHS. | Baseline RTHS control reference. | Model-based and not online adaptive in the same sense. | Same? no. | Not applicable as an adaptive method; useful baseline/reference only. |
| 13 | Hashemi, Masroor, and Mosqueda, 2014, "Implementation of online model updating in hybrid simulation" ([DOI](https://doi.org/10.1002/eqe.2350)) | Yes | Experimental substructure hysteretic/model parameters change as nonlinear damage evolves. | Uses online model updating in hybrid simulation, including UKF-based parameter identification. | Close on online indication/updating under uncertain structural behavior. | Updates structural model parameters, not controller/PID authority. Needs an assumed parameterized model. | Related residual: Kalman innovation/model residual. | Not tried; not directly useful for actuator authority. Worth citing, not implementing, unless we later update FEM/device parameters. |
| 14 | Shao, Mueller, and Mohammed, 2016, "Real-Time Hybrid Simulation with Online Model Updating: Methodology and Implementation" ([DOI](https://doi.org/10.1061/%28ASCE%29EM.1943-7889.0000987)) | Yes | Bouc-Wen hysteretic parameters change/are uncertain during RTHS. | Implements RTHS with UKF-based online model updating of a Bouc-Wen model. | Close on real-time updating and uncertain/nonlinear hysteretic dynamics. | Updates numerical model, not control authority; requires a Bouc-Wen-type model family. | Related residual: UKF innovation. | Not tried; not a near-term OSI improvement because our problem is stability/authority under limited excitation, not hysteretic model updating. |
| 15 | Ou, Dyke, and Prakash, 2017, "Real time hybrid simulation with online model updating: an analysis of accuracy" ([DOI](https://doi.org/10.1016/j.ymssp.2016.06.015)) | Yes | Model fidelity changes as online updating reacts to nonlinear experimental response. | Analyzes accuracy effects of online model updating in RTHS. | Close on online dynamics correction. | Model fidelity focus, not controller stability authority. | Related residual: model update residual/innovation. | Not tried; not a controller-improvement candidate. Worth using to justify why we are not attempting full online identification. |
| 16 | Song and Dyke, 2014, "Real-Time Dynamic Model Updating of a Hysteretic Structural System" ([DOI](https://doi.org/10.1061/%28ASCE%29ST.1943-541X.0000857)) | Yes | Nonlinear hysteretic stiffness/yield/post-yield parameters evolve with damage. | Real-time update of nonlinear hysteretic structural model parameters. | Similar because dynamics are changing and not perfectly known. | Structural model updating, not actuator/controller authority. | Related residual: estimator innovation/model error. | Not tried; not directly applicable unless we introduce a physical-column parameter estimator. |
| 17 | Kwon and Kammula, 2013, "Model updating method for substructure pseudo-dynamic hybrid simulation" ([DOI](https://doi.org/10.1002/eqe.2307)) | Yes | Substructure model parameters change or are corrected as hybrid-test data arrives. | Updates hybrid simulation model parameters in pseudo-dynamic substructuring. | Similar online model correction from hybrid-test data. | Not real-time controller adaptation, and not PID authority. | Related residual: model discrepancy. | Not tried; not applicable to immediate OSI/authority results. |
| 18 | Wu and Wang, 2014, "Model updating with constrained unscented Kalman filter for hybrid testing" ([DOI](https://doi.org/10.12989/sss.2014.14.6.1105)) | Yes | Constrained structural/model parameters evolve under hybrid-test data. | Uses constrained UKF for model updating in hybrid testing. | Close on online parameter estimation with constraints. | Estimation/model updating rather than stability indicator and control-authority scheduling. | Related residual: UKF innovation. | Not tried; low priority because constrained UKF adds complexity and needs a chosen parameter model. |
| 19 | Mei et al., 2019, "Hybrid simulation with online model updating: Application to a reinforced concrete bridge endowed with tall piers" ([DOI](https://doi.org/10.1016/j.ymssp.2019.01.009)) | Yes | RC bridge pier stiffness/damage parameters change during nonlinear response. | Applies online model updating to a bridge hybrid simulation with tall piers. | Close structural application with changing/uncertain nonlinear response. | Updates structural parameters, not actuator/PID authority. | Related residual: parameter-estimation residual. | Not tried; not useful for improving current actuator stability unless the numerical bridge/FEM model becomes the target. |
| 20 | Al-Subaihawi, Ricles, Quiel, and Marullo, 2022, "Online explicit model updating of nonlinear viscous dampers for real time hybrid simulation" ([DOI](https://doi.org/10.1016/j.soildyn.2021.107108)) | Yes | Nonlinear viscous damper coefficients and velocity dependence change/are uncertain. | Online explicit model updating for nonlinear viscous dampers in RTHS. | Close because it handles difficult nonlinear devices online. | Updates damper model parameters, not controller authority; device model is explicit. | Related residual: model-fitting error. | Not tried; only worth trying if our physical column can be reduced to a simple explicit device law. Otherwise not directly applicable. |
| 21 | Sepulveda et al., 2024, "Selective online model updating in hybrid simulation of a full-scale steel moment frame" ([DOI](https://doi.org/10.1002/eqe.4149)) | Yes | RBS plastic hinge parameters and asymmetric fracture/local damage evolve during full-scale HS. | Selective UKF-based online updating of plastic hinge models in a full-scale steel moment frame hybrid simulation. | Close on realistic structural nonlinearity and online adaptation. | The update target is the numerical structural model; it is not an actuator/PID authority law. | Related residual: UKF/model residual. | Not tried; not an OSI improvement, but useful to cite as evidence that online model updating is a separate contribution family. |
| 22 | Zhong et al., 2025, "Real-Time Hybrid Simulation With EGO-Based Online Model Updating" ([DOI](https://doi.org/10.1002/eqe.4333)) | Yes | Structural model parameters are corrected in moving windows as test data reveals model mismatch. | Uses efficient global optimization with moving-window test data for online model updating. | Similar because it addresses online updating without simple fixed schedules. | Optimization-based model updating; not stability indicator to controller authority. | Related residual: objective/model error. | Not tried; not target-safe enough for current OSI path, but possibly useful for offline post-test parameter studies. |
| 23 | Malik et al., 2025, "Online Cyber-Physical Neural Network Model for Real-Time Hybrid Simulation" ([DOI](https://doi.org/10.1002/eqe.70036)) | Yes | Device/model behavior changes and is learned by a cyber-physical neural network during RTHS. | Uses an online cyber-physical neural network model for RTHS. | Similar in online learning under uncertain device behavior. | Learns/predicts model/device behavior rather than scaling a controller based on NCF. | Related residual: training/model error. | Not tried; not worth trying for current Speedgoat stability protection because NN training/validation burden is high. |
| 24 | Al-Subaihawi et al., 2024, "Real-Time Hybrid Simulation of Structural Systems With Soil-Foundation Interaction Effects Using Neural Networks" ([DOI](https://doi.org/10.1002/eqe.4236)) | Yes | Soil-foundation-structure interaction is nonlinear and hard to model directly. | Uses neural networks for soil-foundation interaction effects in RTHS. | Similar in using data-driven modeling for poorly known dynamics. | Model/surrogate update, not online PID authority or residual OSI. | Related residual: learning/model error. | Not tried; not applicable unless the research shifts to surrogate modeling of the physical substructure. |
| 25 | Simpson, Dertimanis, and Chatzi, 2020, "Towards Data-Driven Real-Time Hybrid Simulation: Adaptive Modeling of Control Plants" ([DOI](https://doi.org/10.3389/fbuil.2020.570947)) | Yes | Control-plant/inverse dynamics drift or are not known well enough for a fixed inverse model. | Adaptive signal-processing / adaptive inverse-control modeling of RTHS control plants. | Very relevant because it learns the control plant online rather than relying fully on a known model. | Still adapts a control plant/inverse model for tracking, not a scalar authority factor from a stability indicator. | Closest among adaptive-control papers, but residual/error is for inverse modeling, not our residual branch. | Not tried; worth trying offline if we want a tracking improvement baseline. It could improve `dm` following `dd`, but does not answer the limited-excitation stability problem by itself. |
| 26 | Tsokanas, Pastorino, and Stojadinovic, 2022, "Adaptive model predictive control for actuation dynamics compensation in real-time hybrid simulation" ([DOI](https://doi.org/10.1016/j.mechmachtheory.2022.104817)) | Yes | Actuation-dynamics model parameters change and are identified online for MPC. | Adaptive MPC with real-time model identification for actuation dynamics compensation. | Similar online controller update under uncertain actuation dynamics. | Requires online model identification and MPC, while our method avoids full online ID and only scales authority. | Related residual: model identification/tracking error. | Not tried; not worth first because it violates the simple/codegen-safe direction. Good high-performance benchmark only. |
| 27 | Li et al., 2022, "An Adaptive and Robust Control Strategy for Real-Time Hybrid Simulation" ([DOI](https://doi.org/10.3390/s22176569)) | Yes | Control-plant uncertainty and test-condition variation affect RTHS tracking/stability. | Adaptive/robust controller strategy for RTHS. | Similar in combining robustness and adaptation. | Controller architecture is different; not NCF indicator to PID authority and no residual-output fallback. | Related residual: tracking/model error. | Not tried; possible later, but not the most direct way to improve our current results. |
| 28 | Safonov and Tsao, 1997, "The unfalsified control concept and learning" ([DOI](https://doi.org/10.1109/9.587340)) | No | Unknown plant/controller performance changes; data falsifies controllers that no longer meet performance criteria. | Data-driven controller selection from closed-loop input-output data without explicit plant identification. | Conceptually close to online performance indication and controller switching without full model ID. | Usually chooses among candidate controllers; not RTHS, not PID authority, and no frequency-local residual output branch. | Related residual: unfalsified performance cost. | Not tried; worth a small offline experiment as an authority-level selector/candidate-bank baseline, but low priority. |
| 29 | Campi, Lecchini, and Savaresi, 2002, "Virtual Reference Feedback Tuning: a direct method for the design of feedback controllers" ([DOI](https://doi.org/10.1016/S0005-1098(02)00032-8)) | No | Plant/controller mismatch is corrected from informative input-output data, usually offline. | Data-driven controller tuning directly from input-output data. | Similar in avoiding explicit plant identification. | Primarily offline/batch tuning and needs informative data; not online stability protection under narrow excitation. | Same? no. | Not applicable to online OSI; possibly useful for post-test PID retuning only. |
| 30 | Hoagg and Bernstein, 2012, "Retrospective Cost Model Reference Adaptive Control for Nonminimum-Phase Systems" ([DOI](https://doi.org/10.2514/1.57001)) | No | Unknown sampled-data plant dynamics and performance change relative to a target model. | Direct adaptive control using retrospective performance/cost and recursive least squares. | Similar in online controller adaptation with limited plant knowledge. | General control method, not RTHS; requires target-model/control assumptions and does not implement an OSI residual fallback. | Related residual: retrospective performance variable. | Not tried; not worth first for this project because assumptions and implementation complexity are high. |

## Screening analysis: what is worth trying

No implementation trials were run for this review. I did not run MATLAB, change Simulink, change saved results, or alter the OSI implementation. "Tried here?" in the table means paper-screened only.

The methods most worth trying, in priority order, are:

1. Energy-based online stability indicator as a diagnostic or secondary authority cap.
   - Source family: Galmez and Fermandois 2020.
   - Why it is worth trying: it measures instability through energy/work rather than frequency response, so it is independent evidence. It could be evaluated offline from existing `dd`, `dm`, and possibly `fm` records without changing the target controller.
   - Risk: it may need force or reliable power/energy signals; if it uses `fm`, it weakens the current "dd/dm only" implementation claim.

2. Simple tracking-error/phase-error adaptive rule as a baseline, not as a replacement.
   - Source family: Chen/Ricles/Guo, Chae/Ricles, Palacio-Betancur/Gutierrez Soto, Wang/Ning/Wu.
   - Why it is worth trying: reviewers will expect comparison against tracking-error-driven adaptation. If tracking error alone performs worse than OSI in the narrow-excitation case, that strengthens the paper.
   - Risk: it can reduce phase lag and improve tracking, but it may not detect output-only instability when the command lacks critical-frequency content.

3. Adaptive time-series or data-driven inverse model as a tracking improvement layer.
   - Source family: Chae et al. 2013, Aguila et al. 2024, Simpson et al. 2020.
   - Why it is worth trying: it may improve `dm` following `dd`, which can indirectly improve OSI quality and RTHS response.
   - Risk: it changes the actuator/control path rather than the OSI logic. It may make the contribution less clean unless tested as a separate baseline.

4. Unfalsified authority-level candidate bank.
   - Source family: Safonov and Tsao 1997.
   - Why it is worth trying: it maps naturally to our scalar authority factor. Candidate authorities such as `[1.0, 0.7, 0.5, 0.3, 0.15, 0.08]` could be evaluated from closed-loop data using a performance/falsification cost.
   - Risk: under narrow excitation, the falsification cost may not see the dangerous frequency either. This is low priority but intellectually close.

Methods I would not try first:

- Full UKF/EGO/NN online model updating. These papers are useful for positioning the literature, but they update structural/device models and require parameterized models, optimization, or learned surrogates. They are not direct fixes for the current stability-authority problem.
- Adaptive MPC or full self-tuning robust control. These are powerful but too large for the current code-generation-safe Speedgoat path. They would be a separate controller project, not a small improvement to OSI/auth-factor behavior.
- VRFT. It is useful for post-test PID retuning, but it does not solve the online, narrow-excitation stability-monitoring problem.

My practical recommendation is to try only the first two before writing the paper: an energy indicator as an independent diagnostic and a tracking-error authority baseline. If the current OSI/residual authority beats those on saved records and at least one real-time run, the contribution claim becomes much stronger.

## Are they using our residual method?

No, not in the same form.

Several papers use something that could be called a residual:

- Adaptive compensation papers use actuator tracking error, phase error, amplitude error, or residual delay.
- Online model updating papers use Kalman-filter innovations, model prediction errors, or parameter-estimation objective residuals.
- Online stability papers use energy/work balance or predicted stability metrics.
- General data-driven control papers use performance costs, virtual references, or retrospective performance variables.

The current OSI residual branch is different because it is an output-only stability-warning path:

- It explicitly removes the command-correlated output contribution using coherence.
- It compares the residual output spectrum against a healthy baseline.
- It is designed for the specific bad case where the command has little or no power at the dangerous frequency, so direct FRF/closed-loop identification is not reliable.
- It maps residual growth to a conservative NCF-like margin and then uses that margin to reduce PID authority.

That combination is the most publishable technical distinction I found.

## Contribution assessment

My opinion: the implementation is promising enough to be a new contribution, but the paper should be framed carefully.

The strongest novelty claim is not "adaptive RTHS control" by itself. That field is already active. The stronger claim is:

> A code-generation-safe online stability-indicator-to-authority controller for RTHS that uses a phase-aware closed-loop `S/T` NCF estimate when the command excites the loop and a coherence-removed residual-output branch when excitation is too narrow for full online identification.

This is meaningfully different from:

- Galmez and Fermandois: online stability indication, but no automatic authority update.
- Maghareh et al. SRCSys: online controller adaptation, but through robust nonlinear control and plant learning, not a compact NCF indicator plus residual-output authority scaling.
- ATS/adaptive inverse/MPC compensation papers: online controller updates, but mainly for tracking/delay, not stability margin under insufficient excitation.
- UKF/EGO/NN model-updating papers: online model updates, but not controller-authority scheduling.
- Unfalsified/VRFT/RCAC controls: related data-driven philosophy, but not structural RTHS and not the residual-output NCF branch.

## What is needed to make the paper defensible

The current implementation looks journal-worthy only if the paper includes validation that directly attacks the likely reviewer objections:

1. Show that reducing the scalar PID authority actually monotonically improves the relevant loop stability margin for the tested inner loop. The local research notes already suggest this, but it should be formalized with plots and a concise derivation.
2. Compare against at least three baselines:
   - Fixed conservative authority.
   - Direct `S/T` OSI without residual branch.
   - A simple tracking-error or RMS-error authority rule.
3. Demonstrate the narrow-excitation case where full online identification fails or is unreliable, but the residual branch still detects risk early enough.
4. Demonstrate that the residual branch does not falsely reduce authority during quiet/no-excitation periods, sensor noise, or harmless uncorrelated output noise.
5. Include at least one real-time Speedgoat/RTHS run if possible. Offline replay is useful but will not fully prove real-time feasibility, even though the code is written for fixed-size runtime use.
6. Report computational timing and code-generation constraints because this is one of the practical strengths of the method.

If those points are covered, I think the work is strong enough for a structural control / hybrid simulation paper. Without real-time or hardware evidence, it is still a credible conference paper or methods note, but the journal claim should be more conservative.

## Suggested paper angle

Possible title:

> Online Stability-Indicator Authority Scaling for Real-Time Hybrid Simulation Under Limited Excitation

Possible contribution bullets:

- A two-branch online stability indicator for RTHS that remains useful when the command does not excite the critical frequency.
- A scalar PID authority update law driven by an NCF-like stability margin rather than tracking error alone.
- A Speedgoat-compatible implementation using fixed-size arrays and only `dd`/`dm` runtime signals.
- Validation on saved and real-time RTHS records showing earlier/more reliable protection than direct FRF-only OSI or tracking-error rules.

## Source notes

Primary publisher or DOI pages used during this search include:

- Frontiers, Online Stability Analysis for RTHS: https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.00134/full
- Frontiers, Adaptive sliding-mode delay compensation: https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2024.1393710/full
- Frontiers, Conditional adaptive time series compensation: https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2024.1384235/full
- Frontiers, Data-driven RTHS adaptive modeling: https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.570947/full
- Frontiers, Hybrid simulation with model updating compared to shake table: https://www.frontiersin.org/journals/built-environment/articles/10.3389/fbuil.2020.00103/full
- Wiley, Predictive stability indicator: https://doi.org/10.1002/eqe.2775
- Wiley, Self-tuning robust control system: https://doi.org/10.1002/eqe.3260
- Wiley, Selective online model updating: https://doi.org/10.1002/eqe.4149
- Wiley, EGO-based online model updating: https://doi.org/10.1002/eqe.4333
- Wiley, Online cyber-physical neural network model: https://doi.org/10.1002/eqe.70036
- Wiley, Soil-foundation interaction using neural networks: https://doi.org/10.1002/eqe.4236
- ASCE, real-time dynamic model updating: https://doi.org/10.1061/%28ASCE%29ST.1943-541X.0000857
- ASCE, RTHS with online model updating: https://doi.org/10.1061/%28ASCE%29EM.1943-7889.0000987
- ASCE, improved adaptive inverse compensation: https://doi.org/10.1061/%28ASCE%29EM.1943-7889.0000450
- ASCE, model-based feedforward-feedback actuator control: https://doi.org/10.1061/%28ASCE%29ST.1943-541X.0000606
- Elsevier, adaptive tracking control: https://doi.org/10.1016/j.ymssp.2019.106345
- Elsevier, high performance adaptive compensation: https://doi.org/10.1016/j.ymssp.2019.106262
- Elsevier, RTHS with online model updating accuracy: https://doi.org/10.1016/j.ymssp.2016.06.015
- Elsevier, RC bridge online model updating: https://doi.org/10.1016/j.ymssp.2019.01.009
- Elsevier, online explicit model updating of nonlinear viscous dampers: https://doi.org/10.1016/j.soildyn.2021.107108
- Elsevier, adaptive MPC for actuation dynamics compensation: https://doi.org/10.1016/j.mechmachtheory.2022.104817
- Sensors, adaptive and robust RTHS control: https://doi.org/10.3390/s22176569
- Structural Control and Health Monitoring, adaptive feedforward-feedback control: https://doi.org/10.1155/2023/5550580
- Smart Structures and Systems, constrained UKF for hybrid testing: https://doi.org/10.12989/sss.2014.14.6.1105
- IEEE TAC, unfalsified control: https://doi.org/10.1109/9.587340
- Automatica, VRFT: https://doi.org/10.1016/S0005-1098(02)00032-8
- AIAA Journal of Guidance, Control, and Dynamics, retrospective cost MRAC: https://doi.org/10.2514/1.57001
