///|
fn followup_at(value : Value, keys : Array[String]) -> Value raise {
  let mut current=value
  for key in keys { current=match current { Object(fields)=>fields[key]; Array(items)=> { let index=match @json.parse(key) { Json::Number(n, ..)=>n.to_int(); _=>raise InputError("invalid test index") }; items[index] }; _=>raise InputError("invalid test path") } }
  current
}

///|
test "followup parallel topology layers" {
  let result=run(from_json(@json.parse("{\"operation\":\"topology\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"}]}}")))
  assert_eq(followup_at(result,["acyclic"]),from_json(@json.parse("true")))
  assert_eq(followup_at(result,["layers"]),from_json(@json.parse("[[\"a\",\"d\"],[\"b\"],[\"c\"]]")))
  assert_eq(followup_at(result,["blocked"]),from_json(@json.parse("[]")))
}

///|
test "followup cycle downstream blocking" {
  let result=run(from_json(@json.parse("{\"operation\":\"topology\",\"graph\":{\"nodes\":[{\"id\":\"a\"},{\"id\":\"b\"},{\"id\":\"c\"},{\"id\":\"d\"}],\"edges\":[{\"id\":\"ab\",\"from\":\"a\",\"to\":\"b\"},{\"id\":\"bc\",\"from\":\"b\",\"to\":\"c\"},{\"id\":\"ba\",\"from\":\"b\",\"to\":\"a\"}]}}")))
  assert_eq(followup_at(result,["acyclic"]),from_json(@json.parse("false")))
  assert_eq(followup_at(result,["blocked"]),from_json(@json.parse("[\"a\",\"b\",\"c\"]")))
  assert_eq(followup_at(result,["cycles"]),from_json(@json.parse("[[\"a\",\"b\"]]")))
  assert_eq(followup_at(result,["order"]),from_json(@json.parse("[\"d\"]")))
}

///|
test "followup self loop block" {
  let result=run(from_json(@json.parse("{\"operation\":\"topology\",\"graph\":{\"nodes\":[{\"id\":\"a\"}],\"edges\":[{\"id\":\"aa\",\"from\":\"a\",\"to\":\"a\"}]}}")))
  assert_eq(followup_at(result,["acyclic"]),from_json(@json.parse("false")))
  assert_eq(followup_at(result,["cycles"]),from_json(@json.parse("[[\"a\"]]")))
}

///|
test "followup empty topology" {
  let result=run(from_json(@json.parse("{\"operation\":\"topology\",\"graph\":{\"nodes\":[],\"edges\":[]}}")))
  assert_eq(followup_at(result,["acyclic"]),from_json(@json.parse("true")))
  assert_eq(followup_at(result,["layers"]),from_json(@json.parse("[]")))
}
