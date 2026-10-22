///|
pub fn graph_merge(left : Graph, right : Graph) -> Value raise {
  // Union of two validated graphs. Same-ID payloads must be structurally
  // identical or the merge is refused; combined endpoints always exist
  // because each side was import-validated on its own.
  let nodes : Map[String, Value] = Map([])
  let mut added_nodes = 0
  for id in sorted_keys(left.nodes) {
    nodes[id] = left.nodes[id]
  }
  for id in sorted_keys(right.nodes) {
    match nodes.get(id) {
      Some(existing) =>
        if existing != right.nodes[id] {
          raise InputError("conflicting node payload: " + id)
        }
      None => {
        nodes[id] = right.nodes[id]
        added_nodes += 1
      }
    }
  }
  let edges_by_id : Map[String, Value] = Map([])
  let merged_edges : Array[Value] = []
  let mut added_edges = 0
  for edge in left.edges {
    edges_by_id[str(get(edge, "id"))] = edge
    merged_edges.push(edge)
  }
  for edge in right.edges {
    let id = str(get(edge, "id"))
    match edges_by_id.get(id) {
      Some(existing) =>
        if existing != edge {
          raise InputError("conflicting edge payload: " + id)
        }
      None => {
        edges_by_id[id] = edge
        merged_edges.push(edge)
        added_edges += 1
      }
    }
  }
  let ids = nodes.keys().collect()
  ids.sort()
  record([
    ("nodes", Number(nodes.length().to_double())),
    ("edges", Number(merged_edges.length().to_double())),
    ("added_nodes", Number(added_nodes.to_double())),
    ("added_edges", Number(added_edges.to_double())),
    (
      "graph",
      record([
        ("version", Number(1.0)),
        ("nodes", Array(ids.map(fn(id) { nodes[id] }))),
        ("edges", Array(merged_edges)),
      ]),
    ),
  ])
}
