# Opus 5.5 high versus the Codex writing workflow

Use the frozen v3 guide and dictionary without tuning either for one model.
The installed Claude Code runner is 2.1.281. A preliminary request confirmed claude-opus-5-5 in its modelUsage metadata. Every production request specifies --model claude-opus-5-5 and --effort high. No fallback model is requested.

## Cases

- Three primary-case drafts and two system-case drafts repeat the saved Paper 1 v3 trials. Their engineering points and neighbors are identical to the original inputs.
- Three new paired trials address the actual Paper 2 passage discussed with the author. Both sides receive the same fresh packet. Neither receives the earlier revision.
- The original Paper 1 target is withheld from writers and supplied to reviewers. Paper 2 reviewers receive the required engineering facts and neighboring draft paragraphs. No reference wording is treated as a required style template.

## Context and runtime

Claude receives each full packet through stdin in a fresh print process. Safe mode disables custom instructions and memory. Tools, external MCP configurations, and session persistence are disabled. No previous session is resumed. The host saves the returned Markdown and raw metadata.
New Codex writers use fresh subagents with fork_turns=none and read only the matching packet. They save the response without reading other files. No model or reasoning override is applied. The prior Codex trials also inherited those settings. Their exact serving model ID and reasoning setting were not logged by the subagent interface, so the comparison cannot claim equal reasoning effort or pure model-only causality. The user refers to this side as Astra.
The Paper 1 inputs differ only in delivery instructions between the old file-writing tasks and the Claude print runner. The scientific facts, neighboring paragraphs, guide, dictionary, and requested editorial work remain the same. The system prompts and tool environments differ between runtimes.

## Evaluation fixed before seeing outputs

Mechanical checks count prose commas after removing inline mathematics. Every final sentence must have fewer than three prose commas. No semicolon or whose is allowed. Verify required section headings and preserve all outputs, including failures.

Two fresh reviewers from each model family receive anonymized pairs with source context. Randomize left/right order independently for each reviewer. Do not expose the model key or previous review results. Each reviewer must assess every candidate for source fidelity, required content, established terminology, and readable flow. An unsupported claim, material omission, or invented technical name requires revision and cannot be offset by a high overall score.

For each pair choose the draft requiring fewer meaningful edits for an engineering journal, or tie. Explain the choice with specific quoted text. Prioritize meaning and terminology, then logical progression and natural sentences. Do not prefer a draft merely because it is shorter or more similar to the reference. Separate mandatory repairs from optional style preferences.

Aggregate results by case and by pair. A pair has a consensus winner only if at least three of the four reviewers prefer the same candidate. Otherwise call it inconclusive. Do not treat replicated drafts of the same paragraph as independent research topics or use this small sample to rank model families generally. Report reviewer disagreements and setting limitations.
