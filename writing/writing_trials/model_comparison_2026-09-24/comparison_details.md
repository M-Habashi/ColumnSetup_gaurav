# Anonymous pairwise comparison results

| Pair | Astra votes | Opus votes | Ties | Consensus | Astra usable votes | Opus usable votes |
| --- | ---: | ---: | ---: | --- | ---: | ---: |
| primary_01 | 3 | 0 | 1 | astra | 4/4 | 4/4 |
| primary_02 | 0 | 2 | 2 | inconclusive | 4/4 | 4/4 |
| primary_03 | 3 | 0 | 1 | astra | 4/4 | 4/4 |
| system_01 | 0 | 0 | 4 | inconclusive | 4/4 | 4/4 |
| system_02 | 2 | 2 | 0 | inconclusive | 4/4 | 4/4 |
| paper2_01 | 1 | 2 | 1 | inconclusive | 3/4 | 4/4 |
| paper2_02 | 0 | 4 | 0 | claude | 4/4 | 4/4 |
| paper2_03 | 0 | 1 | 3 | inconclusive | 4/4 | 4/4 |

Three agreeing reviewers are required for a consensus. Replicates of one passage are not independent topics.

## Reviewer findings

### reviewer_01 / paper2_02
Reviewer family: astra. Preference: claude. Certainty: low.

Both retain all required relationships and use clear terminology. B gives a small explanatory improvement with 'before the tracking error is formed and therefore lies outside the outer controller loop': it explains the compensator's location rather than only stating it. A's 'distinct roles of displacement and force feedback' is also a useful engineering purpose for the figure. The preference is small and does not imply a required repair to A.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / paper2_03
Reviewer family: astra. Preference: tie. Certainty: none.

A's 'how actuator tracking and force feedback couple the numerical substructure to the specimen' and B's 'signals exchanged between the numerical and physical substructures' both give Figure 1 a useful engineering purpose. Both correctly place the compensator outside the outer loop and explicitly distinguish displacement feedback from force feedback. A's separate closing sentences and B's 'whereas' construction are both readable. Neither requires a meaningful edit that the other avoids.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / primary_03
Reviewer family: astra. Preference: astra. Certainty: low.

Both preserve the qualified mechanism, the unspecified influence of specimen mass, and the limitation across system dynamics. B's 'consistent with this gain amplification' connects directly to the preceding gain-versus-delay discussion, while A's 'behind this behavior' has a broader referent. This is a small stylistic preference for a more explicit transition, not a fidelity defect in A.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The opening 'this behavior' could name gain amplification to make the link to the preceding paragraph more explicit.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / system_01
Reviewer family: astra. Preference: tie. Certainty: none.

Both preserve the same components, interface functions, Paper 1 notation, and applicability beyond seismic loading. A integrates 'Figure 1 shows a typical RTHS scheme in which' into the signal description. B joins the complementary substructure descriptions with 'while' and then separates the figure introduction from its signal description. These are reasonable alternative sentence groupings without a defensible difference in required editing.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / primary_01
Reviewer family: astra. Preference: astra. Certainty: low.

Both give the same cautious causal explanation and retain the nonuniversality qualification. B's 'gain amplification associated with stiffness degradation' directly names the relevant relationship. A's 'observations' followed by 'observed in these results' adds slight verbal repetition and a less specific reference. B has a small stylistic advantage in the opening, with no required repair to A.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The opening 'observations suggest a physical explanation for the gain amplification observed in these results' could avoid repeating the observation wording.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / system_02
Reviewer family: astra. Preference: astra. Certainty: low.

Both preserve the required technical content and meet the usability threshold. B's Figure 1 sentence chains 'receives ... and computes ... and the physical substructure provides', making the change of subject less immediate. A gives 'The physical substructure provides the measured force' its own sentence, which makes the two substructures' signals easier to distinguish. This is a small readability preference, not a change in scientific meaning.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 1}
  - Optional preference: Split or repunctuate 'receives the ground acceleration $a_g(t)$ and computes the desired displacement $d_d$ and the physical substructure provides the measured force $f_e$' so that the subject change is easier to follow.

