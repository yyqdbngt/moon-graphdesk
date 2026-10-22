///|
pub struct Graph {
  nodes : Map[String, Value]
  edges : Array[Value]
  outgoing : Map[String, Array[Int32]]
  incoming : Map[String, Array[Int32]]
}

///|
pub fn load_graph(source : Value) -> Graph raise {
  if get(source, "version") != Null && get(source, "version") != Number(1.0) {
    raise InputError("unsupported graph snapshot version")
  }
  let nodes : Map[String, Value] = Map([])
  let outgoing : Map[String, Array[Int32]] = Map([])
  let incoming : Map[String, Array[Int32]] = Map([])
  for node in arr(get(source, "nodes")) {
    let id = str(get(node, "id"))
    if id == "" || nodes.contains(id) {
      raise InputError("empty or duplicate node ID")
    }
    if get(node, "properties") != Null {
      ignore(obj(get(node, "properties")))
    }
    nodes[id] = node
    outgoing[id] = []
    incoming[id] = []
  }
  let edges = arr(get(source, "edges"))
  let ids : Map[String, Bool] = Map([])
  for i = 0; i < edges.length(); i = i + 1 {
    let edge = edges[i]
    let id = str(get(edge, "id"))
    let from = str(get(edge, "from"))
    let to = str(get(edge, "to"))
    if ids.contains(id) {
      raise InputError("duplicate edge ID")
    }
    ids[id] = true
    if !nodes.contains(from) || !nodes.contains(to) {
      raise InputError("edge references unknown endpoint: " + id)
    }
    let weight = optional_num(get(edge, "weight"), 1.0)
    if weight < 0.0 {
      raise InputError("negative edge weight")
    }
    outgoing[from].push(i)
    incoming[to].push(i)
  }
  { nodes, edges, outgoing, incoming, }
}

///|
pub fn Graph::snapshot(self : Graph) -> Value {
  let ids = self.nodes.keys().collect()
  ids.sort()
  record([
    ("version", Number(1.0)),
    ("nodes", Array(ids.map(fn(id) { self.nodes[id] }))),
    ("edges", Array(self.edges.copy())),
  ])
}

///|
fn Graph::neighbors(
  self : Graph,
  id : String,
  reverse : Bool,
  edge_type : String,
) -> Array[(String, Int32)] raise InputError {
  if !self.nodes.contains(id) {
    raise InputError("unknown node: " + id)
  }
  let indices = if reverse { self.incoming[id] } else { self.outgoing[id] }
  let neighbors : Array[(String, Int32)] = []
  for index in indices {
    let edge = self.edges[index]
    if edge_type != "" && get(edge, "type") != String(edge_type) {
      continue
    }
    neighbors.push((str(get(edge, if reverse { "from" } else { "to" })), index))
  }
  neighbors
}

///|
pub fn Graph::traverse(
  self : Graph,
  start : String,
  depth : Int32,
  reverse~ : Bool = false,
  edge_type~ : String = "",
) -> Value raise {
  if depth < 0 || depth > 100000 {
    raise InputError("depth out of range")
  }
  ignore(self.neighbors(start, reverse, edge_type))
  let distances : Map[String, Int32] = Map([(start, 0)])
  let queue = [start]
  let parents : Map[String, String] = Map([])
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
        parents[neighbor] = current
        queue.push(neighbor)
      }
    }
  }
  let ids = distances.keys().collect()
  ids.sort()
  record([
    (
      "visited",
      Array(
        ids.map(fn(id) {
          record([
            ("id", String(id)),
            ("distance", Number(distances[id].to_double())),
            (
              "parent",
              match parents.get(id) {
                Some(parent) => String(parent)
                None => Null
              },
            ),
          ])
        }),
      ),
    ),
  ])
}

