"""Independent induced-subgraph oracle: filter nodes and both-endpoint edges."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261023)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n = 8
    edges = [{'id': str(k), 'from': str(a), 'to': str(b)}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.2)]
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    subset = {str(i) for i in range(n) if random.random() < 0.5} or {'0'}
    result = run({'operation': 'subgraph', 'graph': graph, 'nodes': sorted(subset)})
    kept = [e for e in edges if e['from'] in subset and e['to'] in subset]
    assert result['nodes'] == len(subset) and result['edges'] == len(kept), (result, subset)
    assert [node['id'] for node in result['graph']['nodes']] == sorted(subset)
    assert result['graph']['edges'] == kept
    # Round trip: the exported graph is a valid import again.
    summary = run({'operation': 'summary', 'graph': result['graph']})
    assert summary['nodes'] == len(subset) and summary['edges'] == len(kept)
print('Subgraph: 20 random induced subsets with round-trip summaries passed')
