## Purpose

This paragraph opens the problem formulation by introducing the RTHS partition, the role of the transfer system, and the signals in Figures 1 and 2 before the numerical substructure is defined.

## Sequence

- State that RTHS partitions a reference structural model into numerical and physical substructures.
- Describe how each substructure is realized: real-time computation for one, actuator excitation and sensor instrumentation for the other.
- Introduce the transfer system through its components and its interface functions.
- Describe the Figure 1 signals ($a_g(t)$, $d_d$, $f_e$), then point to Figure 2 for the transfer system.
- Close with the note that seismic excitation is illustrative, which leads into the numerical-substructure equation of motion.

## First draft

RTHS partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while the physical substructure is excited by actuators and instrumented with sensors. The transfer system, which comprises the controller, servo-valve, and actuator hydraulics, enforces compatibility and equilibrium at the interface by synchronizing the physical response with the numerically computed response. Figure 1 shows a typical RTHS scheme, in which the numerical substructure receives the ground acceleration $a_g(t)$ and computes the desired displacement $d_d$, and the physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Although seismic excitation is used for illustration, the proposed framework also applies to other external excitations, such as wind loading, when the corresponding input to the numerical substructure is changed.

## Review

- **Idea mapping.** Every required idea appears in the draft:
  - partition: S1
  - real-time evaluation, actuators, and sensors: S2
  - transfer system components and functions: S3
  - Figure 1 signals: S4
  - Figure 2: S5
  - excitation generality: S6
- **Added claims.** No components beyond the controller, servo-valve, and actuator hydraulics were added. No Paper 2 symbols or interventions appear.
- **Force path.** I considered stating that $f_e$ is returned to the numerical substructure. I did not add it because the packet only says that the physical substructure provides $f_e$.
- **Qualification.** The condition "when the corresponding input to the numerical substructure is changed" is kept attached to the claim about other excitations.
- **Neighbors.** RTHS is already defined in the previous paragraph, so the acronym is used directly. The previous paragraph only outlines sections, so nothing is repeated. The last sentence ends on the input to the numerical substructure. This leads directly into the next paragraph, which defines the numerical substructure block from the equation of motion.
- **Roles and verbs.**
  - Actuators excite the specimen and the specimen "is instrumented with sensors", as in the dictionary.
  - The transfer system performs "enforces" and "synchronizing", which it actually does.
  - "Actuator hydraulics" and "the controller" are kept as supplied rather than renamed.
- **Draft comma counts:** S1 = 0, S2 = 1, S3 = 4, S4 = 2, S5 = 0, S6 = 3. S3 and S6 exceeded the limit.
- **Edits.**
  - S3 was split into a component sentence and a function sentence, with "It" referring unambiguously to the transfer system.
  - S4 was recast so that Figure 1 frames the clause, and "and" now joins only the two substructure roles.
  - S6 lost the commas around "such as wind loading". The restrictive phrase reads correctly and the qualification stays attached.
- **Reread after edits.** Splitting S3 did not detach the interface functions from the transfer system. The final sentence still connects to the next paragraph.
- **Final comma counts:**

  | Sentence | Prose commas |
  | --- | --- |
  | S1 | 0 |
  | S2 | 1 |
  | S3 | 2 (list) |
  | S4 | 0 |
  | S5 | 1 |
  | S6 | 0 |
  | S7 | 1 |

## Final paragraph

RTHS partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while the physical substructure is excited by actuators and instrumented with sensors. The transfer system comprises the controller, servo-valve, and actuator hydraulics. It enforces compatibility and equilibrium at the interface by synchronizing the physical response with the numerically computed response. In the typical RTHS scheme shown in Figure 1, the numerical substructure receives the ground acceleration $a_g(t)$ and computes the desired displacement $d_d$ and the physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Although seismic excitation is used for illustration, the proposed framework also applies to other external excitations such as wind loading when the corresponding input to the numerical substructure is changed.