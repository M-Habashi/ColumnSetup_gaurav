## Purpose

This paragraph opens the problem formulation by describing the RTHS partition, the role of the transfer system, and the scheme in Figures 1 and 2 before the equation of motion is introduced.

## Sequence

- State the RTHS partition of the reference structural model into numerical and physical substructures.
- Describe how each substructure is realized: real-time computation for one, actuator excitation and sensor instrumentation for the other.
- Name the transfer-system components and state its interface function.
- Introduce Figure 1 with its signals $a_g(t)$, $d_d$, and $f_e$, then Figure 2 as the closer view of the transfer system.
- Close with the qualification that seismic excitation is only an illustration, which leads into the equation of motion.

## First draft

RTHS partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while the physical substructure is excited by actuators and instrumented with sensors. The transfer system, which comprises the controller, servo-valve, and actuator hydraulics, links the two substructures. It enforces compatibility and equilibrium at the interface by synchronizing the physical response with the numerically computed response. Figure 1 shows a typical RTHS scheme, in which the numerical substructure receives the ground acceleration $a_g(t)$ and computes the desired displacement $d_d$, and the physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Seismic excitation is used here as an illustration. The proposed framework also applies to other external excitations, such as wind loading, when the corresponding input to the numerical substructure is changed.

## Review

- **Required ideas mapped:**
  - The partition is stated in sentence 1.
  - Real-time evaluation, actuators, and sensors are in sentence 2.
  - The transfer-system components are in sentence 3, and its function is in sentence 4.
  - Figure 1 and its signals are in sentences 5–7, and Figure 2 is in sentence 8.
  - The seismic illustration and its wind-loading generalization are in sentences 9–10.
  - No idea was omitted. The condition "when the corresponding input to the numerical substructure is changed" stays attached to the generality claim.
- **Unsupported addition removed:** The draft said the transfer system "links the two substructures." The supplied facts give only its components and its synchronization function, so I deleted this clause. The sentence now just lists the components.
- **Actor check:** The sensors are not the subject of "instrument." The physical substructure is "instrumented with sensors" and "excited by actuators," which matches the dictionary roles. The numerical substructure "is evaluated in real time," so the model is not confused with the response it computes.
- **Terminology:**
  - "Controller" is kept unqualified, as in the input. I did not relabel it as an inner or outer loop controller.
  - No Paper 2 symbols, lambda, or adaptive intervention appear.
  - "Interface compatibility and equilibrium" replaces "compatibility and equilibrium at the interface" to match the source phrasing more closely.
- **Crowded sentences split:**
  - The draft's Figure 1 sentence had 2 commas and chained three clauses. I split it so that the figure is introduced first and its signals are described in the following sentences.
  - The draft's sentence 3 had 4 commas. It is now a plain component list.
- **Neighbors:**
  - The first sentence moves directly from the section roadmap into the formulation without repeating it.
  - The last sentence ends on the excitation input to the numerical substructure. This leads naturally into the next paragraph's equation of motion for the reference model.
  - I removed the commas around "such as wind loading" because the phrase restricts "other external excitations."
- **Final prose-comma counts:** S1: 0, S2: 1, S3: 2, S4: 0, S5: 0, S6: 0, S7: 0, S8: 0, S9: 0, S10: 0.

## Final paragraph

RTHS partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while the physical substructure is excited by actuators and instrumented with sensors. The transfer system comprises the controller, servo-valve, and actuator hydraulics. It enforces interface compatibility and equilibrium by synchronizing the physical response with the numerically computed response. Figure 1 shows a typical RTHS scheme. In this scheme the numerical substructure receives the ground acceleration $a_g(t)$ and computes the desired displacement $d_d$. The physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Seismic excitation is used here only as an illustration. The proposed framework also applies to other external excitations such as wind loading when the corresponding input to the numerical substructure is changed.