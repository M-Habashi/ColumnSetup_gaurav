## Purpose

This passage introduces Figure 1 as the hybrid simulation with the adaptive controller. It follows each signal from the numerical substructure to the plant so the reader reaches the outer controller loop equations knowing where λ acts and which measurement closes each loop.

## Sequence

- State the engineering purpose of Figure 1: it shows where the adaptive factor acts and which measured signals close each feedback loop.
- The numerical substructure computes d(t) from the ground acceleration and f_m(t).
- The phase-lead compensator advances d(t) to u(t), outside the outer controller loop.
- C(s) acts on u(t) − y(t), and λ scales its output to give the command v(t) applied to H(s,k).
- Describe what H(s,k) comprises, then separate the outer controller loop (closed by y(t)) from the numerical substructure loop (closed by f_m(t)).

## First draft

Figure 1 shows the hybrid simulation with the adaptive controller and traces each signal that enters the outer controller loop. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). A phase-lead compensator advances d(t) to produce the reference u(t). The compensator is designed to offset the lag of the transfer system and improve tracking, and it acts on the reference outside the outer controller loop. Within the loop, the outer controller C(s) acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] scales the controller output to produce the command v(t), which is applied to the plant H(s,k).

The plant H(s,k) comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, and the actuator. It also includes the control-structure interaction, which is the physical coupling between the actuator and the specimen. Two feedback paths leave the plant. The measured displacement y(t) closes the outer controller loop, whereas the measured force f_m(t) returns to the numerical substructure and closes the numerical substructure loop.

## Review

I reread the previous paragraph, the first draft, and the next paragraph together.

- **Opening sentence was inaccurate.** "Traces each signal that enters the outer controller loop" misstates the figure's content. d(t) and f_m(t) belong to the numerical substructure loop, and u(t) is formed outside the outer controller loop. I split the sentence. The figure is introduced first, and a second sentence states its engineering purpose: where the adaptive factor acts and which measured signals close each loop. This also prepares the next paragraph's focus on the loop from u(t) to y(t).
- **Unclear referent.** "Within the loop" appeared before any single loop had been established in this paragraph. The preceding sentence had just described the compensator as outside the outer controller loop, so the reference was ambiguous. I replaced it with "then" to keep the signal sequence and removed an introductory clause. That sentence dropped from two prose commas to one.
- **Neighbor overlap.** The previous paragraph already links the estimated indicator to updates of λ. The draft does not repeat that link, and I kept it that way. The degradation mechanism is not re-explained. The next paragraph defines H(s,k) = Y(s)/V(s), which is consistent with v(t) being the command applied to H(s,k) and y(t) being its measured output. No edit was needed.
- **Causal claims.** The compensator sentence states only its design intent (offset transfer-system lag, improve tracking) and its placement outside the outer controller loop. I considered adding "therefore" to link the two, but no supplied fact supports that causal relation, so none was added. The draft makes no claims of perfect tracking or guaranteed stability.
- **Terminology.** "Two feedback paths leave the plant" became "Two measured signals leave the plant." y(t) and f_m(t) are measurements, and the phrase avoids implying extra hardware paths. The control-structure interaction is described as a physical coupling within the transfer system, not as a component. Established names are used throughout: numerical substructure, phase-lead compensator, outer controller, adaptive factor, transfer system, inner-loop controller, servo-valve, actuator. The notation d(t), u(t), y(t), v(t), C(s), H(s,k), k, λ, f_m(t) is unchanged. There is no semicolon, no "whose", and no "RTHS".
- **Required ideas mapped (final numbering).**
  - Figure purpose: S1–S2
  - d(t) from ground acceleration and f_m(t): S3
  - Compensator: S4–S5
  - C(s) on the tracking error with y(t) defined: S6
  - λ and v(t) applied to H(s,k): S7
  - H(s,k) composition covering all four transfer-system parts: S8–S10
  - The two distinct loops: S11–S12
- **Prose-comma counts, final paragraph.** The comma in the interval (0, 1] is notation and is not counted.

  | Sentence | Commas |
  | --- | --- |
  | S1 | 0 |
  | S2 | 0 |
  | S3 | 0 |
  | S4 | 0 |
  | S5 | 1 |
  | S6 | 1 |
  | S7 | 1 |
  | S8 | 0 |
  | S9 | 2 |
  | S10 | 1 |
  | S11 | 0 |
  | S12 | 1 |

  No sentence has three or more.

## Final paragraph

Figure 1 presents the hybrid simulation with the adaptive controller. It shows where the adaptive factor acts on the command and which measured signals close each feedback loop. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). A phase-lead compensator advances d(t) to produce the reference u(t). The compensator is designed to offset the lag of the transfer system and improve tracking, and it acts on the reference outside the outer controller loop. The outer controller C(s) then acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] scales the controller output to produce the command v(t), which is applied to the plant H(s,k).

The plant H(s,k) comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, and the actuator. It also includes the control-structure interaction, which is the physical coupling between the actuator and the specimen. Two measured signals leave the plant. The measured displacement y(t) closes the outer controller loop, whereas the measured force f_m(t) returns to the numerical substructure and closes the numerical substructure loop.