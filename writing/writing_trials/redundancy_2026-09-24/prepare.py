import ast
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WRITING = ROOT.parent.parent
ROOT.mkdir(exist_ok=True)
(ROOT / 'guides').mkdir(exist_ok=True)
(ROOT / 'cases').mkdir(exist_ok=True)
(ROOT / 'runs').mkdir(exist_ok=True)
v4 = (WRITING / 'write.md').read_text(encoding='utf-8-sig')
assert 'Version 4.' in v4
(ROOT / 'guides/v4.md').write_text(v4, encoding='utf-8')
v5 = v4.replace(
    'Version 4. This file is the entry point for improving a manuscript paragraph. The tested writing rules below are retained from version 3. Version 4 adds the everyday-use instructions. The trial record is in writing_trials/report.md.',
    'Version 5 candidate. This file is the entry point for improving a manuscript paragraph. It adds a section-level check for redundant explanations to version 4. Trial record: writing_trials/redundancy_2026-09-24/report.md.')
v5 = v5.replace(
    'Read the preceding and following paragraphs and enough of the section to understand its purpose.',
    'Read from the relevant section opening through the target and the next paragraph. Look farther back when a definition or explanation has already been introduced.')
v5 = v5.replace(
    '- Use the supplied engineering points. Preserve their meaning and qualifications. Do not add unsupported technical claims.',
    '- Use the supplied engineering points. Preserve their meaning and qualifications across the passage and its context. An editing task does not require repeating every fact from the original paragraph when the surrounding text already supplies it. Do not add unsupported technical claims.')
v5 = v5.replace(
    '- Explain the engineering reason for a figure or equation. Avoid writer-facing statements about what needs to be defined first.',
    '- Explain the engineering reason for a figure or equation when the reader does not already have it. A new equation does not require another statement of the section motivation. Interpret the equation when that adds physical meaning or a useful consequence, rather than automatically translating it into words.')
insert = '''## Contribution and repetition

Before drafting, make brief private notes separating what the reader already knows from what this passage must add. Locate the earlier statement for each idea you consider already established. Identify any short connection needed to introduce a new definition, equation, contrast, or consequence.

- Judge repetition by meaning, not matching words. Rephrasing an earlier explanation still repeats it. Reusing a technical term is often necessary and is not itself redundancy.
- Make each sentence add information or provide a necessary connection. If deleting a sentence leaves the reasoning and references clear, and its meaning is already available, delete it or retain only the needed connecting phrase.
- Give each explanation one place in the revised span. When prose surrounds an equation, state its purpose and interpretation where they help, without explaining the same reason on both sides.
- Preserve genuinely new distinctions, assumptions, definitions, and qualifications even when they mention a familiar concept. Do not shorten by deleting engineering meaning.
- Read the revised text as part of the section, not as a standalone explanation. Do not add a recap or concluding restatement simply to make the edited paragraph self-contained.
- No word-count reduction is a target. Fewer words count as an improvement only when the same necessary meaning remains clear.

'''
v5 = v5.replace('## Draft and review\n', insert + '## Draft and review\n')
v5 = v5.replace(
    '1. Map every required idea to a sentence. Identify any omitted fact or weakened qualification.',
    '1. Map every required new idea to a sentence. For an idea removed as redundant, identify where the unchanged context already supplies it. Check that no new fact or qualification was lost.')
v5 = v5.replace(
    '3. Check the first and last sentences against the neighbors. Remove repeated explanations and transitions that announce an explanation without supplying useful content.',
    '3. Check every sentence against the section context and the rest of the revised span. Identify the new information or necessary connection it supplies. Remove repeated explanations, including the same claim expressed in different words. Check the first and last sentences again in context.')
v5 = v5.replace(
    'Ordinary variation in connective wording is allowed.',
    'A fluent paragraph still needs revision if it repeats an established explanation without a necessary connection. Record a specific repeated claim and its earlier location rather than a general claim that the prose is concise.\nOrdinary variation in connective wording is allowed.')
(ROOT / 'guides/v5.md').write_text(v5, encoding='utf-8')

tree = ast.parse((WRITING / 'build_manuscript2_journal.py').read_text(encoding='utf-8'))
blocks = []
for node in tree.body:
    if not isinstance(node, ast.Expr) or not isinstance(node.value, ast.Call):
        continue
    call = node.value
    if not isinstance(call.func, ast.Name) or call.func.id not in ('P','E','H2','RAW'):
        continue
    name = call.func.id
    try:
        args = [ast.literal_eval(a) for a in call.args]
    except (ValueError, TypeError):
        if name == 'RAW':
            inline = next((n for n in ast.walk(call) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='inline'),None)
            if inline:
                try: blocks.append(dict(type='P', text=ast.literal_eval(inline.args[0])))
                except (ValueError,TypeError): pass
        continue
    if name=='P': blocks.append(dict(type='P',text=args[0]))
    if name=='E': blocks.append(dict(type='equation',id=args[0],latex=args[1]))
    if name=='H2': blocks.append(dict(type='heading',number=args[0],text=args[1]))
    if name=='RAW' and '<figure id="fig1">' in args[0]:
        blocks.append(dict(type='figure',text='Figure 1. Hybrid simulation loop with the NCF OSI framework setup.', description='Numerical substructure -> d -> phase-lead compensator -> u -> summing junction u-y -> C -> lambda -> v -> H(s,k) -> y. y returns to summing junction; f_m returns from specimen to numerical substructure.'))

