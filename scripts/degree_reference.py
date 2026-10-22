"""Independent degree oracle: recount incidence from raw edge lists."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261024)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n = 8
    edges = [{'id': str(k), 'from': str(a), 'to': str(b), 'type': random.choice(['dep', 'call'])}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.2)]
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    for edge_type in (None, 'dep'):
        request = {'operation': 'degree', 'graph': graph}
        if edge_type: request['edge_type'] = edge_type
        result = run(request)
        kept = [e for e in edges if edge_type in (None, e.get('type'))]
        expected = {}
        for e in kept:
            expected[e['from']] = expected.get(e['from'], 0) + 1  # out
        indeg = {}
        for e in kept:
            indeg[e['to']] = indeg.get(e['to'], 0) + 1
        ids = sorted(str(i) for i in range(n))
        assert [entry['id'] for entry in result['nodes']] == ids
        for entry in result['nodes']:
            out, inn = expected.get(entry['id'], 0), indeg.get(entry['id'], 0)
            assert (entry['in'], entry['out'], entry['total']) == (inn, out, inn + out)
        totals = {i: expected.get(i, 0) + indeg.get(i, 0) for i in ids}
        assert result['max_total'] == sorted(i for i in ids if totals[i] == max(totals.values()))
        assert result['min_total'] == sorted(i for i in ids if totals[i] == min(totals.values()))
        assert result['average_total'] == sum(totals.values()) / n
        assert result['self_loops'] == sum(1 for e in kept if e['from'] == e['to'])
print('Degree: 20 random graphs, unfiltered and type-filtered, recounted from raw edges passed')
