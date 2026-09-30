# Paper 2 — Context

This file is the single working context for Paper 2: what the paper is about, the system it describes, its notation, and its wording rules. Write every sentence by [writing_guide.md](writing_guide.md). Paper 1 background and vocabulary are in [paper1.md](paper1.md).

## Current status

- **Working title:** TBD
- **Target journal:** TBD
- **Status:** Planning
- **Last updated:** 2026-09-30
- **Manuscript:** `writing/manuscript2_journal.html` (built by `writing/.agent/build_manuscript2_journal.py`) and `writing/manuscript2.docx`

## Central contribution

TBD. State the paper's main contribution in one or two precise sentences.

## Research question and scope

- **Research question:** TBD
- **Specific objectives:** TBD
- **In scope:** TBD
- **Out of scope:** TBD

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

**Paper 2's current formulation:**
- It estimates the loop directly from the measured u and y at each frequency, with no stiffness estimate.
- Its current NCF formulation retains separate plant $H(s,k)$ and scaled outer controller $\lambda C(s)$. Do not describe it as $P=L$ with $K=1$ or claim a capped margin. Check the current equations before explaining differences from [2].
- It replaces controller switching with a continuous adaptive factor λ.

## Terminology and notation

Use the project-level RTHS notation in the repository instructions unless this paper explicitly establishes a different convention.

- `λ` is the dimensionless adaptive factor that scales the controller output.
- `γ_n²(ω)` is the magnitude-squared coherence used in the estimator confidence.
- Evidence sources: direct identification b_id, output-power inference b_pow, and prior identification of the initial state b_0.

## Technical accuracy

- Use only established terms: hybrid simulation, numerical substructure loop, outer controller loop, inner loop, transfer system, specimen. Never invent names such as "hybrid loop".
- State causes correctly. Degradation does not "act on" anything. The specimen degrades, its stiffness decreases, and the dynamics of the outer controller loop change.
- Before introducing a method, quantity, setting, or equation, establish why it is needed if the reader cannot already infer that need. Let the reason lead into the specific quantities or operations used, and keep the explanation within what the subsection delivers.
- Check every technical statement against Paper 1 and the code in main/ before writing it. If unsure, ask rather than guess.

## Paper 2 wording

- Never use semicolons, in the paper or in these guides.
- Use "hybrid simulation", "experiment", and "initial". Call λ the "adaptive factor".
- Spell out "Figure N". Name each evidence source and its symbol when introduced.
- Link the estimator to the adaptive controller when explaining the framework. Present each designed component through its purpose.
- Avoid "describe", "It should be noted", and "Moreover" before a major idea. Keep references concrete and preserve wording the author has approved unless it needs correction.

## Editing the manuscript HTML

Before editing a manuscript HTML file, search it for `<meta name="review-workflow" content="enabled">`.
- If the flag is present, follow [REVIEW_WORKFLOW.md](../.agent/REVIEW_WORKFLOW.md) for versions, comments and the user's saved and unsaved edits.
- If it is missing or not "enabled", tell the user that this HTML file may not have a versions workflow, and ask before editing.

## Manuscript outline

1. Introduction — TBD
2. Problem formulation / methods — TBD
3. Results — TBD
4. Discussion — TBD
5. Conclusions — TBD

## Claims and evidence

For each important claim, record the supporting result, figure, table, source file, or citation. Do not promote an interpretation to a conclusion until its evidence is identified.

| Claim | Evidence | Source / location | Status |
| --- | --- | --- | --- |
| TBD | TBD | TBD | Open |

## Planned figures and tables

Record the purpose of each figure or table, not just its filename.

| Item | Purpose | Evidence / source | Status |
| --- | --- | --- | --- |
| TBD | TBD | TBD | Open |

## Open decisions and next actions

- TBD

## Limitations and provenance notes

- Keep computational truth in the relevant files under `main/`.
- Link paper claims to reproducible analysis, saved results, or source literature whenever possible.
- Record assumptions, exclusions, and unresolved limitations rather than silently filling them in.

## Revision log

| Date | Change | Reason |
| --- | --- | --- |
| 2026-09-21 | Created Paper 2 context file | Initial setup |
| 2026-09-21 | Set the simplified SOL-OSI page as the primary HTML | Clarified the default page |
| 2026-09-22 | Reserved `λ` for the adaptive factor and `γ²` for coherence | Avoided a notation conflict between controller adaptation and estimator confidence |
| 2026-09-30 | Merged writing.md into this file and renamed it from journal_paper.md | One Paper 2 context file |
