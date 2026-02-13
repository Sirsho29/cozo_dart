# cozo_dart

A Dart/Flutter package for [CozoDB](https://github.com/cozodb/cozo) — an embedded transactional relational-graph-vector database with Datalog queries, 15+ graph algorithms, HNSW vector search, full-text search, LSH similarity, and time-travel.

[![pub package](https://img.shields.io/pub/v/cozo_dart.svg)](https://pub.dev/packages/cozo_dart)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

## Features

- **Embedded database** — runs locally with zero network, no server needed
- **Datalog queries** — powerful recursive queries via CozoScript
- **15+ graph algorithms** — PageRank, shortest paths, community detection, centrality, MST, topological sort, random walk
- **HNSW vector search** — approximate nearest neighbor on-device with hybrid Datalog filters
- **Full-text search** — BM25-ranked keyword search with tokenizers, stemming, and stopword filters
- **LSH similarity** — MinHash / Jaccard near-duplicate detection
- **ACID transactions** — full transactional guarantees
- **Persistent storage** — SQLite backend for durable on-device data
- **Cross-platform** — Android, iOS, macOS, Linux, Windows

## Installation

```yaml
dependencies:
  cozo_dart: ^0.1.0
```

### Prerequisites

This package uses [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) to bridge Dart and a Rust CozoDB engine. You need:

- **Rust toolchain** (`rustup`, `cargo`) — [Install Rust](https://rustup.rs/)
- For **Android**: install Android NDK and `cargo-ndk`
  ```bash
  cargo install cargo-ndk
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
  ```
- For **iOS**: `rustup target add aarch64-apple-ios`
- For **macOS**: `rustup target add aarch64-apple-darwin x86_64-apple-darwin`

## Quick Start

```dart
import 'package:cozo_dart/cozo_dart.dart';

// Initialize once at app startup
await CozoDatabase.init();

// Open an in-memory database
final db = await CozoDatabase.openMemory();

// Create a relation
await db.query(':create users {id: String => name: String, age: Int}');

// Insert data
await db.query(r'''
  ?[id, name, age] <- [["alice", "Alice", 30], ["bob", "Bob", 25]]
  :put users {id => name, age}
''');

// Query
final result = await db.query('?[name] := *users[_, name, age], age > 26');
print(result.toMaps()); // [{name: Alice}]

// Graph algorithms
final graph = CozoGraph(db);
final ranks = await graph.pageRank('follows');

// Vector search
final vec = CozoVectorSearch(db);
final neighbors = await vec.search('docs', 'doc_idx',
  queryVector: embedding, bindFields: ['id', 'content'], k: 10);

// Full-text search
final fts = CozoTextSearch(db);
final hits = await fts.search('articles', 'articles_fts',
  queryText: 'graph database', bindFields: ['id', 'title'], k: 10);

await db.close();
```

## Storage Engines

| Engine              | Persistent | Use Case                      |
| ------------------- | ---------- | ----------------------------- |
| `CozoEngine.memory` | No         | Tests, temporary data, caches |
| `CozoEngine.sqlite` | Yes        | Mobile apps, desktop apps     |

```dart
// In-memory (default)
final db = await CozoDatabase.openMemory();

// SQLite persistent
final db = await CozoDatabase.openSqlite('/path/to/database.db');
```

---

## API Reference

The SDK exports 7 modules from `package:cozo_dart/cozo_dart.dart`:

### CozoDatabase

Core database lifecycle, queries, system operations, and data I/O.

#### Initialization & Lifecycle

| Method                                       | Description                                                                                           |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `CozoDatabase.init()`                        | Initialize the flutter_rust_bridge FFI layer. **Call once** at app startup before any other API call. |
| `CozoDatabase.open({engine, path, options})` | Open a database with explicit engine type, file path, and JSON options string.                        |
| `CozoDatabase.openMemory()`                  | Open an in-memory database. Data is lost when the database is closed.                                 |
| `CozoDatabase.openSqlite(path)`              | Open a persistent SQLite-backed database at the given file path.                                      |
| `close()`                                    | Close the database and release all resources.                                                         |
| `isClosed`                                   | Whether the database has been closed.                                                                 |

#### Query Execution

| Method                             | Description                                                                                                                                                                                          |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `query(script, {params})`          | Execute a mutable CozoScript query. Supports DDL (`:create`, `:drop`), DML (`:put`, `:rm`), and reads. `params` is an optional `Map<String, dynamic>` for parameterized queries using `$param_name`. |
| `queryImmutable(script, {params})` | Execute a **read-only** CozoScript query. Rejects any DDL/DML operations. Use for safe concurrent reads.                                                                                             |

#### System Operations (12 methods)

| Method                                        | Description                                                                                                         |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `listRelations()`                             | List all stored relations in the database. Equivalent to `::relations`.                                             |
| `describeRelation(name)`                      | Describe a relation's columns and types. Equivalent to `::columns <name>`.                                          |
| `listIndices(name)`                           | List all indices (HNSW, FTS, LSH) on a relation. Equivalent to `::indices <name>`.                                  |
| `explain(script)`                             | Show the query execution plan for a CozoScript query. Equivalent to `::explain { <script> }`.                       |
| `listRunningQueries()`                        | List currently executing queries. Equivalent to `::running`.                                                        |
| `cancelQuery(id)`                             | Cancel a running query by its ID. Equivalent to `::kill <id>`.                                                      |
| `removeRelations(names)`                      | Drop one or more stored relations. Accepts a `List<String>` of relation names.                                      |
| `renameRelations(renames)`                    | Rename relations. Accepts a `Map<String, String>` of `{oldName: newName}`.                                          |
| `showTriggers(name)`                          | Show triggers attached to a relation.                                                                               |
| `setTriggers(name, {onPut, onRm, onReplace})` | Set Datalog triggers that fire on put/remove/replace operations on a relation. Each trigger is a CozoScript string. |
| `setAccessLevel(accessLevel)`                 | Set the database access level. Values: `"normal"`, `"protected"`, `"read_only"`.                                    |
| `compact()`                                   | Compact the underlying storage. Useful for SQLite to reclaim disk space.                                            |

#### Data Import/Export & Backup

| Method                              | Description                                                                                     |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| `exportRelations(names)`            | Export one or more relations as a JSON-serializable `Map`. Accepts a `List<String>`.            |
| `importRelations(data)`             | Import relations from a `Map` previously returned by `exportRelations`.                         |
| `backup(path)`                      | Write a full database backup to the given file path.                                            |
| `restore(path)`                     | Restore the database from a backup file.                                                        |
| `importFromBackup(path, relations)` | Selectively import specific relations from a backup file without restoring the entire database. |

---

### CozoGraph

High-level graph operations wrapping CozoDB's built-in Datalog graph algorithms. All methods accept relation name strings and return `CozoResult`.

#### CRUD

| Method                                  | Description                                                                                                                                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `createRelation(name, columns, {keys})` | Create a stored relation with typed columns. `columns` is a `Map<String, String>` of `{name: type}`. `keys` specifies the number of leading columns that form the primary key (default 1). |
| `put(relation, rows)`                   | Insert or update rows. `rows` is a `List<Map<String, dynamic>>`.                                                                                                                           |
| `remove(relation, keys)`                | Delete rows by primary key. `keys` is a `List<Map<String, dynamic>>` with key columns only.                                                                                                |
| `getAll(relation)`                      | Fetch all rows from a stored relation.                                                                                                                                                     |

#### PageRank

| Method                                                                         | Description                                                                                                                          |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `pageRank(edgeRelation, {iterations, dampingFactor, epsilon, fromCol, toCol})` | Compute PageRank scores. `iterations` defaults to 10, `dampingFactor` to 0.85, `epsilon` to 0.0001. Returns columns: `node`, `rank`. |

#### Path & Traversal Algorithms (7 methods)

| Method                                                                                        | Description                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shortestPath(edgeRelation, from, to, {fromCol, toCol})`                                      | Find the shortest path between two nodes using **BFS**. Returns columns: `node`, `distance`, `path`.                                                                                                           |
| `shortestPathDijkstra(edgeRelation, starting, goals, {fromCol, toCol, weightCol})`            | **Dijkstra's** weighted shortest path. `starting` and `goals` are lists of node IDs. Returns columns: `starting`, `goal`, `cost`, `path`.                                                                      |
| `kShortestPathsYen(edgeRelation, from, to, {k, fromCol, toCol, weightCol})`                   | **Yen's K-shortest paths**. Returns the `k` shortest paths between two nodes. Returns columns: `path`, `cost`.                                                                                                 |
| `shortestPathAStar(edgeRelation, from, to, {heuristicRelation, fromCol, toCol, weightCol})`   | **A\*** shortest path with a heuristic relation for informed search. Returns columns: `path`, `cost`.                                                                                                          |
| `bfs(edgeRelation, nodeRelation, columns, startingNodes, {condition, limit, fromCol, toCol})` | **BFS** with node-attribute filtering. Traverses from `startingNodes`, optionally filtering by a CozoScript `condition` on node attributes, with an optional `limit`.                                          |
| `dfs(edgeRelation, nodeRelation, columns, startingNodes, {condition, limit, fromCol, toCol})` | **DFS** with node-attribute filtering. Same interface as `bfs` but depth-first.                                                                                                                                |
| `randomWalk(edgeRelation, startingNodes, {steps, walks, fromCol, toCol})`                     | Perform **random walks** from given nodes. `steps` per walk (default 10), `walks` per starting node (default 1). Useful for Node2Vec-style graph embeddings. Returns columns: `node`, `starting_node`, `path`. |

#### Centrality Algorithms (3 methods)

| Method                                                  | Description                                                                                                                                     |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `degreeCentrality(edgeRelation, {fromCol, toCol})`      | Compute **in-degree**, **out-degree**, and **total degree** for every node. Returns columns: `node`, `in_degree`, `out_degree`, `total_degree`. |
| `betweennessCentrality(edgeRelation, {fromCol, toCol})` | Compute **betweenness centrality** — how often a node lies on shortest paths between other nodes. Returns columns: `node`, `centrality`.        |
| `closenessCentrality(edgeRelation, {fromCol, toCol})`   | Compute **closeness centrality** — how close a node is to all other nodes. Returns columns: `node`, `centrality`.                               |

#### Community Detection (4 methods)

| Method                                                        | Description                                                                                                     |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `communityDetection(edgeRelation, {fromCol, toCol})`          | **Louvain** modularity-based community detection. Returns columns: `node`, `community`.                         |
| `labelPropagation(edgeRelation, {fromCol, toCol})`            | **Label propagation** — fast community detection by iterative label exchange. Returns columns: `node`, `label`. |
| `connectedComponents(edgeRelation, {fromCol, toCol})`         | Find **connected components** in an undirected graph. Returns columns: `node`, `component`.                     |
| `stronglyConnectedComponents(edgeRelation, {fromCol, toCol})` | Find **strongly connected components** in a directed graph. Returns columns: `node`, `component`.               |

#### Clustering

| Method                                                   | Description                                                                                                                                                                                     |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clusteringCoefficients(edgeRelation, {fromCol, toCol})` | Compute the **clustering coefficient** for each node — the fraction of a node's neighbors that are also connected to each other. Returns columns: `node`, `coefficient`, `triangles`, `degree`. |

#### Minimum Spanning Tree (2 methods)

| Method                                                                  | Description                                                                                                                          |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `minimumSpanningTreeKruskal(edgeRelation, {fromCol, toCol, weightCol})` | Compute the MST using **Kruskal's** algorithm. The edge relation must have a weight column. Returns columns: `from`, `to`, `weight`. |
| `minimumSpanningTreePrim(edgeRelation, {fromCol, toCol, weightCol})`    | Compute the MST using **Prim's** algorithm. Often faster for dense graphs. Returns columns: `from`, `to`, `weight`.                  |

#### Topological Sort

| Method                                            | Description                                                                                                                                        |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `topologicalSort(edgeRelation, {fromCol, toCol})` | Perform a **topological sort** on a DAG. Returns nodes in dependency order. Throws if the graph contains cycles. Returns columns: `node`, `order`. |

---

### CozoVectorSearch

HNSW (Hierarchical Navigable Small World) vector index and approximate nearest neighbor (ANN) search.

#### Enums

| Enum             | Values                         | Description                                                                   |
| ---------------- | ------------------------------ | ----------------------------------------------------------------------------- |
| `VectorDistance` | `l2`, `cosine`, `innerProduct` | Distance metric for HNSW search.                                              |
| `VectorDType`    | `f32`, `f64`                   | Vector storage data type. `f32` is smaller and sufficient for most use cases. |

#### Methods

| Method                                                                                                                                              | Description                                                                                                                                                                                                                                                                                 |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `createIndex(relation, indexName, {dim, fields, distance, dtype, m, efConstruction, extendCandidates, keepPrunedConnections})`                      | Create an HNSW vector index. `dim` = vector dimensionality, `fields` = columns to index, `m` = max edges per HNSW node (default 50), `efConstruction` = build-time candidate list size (default 200).                                                                                       |
| `dropIndex(relation, indexName)`                                                                                                                    | Drop an HNSW index. The underlying relation is not affected.                                                                                                                                                                                                                                |
| `search(relation, indexName, {queryVector, bindFields, k, ef, bindDistance, radius, filter})`                                                       | Search for `k` approximate nearest neighbors. `queryVector` = the query embedding, `bindFields` = columns to return, `ef` = search-time accuracy parameter (≥ k), `radius` = max distance threshold, `filter` = CozoScript pre-filter expression. Returns `bindFields` + a distance column. |
| `searchWithConditions(relation, indexName, {queryVector, bindFields, joinConditions, outputFields, k, ef, bindDistance, radius, additionalParams})` | **Hybrid vector + Datalog** search. Combines ANN similarity with structured relational filters, graph traversals, or aggregations using CozoDB's Datalog engine. `joinConditions` is appended after the vector search clause.                                                               |
| `upsert(relation, rows, {vectorColumns})`                                                                                                           | Insert or update rows with vector data. Automatically wraps columns listed in `vectorColumns` with CozoDB's `vec()` function.                                                                                                                                                               |
| `remove(relation, keys)`                                                                                                                            | Remove rows by primary key. Convenience method so you don't need `CozoGraph` for vector workflows.                                                                                                                                                                                          |

```dart
// Example: create index and search
await vecSearch.createIndex('documents', 'doc_idx',
  dim: 1536, fields: ['embedding'], distance: VectorDistance.cosine);

final results = await vecSearch.search('documents', 'doc_idx',
  queryVector: [0.1, 0.2, ...], bindFields: ['id', 'content'], k: 10);
```

---

### CozoTextSearch

Full-text search (FTS with BM25 ranking) and locality-sensitive hashing (LSH with MinHash / Jaccard similarity).

#### Tokenizers

| `FtsTokenizer` value | Description                                                            |
| -------------------- | ---------------------------------------------------------------------- |
| `raw`                | No tokenization — entire field is a single token.                      |
| `simple`             | Splits on whitespace and punctuation. Best for Latin-script languages. |
| `cangjie`            | CJK-aware tokenizer for Chinese, Japanese, and Korean text.            |

#### Token Filters

Applied in order after tokenization:

| Class                    | Description                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------- |
| `FtsLowercase()`         | Convert all tokens to lowercase.                                                                |
| `FtsAlphaNumOnly()`      | Remove non-alphanumeric characters.                                                             |
| `FtsAsciiFolding()`      | Fold Unicode to ASCII equivalents (ñ → n, ü → u).                                               |
| `FtsStemmer(language)`   | Language-specific stemming (e.g., `'english'`, `'french'`, `'german'`). 18 languages supported. |
| `FtsStopwords(language)` | Remove common stopwords. Use ISO 639-1 codes (`'en'`, `'fr'`, `'de'`).                          |

#### FTS Methods

| Method                                                                                                                             | Description                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `createIndex(relation, indexName, {extractor, tokenizer, filters})`                                                                | Create a full-text search index. `extractor` = column containing text, `tokenizer` defaults to `simple`, `filters` = ordered list of `FtsFilter` instances. |
| `dropIndex(relation, indexName)`                                                                                                   | Drop an FTS index.                                                                                                                                          |
| `search(relation, indexName, {queryText, bindFields, k, bindScore, filter})`                                                       | Search by text query with **BM25 ranking**. Returns `bindFields` + a score column ordered by relevance.                                                     |
| `searchWithConditions(relation, indexName, {queryText, bindFields, joinConditions, outputFields, k, bindScore, additionalParams})` | **Hybrid FTS + Datalog** search. Combines keyword relevance with structured relational filters via CozoDB's Datalog engine.                                 |

#### LSH Methods

| Method                                                                                                                                          | Description                                                                                                                                                                                                  |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `createLSHIndex(relation, indexName, {extractor, tokenizer, filters, nPerm, targetThreshold, nGram, falsePositiveWeight, falseNegativeWeight})` | Create an LSH index for near-duplicate detection. `nPerm` = MinHash permutations (default 200), `targetThreshold` = Jaccard similarity threshold (default 0.7), `nGram` = shingling n-gram size (default 3). |
| `dropLSHIndex(relation, indexName)`                                                                                                             | Drop an LSH index.                                                                                                                                                                                           |
| `similaritySearch(relation, indexName, {queryText, bindFields, k})`                                                                             | Find documents similar to `queryText` via MinHash / Jaccard similarity.                                                                                                                                      |
| `similaritySearchWithConditions(relation, indexName, {queryText, bindFields, joinConditions, outputFields, k, additionalParams})`               | **Hybrid LSH + Datalog** similarity search with join conditions.                                                                                                                                             |

```dart
// Example: FTS with stemming + stopwords
await textSearch.createIndex('articles', 'articles_fts',
  extractor: 'body',
  tokenizer: FtsTokenizer.simple,
  filters: [FtsLowercase(), FtsStemmer('english'), FtsStopwords('en')]);

final results = await textSearch.search('articles', 'articles_fts',
  queryText: 'graph database performance', bindFields: ['id', 'title'], k: 10);

// Example: LSH near-duplicate detection
await textSearch.createLSHIndex('articles', 'articles_lsh',
  extractor: 'body', targetThreshold: 0.5, nGram: 3);

final similar = await textSearch.similaritySearch('articles', 'articles_lsh',
  queryText: 'some document text...', bindFields: ['id', 'title'], k: 5);
```

---

### CozoUtils

Utility operations wrapping CozoDB's fixed-point algorithms for sorting, CSV reading, and JSON reading.

| Method                                                                               | Description                                                                                                                                                                              |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `reorderSort(relation, {columns, sortBy, descending, breakTies, skip, take})`        | Sort and paginate rows from a stored relation using CozoDB's `ReorderSort` algorithm. `sortBy` = columns to sort by, `descending` = sort order, `skip`/`take` = offset/limit pagination. |
| `reorderSortRaw({dataQuery, outColumns, sortBy, descending, breakTies, skip, take})` | Sort and paginate results of an **inline CozoScript query** rather than a stored relation. `dataQuery` defines a `data[...]` rule.                                                       |
| `readCsv(url, {types, columns, delimiter, prependIndex, hasHeaders})`                | Read data from a CSV file or URL into a `CozoResult`. Supports `file://`, `http://`, `https://`. `types` = list of column types (e.g., `['String', 'Int', 'Float']`).                    |
| `readJson(url, {fields, columns, jsonLines, nullIfAbsent, prependIndex})`            | Read data from a JSON file or URL. `fields` = list of `(jsonPath, type)` pairs. Supports JSON Lines format.                                                                              |

```dart
final utils = CozoUtils(db);

// Sort and paginate
final top10 = await utils.reorderSort('users',
  sortBy: ['score'], descending: true, take: 10);

// Read CSV
final csv = await utils.readCsv('file:///data.csv',
  types: ['String', 'Int', 'Float'], columns: ['name', 'age', 'score']);

// Read JSON
final json = await utils.readJson('https://api.example.com/users.json',
  fields: [('name', 'String'), ('age', 'Int')], nullIfAbsent: true);
```

---

### CozoResult

Structured result type returned by all query and algorithm methods.

| Property / Method     | Type                         | Description                                                                                         |
| --------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `headers`             | `List<String>`               | Column header names.                                                                                |
| `rows`                | `List<List<dynamic>>`        | Row data. Each row is a list of values matching header order.                                       |
| `took`                | `double?`                    | Query execution time in seconds (reported by the CozoDB engine).                                    |
| `length`              | `int`                        | Number of rows in the result.                                                                       |
| `isEmpty`             | `bool`                       | `true` if no rows returned.                                                                         |
| `isNotEmpty`          | `bool`                       | `true` if at least one row returned.                                                                |
| `columnIndex(header)` | `int`                        | Get the 0-based column index by header name. Returns `-1` if not found.                             |
| `toMaps()`            | `List<Map<String, dynamic>>` | Convert all rows to a list of `{header: value}` maps.                                               |
| `column(header)`      | `List<dynamic>`              | Extract all values from a single column by header name. Throws `ArgumentError` if column not found. |
| `firstOrNull`         | `Map<String, dynamic>?`      | First row as a map, or `null` if empty.                                                             |

```dart
final result = await db.query('?[name, age] := *users[_, name, age]');

print(result.length);         // 10000
print(result.headers);        // ['name', 'age']
print(result.took);           // 0.042
print(result.firstOrNull);    // {name: 'Alice Smith', age: 30}
print(result.column('name')); // ['Alice Smith', 'Bob Jones', ...]

for (final row in result.toMaps()) {
  print('${row['name']} is ${row['age']} years old');
}
```

---

### CozoException

Typed exception hierarchy for error handling.

| Class                   | Description                                                                                                                                                             |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CozoException`         | Base exception. Has a `message` property.                                                                                                                               |
| `CozoQueryException`    | Thrown when a CozoScript query fails (syntax errors, constraint violations, etc.). Has an additional `rawResponse` property containing the full JSON error from CozoDB. |
| `CozoDatabaseException` | Thrown when a database operation fails (open, close, backup, etc.).                                                                                                     |

```dart
try {
  await db.query('INVALID QUERY');
} on CozoQueryException catch (e) {
  print(e.message);      // Human-readable error
  print(e.rawResponse);  // Full JSON error from CozoDB engine
} on CozoDatabaseException catch (e) {
  print(e.message);
}
```

---

## CozoScript

CozoDB uses Datalog, not SQL or Cypher. See the [CozoScript tutorial](https://docs.cozodb.org/en/latest/tutorial.html) for full documentation.

### Common Patterns

```
// Create a relation
:create table_name {key_col: Type => value_col: Type}

// Insert data
?[col1, col2] <- [[val1, val2], [val3, val4]]
:put table_name {col1, col2}

// Query with pattern matching
?[name, age] := *users[_, name, age], age > 25

// Recursive queries
?[ancestor] := *parent["alice", ancestor]
?[ancestor] := *parent[p, ancestor], ?[p]

// Graph algorithms (fixed-point)
edges[from, to] := *follows[from, to]
?[node, rank] <~ PageRank(edges[])

// Vector search
?[id, content, distance] := ~docs:vec_idx{ id, content | query: vec($q), k: 10 }

// Full-text search
?[id, title, score] := ~articles:fts_idx{ id, title | query: $q, k: 10, bind_score: score }
```

## Parameterized Queries

Use `$param_name` in CozoScript and pass parameters as a map:

```dart
final result = await db.query(
  r'?[name] := *users[_, name, age], age > $min_age',
  params: {'min_age': 25},
);
```

## Architecture

```
┌──────────────────────────────────────────┐
│          Dart API Layer                  │
│  CozoDatabase · CozoGraph · CozoResult  │
│  CozoVectorSearch · CozoTextSearch       │
│  CozoUtils · CozoException              │
├──────────────────────────────────────────┤
│       flutter_rust_bridge (FFI)          │
├──────────────────────────────────────────┤
│          Rust Bridge Layer               │
├──────────────────────────────────────────┤
│       CozoDB Engine (cozo crate)         │
│  Datalog · Graph · HNSW · FTS · LSH     │
│  SQLite backend · In-memory backend      │
└──────────────────────────────────────────┘
```

## Binary Size

CozoDB with SQLite backend and graph algorithms compiles to ~5–10 MB per architecture. The release profile uses LTO and `opt-level = "z"` to minimize binary size.

---

## Performance Benchmarks

The benchmark suite exercises the full API surface — bulk writes, read queries, graph algorithms, export/import, concurrent reads, updates, and deletes — against an **in-memory CozoDB instance** with a large synthetic dataset.

### Test Environment

- **Device**: iOS Simulator (iPhone)
- **Database**: In-memory (`CozoEngine.memory`)
- **Dataset**: 75,000 total rows across 4 relations
  - 10,000 users (id, name, age, email, score)
  - 50,000 follow edges (directed graph)
  - 5,000 posts (author, title, body, likes, timestamp)
  - 10,000 tags (post_id, tag — from a pool of 20 tag values)
- **Batch size**: 2,000 rows per insert query

### Benchmark Results (iOS Simulator)

#### Write Performance

| Operation                  | Time      | Throughput    |
| -------------------------- | --------- | ------------- |
| Schema creation (4 tables) | 69 ms     | —             |
| Insert 10,000 users        | 984 ms    | 10,163 rows/s |
| Insert 50,000 edges        | 2,070 ms  | 24,155 rows/s |
| Insert 5,000 posts         | 40,739 ms | 123 rows/s    |
| Insert 10,000 tags         | 538 ms    | 18,587 rows/s |

#### Read Query Performance

| Operation                                     | Time   | Result      |
| --------------------------------------------- | ------ | ----------- |
| Full scan 10,000 users                        | 166 ms | 10,000 rows |
| Filtered query (age 50–59)                    | 50 ms  | 1,610 rows  |
| Aggregation (count, mean, min, max)           | 86 ms  | —           |
| Join posts × users (likes > 80)               | 38 ms  | 920 rows    |
| Multi-hop join (tags → posts → users, "dart") | 28 ms  | 501 rows    |

#### Graph Algorithm Performance (50,000 edges)

| Algorithm                           | Time     | Result              |
| ----------------------------------- | -------- | ------------------- |
| PageRank (10 iterations)            | 477 ms   | 10,000 ranked nodes |
| Community Detection (Louvain)       | 4,668 ms | 10,000 communities  |
| BFS (condition: age > 90, limit 10) | 513 ms   | 0 results           |
| Shortest Path BFS (node 0 → 5000)   | 349 ms   | 6 hops              |

#### Export / Import Performance

| Operation                      | Time   |
| ------------------------------ | ------ |
| Export 10,000 users            | 79 ms  |
| Import 10,000 users (fresh db) | 118 ms |

#### Concurrent & Mutation Performance

| Operation                              | Time   |
| -------------------------------------- | ------ |
| 4 concurrent aggregation queries       | 271 ms |
| Update 1,000 user rows (age increment) | 25 ms  |
| Delete edges from last 500 users       | 25 ms  |

### Raw Benchmark Output

<details>
<summary>Click to expand</summary>

```
═══  BENCHMARK SUITE  ═══

Schema creation (4 relations): 69ms
Insert 10000 users: 984ms (10163 rows/s)
Insert 50000 follow edges: 2070ms (24155 rows/s)
Insert 5000 posts: 40739ms (123 rows/s)
Insert 10000 tags: 538ms (18587 rows/s)

Total data: 75000 rows across 4 relations

─── READ QUERIES ───
Full scan 10000 users: 166ms → 10000 rows
Filtered users (age 50-59): 50ms → 1610 rows
Aggregation (count, mean, min, max): 86ms
Join posts×users (likes>80): 38ms → 920 rows
Multi-hop join (tags→posts→users, tag="dart"): 28ms → 501 rows

─── GRAPH ALGORITHMS (50000 edges) ───
PageRank (10 iter): 477ms → 10000 ranked nodes
Community detection (Louvain): 4668ms → 10000 communities
BFS from node 0 (condition: age>90, limit 10): 513ms → 0 results
Shortest path (0 → 5000): 349ms → 6 hops

─── EXPORT / IMPORT ───
Export 10000 users: 79ms
Import 10000 users into fresh db: 118ms

─── CONCURRENT READS ───
4 concurrent aggregation queries: 271ms

─── UPDATES ───
Update 1000 user rows: 25ms
Delete edges from last 500 users: 25ms

═══  BENCHMARKS COMPLETE  ═══
```

</details>

---

## Testing

The package includes two levels of tests:

### Unit / Integration Tests (`simple_test.dart`)

Validates core API correctness:

| Test                            | Description                                                    |
| ------------------------------- | -------------------------------------------------------------- |
| Basic query round-trip          | Runs `?[a] := a in [1, 2, 3]` and verifies 3 rows returned     |
| Create relation and insert data | Creates `users` table, inserts 2 rows, validates filtered read |
| Graph helper put and query      | Uses `CozoGraph.put()` / `getAll()` convenience methods        |
| Parameterized query             | Tests `$param_name` substitution in CozoScript                 |
| Error handling for bad query    | Ensures `CozoQueryException` thrown on invalid CozoScript      |
| Immutable query rejects writes  | Verifies `queryImmutable()` refuses DDL/DML operations         |
| PageRank on simple graph        | Runs PageRank on a 4-node directed graph                       |
| Export and import relations     | Exports a relation, imports into fresh db, verifies data match |

```bash
cd example && flutter test integration_test/simple_test.dart -d <device>
```

### Performance / Stress Tests (`performance_test.dart`)

Comprehensive benchmarks: bulk inserts, read queries, graph algorithms, concurrent reads, mutations, and export/import.

```bash
cd example && flutter test integration_test/performance_test.dart -d <device>
```

### Running the Example App

```bash
cd example && flutter run -d <device>
```

---

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

See [LICENSE](LICENSE) for the full license text.