### reviewer_01 / primary_02
Reviewer family: astra. Preference: tie. Certainty: none.

A's 'If the corrective control action remains unchanged' and B's 'under the same corrective control action' both clearly preserve the condition governing greater overshoot. Both retain 'likely', the influence of mass without an invented direction, possible eventual instability, and dependence on both sets of dynamics. Their openings emphasize different parts of the same mechanism, and neither requires fewer meaningful edits.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_01 / paper2_01
Reviewer family: astra. Preference: tie. Certainty: none.

Both accurately describe the signal path, adaptive scaling, plant composition, physical coupling, and separate feedback loops. B's opening 'where the adaptive factor acts on the command and which measured signals close each feedback loop' offers a more explicit preview. A's 'desired displacement and measured feedback connect the numerical substructure to the experiment' is also purposeful, and its paragraph break before 'The outer controller' usefully separates reference preparation from outer-loop operation. These strengths balance, with no defensible required-edit difference.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / system_01
Reviewer family: astra. Preference: tie. Certainty: none.

Both preserve the same components, signals, interface functions, and excitation qualification. A connects the substructures with "while the physical substructure is excited by actuators" and B connects Figure 1 directly to the numerical computation with "in which the numerical substructure receives ground acceleration". Both connections are natural, and neither creates a meaningful editing need.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / paper2_01
Reviewer family: astra. Preference: astra. Certainty: low.

Both accurately describe the compensator, controller scaling, plant, physical coupling, and distinct feedback loops. B moves directly from "the physical coupling between the actuator and specimen" to the two feedback paths. A inserts "Two measured signals leave the plant" before immediately naming them. B has a small stylistic advantage from this more direct progression, not from its shorter length.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The transition "Two measured signals leave the plant" can be omitted because the following sentence already identifies both signals and their destinations. This is a small preference for a more direct transition.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / primary_03
Reviewer family: astra. Preference: tie. Certainty: none.

A's "The same corrective control action is therefore likely to produce greater overshoot" and B's "If the same corrective control action is retained, it is likely to cause more overshoot" express the same qualified mechanism clearly. Both retain the unspecified mass influence and the warning that the behavior is not universal. "Consistent with this gain amplification" and "behind this behavior" both connect intelligibly to the preceding discussion.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / paper2_03
Reviewer family: astra. Preference: tie. Certainty: none.

A gives Figure 1 an engineering purpose through "how actuator tracking and force feedback couple the numerical substructure to the specimen". B gives an equally useful purpose through "the signals exchanged" and the adaptive factor's location. A describes the return paths in separate sentences, while B joins them with "whereas". Both keep the loops distinct and explain every required component and signal without crowded prose.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / system_02
Reviewer family: astra. Preference: astra. Certainty: moderate.

B gives force feedback its own clear sentence: "The physical substructure provides the measured force". A embeds that role after "computes the desired displacement $d_d$ and the physical substructure provides", which requires the reader to shift from coordinated verbs to a new subject inside the same sentence. This is a concrete local clarity advantage for B. A still preserves the meaning and meets the usability threshold.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 1}
  - Optional preference: The Figure 1 sentence joins "receives the ground acceleration", "computes the desired displacement", and "the physical substructure provides the measured force" through repeated coordination. Separating the numerical and physical roles would make this locally crowded sentence easier to follow.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / paper2_02
Reviewer family: astra. Preference: claude. Certainty: low.

Both are complete and usable. A's "before the tracking error is formed and therefore lies outside the outer controller loop" explains the compensator's location in relation to the subsequent controller equation. B states the correct location without this explanation. A has a small explanatory advantage that helps prepare the reader for the next paragraph's focus on the outer controller loop.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: For additional explanation, B could connect "outside the outer controller loop" to the compensator acting before the tracking error is formed, as A does. The existing description is already sufficient and accurate.

