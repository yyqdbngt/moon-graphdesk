///|
fn paths_at(value : Value, keys : Array[String]) -> Value raise {
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
fn diamond_request(extra : String) -> Value raise {
  from_json(
    @json.parse(
      "{\"operation\":\"paths\",\"start\":\"a\",\"target\":\"d\",\"limit\":10,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\"},{\"id\":\"bd\",\"from\":\"b\",\"to\":\"d\"},{\"id\":\"cd\",\"from\":\"c\",\"to\":\"d\"}" +
      extra +
      "]}}",
    ),
  )
}

///|
test "simple paths enumerate a diamond in discovery order" {
  let result = run(diamond_request(""))
  assert_eq(paths_at(result, ["count"]), from_json(@json.parse("2")))
  assert_eq(paths_at(result, ["truncated"]), from_json(@json.parse("false")))
  assert_eq(
    paths_at(result, ["paths", "0"]),
    from_json(
      @json.parse(
        "{\"nodes\":[\"a\",\"b\",\"d\"],\"edges\":[\"ab\",\"bd\"],\"weight\":2}",
      ),
    ),
  )
  assert_eq(
    paths_at(result, ["paths", "1", "nodes"]),
    from_json(@json.parse("[\"a\",\"c\",\"d\"]")),
  )
}

///|
test "paths limit truncates and reports honestly" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"paths\",\"start\":\"a\",\"target\":\"d\",\"limit\":1,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\"},{\"id\":\"bd\",\"from\":\"b\",\"to\":\"d\"},{\"id\":\"cd\",\"from\":\"c\",\"to\":\"d\"}]}}",
      ),
    ),
  )
  assert_eq(paths_at(result, ["count"]), from_json(@json.parse("1")))
  assert_eq(paths_at(result, ["truncated"]), from_json(@json.parse("true")))
}

///|
test "cycles cannot loop simple paths" {
  let result = run(
    diamond_request(",{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\"}"),
  )
  assert_eq(paths_at(result, ["count"]), from_json(@json.parse("2")))
}

///|
test "parallel edges produce distinct paths" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"paths\",\"start\":\"a\",\"target\":\"b\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"}],\"edges\":[{\"id\":\"e1\",\"from\":\"a\",\"to\":\"b\",\"weight\":2},{\"id\":\"e2\",\"from\":\"a\",\"to\":\"b\",\"weight\":3}]}}",
      ),
    ),
  )
  assert_eq(paths_at(result, ["count"]), from_json(@json.parse("2")))
  assert_eq(
    paths_at(result, ["paths", "0", "weight"]),
    from_json(@json.parse("2")),
  )
  assert_eq(
    paths_at(result, ["paths", "1", "weight"]),
    from_json(@json.parse("3")),
  )
}

///|
test "start equals target yields the trivial path" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"paths\",\"start\":\"a\",\"target\":\"a\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"}]}}",
      ),
    ),
  )
  assert_eq(paths_at(result, ["count"]), from_json(@json.parse("1")))
  assert_eq(
    paths_at(result, ["paths", "0"]),
    from_json(@json.parse("{\"nodes\":[\"a\"],\"edges\":[],\"weight\":0}")),
  )
}

///|
test "paths reject unknown endpoints" {
  let refused = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"paths\",\"start\":\"a\",\"target\":\"missing\",\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(refused, true)
}
