## Purpose

This paragraph gives the physical mechanism that laboratory observations suggest for degradation-driven instability, and it states that the mechanism is not universal, which motivates the stability indicator in the next paragraph.

## Sequence

- Link to the preceding paragraph's gain-amplification trend by stating that laboratory observations suggest a physical mechanism, without claiming experimental validation.
- State the initial condition: the controller is tuned against the relatively high initial specimen stiffness to meet the required tracking performance.
- Give the cause and its consequence: loss of stiffness makes the specimen easier to move, so the same corrective control action is likely to produce more overshoot and a larger displacement response.
- Note that specimen mass influences the extent of amplification, without giving a direction, and that the interaction with the transfer system and controller can eventually lead to instability.
- Qualify the scope: the dominant mechanism and indicator performance vary with transfer-system and specimen dynamics, which sets up the need for an online indicator.

## First draft

Laboratory observations suggest a physical explanation for this gain amplification. The controller is initially tuned to overcome the relatively high stiffness of the specimen and to achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move. If the same corrective control action is retained, it is likely to cause more overshoot and a larger displacement response than under the initial stiffness condition. The specimen mass also influences the extent of this response amplification. The interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. This behavior is not universal, however, because the dominant instability mechanism and the performance of stability indicators can vary substantially with both transfer-system and specimen dynamics.

## Review

- **Idea mapping.**
  - Laboratory-observation mechanism → S1.
  - Initial tuning against high stiffness for tracking performance → S2.
  - Stiffness loss makes the specimen easier to move → S3.
  - Same corrective action is likely to cause more overshoot and larger displacement relative to the initial stiffness condition → S4. "Is likely to" is kept.
  - Mass influences the extent of amplification with no direction → S5. No direction or dependence is added.
  - Interaction with the transfer system including the controller can eventually drive toward instability → S6. "Can eventually" is kept.
  - Non-universality, with "can vary substantially" for both the mechanism and indicator performance and for both transfer-system and specimen dynamics → S7.
  - No idea is omitted.
- **Unsupported link removed.** S1 of the draft stated that laboratory observations explain "this gain amplification." The packet supports a mechanism suggested by observations. It does not support a claim that the observations explain the Figure 4/5 gain-margin trend. I changed S1 to "a physical mechanism behind this behavior." This keeps the connection to the preceding paragraph's discussion of degradation-driven instability without overclaiming.
- **No validation claim.** "Suggest" is used and nothing implies that the paper experimentally validated an indicator or intervention.
- **Neighbor check.**
  - The first sentence connects to the preceding paragraph's closing point about outer-loop dynamics leading to instability. It does not repeat the Figure 5 description.
  - The last sentence sets up the next paragraph's aim of an indicator robust against "different instability mechanisms."
  - Nothing from the next paragraph is anticipated or repeated.
  - No lambda, Paper 2 terminology, or controller switching is introduced.
- **Terminology.**
  - "Corrective control action," "displacement response," "initial stiffness condition," "response amplification," "transfer system," "tracking performance," "instability mechanism," and "stability indicator" all follow the dictionary.
  - I kept "the controller" rather than specifying "outer loop controller" because the notes do not name which controller is tuned.
  - "The controller is initially tuned" keeps the passive voice because the controller receives the tuning.
- **Referent issue.** In S6, "the transfer system ... drive the system" makes the second "system" slightly ambiguous. I kept "the system" because the next paragraph uses "the system's robustness" in the same sense, and naming it "RTHS" would add a specification that the notes did not give. This is a possible optional refinement for the author.
- **Flow edit.** S7 in the draft used a mid-sentence "however" and a "because" clause, which made the sentence 29 words long with 2 commas. I split it so that "However, this behavior is not universal" stands as a short turning point and the variation statement follows as its own sentence. The qualification "can vary substantially" stays attached to both the mechanism and the indicator performance. I also added "the" before "transfer-system and specimen dynamics" so the phrase reads more easily.
- **Prose-comma counts (final).** S1: 0. S2: 0. S3: 1. S4: 1. S5: 0. S6: 2. S7: 1. S8: 0. No sentence has three or more.
- **Style checks.** There are no semicolons and no "whose." Sentence lengths range from 6 to 26 words.

## Final paragraph

Laboratory observations suggest a physical mechanism behind this behavior. The controller is initially tuned to overcome the relatively high stiffness of the specimen and to achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move. If the same corrective control action is retained, it is likely to cause more overshoot and a larger displacement response than under the initial stiffness condition. The specimen mass also influences the extent of this response amplification. The interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. However, this behavior is not universal. The dominant instability mechanism and the performance of stability indicators can vary substantially with both the transfer-system and specimen dynamics.