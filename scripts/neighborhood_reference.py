"""Independent neighborhood oracle: BFS closure with hop distances."""
import json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261030)

def run(request, error=False):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if error:
        assert result.returncode == 1, (result.returncode, result.stdout)
        return
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    n = 9
    edges = [{'id': 'e' + str(k), 'from': str(a), 'to': str(b)}
             for k, (a, b) in enumerate((a, b) for a in range(n) for b in range(n)
                                        if a != b and random.random() < 0.18)]
    graph = {'nodes': [{'id': str(i)} for i in range(n)], 'edges': edges}
    start = str(random.randrange(n))
    depth = random.randrange(0, 4)
    for reverse in (False, True):
        adjacency = {}
        for e in edges:
            source, target = (e['to'], e['from']) if reverse else (e['from'], e['to'])
            adjacency.setdefault(source, []).append(target)
        distances = {start: 0}
        queue, cursor = [start], 0
        while cursor < len(queue):
            node = queue[cursor]
            cursor += 1
            if distances[node] >= depth: continue
            for neighbor in adjacency.get(node, []):
                if neighbor not in distances:
                    distances[neighbor] = distances[node] + 1
                    queue.append(neighbor)
        request = {'operation': 'neighborhood', 'graph': graph, 'start': start, 'depth': depth}
        if reverse: request['reverse'] = True
        result = run(request)
        assert result['visited'] == len(distances) and result['nodes'] == len(distances)
        kept = [e for e in edges if e['from'] in distances and e['to'] in distances]
        assert result['edges'] == len(kept)
        assert result['graph']['edges'] == kept
        assert [entry['id'] for entry in result['graph']['nodes']] == sorted(distances)
        expected_entries = sorted(distances.items(), key=lambda kv: (kv[1], kv[0]))
        assert [(e['id'], e['distance']) for e in result['distances']] == expected_entries
        summary = run({'operation': 'summary', 'graph': result['graph']})
        assert summary['nodes'] == len(distances) and summary['edges'] == len(kept)

run({'operation': 'neighborhood', 'start': 'zz', 'depth': 1, 'graph':
     {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
run({'operation': 'neighborhood', 'start': 'a', 'depth': 0.5, 'graph':
     {'nodes': [{'id': 'a'}], 'edges': []}}, error=True)
print('Neighborhood: 20 random graphs, forward and reverse, with round trips passed')
