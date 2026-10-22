///|
pub fn Graph::weak_components(self : Graph) -> Array[Array[String]] raise {
  // Undirected connectivity: an edge joins its endpoints regardless of
  // direction, so both indexes are walked from every unvisited node.
  let visited : Map[String, Bool] = Map([])
  let ids = self.nodes.keys().collect()
  ids.sort()
  let components : Array[Array[String]] = []
  for start in ids {
    if visited.contains(start) {
      continue
    }
    let component : Array[String] = []
    let stack = [start]
    visited[start] = true
    while !stack.is_empty() {
      let current = stack.pop().unwrap()
      component.push(current)
      for (neighbor, _) in self.neighbors(current, false, "") {
        if !visited.contains(neighbor) {
          visited[neighbor] = true
          stack.push(neighbor)
        }
      }
      for (neighbor, _) in self.neighbors(current, true, "") {
        if !visited.contains(neighbor) {
          visited[neighbor] = true
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
