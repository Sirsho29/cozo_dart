import 'cozo_database.dart';
import 'cozo_result.dart';

/// High-level graph operations built on CozoScript.
///
/// Provides convenient methods for common graph patterns without
/// needing to write raw CozoScript.
class CozoGraph {
  final CozoDatabase db;

  const CozoGraph(this.db);

  /// Create a stored relation (table) with the given schema.
  ///
  /// ```dart
  /// await graph.createRelation('users', {
  ///   'id': 'String',      // key column
  ///   'name': 'String',    // value column
  ///   'age': 'Int',        // value column
  /// }, keys: ['id']);
  /// ```
  Future<CozoResult> createRelation(
    String name,
    Map<String, String> columns, {
    List<String> keys = const [],
  }) async {
    final keyCols = keys.isEmpty ? [columns.keys.first] : keys;
    final valueCols = columns.keys.where((k) => !keyCols.contains(k));

    final schema = [
      ...keyCols.map((k) => '$k: ${columns[k]}'),
      '=>',
      ...valueCols.map((k) => '$k: ${columns[k]}'),
    ].join(', ');

    return db.query(':create $name {$schema}');
  }

  /// Insert or update rows in a relation.
  ///
  /// ```dart
  /// await graph.put('users', [
  ///   {'id': 'alice', 'name': 'Alice', 'age': 30},
  ///   {'id': 'bob', 'name': 'Bob', 'age': 25},
  /// ]);
  /// ```
  Future<CozoResult> put(
    String relation,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return db.query('?[] <- [[]]');

    final columns = rows.first.keys.toList();
    final bindings = columns.join(', ');
    final data = rows
        .map((row) =>
            '[${columns.map((c) => _toCozoLiteral(row[c])).join(", ")}]')
        .join(', ');

    return db.query('?[$bindings] <- [$data]\n:put $relation {$bindings}');
  }

  /// Remove rows from a relation by key.
  Future<CozoResult> remove(
    String relation,
    List<Map<String, dynamic>> keys,
  ) async {
    if (keys.isEmpty) return db.query('?[] <- [[]]');

    final columns = keys.first.keys.toList();
    final bindings = columns.join(', ');
    final data = keys
        .map((row) =>
            '[${columns.map((c) => _toCozoLiteral(row[c])).join(", ")}]')
        .join(', ');

    return db.query('?[$bindings] <- [$data]\n:rm $relation {$bindings}');
  }

  /// Get all rows from a relation.
  ///
  /// Note: Uses `::columns` to discover the schema, then queries all columns.
  Future<CozoResult> getAll(String relation) async {
    // First get the relation's columns
    final info = await db.queryImmutable('::columns $relation');
    final colNames = info.column('column').cast<String>().toList();
    final bindings = colNames.join(', ');
    return db.queryImmutable('?[$bindings] := *$relation[$bindings]');
  }

