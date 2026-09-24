import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parent
def load(p): return json.loads(p.read_text(encoding='utf-8-sig'))
manifest=load(ROOT/'manifest.json')
completed=[r for r in manifest if (ROOT/r['response']).exists()]
assert len(completed)==30
audit=[]
agent_runs=[]
for row in completed:
    packet=load(ROOT/row['packet'])
    case=load(ROOT/'cases'/f"{row['case']}.json")
    baseline=load(ROOT/'runs'/f"v4_{row['case']}_astra_medium/packet.json")
    assert {k:v for k,v in packet.items() if k!='guide'}=={k:v for k,v in baseline.items() if k!='guide'}
    assert packet['guide']==(ROOT/'guides'/f"{row['guide']}.md").read_text(encoding='utf-8')
    output=load(ROOT/row['response'])
    assert len(output['final'])==len(output['first_draft'])==len(case['prose_slots'])
    paragraphs=output['final']
    prose_blocks=[re.sub(r'\$.*?\$','MATH',p) for p in paragraphs]
    prose='\n\n'.join(prose_blocks)
    # Locked equations separate these prose blocks and carry their punctuation.
    sentences=[s for p in prose_blocks for s in re.split(r'(?<=[.!?])\s+(?=[A-Z])',p)]
    counts=[s.count(',') for s in sentences if s.strip()]
    max_commas=max(counts)
    semicolons=prose.count(';')
    whose=bool(re.search(r'\bwhose\b',prose,re.I))
    # Report serialization/typesetting anomalies without silently rewriting outputs.
    doubled=any(re.search(r'\\{2,}[A-Za-z,]',p) for p in paragraphs)
    short={'astra':'a','sol':'s'}[row['model']]+{'medium':'m','high':'h'}[row['effort']]
    task=f"/root/red_{row['guide']}_{row['case']}_{short}"
    agent_runs.append(dict(id=row['id'],task_name=task,fork_turns='none',
                           model=row['requested_model'],reasoning_effort=row['effort'],
                           configuration_evidence='Explicit spawn_agent overrides accepted; no independent serving metadata returned.',
                           response=row['response']))
    audit.append(dict(id=row['id'],same_non_guide_inputs=True,
                      guide_sha256=hashlib.sha256(packet['guide'].encode()).hexdigest(),
                      max_prose_commas=max_commas,semicolons=semicolons,whose=whose,
                      prose_words=len(prose.split()),doubled_math_backslashes=doubled,
                      mechanical_pass=max_commas<3 and semicolons==0 and not whose,
                      response_sha256=hashlib.sha256((ROOT/row['response']).read_bytes()).hexdigest()))
(ROOT/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
(ROOT/'agent_runs.json').write_text(json.dumps(agent_runs,indent=2),encoding='utf-8')
print('Completed writers:',len(completed))
print('Matched final comparison:',sum(r['guide'] in ('v4','v7') for r in completed))
print('Same non-guide inputs: all')
print('Mechanical passes:',sum(x['mechanical_pass'] for x in audit),'/',len(audit))
print('Math serialization anomalies:',[x['id'] for x in audit if x['doubled_math_backslashes']])