///|
pub fn Graph::shortest_path(
  self : Graph,
  start : String,
  target : String,
  edge_type~ : String = "",
) -> Value raise {
  if !self.nodes.contains(start) || !self.nodes.contains(target) {
    raise InputError("unknown path endpoint")
  }
  // Binary-heap Dijkstra with lazy stale-entry skipping. The (distance, id)
  // heap order reproduces the previous linear-scan tie-breaking exactly.
  let distances : Map[String, Double] = Map([(start, 0.0)])
  let parents : Map[String, (String, Int32)] = Map([])
  let closed : Map[String, Bool] = Map([])
  let heap : MinHeap = { items: [], }
  heap.push((0.0, start))
  while true {
    let (distance, current) = match heap.pop() {
      None => break
      Some(entry) => entry
    }
    if closed.contains(current) {
      continue
    }
    if distance > distances[current] {
      continue
    }
    if current == target {
      break
    }
    closed[current] = true
    for (neighbor, edge) in self.neighbors(current, false, edge_type) {
      if closed.contains(neighbor) {
        continue
      }
      let candidate = distance +
        optional_num(get(self.edges[edge], "weight"), 1.0)
      if candidate.is_inf() {
        raise InputError("path weight overflow")
      }
      if candidate < distances.get(neighbor).unwrap_or(1.7976931348623157e308) {
        distances[neighbor] = candidate
        parents[neighbor] = (current, edge)
        heap.push((candidate, neighbor))
      }
    }
  }
  if !distances.contains(target) {
    return record([
      ("reachable", Bool(false)),
      ("nodes", Array([])),
      ("edges", Array([])),
      ("cost", Null),
    ])
  }
  let path = [target]
  let edge_path : Array[Value] = []
  let mut current = target
  while current != start {
    let (parent, edge) = parents[current]
    path.push(parent)
    edge_path.push(get(self.edges[edge], "id"))
    current = parent
  }
  path.rev_in_place()
  edge_path.rev_in_place()
  record([
    ("reachable", Bool(true)),
    ("nodes", strings(path)),
    ("edges", Array(edge_path)),
    ("cost", Number(distances[target])),
  ])
}

///|
pub fn Graph::strong_components(self : Graph) -> Array[Array[String]] raise {
  let visited : Map[String, Bool] = Map([])
  let order : Array[String] = []
  let ids = self.nodes.keys().collect()
  ids.sort()
  for start in ids {
    if visited.contains(start) {
      continue
    }
    let stack : Array[(String, Bool)] = [(start, false)]
    while !stack.is_empty() {
      let (current, finish) = stack.pop().unwrap()
      if finish {
        order.push(current)
        continue
      }
      if visited.contains(current) {
        continue
      }
      visited[current] = true
      stack.push((current, true))
      for (neighbor, _) in self.neighbors(current, false, "") {
        if !visited.contains(neighbor) {
          stack.push((neighbor, false))
        }
      }
    }
  }
  visited.clear()
  let components : Array[Array[String]] = []
  for start in order.rev_iter() {
    if visited.contains(start) {
      continue
    }
    let component : Array[String] = []
    let stack = [start]
    while !stack.is_empty() {
      let current = stack.pop().unwrap()
      if visited.contains(current) {
        continue
      }
      visited[current] = true
      component.push(current)
      for (neighbor, _) in self.neighbors(current, true, "") {
        if !visited.contains(neighbor) {
          stack.push(neighbor)
        }
      }
    }
    component.sort()
    components.push(component)
  }
  components.sort_by(fn(a, b) { a[0].compare(b[0]) })
  components
}

///|
fn Graph::select(self : Graph, query : Value) -> Array[Value] raise {
  let ids = self.nodes.keys().collect()
  ids.sort()
  let expected = get(query, "properties")
  ids
  .filter(id => {
    let node = self.nodes[id]
    if get(query, "type") != Null && get(query, "type") != get(node, "type") {
      return false
    }
    if expected != Null {
      for key, value in obj(expected) {
        if get(get(node, "properties"), key) != value {
          return false
        }
      }
    }
    true
  })
  .map(fn(id) { self.nodes[id] })
}

///|
pub fn Graph::subgraph(
  self : Graph,
  nodes_value : Value,
  query : Value,
) -> Value raise {
  if (nodes_value != Null) == (query != Null) {
    raise InputError("subgraph requires exactly one of nodes or query")
  }
  let keep : Map[String, Bool] = Map([])
  if nodes_value != Null {
    for id in string_list(nodes_value) {
      if !self.nodes.contains(id) {
        raise InputError("unknown node: " + id)
      }
      if keep.contains(id) {
        raise InputError("duplicate subgraph node: " + id)
      }
      keep[id] = true
    }
  } else {
    for node in self.select(query) {
      keep[str(get(node, "id"))] = true
    }
  }
  let nodes : Array[Value] = []
  let ids = self.nodes.keys().collect()
  ids.sort()
  for id in ids {
    if keep.contains(id) {
      nodes.push(self.nodes[id])
    }
  }
  // Only edges with both endpoints kept survive; node data is unchanged.
  let edges : Array[Value] = []
  for edge in self.edges {
    if keep.contains(str(get(edge, "from"))) &&
      keep.contains(str(get(edge, "to"))) {
      edges.push(edge)
    }
  }
  record([
    ("nodes", Number(nodes.length().to_double())),
    ("edges", Number(edges.length().to_double())),
    (
      "graph",
      record([
        ("version", Number(1.0)),
        ("nodes", Array(nodes)),
        ("edges", Array(edges)),
      ]),
    ),
  ])
}

