///|
fn weak_at(value : Value, keys : Array[String]) -> Value raise {
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
test "weak components ignore edge direction" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"weak_components\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"},{\"id\":\"e\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\"},{\"id\":\"de\",\"from\":\"d\",\"to\":\"e\"}]}}",
      ),
    ),
  )
  assert_eq(
    weak_at(result, ["components"]),
    from_json(@json.parse("[[\"a\",\"b\",\"c\"],[\"d\",\"e\"]]")),
  )
}

///|
test "weak components merge strongly separated pairs" {
  // a -> b -> a is one strong component already; a <- c joins it weakly.
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"weak_components\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\"},{\"id\":\"ca\",\"from\":\"c\",\"to\":\"a\"}]}}",
      ),
    ),
  )
  assert_eq(
    weak_at(result, ["components"]),
    from_json(@json.parse("[[\"a\",\"b\",\"c\"]]")),
  )
}
