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

  /// Find the shortest path between two nodes.
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
      ?[node] <~ ShortestPathBFS(edges[], starting[], ending: [$to])
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
  Future<CozoResult> bfs(
    String edgeRelation,
    List<dynamic> startingNodes, {
    int? maxDepth,
    String fromCol = 'from',
    String toCol = 'to',
  }) async {
    final starts =
        startingNodes.map(_toCozoLiteral).map((s) => '[$s]').join(', ');
    final depthClause = maxDepth != null ? ', limit: $maxDepth' : '';
    return db.queryImmutable('''
      edges[$fromCol, $toCol] := *$edgeRelation[$fromCol, $toCol]
      starting[] <- [$starts]
      ?[node, depth] <~ BFS(edges[], starting[]$depthClause)
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
