# Request and result guide

Every example below is an executable fixture. Assertions cover the listed result fields; additional output fields are documented by the API and other fixtures. Error cases intentionally reject the request.

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
