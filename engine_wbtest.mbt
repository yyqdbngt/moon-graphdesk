///|
fn test_at(value : Value, parts : Array[String]) -> Value raise {
  let mut current = value
  for part in parts {
    current = match current {
      Object(fields) =>
        match fields.get(part) {
          Some(v) => v
          None => raise InputError("test key missing: " + part)
        }
      Array(items) => items[num(parse_value(part)).to_int()]
      _ => raise InputError("invalid test traversal")
    }
  }
  current
}

///|
test "weighted shortest path" {
  let result = run(
    parse_value(
      "{\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\",\"weight\":1},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"weight\":1}]},\"operation\":\"path\",\"start\":\"a\",\"target\":\"b\"}",
    ),
  )
  assert_eq(test_at(result, ["cost"]), parse_value("2"))
  assert_eq(test_at(result, ["nodes"]), parse_value("[\"a\",\"c\",\"b\"]"))
}

///|
test "unreachable" {
  let result = run(
    parse_value(
      "{\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\",\"weight\":1},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"weight\":1}]},\"operation\":\"path\",\"start\":\"a\",\"target\":\"d\"}",
    ),
  )
  assert_eq(test_at(result, ["reachable"]), parse_value("false"))
}

///|
test "cycle and isolated" {
  let result = run(
    parse_value(
      "{\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\",\"weight\":1},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"weight\":1}]}}",
    ),
  )
  assert_eq(test_at(result, ["nodes"]), parse_value("4"))
  assert_eq(test_at(result, ["edges"]), parse_value("4"))
  assert_eq(test_at(result, ["isolated"]), parse_value("[\"d\"]"))
}

///|
test "components" {
  let result = run(
    parse_value(
      "{\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":5},{\"id\":\"ac\",\"from\":\"a\",\"to\":\"c\",\"weight\":1},{\"id\":\"cb\",\"from\":\"c\",\"to\":\"b\",\"weight\":1},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\",\"weight\":1}]},\"operation\":\"components\"}",
    ),
  )
  assert_eq(
    test_at(result, ["components"]),
    parse_value("[[\"a\",\"b\",\"c\"],[\"d\"]]"),
  )
}

///|
test "negative weights" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[{\"id\":\"e\",\"from\":\"a\",\"to\":\"a\",\"weight\":-1}]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "invalid endpoints" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[{\"id\":\"e\",\"from\":\"a\",\"to\":\"missing\"}]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
