## Purpose

This passage uses Figure 1 to trace the signals from the numerical substructure through the phase-lead compensator, outer controller, adaptive factor, and plant, so the reader can separate the outer controller loop from the numerical substructure loop before the loop transfer functions are defined.

## Sequence

- Figure 1's engineering purpose: it shows where the adaptive factor enters the signal path of the hybrid simulation.
- Reference generation: the numerical substructure produces d(t), and the phase-lead compensator produces u(t) outside the outer controller loop.
- Control action: C(s) acts on u(t) − y(t), and λ scales the controller output to produce v(t) for H(s,k).
- Plant composition: the transfer system components, the control-structure interaction as a physical coupling, and the specimen of stiffness k.
- Two feedback loops: y(t) closes the outer controller loop, and f_m(t) closes the numerical substructure loop. This sets up the next paragraph's focus on the u(t)-to-y(t) loop.

## First draft

Figure 1 presents the hybrid simulation with the adaptive controller and shows where the adaptive factor enters the signal path between the numerical substructure and the specimen. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). The phase-lead compensator, which is designed to offset the lag of the transfer system and improve tracking, advances d(t) to produce the reference u(t) outside the outer controller loop. The outer controller C(s) acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] then scales the controller output to produce the command v(t), which is applied to the plant H(s,k). The plant comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, the actuator, and the control-structure interaction between the actuator and the specimen. The measured displacement y(t) closes the outer controller loop, and the measured force f_m(t) returns to the numerical substructure to close the numerical substructure loop.

## Review

- **Required-idea mapping (first draft):**
  - Figure purpose: S1.
  - d(t) from ground acceleration and f_m(t): S2.
  - Phase-lead compensator, its design intent, and its position outside the loop: S3.
  - C(s) on u(t) − y(t) and y(t) as measured actuator displacement: S4.
  - λ ∈ (0, 1] producing v(t) for H(s,k): S5.
  - H(s,k) composition and the four transfer-system elements: S6–S7.
  - Two distinct loops: S8.
  - No fact was omitted. No claim of perfect tracking, guaranteed stability, or new results appears.
- **Phase-lead sentence (S3):** The nonrestrictive clause buries the design intent. The phrase "outside the outer controller loop" also attaches ambiguously to "produce". I split it into three sentences:
  1. The compensator's action.
  2. Its design intent, kept as "is designed to" so the qualification is not weakened into a performance claim.
  3. Its position.

  The position sentence states the structural reason: the compensator acts before the tracking error is formed. This follows directly from the supplied facts, since u(t) is the compensator output and C(s) acts on u(t) − y(t).
- **Transfer-system sentence (S7):** It had three prose commas. It also listed the control-structure interaction as though it were a fourth piece of hardware. I split it into two sentences. One lists the inner-loop controller, servo-valve, and actuator. The next names the interaction as the physical coupling between the actuator and the specimen. All four elements remain accounted for.
- **λ sentence (S5):** I removed "then", which implied a temporal step rather than a signal-path relation. I also shortened the relative clause to "the command v(t) applied to the plant H(s,k)". I did not restate the link between the estimated indicator and λ, because the previous paragraph establishes it.
- **Final sentence (S8):** The "and" joined the two loops as if they were one continuous idea. I split them into two sentences and added "separate" so that the outer controller loop and the numerical substructure loop stay distinct.
- **Neighbors:**
  - The previous paragraph ends by announcing the evaluation. The first sentence moves to Figure 1 without repeating the estimator branches or the degradation mechanism.
  - The next paragraph opens with "The estimator monitors the outer controller loop, from u(t) to y(t)". The final sentences now leave that loop clearly identified and separated from the force feedback.
- **Paragraphing:** I split the passage into two connected paragraphs. The first covers the signal path to the plant. The second covers the plant composition and the loop closures.
- **Names and pronouns:** I kept "outer controller" for C(s) and "outer controller loop" for the loop, which keeps the controller and the loop as different objects. "It" in the compensator position sentence refers to the compensator. "It" in the interaction sentence refers to the transfer system, the subject of the preceding sentence. I kept "actuator" rather than adding "hydraulic", because the packet does not use it here.
- **Prose-comma counts (final):** Commas inside mathematical notation, such as (0, 1] and H(s,k), are excluded.
  - S1: 0. S2: 0. S3: 0. S4: 0. S5: 0. S6: 1. S7: 0.
  - S8: 0. S9: 2. S10: 1. S11: 0. S12: 0.
  - No sentence has three or more.

## Final paragraph

Figure 1 presents the hybrid simulation with the adaptive controller and shows where the adaptive factor enters the signal path between the numerical substructure and the specimen. The numerical substructure computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t). A phase-lead compensator advances d(t) to produce the reference u(t). The compensator is designed to offset the lag of the transfer system and improve tracking. It acts on the reference before the tracking error is formed and therefore lies outside the outer controller loop. The outer controller C(s) acts on the tracking error u(t) − y(t), where y(t) is the measured actuator displacement. The adaptive factor λ ∈ (0, 1] scales the controller output to produce the command v(t) applied to the plant H(s,k).

The plant H(s,k) comprises the transfer system and the specimen of stiffness k. The transfer system includes the inner-loop controller, the servo-valve, and the actuator. It also includes the control-structure interaction, which is the physical coupling between the actuator and the specimen. The measured displacement y(t) closes the outer controller loop. The measured force f_m(t) returns to the numerical substructure and closes a separate numerical substructure loop.