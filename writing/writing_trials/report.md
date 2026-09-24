# Writing workflow trial report

Date: 2026-09-24

## Outcome

The trials produced a usable writing workflow and a source-based expression dictionary. They also showed that a favorable agent review is insufficient evidence of good prose. Two concrete language defects survived positive reviews and required more specific checks.

The resulting files are [write.md](../write.md) and [scientific_expressions.md](../scientific_expressions.md). The existing [writing.md](../writing.md) links to them and retains the Paper 2 context. No manuscript paragraph was replaced by these trials.

Fifteen fresh writer agents generated drafts across three guide versions and three Paper 1 passages. Every writer received only a frozen task packet containing the guide, dictionary, engineering ideas, and neighboring paragraphs. The actual target paragraph was withheld. Every evaluation also used a fresh agent. No trial agent received previous trial history or feedback.

## What was tested

The source is the author's Paper 1 manuscript SCHM_Main_Manuscript_Rev1.docx. Its exact path and SHA256 are recorded in [protocol.md](protocol.md). Paragraph identifiers refer to direct DOCX body paragraphs rather than page numbers. The source was extracted read-only. Mathematical formatting is flattened in the extraction, so these trials focus on prose.

| Case | Source paragraph | Purpose | Trials |
| --- | ---: | --- | ---: |
| Primary | 56 | Explain amplification after stiffness loss and preserve the nonuniversal scope | 3 each with v1, v2, and v3 |
| Transfer | 52 | Explain a short-window approximation and qualify its accuracy | 2 with v2 |
| System | 22 | Introduce components, signal roles, figures, and excitation scope | 2 each with v2 and v3 |

The transfer case was reserved before the first trial. The system case was added afterward as an exploratory stress test. Once the system case informed v3, its repeat was a development test rather than an unseen holdout.

The fixed facts and neighboring paragraphs remained identical within each case across versions. The input verification script found one distinct set of facts and neighbors per case. Every packet matched its saved guide and dictionary snapshots. The full target paragraph did not appear in any writer packet. These checks are recorded in [mechanical_summary.json](mechanical_summary.json).

The writers had access to the same shared filesystem but were instructed to read only their own packets. This is context isolation through fresh agents and restricted task instructions, not an independent filesystem sandbox. The agents used the inherited model and reasoning settings. Fresh contexts do not make them independent model families or rule out prior training exposure to published material.

## Changes driven by observed failures

| Observation | Diagnosis | Change | Repeat result |
| --- | --- | --- | --- |
| v1_primary_03 retained a sentence with three commas while claiming its punctuation was fine | A general self-review statement did not verify the final text | v2 required final sentence comma counts and specific repairs | All three v2 primary drafts had at most two commas per sentence |
| v2_system_01 and v2_system_02 wrote "sensors instrument it" | An awkward input bullet was copied into prose. The preference for active voice was insufficiently qualified | v3 treated bullets as facts to interpret and added an actor/action check. The dictionary added source-based verb phrases | Both v3 system drafts used natural passive instrumentation wording while receiving the same original bullet |
| A reviewer flagged an invented technical name but accepted the draft at 9/10 | A summed score allowed a terminology defect to be offset by other strengths | v3 required full fidelity, completeness, and terminology scores before acceptance | A fresh reviewer rejected all three deliberately flawed controls and accepted the unchanged control |

The v3 dictionary explicitly includes the source phrase "instrumented with sensors". The improvement on that wording is therefore a targeted correction with supplied vocabulary. It is not proof that the agent can discover every awkward scientific expression unaided.

The previous Paper 2 instruction to repeat all four transfer-system elements every time the term is named was also clarified. The full definition must remain accurate, but it may span clear sentences and does not need repeating at every mention.

## Comparison with the actual primary paragraph

The actual paragraph states:

> Based on our observations in the laboratory, this instability is caused by the controller being initially tuned to both overcome the specimen's relatively high stiffness and also achieve the required tracking performance. As the specimen degrades and loses stiffness, it becomes easier to move, so the same corrective control action is likely to overshoot more and produce a larger displacement response than under the original stiffness condition. The extent of this response amplification is influenced by the specimen mass, and the resulting interaction between the degraded specimen and the transfer system, which includes this controller, can eventually drive the system toward instability. It's important to note that, despite being observed experimentally, these behaviors are not universal, as the dominant instability mechanism and the performance of each indicator can change substantially depending on the specific dynamics of the transfer system and the physical substructure.

One final candidate, [v3_primary_02](runs/v3_primary_02/response.md), reads:

> Laboratory observations suggest that stiffness degradation changes how the specimen responds to corrective control action. The controller is initially tuned to overcome the relatively high specimen stiffness and achieve the required tracking performance. As the specimen loses stiffness, it becomes easier to move under the same corrective control action. This action is therefore likely to produce greater overshoot and a larger displacement response than under the initial stiffness condition. Specimen mass also influences the extent of this response amplification. Interaction between the degraded specimen and the transfer system, including its controller, can eventually drive the system toward instability. This behavior is not universal. The dominant instability mechanism and stability indicator performance can vary substantially with the dynamics of both the transfer system and the specimen.

| Source meaning | Candidate evidence | Assessment |
| --- | --- | --- |
| Laboratory observations motivate the explanation | Sentence 1 attributes the interpretation to laboratory observations | Retained with cautious wording |
| Initial tuning addresses stiffness and tracking | Sentence 2 states both objectives | Retained |
| The same corrective action can amplify motion after stiffness loss | Sentences 3–4 connect easier motion to likely overshoot and increased displacement relative to the initial condition | Retained with the likelihood qualification |
| Specimen mass affects amplification | Sentence 5 states influence without adding its direction | Retained |
| Interaction with the transfer system including the controller can lead toward instability | Sentence 6 retains the interaction and "can eventually" | Retained |
| Behavior is not universal and depends on both sets of dynamics | Sentences 7–8 retain both the mechanism and indicator-performance caveat | Retained |