### reviewer_02 / primary_01
Reviewer family: astra. Preference: tie. Certainty: none.

A's "gain amplification observed in these results" and B's "gain amplification associated with stiffness degradation" both connect the laboratory interpretation to the preceding gain discussion without claiming experimental validation. Their accounts of unchanged corrective action, mass influence, and possible instability are equivalent. "Relative to the initial stiffness condition" and "than under the initial stiffness condition" are both clear conventional comparisons.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_02 / primary_02
Reviewer family: astra. Preference: tie. Certainty: none.

A develops the mechanism through "easier to move under the same corrective control action" followed by "This action is therefore likely". B uses the equally clear conditional "If the corrective control action remains unchanged". Both preserve the causal sequence, uncertainty, mass qualification, controller interaction, and dependence on both sets of dynamics. Neither requires a meaningful repair.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_03 / paper2_01
Reviewer family: claude. Preference: claude. Certainty: low.

Both passages pass. B gives the figure a concrete purpose tied to the previous paragraph: 'where the adaptive factor acts on the command and which measured signals close each feedback loop'. A's purpose is less specific: 'connect the numerical substructure to the experiment'. B also prepares the loop distinction with 'Two measured signals leave the plant' and '... whereas the measured force f_m(t) returns ...'. The preference is small and mainly stylistic.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The figure purpose 'connect the numerical substructure to the experiment' is vague. 'the specimen' or 'the physical substructure' would name the connected part precisely.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: 'where the adaptive factor acts on the command' is slightly loose because λ scales the controller output to produce the command. 'where the adaptive factor scales the controller output' would be more exact.

### reviewer_03 / primary_02
Reviewer family: claude. Preference: claude. Certainty: low.

Both passages pass. B's opening 'a physical mechanism for this degradation-driven instability' links directly to the instability discussed in the previous paragraph. A's opening 'stiffness degradation changes how the specimen responds to corrective control action' is accurate but connects less directly. B also marks the contrast with 'However, this behavior is not universal.' The preference is small and stylistic.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: 'stability indicator performance' reads more easily as 'the performance of stability indicators'.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_03 / paper2_02
Reviewer family: claude. Preference: claude. Certainty: low.

Both passages pass. A explains why the compensator is outside the loop: 'It acts on the reference before the tracking error is formed and therefore lies outside the outer controller loop.' It also reinforces the loop distinction with 'closes a separate numerical substructure loop'. B states the placement without the reason. The preference is small and rests on explanatory strength.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: 'closes the outer controller loop by providing feedback to C(s)' is slightly loose because y(t) enters the tracking error u(t)-y(t) and does not feed C(s) directly. Dropping the 'by' phrase would avoid this.

### reviewer_03 / system_02
Reviewer family: claude. Preference: claude. Certainty: low.

Each passage has one local issue. B needs only a sentence split at 'computes the desired displacement $d_d$ and the physical substructure provides'. A needs its illustration statement repositioned so that 'also applies to other external excitations' follows it. B's 'Although seismic excitation is used for illustration, the proposed framework also applies ...' already states the scope clearly. The preference is small.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 1, 'clarity': 2}
  - Optional preference: The illustration idea is carried only by 'For the illustrative seismic excitation,' in the Figure 1 sentence. The closing 'also applies to other external excitations' therefore depends on a mention three sentences earlier. Stating the illustrative role of seismic excitation next to the final sentence would restore the connection.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 1}
  - Optional preference: 'computes the desired displacement $d_d$ and the physical substructure provides the measured force $f_e$' creates a garden path: 'd_d and the physical substructure' first reads as a compound object. Splitting into two sentences fixes it.

### reviewer_03 / primary_01
Reviewer family: claude. Preference: astra. Certainty: medium.

