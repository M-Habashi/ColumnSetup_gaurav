import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def parse_review(path):
    text = path.read_text(encoding='utf-8-sig').strip()
    if text.startswith(chr(96) * 3):
        text = text.split('\n', 1)[1].rsplit(chr(96) * 3, 1)[0].strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        if path.parent.name != 'reviewer_04_claude':
            raise
        # Preserve the raw model output. Only repair the misplaced array bracket
        # around overall_limits; no assessment wording or votes are changed.
        marker = ',"overall_limits":'
        position = text.rindex(marker)
        parsed = json.loads(text[:position] + ']}')
        parsed['overall_limits'], _ = json.JSONDecoder().raw_decode(text[position + len(marker):])
        (path.parent / 'response_normalized.json').write_text(
            json.dumps(parsed, indent=2, ensure_ascii=False), encoding='utf-8')
        (path.parent / 'normalization_note.txt').write_text(
            'Raw response.md has misplaced closing brackets around overall_limits. '
            'summarize.py reparses the eight unchanged pair objects and the unchanged '
            'overall_limits string into valid JSON. No judgments were altered.\n',
            encoding='utf-8')
        return parsed

manifest = load(ROOT / 'manifest.json')
key = load(ROOT / 'reviewer_key.json')
results = {}
votes = collections.defaultdict(collections.Counter)
usability = collections.defaultdict(lambda: collections.defaultdict(list))
rows = []
for i in range(1, 5):
    reviewer_id = f'reviewer_{i:02}'
    file = ROOT / 'reviews' / (f'{reviewer_id}_response.json' if i <= 2 else f'{reviewer_id}_claude/response.md')
    review = parse_review(file)
    results[reviewer_id] = review
    expected = {run['id'] for run in manifest}
    if {pair['id'] for pair in review['pairs']} != expected or len(review['pairs']) != len(expected):
        raise ValueError(f'{reviewer_id} did not assess exactly the eight expected pairs')
    for pair in review['pairs']:
        identity = key[reviewer_id][pair['id']]
        pref = pair['preference']
        if pref not in ('A', 'B', 'tie'):
            raise ValueError(f'Invalid preference from {reviewer_id}')
        winner = identity[pref] if pref != 'tie' else 'tie'
        votes[pair['id']][winner] += 1
        candidates = {}
        for label in ('A', 'B'):
            candidate = pair[label]
            usability[pair['id']][identity[label]].append(candidate['usable'])
            candidates[identity[label]] = candidate
        rows.append(dict(reviewer=reviewer_id, reviewer_family='astra' if i <= 2 else 'claude',
                         pair=pair['id'], preference=winner, certainty=pair['certainty'],
                         reason=pair['reason'], candidates=candidates))

summary = []
for run in manifest:
    count = votes[run['id']]
    if count['astra'] >= 3:
        consensus = 'astra'
    elif count['claude'] >= 3:
        consensus = 'claude'
    else:
        consensus = 'inconclusive'
    summary.append(dict(pair=run['id'], case=run['case'], votes=dict(count),
                        consensus=consensus,
                        usable_votes={model: sum(values) for model, values in usability[run['id']].items()}))

metadata = [load(p) for p in (ROOT / 'claude').glob('*/metadata.json')]
guide = (ROOT.parent / 'versions/v3/write.md').read_text(encoding='utf-8-sig')
dictionary = (ROOT.parent / 'versions/v3/scientific_expressions.md').read_text(encoding='utf-8-sig')
input_audit = []
for run in manifest:
    packet = load(ROOT / run['packet'])
    assert packet['writing_guide'] == guide
    assert packet['scientific_expressions'] == dictionary
    if run['case'] != 'paper2':
        prior = load((ROOT / run['astra_baseline']).parent / 'packet.json')
        differences = [name for name in set(packet) | set(prior) if packet.get(name) != prior.get(name)]
        assert set(differences) <= {'output_path', 'isolation', 'output'}
    else:
        differences = []
        assert packet == load(ROOT / 'packets/paper2_01.json')
    input_audit.append(dict(pair=run['id'], frozen_guide_and_dictionary=True,
                            substantive_input_match=True, delivery_differences=differences))
measurements = load(ROOT / 'mechanical_metrics.json')
assert len(measurements) == 16
assert all(max(row['prose_commas']) < 3 and row['semicolons'] == row['whose'] == 0 for row in measurements)
(ROOT / 'input_audit.json').write_text(json.dumps(input_audit, indent=2), encoding='utf-8')
provenance = dict(
    claude_writer_runs=len(metadata),
    verified_model=all('claude-opus-5-5' in row['model_usage'] for row in metadata),
    verified_high_flag=all(row['effort'] == 'high' for row in metadata),
    unique_sessions=len({row['session_id'] for row in metadata}),
    packet_hashes={run['id']: hashlib.sha256((ROOT / run['packet']).read_bytes()).hexdigest() for run in manifest},
    cli_reported_writer_cost_usd=sum(row['total_cost_usd'] for row in metadata),
    substantive_inputs_match=True, frozen_guide_and_dictionary=True,
    candidates_passing_mechanical_checks=len(measurements)
)
output = dict(summary=summary, reviews_unblinded=rows, provenance=provenance)
(ROOT / 'results.json').write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding='utf-8')

lines = ['# Anonymous pairwise comparison results', '',
         '| Pair | Astra votes | Opus votes | Ties | Consensus | Astra usable votes | Opus usable votes |',
         '| --- | ---: | ---: | ---: | --- | ---: | ---: |']
for row in summary:
    v = row['votes']
    u = row['usable_votes']
    lines.append(f"| {row['pair']} | {v.get('astra', 0)} | {v.get('claude', 0)} | {v.get('tie', 0)} | {row['consensus']} | {u.get('astra', 0)}/4 | {u.get('claude', 0)}/4 |")
lines += ['', 'Three agreeing reviewers are required for a consensus. Replicates of one passage are not independent topics.', '',
          '## Reviewer findings', '']
for row in rows:
    lines += [f"### {row['reviewer']} / {row['pair']}",
              f"Reviewer family: {row['reviewer_family']}. Preference: {row['preference']}. Certainty: {row['certainty']}.",
              '', row['reason'], '']
    for model, candidate in row['candidates'].items():
        lines.append(f"- {model}: usable={candidate['usable']}, scores={candidate['scores']}")
        for repair in candidate['required_repairs']:
            lines.append(f"  - Required repair: {repair}")
        for preference in candidate['optional_preferences']:
            lines.append(f"  - Optional preference: {preference}")
    lines.append('')
(ROOT / 'comparison_details.md').write_text('\n'.join(lines), encoding='utf-8')
print('\n'.join(lines[:13]))
print(json.dumps(provenance, indent=2))
