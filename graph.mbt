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
  let nodes : Map[String, Value] = {}
  let outgoing : Map[String, Array[Int32]] = {}
  let incoming : Map[String, Array[Int32]] = {}
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
  let ids : Map[String, Bool] = {}
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
  let parents : Map[String, String] = {}
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
  let distances : Map[String, Double] = Map([(start, 0.0)])
  let parents : Map[String, (String, Int32)] = {}
  let closed : Map[String, Bool] = {}
  while true {
    let mut chosen : String? = None
    let mut best = 1.7976931348623157e308
    for id, distance in distances {
      let tie = match chosen {
        None => true
        Some(other) => id < other
      }
      if !closed.contains(id) && (distance < best || (distance == best && tie)) {
        chosen = Some(id)
        best = distance
      }
    }
    let current = match chosen {
      None => break
      Some(id) => id
    }
    if current == target {
      break
    }
    closed[current] = true
    for (neighbor, edge) in self.neighbors(current, false, edge_type) {
      if closed.contains(neighbor) {
        continue
      }
      let distance = best + optional_num(get(self.edges[edge], "weight"), 1.0)
      if distance.is_inf() {
        raise InputError("path weight overflow")
      }
      if distance < distances.get(neighbor).unwrap_or(1.7976931348623157e308) {
        distances[neighbor] = distance
        parents[neighbor] = (current, edge)
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
  let visited : Map[String, Bool] = {}
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
  .filter(fn(id) {
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
pub fn run(request : Value) -> Value raise {
  let graph = load_graph(get(request, "graph"))
  let operation = optional_str(get(request, "operation"), "summary")
  match operation {
    "topology" => graph.topology()
    "critical_path" =>
      graph.critical_path(edge_type=optional_str(get(request, "edge_type"), ""))
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
