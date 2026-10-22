"""Independent simple-path oracle: recursive DFS in the same discovery order."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261026)

def run(request, error=False):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if error:
        assert result.returncode == 1, (result.returncode, result.stdout)
        return
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

def dfs_all(adjacency, start, target):
    paths, visited = [], {start}
    def dfs(node, nodes, edges, weight):
        for nxt, w, eid in adjacency.get(node, []):
            if nxt in visited: continue
            if nxt == target:
                paths.append((nodes + [nxt], edges + [eid], weight + w))
            else:
                visited.add(nxt)
                dfs(nxt, nodes + [nxt], edges + [eid], weight + w)
                visited.remove(nxt)
    dfs(start, [start], [], 0.0)
    return paths

checked = 0
while checked < 20:
    n = 8
    edges = [{'id': 'e' + str(k), 'from': str(random.randrange(n)), 'to': str(random.randrange(n)),
              'weight': random.randint(0, 9)}
             for k in range(14)]
    edges = [e for e in edges if e['from'] != e['to']]
    adjacency = {}
    for e in edges:
        adjacency.setdefault(e['from'], []).append((e['to'], e['weight'], e['id']))
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    expected = dfs_all(adjacency, '0', '7')
    if len(expected) > 3000:
        continue
    checked += 1
    result = run({'operation': 'paths', 'start': '0', 'target': '7', 'limit': 1000, 'graph': graph})
    assert result['truncated'] is False and result['count'] == len(expected)
    for got, (nodes, edge_ids, weight) in zip(result['paths'], expected):
        assert got['nodes'] == nodes and got['edges'] == edge_ids and got['weight'] == weight
    if expected:
        limit = max(1, len(expected) // 2)
        partial = run({'operation': 'paths', 'start': '0', 'target': '7', 'limit': limit, 'graph': graph})
        assert partial['count'] == limit and partial['truncated'] is True
        assert [p['nodes'] for p in partial['paths']] == [nodes for nodes, _, _ in expected[:limit]]

trivial = run({'operation': 'paths', 'start': 'a', 'target': 'a', 'graph':
               {'nodes': [{'id': 'a'}], 'edges': []}})
assert trivial['count'] == 1 and trivial['paths'][0] == {'nodes': ['a'], 'edges': [], 'weight': 0}
run({'operation': 'paths', 'start': 'a', 'target': 'zz', 'graph':
     {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
run({'operation': 'paths', 'limit': 0, 'start': 'a', 'target': 'a', 'graph':
     {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
print('Paths: 20 random graphs enumerated by independent DFS with truncation prefixes passed')
