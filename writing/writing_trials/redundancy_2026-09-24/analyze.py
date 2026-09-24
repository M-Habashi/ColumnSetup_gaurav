import collections
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
def load(p): return json.loads(p.read_text(encoding='utf-8-sig'))
manifest=[r for r in load(ROOT/'manifest.json') if r['guide'] in ('v4','v7')]
byid={r['id']:r for r in manifest}
findings=[]
comparisons=[]
for case in ('margin','spectra','approximation'):
    keys=load(ROOT/'reviews'/f'{case}_key.json')
    for reviewer in ('astra','sol'):
        review=load(ROOT/'reviews'/f'{case}_{reviewer}_response.json')
        packet=load(ROOT/'reviews'/f'{case}_{reviewer}_packet.json')
        assert {x['id'] for x in review['candidates']}=={x['id'] for x in packet['candidates']}
        assert len(review['candidates'])==len(packet['candidates'])
        assert {x['pair_id'] for x in review['comparisons']}=={x['pair_id'] for x in packet['comparisons']}
        pairkey={x['pair_id']:x for x in keys[reviewer+'_comparisons']}
        for candidate in review['candidates']:
            findings.append(dict(case=case,reviewer=reviewer,run=keys[reviewer][candidate['id']],assessment=candidate))
        for comparison in review['comparisons']:
            identity=pairkey[comparison['pair_id']]
            choice=comparison['preference']
            winner=keys[reviewer][choice] if choice!='tie' else 'tie'
            assert winner=='tie' or winner in identity['runs']
            comparisons.append(dict(case=case,reviewer=reviewer,**identity,winner=winner,
                                    advantage=comparison['advantage'],reason=comparison['reason']))
summary=[]
for run in manifest:
    assessments=[x['assessment'] for x in findings if x['run']==run['id']]
    assert len(assessments)==2
    summary.append(dict(**run,ready_votes=sum(x['ready'] for x in assessments),
                        repetition_counts=[len(x['repeated_claims']) for x in assessments],
                        meaning_defects=[x['missing_or_changed_meaning'] for x in assessments]))
grouped=[]
for guide in ('v4','v7'):
 for model in ('astra','sol'):
  for effort in ('medium','high'):
    rows=[x for x in summary if (x['guide'],x['model'],x['effort'])==(guide,model,effort)]
    grouped.append(dict(guide=guide,model=model,effort=effort,
                        ready_both=sum(x['ready_votes']==2 for x in rows),
                        ready_split=sum(x['ready_votes']==1 for x in rows),
                        not_ready_both=sum(x['ready_votes']==0 for x in rows)))
output=dict(grouped=grouped,summary=summary,findings=findings,comparisons=comparisons)
(ROOT/'results.json').write_text(json.dumps(output,indent=2,ensure_ascii=False),encoding='utf-8')
lines=['# Anonymous review details','','All model/guide labels below were restored after the reviews.','']
for f in findings:
    c=f['assessment']
    lines += [f"## {f['run']} / {f['reviewer']} reviewer",'',
              f"Ready: {c['ready']}. Scores: {c['score']}.",'']
    for field in ('repeated_claims','missing_or_changed_meaning','language_defects'):
        lines.append(f'{field}:')
        for item in c[field]:
            lines.append('- '+(json.dumps(item,ensure_ascii=False) if isinstance(item,dict) else item))
        if not c[field]: lines.append('- None recorded.')
        lines.append('')
lines += ['## Pairwise comparisons','']
for c in comparisons:
    lines += [f"- {c['case']} / {c['reviewer']} / {c['kind']}: {c['runs']}. Winner: {c['winner']}. Advantage: {c['advantage']}. {c['reason']}"]
(ROOT/'review_details.md').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps(grouped,indent=2))
print('Guide preference votes:',dict(collections.Counter(
    'tie' if c['winner']=='tie' else byid[c['winner']]['guide'] for c in comparisons if c['kind']=='guide')))
for kind,field in (('model','model'),('effort','effort')):
    print('v7',kind,'preference votes:',dict(collections.Counter(
        'tie' if c['winner']=='tie' else byid[c['winner']][field] for c in comparisons
        if c['kind']==kind and all(byid[r]['guide']=='v7' for r in c['runs']))))
