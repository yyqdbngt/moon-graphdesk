///|
fn sorted_keys(map : Map[String, Value]) -> Array[String] {
  let keys = map.keys().collect()
  keys.sort()
  keys
}

///|
pub fn graph_diff(left : Graph, right : Graph) -> Value raise {
  // "added" means present in right and absent in left; payload equality is
  // structural, so a same-ID node or edge with different data is "changed".
  let nodes_added : Array[String] = []
  let nodes_removed : Array[String] = []
  let nodes_changed : Array[String] = []
  for id in sorted_keys(right.nodes) {
    if !left.nodes.contains(id) {
      nodes_added.push(id)
    }
  }
  for id in sorted_keys(left.nodes) {
    match right.nodes.get(id) {
      None => nodes_removed.push(id)
      Some(node) => if node != left.nodes[id] { nodes_changed.push(id) }
    }
  }
  let left_edges : Map[String, Value] = Map([])
  for edge in left.edges {
    left_edges[str(get(edge, "id"))] = edge
  }
  let right_edges : Map[String, Value] = Map([])
  for edge in right.edges {
    right_edges[str(get(edge, "id"))] = edge
  }
  let edges_added : Array[String] = []
  let edges_removed : Array[String] = []
  let edges_changed : Array[String] = []
  for id in sorted_keys(right_edges) {
    if !left_edges.contains(id) {
      edges_added.push(id)
    }
  }
  for id in sorted_keys(left_edges) {
    match right_edges.get(id) {
      None => edges_removed.push(id)
      Some(edge) => if edge != left_edges[id] { edges_changed.push(id) }
    }
  }
  let identical = nodes_added.is_empty() &&
    nodes_removed.is_empty() &&
    nodes_changed.is_empty() &&
    edges_added.is_empty() &&
    edges_removed.is_empty() &&
    edges_changed.is_empty()
  record([
    ("identical", Bool(identical)),
    ("nodes_added", strings(nodes_added)),
    ("nodes_removed", strings(nodes_removed)),
    ("nodes_changed", strings(nodes_changed)),
    ("edges_added", strings(edges_added)),
    ("edges_removed", strings(edges_removed)),
    ("edges_changed", strings(edges_changed)),
    (
      "changes",
      Number(
        (nodes_added.length() +
        nodes_removed.length() +
        nodes_changed.length() +
        edges_added.length() +
        edges_removed.length() +
        edges_changed.length()).to_double(),
      ),
    ),
  ])
}