Both passages pass. B's opening 'the gain amplification associated with stiffness degradation' links cleanly to the previous paragraph. A's 'observations ... observed in these results' repeats the root and slightly firms up an inferred mechanism. The rest of the two passages is essentially equivalent.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 1}
  - Optional preference: 'Laboratory observations suggest a physical explanation for the gain amplification observed in these results' repeats 'observ-'. 'observed in these results' also presents gain amplification more firmly than the previous paragraph, which infers it from the GMP trend. 'the gain amplification associated with stiffness degradation' would avoid both issues.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_03 / primary_03
Reviewer family: claude. Preference: astra. Certainty: low.

Both passages pass. B's opening 'a physical mechanism consistent with this gain amplification' names its referent explicitly. A's 'a physical mechanism behind this behavior' leaves the referent general and reuses 'this behavior' later. A's 'If the same corrective control action is retained' is marginally more explicit than B's 'The same corrective control action is therefore likely', so the preference is small.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: 'this behavior' appears in the first sentence and again in 'However, this behavior is not universal' with slightly different referents. Naming the first referent, for example the gain amplification, would sharpen it.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_03 / paper2_03
Reviewer family: claude. Preference: tie. Certainty: none.

Both passages pass with concrete figure purposes. A has 'how actuator tracking and force feedback couple the numerical substructure to the specimen'. B has 'the signals exchanged between the numerical and physical substructures and the point at which the adaptive factor modifies the command'. Each has only a minor stylistic point, the fronted phrase in A and 'modifies the command' in B. Neither needs fewer meaningful edits.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The fronted 'Outside the outer controller loop, a phase-lead compensator advances' puts the placement before the component. Stating the placement after the compensator is introduced reads more naturally.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: 'the point at which the adaptive factor modifies the command' is slightly loose because λ scales the controller output to produce the command.

### reviewer_03 / system_01
Reviewer family: claude. Preference: tie. Certainty: none.

Both passages are accurate, complete and clear. The differences are stylistic. A uses 'Actuators excite the physical substructure, which is instrumented with sensors' and folds the scheme into 'in which'. B pairs the substructures with 'while' and uses 'In this scheme'. Neither needs a meaningful edit.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_04 / system_01
Reviewer family: claude. Preference: tie. Certainty: low.

Both retain every required idea with correct Paper 1 symbols and no added components. A joins the substructure descriptions with "while", and B uses "Actuators excite the physical substructure, which is instrumented with sensors". B merges the Figure 1 sentence with "in which", and A splits it with "In this scheme". A's "only as an illustration" and B's "as an illustration" both lead correctly into the generalization. These are stylistic differences of equal weight.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "Figure 1 shows a typical RTHS scheme. In this scheme the numerical substructure..." could be one sentence with "in which" to reduce the run of short sentences.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "receives ground acceleration $a_g(t)$" lacks the article used in "the desired displacement" and "the measured force".

### reviewer_04 / primary_03
Reviewer family: claude. Preference: astra. Certainty: low.

A opens with "a physical mechanism consistent with this gain amplification", which ties directly to the previous paragraph's conclusion. B's "behind this behavior" leaves the referent loose and reuses "this behavior" later with a different scope. B's "If the same corrective control action is retained" states the unchanged action more explicitly than A's "The same corrective control action is therefore", which partly offsets this. The preference is small and stylistic.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "stability-indicator performance" is a compressed noun stack. "the performance of stability indicators" reads more naturally.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "a physical mechanism behind this behavior" is vaguer than naming the gain amplification from the previous paragraph, and "this behavior" recurs in "However, this behavior is not universal".

### reviewer_04 / paper2_03
Reviewer family: claude. Preference: claude. Certainty: low.

Both are complete and accurate. A follows the signal path in order: d(t), compensator, u(t), then "acts on the reference outside the outer controller loop" once the loop context is set. It ends with a "whereas" sentence that keeps the two loops distinct. B front-loads "Outside the outer controller loop" before the loop is defined. B's opening purpose, "how actuator tracking and force feedback couple the numerical substructure to the specimen", is good. The preference is small.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "the point at which the adaptive factor modifies the command" could say that λ scales the controller output, to match the later sentence.
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: The fronted "Outside the outer controller loop," places the loop before C(s) or the tracking error has been introduced. It also produces the echo "Outside the outer".