///|
fn Graph::count_typed(
  self : Graph,
  indices : Array[Int32],
  edge_type : String,
) -> Int32 {
  let mut count = 0
  for index in indices {
    if edge_type == "" || get(self.edges[index], "type") == String(edge_type) {
      count += 1
    }
  }
  count
}

///|
pub fn Graph::degree_report(self : Graph, edge_type~ : String = "") -> Value {
  let ids = self.nodes.keys().collect()
  ids.sort()
  let entries : Array[Value] = []
  let totals : Map[String, Int32] = Map([])
  let mut sum = 0.0
  for id in ids {
    let outgoing = self.count_typed(self.outgoing[id], edge_type)
    let incoming = self.count_typed(self.incoming[id], edge_type)
    let total = outgoing + incoming
    totals[id] = total
    sum += total.to_double()
    entries.push(
      record([
        ("id", String(id)),
        ("in", Number(incoming.to_double())),
        ("out", Number(outgoing.to_double())),
        ("total", Number(total.to_double())),
      ]),
    )
  }
  // A self-loop contributes one incoming and one outgoing incidence.
  let mut self_loops = 0
  for edge in self.edges {
    if (edge_type == "" || get(edge, "type") == String(edge_type)) &&
      get(edge, "from") == get(edge, "to") {
      self_loops += 1
    }
  }
  let mut max_total = 0
  let mut min_total = 0
  let mut first = true
  for id in ids {
    let total = totals[id]
    if first {
      max_total = total
      min_total = total
      first = false
    }
    if total > max_total {
      max_total = total
    }
    if total < min_total {
      min_total = total
    }
  }
  let extremes = fn(total : Int32) -> Value {
    strings(ids.filter(fn(id) { totals[id] == total }))
  }
  record([
    ("nodes", Array(entries)),
    ("max_total", extremes(max_total)),
    ("min_total", extremes(min_total)),
    (
      "average_total",
      Number(if ids.is_empty() { 0.0 } else { sum / ids.length().to_double() }),
    ),
    ("self_loops", Number(self_loops.to_double())),
  ])
}

///|
pub fn run(request : Value) -> Value raise {
  let graph = load_graph(get(request, "graph"))
  let operation = optional_str(get(request, "operation"), "summary")
  match operation {
    "topology" => graph.topology()
    "critical_path" =>
      graph.critical_path(edge_type=optional_str(get(request, "edge_type"), ""))
    "subgraph" => graph.subgraph(get(request, "nodes"), get(request, "query"))
    "degree" =>
      graph.degree_report(edge_type=optional_str(get(request, "edge_type"), ""))
    "snapshot" => graph.snapshot()
    "select" => record([("nodes", Array(graph.select(get(request, "query"))))])
    "neighbors" | "impact" => {
      let requested_depth = optional_num(get(request, "depth"), 1.0)
      if requested_depth < 0.0 ||
        requested_depth > 100000.0 ||
        requested_depth.floor() != requested_depth {
        raise InputError("depth must be a bounded nonnegative integer")
      }
      graph.traverse(
        str(get(request, "start")),
        requested_depth.to_int(),
        reverse=operation == "impact",
        edge_type=optional_str(get(request, "edge_type"), ""),
      )
    }
    "path" =>
      graph.shortest_path(
        str(get(request, "start")),
        str(get(request, "target")),
        edge_type=optional_str(get(request, "edge_type"), ""),
      )
    "components" =>
      record([("components", Array(graph.strong_components().map(strings)))])
    "summary" => {
      let components = graph.strong_components()
      let cyclic = components.filter(fn(c) {
        if c.length() > 1 {
          true
        } else {
          graph.outgoing[c[0]].any(fn(i) {
            get(graph.edges[i], "to") == String(c[0])
          })
        }
      })
      let isolated = graph.nodes
        .keys()
        .filter(fn(id) {
          graph.outgoing[id].is_empty() && graph.incoming[id].is_empty()
        })
        .collect()
      isolated.sort()
      record([
        ("nodes", Number(graph.nodes.length().to_double())),
        ("edges", Number(graph.edges.length().to_double())),
        ("cycles", Array(cyclic.map(strings))),
        ("isolated", strings(isolated)),
      ])
    }
    _ => raise InputError("unknown graph operation")
  }
}
