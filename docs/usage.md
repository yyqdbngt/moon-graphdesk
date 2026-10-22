# Request and result guide

Every example below is an executable fixture. Assertions cover the listed result fields; additional output fields are documented by the API and other fixtures. Error cases intentionally reject the request.

## merge

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      }
    ]
  },
  "other": {
    "nodes": [
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "bc",
        "from": "b",
        "to": "c"
      }
    ]
  },
  "operation": "merge"
}
```

Expected result fields:

```json
{
  "nodes": 3,
  "edges": 2,
  "added_nodes": 1,
  "added_edges": 1,
  "graph": {
    "version": 1,
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bc",
        "from": "b",
        "to": "c"
      }
    ]
  }
}
```

Both inputs pass full import validation first. The union keeps identical shared payloads and refuses same-ID nodes or edges whose payloads differ structurally; added_nodes/added_edges count what the other side contributed, and the merged graph imports again.

## neighborhood

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bc",
        "from": "b",
        "to": "c"
      }
    ]
  },
  "operation": "neighborhood",
  "start": "a",
  "depth": 1
}
```

Expected result fields:

```json
{
  "visited": 2,
  "nodes": 2,
  "edges": 1,
  "distances": [
    {
      "id": "a",
      "distance": 0
    },
    {
      "id": "b",
      "distance": 1
    }
  ]
}
```

Breadth-first closure within depth hops from start (default 1, 0..100000 integer), then induced-subgraph export over exactly the visited set: only edges with both endpoints inside survive, node payloads are untouched, and the graph object imports again. reverse=true walks incoming edges for impact views; an optional edge_type restricts traversal.

## betweenness

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bc",
        "from": "b",
        "to": "c"
      }
    ]
  },
  "operation": "betweenness"
}
```

Expected result fields:

```json
{
  "scores": [
    {
      "id": "b",
      "score": 1
    },
    {
      "id": "a",
      "score": 0
    },
    {
      "id": "c",
      "score": 0
    }
  ]
}
```

Brandes unweighted betweenness over directed edges: the score counts how many ordered shortest-path pairs a node sits inside of, endpoints excluded. Scores sort descending with ascending-ID tie-breaks; an optional edge_type restricts edges. Inputs where nodes x (nodes + edges) exceeds 20,000,000 are refused before any work runs.

## weak_components

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bc",
        "from": "c",
        "to": "b"
      }
    ]
  },
  "operation": "weak_components"
}
```

Expected result fields:

```json
{
  "components": [
    [
      "a",
      "b",
      "c"
    ]
  ],
  "edge_direction": "ignored"
}
```

Connectivity treats every edge as undirected, so one-way and two-way links join the same component. Components are sorted internally and by first member, matching the strong-components report format.

## diff

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      }
    ],
    "edges": []
  },
  "other": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      }
    ]
  },
  "operation": "diff"
}
```

Expected result fields:

```json
{
  "identical": false,
  "nodes_added": [
    "b"
  ],
  "edges_added": [
    "ab"
  ],
  "changes": 2
}
```

`other` is compared against `graph` and both pass full import validation first. Added/removed are ID-set differences; a shared ID whose node or edge payload differs structurally is reported as changed, not removed and re-added. All lists are sorted and the changes field counts every entry.

## paths

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "d"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bd",
        "from": "b",
        "to": "d",
        "weight": 3
      }
    ]
  },
  "operation": "paths",
  "start": "a",
  "target": "d"
}
```

Expected result fields:

```json
{
  "count": 1,
  "truncated": false,
  "paths": [
    {
      "nodes": [
        "a",
        "b",
        "d"
      ],
      "edges": [
        "ab",
        "bd"
      ],
      "weight": 4
    }
  ]
}
```

Enumerates simple paths (no repeated nodes) depth-first in edge insertion order; every entry carries nodes, edge IDs and summed weight. An optional limit (integer 1..1000, default 10) truncates the listing and reports truncated=true when more paths exist. start == target yields the single trivial path. Enumeration is bounded by a one-million-step budget; path-poor dense graphs can exceed it and are refused instead of hanging.

## pagerank

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      }
    ]
  },
  "operation": "pagerank",
  "iterations": 100
}
```

Expected result fields:

```json
{
  "converged": true,
  "ranks": [
    {
      "id": "b",
      "rank": 0.6491228070313491
    },
    {
      "id": "a",
      "rank": 0.35087719296865083
    }
  ]
}
```

Ranks are unweighted and sorted descending with ascending-ID tie-breaks for exactly equal values; ranks separated only by floating-point noise may order differently across builds. Dangling nodes spread their rank uniformly over all nodes, so total mass stays 1. Optional damping (0..1, default 0.85), iterations (integer 1..100, default 20) and tolerance ((0, 1], default 1e-10) control the run; converged reports whether the total change dropped below tolerance.

## degree

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "bb",
        "from": "b",
        "to": "b"
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b"
      }
    ]
  },
  "operation": "degree"
}
```

