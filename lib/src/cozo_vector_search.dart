import 'cozo_database.dart';
import 'cozo_result.dart';

/// Distance metric for HNSW vector search.
enum VectorDistance {
  /// L2 (Euclidean) distance.
  l2('L2'),

  /// Cosine distance (1 - cosine similarity).
  cosine('Cosine'),

  /// Inner product distance (negative dot product).
  innerProduct('InnerProduct');

  final String value;
  const VectorDistance(this.value);
}

/// Vector data type for stored vectors.
enum VectorDType {
  /// 32-bit floating point. Smaller, faster, sufficient for most use cases.
  f32('F32'),

  /// 64-bit floating point. Higher precision.
  f64('F64');

  final String value;
  const VectorDType(this.value);
}

/// HNSW vector index and nearest-neighbor search operations for CozoDB.
///
/// CozoDB natively supports HNSW (Hierarchical Navigable Small World)
/// indices for approximate nearest neighbor (ANN) search. This class
/// provides convenient methods for creating indices, running vector
/// queries, and combining them with Datalog conditions (hybrid search).
///
/// ## Quick start
///
/// ```dart
/// final db = await CozoDatabase.openMemory();
/// final vecSearch = CozoVectorSearch(db);
///
/// // 1. Create a relation with a vector column
/// await db.query(
///   ':create documents {id: Int => content: String, embedding: <F32; 128>}',
/// );
///
/// // 2. Insert data (vectors use the vec() wrapper)
/// await vecSearch.upsert('documents', [
///   {'id': 1, 'content': 'hello world', 'embedding': [0.1, 0.2, ...]},
/// ], vectorColumns: {'embedding'});
///
/// // 3. Create an HNSW index
/// await vecSearch.createIndex(
///   'documents', 'doc_vec_idx',
///   dim: 128,
///   fields: ['embedding'],
///   distance: VectorDistance.cosine,
/// );
///
/// // 4. Search for nearest neighbors
/// final results = await vecSearch.search(
///   'documents', 'doc_vec_idx',
///   queryVector: queryEmbedding,
///   bindFields: ['id', 'content'],
///   k: 10,
/// );
/// ```
///
/// ## Vector column types
///
/// When creating relations with vector columns, use the CozoDB type syntax:
/// - `<F32; 128>` — 128-dimensional float32 vector
/// - `<F64; 256>` — 256-dimensional float64 vector
class CozoVectorSearch {
  final CozoDatabase db;

  const CozoVectorSearch(this.db);

  /// Create an HNSW vector index on a stored relation.
  ///
  /// - [relation]: Name of the stored relation containing vector data.
  /// - [indexName]: Name for the new index (unique within the relation).
  /// - [dim]: Dimensionality of the vectors.
  /// - [fields]: Column names containing vectors to index (usually one).
  /// - [distance]: Distance metric. Defaults to [VectorDistance.cosine].
  /// - [dtype]: Vector data type. Defaults to [VectorDType.f32].
  /// - [m]: Max edges per node in the HNSW graph. Higher values give more
  ///   accurate searches but slower index construction. Typical range: 12-64.
  /// - [efConstruction]: Size of the dynamic candidate list during
  ///   construction. Higher = better recall, slower builds. Typical: 100-500.
  /// - [extendCandidates]: Whether to extend the candidate list during
  ///   construction. Can improve recall for high-dimensional data.
  /// - [keepPrunedConnections]: Whether to retain pruned connections.
  ///   Can improve recall at the cost of higher memory usage.
  ///
  /// ```dart
  /// await vecSearch.createIndex(
  ///   'documents', 'doc_vec_idx',
  ///   dim: 1536,  // OpenAI ada-002 embedding size
  ///   fields: ['embedding'],
  ///   distance: VectorDistance.cosine,
  ///   m: 32,
  ///   efConstruction: 200,
  /// );
  /// ```
  Future<CozoResult> createIndex(
    String relation,
    String indexName, {
    required int dim,
    required List<String> fields,
    VectorDistance distance = VectorDistance.cosine,
    VectorDType dtype = VectorDType.f32,
    int m = 50,
    int efConstruction = 200,
    bool extendCandidates = false,
    bool keepPrunedConnections = false,
  }) async {
    final fieldsList = fields.join(', ');
    return db.query(
      '::hnsw create $relation:$indexName {'
      ' dim: $dim,'
      ' m: $m,'
      ' dtype: ${dtype.value},'
      ' fields: [$fieldsList],'
      ' distance: ${distance.value},'
      ' ef_construction: $efConstruction,'
      ' extend_candidates: $extendCandidates,'
      ' keep_pruned_connections: $keepPrunedConnections'
      ' }',
    );
  }

  /// Drop an HNSW vector index.
  ///
  /// The underlying stored relation is not affected.
  Future<CozoResult> dropIndex(String relation, String indexName) async {
    return db.query('::hnsw drop $relation:$indexName');
  }

