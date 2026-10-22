///|
fn pagerank_at(value : Value, keys : Array[String]) -> Value raise {
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
fn rank_number(value : Value, id : String) -> Double raise {
  let ranks = match pagerank_at(value, ["ranks"]) {
    Array(items) => items
    _ => raise InputError("ranks missing")
  }
  for entry in ranks {
    if get(entry, "id") == String(id) {
      match get(entry, "rank") {
        Number(n) => return n
        _ => raise InputError("rank missing")
      }
    }
  }
  raise InputError("id not ranked: " + id)
}

///|
test "one pagerank iteration matches the closed form" {
  // a -> b with b dangling: first update gives exact hand-computed values.
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"pagerank\",\"iterations\":1,\"damping\":0.85,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"}]}}",
      ),
    ),
  )
  assert_eq(pagerank_at(result, ["iterations"]), from_json(@json.parse("1")))
  assert_eq(
    pagerank_at(result, ["ranks", "0", "id"]),
    from_json(@json.parse("\"b\"")),
  )
  assert_eq(rank_number(result, "a"), 0.2875)
  let b_drift = rank_number(result, "b") - 0.7125
  let b_drift = if b_drift < 0.0 { -b_drift } else { b_drift }
  assert_eq(b_drift < 0.000000000001, true)
}

///|
test "pagerank converges with dangling mass kept in the system" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"pagerank\",\"iterations\":100,\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"}]}}",
      ),
    ),
  )
  assert_eq(pagerank_at(result, ["converged"]), from_json(@json.parse("true")))
  let total = rank_number(result, "a") +
    rank_number(result, "b") +
    rank_number(result, "c")
  let drift = if total - 1.0 < 0.0 { -(total - 1.0) } else { total - 1.0 }
  assert_eq(drift < 0.000000001, true)
  // The chain tail ranks first: it receives from b and its own dangling mass
  // is spread uniformly back into the system, including to itself.
  assert_eq(
    pagerank_at(result, ["ranks", "0", "id"]),
    from_json(@json.parse("\"c\"")),
  )
}

///|
test "pagerank rejects out-of-contract parameters" {
  let refused = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"pagerank\",\"damping\":1.5,\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(refused, true)
  let fractional = try {
    let _ = run(
      from_json(
        @json.parse(
          "{\"operation\":\"pagerank\",\"iterations\":2.5,\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[]}}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_eq(fractional, true)
}

///|
test "pagerank of an empty graph is trivially converged" {
  let result = run(
    from_json(
      @json.parse(
        "{\"operation\":\"pagerank\",\"graph\":{\"nodes\":[],\"edges\":[]}}",
      ),
    ),
  )
  assert_eq(pagerank_at(result, ["ranks"]), from_json(@json.parse("[]")))
  assert_eq(pagerank_at(result, ["converged"]), from_json(@json.parse("true")))
}
