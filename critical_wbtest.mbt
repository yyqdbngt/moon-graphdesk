///|
fn critical_at(value : Value, keys : Array[String]) -> Value raise {
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
test "critical path prefers the heaviest chain" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"critical_path\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\",\"weight\":1}]}}",
      ),
    ),
  )
  assert_eq(critical_at(result, ["acyclic"]), from_json(@json.parse("true")))
  assert_eq(
    critical_at(result, ["nodes"]),
    from_json(@json.parse("[\"a\",\"b\"]")),
  )
  assert_eq(critical_at(result, ["edges"]), from_json(@json.parse("[\"ab\"]")))
  assert_eq(critical_at(result, ["weight"]), from_json(@json.parse("5")))
}

///|
test "critical path accumulates a longer chain over a heavy direct edge" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"critical_path\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":1},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\",\"weight\":1},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1.5}]}}",
      ),
    ),
  )
  assert_eq(
    critical_at(result, ["nodes"]),
    from_json(@json.parse("[\"a\",\"b\",\"c\"]")),
  )
  assert_eq(critical_at(result, ["weight"]), from_json(@json.parse("2")))
}

///|
test "critical path breaks ties by smallest chain" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"critical_path\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":1},{\"id\":\"bd\",\"from\":\"b\",\"to\":\"d\",\"weight\":1},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cd\",\"from\":\"c\",\"to\":\"d\",\"weight\":1}]}}",
      ),
    ),
  )
  assert_eq(
    critical_at(result, ["nodes"]),
    from_json(@json.parse("[\"a\",\"b\",\"d\"]")),
  )
  assert_eq(
    critical_at(result, ["edges"]),
    from_json(@json.parse("[\"ab\",\"bd\"]")),
  )
}

///|
test "critical path refuses cycles instead of guessing" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"critical_path\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"weight\":1}]}}",
      ),
    ),
  )
  assert_eq(critical_at(result, ["acyclic"]), from_json(@json.parse("false")))
  assert_eq(critical_at(result, ["weight"]), from_json(@json.parse("null")))
}

///|
test "critical path of an edgeless graph is the smallest node" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"critical_path\",\"graph\":{\"nodes\":[{\"id\":\"b\"},{\"id\":\"a\"}],\"edges\":[]}}",
      ),
    ),
  )
  assert_eq(critical_at(result, ["nodes"]), from_json(@json.parse("[\"a\"]")))
  assert_eq(critical_at(result, ["weight"]), from_json(@json.parse("0")))
}
