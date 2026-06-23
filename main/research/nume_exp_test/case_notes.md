# Numerical-Experimental Case Notes

This folder documents and tests three numerical-substructure choices while
keeping the experimental substructure constant:

- Experimental substructure: 40 in W8x28 physical column represented only by
  the scalar restoring relation `F_exp = k*x`.
- Specimen source: `saved_results/specimens/sp_1_or.mat`.
- Earthquake input for the comparison script: El Centro 1940.
- SAP is not used for this research task.

## Case 1

- Only floor translations are active.
- Floor and base rotations are prevented.
- The edge-column inflection point is fixed at mid-height.
- Reference story height is `80 in`, so the 40 in experimental
  substructure reaches the known mid-column inflection point.

## Case 2

- Floor translations are the active dynamic DOFs.
- Base flexibility is represented with calibrated rotational springs.
- Floor joint rotations remain restrained.
- The numerical cut at 40 in has a released internal rotation, so the
  numerical upper column enforces zero moment at the interface while the
  experimental part still transfers only `F_exp = k*x`.
- The reference story height is adjusted so the first-mode edge-column
  inflection point is at 40 in.

## Case 3

- This follows the current `vHS` modeling idea.
- Frame joint and base rotations are assembled explicitly as massless
  internal DOFs.
- The reference model therefore contains 3 floor translations plus
  rotation DOFs before static condensation for time integration.
- The reference story height is adjusted so the first-mode edge-column
  inflection point is at 40 in.
- The height choice is first-mode optimized; higher modes are not forced to
  have their inflection point at the 40 in interface.

## Later Figure Requirements

- Show three bays and three floors in every case.
- Mark only the three floor translation responses as `u_1`, `u_2`, `u_3`.
- Show the experimental column height as 40 in from base to interface.
- For Case 1, show fixed rotations and the 80 in first-story height.
- For Case 2, show base rotational springs and the adjusted story height.
- For Case 3, show frame joint rotations and the adjusted story height.
