## Purpose

Connect the previously introduced estimator and adaptive controller to the physical signal paths in Figure 1 so that the following outer controller loop equations have clear inputs, outputs, and boundaries.

## Sequence

- The preceding paragraph establishes the estimator and indicator-based adjustment of the adaptive factor.
- Introduce Figure 1 through the coupling between the numerical substructure and the specimen.
- Follow the desired displacement through reference compensation and feedback control to the plant command.
- Define the plant and distinguish the displacement and force feedback loops.
- Prepare the next paragraph by establishing the outer controller loop from \(u(t)\) to \(y(t)\).

## First draft

Figure 1 presents the hybrid simulation with the adaptive controller and identifies the signal paths in its feedback loops. The numerical substructure computes the desired displacement \(d(t)\) from the ground acceleration and the measured force \(f_m(t)\). A phase-lead compensator advances \(d(t)\) to produce the reference \(u(t)\) and is designed to offset transfer-system lag and improve tracking. It acts on the reference outside the outer controller loop. The outer controller \(C(s)\) acts on the tracking error \(u(t)-y(t)\), where \(y(t)\) is the measured actuator displacement. The adaptive factor \(\lambda\in(0,1]\) scales the controller output to produce the command \(v(t)\) applied to the plant \(H(s,k)\).

The plant \(H(s,k)\) comprises the transfer system and the specimen of stiffness \(k\). The transfer system includes the inner-loop controller, servo-valve, and actuator. Control-structure interaction between the actuator and the specimen is also included in the transfer system. The measured displacement \(y(t)\) closes the outer controller loop. The measured force \(f_m(t)\) returns to the numerical substructure and closes the numerical substructure loop.

## Review

- After rereading both neighboring paragraphs, I revised the opening to explain the engineering purpose of Figure 1: actuator tracking and force feedback couple the numerical substructure to the specimen. The first draft merely announced the signal paths.
- I moved the compensator's position outside the outer controller loop into the sentence describing the transformation from \(d(t)\) to \(u(t)\). Its design purpose now occupies a separate sentence. This keeps the loop boundary explicit without crowding the reference transformation and its purpose into one sentence.
- I revised the interaction sentence to identify control-structure interaction explicitly as physical coupling. The hardware inventory remains in a separate sentence so that the interaction is not presented as another hardware component.
- Required-idea mapping for the final passage: sentence 1 introduces the figure and its purpose; sentence 2 gives both numerical-substructure inputs and its displacement output; sentences 3–4 establish reference compensation outside the outer controller loop and its design purpose; sentence 5 defines the controller input and measured displacement; sentence 6 gives the adaptive factor's range, scaling action, and plant command; sentences 7–9 define the plant, specimen stiffness, and all four transfer-system constituents; sentences 10–11 distinguish the two feedback loops.
- The compensator remains “designed to” offset lag and improve tracking. The passage makes no claim of perfect tracking or guaranteed stability. It does not repeat the preceding degradation mechanism or add an initial-state assumption. The final feedback sentences establish the two loop boundaries before the next paragraph selects the outer controller loop for analysis.
- Final sentence prose-comma counts, excluding commas inside mathematical notation: S1 = 1; S2 = 0; S3 = 1; S4 = 0; S5 = 1; S6 = 0; S7 = 0; S8 = 2; S9 = 1; S10 = 0; S11 = 0. No sentence contains three or more prose commas. Rereading the revised passage confirmed that “It” in sentence 4 refers to the compensator and “It” in sentence 9 refers to the transfer system.

## Final paragraph

Figure 1 presents the hybrid simulation with the adaptive controller, showing how actuator tracking and force feedback couple the numerical substructure to the specimen. The numerical substructure computes the desired displacement \(d(t)\) from the ground acceleration and the measured force \(f_m(t)\). Outside the outer controller loop, a phase-lead compensator advances \(d(t)\) to produce the reference \(u(t)\). It is designed to offset transfer-system lag and improve tracking. The outer controller \(C(s)\) acts on the tracking error \(u(t)-y(t)\), where \(y(t)\) is the measured actuator displacement. The adaptive factor \(\lambda\in(0,1]\) scales the controller output to produce the command \(v(t)\) applied to the plant \(H(s,k)\).

The plant \(H(s,k)\) comprises the transfer system and the specimen of stiffness \(k\). The transfer system includes the inner-loop controller, servo-valve, and actuator. It also includes the control-structure interaction, which is the physical coupling between the actuator and the specimen. The measured displacement \(y(t)\) closes the outer controller loop. The measured force \(f_m(t)\) returns to the numerical substructure and closes the numerical substructure loop.
