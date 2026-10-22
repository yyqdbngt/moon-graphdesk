///|
fn diff_at(value : Value, keys : Array[String]) -> Value raise {
  let mut current = value
  for key in keys {
    current = match current {
      Object(fields) => fields[key]
      _ => raise InputError("invalid test path")
    }
  }
  current
}

///|
fn diff_graph(nodes : String, edges : String) -> Value raise {
  from_json(
    @json.parse("{\"nodes\":[" + nodes + "],\"edges\":[" + edges + "]}"),
  )
}

///|
test "diff reports additions, removals and payload changes" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"diff\",\"other\":" +
        diff_graph(
          "{\"id\":\"a\",\"type\":\"service\"},{\"id\":\"b\"},{\"id\":\"new\"}",
          "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"an\",\"from\":\"a\",\"to\":\"new\"}",
        ).stringify() +
        ",\"graph\":" +
        diff_graph(
          "{\"id\":\"a\"},{\"id\":\"c\"}", "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"c\"}",
        ).stringify() +
        "}",
      ),
    ),
  )
  assert_eq(
    diff_at(result, ["nodes_added"]),
    from_json(@json.parse("[\"b\",\"new\"]")),
  )
  assert_eq(
    diff_at(result, ["nodes_removed"]),
    from_json(@json.parse("[\"c\"]")),
  )
  assert_eq(
    diff_at(result, ["nodes_changed"]),
    from_json(@json.parse("[\"a\"]")),
  )
  assert_eq(
    diff_at(result, ["edges_added"]),
    from_json(@json.parse("[\"an\"]")),
  )
  assert_eq(diff_at(result, ["edges_removed"]), from_json(@json.parse("[]")))
  assert_eq(
    diff_at(result, ["edges_changed"]),
    from_json(@json.parse("[\"ab\"]")),
  )
  assert_eq(diff_at(result, ["identical"]), from_json(@json.parse("false")))
  assert_eq(diff_at(result, ["changes"]), from_json(@json.parse("6")))
}

///|
test "diff of equal snapshots is identical" {
  let snapshot = diff_graph(
    "{\"id\":\"a\"},{\"id\":\"b\"}", "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\",\"weight\":2}",
  )
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"diff\",\"other\":" +
        snapshot.stringify() +
        ",\"graph\":" +
        snapshot.stringify() +
        "}",
      ),
    ),
  )
  assert_eq(diff_at(result, ["identical"]), from_json(@json.parse("true")))
  assert_eq(diff_at(result, ["changes"]), from_json(@json.parse("0")))
}

///|
test "diff requires a second importable graph" {
  let refused = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"diff\",\"graph\":" +
          diff_graph("{\"id\":\"a\"}", "").stringify() +
          ",\"other\":{\"nodes\":[{\"id\":\"b\"}],\"edges\":[{\"id\":\"x\",\"from\":\"b\",\"to\":\"missing\"}]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(refused, true)
}
