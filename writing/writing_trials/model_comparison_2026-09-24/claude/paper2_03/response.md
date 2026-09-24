## Purpose

This passage uses Figure 1 to show how signals pass through the hybrid simulation with the adaptive controller, and where the adaptive factor acts. It keeps the outer controller loop distinct from the numerical substructure loop so that the next paragraph can define the transfer functions of the outer controller loop.

## Sequence

- State the engineering purpose of Figure 1: the signals exchanged between the substructures and the point where λ modifies the command.
- Trace the reference path: d(t) from the numerical substructure, then u(t) from the phase-lead compensator outside the outer controller loop.
- Describe the outer controller loop: C(s) acts on u(t) − y(t), and λ scales its output to give v(t) applied to H(s,k).
- Define H(s,k): the transfer system hardware first, then control-structure interaction as a physical coupling, then the specimen of stiffness k.
- Close with the two feedback signals and the two distinct loops they close.

## First draft

Figure 1 presents the hybrid simulation with the adaptive controller and shows the signal path between the numerical substructure, the outer controller loop, and the plant. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). A phase-lead compensator advances d(t) to produce the reference u(t). It is designed to offset the lag of the transfer system and improve tracking, and it acts on the reference outside the outer controller loop. Within this loop, the outer controller C(s) acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] scales the controller output to produce the command v(t), which is applied to the plant H(s,k).

The plant H(s,k) comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, the actuator, and the control-structure interaction between the actuator and the specimen. The measured displacement y(t) closes the outer controller loop. The measured force f_m(t) returns to the numerical substructure and closes the numerical substructure loop.

## Review

- **Mapping of required ideas.** Each required idea maps to a sentence in both drafts:
  - Figure 1 purpose.
  - d(t) from the ground acceleration and f_m(t).
  - The phase-lead compensator, its design intent, and its position outside the loop.
  - C(s) acting on u(t) − y(t), with y(t) defined.
  - λ ∈ (0, 1] producing v(t) applied to H(s,k).
  - The composition of H(s,k), including all four transfer-system elements and k.
  - The two loops closed by y(t) and f_m(t).
  
  No required fact was omitted. "Improve tracking" is kept without any claim of perfect tracking or guaranteed stability.
- **Figure purpose.** Sentence 1 only said that the figure "shows the signal path," and it had 2 commas. I split it. The second sentence now states the engineering purpose: the figure shows the signals exchanged between the substructures and where the adaptive factor modifies the command.
- **Pronoun referent.** In "It is designed to offset…", "It" could refer to u(t), the last noun of the previous sentence. I replaced it with "The compensator."
- **Misplaced component.** The inventory sentence listed control-structure interaction as if it were a fourth piece of hardware, and it had 3 commas. I split it into two sentences:
  - One sentence names the inner-loop controller, the servo-valve, and the actuator.
  - The next sentence names the interaction as the physical coupling between the actuator and the specimen.
- **Loop contrast.** The last two sentences described the two loops separately, so the reader never saw them contrasted. I joined them with "whereas." This keeps the outer controller loop and the numerical substructure loop explicitly distinct.
- **"Within this loop."** I removed this phrase. Its referent was clear, but the opening clause was unnecessary once C(s) is named with the tracking error.
- **Relative clause.** I removed ", which is applied to" in the λ sentence and used "the command v(t) applied to the plant H(s,k)." This leaves one clause for one idea.
- **Unsupported additions.** I checked for these and found none. I considered making the compensator's position a causal statement ("because it acts on the reference…") and rejected it, because the packet states the position but not a causal reason.
- **Neighbors.**
  - The first sentence does not repeat the previous paragraph's account of the estimator or of degradation.
  - The last sentence stops short of the next paragraph's reason for monitoring u(t) to y(t).
  - v(t) → y(t) through H(s,k) is consistent with the next paragraph's H(s,k) = Y(s)/V(s).
- **Unresolved inconsistency in a neighbor, outside this passage.** The previous paragraph calls u(t) "the desired displacement calculated by the numerical substructure." The required ideas define d(t) as the desired displacement and u(t) as the compensated reference. I followed the required ideas. The previous paragraph should be corrected so that it matches.
- **Terminology checks.**
  - No semicolons, "whose", RTHS, or controller switching.
  - Named blocks and all notation are unchanged.
  - "Inner-loop controller" follows the packet's spelling.
- **Final prose-comma counts, in sentence order.** Mathematical commas in (0, 1] and H(s,k) are not counted. No sentence has three or more prose commas.

| Paragraph | Sentence | Prose commas |
| --- | --- | --- |
| 1 | S1 | 0 |
| 1 | S2 | 0 |
| 1 | S3 | 0 |
| 1 | S4 | 0 |
| 1 | S5 | 1 |
| 1 | S6 | 1 |
| 1 | S7 | 0 |
| 2 | S1 | 0 |
| 2 | S2 | 2 |
| 2 | S3 | 1 |
| 2 | S4 | 1 |

## Final paragraph

Figure 1 presents the hybrid simulation with the adaptive controller. It shows the signals exchanged between the numerical and physical substructures and the point at which the adaptive factor modifies the command. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). A phase-lead compensator advances d(t) to produce the reference u(t). The compensator is designed to offset the lag of the transfer system and improve tracking, and it acts on the reference outside the outer controller loop. The outer controller C(s) acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] scales the controller output to produce the command v(t) applied to the plant H(s,k).

The plant H(s,k) comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, and the actuator. It also includes the control-structure interaction, which is the physical coupling between the actuator and the specimen. The measured displacement y(t) closes the outer controller loop, whereas the measured force f_m(t) returns to the numerical substructure and closes the numerical substructure loop.