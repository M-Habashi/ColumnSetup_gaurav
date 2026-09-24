import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TRIAL = ROOT.parent

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def final_text(path):
    text = path.read_text(encoding='utf-8-sig')
    match = re.search(r'(?im)^#{1,6}\s+Final paragraph\s*$', text)
    if not match:
        raise ValueError(f'Missing Final paragraph heading in {path}')
    text = text[match.end():].strip()
    text = re.split(r'(?m)^#{1,6}\s+', text)[0].strip()
    text = re.split(r'(?im)^Output path:', text)[0].strip()
    return text.rstrip(chr(96)).strip()

def metrics(text):
    prose = re.sub(r'\\\(.*?\\\)|\\\[.*?\\\]|\$(?:\\.|[^$])+\$', 'MATH', text, flags=re.S)
    prose = re.sub(r'\b[A-Za-z_]+\([^)]*\)', 'SYMBOL', prose)
    prose = re.sub(r'\(0,\s*1\]', 'RANGE', prose)
    sentences = re.split(r'(?<=[.!?])\s+(?=[A-Z“"\\])', prose)
    commas = [sentence.count(',') for sentence in sentences]
    return dict(words=len(re.findall(r"\b\w+(?:[-’']\w+)*\b", prose)),
                sentences=len(sentences), prose_commas=commas,
                semicolons=prose.count(';'), whose=len(re.findall(r'\bwhose\b', prose, re.I)))

manifest = read_json(ROOT / 'manifest.json')
source = {p['id']: p['text'] for p in read_json(TRIAL / 'paper1_paragraphs.json')}
pairs, measurements = [], []
for run in manifest:
    packet = read_json(ROOT / run['packet'])
    candidates = {}
    for model, relpath in [('astra', run['astra_baseline']), ('claude', run['claude_response'])]:
        path = ROOT / relpath
        text = final_text(path)
        measured = metrics(text)
        candidates[model] = dict(text=text, mechanical_checks=measured)
        measurements.append(dict(id=run['id'], model=model, path=str(path), **measured))
    actual = source[56 if run['case'] == 'primary' else 22] if run['case'] != 'paper2' else None
    pairs.append(dict(id=run['id'], case=run['case'], previous=packet['previous_paragraph'],
                      required_ideas=packet['required_ideas'], next=packet['next_paragraph'],
                      actual_reference_paragraph=actual, candidates=candidates))
(ROOT / 'mechanical_metrics.json').write_text(json.dumps(measurements, indent=2, ensure_ascii=False), encoding='utf-8')

schema_example = {
    'pairs': [
        {'id': 'provided pair id',
         'A': {'usable': True, 'scores': {'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}, 'required_repairs': [], 'optional_preferences': []},
         'B': {'usable': True, 'scores': {'fidelity': 2, 'content': 2, 'terminology': 2, 'flow': 2, 'clarity': 2}, 'required_repairs': [], 'optional_preferences': []},
         'preference': 'tie', 'reason': 'Quote specific wording and explain its effect.', 'certainty': 'none'}
    ], 'overall_limits': 'Short limits statement'
}
rules = '''Compare anonymous candidate passages for an engineering journal. The user values accurate meaning, conventional scientific expressions, smooth progression, and clear sentences with few commas. Evaluate the writing actually provided. Source paragraphs are authorities for meaning, not wording or sentence-count templates. No original target is available for the Paper 2 case, so use its required ideas and neighboring draft paragraphs.
Score each dimension 0, 1, or 2: 2 meets the requirement, 1 has a local ambiguity or awkwardness, 0 has a material failure. Fidelity means preserving causal relationships and qualifications without adding claims. Content means retaining all required ideas. Terminology means accurate conventional names and verb phrases without invented technical labels. Flow means a coherent progression within and between neighboring paragraphs. Clarity means readable connected sentences without crowded clauses or needless repetition.
A candidate is usable only when fidelity=content=terminology=2, the total is at least 9, no sentence has 3 or more prose commas, no semicolon or whose occurs, and no material defect remains. Mechanical counts are supplied as a check, but distinguish prose commas from mathematical notation. Ordinary differences in wording are not terminology errors. Do not invent defects just to differentiate candidates. Do not penalize accurate passive voice or prefer a shorter passage merely for being shorter.
Choose A, B, or tie for each pair based on which requires fewer meaningful edits for this user. If both pass, you may prefer the one with stronger explanation or more natural flow, but identify the concrete difference and call the preference small if it is stylistic. If no defensible difference exists, choose tie. If a candidate is not usable, list the specific required repair with a quoted phrase. Keep optional preferences separate from required repairs. Do not let high scores offset a material meaning or terminology defect.
Do not identify or guess the model. Read only this packet, do not consult another agent or file, and do not browse. Return exactly one JSON object using the supplied structure, without code fences. Assess all eight pairs. Do not rewrite the passages.'''

(ROOT / 'reviews').mkdir(exist_ok=True)
keys = {}
for index in range(1, 5):
    rng = random.Random(20260924 + index)
    shuffled = pairs.copy()
    rng.shuffle(shuffled)
    blind, key = [], {}
    for pair in shuffled:
        order = ['astra', 'claude']
        rng.shuffle(order)
        entry = {name: value for name, value in pair.items() if name != 'candidates'}
        entry['A'] = pair['candidates'][order[0]]
        entry['B'] = pair['candidates'][order[1]]
        blind.append(entry)
        key[pair['id']] = dict(A=order[0], B=order[1])
    packet = dict(task=rules, response_structure=schema_example, pairs=blind)
    path = ROOT / 'reviews' / f'reviewer_{index:02}.json'
    path.write_text(json.dumps(packet, indent=2, ensure_ascii=False), encoding='utf-8')
    keys[f'reviewer_{index:02}'] = key
(ROOT / 'reviewer_key.json').write_text(json.dumps(keys, indent=2), encoding='utf-8')
print('Prepared four independently randomized reviewer packets and mechanical metrics.')
