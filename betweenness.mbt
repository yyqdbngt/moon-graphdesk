///|
pub fn Graph::betweenness(
  self : Graph,
  edge_type~ : String = "",
) -> Value raise {
  let ids = self.nodes.keys().collect()
  ids.sort()
  let count = ids.length()
  if count > 1 &&
    count.to_double() * (count.to_double() + self.edges.length().to_double()) >
    20000000.0 {
    raise InputError(
      "betweenness budget exceeded: nodes x (nodes + edges) over 20000000",
    )
  }
  // Brandes unweighted betweenness over directed edges: raw interior
  // shortest-path pair counts, sources processed in ascending ID order.
  let scores : Map[String, Double] = Map([])
  for id in ids {
    scores[id] = 0.0
  }
  for source in ids {
    let sigma : Map[String, Double] = Map([])
    let distance : Map[String, Int32] = Map([])
    let predecessors : Map[String, Array[String]] = Map([])
    let seen : Map[String, Bool] = Map([])
    let order : Array[String] = []
    sigma[source] = 1.0
    distance[source] = 0
    seen[source] = true
    let queue = [source]
    let mut cursor = 0
    while cursor < queue.length() {
      let node = queue[cursor]
      cursor += 1
      order.push(node)
      for (neighbor, _) in self.neighbors(node, false, edge_type) {
        if !seen.contains(neighbor) {
          seen[neighbor] = true
          distance[neighbor] = distance[node] + 1
          queue.push(neighbor)
        }
        if distance[neighbor] == distance[node] + 1 {
          sigma[neighbor] = sigma.get(neighbor).unwrap_or(0.0) + sigma[node]
          match predecessors.get(neighbor) {
            Some(list) => list.push(node)
            None => predecessors[neighbor] = [node]
          }
        }
      }
    }
    let delta : Map[String, Double] = Map([])
    for index = order.length() - 1; index >= 0; index = index - 1 {
      let node = order[index]
      let node_delta = delta.get(node).unwrap_or(0.0)
      for pred in predecessors.get(node).unwrap_or([]) {
        let contribution = sigma[pred] /
          sigma.get(node).unwrap_or(1.0) *
          (1.0 + node_delta)
        delta[pred] = delta.get(pred).unwrap_or(0.0) + contribution
      }
      if node != source {
        scores[node] += delta.get(node).unwrap_or(0.0)
      }
    }
  }
  let entries : Array[(String, Double)] = []
  for id in ids {
    entries.push((id, scores[id]))
  }
  entries.sort_by(fn(a, b) {
    if a.1 != b.1 {
      if b.1 < a.1 {
        -1
      } else {
        1
      }
    } else {
      a.0.compare(b.0)
    }
  })
  record([
    (
      "scores",
      Array(
        entries.map(fn(entry) {
          record([("id", String(entry.0)), ("score", Number(entry.1))])
        }),
      ),
    ),
    ("measure", String("raw directed interior shortest-path pair counts")),
  ])
}
