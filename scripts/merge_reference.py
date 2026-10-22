"""Independent merge oracle: set unions with conflict detection in Python."""
import copy, json, random, subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
random.seed(20261031)

def run(request, error=False):
    result = subprocess.run(['node', str(root/'_build/js/debug/build/cmd/main/main.js'), '-'],
        input=json.dumps(request), capture_output=True, text=True, encoding='utf-8', timeout=30)
    if error:
        assert result.returncode == 1, (result.returncode, result.stdout)
        return
    if result.returncode: raise RuntimeError(result.stdout or result.stderr)
    return json.loads(result.stdout)

for _ in range(20):
    shared = [{'id': 's' + str(i), 'type': 'shared'} for i in range(3)]
    left = {'nodes': copy.deepcopy(shared) + [{'id': 'l0'}, {'id': 'l1'}],
            'edges': [{'id': 'se', 'from': 's0', 'to': 's1'}]}
    right = {'nodes': copy.deepcopy(shared) + [{'id': 'r0'}],
             'edges': [{'id': 'se', 'from': 's0', 'to': 's1'},
                       {'id': 're', 'from': 'r0', 'to': 's2', 'weight': 4}]}
    result = run({'operation': 'merge', 'graph': left, 'other': right})
    assert result['nodes'] == 6 and result['edges'] == 2
    assert result['added_nodes'] == 1 and result['added_edges'] == 1
    assert [node['id'] for node in result['graph']['nodes']] == sorted(
        {node['id'] for node in left['nodes']} | {node['id'] for node in right['nodes']})
    summary = run({'operation': 'summary', 'graph': result['graph']})
    assert summary['nodes'] == 6 and summary['edges'] == 2

conflict = copy.deepcopy(right)
conflict['nodes'][0]['type'] = 'mutated'
run({'operation': 'merge', 'graph': left, 'other': conflict}, error=True)
edge_conflict = copy.deepcopy(right)
edge_conflict['edges'][0]['weight'] = 9
run({'operation': 'merge', 'graph': left, 'other': edge_conflict}, error=True)
run({'operation': 'merge', 'graph': left, 'other': {'nodes': [{'id': 'x'}], 'edges': []}}, error=False)
print('Merge: 20 union pairs with round trips, node and edge conflicts refused passed')
