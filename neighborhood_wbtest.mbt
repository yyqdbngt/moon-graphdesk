///|
fn neighborhood_at(value : Value, keys : Array[String]) -> Value raise {
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
test "neighborhood bounds hops and exports the induced subgraph" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"neighborhood\",\"start\":\"a\",\"depth\":1,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"},{\"id\":\"ad\",\"from\":\"a\",\"to\":\"d\"}]}}",
      ),
    ),
  )
  assert_eq(neighborhood_at(result, ["visited"]), from_json(@json.parse("3")))
  assert_eq(neighborhood_at(result, ["edges"]), from_json(@json.parse("2")))
  assert_eq(
    neighborhood_at(result, ["graph", "nodes", "2", "id"]),
    from_json(@json.parse("\"d\"")),
  )
  // The exported graph imports again and keeps the boundary edges only.
  let reloaded = run(
    from_json(
      @json.parse(
        "{\"operation\":\"summary\",\"graph\":" +
        neighborhood_at(result, ["graph"]).stringify() +
        "}",
      ),
    ),
  )
  assert_eq(neighborhood_at(reloaded, ["nodes"]), from_json(@json.parse("3")))
  assert_eq(neighborhood_at(reloaded, ["edges"]), from_json(@json.parse("2")))
}

///|
test "neighborhood reverse follows incoming impact" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"neighborhood\",\"start\":\"c\",\"depth\":1,\"reverse\":true,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"}]}}",
      ),
    ),
  )
  assert_eq(neighborhood_at(result, ["visited"]), from_json(@json.parse("2")))
  assert_eq(
    neighborhood_at(result, ["distances", "0"]),
    from_json(@json.parse("{\"id\":\"c\",\"distance\":0}")),
  )
  assert_eq(
    neighborhood_at(result, ["distances", "1", "id"]),
    from_json(@json.parse("\"b\"")),
  )
}

///|
test "neighborhood depth zero keeps only the start" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"neighborhood\",\"start\":\"a\",\"depth\":0,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"}]}}",
      ),
    ),
  )
  assert_eq(neighborhood_at(result, ["visited"]), from_json(@json.parse("1")))
  assert_eq(neighborhood_at(result, ["edges"]), from_json(@json.parse("0")))
}

///|
test "neighborhood rejects unknown start and bad depth" {
  let unknown = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"neighborhood\",\"start\":\"missing\",\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(unknown, true)
  let fractional = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"neighborhood\",\"start\":\"a\",\"depth\":1.5,\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(fractional, true)
}
