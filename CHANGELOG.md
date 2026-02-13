## 0.1.0

- Initial release
- **CozoDatabase** — Open/close databases (in-memory & SQLite), execute mutable and immutable Datalog queries, parameterized queries, export/import relations, backup/restore, system operations (list/remove/rename relations, describe, compact, etc.)
- **CozoGraph** — 15+ graph algorithms: PageRank, BFS, DFS, shortest path (BFS/Dijkstra/A\*), community detection (Louvain, label propagation), connected components, strongly connected components, betweenness/closeness centrality, minimum spanning tree, topological sort, random walk, degree centrality
- **CozoVectorSearch** — HNSW index creation, vector upsert, k-NN search with optional filters
- **CozoTextSearch** — Full-text search (FTS with BM25 ranking), LSH similarity search
- **CozoUtils** — Reorder/sort/paginate, CSV reading, JSON reading
- **CozoResult** — Structured result type with `toMaps()`, `column()`, `firstOrNull`
- **CozoException** — Typed exceptions for query and database errors
- Cross-platform support: Android, iOS, macOS, Linux, Windows
