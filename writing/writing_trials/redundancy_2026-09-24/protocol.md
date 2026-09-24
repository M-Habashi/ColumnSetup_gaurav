# Redundancy trials

Objective: improve write.md so manuscript editing adds the necessary engineering explanation without repeating established context. Compare requested gpt-6-astra and gpt-6-sol at medium and high effort. "Soul" is interpreted as Sol, the available model name.

First freeze v4 and a candidate v5. Test both on the author's actual rejected v18 passage after Figure 1. Use four fresh writers per guide: Astra medium/high and Sol medium/high. Inspect failures before proceeding. If v5 fails materially, revise the candidate and repeat with new agents. Never revise a guide silently after a writer has used it.

Two other cases are reserved before generating drafts: Paper 2 Section 2.2 and Paper 1's short-window approximation paragraph. The first tests transfer to a new explanation after a long context. The second tests that avoiding repetition does not delete a necessary motivation and qualified limitation. Run both guides on both cases after the candidate is provisionally frozen. This gives 24 drafts for the planned comparison. A new candidate adds runs rather than replacing failed ones.

Each agent uses fork_turns=none, the explicitly requested model and effort, and only its packet. The packet contains the original target, full relevant context, frozen guide, and unchanged dictionary. Reviewer-only required-fact lists and known-context notes are withheld from writers so the test includes recovering the intended message. Writers return first draft, review, final. Equations are locked blocks, not writable prose. This tests prose editing around fixed equations, not the agent's ability to copy equation markup.

Record spawn IDs and requested settings. Tool acceptance of an override is evidence of the requested configuration; do not invent serving-model metadata or claim equal compute across model families. Times include runtime and tool overhead and are not inference-speed benchmarks.

Evaluate anonymized drafts with fresh reviewers from both families at high effort. Hide guide, model, effort and author labels; randomize order independently. Ask for exact evidence for redundancy, lost meaning, or awkward language. Judge the passage in its section. A repeated technical word, a needed reference, or a new qualification is not redundancy. Do not reward brevity alone.

Record distinct repeated claims, not token overlap. Distinguish (a) repeated earlier context, (b) repeated explanation within the edited span, (c) necessary connections. A draft is ready only if no material repeated explanation remains, no required engineering meaning/qualification is lost, no unsupported claim or invented terminology appears, and the sentence rules pass. Disagreement remains visible and is adjudicated from quoted text and source context, not majority alone.

Primary comparisons: v4 versus revised guide within each case/model/effort; Astra versus Sol at matched guide/case/effort; high versus medium at matched guide/case/model. Summarize practical defects and evaluator agreement. Three topics with one draft per cell cannot establish statistical significance or a general model ranking. Repeated reviewer votes on one draft are not independent samples. Add confirmation runs only when an unresolved failure or inconsistent result needs them.

Keep the production manuscript unchanged during tuning. Promote the final guide only after testing. Save all packets, responses, reviews and intermediate guide versions. Report remaining weaknesses rather than claiming a guarantee against future repetition.

## Changes after the first round

Both independent reviewers rejected the four v4 margin drafts. They accepted three v5 drafts and rejected Sol high for omitting the explicit delta(0) baseline. The root also noted remaining purpose repetition and a repeated cap explanation in Sol's medium draft, which the reviewers treated more leniently. v6 adds drafting from new contributions and a separate sentence-by-sentence deletion pass followed by a definitions/qualifications check.

Two v6 exploratory writers (Astra medium/high) had started when the author explicitly clarified that improving prose need not preserve its original length. v7 adds that preference directly: no original word/sentence/paragraph-count target, expansion only for necessary supported meaning, and permission to split/merge/delete paragraphs. Fixed prose slots may contain multiple paragraphs or be empty. The writer delivery schema, original content, and all other packet fields remain unchanged.

The final balanced comparison is v4 versus v7 on all three cases and four model/effort combinations. The v5 primary round and two v6 exploratory drafts are retained but excluded from this balanced comparison. Unrun v5/v6 packets remain marked by absence of response files. Baseline transfer runs started while the v5 pilot was being reviewed; the final v7 guide was frozen before any v7 transfer writer ran. The v5 pilot reviews are preserved under reviews/pilot_v5.
