# Paper 1 writing trials

## Purpose and source

Test whether a short writing workflow and source vocabulary help fresh agents reconstruct an engineering paragraph from its ideas and surrounding context.
Do not score verbatim similarity. The original supplies meaning and qualifications. The user's preferences govern sentence style.

Source DOCX: C:/Users/Victus/Desktop/folder_working/a purdue/aa reasearch/aab paper1/writing/submit/Paper Submit 02/SCHM_Main_Manuscript_Rev1.docx
SHA256: 795C6C7816326820A49ED0C1BE1C63C1F828DAFADED80F7E632E91E35ACBBCB1
Read-only XML extraction includes visible Word and math text. Deleted revision text is excluded. Mathematical formatting is flattened. Selected target paragraphs are prose without formulas.

Primary case: direct body paragraph 56. Adjacent paragraphs: 55 and 57.
Transfer case reserved before trials: direct body paragraph 52. Adjacent paragraphs: 51 and 53.

## Isolation and reproducibility

- Every writing trial uses a newly spawned agent with fork_turns="none".
- No writer is reused through followup_task. No writer gets conversation history or earlier drafts or feedback.
- Each writer reads only its own packet. The packet contains the frozen guide and dictionary along with fixed ideas and neighboring paragraphs. The target paragraph is withheld.
- All writers within a round receive identical substantive inputs. Only identifiers and output paths differ.
- Writers return their first draft, concrete review, and final paragraph. These are recorded separately so review effectiveness can be inspected.
- Evaluators see the original and candidates. They do not write candidate paragraphs. Each evaluation uses a new agent without conversation history.
- File access is restricted by instruction and observable tool calls, not by a separate filesystem sandbox. This cannot rule out prior model knowledge of published text.
- Freeze a guide version before generating each round. Save every trial, including weak drafts.

## Fixed engineering checks for paragraph 56

1. Laboratory observations motivate the explanation. Do not portray the study's virtual demonstration as an experimental validation campaign.
2. Initial controller tuning addresses relatively high specimen stiffness and required tracking performance.
3. Stiffness loss makes the specimen easier to move. The same corrective action is likely to overshoot more and increase displacement relative to the initial condition.
4. Specimen mass influences the extent of amplification. No direction or quantitative law is supplied here.
5. Interaction between the degraded specimen and transfer system including its controller can eventually lead toward instability.
6. The behavior is not universal. The dominant instability mechanism and indicator performance depend on both transfer-system and specimen dynamics.

## Rating fixed before trials

Each dimension receives 0, 1, or 2. Quote a specific defect for every deduction.

| Dimension | 2 | 1 | 0 |
| --- | --- | --- | --- |
| Completeness | All six engineering points retained | One point weakened or partly missing | Major point or multiple points lost |
| Fidelity | Causality and qualifications preserved with no added claim | One ambiguous relation or slightly stronger assertion | Unsupported technical mechanism or material change of meaning |
| Context and sequence | Clear progression from previous paragraph through explanation to next | Local repetition or weak transition | Misplaced purpose or broken reasoning |
| Terminology | Established precise expressions with clear referents | One vague label or unnecessary synonym | Misnamed physical or control concept |
| Readability | Clear connected sentences without crowded clauses | One awkward sentence or overloaded sentence | Repeated difficult or comma-heavy sentences |

Acceptance for a draft: at least 9/10 with completeness=2 and fidelity=2, no semicolon or "whose", and no unresolved sentence with three or more prose commas. Mathematical commas do not count. A comma flag requires rewriting or a specific documented readability justification rather than arbitrary deletion.
Three accepted fresh primary-case drafts are required for a version to be called promising on that case.
Then test at least two fresh drafts on the reserved transfer case. If a material defect remains, revise and repeat the affected case with fresh agents.
These are small local trials. Passing does not prove general writing quality or user approval.

## Planned comparison

Round 1: initial guide and dictionary, three independent writers.
Round 2 and later: revise only in response to observed defects, then repeat the same primary packet with three fresh writers.
Reserve the transfer case until the guide is provisionally stable. Record all changes to the packet or guide so improvements are not attributed solely to instructions when inputs changed.

## Recorded decisions after round 1

The independent reviewer scored all three initial drafts 10/10. It justified the one three-comma sentence as readable under the original rubric's exception. The root editor retained that positive meaning assessment but found the sentence insufficiently aligned with the user's punctuation preference.
Version 2 therefore makes rewriting sentences with at least three prose commas a drafting requirement. Report literal comma compliance separately across all versions. Do not claim an improvement from a failed semantic score when the initial semantic scores passed.
The version 2 guide also requires a sentence-to-idea mapping and specific review findings after the baseline self-review missed the punctuation issue.

An additional exploratory stress case was selected after round 1: direct body paragraph 22 introduces the system and includes component inventories and figure references. It tests a different difficulty from the mechanism paragraph. The previous prose paragraph is 20. Section heading 21 precedes the target. The next prose paragraph is 27 after the two figure captions. This case was not reserved before the first trial. It receives the frozen version 2 guide and dictionary with no tuning to its target text.

## Recorded decisions after the system stress case

Both version 2 system writers repeated "sensors instrument it" from the root editor's input bullet. This is an input-quality failure propagated into prose. The actual source uses "instrumented with sensors".
Version 3 adds an actor/action check and explicitly treats input bullets as content notes. Dictionary version 2 adds scientific verb phrases with physical roles. The original system bullet is deliberately retained for the repeat so an input improvement is not confounded with the guide and dictionary change.
The system repeat is now a development case rather than an unseen holdout. The exact phrase "instrumented with sensors" is supplied as a source-derived dictionary expression after the defect was observed. Success on that phrase alone is therefore not evidence of generalization.
Repeat the primary case with three fresh version 3 writers to check that the added language guidance does not weaken the original mechanism explanation. Repeat the system case with two fresh version 3 writers to test the observed defect.

A separate fresh evaluator receives an unmodified primary draft plus three controlled mutations. The mutations introduce an unsupported direction of the mass effect, an invented name for the transfer system, and a universal claim that contradicts the source caveat. Keep the mutation key hidden from the evaluator. These are reviewer sensitivity checks, not writer trials or independent source validation.

The first sensitivity review rejected the mass and universality errors. It flagged the invented technical name but accepted the draft at 9/10 because the original acceptance rule did not require terminology=2. Before starting any version 3 writers, the version 3 guide and packets were finalized with a noncompensable acceptance requirement for terminology and meaning. Version 3 evaluation requires completeness=fidelity=terminology=2 and no sentence with at least three prose commas. Earlier scores and decisions remain recorded under their original rules.
The sensitivity test is repeated with the stronger gate and a new reviewer. Keep both reviews. Do not report the changed decisions as an improvement in the generated prose.