Expected result fields:

```json
{
  "max_total": [
    "b"
  ],
  "min_total": [
    "a",
    "c"
  ],
  "average_total": 2,
  "self_loops": 1
}
```

Every node reports `in`, `out` and `total` incidence in ID order; a self-loop counts once in each direction. `max_total`/`min_total` list all nodes sharing the extreme total, and an optional `edge_type` restricts the count to typed edges.

## subgraph

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b"
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c"
      }
    ]
  },
  "operation": "subgraph",
  "nodes": [
    "a",
    "c"
  ]
}
```

Expected result fields:

```json
{
  "nodes": 2,
  "edges": 1,
  "graph": {
    "version": 1,
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ac",
        "from": "a",
        "to": "c"
      }
    ]
  }
}
```

Exactly one of `nodes` (explicit ID list, all must exist) or `query` (same type/property selection as the select operation) is required. Only edges with both endpoints kept survive, node data is unchanged, and the exported `graph` object is a valid import payload again.

## critical path

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b",
        "weight": 5
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c",
        "weight": 1
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b",
        "weight": 1
      }
    ]
  },
  "operation": "critical_path"
}
```

Expected result fields:

```json
{
  "acyclic": true,
  "nodes": [
    "a",
    "b"
  ],
  "edges": [
    "ab"
  ],
  "weight": 5
}
```

Cyclic graphs return `"acyclic": false` with empty nodes/edges and null weight instead of guessing a longest walk. Equal-weight chains resolve to the lexicographically smallest chain. An optional `edge_type` restricts the edges considered.

## weighted shortest path

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      },
      {
        "id": "d"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b",
        "weight": 5
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c",
        "weight": 1
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b",
        "weight": 1
      },
      {
        "id": "ba",
        "from": "b",
        "to": "a",
        "weight": 1
      }
    ]
  },
  "operation": "path",
  "start": "a",
  "target": "b"
}
```

Expected result fields:

```json
{
  "cost": 2,
  "nodes": [
    "a",
    "c",
    "b"
  ]
}
```

## unreachable

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      },
      {
        "id": "d"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b",
        "weight": 5
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c",
        "weight": 1
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b",
        "weight": 1
      },
      {
        "id": "ba",
        "from": "b",
        "to": "a",
        "weight": 1
      }
    ]
  },
  "operation": "path",
  "start": "a",
  "target": "d"
}
```

Expected result fields:

```json
{
  "reachable": false
}
```

## cycle and isolated

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      },
      {
        "id": "d"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b",
        "weight": 5
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c",
        "weight": 1
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b",
        "weight": 1
      },
      {
        "id": "ba",
        "from": "b",
        "to": "a",
        "weight": 1
      }
    ]
  }
}
```

Expected result fields:

```json
{
  "nodes": 4,
  "edges": 4,
  "isolated": [
    "d"
  ]
}
```

## components

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      },
      {
        "id": "b"
      },
      {
        "id": "c"
      },
      {
        "id": "d"
      }
    ],
    "edges": [
      {
        "id": "ab",
        "from": "a",
        "to": "b",
        "weight": 5
      },
      {
        "id": "ac",
        "from": "a",
        "to": "c",
        "weight": 1
      },
      {
        "id": "cb",
        "from": "c",
        "to": "b",
        "weight": 1
      },
      {
        "id": "ba",
        "from": "b",
        "to": "a",
        "weight": 1
      }
    ]
  },
  "operation": "components"
}
```

Expected result fields:

```json
{
  "components": [
    [
      "a",
      "b",
      "c"
    ],
    [
      "d"
    ]
  ]
}
```

## negative weights

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      }
    ],
    "edges": [
      {
        "id": "e",
        "from": "a",
        "to": "a",
        "weight": -1
      }
    ]
  }
}
```

Expected: nonzero exit with an input error.

## invalid endpoints

```json
{
  "graph": {
    "nodes": [
      {
        "id": "a"
      }
    ],
    "edges": [
      {
        "id": "e",
        "from": "a",
        "to": "missing"
      }
    ]
  }
}
```

Expected: nonzero exit with an input error.
