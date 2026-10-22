///|
fn betweenness_at(value : Value, keys : Array[String]) -> Value raise {
  let mut current = value
  for key in keys {
    current = match current {
      Object(fields) => fields[key]
      Array(items) => {
        let index = match @json.parse(key) {
          Json::Number(n, ..) => n.to_int()
          _ => raise InputError("invalid test index")
        }
        items[index]
      }
      _ => raise InputError("invalid test path")
    }
  }
  current
}

///|
fn score_of(value : Value, id : String) -> Double raise {
  let scores = match betweenness_at(value, ["scores"]) {
    Array(items) => items
    _ => raise InputError("scores missing")
  }
  for entry in scores {
    if get(entry, "id") == String(id) {
      match get(entry, "score") {
        Number(n) => return n
        _ => raise InputError("score missing")
      }
    }
  }
  raise InputError("id not scored: " + id)
}

///|
test "chain interior node carries the only pair" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"betweenness\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"}]}}",
      ),
    ),
  )
  assert_eq(score_of(result, "b"), 1.0)
  assert_eq(score_of(result, "a"), 0.0)
  assert_eq(score_of(result, "c"), 0.0)
}

///|
test "balanced diamond splits credit in half" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"betweenness\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\"},{\"id\":\"bd\",\"from\":\"b\",\"to\":\"d\"},{\"id\":\"cd\",\"from\":\"c\",\"to\":\"d\"}]}}",
      ),
    ),
  )
  assert_eq(score_of(result, "b"), 0.5)
  assert_eq(score_of(result, "c"), 0.5)
  assert_eq(score_of(result, "a"), 0.0)
}

///|
test "betweenness refuses oversized work before running" {
  // 4000-node chain: nodes x (nodes + edges) = 4000 x 7999 exceeds the budget.
  let nodes : Array[Value] = []
  let edges : Array[Value] = []
  for i in 0..<4000 {
    nodes.push(record([("id", String("n" + i.to_string()))]))
  }
  for i in 0..<3999 {
    edges.push(
      record([
        ("id", String("e" + i.to_string())),
        ("from", String("n" + i.to_string())),
        ("to", String("n" + (i + 1).to_string())),
      ]),
    )
  }
  let request = record([
    ("operation", String("betweenness")),
    ("graph", record([("nodes", Array(nodes)), ("edges", Array(edges))])),
  ])
  let refused = try {
    let _ = run(request)
    false
  } catch {
    _ => true
  }
  assert_eq(refused, true)
}
