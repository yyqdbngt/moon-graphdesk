///|
fn limits_request(nodes : Array[Value], edges : Array[Value]) -> Value {
  record([
    ("operation", String("summary")),
    ("graph", record([("nodes", Array(nodes)), ("edges", Array(edges))])),
  ])
}

///|
fn limits_node(id : String) -> Value {
  record([("id", String(id))])
}

///|
test "oversized IDs are rejected with a clear contract" {
  let mut long_id = ""
  for _ in 0..<257 {
    long_id += "x"
  }
  let bad_node = try {
    let _ = run(limits_request([limits_node(long_id)], []))
    false
  } catch {
    _ => true
  }
  assert_eq(bad_node, true)
  let bad_edge = try {
    let _ = run(
      limits_request([limits_node("a")], [
        record([
          ("id", String(long_id)),
          ("from", String("a")),
          ("to", String("a")),
        ]),
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(bad_edge, true)
  let empty_edge = try {
    let _ = run(
      limits_request([limits_node("a")], [
        record([("id", String("")), ("from", String("a")), ("to", String("a"))]),
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(empty_edge, true)
}

///|
test "node count over the documented ceiling is refused" {
  let nodes : Array[Value] = []
  for i in 0..<65537 {
    nodes.push(limits_node("n" + i.to_string()))
  }
  let refused = try {
    let _ = run(limits_request(nodes, []))
    false
  } catch {
    _ => true
  }
  assert_eq(refused, true)
}
