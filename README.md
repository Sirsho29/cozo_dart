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
await db.query(r\'\'\'
  ?[id, name, age] <- [["alice", "Alice", 30], ["bob", "Bob", 25]]
  :put users {id, name, age}
\'\'\');

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

| Method                                | Description                     |
| ------------------------------------- | ------------------------------- |
| `createRelation(name, columns, keys)` | Create a stored relation        |
| `put(relation, rows)`                 | Insert/update rows              |
| `remove(relation, keys)`              | Delete rows by key              |
| `getAll(relation)`                    | Fetch all rows                  |
| `pageRank(edgeRelation)`              | Run PageRank algorithm          |
| `shortestPath(edges, from, to)`       | Find shortest path (BFS)        |
| `communityDetection(edges)`           | Run Louvain community detection |
| `bfs(edges, startingNodes)`           | Breadth-first search            |

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

## License

See [LICENSE](LICENSE).
