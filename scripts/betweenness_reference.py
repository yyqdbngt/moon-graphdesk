"""Independent betweenness oracle: separate Brandes implementation."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261029)

def run(request, error=False):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=60)
    if error:
        assert result.returncode == 1, (result.returncode, result.stdout)
        return
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

def brandes(ids, edges):
    adjacency = {}
    for e in edges:
        adjacency.setdefault(e['from'], []).append(e['to'])
    scores = {i: 0.0 for i in ids}
    for source in ids:
        sigma = {source: 1.0}
        distance = {source: 0}
        predecessors = {}
        order, queue, cursor = [], [source], 0
        while cursor < len(queue):
            node = queue[cursor]
            cursor += 1
            order.append(node)
            for neighbor in adjacency.get(node, []):
                if neighbor not in distance:
                    distance[neighbor] = distance[node] + 1
                    queue.append(neighbor)
                if distance[neighbor] == distance[node] + 1:
                    sigma[neighbor] = sigma.get(neighbor, 0.0) + sigma[node]
                    predecessors.setdefault(neighbor, []).append(node)
        delta = {}
        for node in reversed(order):
            for pred in predecessors.get(node, []):
                delta[pred] = delta.get(pred, 0.0) + sigma[pred] / sigma[node] * (1.0 + delta.get(node, 0.0))
            if node != source:
                scores[node] += delta.get(node, 0.0)
    return scores

for _ in range(20):
    n = 9
    edges = [{'id': 'e' + str(k), 'from': str(a), 'to': str(b), 'type': random.choice(['dep', 'call'])}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.15)]
    ids = sorted(str(i) for i in range(n))
    graph = {'nodes': [{'id': i} for i in ids], 'edges': edges}
    result = run({'operation': 'betweenness', 'graph': graph})
    expected = brandes(ids, edges)
    engine = {entry['id']: entry['score'] for entry in result['scores']}
    assert sum(abs(engine[i] - expected[i]) for i in ids) < 1e-9
    values = [engine[entry['id']] for entry in result['scores']]
    assert all(values[k] >= values[k + 1] - 1e-12 for k in range(len(values) - 1))
    expected_order = sorted(ids, key=lambda i: (-expected[i], i))
    for got, want in zip([entry['id'] for entry in result['scores']], expected_order):
        assert got == want or abs(expected[got] - expected[want]) <= 1e-9

refused = {'operation': 'betweenness', 'graph': {
    'nodes': [{'id': 'n' + str(i)} for i in range(4000)],
    'edges': [{'id': 'e' + str(i), 'from': 'n' + str(i), 'to': 'n' + str(i + 1)} for i in range(3999)]}}
run(refused, error=True)
print('Betweenness: 20 random graphs versus independent Brandes and budget refusal passed')
