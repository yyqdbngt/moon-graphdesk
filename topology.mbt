///|
pub fn Graph::topology(self : Graph) -> Value raise {
  let remaining : Map[String, Int] = Map([])
  let ids = self.nodes.keys().collect(); ids.sort()
  for id in ids { remaining[id] = self.incoming[id].length() }
  let order : Array[String] = []; let layers : Array[Value] = []; let done : Map[String,Bool] = Map([])
  while true {
    let ready = ids.filter(fn(id) { !done.contains(id) && remaining[id] == 0 })
    if ready.is_empty() { break }
    layers.push(strings(ready))
    for id in ready {
      done[id] = true; order.push(id)
      for index in self.outgoing[id] { let target = str(get(self.edges[index],"to")); remaining[target] = remaining[target] - 1 }
    }
  }
  let blocked = ids.filter(fn(id) { !done.contains(id) })
  let cycles = self.strong_components().filter(fn(component) {
    component.length()>1 || self.outgoing[component[0]].any(fn(i) { get(self.edges[i],"to")==String(component[0]) })
  })
  record([("acyclic",Bool(blocked.is_empty())),("order",strings(order)),("layers",Array(layers)),("blocked",strings(blocked)),("cycles",Array(cycles.map(strings))), ("edge_direction",String("prerequisite to dependent"))])
}
