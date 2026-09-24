# Redundancy workflow trials

The updated guide produced a clear practical improvement on the two Paper 2 passages tested. Both independent reviewers preferred it in eight of twelve matched guide comparisons. The other four comparisons, all on a Paper 1 paragraph that was already concise, were ties. Neither reviewer preferred the original guide. This does not establish a general model ranking or guarantee that future drafts will contain no repetition.

The production [write.md](../../write.md) is now version 7. The user still needs only to identify a paragraph and ask the agent to follow that file.

## What changed

The original guide encouraged preserving facts and explaining equations, but did not adequately distinguish information already established in the section from information that the edited passage needed to add. Its repetition check focused on the first and last sentences. This allowed a fluent rewrite to retain the original paragraph's redundant structure.

Version 7 requires the writer to read the relevant section, identify established information and new contributions, and draft from the new contributions rather than rewrite sentence by sentence. A separate deletion pass asks what specific information would disappear with each sentence. The writer then checks again for lost definitions, assumptions and qualifications. Equation explanations need to add meaning rather than repeat a purpose already given.

The user's length preference is explicit: the revision can be shorter or longer and can split, merge or remove paragraphs. Original word count, sentence count and paragraph count are not targets. Expansion is justified only by necessary supported meaning. The writer must not add filler or invent details to replace deleted text.

All of this remains private preparation and review by default. The user receives the improved prose, not the testing paperwork.

## Trials and controls

Thirty fresh writing agents were used, with no previous trial history:

- Twelve v4 baseline drafts: three cases at Astra medium/high and Sol medium/high.
- Four v5 development drafts on the actual problem passage.
- Two v6 exploratory drafts, retained when the user's length clarification arrived.
- Twelve v7 drafts forming the final balanced comparison with v4.

The cases were the actual v18 passage after Figure 1, Paper 2 Section 2.2 on spectral estimation, and Paper 1's paragraph on the short-window linear approximation. The latter tests whether avoiding repetition damages a necessary motivation or qualified limitation. Writers received the original prose and relevant section context. Reviewer-only preservation checklists were withheld from them.

The requested configurations were gpt-6-astra and gpt-6-sol with medium and high reasoning effort. Each spawn used fork_turns=none and explicit model/effort overrides. These requests were accepted by the collaboration tool. There was no independent serving-model or token-usage metadata, so compute and latency were not compared.

Two fresh high-effort reviewers, one Astra and one Sol, evaluated each case anonymously. Candidate order was independently randomized and guide/model/effort labels were hidden. Two earlier reviewers evaluated the v5 pilot, giving eight reviewer agents in total. All outputs and weak drafts were retained.

The final comparison contains 24 drafts and 48 candidate assessments. Reviewer votes on the same draft are not independent writing samples. The non-guide packet fields are identical within each case. The dictionary remained unchanged. Equations were locked outside the writable prose slots, so these trials test editing around preserved equations rather than copying equation markup. The manuscript itself was not changed during tuning.

## Results

“Both ready” means both reviewers accepted the draft without a material repair. A minor optional edit can remain. “Split” means they disagreed.

| Model and effort | v4 both ready | v7 both ready | v7 split |
| --- | ---: | ---: | ---: |
| Astra medium | 1/3 | 2/3 | 1/3 |
| Astra high | 2/3 | 2/3 | 1/3 |
| Sol medium | 1/3 | 3/3 | 0/3 |
| Sol high | 1/3 | 3/3 | 0/3 |

Both reviewers rejected all four baseline drafts of the Figure 1 passage because they repeated the degradation motivation and the monitored-loop explanation. All four v7 writers removed that recap. For example, the revised Astra medium draft starts directly with H=Y/V and the loop transfer functions. The rest of the section already establishes why the loop is monitored.

All eight final-comparison drafts of the Paper 1 approximation paragraph retained its nonlinear/time-varying motivation and its qualified accuracy claims. The reviewers accepted them and tied all comparisons. The added guidance therefore did not produce a measured benefit there, but also did not cause the deletion of those needed qualifications.

| Matched comparison under v7 | Figure 1 passage | Spectral estimation | Linear approximation |
| --- | --- | --- | --- |
| Astra vs Sol, medium | Reviewers disagreed | Astra, small advantage | Tie |
| Astra vs Sol, high | Reviewers disagreed | Tie | Tie |
| High vs medium, Astra | Tie | Tie | Tie |
| High vs medium, Sol | Tie | High, small advantage | Tie |

Astra medium's local advantage was starting directly with the new short-window procedure. Sol medium first repeated that degradation changes the loop response needed for the margin. Sol high folded that connection into the sentence introducing the procedure, which both reviewers preferred to the separate recap.

The Figure 1 disagreement explains Sol's higher unanimous-readiness count. Sol explicitly stated that the reported indicator is bounded by 1/sqrt(2). Astra left that bound to the unchanged cap equation and the accompanying explanation. The Astra reviewer accepted both approaches. The Sol reviewer required the explicit conclusion and rejected the Astra drafts on that basis. The raw judgments are retained rather than silently resolved in favor of either model.

Across the twelve individual reviewer decisions comparing models under v7, there were eight ties, two Astra preferences and two Sol preferences. Across the twelve effort decisions, there were ten ties and two high-effort preferences, both on the same Sol spectral-estimation pair. These are reviewer decisions, not twelve independent passage samples.

## Editorial assessment and significance

The workflow change mattered more than the model or effort choice in this test. Astra was more willing to remove established background. Sol tended to retain more explicit explanatory statements. Neither approach was consistently better across the cases.

There is no convincing overall model winner here. High effort had a small practical advantage in one of six matched effort comparisons, and the other five were ties. Three distinct passages with one draft per setting are insufficient to establish a statistically significant model or effort advantage. No significance test or general population claim is warranted.

The root editor would still remove the generic robustness-purpose sentence in the Sol Figure 1 drafts. The final reviewers accepted it, although an earlier reviewer called the same type of statement a minor recap. Sol medium's spectral opening also remains a minor repetition under both final reviewers. Thus reviewer approval does not mean perfect alignment with the author's preferences.

For the disputed cap conclusion, a short explicit phrase can preserve clarity without restarting the explanation. The available equation supports Astra's concise account, while the explicit reported-indicator bound can help readers distinguish the implemented indicator from the uncapped margin. This is an editorial choice about useful interpretation, not evidence that one model invented a false equation.

The final guide is a tested improvement, not a promise that a model will never repeat information. Further changes should respond to new author feedback or a concrete failure on another passage. Repeatedly tuning these same examples would risk fitting the guide to the test.

## Verification and retained evidence

All 30 writer responses passed the prose-comma limit and the restrictions on semicolons and “whose.” One v4 Astra medium response over-escaped inline LaTeX commands. That raw artifact is retained and its typesetting defect is recorded separately; the final v7 outputs did not have that issue.

The first comma-check script temporarily joined prose across locked equations, producing a false three-comma flag. It was corrected to check the separate prose blocks and rerun. No writer output was altered to pass a check.

- [Protocol and recorded changes](protocol.md)
- [Frozen guides](guides/v7.md)
- [All writer configurations and output paths](agent_runs.json)
- [Input and mechanical audit](audit.json)
- [Machine-readable final results](results.json)
- [Every final reviewer finding and pairwise reason](review_details.md)
- [Root editorial observations](editor_notes.md)
- [Initial v5 reviewer results](reviews/pilot_v5/margin_astra_response.json)

The production guide's body matches the tested v7 snapshot. Only the word “candidate” was removed from its version label.