This candidate is an example selected for inspection, not an author-approved replacement. It changes wording and sentence count rather than trying to reproduce the source verbatim. The source itself has comma-heavy sentences, so copying its punctuation was not a success criterion.

## What the reviews actually established

The independent reviewers gave every v1 and v2 writer candidate 10/10 under the initial broad rubric. Those scores did not establish that every draft met the author's language preferences. The first review justified the three-comma sentence. The system review did not identify "sensors instrument it" as a defect. The root editor recorded both disagreements instead of rewriting the review history.

All five final v3 drafts satisfy the mechanical checks: fewer than three commas per sentence, no semicolon, and no "whose". The primary drafts preserve the supplied mechanism and qualifications in the root comparison. Both system drafts repair the instrumentation wording without omitting the source's component roles or excitation scope. The final independent reviewers accepted all five at 10/10 under the stronger gate. Those reviews are recorded separately below.

| Group | Fresh writers | Literal comma preference met | Root editorial finding | Independent review |
| --- | ---: | ---: | --- | --- |
| v1 primary | 3 | 2/3 | One punctuation defect remained | [v1 review](evaluation_v1_primary.md) |
| v2 primary | 3 | 3/3 | All six required ideas retained | [v2 primary review](evaluation_v2_primary.md) |
| v2 transfer | 2 | 2/2 | Approximation purpose and all accuracy qualifications retained | [v2 transfer review](evaluation_v2_transfer.md) |
| v2 system | 2 | 2/2 | Both copied the awkward sensor wording | [v2 system review](evaluation_v2_system.md) |
| v3 primary | 3 | 3/3 | Mechanism and qualifications retained | [v3 primary review](evaluation_v3_primary.md) |
| v3 system | 2 | 2/2 | Both repaired the sensor wording | [v3 system review](evaluation_v3_system.md) |

The self-review record is informative in specific places. v2_primary_03 added the controller after finding that its first draft omitted it from the interaction statement. v2_system_01 split a three-comma sentence without losing the transfer-system functions. v3_primary_02 replaced an opening that merely announced an explanation with one stating the physical relationship. The two transfer-case writers made no revisions and explicitly reported that fact. Revision count alone is not a quality measure.

## Reviewer sensitivity check

Four anonymous candidates were evaluated twice by separate fresh reviewers. One was an unchanged valid draft. The other three were controlled mutations prepared by the root editor. The mutation key was withheld from the evaluators.

| Candidate | Controlled change | Original acceptance rule | Stronger acceptance rule |
| --- | --- | --- | --- |
| A | Added a directional law for the influence of specimen mass | Rejected | Rejected |
| B | Unchanged valid candidate | Accepted | Accepted |
| C | Renamed the transfer system "actuation orchestration assembly" | Flagged but accepted at 9/10 | Rejected because terminology must pass fully |
| D | Claimed universal behavior and invariant mechanisms | Rejected | Rejected |

See the [original control review](evaluation_reviewer_controls.md), [stronger-rule control review](evaluation_reviewer_controls_strict.md), and [mutation key](reviewer_controls_key.json). The terminology correction changed the acceptance policy, not the prose. The second result shows sensitivity to these seeded defects. It does not establish reliable detection of all subtle language problems.

## How to use the files

1. Read write.md and scientific_expressions.md together with the relevant paper context. Keep Paper 1 and Paper 2 definitions distinct.
2. Assemble a short task packet containing the intended engineering points and the previous and next paragraphs. Include the required qualifications and the source for technical statements.
3. Establish the paragraph's purpose and sentence sequence before drafting. Resolve a real ambiguity in the intended message before polishing the prose.
4. Draft and then reread the three paragraphs together. Map the required ideas to the final sentences and inspect technical terms, physical actions, qualifications, and punctuation.
5. Review the actual text. A checklist assertion or high score does not override a concrete defect. User approval is still distinct from passing these checks.

Use the guide and dictionary for ordinary manuscript work. The trial outputs are evidence about this workflow, not a collection of author-approved style exemplars. No further multi-agent trial is required for every paragraph.

To reproduce a trial, use prepare_trial.ps1 from the project's main folder and then spawn a new agent with fork_turns="none" for each packet. Do not use followup_task for a new trial. prepare_evaluation.ps1 builds separate reference-containing packets for fresh evaluators. summarize_trials.ps1 checks final text and input consistency. A new guide change needs a new version name so old snapshots remain intact.

## Limits and stopping decision

The final workflow is ready for supervised manuscript use. These small local trials do not guarantee universally natural writing or establish superiority over other models. The same model family supplied the writers and evaluators. The root editor also made subjective language judgments. The final v3 guide was retested on two development cases. The untouched transfer case was tested with v2, not v3.

The study did not separately isolate the effect of the dictionary, neighboring paragraphs, or self-review. Therefore no individual component can be credited with a measured general improvement. The demonstrated changes are narrower: fewer comma violations, correction of a repeated input-derived phrase, preservation of the checked source meanings, and rejection of specified terminology defects under the revised acceptance rule.

Further iteration should respond to a new observed defect or an author judgment on real manuscript prose. Repeating the same cases after these checks pass would provide diminishing evidence and could overfit the guide to the examples.

All writer packets and responses remain under runs/. Frozen instructions are under versions/. The [agent manifest](agent_runs.json) records fresh task identities. The reference extraction remains in [paper1_paragraphs.json](paper1_paragraphs.json).
