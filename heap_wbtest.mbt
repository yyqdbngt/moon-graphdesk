///|
test "min heap pops in (distance, id) order" {
  let heap : MinHeap = { items: [], }
  heap.push((3.0, "b"))
  heap.push((1.0, "z"))
  heap.push((1.0, "a"))
  heap.push((2.0, "m"))
  heap.push((1.0, "a"))
  let mut merged = ""
  while true {
    match heap.pop() {
      None => break
      Some((distance, id)) => merged += distance.to_string() + ":" + id + ";"
    }
  }
  assert_eq(merged, "1:a;1:a;1:z;2:m;3:b;")
}

///|
test "heap path search scales along a long chain" {
  // 500-node chain n<i> -> n<i+1> with unit weights: cost must be 499 and the
  // chain must include every node regardless of heap internals.
  let nodes : Array[Json] = []
  let edges : Array[Json] = []
  for i in 0..<500 {
    nodes.push({ "id": "n" + i.to_string() })
  }
  for i in 0..<499 {
    edges.push({
      "id": "e" + i.to_string(),
      "from": "n" + i.to_string(),
      "to": "n" + (i + 1).to_string(),
      "weight": 1,
    })
  }
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"path\",\"start\":\"n0\",\"target\":\"n499\",\"graph\":{\"nodes\":" +
        Json::array(nodes).stringify() +
        ",\"edges\":" +
        Json::array(edges).stringify() +
        "}}",
      ),
    ),
  )
  assert_eq(
    match get(result, "cost") {
      Number(n) => n
      _ => -1.0
    },
    499.0,
  )
  assert_eq(
    match get(result, "nodes") {
      Array(items) => items.length()
      _ => -1
    },
    500,
  )
}
