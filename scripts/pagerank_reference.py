"""Independent PageRank oracle: same semantics reimplemented with dict math."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261025)

def run(request, error=False):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if error:
        assert result.returncode == 1, (result.returncode, result.stdout)
        return
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

def pagerank(ids, edges, damping=0.85, iterations=100, tolerance=1e-10, edge_type=None):
    kept = [e for e in edges if edge_type in (None, e.get('type'))]
    outdeg = {i: 0 for i in ids}
    sources = {i: [] for i in ids}
    for e in kept:
        outdeg[e['from']] += 1
    # Match the engine's accumulation order exactly: incoming sources are
    # grouped by ascending source ID, then edge order within each source.
    out_edges = {i: [] for i in ids}
    for e in kept:
        out_edges[e['from']].append(e)
    for source in sorted(ids):
        for e in out_edges[source]:
            sources[e['to']].append(source)
    n = len(ids)
    ranks = {i: 1.0 / n for i in ids}
    converged = False
    used = 0
    for _ in range(iterations):
        used += 1
        dangling = sum(ranks[i] for i in ids if outdeg[i] == 0)
        base = (1.0 - damping) / n + damping * dangling / n
        nxt, delta = {}, 0.0
        for i in ids:
            value = base + damping * sum(ranks[s] / outdeg[s] for s in sources[i])
            nxt[i] = value
            delta += abs(value - ranks[i])
        ranks = nxt
        if delta < tolerance:
            converged = True
            break
    return ranks, used, converged

for _ in range(20):
    n = 9
    edges = [{'id': str(k), 'from': str(a), 'to': str(b), 'type': random.choice(['dep', 'call'])}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.15)]
    ids = sorted(str(i) for i in range(n))
    graph = {'nodes': [{'id': i} for i in ids], 'edges': edges}
    for edge_type in (None, 'dep'):
        request = {'operation': 'pagerank', 'iterations': 100, 'graph': graph}
        if edge_type: request['edge_type'] = edge_type
        result = run(request)
        ranks, _, converged = pagerank(ids, edges, edge_type=edge_type)
        assert result['converged'] == converged
        assert sum(abs(entry['rank'] - ranks[entry['id']]) for entry in result['ranks']) < 1e-9
        # Cross-implementation float accumulation can differ in the last ulp,
        # so ordering is checked per node against independent ranks with an
        # epsilon tie-group instead of a bit-exact global permutation.
        order = [entry['id'] for entry in result['ranks']]
        engine_ranks = {entry['id']: entry['rank'] for entry in result['ranks']}
        values = [engine_ranks[i] for i in order]
        assert all(values[k] >= values[k + 1] - 1e-12 for k in range(len(values) - 1))
        expected_order = sorted(ids, key=lambda i: (-ranks[i], i))
        for got, want in zip(order, expected_order):
            assert got == want or abs(ranks[got] - ranks[want]) <= 1e-9, (order, expected_order)

result = run({'operation': 'pagerank', 'iterations': 3, 'graph':
              {'nodes': [{'id': 'a'}], 'edges': []}})
assert result['iterations'] == 1 and result['converged'] and result['ranks'][0]['rank'] == 1.0
run({'operation': 'pagerank', 'damping': 1.5, 'graph': {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
run({'operation': 'pagerank', 'iterations': 0, 'graph': {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
print('PageRank: 20 random graphs, unfiltered and typed, plus parameter refusals passed')
