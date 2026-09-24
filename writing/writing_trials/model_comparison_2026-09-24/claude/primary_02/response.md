## Purpose

This paragraph explains the physical mechanism that laboratory observations suggest for degradation-driven instability, and notes that the behavior is not universal.

## Sequence

- Link the gain-amplification trend in the previous paragraph to a mechanism suggested by laboratory observations. Do not claim experimental validation.
- State that the controller is tuned for the relatively high initial specimen stiffness and the required tracking performance.
- Explain that stiffness loss makes the specimen easier to move, so the unchanged corrective control action is likely to amplify the response. Note that specimen mass affects the extent of the amplification.
- State that the interaction between the degraded specimen and the transfer system can eventually drive the system toward instability.
- Qualify the behavior as system-dependent. This sets up the next paragraph's focus on different instability mechanisms.

## First draft

Laboratory observations suggest a physical explanation for this behavior. The controller is initially tuned to overcome the relatively high stiffness of the specimen and to achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move, and the same corrective control action is likely to cause more overshoot and a larger displacement response than under the initial stiffness condition. The specimen mass also influences the extent of this response amplification. With continued degradation, the interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. However, this behavior is not universal, as the dominant instability mechanism and the performance of the stability indicators can vary substantially with both the transfer-system and specimen dynamics.

## Review

- **Idea mapping:**
  - Laboratory observations suggesting a mechanism → S1.
  - Initial tuning for high stiffness and tracking performance → S2.
  - Stiffness loss makes the specimen easier to move → S3.
  - Unchanged corrective action is likely to cause more overshoot and a larger displacement response → S4.
  - Mass influences the amplification with no direction stated → S5.
  - Interaction can eventually drive the system toward instability → S6.
  - The behavior is not universal and varies with transfer-system and specimen dynamics → S7–S8.
  - No idea was omitted. "Suggest", "is likely to", "can eventually", and "can vary substantially" are all retained.
- **S1 referent:** "this behavior" was ambiguous after the previous paragraph's final sentence about Figure 5. I changed it to "this degradation-driven instability", which reuses the previous paragraph's "instability triggered by the degradation". "Suggest" is kept so the sentence does not claim experimental validation.
- **Draft S3 split:** Draft S3 combined two ideas. It also said "the same corrective control action" without stating that the action is kept unchanged, which the notes require. I split it into a short causal sentence and a conditional sentence: "If the corrective control action remains unchanged…". The "is likely to" qualification stays attached to the consequence.
- **Draft S5 removal:** Draft S5 had three commas. Its opening "With continued degradation" added a progression not stated in the notes and repeated "degraded". I removed it. "Including the controller" is kept because the notes place the controller within the transfer system.
- **Final S2 wording:** "initially tuned … initial stiffness" would repeat "initial", so S2 uses "relatively high specimen stiffness". S4 keeps the dictionary term "initial stiffness condition".
- **Draft S6 split:** Draft S6 ("not universal, as …") was split so that the variability statement stands alone. I changed "the stability indicators" to "stability indicators" because the claim applies generally and not only to τcr,N, τcr,P, and GMP. The final sentence now leads into the next paragraph's "different instability mechanisms".
- **Unsupported claims:** I added no direction for the mass effect, did not name the controller as the outer loop controller, and made no claim about Paper 2.
- **Final prose-comma counts:** S1 0, S2 0, S3 1, S4 1, S5 0, S6 2, S7 1, S8 0. No sentence has three or more.

## Final paragraph

Laboratory observations suggest a physical mechanism for this degradation-driven instability. The controller is initially tuned to overcome the relatively high specimen stiffness and to achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move. If the corrective control action remains unchanged, it is likely to cause more overshoot and a larger displacement response than under the initial stiffness condition. The specimen mass also influences the extent of this response amplification. The interaction between the degraded specimen and the transfer system, including the controller, can eventually drive the system toward instability. However, this behavior is not universal. The dominant instability mechanism and the performance of stability indicators can vary substantially with both transfer-system and specimen dynamics.