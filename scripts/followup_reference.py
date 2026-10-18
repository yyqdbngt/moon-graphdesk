"""Independent follow-up oracles over synthetic deterministic inputs."""
import collections,copy,hashlib,json,math,random,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
random.seed(20261018)
def run(request, error=False):
    result=subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=60)
    if error:
        assert result.returncode==1,(result.returncode,result.stdout); return
    assert result.returncode in (0,2),(result.returncode,result.stdout,result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n=8; edges=[(i,j) for i in range(n) for j in range(i+1,n) if random.random()<0.3]
    graph={'nodes':[{'id':str(i)} for i in range(n)],'edges':[{'id':str(k),'from':str(a),'to':str(b)} for k,(a,b) in enumerate(edges)]}
    report=run({'operation':'topology','graph':graph})
    position={id:i for i,id in enumerate(report['order'])}
    assert report['acyclic'] and len(position)==n and all(position[str(a)]<position[str(b)] for a,b in edges)
    done=set()
    for layer in report['layers']:
        expected={str(i) for i in range(n) if str(i) not in done and all(str(a) in done for a,b in edges if b==i)}
        assert set(layer)==expected; done.update(layer)
print('Topology: 20 random DAGs checked by prerequisite layer closure passed')
