import argparse
import hashlib
import json
import random
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
def load(p): return json.loads(p.read_text(encoding='utf-8-sig'))
parser=argparse.ArgumentParser()
parser.add_argument('case')
parser.add_argument('--guides',nargs='+',default=['v4','v7'])
args=parser.parse_args()
case=load(ROOT/'cases'/f'{args.case}.json')
manifest=[r for r in load(ROOT/'manifest.json') if r['case']==args.case and r['guide'] in args.guides]
entries=[]
for run in manifest:
    response=load(ROOT/run['response'])
    assert len(response['first_draft'])==len(case['prose_slots'])==len(response['final'])
    metrics=[]
    for paragraph in response['final']:
        prose=re.sub(r'\$.*?\$','MATH',paragraph)
        sentences=re.split(r'(?<=[.!?])\s+(?=[A-Z])',prose)
        metrics.append(dict(words=len(prose.split()),comma_counts=[s.count(',') for s in sentences],
                            semicolons=prose.count(';'),whose=bool(re.search(r'\bwhose\b',prose,re.I))))
    content=[]
    cursor=0
    for block in case['target']:
        if block['type']=='P':
            if response['final'][cursor]:
                content.append(dict(type='P',text=response['final'][cursor]))
            cursor+=1
        else: content.append(block)
    entries.append(dict(run=run,candidate=dict(prose=response['final'],content=content),metrics=metrics,
                        response_hash=hashlib.sha256((ROOT/run['response']).read_bytes()).hexdigest()))
out=ROOT/'reviews'
out.mkdir(exist_ok=True)
(out/f'{args.case}_mechanical.json').write_text(json.dumps(entries,indent=2,ensure_ascii=False),encoding='utf-8')
key={}
rules='''You are an independent engineering manuscript editor evaluating anonymous revised prose in its full section context.
Do not guess the writer, effort level, guide, or chronology. Read only this packet. Do not browse, read other files, consult agents, or rewrite candidates.
The author's priority is useful new engineering explanation without unnecessary repetition of earlier context or of another sentence in the target. Judge meaning, not lexical overlap. Technical terms, necessary definitions, new qualifications and short connections may legitimately recur. Do not reward shorter prose when meaning is lost, or require a standalone recap.
The original is not a style gold standard. Some of its prose is intentionally the problematic target. Use required_meaning as the engineering preservation checklist; established_context identifies information already available. Equations are locked and identical across candidates.
For every candidate, assess:
- repeated_claims: each unnecessary repetition as an object with quote, earlier_location, why_unnecessary, severity ("minor" or "material"). Quote exact candidate wording and identify the earlier sentence in context or candidate. Split one claim only once.
- missing_or_changed_meaning: specific omitted new fact, lost qualification, unsupported addition, or ambiguous relation. Do not require reintroducing known motivation.
- language_defects: awkward terminology, unnatural sentence or comma crowding, with exact evidence.
- ready: true only if no material redundancy or meaning defect or material language defect remains; minor optional wording preferences do not fail.
- score: 0..2 for each of fidelity, necessary_content, contribution, flow, clarity. 2 meets requirement, 1 local defect, 0 substantial defect. A score cannot override a material defect.
Compare every requested pair by fewer meaningful repairs: preference must be the first candidate id, second candidate id, or "tie". Reason must quote concrete evidence. advantage must be "none", "small", or "material". A tie is welcome when differences are optional.
Keep judgments independent of score totals. Do not invent errors merely to distinguish candidates. Evaluate all candidates and all requested pairs. Return one valid JSON object with candidates (array of objects with id, repeated_claims, missing_or_changed_meaning, language_defects, ready, score), comparisons (array of objects with pair_id, preference, advantage, reason), and limits (string).'''
for reviewer,family in (('astra','astra'),('sol','sol')):
    rng=random.Random(f'{args.case}-{reviewer}-20260924')
    order=entries.copy()
    rng.shuffle(order)
    mapped={entry['run']['id']:f'C{i+1}' for i,entry in enumerate(order)}
    key[reviewer]={v:k for k,v in mapped.items()}
    compare=[]
    pairnum=0
    # Same-case matched comparisons: guide, model and effort.
    def add(r1,r2,kind):
        global pairnum
        pairnum+=1
        ids=[mapped[r1['id']],mapped[r2['id']]]
        rng.shuffle(ids)
        compare.append(dict(pair_id=f'P{pairnum}',first=ids[0],second=ids[1]))
        return dict(pair_id=f'P{pairnum}',kind=kind,runs=[r1['id'],r2['id']])
    comparison_key=[]
    for model in ('astra','sol'):
      for effort in ('medium','high'):
        matched=[r for r in manifest if r['model']==model and r['effort']==effort]
        for r in matched[1:]: comparison_key.append(add(matched[0],r,'guide'))
    for guide in sorted({r['guide'] for r in manifest}):
      for effort in ('medium','high'):
        r=[r for r in manifest if r['guide']==guide and r['effort']==effort]
        comparison_key.append(add(r[0],r[1],'model'))
      for model in ('astra','sol'):
        r=[r for r in manifest if r['guide']==guide and r['model']==model]
        comparison_key.append(add(r[0],r[1],'effort'))
    rng.shuffle(compare)
    packet=dict(task=rules,source=case['source'],before=case['before'],original_target=case['target'],
                after=case['after'],required_meaning=case['required'],established_context=case['established'],
                candidates=[dict(id=mapped[e['run']['id']],**e['candidate']) for e in order],
                comparisons=compare)
    (out/f'{args.case}_{reviewer}_packet.json').write_text(json.dumps(packet,indent=2,ensure_ascii=False),encoding='utf-8')
    key[reviewer+'_comparisons']=comparison_key
(out/f'{args.case}_key.json').write_text(json.dumps(key,indent=2),encoding='utf-8')
print('Prepared blind review packets for',args.case,'with',len(entries),'candidates each.')
