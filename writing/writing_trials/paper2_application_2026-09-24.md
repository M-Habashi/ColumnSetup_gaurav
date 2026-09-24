# Paper 2 paragraph revision

This is an application of write.md version 3, not an additional blind agent trial. The manuscript HTML has not been edited.

## Purpose and context

The preceding paragraph introduces the estimator and adaptive controller. The next paragraph identifies the outer controller loop and introduces its transfer functions.

This passage should explain how the numerical displacement becomes a plant command and distinguish the two feedback loops. It should establish the symbols needed for the following equations. Repeating the degradation mechanism here would interrupt that explanation and duplicate the surrounding discussion.

Sequence: numerical calculation → phase-lead compensation → tracking error and controller → adaptive scaling → plant definition → force and displacement feedback. End with the outer controller loop to connect to the next paragraph.

## First draft

Figure 1 shows the hybrid simulation with the proposed adaptive controller. The numerical substructure computes the desired displacement \(d(t)\) from the ground acceleration and measured force \(f_m(t)\). A phase-lead compensator advances \(d(t)\) to produce the reference \(u(t)\). It is designed to offset the transfer-system lag and improve tracking. The outer controller \(C(s)\) acts on the tracking error \(u(t)-y(t)\), where \(y(t)\) is the measured actuator displacement. Its output is scaled by the adaptive factor \(\lambda\in(0,1]\) to produce the command \(v(t)\) applied to the plant \(H(s,k)\).

The plant comprises the transfer system and the specimen of stiffness \(k\). The transfer system includes the inner-loop controller, servo-valve and actuator. It also includes control–structure interaction between the actuator and specimen. The measured displacement \(y(t)\) closes the outer controller loop. The measured force \(f_m(t)\) returns to the numerical substructure and closes the numerical substructure loop.

## Review

- Replaced the figure-only opening with the numerical substructure's actual operation. Figure 1 is introduced within that explanation rather than through a statement about locating or defining a loop.
- Put the compensator's intended engineering purpose before its action. The infinitive states a design purpose rather than claiming perfect cancellation of lag.
- Kept d(t), u(t), v(t), and y(t) distinct. The numerical displacement is not mislabeled as the phase-lead output.
- Kept all four elements in the Paper 2 transfer-system definition. The hardware inventory has one prose comma. Control–structure interaction is identified separately as part of the dynamics rather than presented as another hardware component.
- Ended with displacement feedback to prepare for the following outer-controller-loop equations. The force-feedback sentence remains with the physical signal explanation, without an intervening degradation discussion.
- Required-idea mapping: numerical input and displacement in sentence 1, compensator purpose and reference in sentence 2, tracking error and displacement measurement in sentence 3, adaptive factor and plant command in sentence 4, plant and specimen stiffness in sentence 5, three hardware elements in sentence 6, control–structure interaction in sentence 7, force feedback in sentence 8, and displacement feedback in sentence 9.
- Retained the existing paper-specific notation and scope. Did not add claims about stability guarantees or the direction of mass effects.
- Final prose-comma counts by sentence: 1, 1, 1, 0, 0, 1, 0, 0, 0. Commas inside mathematical notation are excluded. No semicolon or "whose" occurs in the final text.
- Read the final passage with its neighbors. It supplies the signal definitions and loop distinction needed for the next paragraph. The adjacent draft's wording that degradation "acts directly" on a loop remains a separate existing issue, not a claim introduced by this revision.

Sources checked: writing.md for Paper 2 definitions, the current manuscript2_journal_draft.json for neighboring paragraphs, the Paper 1 extraction for physical component roles, and main/control_and_HS/d_HS/utils_HS/optimize_vHS_phase_lead.m plus main/control_and_HS/d_HS/vHS.m for the phase-lead placement after the numerical displacement. The main SOL-OSI page confirms controller scaling but uses an older alpha notation. This revision follows Paper 2's lambda notation.

## Final paragraph

In the hybrid simulation shown in Figure 1, the numerical substructure computes the desired displacement \(d(t)\) from the ground acceleration and measured force \(f_m(t)\). To offset the transfer-system lag and improve tracking, a phase-lead compensator advances \(d(t)\) to produce the reference \(u(t)\). The outer controller \(C(s)\) acts on the tracking error \(u(t)-y(t)\), where \(y(t)\) is the measured actuator displacement. Its output is scaled by the adaptive factor \(\lambda\in(0,1]\) to produce the command \(v(t)\) applied to the plant \(H(s,k)\).

The plant comprises the transfer system and the specimen of stiffness \(k\). The transfer system includes the inner-loop controller, servo-valve and actuator. Control–structure interaction between the actuator and specimen is also included in the transfer-system dynamics. The measured force \(f_m(t)\) returns to the numerical substructure and closes the numerical substructure loop. The measured displacement \(y(t)\) provides feedback to the outer controller and closes the outer controller loop.
