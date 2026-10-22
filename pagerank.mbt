///|
pub fn Graph::pagerank(
  self : Graph,
  damping~ : Double = 0.85,
  iterations~ : Int32 = 20,
  tolerance~ : Double = 0.0000000001,
  edge_type~ : String = "",
) -> Value raise {
  let ids = self.nodes.keys().collect()
  ids.sort()
  let count = ids.length()
  if count == 0 {
    return record([
      ("damping", Number(damping)),
      ("iterations", Number(0)),
      ("converged", Bool(true)),
      ("ranks", Array([])),
    ])
  }
  // Typed out-degrees and typed incoming sources, computed once. Nodes without
  // outgoing edges are dangling: their rank is spread uniformly over all nodes.
  let out_degree : Map[String, Int32] = Map([])
  let sources : Map[String, Array[String]] = Map([])
  for id in ids {
    out_degree[id] = self.count_typed(self.outgoing[id], edge_type)
    sources[id] = []
  }
  for id in ids {
    for index in self.outgoing[id] {
      let edge = self.edges[index]
      if edge_type == "" || get(edge, "type") == String(edge_type) {
        sources[str(get(edge, "to"))].push(id)
      }
    }
  }
  let ranks : Map[String, Double] = Map([])
  for id in ids {
    ranks[id] = 1.0 / count.to_double()
  }
  let mut used = 0
  let mut converged = false
  for _ in 0..<iterations {
    used += 1
    let mut dangling = 0.0
    for id in ids {
      if out_degree[id] == 0 {
        dangling += ranks[id]
      }
    }
    let base = (1.0 - damping) / count.to_double() +
      damping * dangling / count.to_double()
    let next : Map[String, Double] = Map([])
    let mut delta = 0.0
    for id in ids {
      let mut incoming = 0.0
      for source in sources[id] {
        incoming += ranks[source] / out_degree[source].to_double()
      }
      let value = base + damping * incoming
      next[id] = value
      let change = value - ranks[id]
      delta += if change < 0.0 { -change } else { change }
    }
    for id in ids {
      ranks[id] = next[id]
    }
    if delta < tolerance {
      converged = true
      break
    }
  }
  let entries : Array[(String, Double)] = []
  for id in ids {
    entries.push((id, ranks[id]))
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
    ("damping", Number(damping)),
    ("iterations", Number(used.to_double())),
    ("converged", Bool(converged)),
    (
      "ranks",
      Array(
        entries.map(fn(entry) {
          record([("id", String(entry.0)), ("rank", Number(entry.1))])
        }),
      ),
    ),
  ])
}
