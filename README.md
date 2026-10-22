# Moon GraphDesk

Property graph queries, implemented in MoonBit with a JSON CLI and reusable library API.

- Repository: [https://github.com/yyqdbngt/moon-graphdesk](https://github.com/yyqdbngt/moon-graphdesk)
- Package: `yyqdbngt/moon_graphdesk@0.3.0`
- License: Apache-2.0
- Release scope: **0.1.0 initial implementation**. The broader competition proposal in `docs/proposal.md` is a reference design, not a claim that every planned capability is implemented.

## Implemented

Node/edge/property import with identity and endpoint checks; outgoing and incoming indexes; typed/property selection; depth-limited forward and reverse traversal; nonnegative weighted shortest paths; iterative strongly connected components; cycles/isolated-node summaries; snapshots; topology layers with cycle-blocked descendants; longest weighted critical paths on DAGs with deterministic tie-breaking; induced subgraph export by ID list or typed query; per-node degree reports with typed filtering, extremes and self-loop counts; PageRank centrality with dangling-mass redistribution; capped simple-path enumeration between two nodes; structural diff of two validated graphs; undirected weak-component reports; Brandes betweenness centrality with an explicit work budget; k-hop neighborhood export with hop distances.

## Build and run

Use MoonBit and Node.js 24. The core library supports JS, wasm, wasm-gc and native; the filesystem/HTTP/process CLI is JS only.

```sh
moon update
moon build --target js
moon run cmd/main --target js -- examples/scenario-1.json
node _build/js/debug/build/cmd/main/main.js examples/scenario-1.json
```

Pass `-` to read a UTF-8 JSON request from stdin. A single request must be at most 16 MiB, at most 65,536 nodes and 262,144 edges, and node/edge IDs are 1..256 characters. Successful requests print one JSON result; invalid requests exit nonzero. The host runner is a separate process and does not edit the input request file.

## Library use

```sh
moon add yyqdbngt/moon_graphdesk@0.3.0
```

In the consumer's `moon.pkg`:

```moonbit
import {
  "yyqdbngt/moon_graphdesk" @engine,
  "moonbitlang/core/json",
}
```

```moonbit
fn example(request : Json) -> Json raise {
  @engine.execute(request)
}
```

`execute(Json) -> Json raise` is the standard JSON boundary. `from_json`, `Value::to_json`, and `run(Value) -> Value raise` provide a typed semantic value interface. Object ordering is not significant; numeric values use finite Double. Public domain functions are listed in `pkg.generated.mbti`.

## Tests

```sh
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon test --target native  # requires a C compiler
moon build --target js
moon fmt --check
moon info
node scripts/check.mjs
python -B scripts/reference.py
python -B scripts/critical_reference.py
python -B scripts/subgraph_reference.py
python -B scripts/degree_reference.py
python -B scripts/scale_reference.py
python -B scripts/pagerank_reference.py
python -B scripts/paths_reference.py
python -B scripts/diff_reference.py
python -B scripts/weak_reference.py
python -B scripts/betweenness_reference.py
python -B scripts/neighborhood_reference.py
```

There are 27 checked fixture cases in `tests/cases.json`, executed both in MoonBit white-box tests and through the actual Node CLI. Independent reference checks use Python's standard library or separately written algorithms. Fixtures are synthetic and are not presented as production adoption evidence. See [input and output examples](docs/usage.md) and [current boundaries](docs/boundaries.md).

## Current boundaries

An in-memory property graph. Shortest paths use O(V²) Dijkstra and reject negative weights. Components are sorted for reproducible output. Impact analysis follows incoming edges up to the requested depth (default 1). No graph query language or disk database. Numeric weights use finite Double. Snapshots are JSON graph data validated again on import.

See [source and dependency attribution](THIRD_PARTY.md). This release does not establish competition eligibility or organizer acceptance.


## 2026-10-18 follow-up

新增 topology，按 prerequisite→dependent 的边方向计算拓扑层次与可执行前缀，报告环组件及被环阻塞的下游节点。平行边按实际入度计数，孤立节点进入首层；遇到环不伪造完整拓扑序。修复遍历深度的小数截断及过大参数。

拓扑以输入图边方向为准，不自动猜测业务依赖方向。环和阻塞报告不负责修改关系；最短路径仍使用非负权 Dijkstra 的内存实现。

Repository release: 0.2.0; installable MoonCakes module: `yyqdbngt/moon_graphdesk@0.2.0`. Earlier repository 1.0.0 labels are retained as history; the module uses the registry-compatible zero-major sequence.

Current source contains 12 MoonBit test declarations and 10 CLI fixtures (generated fixture tests are included in the declaration count). Run `python -B scripts/followup_reference.py` for independent follow-up oracles and `examples/followup-20261018.json` for the new scenario.

## 2026-10-22 follow-up

新增 critical_path（DAG 最长加权路径，环拒绝）、subgraph（按 ID 列表或类型/属性查询导出诱导子图，可再导入）与 degree（入/出/总度数、极值、自环统计，可选 edge_type）。最短路改为二叉堆 Dijkstra（O((V+E)logV)，平局裁决不变）。输入硬化：65,536 节点 / 262,144 边 / ID 1..256 字符上限，空边 ID 拒绝。全部编译告警清零；CI 增加 fmt 检查、接口清单新鲜度检查与中规模独立算法冒烟门（scripts/scale_reference.py）。

Repository release: 0.3.0; installable MoonCakes module: `yyqdbngt/moon_graphdesk@0.3.0`.