i1=next(i for i,b in enumerate(blocks) if b['type']=='figure')
i2=next(i for i,b in enumerate(blocks) if b.get('number')=='2.2')
i3=next(i for i,b in enumerate(blocks) if b.get('number')=='2.3')
common_scope='Paper 2 uses hybrid simulation, experiment, initial, and adaptive factor. C is the outer controller; H includes transfer system and specimen. Do not import Paper 1 controller switching. Engineering facts in the manuscript are the authority for this editing task.'
cases = {
 'margin':dict(scope=common_scope, task='Improve the prose after Figure 1 and before Section 2.2. Keep all equations unchanged.',
               before=blocks[:i1+1], target=blocks[i1+1:i2], after=blocks[i2:i2+2],
               required=['H(s,k)=Y(s)/V(s), U and Y as Laplace transforms of u and y.',
                         'Paper 1 separates controller and plant. Here P=L and K=1; this formulation uses the loop response.',
                         'NCF margin definition and chordal distance to -1. Retain enough interpretation for the reader without repeating the section motivation.',
                         'All estimator branches use capped distance. Preserve the algebraic identity, the threshold delta(0)=1/sqrt(2), the Re L>0 region, and meaning of cap: retain smaller distances and bound reported indicator. One coherent explanation is enough.'],
               established=['Section opening already establishes robustness purpose, degradation/gain mechanism, online estimation and adaptive factor.',
                            'Before Figure 1 the signal path, physical components and two feedback loops are already introduced.'],
               source='Current builder / manuscript v18, Section 2.1 after Figure 1'),
 'spectra':dict(scope=common_scope, task='Improve the prose in Section 2.2. Keep all equations unchanged.',
                before=blocks[:i2+1],target=blocks[i2+1:i3],after=blocks[i3:i3+4],
                required=['Short windows of u and y with update interval 0.125 s, window 0.5 s, 75% overlap, fs=2048 Hz, N=1024, bin spacing 2 Hz. Define n and r.',
                          'Hann window and omega_m definition. Instantaneous auto/cross spectra; unnormalized because normalization cancels in ratios; omega argument omitted for brevity.',
                          'Noise motivates recursive smoothing, modified-periodogram citation [3], exponential weighting [4], initialization by first full window.',
                          '2-100 Hz band and 58-62 Hz exclusion gives 47 bins. omega in Omega and n denotes (lambda_n,k_n). k_n is unknown and not estimated.'],
                established=['Online estimation as the specimen changes, measured u/y inputs, estimator branches and adaptive purpose have been introduced.',
                             'Prior section has just defined the frequency-dependent loop and margin. The next section derives H1 and coherence.'],
                source='Current builder / manuscript v18, Section 2.2'),
}
paper=json.loads((WRITING/'writing_trials/paper1_paragraphs.json').read_text(encoding='utf-8-sig'))
byid={x['id']:x['text'] for x in paper}
cases['approximation']=dict(scope='Paper 1. Retain its terminology and qualifications. Do not import Paper 2 adaptive scaling.',
    task='Improve this paragraph about the short-window linear approximation in the supplied Paper 1 context.',
    before=[dict(type='P',text=byid[x]) for x in (50,51)],
    target=[dict(type='P',text=byid[52])],after=[dict(type='P',text=byid[53])],
    required=['Degradation is nonlinear and time varying. Short-window linear approximation keeps analysis tractable and suitable for online evaluation.',
              'Approximation may be inaccurate during brief rapid property changes. It is typically accurate before/after those events and during slow degradation. No guarantee or new algorithm.',
              'Repeating the word degradation is not a defect. Its nonlinear/time-varying character motivates a new approximation here; do not delete the explanation just because degradation was mentioned earlier.'],
    established=['Previous paragraph defines a stiffness-degradation factor and caveat about damping. Next paragraph starts the virtual simulation.'],
    source='Paper 1 direct body paragraph 52; references 50,51,53 from archived extraction')
for key,case in cases.items():
    case['prose_slots']=[x['text'] for x in case['target'] if x['type']=='P']
    (ROOT/'cases'/f'{key}.json').write_text(json.dumps(case,indent=2,ensure_ascii=False),encoding='utf-8')

manifest=[]
dictionary=(WRITING/'scientific_expressions.md').read_text(encoding='utf-8-sig')
for guide in ('v4','v5'):
 for case_id,case in cases.items():
  for model,modelid in (('astra','gpt-6-astra'),('sol','gpt-6-sol')):
   for effort in ('medium','high'):
    run_id=f'{guide}_{case_id}_{model}_{effort}'
    run=ROOT/'runs'/run_id
    run.mkdir(exist_ok=True)
    packet=dict(task=case['task'],scope=case['scope'],
      isolation='Use only this packet. No browsing, other files, other agents, earlier trials, or previous conversation. Do not edit the manuscript. Return output only to the path specified by the host.',
      guide=(ROOT/'guides'/f'{guide}.md').read_text(encoding='utf-8'),
      scientific_expressions=dictionary,before=case['before'],target=case['target'],after=case['after'],
      delivery='Return a JSON object with purpose (short string), first_draft (array of prose strings), review (array of specific findings and changes), and final (array of prose strings). Each array has one entry per target P block in the same order. An empty string is allowed if a whole prose block is unnecessary. Equations are locked separate blocks and will stay verbatim in place: do not reproduce or change them. Use the original $...$ notation for inline mathematics and preserve all necessary definitions and qualifications. Do not include a model identity, score, or claim of author approval. The supplied guide overrides style rules from other contexts. Show editorial notes only inside purpose/review. Perform the review before returning final.')
    (run/'packet.json').write_text(json.dumps(packet,indent=2,ensure_ascii=False),encoding='utf-8')
    manifest.append(dict(id=run_id,guide=guide,case=case_id,model=model,requested_model=modelid,effort=effort,packet=f'runs/{run_id}/packet.json',response=f'runs/{run_id}/response.json'))
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Prepared 24 isolated writing packets, frozen v4/v5 guides, and three fixed cases.')
