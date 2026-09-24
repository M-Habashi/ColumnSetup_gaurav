import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
v5=(ROOT/'guides/v5.md').read_text(encoding='utf-8')
v6=v5.replace('Version 5 candidate.', 'Version 6 candidate.')
v6=v6.replace(
    'It adds a section-level check for redundant explanations to version 4.',
    'It adds a section-level contribution check and a separate deletion pass to version 4.')
v6=v6.replace(
    'Before drafting, make brief private notes separating what the reader already knows from what this passage must add. Locate the earlier statement for each idea you consider already established. Identify any short connection needed to introduce a new definition, equation, contrast, or consequence.',
    '''Before drafting, make brief private notes in two groups: already established (with the earlier location) and new here (definitions, distinctions, assumptions, qualifications, or consequences still needed). Identify any short connection needed between them.

Build the draft from the "new here" notes and those necessary connections. Do not rewrite the original sentence by sentence: that can preserve its redundant structure even when the wording improves. A statement in the original is evidence to assess, not an obligation to repeat it. Preserve explicitly required content.

A general purpose already given for a method or quantity does not become new information merely because a later sentence names its symbol or formula. Keep a genuinely new technical definition or scope qualification, but introduce it directly. For example, "the filter suppresses noise" adds nothing after "the filter reduces measurement noise" unless the later sentence explains a new condition, mechanism, or limitation.''')
v6=v6.replace(
    '6. Read the revised paragraph again. Ensure that splitting a sentence has not detached its qualification or broken the connection to the next sentence.',
    '''6. Perform a separate deletion pass after the meaning check. For each final sentence, state in the private review notes the specific information that would disappear if it were deleted. Check both earlier context and the rest of the revised span. If only an already-established purpose or explanation disappears, delete the sentence or reduce it to the necessary connection. "Provides context", "improves flow", and "reinforces the point" are not sufficient reasons to keep a recap. For a necessary connection, identify the referent or reasoning step that would otherwise become unclear.
7. Reread the result and recheck the protected new definitions and qualifications. Ensure that deleting or splitting a sentence has not detached a condition, left an equation symbol undefined, or broken the connection to the next paragraph. Keep equations unchanged when the task requires it.''')
(ROOT/'guides/v6.md').write_text(v6,encoding='utf-8')
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
assert not any(r['guide']=='v6' for r in manifest)
for previous in list(manifest):
    if previous['guide']!='v5': continue
    run=dict(previous)
    run['id']=run['id'].replace('v5_','v6_',1)
    run['guide']='v6'
    run['packet']=run['packet'].replace('v5_','v6_',1)
    run['response']=run['response'].replace('v5_','v6_',1)
    packet=json.loads((ROOT/previous['packet']).read_text(encoding='utf-8'))
    packet['guide']=v6
    (ROOT/run['packet']).parent.mkdir(exist_ok=True)
    (ROOT/run['packet']).write_text(json.dumps(packet,indent=2,ensure_ascii=False),encoding='utf-8')
    manifest.append(run)
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Frozen v6 and prepared 12 new packets. Previous packets unchanged.')
