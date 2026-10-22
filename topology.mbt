///|
fn Graph::topological_layers(
  self : Graph,
) -> (Array[Array[String]], Array[String]) raise InputError {
  let remaining : Map[String, Int32] = Map([])
  let ids = self.nodes.keys().collect()
  ids.sort()
  for id in ids {
    remaining[id] = self.incoming[id].length()
  }
  let layers : Array[Array[String]] = []
  let done : Map[String, Bool] = Map([])
  while true {
    let ready = ids.filter(fn(id) { !done.contains(id) && remaining[id] == 0 })
    if ready.is_empty() {
      break
    }
    layers.push(ready)
    for id in ready {
      done[id] = true
      for index in self.outgoing[id] {
        let target = str(get(self.edges[index], "to"))
        remaining[target] = remaining[target] - 1
      }
    }
  }
  let blocked = ids.filter(fn(id) { !done.contains(id) })
  (layers, blocked)
}

///|
pub fn Graph::topology(self : Graph) -> Value raise {
  let (layers, blocked) = self.topological_layers()
  let order : Array[String] = []
  for layer in layers {
    for id in layer {
      order.push(id)
    }
  }
  let cycles = self
    .strong_components()
    .filter(fn(component) {
      component.length() > 1 ||
      self.outgoing[component[0]].any(fn(i) {
        get(self.edges[i], "to") == String(component[0])
      })
    })
  record([
    ("acyclic", Bool(blocked.is_empty())),
    ("order", strings(order)),
    ("layers", Array(layers.map(fn(layer) { strings(layer) }))),
    ("blocked", strings(blocked)),
    ("cycles", Array(cycles.map(strings))),
    ("edge_direction", String("prerequisite to dependent")),
  ])
}

///|
pub fn Graph::critical_path(
  self : Graph,
  edge_type~ : String = "",
) -> Value raise {
  let (layers, blocked) = self.topological_layers()
  if !blocked.is_empty() {
    return record([
      ("acyclic", Bool(false)),
      ("nodes", Array([])),
      ("edges", Array([])),
      ("weight", Null),
    ])
  }
  if self.nodes.is_empty() {
    return record([
      ("acyclic", Bool(true)),
      ("nodes", Array([])),
      ("edges", Array([])),
      ("weight", Number(0.0)),
    ])
  }
  // Relax outgoing edges in topological order; equal distances keep the
  // lexicographically smallest predecessor and edge so the chain is deterministic.
  let best : Map[String, Double] = Map([])
  let choice : Map[String, (String, String)] = Map([])
  for id in self.nodes.keys() {
    best[id] = 0.0
  }
  for layer in layers {
    for current in layer {
      for (neighbor, index) in self.neighbors(current, false, edge_type) {
        let candidate = best[current] +
          optional_num(get(self.edges[index], "weight"), 1.0)
        if candidate.is_inf() {
          raise InputError("path weight overflow")
        }
        let edge_id = str(get(self.edges[index], "id"))
        let mut better = candidate > best[neighbor]
        if !better && candidate == best[neighbor] {
          better = match choice.get(neighbor) {
            None => false
            Some((from, edge)) =>
              current < from || (current == from && edge_id < edge)
          }
        }
        if better {
          best[neighbor] = candidate
          choice[neighbor] = (current, edge_id)
        }
      }
    }
  }
  let mut endpoint = ""
  let mut started = false
  for id in self.nodes.keys() {
    let take = !started ||
      best[id] > best[endpoint] ||
      (best[id] == best[endpoint] && id < endpoint)
    if take {
      endpoint = id
      started = true
    }
  }
  let nodes = [endpoint]
  let edge_ids : Array[Value] = []
  let mut current = endpoint
  while choice.contains(current) {
    let (parent, edge) = choice[current]
    nodes.push(parent)
    edge_ids.push(String(edge))
    current = parent
  }
  nodes.rev_in_place()
  edge_ids.rev_in_place()
  record([
    ("acyclic", Bool(true)),
    ("nodes", strings(nodes)),
    ("edges", Array(edge_ids)),
    ("weight", Number(best[endpoint])),
  ])
}
