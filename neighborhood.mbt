///|
pub fn Graph::neighborhood(
  self : Graph,
  start : String,
  depth : Int32,
  reverse~ : Bool = false,
  edge_type~ : String = "",
) -> Value raise {
  if !self.nodes.contains(start) {
    raise InputError("unknown node: " + start)
  }
  // Breadth-first closure within depth hops, then induced-subgraph export
  // over exactly the visited set; both endpoints must be inside it.
  let distances : Map[String, Int32] = Map([(start, 0)])
  let queue = [start]
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    cursor += 1
    if distances[current] >= depth {
      continue
    }
    for (neighbor, _) in self.neighbors(current, reverse, edge_type) {
      if !distances.contains(neighbor) {
        distances[neighbor] = distances[current] + 1
        queue.push(neighbor)
      }
    }
  }
  let ids = distances.keys().collect()
  ids.sort()
  let nodes : Array[Value] = []
  for id in ids {
    nodes.push(self.nodes[id])
  }
  let kept_edges : Array[Value] = []
  for edge in self.edges {
    if distances.contains(str(get(edge, "from"))) &&
      distances.contains(str(get(edge, "to"))) {
      kept_edges.push(edge)
    }
  }
  let entries : Array[(Int32, String)] = []
  for id in ids {
    entries.push((distances[id], id))
  }
  entries.sort_by(fn(a, b) {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  record([
    ("start", String(start)),
    ("depth", Number(depth.to_double())),
    ("visited", Number(ids.length().to_double())),
    ("nodes", Number(nodes.length().to_double())),
    ("edges", Number(kept_edges.length().to_double())),
    (
      "distances",
      Array(
        entries.map(fn(entry) {
          record([
            ("id", String(entry.1)),
            ("distance", Number(entry.0.to_double())),
          ])
        }),
      ),
    ),
    (
      "graph",
      record([
        ("version", Number(1.0)),
        ("nodes", Array(nodes)),
        ("edges", Array(kept_edges)),
      ]),
    ),
  ])
}
