///|
fn degree_at(value : Value, keys : Array[String]) -> Value raise {
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
test "degree reports per-node incidence with extremes and self-loops" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"degree\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bb\",\"from\":\"b\",\"to\":\"b\"},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\"}]}}",
      ),
    ),
  )
  assert_eq(
    degree_at(result, ["nodes", "0"]),
    from_json(@json.parse("{\"id\":\"a\",\"in\":0,\"out\":1,\"total\":1}")),
  )
  assert_eq(
    degree_at(result, ["nodes", "1"]),
    from_json(@json.parse("{\"id\":\"b\",\"in\":3,\"out\":1,\"total\":4}")),
  )
  assert_eq(degree_at(result, ["max_total"]), from_json(@json.parse("[\"b\"]")))
  assert_eq(
    degree_at(result, ["min_total"]),
    from_json(@json.parse("[\"a\",\"c\"]")),
  )
  assert_eq(degree_at(result, ["self_loops"]), from_json(@json.parse("1")))
  assert_eq(degree_at(result, ["average_total"]), from_json(@json.parse("2")))
}

///|
test "degree honors the edge type filter" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"degree\",\"edge_type\":\"dep\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"type\":\"dep\"},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"type\":\"call\"}]}}",
      ),
    ),
  )
  assert_eq(
    degree_at(result, ["nodes", "0"]),
    from_json(@json.parse("{\"id\":\"a\",\"in\":0,\"out\":1,\"total\":1}")),
  )
  assert_eq(
    degree_at(result, ["nodes", "1"]),
    from_json(@json.parse("{\"id\":\"b\",\"in\":1,\"out\":0,\"total\":1}")),
  )
  assert_eq(degree_at(result, ["self_loops"]), from_json(@json.parse("0")))
}

///|
test "degree of an empty graph is well-defined" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"degree\",\"graph\":{\"nodes\":[],\"edges\":[]}}",
      ),
    ),
  )
  assert_eq(degree_at(result, ["nodes"]), from_json(@json.parse("[]")))
  assert_eq(degree_at(result, ["max_total"]), from_json(@json.parse("[]")))
  assert_eq(degree_at(result, ["average_total"]), from_json(@json.parse("0")))
}
