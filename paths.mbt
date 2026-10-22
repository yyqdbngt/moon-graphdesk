///|
priv struct PathFrame {
  node : String
  candidates : Array[(String, Int32)]
  mut cursor : Int32
}

///|
pub fn Graph::simple_paths(
  self : Graph,
  start : String,
  target : String,
  limit : Int32,
  edge_type~ : String = "",
) -> Value raise {
  if !self.nodes.contains(start) || !self.nodes.contains(target) {
    raise InputError("unknown path endpoint")
  }
  let paths : Array[Value] = []
  if start == target {
    paths.push(
      record([
        ("nodes", strings([start])),
        ("edges", Array([])),
        ("weight", Number(0.0)),
      ]),
    )
    return record([
      ("paths", Array(paths)),
      ("count", Number(1.0)),
      ("truncated", Bool(false)),
      ("limit", Number(limit.to_double())),
    ])
  }
  // Explicit-stack DFS in edge insertion order; visited nodes keep paths
  // simple, and a step budget bounds exploration on path-poor dense graphs.
  let visited : Map[String, Bool] = Map([(start, true)])
  let stack : Array[PathFrame] = [
    {
      node: start,
      candidates: self.neighbors(start, false, edge_type),
      cursor: 0,
    },
  ]
  let path_nodes : Array[String] = [start]
  let path_edges : Array[Int32] = []
  let mut truncated = false
  let mut steps = 0
  while !stack.is_empty() {
    if paths.length() >= limit {
      truncated = true
      break
    }
    let frame = stack[stack.length() - 1]
    if frame.cursor >= frame.candidates.length() {
      ignore(stack.pop())
      ignore(path_nodes.pop())
      visited.remove(frame.node)
      if !stack.is_empty() {
        ignore(path_edges.pop())
      }
      continue
    }
    steps += 1
    if steps > 1000000 {
      raise InputError("path enumeration budget exceeded")
    }
    let (next, edge_index) = frame.candidates[frame.cursor]
    frame.cursor += 1
    if visited.contains(next) {
      continue
    }
    if next == target {
      let nodes = path_nodes.copy()
      nodes.push(target)
      let edge_ids : Array[Value] = []
      let mut weight = 0.0
      for edge in path_edges {
        weight += optional_num(get(self.edges[edge], "weight"), 1.0)
        edge_ids.push(get(self.edges[edge], "id"))
      }
      weight += optional_num(get(self.edges[edge_index], "weight"), 1.0)
      edge_ids.push(get(self.edges[edge_index], "id"))
      if weight.is_inf() {
        raise InputError("path weight overflow")
      }
      paths.push(
        record([
          ("nodes", strings(nodes)),
          ("edges", Array(edge_ids)),
          ("weight", Number(weight)),
        ]),
      )
      continue
    }
    visited[next] = true
    path_nodes.push(next)
    path_edges.push(edge_index)
    stack.push({
      node: next,
      candidates: self.neighbors(next, false, edge_type),
      cursor: 0,
    })
  }
  record([
    ("paths", Array(paths)),
    ("count", Number(paths.length().to_double())),
    ("truncated", Bool(truncated)),
    ("limit", Number(limit.to_double())),
  ])
}
