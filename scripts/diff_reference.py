"""Independent structural diff oracle: set and payload comparisons in Python."""
import copy, json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261027)

def run(request):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

def key(item):
    return item['id']

for _ in range(20):
    n = 8
    left_nodes = [{'id': str(i), 'type': random.choice(['svc', 'lib'])} for i in range(n)]
    left_edges = [{'id': 'e' + str(k), 'from': str(random.randrange(n)), 'to': str(random.randrange(n)),
                   'weight': random.randint(0, 5)}
                  for k in range(10)]
    left = {'nodes': copy.deepcopy(left_nodes), 'edges': copy.deepcopy(left_edges)}
    right = {'nodes': copy.deepcopy(left_nodes), 'edges': copy.deepcopy(left_edges)}
    # Perturbations must keep the graph importable: node deletion cascades to
    # incident edges, and added edges reference the freshly added node.
    right['nodes'].append({'id': 'extra', 'type': 'svc'})
    right['edges'].append({'id': 'extra-edge', 'from': 'extra', 'to': 'extra', 'weight': 1})
    victim = str(random.randrange(n))
    right['nodes'] = [node for node in right['nodes'] if node['id'] != victim]
    right['edges'] = [e for e in right['edges'] if e['from'] != victim and e['to'] != victim]
    if random.random() < 0.8 and right['nodes']:
        right['nodes'][random.randrange(len(right['nodes']))]['type'] = 'mutated'
    if random.random() < 0.8 and right['edges']: del right['edges'][random.randrange(len(right['edges']))]
    if random.random() < 0.8 and right['edges']:
        right['edges'][random.randrange(len(right['edges']))]['weight'] = 99
    result = run({'operation': 'diff', 'graph': left, 'other': right})
    left_by_id = {node['id']: node for node in left['nodes']}
    right_by_id = {node['id']: node for node in right['nodes']}
    left_edges = {edge['id']: edge for edge in left['edges']}
    right_edges = {edge['id']: edge for edge in right['edges']}
    assert result['nodes_added'] == sorted(set(right_by_id) - set(left_by_id))
    assert result['nodes_removed'] == sorted(set(left_by_id) - set(right_by_id))
    assert result['nodes_changed'] == sorted(i for i in set(left_by_id) & set(right_by_id)
                                             if left_by_id[i] != right_by_id[i])
    assert result['edges_added'] == sorted(set(right_edges) - set(left_edges))
    assert result['edges_removed'] == sorted(set(left_edges) - set(right_edges))
    assert result['edges_changed'] == sorted(i for i in set(left_edges) & set(right_edges)
                                             if left_edges[i] != right_edges[i])
    total = sum(len(result[f]) for f in ('nodes_added', 'nodes_removed', 'nodes_changed',
                                         'edges_added', 'edges_removed', 'edges_changed'))
    assert result['changes'] == total and result['identical'] == (total == 0)

same = {'nodes': [{'id': 'a'}], 'edges': []}
assert run({'operation': 'diff', 'graph': same, 'other': same})['identical'] is True
print('Diff: 20 random perturbation pairs versus set and payload recomputation passed')
