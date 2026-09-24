## Purpose

Explain Figure 1 through the displacement-control signal path and the distinct feedback loops that connect the adaptive controller, plant, and numerical substructure.

## Sequence

- The preceding paragraph establishes the estimator, its initial-state fallback, and adjustment of the adaptive factor during the experiment.
- This passage must add the physical components and signal relationships that make Figure 1 useful for interpreting the feedback loops.
- Follow the desired displacement through the phase-lead compensator, outer controller, and adaptive scaling.
- Define the plant and distinguish displacement feedback to the controller from force feedback to the numerical substructure.
- Prepare the next paragraph by identifying the outer controller loop and placing reference compensation outside it.

## First draft

Figure 1 presents the hybrid simulation with the adaptive controller and shows the distinct roles of displacement and force feedback. The numerical substructure computes the desired displacement $d(t)$ from the ground acceleration and measured force $f_m(t)$. A phase-lead compensator advances $d(t)$ to produce the reference $u(t)$, with the aim of offsetting transfer-system lag and improving tracking. It acts on the reference outside the outer controller loop. The outer controller $C(s)$ acts on the tracking error $u(t)-y(t)$, where $y(t)$ is the measured actuator displacement. The adaptive factor $\lambda \in (0,1]$ scales the controller output to produce the command $v(t)$ applied to the plant $H(s,k)$.

The plant $H(s,k)$ comprises the specimen of stiffness $k$ and the transfer system, including the inner-loop controller, servo-valve, actuator, and control-structure interaction between the actuator and specimen. The measured displacement $y(t)$ closes the outer controller loop by providing feedback to $C(s)$. The measured force $f_m(t)$ returns to the numerical substructure and closes the numerical substructure loop.

## Review

- Rereading the preceding paragraph showed that the estimator branches and the reason for adjusting $\lambda$ are already established. The draft therefore introduces neither another estimator explanation nor another account of degradation. The opening sentence gives Figure 1 an engineering purpose through the roles of the two feedback signals.
- Split the phase-lead explanation between the signal transformation and the compensator's location and design purpose. Replaced “with the aim of” with “is designed to.” The final wording retains a design objective without asserting perfect compensation or tracking.
- The draft's plant sentence contains four prose commas and places physical interaction in the same inventory as hardware. Replaced it with three sentences: plant composition, transfer-system hardware, and control-structure interaction as physical coupling. All four required transfer-system elements remain explicit.
- Required-idea mapping to the final sentences: S1 introduces Figure 1 and its purpose. S2 gives both numerical-substructure inputs and $d(t)$. S3–S4 define $u(t)$ and the compensator's purpose and position. S5 defines the tracking error and $y(t)$. S6 defines adaptive scaling, its range, and $v(t)$. S7–S9 define $H(s,k)$ and its contents. S10–S11 distinguish the displacement and force feedback loops. No required fact or qualification is omitted.
- Checked the final passage against the following paragraph: the controller input, measured displacement, and plant command are defined before the loop transfer functions. The compensator remains outside the outer controller loop. The passage adds no stability guarantee, controller switching, or scientific result.
- Final sentence prose-comma counts: S1 = 0, S2 = 0, S3 = 0, S4 = 0, S5 = 1, S6 = 0, S7 = 0, S8 = 2, S9 = 0, S10 = 0, S11 = 0. Commas within mathematical notation are excluded. Rereading the revised sentences confirmed that “It” in S4 refers to the compensator and “It” in S9 refers to the transfer system. No unresolved defect was identified.

## Final paragraph

Figure 1 presents the hybrid simulation with the adaptive controller and shows the distinct roles of displacement and force feedback. The numerical substructure computes the desired displacement $d(t)$ from the ground acceleration and measured force $f_m(t)$. A phase-lead compensator advances $d(t)$ to produce the reference $u(t)$. It acts on the reference outside the outer controller loop and is designed to offset transfer-system lag and improve tracking. The outer controller $C(s)$ acts on the tracking error $u(t)-y(t)$, where $y(t)$ is the measured actuator displacement. The adaptive factor $\lambda \in (0,1]$ scales the controller output to produce the command $v(t)$ applied to the plant $H(s,k)$.

The plant $H(s,k)$ comprises the transfer system and the specimen of stiffness $k$. The transfer system includes the inner-loop controller, servo-valve, and actuator. It also includes the control-structure interaction that physically couples the actuator and specimen. The measured displacement $y(t)$ closes the outer controller loop by providing feedback to $C(s)$. The measured force $f_m(t)$ returns to the numerical substructure and closes the numerical substructure loop.