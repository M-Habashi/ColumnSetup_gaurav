## Purpose

This paragraph gives the physical mechanism, suggested by laboratory observations, for the degradation-induced gain amplification identified in Figures 4 and 5, and states that this mechanism is not universal.

## Sequence

- Link the gain amplification in the preceding paragraph to a mechanism suggested by laboratory observations.
- State that the controller was initially tuned against the relatively high specimen stiffness to meet the required tracking performance.
- Explain why stiffness degradation combined with an unchanged corrective control action is likely to produce overshoot and response amplification, and note that specimen mass also plays a role.
- State that the interaction between the degraded specimen and the transfer system can eventually lead to instability.
- Qualify that the dominant instability mechanism and indicator performance depend on the transfer-system and specimen dynamics, which leads into the study aims.

## First draft

Laboratory observations suggest a physical explanation for this gain amplification mechanism. The controller is initially tuned to overcome the relatively high stiffness of the specimen and to achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move. Maintaining the same corrective control action is therefore likely to produce more overshoot and a larger displacement response relative to the initial stiffness condition. The extent of this response amplification is also influenced by the specimen mass. As degradation progresses, the interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. This behavior is not universal, however. The dominant instability mechanism and the performance of stability indicators can vary substantially with both the transfer-system and specimen dynamics.

## Review

- **Idea mapping.** Each required idea appears in the draft:
  - "Laboratory observations suggest" appears in sentence 1. It presents the mechanism as suggested, not validated.
  - Initial tuning appears in sentence 2.
  - The effect of stiffness loss appears in sentences 3–4. "Is likely to" and "relative to the initial stiffness condition" are kept.
  - Specimen mass appears in sentence 5. No direction of influence is given.
  - The path to instability appears in sentence 6. "Can eventually" is kept.
  - The non-universality qualification appears in sentences 7–8. "Substantially" and "both" are kept.
- **Unsupported addition.** Sentence 6 opened with "As degradation progresses." This duplicated "eventually" and added a clause, so I deleted it.
- **Terminology.** I replaced "As the specimen loses stiffness" with the dictionary term "Stiffness degradation," which gives a direct subject–action sentence. "Corrective control action," "displacement response," "response amplification," "transfer system," and "stability indicators" match the dictionary.
- **Unresolved ambiguity.** The notes say only "the controller." The preceding paragraph points to the outer controller loop. However, the packet does not confirm that the retuned or tuned controller is the outer loop controller. I therefore kept "the controller" rather than add that claim. The author should confirm whether it should read "outer loop controller."
- **Neighbor check.**
  - The first sentence builds on "gain amplification" from the previous paragraph without repeating the Figure 4 and Figure 5 interpretation. I changed "this gain amplification mechanism" to "the gain amplification observed in these results" to make the link to the figures explicit.
  - The last sentence leads into the next paragraph's aim of an indicator robust to "different instability mechanisms" without anticipating its content.
- **Sentence length.** I merged sentences 4 and 5 by linking the specimen-mass point to the response amplification. This keeps the qualification attached and reduces short fragments.
- **Word order.** I moved "however" to the front of sentence 7 so the contrast is clear on first reading.
- **Comma counts in the first draft.** The counts were 0, 0, 0, 0, 0, 3, 1, 0. Sentence 6 had three commas, which I resolved by deleting the introductory clause.

**Comma counts in the final paragraph:**

| Sentence | Commas |
| --- | --- |
| 1 | 0 |
| 2 | 0 |
| 3 | 0 |
| 4 | 0 |
| 5 | 0 |
| 6 | 2 |
| 7 | 1 |
| 8 | 0 |

## Final paragraph

Laboratory observations suggest a physical explanation for the gain amplification observed in these results. The controller is initially tuned to overcome the relatively high stiffness of the specimen and to achieve the required tracking performance. Stiffness degradation makes the specimen easier to move. Maintaining the same corrective control action is therefore likely to produce more overshoot and a larger displacement response relative to the initial stiffness condition. The specimen mass also influences the extent of this response amplification. The interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. However, this behavior is not universal. The dominant instability mechanism and the performance of stability indicators can vary substantially with both the transfer-system and specimen dynamics.