  /// Search for the k approximate nearest neighbors of a query vector.
  ///
  /// - [relation]: Name of the indexed relation.
  /// - [indexName]: Name of the HNSW index.
  /// - [queryVector]: The query vector (length must match index dimension).
  /// - [bindFields]: Columns from the relation to include in results.
  /// - [k]: Number of nearest neighbors to return. Defaults to 10.
  /// - [ef]: Search-time ef parameter. Higher = more accurate but slower.
  ///   Must be >= k. If omitted, uses the index default.
  /// - [bindDistance]: Output column name for neighbor distances.
  /// - [radius]: Maximum distance threshold. Only returns results within
  ///   this distance from the query vector.
  /// - [filter]: CozoScript boolean expression for pre-filtering candidates
  ///   before the ANN search. References columns from the indexed relation.
  ///
  /// Returns a [CozoResult] with the requested [bindFields] plus a
  /// distance column (named by [bindDistance]).
  ///
  /// ```dart
  /// final results = await vecSearch.search(
  ///   'documents', 'doc_vec_idx',
  ///   queryVector: [0.1, 0.2, ...],  // 128 floats
  ///   bindFields: ['id', 'content'],
  ///   k: 10,
  ///   ef: 50,
  /// );
  /// for (final row in results.toMaps()) {
  ///   print('${row['content']} (distance: ${row['distance']})');
  /// }
  /// ```
  Future<CozoResult> search(
    String relation,
    String indexName, {
    required List<double> queryVector,
    required List<String> bindFields,
    int k = 10,
    int? ef,
    String bindDistance = 'distance',
    double? radius,
    String? filter,
  }) async {
    final effectiveEf = ef ?? k;
    final searchParams = StringBuffer('query: vec(\$_q), k: $k, ef: $effectiveEf');
    searchParams.write(', bind_distance: $bindDistance');
    if (radius != null) searchParams.write(', radius: $radius');
    if (filter != null) searchParams.write(', filter: $filter');

    final outputFields = [...bindFields, bindDistance];

    return db.query(
      '?[${outputFields.join(', ')}] := '
      '~$relation:$indexName{ ${bindFields.join(', ')} '
      '| $searchParams }',
      params: {'_q': queryVector},
    );
  }

  /// Search for nearest neighbors with additional Datalog join conditions.
  ///
  /// This enables **hybrid search** — combining vector similarity with
  /// structured relational filters, graph traversals, or aggregations
  /// using CozoDB's Datalog engine.
  ///
  /// The [joinConditions] string is appended after the vector search clause.
  /// It can reference any variable bound by the vector search (from
  /// [bindFields] and [bindDistance]), plus variables from other relations.
  ///
  /// ```dart
  /// // Find similar documents by a specific author, written recently
  /// final results = await vecSearch.searchWithConditions(
  ///   'documents', 'doc_vec_idx',
  ///   queryVector: queryEmbedding,
  ///   bindFields: ['id', 'content'],
  ///   k: 50,  // over-fetch to account for filtering
  ///   joinConditions:
  ///     '*documents{ id, author_id, timestamp },'
  ///     ' *users{ author_id, author_name },'
  ///     ' timestamp > 1700000000',
  ///   outputFields: ['content', 'author_name', 'distance'],
  /// );
  /// ```
  Future<CozoResult> searchWithConditions(
    String relation,
    String indexName, {
    required List<double> queryVector,
    required List<String> bindFields,
    required String joinConditions,
    required List<String> outputFields,
    int k = 10,
    int? ef,
    String bindDistance = 'distance',
    double? radius,
    Map<String, dynamic>? additionalParams,
  }) async {
    final effectiveEf = ef ?? k;
    final searchParams = StringBuffer('query: vec(\$_q), k: $k, ef: $effectiveEf');
    searchParams.write(', bind_distance: $bindDistance');
    if (radius != null) searchParams.write(', radius: $radius');

    final params = <String, dynamic>{
      '_q': queryVector,
      ...?additionalParams,
    };

    final script = '?[${outputFields.join(', ')}] := '
        '~$relation:$indexName{ ${bindFields.join(', ')} '
        '| $searchParams }, $joinConditions';

    return db.query(script, params: params);
  }

  /// Insert or update rows containing vector data into a relation.
  ///
  /// Handles the `vec()` wrapping automatically for columns listed in
  /// [vectorColumns]. All other columns are serialized normally.
  ///
  /// - [relation]: Target stored relation.
  /// - [rows]: List of row maps (column name → value). Vector columns
  ///   should be `List<double>`.
  /// - [vectorColumns]: Set of column names that contain vector data.
  ///
  /// ```dart
  /// await vecSearch.upsert('documents', [
  ///   {'id': 1, 'content': 'hello', 'embedding': [0.1, 0.2, 0.3]},
  ///   {'id': 2, 'content': 'world', 'embedding': [0.4, 0.5, 0.6]},
  /// ], vectorColumns: {'embedding'});
  /// ```
  Future<CozoResult> upsert(
    String relation,
    List<Map<String, dynamic>> rows, {
    required Set<String> vectorColumns,
  }) async {
    if (rows.isEmpty) return db.query('?[] <- [[]]');

    final columns = rows.first.keys.toList();
    final bindings = columns.join(', ');
    final data = rows
        .map((row) => '[${columns.map((c) {
              final v = row[c];
              if (vectorColumns.contains(c) && v is List) {
                return 'vec([${v.join(", ")}])';
              }
              return _toCozoLiteral(v);
            }).join(", ")}]')
        .join(', ');

    return db.query('?[$bindings] <- [$data]\n:put $relation {$bindings}');
  }

  /// Remove rows from a vector relation by key columns.
  ///
  /// Same as [CozoGraph.remove] but provided here for convenience
  /// so you don't need to import [CozoGraph] for vector workflows.
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
