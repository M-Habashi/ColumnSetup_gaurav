## Purpose

Introduce the RTHS substructures and transfer-system functions after the paper roadmap to prepare the reader for the reference-model equation of motion.

## Sequence

- The preceding paragraph establishes the paper roadmap and identifies Section 2 as the problem formulation.
- Add the engineering definition of RTHS by introducing the partition and how each substructure is evaluated or excited.
- Define the transfer-system components and explain how synchronization enforces the interface conditions.
- Connect Figure 1 to the input and response signals and Figure 2 to the transfer system, then explain the excitation scope.
- The next paragraph needs the numerical substructure and its excitation input established before introducing the reference-model equation.

## First draft

Real-time hybrid simulation (RTHS) partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while actuators excite the physical substructure and sensors instrument it. The transfer system comprises the controller, servo-valve, and actuator hydraulics, and it enforces interface compatibility and equilibrium by synchronizing the physical response with the numerically computed response. Figure 1 shows a typical RTHS scheme in which the numerical substructure receives ground acceleration $a_g(t)$ and computes the desired displacement $d_d$, while the physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Seismic excitation is used here as an illustration, and the proposed framework also applies to other external excitations such as wind loading by changing the corresponding input to the numerical substructure.

## Review

- Rereading the roadmap and the equation-introducing paragraph confirmed that the opening should define RTHS directly. The final sentence returns to the numerical-substructure input and prepares for the equation without repeating the roadmap.
- Split the first draft's third sentence into final sentences 3 and 4. The original contained three prose commas and combined a component inventory with the system's function. The revised pair retains the synchronization mechanism and both interface conditions.
- Split the Figure 1 description into final sentences 5 and 6 to distinguish the numerical displacement calculation from the physical force measurement. Neither signal nor its source changed.
- Split the excitation statement into final sentences 8 and 9. The seismic illustration remains distinct from the broader applicability claim, and changing the corresponding numerical input remains attached to that claim.
- Required-idea mapping: sentence 1 gives the structural partition. Sentence 2 supplies real-time computer evaluation, actuator excitation, and sensor instrumentation. Sentences 3–4 define the transfer system and its functions. Sentences 5–6 identify Figure 1 and preserve $a_g(t)$, $d_d$, and $f_e$. Sentence 7 identifies Figure 2. Sentences 8–9 preserve the seismic illustration and applicability to wind loading through an input change.
- The synchronization mechanism and excitation-input change follow the supplied facts. No additional components, scientific claims, citations, or Paper 2 interventions were introduced. In sentence 4, “It” refers directly to the transfer system in sentence 3.
- Final prose-comma counts for sentences 1–9 are 0, 1, 2, 0, 0, 0, 0, 0, and 0. Rereading the revised paragraph found no detached qualification or omitted required idea.

## Final paragraph

Real-time hybrid simulation (RTHS) partitions a reference structural model into a numerical substructure and a physical substructure. The numerical substructure is evaluated in real time on a computer, while actuators excite the physical substructure and sensors instrument it. The transfer system comprises the controller, servo-valve, and actuator hydraulics. It enforces interface compatibility and equilibrium by synchronizing the physical response with the numerically computed response. Figure 1 shows a typical RTHS scheme in which the numerical substructure receives ground acceleration $a_g(t)$ and computes the desired displacement $d_d$. The physical substructure provides the measured force $f_e$. Figure 2 gives a closer view of the transfer system. Seismic excitation is used here as an illustration. The proposed framework also applies to other external excitations such as wind loading by changing the corresponding input to the numerical substructure.

Output path: `C:\Users\Victus\Desktop\folder_working\a purdue\aa reasearch\Gaurav Setup\ColumnSetup_gaurav\writing\writing_trials\runs\v2_system_01\response.md`
