///|
fn subgraph_at(value : Value, keys : Array[String]) -> Value raise {
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
test "subgraph keeps internal edges and drops crossing ones" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"subgraph\",\"nodes\":[\"a\",\"c\"],\"graph\":{\"nodes\":[{\"id\":\"a\",\"type\":\"core\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\"}]}}",
      ),
    ),
  )
  assert_eq(subgraph_at(result, ["nodes"]), from_json(@json.parse("2")))
  assert_eq(subgraph_at(result, ["edges"]), from_json(@json.parse("1")))
  assert_eq(
    subgraph_at(result, ["graph", "nodes", "1", "id"]),
    from_json(@json.parse("\"c\"")),
  )
  assert_eq(
    subgraph_at(result, ["graph", "edges", "0", "id"]),
    from_json(@json.parse("\"ac\"")),
  )
  // The exported graph is a valid load_graph input again.
  let reloaded = run(
    from_json(
      @json.parse(
        "{\"operation\":\"summary\",\"graph\":" +
        subgraph_at(result, ["graph"]).stringify() +
        "}",
      ),
    ),
  )
  assert_eq(subgraph_at(reloaded, ["nodes"]), from_json(@json.parse("2")))
  assert_eq(subgraph_at(reloaded, ["edges"]), from_json(@json.parse("1")))
}

///|
test "subgraph by query keeps typed nodes only" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"subgraph\",\"query\":{\"type\":\"service\"},\"graph\":{\"nodes\":[{\"id\":\"a\",\"type\":\"service\"},{\"id\":\"b\",\"type\":\"library\"},{\"id\":\"c\",\"type\":\"service\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\"}]}}",
      ),
    ),
  )
  assert_eq(subgraph_at(result, ["nodes"]), from_json(@json.parse("2")))
  assert_eq(subgraph_at(result, ["edges"]), from_json(@json.parse("1")))
  assert_eq(
    subgraph_at(result, ["graph", "nodes", "1", "id"]),
    from_json(@json.parse("\"c\"")),
  )
}

///|
test "subgraph rejects unknown and duplicate ids" {
  let base = "{\"operation\":\"subgraph\",\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]},"
  let unknown = try {
    let _ = run(from_json(@json.parse(base + "\"nodes\":[\"missing\"]}")))
    false
  } catch {
    _ => true
  }
  assert_eq(unknown, true)
  let duplicate = try {
    let _ = run(from_json(@json.parse(base + "\"nodes\":[\"a\",\"a\"]}")))
    false
  } catch {
    _ => true
  }
  assert_eq(duplicate, true)
  let both = try {
    let _ = run(
      from_json(@json.parse(base + "\"nodes\":[\"a\"],\"query\":{}}")),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(both, true)
}
