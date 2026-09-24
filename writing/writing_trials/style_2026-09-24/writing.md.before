# Writing guide (Paper 2)

Use [write.md](write.md) for the drafting and review workflow and [scientific_expressions.md](scientific_expressions.md) for source-based terminology. This file supplies Paper 2 context and conventions. For sentence style and review acceptance, follow the current workflow in write.md.

Follow this for every sentence written for the paper. Never use semicolons, in the paper or in this file.
Paper 1 is Gomaa et al., cited as [2]. Its manuscript is `aab paper1/writing/submit/Paper Submit 02/SCHM_Main_Manuscript_Rev1.docx`.

## Versions workflow check
Before editing a manuscript HTML file, search it for `<meta name="review-workflow" content="enabled">`.
- If the flag is present, follow [REVIEW_WORKFLOW.md](REVIEW_WORKFLOW.md) for versions, comments and the user's saved and unsaved edits.
- If it is missing or not "enabled", tell the user that this HTML file may not have a versions workflow, and ask before editing.

## The system (learn this before writing)
**Hybrid simulation** splits a reference structure into two substructures:
- the **numerical substructure**, computed in real time and driven by the ground acceleration and the measured force
- the **physical substructure**, which is the specimen

The **transfer system** enforces compatibility and equilibrium at their interface by making the specimen follow the numerically computed response.

Blocks, and what each one does:
- **Numerical substructure**: computes the desired displacement d(t) from the ground acceleration and the measured force f_m(t).
- **Phase-lead compensator**: advances d(t) to give the reference u(t). It is designed to offset the transfer-system lag and improve tracking. It acts on the reference, outside the outer controller loop.
- **Outer controller C(s)**: user-designed and run on the real-time computer. It acts on the tracking error u − y and produces the command v(t) to the inner loop. In Paper 2 its output is scaled by the adaptive factor λ.
- **Plant H(s,k)** (Paper 1 calls it T): the transfer system plus the specimen, from command v(t) to measured actuator displacement y(t). In Paper 2, the **transfer system** means the inner-loop controller (the hardware PID), servo-valve, actuator and control–structure interaction. Account for all four when defining the transfer system. Explain them across clear sentences if needed. Do not repeat the inventory every time the term appears.
  - The servo-valve regulates the oil flow into the actuator.
  - The actuator converts hydraulic power into the displacement imposed on the specimen.
  - Control–structure interaction is the physical coupling between the actuator and the specimen, which makes the plant depend on the specimen dynamics.

Two loops:
1. **The numerical substructure loop** runs from the numerical substructure through the transfer system and specimen, and returns through the measured force f_m.
2. **The outer controller loop** runs from u to y: L = λ C H, with unity feedback.

Delay-based indicators assess only the first loop. Paper 1 showed that degradation threatens the **outer controller loop**, which those indicators miss.

**Why degradation causes instability** (Paper 1):
1. The outer controller is tuned to overcome the initial stiffness and to meet the tracking target.
2. When the specimen degrades, its stiffness decreases and it becomes easier to move.
3. The same control action then overshoots, and the response is amplified.
4. The dynamics of the outer controller loop change, and its stability margin shrinks.

This is a **gain amplification** mechanism, not a time delay. Flexible specimens (higher mass, lower stiffness-to-mass ratio) are more susceptible.

**Paper 1's indicator** is the NCF margin, b_g(C_out, T).
- It splits the loop into the outer controller C_out and the plant T.
- Its value is at most the scaled margin b_s(L).
- b ≥ 0.4 guarantees the usual gain- and phase-margin targets and is the practical guideline for experiments.
- It was computed online from a parametric model, updated with a stiffness factor α estimated by least squares from force and displacement.
- It was demonstrated numerically (virtual hybrid simulation of a modified benchmark), not experimentally.
- Intervention was a Lyapunov-guaranteed switch from a high-performance controller to a high-robustness one.

**Paper 2 differs in three ways:**
- It estimates the loop directly from the measured u and y at each frequency, with no stiffness estimate.
- It lumps the whole loop into P = L with K = 1, which is not the C_out/T split of Paper 1. The user approved this. State it in the text as a deliberate difference from [2].
- It replaces controller switching with a continuous adaptive factor λ.

## Technical accuracy
- Use only established terms: hybrid simulation, numerical substructure loop, outer controller loop, inner loop, transfer system, specimen. Never invent names such as "hybrid loop".
- State causes correctly. Degradation does not "act on" anything. The specimen degrades, its stiffness decreases, and the dynamics of the outer controller loop change.
- A reason must be the engineering cause, not bookkeeping. Write "the loop response changes as the specimen degrades, so it is identified from measured signals", not "equation (3) needs it".
- Check every technical statement against Paper 1 and the code in main/ before writing it. If unsure, ask rather than guess.

## Flow
- Give the reason first. Say why the reader needs a figure, equation or step before saying what it shows.
- Build understanding block by block: context → problem → idea → equation → meaning → consequence.
- Link sentences from known to new. Start with what the reader already has, and end with the new point.
- Give each paragraph one message. Open with a topic sentence and close with its consequence or a bridge to the next paragraph.
- Open a section by linking it to the previous one and stating its goal, as Paper 1 does ("The preceding section… This section…").
- Introduce each equation by its purpose ("To derive…", "Substituting… yields"). After it, define the new symbols ("where…") and state what the equation means physically.
- When presenting a system, give each block a one-line role, in signal order.
- Write for the reader, not for the writer. Every sentence gives a fact, a reason or a consequence. No planning notes such as "Before X can be formulated, Y must be defined".
- Present designed components by their purpose ("a phase-lead compensator, designed to improve tracking").
- Keep references concrete: "this ratio", not a bare "this".

## Revise every paragraph
After drafting, check each sentence:
1. What message does it carry?
2. Does the reader need this message? If not, cut it.
3. Is it technically true, and are its terms and causes correct?
4. Is the order step by step for the reader? Reorder, or add the missing step.

Do not over-correct: keep wording the user has approved unless it is wrong.

## Size
- Sentences: 15–25 words on average, rarely above 30. Vary the length. One idea per sentence.
- Paragraphs: one message, 3–6 sentences, about 80–200 words.

## Wording
- Avoid using many commas in the same sentence. Split stacked clauses or parenthetical explanations into separate sentences rather than removing necessary punctuation.
- Make every sentence clear on the first reading. Use direct wording and make the subject and its action explicit.
- Say "hybrid simulation" (never RTHS), "experiment" (not "test"), and "initial" (not "healthy"). λ is the "adaptive factor".
- Never use "whose". Split the sentence instead.
- Avoid "describe", "It should be noted", and "Moreover" before a major idea.
- Spell out "Figure N". Introduce each evidence source with its name and symbol: direct identification b_id, output-power inference b_pow, prior identification of the initial state b_0.
- The adaptive controller is half of the framework. Link the estimator and the controller explicitly.
- Active voice where natural. "We" is acceptable.

## Transitions
- Use smooth transitions between sentences and paragraphs. Carry the preceding idea forward and make its connection to the next idea clear. Choose transition words that express that connection naturally.
- Purpose: To…, For this purpose…, This allows…
- Consequence: As a result…, Therefore…, Consequently…
- Contrast: However…, In contrast…, Yet…
- Sequence: First…, The second…, Finally…
- Back-reference: This ratio…, With these spectra…, Where the confidence is small…

## Sources
- Gopen & Swan, "The Science of Scientific Writing": topic and stress positions, known → new.
- Scientific-writing guides: sentences average about 12–25 words, and paragraphs run 100–200 words with one message each.
