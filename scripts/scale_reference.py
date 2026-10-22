"""Deterministic mid-scale smoke gate: independent algorithms on larger synthetic graphs."""
import heapq, json, random, subprocess, time
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261022)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=120)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

# Weighted general graph: heap Dijkstra in Python versus the engine.
n = 3000
edges = []
for a in range(n):
    for _ in range(4):
        b = random.randrange(n)
        if a != b and not any(e['from'] == a and e['to'] == b for e in edges[-4:]):
            edges.append({'id': 'e' + str(len(edges)), 'from': str(a), 'to': str(b),
                          'weight': random.randint(1, 50)})
graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
adjacency = {}
for e in edges:
    adjacency.setdefault(e['from'], []).append((e['to'], e['weight']))
start = time.monotonic()
def dijkstra(source):
    distances = {source: 0}
    queue = [(0, source)]
    while queue:
        distance, node = heapq.heappop(queue)
        if distance > distances.get(node, float('inf')):
            continue
        for neighbor, weight in adjacency.get(node, []):
            candidate = distance + weight
            if candidate < distances.get(neighbor, float('inf')):
                distances[neighbor] = candidate
                heapq.heappush(queue, (candidate, neighbor))
    return distances
expected = dijkstra('0')
for target in ('2999', '1500', '777'):
    result = run({'operation': 'path', 'graph': graph, 'start': '0', 'target': target})
    assert result['reachable'] == (target in expected), target
    if target in expected:
        assert result['cost'] == expected[target], (target, result['cost'], expected[target])
elapsed_path = time.monotonic() - start

# Degree and subgraph round-trip on the same graph.
start = time.monotonic()
degrees = run({'operation': 'degree', 'graph': graph})
totals = {entry['id']: entry['total'] for entry in degrees['nodes']}
recount = {}
for e in edges:
    recount[e['from']] = recount.get(e['from'], 0) + 1
    recount[e['to']] = recount.get(e['to'], 0) + 1
assert totals == {str(i): recount.get(str(i), 0) for i in range(n)}
subset = sorted({str(random.randrange(n)) for _ in range(400)})
sub = run({'operation': 'subgraph', 'graph': graph, 'nodes': subset})
kept = [e for e in edges if e['from'] in set(subset) and e['to'] in set(subset)]
assert sub['nodes'] == len(subset) and sub['edges'] == len(kept)
summary = run({'operation': 'summary', 'graph': sub['graph']})
assert summary['nodes'] == len(subset) and summary['edges'] == len(kept)
elapsed_degree = time.monotonic() - start

# Layered DAG: topology ordering and critical-path weight versus Python DP.
start = time.monotonic()
n = 2000
dag_edges = []
for layer in range(40):
    for i in range(layer * 50, layer * 50 + 50):
        for _ in range(2):
            lower = layer * 50 + 50
            upper = min(n, layer * 50 + 150)
            if lower >= upper:
                continue
            j = random.randrange(lower, upper)
            if j != i:
                dag_edges.append({'id': 'd' + str(len(dag_edges)), 'from': str(i), 'to': str(j),
                                  'weight': random.randint(1, 9)})
dag = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': dag_edges}
topology = run({'operation': 'topology', 'graph': dag})
assert topology['acyclic'] is True and len(topology['order']) == n
position = {id: index for index, id in enumerate(topology['order'])}
assert all(position[e['from']] < position[e['to']] for e in dag_edges)
best = {str(i): 0 for i in range(n)}
for e in sorted(dag_edges, key=lambda e: position[e['from']]):
    best[e['to']] = max(best[e['to']], best[e['from']] + e['weight'])
critical = run({'operation': 'critical_path', 'graph': dag})
assert critical['weight'] == max(best.values()), (critical['weight'], max(best.values()))
elapsed_dag = time.monotonic() - start

# Neighborhood closure on the big weighted graph versus Python BFS.
start = time.monotonic()
adjacency_scale = {}
for e in edges:
    adjacency_scale.setdefault(e['from'], []).append(e['to'])
closure = {'0': 0}
frontier = ['0']
for hop in (1, 2, 3):
    nxt = []
    for node in frontier:
        for neighbor in adjacency_scale.get(node, []):
            if neighbor not in closure:
                closure[neighbor] = hop
                nxt.append(neighbor)
    frontier = nxt
hood = run({'operation': 'neighborhood', 'graph': graph, 'start': '0', 'depth': 3})
assert hood['visited'] == len(closure)
kept_hood = [e for e in edges if e['from'] in closure and e['to'] in closure]
assert hood['edges'] == len(kept_hood)
elapsed_hood = time.monotonic() - start

# Betweenness on a mid-size graph versus a compact independent Brandes, and a
# budget refusal on the oversized graph.
start = time.monotonic()
n = 800
mid_edges = [{'id': 'm' + str(k), 'from': str(a), 'to': str(b)}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.005)]
mid = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': mid_edges}
def brandes(ids, edge_list):
    adjacency = {}
    for e in edge_list:
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
mid_ids = sorted(str(i) for i in range(n))
mid_scores = run({'operation': 'betweenness', 'graph': mid})['scores']
engine_scores = {entry['id']: entry['score'] for entry in mid_scores}
expected_scores = brandes(mid_ids, mid_edges)
assert sum(abs(engine_scores[i] - expected_scores[i]) for i in mid_ids) < 1e-6
refused = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
                         input=json.dumps({'operation': 'betweenness', 'graph': graph}),
                         capture_output=True, text=True, encoding='utf-8', timeout=120)
assert refused.returncode == 1 and 'budget' in refused.stdout
elapsed_betweenness = time.monotonic() - start
print(f'Scale smoke: {n} node DAG and {len(edges)} edge graph verified against independent '
      f'algorithms (paths {elapsed_path:.1f}s, degree/subgraph {elapsed_degree:.1f}s, DAG {elapsed_dag:.1f}s, '
      f'neighborhood {elapsed_hood:.1f}s, betweenness {elapsed_betweenness:.1f}s)')
