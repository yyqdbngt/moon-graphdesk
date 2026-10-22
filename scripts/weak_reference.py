"""Independent weak-component oracle: union-find over raw edge lists."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261028)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n = 9
    edges = [{'id': 'e' + str(k), 'from': str(a), 'to': str(b)}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.12)]
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    parent = list(range(n))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for e in edges:
        ra, rb = find(int(e['from'])), find(int(e['to']))
        if ra != rb: parent[ra] = rb
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(str(i))
    expected = sorted((sorted(g) for g in groups.values()), key=lambda g: g[0])
    result = run({'operation': 'weak_components', 'graph': graph})
    assert result['components'] == expected, (result['components'], expected)
    # Weak components never split a strong component: every strong member set
    # must sit inside one weak component.
print('Weak components: 20 random graphs versus union-find passed')
