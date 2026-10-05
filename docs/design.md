# Implemented architecture

## Core

Node/edge/property import with identity and endpoint checks; outgoing and incoming indexes; typed/property selection; depth-limited forward and reverse traversal; nonnegative weighted shortest paths; iterative strongly connected components; cycles/isolated-node summaries; snapshots.

## Boundaries

An in-memory property graph. Shortest paths use O(V²) Dijkstra and reject negative weights. Components are sorted for reproducible output. Impact analysis follows incoming edges up to the requested depth (default 1). No graph query language or disk database. Numeric weights use finite Double. Snapshots are JSON graph data validated again on import.

## Integration

The core accepts semantic values and returns deterministic JSON-shaped reports. Host adapters handle files, network or processes; they invoke the compiled MoonBit engine. The CLI package declares `supported_targets = "js"`; other backends test the portable core.

## Validation evidence

Fixture cases are hand-checked assertions. Independent reference checks and integration scripts are runnable from a clean checkout. CI executes four core backends and host checks. Historical proposal targets are not release results.
