# Version 0.1.0 boundaries

An in-memory property graph. Shortest paths use O(V²) Dijkstra and reject negative weights. Components are sorted for reproducible output. Impact analysis follows incoming edges up to the requested depth (default 1). Critical paths are longest weighted chains on acyclic graphs only; cycles are refused rather than walked. No graph query language or disk database. Numeric weights use finite Double. Snapshots are JSON graph data validated again on import.
