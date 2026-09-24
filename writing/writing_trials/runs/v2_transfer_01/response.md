# Purpose

Explain why a short-window linear approximation is used for evolving structural degradation and identify the conditions under which it is typically accurate.

# Sequence

- The preceding paragraph establishes the stiffness-degradation model and explains its damping assumption.
- Sentence 1 introduces nonlinear, time-varying degradation and the approximation used for tractable online analysis.
- Sentences 2 and 3 distinguish possible inaccuracy during rapid property changes from typical accuracy before and after these events and during slow degradation.
- The next paragraph needs this rationale before applying stability indicators to progressively degraded models in vRTHS.

# First draft

Although structural degradation is nonlinear and time varying, a short-window linear approximation keeps the analysis tractable and suitable for online evaluation. The approximation may be inaccurate during brief intervals of rapid property change. It is typically accurate before and after these events and during slowly evolving degradation.

# Review

- Rereading both neighboring paragraphs and the draft showed no need for revision. The final paragraph retains the first draft.
- Sentence 1 covers the nonlinear and time-varying nature of degradation and the approximation's purpose: tractable analysis suitable for online evaluation.
- Sentence 2 preserves possible inaccuracy during brief intervals of rapid property change. Sentence 3 preserves typical accuracy before and after those events and during slowly evolving degradation. Neither statement guarantees accuracy.
- The opening extends the preceding model discussion without repeating its damping argument. The ending establishes the approximation's accuracy qualification before the next paragraph introduces the vRTHS stability analysis.
- “The approximation” and “It” refer to the short-window linear approximation. “These events” refers to the rapid property changes in sentence 2. No algorithms, estimation methods, sampling choices, experimental evidence, or unsupported causal claims were added.
- Final sentence prose-comma counts are 1, 0, and 0. No sentence has three or more commas. The paragraph contains no semicolons or “whose.”

# Final paragraph

Although structural degradation is nonlinear and time varying, a short-window linear approximation keeps the analysis tractable and suitable for online evaluation. The approximation may be inaccurate during brief intervals of rapid property change. It is typically accurate before and after these events and during slowly evolving degradation.
