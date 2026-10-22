///|
fn merge_at(value : Value, keys : Array[String]) -> Value raise {
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
fn merge_graph(nodes : String, edges : String) -> Value raise {
  from_json(
    @json.parse("{\"nodes\":[" + nodes + "],\"edges\":[" + edges + "]}"),
  )
}

///|
test "merge unions disjoint and overlapping graphs" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"merge\",\"other\":" +
        merge_graph(
          "{\"id\":\"b\"},{\"id\":\"c\"}", "{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"}",
        ).stringify() +
        ",\"graph\":" +
        merge_graph(
          "{\"id\":\"a\"},{\"id\":\"b\"}", "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"}",
        ).stringify() +
        "}",
      ),
    ),
  )
  assert_eq(merge_at(result, ["nodes"]), from_json(@json.parse("3")))
  assert_eq(merge_at(result, ["edges"]), from_json(@json.parse("2")))
  assert_eq(merge_at(result, ["added_nodes"]), from_json(@json.parse("1")))
  assert_eq(merge_at(result, ["added_edges"]), from_json(@json.parse("1")))
  let reloaded = run(
    from_json(
      @json.parse(
        "{\"operation\":\"summary\",\"graph\":" +
        merge_at(result, ["graph"]).stringify() +
        "}",
      ),
    ),
  )
  assert_eq(merge_at(reloaded, ["nodes"]), from_json(@json.parse("3")))
  assert_eq(merge_at(reloaded, ["edges"]), from_json(@json.parse("2")))
}

///|
test "merge refuses conflicting payloads" {
  let base = merge_graph("{\"id\":\"a\"}", "").stringify()
  let node_conflict = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"merge\",\"graph\":" +
          base +
          ",\"other\":" +
          merge_graph("{\"id\":\"a\",\"type\":\"svc\"}", "").stringify() +
          "}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(node_conflict, true)
  let edge_conflict = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"merge\",\"graph\":" +
          merge_graph(
            "{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}", "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"}",
          ).stringify() +
          ",\"other\":" +
          merge_graph(
            "{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}", "{\"id\":\"ab\",\"from\":\"a\",\"to\":\"c\"}",
          ).stringify() +
          "}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(edge_conflict, true)
}
