# Writing comparison: Opus 5.5 high and Codex/Astra

For the Paper 2 passage under discussion, Opus produced one draft that all four anonymous reviewers preferred to its paired Astra draft. The other two Paper 2 pairs had no consensus. Across the Paper 1 and Paper 2 cases together, neither model showed a consistent advantage. The practical choice for this particular passage is to use Opus trial 02 as a starting draft and review its opening against the author's purpose.

The test used the frozen version 3 writing guide and version 2 dictionary. They were not changed during the comparison. Eight Opus drafts were compared with eight Astra drafts: three repetitions of the Paper 1 degradation paragraph, two of its system-description paragraph, and three of the current Paper 2 passage. The five Paper 1 Astra drafts were existing trials. The three Paper 2 Astra drafts were newly generated from the same packet used for Opus.

Each writer received the engineering points and neighboring paragraphs. The workflow required a purpose, sentence sequence, first draft, specific review, and final passage. The original Paper 1 paragraphs were withheld from writers and provided to reviewers as authorities for meaning. Paper 2 was evaluated against the supplied facts and neighbors. Every new writer started with no previous trial history. See the [protocol](protocol.md) and [input audit](input_audit.json).

Two fresh Astra reviewers and two fresh Opus reviewers received anonymous A/B pairs. Pair order and A/B positions were randomized separately for each reviewer. The decision rule was fixed before review: at least three of four reviewers must prefer the same candidate for a consensus winner.

| Comparison | Astra votes | Opus votes | Ties | Result |
| --- | ---: | ---: | ---: | --- |
| Paper 1 degradation, trial 01 | 3 | 0 | 1 | Astra |
| Paper 1 degradation, trial 02 | 0 | 2 | 2 | No consensus |
| Paper 1 degradation, trial 03 | 3 | 0 | 1 | Astra |
| Paper 1 system, trial 01 | 0 | 0 | 4 | Tie |
| Paper 1 system, trial 02 | 2 | 2 | 0 | No consensus |
| Paper 2 Figure 1, trial 01 | 1 | 2 | 1 | No consensus |
| Paper 2 Figure 1, trial 02 | 0 | 4 | 0 | Opus |
| Paper 2 Figure 1, trial 03 | 0 | 1 | 3 | No consensus |

The clearest Opus advantage was an explanation in [Paper 2 trial 02](claude/paper2_02/response.md):

> It acts on the reference before the tracking error is formed and therefore lies outside the outer controller loop.

The [paired Astra draft](astra/paper2_02/response.md) stated the location without explaining it. All four reviewers identified this difference. It connects the signal sequence to the loop definition that follows. The reviewers described the advantage as small; both drafts retained the required engineering content.

Astra's two Paper 1 wins came from more explicit transitions. For example, “consistent with this gain amplification” linked the mechanism directly to the previous paragraph. Opus's “behind this behavior” left a broader referent. These were small editorial differences, not differences in the underlying engineering explanation.

Both models passed the final mechanical restrictions in all eight drafts: fewer than three prose commas per sentence, no semicolons, and no “whose.” All four reviewers judged every Opus draft usable. Seven Astra drafts received the same unanimous judgment. One reviewer rejected the remaining Astra draft because “connect the numerical substructure to the experiment” used an imprecise referent. The other three accepted it. This is a disputed wording defect, not evidence of a broad technical failure.

The comparison also exposed limitations in the workflow:

- A low comma count does not ensure clarity. Opus system trial 02 joined “receives,” “computes,” and a change of subject with repeated “and.” All reviewers identified some local crowding there, although they disagreed about which paired passage needed less editing.
- Positive review does not guarantee that the opening serves the author's purpose. Even the unanimously preferred Opus Paper 2 draft begins by saying the figure “shows where the adaptive factor enters the signal path.” This remains close to the figure-navigation emphasis the author questioned. I would revise that opening to foreground the roles of displacement tracking and force feedback.
- The most useful Opus sentence should not be treated as a reason to accept every sentence. Conversely, the vague “experiment” in one Astra draft is worth correcting even though three reviewers accepted it.
- Reviewer preferences differed. Across 16 decisions each, Astra reviewers cast 5 votes for Astra, 2 for Opus, and 9 ties. Opus reviewers cast 4 votes for Astra, 9 for Opus, and 3 ties. This pattern could reflect different editorial standards or model-family preference. This sample cannot distinguish them.

These observations support keeping the same engineering facts, dictionary, and independent review when changing the writer model. They do not establish that switching models eliminates awkward writing. The guide was held fixed for this comparison. A future revision should target the remaining concrete problems: figure openings that merely announce locations, sentences crowded with repeated conjunctions, and vague nouns that replace named components.

The command used Claude Code 2.1.281 with -p, --model claude-opus-5-5, and --effort high. All eight writer responses recorded claude-opus-5-5 in modelUsage and had distinct session IDs. The runner disabled tools, custom instructions, external MCP configuration, and session persistence. Raw responses and invocation metadata are retained in each Claude run directory. The metadata also records auxiliary Haiku usage by the CLI; no fallback writer model was requested.

The Astra side used fresh Codex subagents with inherited settings and no model or effort override. The collaboration interface did not expose the exact serving model and reasoning setting in its run results. Accordingly, this compares the two available writing workflows under the recorded settings. It cannot isolate model choice from reasoning effort, system instructions, and runtime differences. Reasoning effort is itself a configurable generation setting in the [official OpenAI documentation](https://developers.openai.com/api/docs/guides/reasoning); that documentation does not establish the setting used by these particular subagents.

There were three passage topics, not eight independent topics. The guide had previously been developed with Astra trials, and five Astra results were reused. Reviewers were models rather than the author. Their identities were hidden in the review packets, but mathematical formatting was left unchanged and could provide incidental clues. These limits rule out a general ranking of the model families.

One Opus review returned malformed JSON around its final overall_limits field. Its raw response is preserved. The aggregation script repaired only the surrounding brackets in a separate normalized copy; it changed no assessment, score, or vote. See the [normalization note](reviews/reviewer_04_claude/normalization_note.txt).

All individual reasons, scores, and requested repairs are in [comparison_details.md](comparison_details.md). Machine-readable results and model provenance are in [results.json](results.json). The manuscript was not edited as part of this comparison.
