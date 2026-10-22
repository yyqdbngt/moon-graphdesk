"""Independent critical-path oracle: forward recursion brute force on synthetic DAGs."""
import functools, json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261022)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n = 8
    pairs = [(a, b) for a in range(n) for b in range(n) if a < b and random.random() < 0.3]
    edges = [{'id': str(k), 'from': str(a), 'to': str(b), 'weight': random.randint(0, 9)}
             for k, (a, b) in enumerate(pairs)]
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    outgoing = {i: [] for i in range(n)}
    for e in edges: outgoing[int(e['from'])].append((int(e['to']), e['weight'], e['id']))
    @functools.lru_cache(maxsize=None)
    def farthest(start):
        # (total weight, node chain) of the heaviest path leaving start.
        best = (0.0, (start,))
        for target, weight, _ in outgoing[start]:
            total, chain = farthest(target)
            if weight + total > best[0]: best = (weight + total, (start,) + chain)
        return best
    expected = max(farthest(i) for i in range(n)) if n else (0.0, ())
    result = run({'operation': 'critical_path', 'graph': graph})
    assert result['acyclic'] is True and result['weight'] == expected[0], (result, expected)
    nodes, edge_ids = result['nodes'], result['edges']
    assert len(nodes) == len(edge_ids) + 1 and len(set(nodes)) == len(nodes)
    by_id = {e['id']: e for e in edges}
    total = 0.0
    for node, edge_id in zip(nodes, edge_ids):
        edge = by_id[edge_id]
        assert edge['from'] == node
        total += edge['weight']
    if edge_ids:
        assert by_id[edge_ids[-1]]['to'] == nodes[-1]
    assert total == result['weight']

for _ in range(5):
    edges = [{'id': 'x', 'from': 'a', 'to': 'b'}, {'id': 'y', 'from': 'b', 'to': 'a'}]
    if random.random() < 0.5: edges.reverse()
    result = run({'operation': 'critical_path',
                  'graph': {'nodes': [{'id': 'a'}, {'id': 'b'}], 'edges': edges}})
    assert result['acyclic'] is False and result['weight'] is None and result['nodes'] == []
print('Critical path: 20 random DAGs versus forward recursion and 5 cycle refusals passed')
