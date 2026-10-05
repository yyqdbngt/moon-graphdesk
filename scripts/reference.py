"""Independent Python standard library oracles; deterministic synthetic data."""
import csv, datetime, hashlib, heapq, io, json, math, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261005)
def run(request):
    result = subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],
        input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for iteration in range(30):
    n = 8
    edges = [{'id':str(k),'from':str(a),'to':str(b),'weight':random.randint(0,9)} for k,(a,b) in enumerate(( (a,b) for a in range(n) for b in range(n) if random.random()<0.18 ))]
    graph = {'nodes':[{'id':str(i)} for i in range(n)],'edges':edges}
    reach = [[a==b for b in range(n)] for a in range(n)]
    for e in edges: reach[int(e['from'])][int(e['to'])] = True
    for k in range(n):
        for a in range(n):
            for b in range(n): reach[a][b] = reach[a][b] or (reach[a][k] and reach[k][b])
    groups, seen = [], set()
    for a in range(n):
        if a not in seen:
            group = [b for b in range(n) if reach[a][b] and reach[b][a]]; seen.update(group); groups.append([str(b) for b in group])
    assert run({'graph':graph,'operation':'components'})['components'] == groups
    distances = [float('inf')]*n; distances[0]=0
    # Bellman-Ford is independent of the MoonBit Dijkstra implementation.
    for _ in range(n-1):
        for e in edges: distances[int(e['to'])] = min(distances[int(e['to'])],distances[int(e['from'])]+e['weight'])
    result = run({'graph':graph,'operation':'path','start':'0','target':'7'})
    assert result['reachable'] == math.isfinite(distances[7])
    if result['reachable']: assert result['cost'] == distances[7]
print('Graph oracle: 30 random graphs versus transitive closure SCC and Bellman-Ford passed')