### reviewer_04 / paper2_02
Reviewer family: claude. Preference: claude. Certainty: low.

B explains why the compensator is outside the loop: "acts on the reference before the tracking error is formed and therefore lies outside the outer controller loop". A only asserts the placement. B also defines the interaction as "the physical coupling" and marks the force loop as "a separate numerical substructure loop", which reinforces the distinction. A's "by providing feedback to C(s)" is a good touch. B's stronger explanation is a small advantage.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "the control-structure interaction that physically couples the actuator and specimen" is slightly circular. "which is the physical coupling between" states the definition directly.
  - Optional preference: "from the ground acceleration and measured force" lets one article serve two different inputs.
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}

### reviewer_04 / primary_02
Reviewer family: claude. Preference: claude. Certainty: low.

A's opening, "a physical mechanism for this degradation-driven instability", links to the preceding discussion of instability. B's "stiffness degradation changes how the specimen responds to corrective control action" is accurate but reads as a new topic. A's "If the corrective control action remains unchanged" states the retained-action condition clearly. B folds it into "easier to move under the same corrective control action", which also works. The preference is small and stylistic.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "stability indicator performance" is an unhyphenated noun stack.
  - Optional preference: The opening sentence could refer to the instability discussed in the previous paragraph.

### reviewer_04 / primary_01
Reviewer family: claude. Preference: astra. Certainty: low.

The passages are nearly identical in content and structure. A's "the gain amplification associated with stiffness degradation" names the cause directly. B's "observed in these results" echoes "Laboratory observations" in the same sentence. The difference is small and stylistic.

- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "Laboratory observations suggest a physical explanation for the gain amplification observed in these results" repeats the observe root. "associated with stiffness degradation" avoids the echo.

### reviewer_04 / paper2_01
Reviewer family: claude. Preference: claude. Certainty: medium.

A's figure-purpose sentence uses "to the experiment" where an established name is required, so A needs a repair. B keeps established names throughout. B also adds a useful transition, "Two measured signals leave the plant.", before the "whereas" sentence that separates the outer controller loop from the numerical substructure loop.

- astra: usable=False, scores={'fidelity': 2, 'content': 2, 'terminology': 1, 'flow': 2, 'clarity': 2}
  - Required repair: "connect the numerical substructure to the experiment" substitutes a vague term for an established name. The numerical substructure is itself part of the experiment. Name the specimen or physical substructure instead.
  - Optional preference: "measured feedback" is vague next to the named signals y(t) and f_m(t).
  - Optional preference: "from ground acceleration and the measured force" is missing the article before "ground acceleration".
- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}
  - Optional preference: "which measured signals close each feedback loop" describes figure content more than engineering purpose, though it stays informative.

### reviewer_04 / system_02
Reviewer family: claude. Preference: claude. Certainty: low.

Each passage has one local weakness. A's "computes the desired displacement $d_d$ and the physical substructure provides" is a garden path that needs a single clause break. B detaches its seismic illustration from the generalization, so "other external excitations" follows the Figure 2 sentence abruptly and would need restructuring. A's closing, "Although seismic excitation is used for illustration, the proposed framework also applies...", keeps the qualification and generalization together. A's fix is smaller, so the preference is small.

- claude: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 1}
  - Optional preference: "computes the desired displacement $d_d$ and the physical substructure provides" creates a garden path in which the numerical substructure seems to compute the physical substructure. Separate the clause before "the physical substructure provides".
- astra: usable=True, scores={'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 1, 'clarity': 2}
  - Optional preference: "For the illustrative seismic excitation" is awkward. The illustration is also separated from "The proposed framework also applies to other external excitations" by two intervening sentences, which weakens the referent of "other".