  /// Run the PageRank algorithm on an edge relation.
  ///
  /// Returns nodes ranked by importance.
  Future<CozoResult> pageRank(
    String edgeRelation, {
    int iterations = 20,
    double dampingFactor = 0.85,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, score] <~ PageRank(edges[], iterations: $iterations, damping: $dampingFactor)
    ''');
  }

  /// Find the shortest path between two nodes using BFS.
  ///
  /// Returns rows with columns: `start`, `goal`, `path`.
  /// `path` is a list of node indices forming the shortest path.
  Future<CozoResult> shortestPath(
    String edgeRelation,
    dynamic fromNode,
    dynamic toNode, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final from = _toCozoLiteral(fromNode);
    final to = _toCozoLiteral(toNode);
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      starting[] <- [[$from]]
      goals[] <- [[$to]]
      ?[start, goal, path] <~ ShortestPathBFS(edges[], starting[], goals[])
    ''');
  }

  /// Run community detection (Louvain algorithm) on an edge relation.
  Future<CozoResult> communityDetection(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, community] <~ CommunityDetectionLouvain(edges[])
    ''');
  }

  /// Run breadth-first search from starting nodes.
  ///
  /// Requires a [nodeRelation] (e.g. `'users'`) and a list of its
  /// [nodeColumns] (e.g. `['id', 'name', 'age']`). The first column must be
  /// the index that matches the edge endpoints.
  ///
  /// The [condition] is a CozoScript boolean expression referencing bindings
  /// from [nodeColumns] — BFS stops when a node satisfying it is found.
  /// [limit] controls how many answer nodes to return per starting node.
  ///
  /// Returns rows with columns: `start`, `answer`, `path`.
  Future<CozoResult> bfs(
    String edgeRelation,
    String nodeRelation,
    List<String> nodeColumns,
    List<dynamic> startingNodes, {
    required String condition,
    int limit = 1,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final nodeBindings = nodeColumns.join(', ');
    // Use named {col} access so column order doesn't matter.
    final namedAccess = nodeColumns.join(', ');

    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      nodes[$nodeBindings] := *$nodeRelation{$namedAccess}
      starting[] <- [$starts]
      ?[start, answer, path] <~ BFS(edges[], nodes[$nodeBindings], starting[], condition: $condition, limit: $limit)
    ''');
  }

  // ──────────── Centrality Algorithms ────────────

  /// Compute degree centrality for all nodes.
  ///
  /// Returns rows with columns: `node`, `degree`, `out_degree`, `in_degree`.
  /// - `degree`: total edges connected to the node
  /// - `out_degree`: outgoing edges
  /// - `in_degree`: incoming edges
  ///
  /// ```dart
  /// final result = await graph.degreeCentrality('follows');
  /// for (final row in result.toMaps()) {
  ///   print('${row['node']}: degree=${row['degree']}');
  /// }
  /// ```
  Future<CozoResult> degreeCentrality(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, degree, out_degree, in_degree] <~ DegreeCentrality(edges[])
    ''');
  }

  /// Compute betweenness centrality for all nodes.
  ///
  /// Betweenness centrality measures how often a node lies on the shortest
  /// path between other nodes. High betweenness = bridge / bottleneck.
  ///
  /// Returns rows with columns: `node`, `centrality`.
  ///
  /// **Note:** This is computationally expensive on large graphs.
  /// Consider using [undirected] for undirected graphs.
  Future<CozoResult> betweennessCentrality(
    String edgeRelation, {
    bool undirected = false,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final edges = undirected
        ? '''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      edges[$toCol, $fromCol] := *$edgeRelation[$fromCol, $toCol]'''
        : 'edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]';

    return db.queryImmutable('''
      $edges
      ?[node, centrality] <~ BetweennessCentrality(edges[])
    ''');
  }

  /// Compute closeness centrality for all nodes.
  ///
  /// Closeness centrality measures how close a node is to all other
  /// reachable nodes. High closeness = can reach most nodes quickly.
  ///
  /// Returns rows with columns: `node`, `centrality`.
  Future<CozoResult> closenessCentrality(
    String edgeRelation, {
    bool undirected = false,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final edges = undirected
        ? '''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      edges[$toCol, $fromCol] := *$edgeRelation[$fromCol, $toCol]'''
        : 'edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]';

    return db.queryImmutable('''
      $edges
      ?[node, centrality] <~ ClosenessCentrality(edges[])
    ''');
  }

  // ──────────── Community / Clustering ────────────

  /// Compute the clustering coefficient for each node.
  ///
  /// Measures how much a node's neighbors are connected to each other.
  /// High clustering coefficient = node lives in a tightly-knit group.
  ///
  /// Returns rows with columns:
  /// - `node`: the node index
  /// - `coefficient`: clustering coefficient (0.0 to 1.0)
  /// - `triangles`: number of triangles the node participates in
  /// - `degree`: total degree of the node
  ///
  /// ```dart
  /// final result = await graph.clusteringCoefficients('follows');
  /// for (final row in result.toMaps()) {
  ///   print('${row['node']}: coeff=${row['coefficient']}, triangles=${row['triangles']}');
  /// }
  /// ```
  Future<CozoResult> clusteringCoefficients(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, coefficient, triangles, degree] <~ ClusteringCoefficients(edges[])
    ''');
  }

  /// Find connected components in an undirected graph.
  ///
  /// Unlike [stronglyConnectedComponents] (which is for directed graphs),
  /// this treats all edges as undirected.
  ///
  /// Returns rows with columns: `node`, `component` (component ID).
  ///
  /// ```dart
  /// final result = await graph.connectedComponents('friendships');
  /// final numComponents = result.column('component').toSet().length;
  /// print('Found $numComponents connected components');
  /// ```
  Future<CozoResult> connectedComponents(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, component] <~ ConnectedComponents(edges[])
    ''');
  }

  /// Run label propagation community detection.
  ///
  /// An alternative to Louvain — faster but may produce different results.
  /// Good for large graphs where Louvain is too slow.
  ///
  /// Returns rows with columns: `node`, `label` (community ID).
  Future<CozoResult> labelPropagation(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, label] <~ LabelPropagation(edges[])
    ''');
  }

  /// Find strongly connected components in a directed graph.
  ///
  /// A strongly connected component is a maximal subgraph where every
  /// node is reachable from every other node in the component.
  ///
  /// Returns rows with columns: `node`, `component` (component ID).
  Future<CozoResult> stronglyConnectedComponents(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, component] <~ StronglyConnectedComponents(edges[])
    ''');
  }

  // ──────────── Path Algorithms ────────────

  /// Run depth-first search from starting nodes.
  ///
  /// Similar to [bfs] but explores depth-first. Good for exhaustive
  /// traversal, cycle detection, and topological ordering.
  ///
  /// Returns rows with columns: `start`, `answer`, `path`.
  Future<CozoResult> dfs(
    String edgeRelation,
    String nodeRelation,
    List<String> nodeColumns,
    List<dynamic> startingNodes, {
    required String condition,
    int limit = 1,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final nodeBindings = nodeColumns.join(', ');
    final namedAccess = nodeColumns.join(', ');

    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      nodes[$nodeBindings] := *$nodeRelation{$namedAccess}
      starting[] <- [$starts]
      ?[start, answer, path] <~ DFS(edges[], nodes[$nodeBindings], starting[], condition: $condition, limit: $limit)
    ''');
  }

  /// Find shortest paths using Dijkstra's algorithm (weighted edges).
  ///
  /// The [edgeRelation] may have a third column for edge weight.
  /// If no weight column exists, all edges are treated as unit weight.
  ///
  /// - [undirected]: Treat edges as undirected. Defaults to `false`.
  /// - [keepTies]: Return all equally-shortest paths. Defaults to `false`.
  ///
  /// Returns rows with columns: `start`, `goal`, `cost`, `path`.
  ///
  /// ```dart
  /// final result = await graph.shortestPathDijkstra(
  ///   'roads', [cityA], [cityB],
  ///   weightCol: 'distance',
  ///   undirected: true,
  /// );
  /// ```
  Future<CozoResult> shortestPathDijkstra(
    String edgeRelation,
    List<dynamic> startingNodes,
    List<dynamic> goalNodes, {
    String fromCol = 'from',
    String toCol = 'to',
    String? weightCol,
    bool undirected = false,
    bool keepTies = false,
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final goals =
        goalNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');

    final edgeCols = weightCol != null
        ? '$fromCol, $toCol, $weightCol'
        : '$fromCol, $toCol';

    return db.queryImmutable('''
      edges[$edgeCols] := *$edgeRelation[$edgeCols]
      starting[] <- [$starts]
      goals[] <- [$goals]
      ?[start, goal, cost, path] <~ ShortestPathDijkstra(edges[], starting[], goals[], undirected: $undirected, keep_ties: $keepTies)
    ''');
  }

  /// Find the k shortest paths using Yen's algorithm.
  ///
  /// Returns up to [k] paths for each start–goal pair, ordered by cost.
  /// Backed by Dijkstra's algorithm internally.
  ///
  /// - [k]: Number of shortest paths to return per pair. Required.
  /// - [undirected]: Treat edges as undirected. Defaults to `false`.
  ///
  /// Returns rows with columns: `start`, `goal`, `cost`, `path`.
  ///
  /// ```dart
  /// final result = await graph.kShortestPathsYen(
  ///   'roads', [cityA], [cityB],
  ///   k: 3,
  ///   weightCol: 'distance',
  /// );
  /// // Returns up to 3 alternative routes
  /// ```
  Future<CozoResult> kShortestPathsYen(
    String edgeRelation,
    List<dynamic> startingNodes,
    List<dynamic> goalNodes, {
    required int k,
    String fromCol = 'from',
    String toCol = 'to',
    String? weightCol,
    bool undirected = false,
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final goals =
        goalNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');

    final edgeCols = weightCol != null
        ? '$fromCol, $toCol, $weightCol'
        : '$fromCol, $toCol';

    return db.queryImmutable('''
      edges[$edgeCols] := *$edgeRelation[$edgeCols]
      starting[] <- [$starts]
      goals[] <- [$goals]
      ?[start, goal, cost, path] <~ KShortestPathYen(edges[], starting[], goals[], k: $k, undirected: $undirected)
    ''');
  }

  /// Find shortest paths using A* algorithm with a custom heuristic.
  ///
  /// The [edgeRelation] must have a third column for edge weight.
  /// [startingNodes] and [goalNodes] define the search endpoints.
  ///
  /// Returns rows with columns: `start`, `goal`, `cost`, `path`.
  Future<CozoResult> shortestPathAStar(
    String edgeRelation,
    List<dynamic> startingNodes,
    List<dynamic> goalNodes, {
    String fromCol = 'from',
    String toCol = 'to',
    String weightCol = 'weight',
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final goals =
        goalNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');

    return db.queryImmutable('''
      edges[$fromCol, $toCol, $weightCol] := *$edgeRelation[$fromCol, $toCol, $weightCol]
      starting[] <- [$starts]
      goals[] <- [$goals]
      ?[start, goal, cost, path] <~ ShortestPathAStar(edges[], starting[], goals[])
    ''');
  }

  // ──────────── Minimum Spanning Tree ────────────

  /// Compute the minimum spanning tree using Kruskal's algorithm.
  ///
  /// The [edgeRelation] must have a third column for edge weight.
  ///
  /// Returns rows with columns: `from`, `to`, `weight` representing
  /// the edges in the MST.
  Future<CozoResult> minimumSpanningTreeKruskal(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
    String weightCol = 'weight',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol, $weightCol] := *$edgeRelation[$fromCol, $toCol, $weightCol]
      ?[fr, to, weight] <~ MinimumSpanningTreeKruskal(edges[])
    ''');
  }

  /// Compute the minimum spanning tree using Prim's algorithm.
  ///
  /// Alternative to Kruskal — often faster for dense graphs.
  /// The [edgeRelation] must have a third column for edge weight.
  ///
  /// Returns rows with columns: `from`, `to`, `weight`.
  Future<CozoResult> minimumSpanningTreePrim(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
    String weightCol = 'weight',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol, $weightCol] := *$edgeRelation[$fromCol, $toCol, $weightCol]
      ?[fr, to, weight] <~ MinimumSpanningTreePrim(edges[])
    ''');
  }

  // ──────────── Topological ────────────

  /// Perform a topological sort on a directed acyclic graph (DAG).
  ///
  /// Returns nodes in dependency order — if A→B exists, A appears
  /// before B. Useful for task scheduling, build systems, goal planning.
  ///
  /// Throws if the graph contains cycles.
  ///
  /// Returns rows with columns: `node`, `order` (0-indexed position).
  Future<CozoResult> topologicalSort(
    String edgeRelation, {
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      ?[node, order] <~ TopSort(edges[])
    ''');
  }

  // ──────────── Random Walk ────────────

  /// Perform random walks starting from given nodes.
  ///
  /// Useful for Node2Vec-style graph embeddings, sampling, and exploration.
  ///
  /// - [startingNodes]: Nodes to start walks from.
  /// - [steps]: Number of steps per walk.
  /// - [walks]: Number of walks per starting node.
  /// - [weight]: Whether to use weighted edges (requires a weight column).
  ///
  /// Returns rows with columns: `node`, `starting_node`, `path` (list of visited nodes).
  Future<CozoResult> randomWalk(
    String edgeRelation,
    List<dynamic> startingNodes, {
    int steps = 10,
    int walks = 1,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');

    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      nodes[n] := edges[n, _]
      nodes[n] := edges[_, n]
      starting[] <- [$starts]
      ?[node, starting_node, path] <~ RandomWalk(edges[], nodes[], starting[], steps: $steps, walks: $walks)
    ''');
  }

  String _toCozoLiteral(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is List) {
      return '[${value.map(_toCozoLiteral).join(", ")}]';
    }
    return '"${value.toString().replaceAll('"', '\\"')}"';
  }
}
