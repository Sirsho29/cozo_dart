# cozo_dart

A Dart/Flutter package for [CozoDB](https://github.com/cozodb/cozo), an embedded transactional graph database with Datalog queries, graph algorithms, vector search, and time-travel.

## Features

- **Embedded graph database** — runs locally, no server needed
- **Datalog queries** — powerful recursive queries via CozoScript
- **15+ graph algorithms** — PageRank, BFS, shortest path, community detection
- **HNSW vector search** — semantic similarity search on-device
- **Time-travel queries** — query historical data states
- **ACID transactions** — full transactional guarantees
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
  :put users {id, name, age}
''');

// Query
final result = await db.query('?[name] := *users[_, name, age], age > 26');
print(result.toMaps()); // [{name: Alice}]

// Graph algorithms
final graph = CozoGraph(db);
final ranks = await graph.pageRank('follows');

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

## API Reference

### CozoDatabase

| Method                             | Description                            |
| ---------------------------------- | -------------------------------------- |
| `CozoDatabase.init()`              | Initialize the Rust bridge (call once) |
| `CozoDatabase.open(...)`           | Open with engine, path, and options    |
| `CozoDatabase.openMemory()`        | Open an in-memory database             |
| `CozoDatabase.openSqlite(path)`    | Open a SQLite database                 |
| `query(script, {params})`          | Execute a mutable CozoScript query     |
| `queryImmutable(script, {params})` | Execute a read-only query              |
| `exportRelations(names)`           | Export relations as JSON               |
| `importRelations(data)`            | Import relations from JSON             |
| `backup(path)`                     | Backup database to file                |
| `restore(path)`                    | Restore database from file             |
| `close()`                          | Close the database                     |

### CozoGraph

High-level graph operations:

| Method                                           | Description                     |
| ------------------------------------------------ | ------------------------------- |
| `createRelation(name, columns, keys)`            | Create a stored relation        |
| `put(relation, rows)`                            | Insert/update rows              |
| `remove(relation, keys)`                         | Delete rows by key              |
| `getAll(relation)`                               | Fetch all rows                  |
| `pageRank(edgeRelation)`                         | Run PageRank algorithm          |
| `shortestPath(edges, from, to)`                  | Find shortest path (BFS)        |
| `communityDetection(edges)`                      | Run Louvain community detection |
| `bfs(edges, nodeRelation, columns, starts, ...)` | Breadth-first search            |

### CozoResult

| Property/Method          | Description                             |
| ------------------------ | --------------------------------------- |
| `headers`                | Column header names                     |
| `rows`                   | Row data as `List<List<dynamic>>`       |
| `took`                   | Query execution time in seconds         |
| `length`                 | Number of rows                          |
| `isEmpty` / `isNotEmpty` | Check if result has data                |
| `toMaps()`               | Convert to `List<Map<String, dynamic>>` |
| `column(name)`           | Extract a single column                 |
| `firstOrNull`            | First row as a map, or null             |

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

// Graph algorithms
edges[from, to] := *follows[from, to]
?[node, rank] <~ PageRank(edges[])
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
┌──────────────────────────┐
│     Dart API Layer       │  CozoDatabase, CozoGraph, CozoResult
├──────────────────────────┤
│  flutter_rust_bridge     │  Auto-generated FFI bindings
├──────────────────────────┤
│     Rust Bridge          │  CozoDb wrapper struct
├──────────────────────────┤
│     CozoDB Engine        │  cozo crate (Rust)
└──────────────────────────┘
```

## Binary Size

CozoDB with SQLite backend and graph algorithms compiles to ~5-10MB per architecture. The release profile uses LTO and `opt-level = "z"` to minimize binary size.

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

**Run:**

```bash
cd example
flutter test integration_test/simple_test.dart -d <device>
```

### Performance / Stress Tests (`performance_test.dart`)

Comprehensive benchmarks grouped by operation category, each with individual timeouts:

#### 1. Bulk Insert Performance

- Insert 10,000 users with 5 columns (id, name, age, email, score)
- Insert 50,000 directed edges (random, no self-loops or duplicates)
- Insert 20,000 posts with 6 columns (id, author, title, body, likes, timestamp)
- Insert 40,000 tags (deterministic cycling assignment from 20-tag pool)
- **Each test verifies row count** via aggregate query after insert

#### 2. Query Performance (120K+ rows)

- **Full table scan**: retrieve all 10,000 users
- **Filtered query**: age range filter (50–59) — tests predicate pushdown
- **Aggregation**: count, mean, min, max over full user table
- **Two-table join**: posts × users with likes threshold — tests join performance
- **Three-table multi-hop join**: tags → posts → users filtered by tag value — tests multi-hop traversal
- **Concurrent reads**: 4 aggregation queries run in parallel via `Future.wait()`

#### 3. Graph Algorithm Benchmarks (50,000 edges)

- **PageRank** (10 & 20 iterations) on the follow graph
- **Community Detection** (Louvain) — verifies multiple communities found
- **BFS** from node 0 with a node-attribute condition (`age > 90`)
- **Shortest Path BFS** between node 0 and node 5,000

#### 4. Update & Delete Performance

- **Batch update**: increment age of 1,000 users (read-modify-write in single query)
- **Bulk delete**: remove all edges originating from the last 500 user IDs

#### 5. Export & Import Performance

- Export 10,000 users to JSON
- Import into a fresh in-memory database and verify count

**Run:**

```bash
cd example
flutter test integration_test/performance_test.dart -d <device>
```

### Running the Example App Benchmarks

The example app provides an interactive benchmark UI with two tabs:

1. **Query tab** — run arbitrary CozoScript queries interactively
2. **Benchmarks tab** — run the full benchmark suite with live progress in the UI

```bash
cd example
flutter run -d <device>
```

The benchmark tab populates the database, runs all tests sequentially, and displays timing results in real-time.

---

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

See [LICENSE](LICENSE) for the full license text.
