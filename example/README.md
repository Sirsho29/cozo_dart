# cozo_dart Example App

A comprehensive Flutter demo app showcasing the full `cozo_dart` SDK — an embedded CozoDB database with graph algorithms, HNSW vector search, full-text search, LSH similarity, and system operations.

## Screenshots

The app uses Material 3 with an indigo color scheme and supports both light and dark themes.

## Architecture

```
example/lib/
├── main.dart                    # App shell with 3-tab layout
├── services/
│   └── db_service.dart          # Database lifecycle & data generation
├── models/
│   ├── load_step.dart           # LoadStep model for progress tracking
│   └── preset_model.dart        # PresetItem & PresetRunState models
├── tabs/
│   ├── query_tab.dart           # Ad-hoc CozoScript query editor
│   ├── presets_tab.dart         # 35+ preset queries across 8 categories
│   └── compare_tab.dart         # Comparison tab (placeholder)
└── pages/
    └── graph_page.dart          # Interactive graph visualization
```

## Features

### Tab 1: Query

A free-form CozoScript query editor with:

- Multi-line text input for writing CozoScript queries
- Execute button that runs queries against the active CozoDB instance
- Result display showing column headers, row data, row count, and execution time
- Error handling with user-friendly error messages for invalid queries

### Tab 2: DB Presets

**35+ ready-to-run preset queries** organized into 8 categories, each demonstrating different SDK capabilities. Tap any preset to run it instantly and see results.

#### Data Loading

Before running presets, load the test dataset via the **Load Test Data** button. This opens a dialog showing real-time progress across 11 structured loading steps:

| Step       | Description                                                | Size Estimate |
| ---------- | ---------------------------------------------------------- | ------------- |
| Schema     | Create 4 relations (users, follows, posts, tags)           | —             |
| Users      | Insert 10,000 users (name, age, email, score)              | ~547 KB       |
| Edges      | Insert 50,000 directed follow edges                        | ~390 KB       |
| Posts      | Insert 5,000 posts (author, title, body, likes, timestamp) | ~214 KB       |
| Tags       | Insert 10,000 tag assignments from a pool of 20 tags       | ~117 KB       |
| Subgraph   | Create `follows_small` (nodes < 500) for visualization     | ~1 KB         |
| Articles   | Insert 10 articles on AI/DB topics                         | ~1 KB         |
| Embeddings | Insert 1,000 32-dim float32 vectors                        | ~140 KB       |
| HNSW       | Build HNSW index on embeddings (cosine, m=16)              | ~125 KB       |
| FTS        | Build FTS index on article bodies (simple + lowercase)     | ~5 KB         |
| LSH        | Build LSH index on article bodies (threshold=0.3)          | ~3 KB         |

Each step shows: status indicator (pending / running / complete / error), duration in milliseconds, and estimated memory footprint.

#### Preset Categories

**Read Queries (6 presets)**

- **Full Table Scan** — scan all 10,000 users
- **Filtered Query** — users aged 50–59
- **Aggregation** — count, mean, min, max on user scores
- **Join** — posts with likes > 80 joined with user names
- **Multi-hop Join** — tags → posts → users where tag = "dart"
- **Concurrent Reads** — 4 aggregation queries in parallel

**Graph Algorithms (14 presets)**

- **PageRank** — 10 iterations on 50K edges
- **Community Detection** — Louvain modularity-based clustering
- **BFS** — from node 0, filter age > 90, limit 10
- **DFS** — from node 0, filter age > 90, limit 5
- **Shortest Path (BFS)** — node 0 → node 5,000
- **Shortest Path (Dijkstra)** — weighted, 2 starts → 2 goals
- **K Shortest Paths (Yen)** — k=3, node 1 → node 500
- **Degree Centrality** — in/out/total degree for all nodes
- **Label Propagation** — on small subgraph (< 500 nodes)
- **Strongly Connected Components** — on small subgraph
- **Connected Components** — undirected, on small subgraph
- **Clustering Coefficients** — per-node coefficient, triangles, degree
- **Topological Sort** — on small subgraph
- **Random Walk** — 3 starting nodes, 10 steps, 2 walks each

**Vector Search (2 presets)**

- **HNSW Search** — ANN k=10, cosine distance on 1,000 embeddings
- **HNSW Radius Search** — k=100, radius ≤ 1.0

**Text Search (4 presets)**

- **FTS Search** — "graph database" with BM25 ranking
- **FTS Search #2** — "vector search similarity"
- **LSH Similarity** — MinHash Jaccard on articles
- **Hybrid FTS + Filter** — FTS "database" combined with id < 7

**System Operations (7 presets)**

- **List Relations** — `::relations`
- **Describe Relation** — `::columns users`
- **Explain Query** — show query execution plan
- **List Running Queries** — `::running`
- **Describe + Rename + Remove** — create temp relation, rename, then remove
- **Access Level** — set protected, then reset to normal
- **Compact** — `::compact`

**Mutations (2 presets)**

- **Bulk Update** — update age of first 1,000 users
- **Bulk Delete** — delete edges from last 500 users

**Export/Import (1 preset)**

- **Export + Import** — export users, import into fresh DB, verify count

### Tab 3: Compare

Placeholder tab for future benchmark comparison features.

### Graph Visualization Page

Accessible from the **Community Detection** and **Label Propagation** presets, this full-screen page renders the `follows_small` subgraph (nodes < 500) using the `graphview` package.

Features:

- **Force-directed layout** (Fruchterman-Reingold, 500 iterations) as default
- **3 layout algorithms**: Force-Directed, Layered (Sugiyama), Circular — switchable via toolbar
- **Community-colored nodes**: colors assigned by label propagation results (12-color palette)
- **Interactive**: tap nodes to see details (name, ID), pinch to zoom, drag to pan
- **Info bar**: displays node count, edge count, current layout, and selected node details
- **Zoom to fit**: toolbar button to auto-fit the entire graph in view
- **Legend**: explains color coding and interaction hints

## Running

```bash
# From the example directory
cd example

# Run on a connected device or simulator
flutter run -d <device>

# Run integration tests
flutter test integration_test/simple_test.dart -d <device>
flutter test integration_test/performance_test.dart -d <device>
```

## Dependencies

- **cozo_dart** — the CozoDB Dart SDK (parent package)
- **graphview** `^1.5.1` — graph layout and rendering for the visualization page

## Data Generation Details

The test dataset is generated deterministically (seeded `Random(42)`) for reproducible results:

- **Users**: 10,000 rows with cycling first/last names (26 × 20 combinations), ages 18–79, sequential emails, random scores 0–100
- **Edges**: 50,000 unique directed edges (no self-loops, no duplicates) between user IDs 0–9,999
- **Posts**: 5,000 rows with random authors, sequential titles/bodies, random likes 0–99, timestamps around epoch 1.7B
- **Tags**: 10,000 assignments cycling through 20 tags (dart, flutter, rust, cozo, graph, database, mobile, web, performance, ai, ml, iot, cloud, devops, linux, macos, android, ios, ui, ux)
- **Subgraph**: filtered view of edges where both endpoints are < 500
- **Articles**: 10 hand-written articles on graph databases, vector search, FTS, Dart, Flutter, CozoDB, ML, AI agents, knowledge graphs, and embeddings
- **Embeddings**: 1,000 random 32-dimensional float32 vectors

Bulk inserts use a batch size of 2,000 rows per query with `Future.delayed` yields to keep the UI responsive during loading.
