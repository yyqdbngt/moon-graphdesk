///|
test "fractional traversal depth is rejected" {
  let graph = record([
    ("nodes", Array([record([("id", String("a"))])])),
    ("edges", Array([])),
  ])
  let bad = try {
    ignore(
      run(
        record([
          ("graph", graph),
          ("operation", String("neighbors")),
          ("start", String("a")),
          ("depth", Number(0.5)),
        ]),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
test "zero traversal depth remains valid" {
  let graph = record([
    ("nodes", Array([record([("id", String("a"))])])),
    ("edges", Array([])),
  ])
  ignore(
    run(
      record([
        ("graph", graph),
        ("operation", String("neighbors")),
        ("start", String("a")),
        ("depth", Number(0.0)),
      ]),
    ),
  )
}
