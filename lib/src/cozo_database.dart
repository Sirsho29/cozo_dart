import 'dart:convert';

import 'cozo_exception.dart';
import 'cozo_result.dart';
import 'rust/api/simple.dart' as bridge;
import 'rust/frb_generated.dart';

/// Storage engine options for CozoDB.
enum CozoEngine {
  /// In-memory, non-persistent database. Fast, data lost on close.
  memory('mem'),

  /// SQLite-backed persistent database. Recommended for mobile.
  sqlite('sqlite');

  final String value;
  const CozoEngine(this.value);
}

/// A CozoDB database instance.
///
/// Usage:
/// ```dart
/// final db = await CozoDatabase.open(
///   engine: CozoEngine.sqlite,
///   path: '/path/to/db',
/// );
///
/// final result = await db.query('?[a] := a in [1, 2, 3]');
/// print(result.rows);
///
/// await db.close();
/// ```
class CozoDatabase {
  final bridge.CozoDb _handle;
  bool _closed = false;

  CozoDatabase._(this._handle);

  /// Initialize the FRB runtime. Must be called once before using CozoDB.
  static Future<void> init() async {
    await RustLib.init();
  }

  /// Open a CozoDB database.
  ///
  /// - [engine]: Storage backend. Use [CozoEngine.sqlite] for persistence.
  /// - [path]: File path for SQLite engine. Ignored for memory engine.
  /// - [options]: JSON string of engine-specific options. Defaults to "{}".
  static Future<CozoDatabase> open({
    CozoEngine engine = CozoEngine.memory,
    String path = '',
    String options = '{}',
  }) async {
    try {
      final handle = bridge.cozoOpenDb(
        engine: engine.value,
        path: path,
        options: options,
      );
      return CozoDatabase._(handle);
    } catch (e) {
      throw CozoDatabaseException('Failed to open database: $e');
    }
  }

  /// Open an in-memory database (convenience constructor).
  static Future<CozoDatabase> openMemory() async {
    return open(engine: CozoEngine.memory);
  }

  /// Open a SQLite-backed database at the given path.
  static Future<CozoDatabase> openSqlite(String path) async {
    return open(engine: CozoEngine.sqlite, path: path);
  }

  void _ensureOpen() {
    if (_closed) throw CozoDatabaseException('Database is closed');
  }

  // ──────────── System Operations ────────────

  /// List all stored relations in the database.
  ///
  /// Returns a [CozoResult] with columns about each relation including
  /// name, arity, access level, and description.
  ///
  /// ```dart
  /// final relations = await db.listRelations();
  /// for (final row in relations.toMaps()) {
  ///   print(row['name']);
  /// }
  /// ```
  Future<CozoResult> listRelations() async {
    return queryImmutable('::relations');
  }

  /// Describe the columns of a stored relation.
  ///
  /// Returns a [CozoResult] with column metadata: name, type,
  /// whether it's a key column, index, etc.
  ///
  /// ```dart
  /// final schema = await db.describeRelation('users');
  /// for (final col in schema.toMaps()) {
  ///   print('${col['column']}: ${col['type']} (key: ${col['is_key']})');
  /// }
  /// ```
  Future<CozoResult> describeRelation(String name) async {
    return queryImmutable('::columns $name');
  }

  /// List all indices (HNSW, FTS, LSH) on a stored relation.
  ///
  /// Returns a [CozoResult] describing each index, its type,
  /// and configuration parameters.
  Future<CozoResult> listIndices(String relation) async {
    return queryImmutable('::indices $relation');
  }

  /// Show the query execution plan without executing the query.
  ///
  /// Useful for debugging and optimizing complex CozoScript queries.
  /// Returns a [CozoResult] describing the execution steps.
  ///
  /// ```dart
  /// final plan = await db.explain(
  ///   '?[name] := *users[name, age, _, _], age > 30',
  /// );
  /// print(plan.toMaps());
  /// ```
  Future<CozoResult> explain(String script) async {
    return queryImmutable('::explain { $script }');
  }

  /// List currently running queries.
  ///
  /// Returns a [CozoResult] with information about active queries
  /// including their IDs, which can be used with [cancelQuery].
  Future<CozoResult> listRunningQueries() async {
    return queryImmutable('::running');
  }

  /// Cancel a running query by its ID.
  ///
  /// Use [listRunningQueries] to obtain query IDs.
  Future<CozoResult> cancelQuery(int queryId) async {
    return query('::kill $queryId');
  }

  /// Remove one or more stored relations from the database.
  ///
  /// **Warning:** This permanently deletes the relations and all their data.
  /// Relations with access level `protected` or higher cannot be removed.
  ///
  /// ```dart
  /// await db.removeRelations(['temp_data', 'old_logs']);
  /// ```
  Future<CozoResult> removeRelations(List<String> relations) async {
    return query('::remove ${relations.join(', ')}');
  }

  /// Rename one or more stored relations.
  ///
  /// Each entry in [renames] maps old name → new name.
  ///
  /// ```dart
  /// await db.renameRelations({'old_users': 'users', 'temp': 'archive'});
  /// ```
  Future<CozoResult> renameRelations(Map<String, String> renames) async {
    final pairs = renames.entries.map((e) => '${e.key} -> ${e.value}').join(', ');
    return query('::rename $pairs');
  }

  /// Display triggers associated with a stored relation.
  ///
  /// Returns a [CozoResult] describing any on-put or on-rm triggers
  /// that are set on the relation.
  Future<CozoResult> showTriggers(String relation) async {
    return queryImmutable('::show_triggers $relation');
  }

  /// Set triggers on a stored relation.
  ///
  /// Triggers are CozoScript queries that run automatically when rows
  /// are inserted (`:put`) or deleted (`:rm`) from the relation.
  ///
  /// - [onPut]: List of CozoScript queries to run on insert/update.
  /// - [onRm]: List of CozoScript queries to run on delete.
  ///
  /// Pass empty lists to clear existing triggers.
  ///
  /// ```dart
  /// await db.setTriggers('users',
  ///   onPut: [
  ///     '?[id, ts] := _new[id, _, _, _, _], ts = now()\n:put user_log {id, ts}',
  ///   ],
  /// );
  /// ```
  Future<CozoResult> setTriggers(
    String relation, {
    List<String> onPut = const [],
    List<String> onRm = const [],
  }) async {
    final buf = StringBuffer('::set_triggers $relation');
    for (final trigger in onPut) {
      buf.write('\n\non put { $trigger }');
    }
    for (final trigger in onRm) {
      buf.write('\n\non rm { $trigger }');
    }
    return query(buf.toString());
  }

  /// Set the access level on one or more stored relations.
  ///
  /// Access levels protect data from accidental modification:
  /// - `normal`: allows everything (default)
  /// - `protected`: disallows `::remove` and `:replace`
  /// - `read_only`: additionally disallows any mutations and setting triggers
  /// - `hidden`: additionally disallows any data access
  ///
  /// ```dart
  /// await db.setAccessLevel('protected', ['users', 'config']);
  /// ```
  Future<CozoResult> setAccessLevel(
    String level,
    List<String> relations,
  ) async {
    return query('::access_level $level ${relations.join(', ')}');
  }

  /// Run database compaction.
  ///
  /// Makes the database smaller on disk and faster for read queries.
  /// Safe to call at any time; a no-op for in-memory databases.
  Future<CozoResult> compact() async {
    return query('::compact');
  }

  // ──────────── Queries ────────────

  /// Run a CozoScript query (mutable — allows writes).
  ///
  /// ```dart
  /// // Simple query
  /// final result = await db.query('?[a] := a in [1, 2, 3]');
  ///
  /// // With parameters
  /// final result = await db.query(
  ///   r'?[name] := *users[name, age], age > $min_age',
  ///   params: {'min_age': 21},
  /// );
  /// ```
  Future<CozoResult> query(
    String script, {
    Map<String, dynamic>? params,
  }) async {
    _ensureOpen();
    try {
      final paramsJson = json.encode(params ?? {});
      final resultJson = await bridge.cozoRunQuery(
        db: _handle,
        script: script,
        paramsJson: paramsJson,
        immutable: false,
      );
      return CozoResult.fromJson(resultJson);
    } catch (e) {
      if (e is CozoQueryException) rethrow;
      throw CozoDatabaseException('Query execution failed: $e');
    }
  }

  /// Run a read-only CozoScript query (immutable — no writes allowed).
  Future<CozoResult> queryImmutable(
    String script, {
    Map<String, dynamic>? params,
  }) async {
    _ensureOpen();
    try {
      final paramsJson = json.encode(params ?? {});
      final resultJson = await bridge.cozoRunQuery(
        db: _handle,
        script: script,
        paramsJson: paramsJson,
        immutable: true,
      );
      return CozoResult.fromJson(resultJson);
    } catch (e) {
      if (e is CozoQueryException) rethrow;
      throw CozoDatabaseException('Query execution failed: $e');
    }
  }

  /// Export relations from the database.
  ///
  /// Returns a map where keys are relation names and values contain
  /// 'headers' and 'rows' for each relation.
  Future<Map<String, dynamic>> exportRelations(List<String> relations) async {
    _ensureOpen();
    try {
      final payload = json.encode({'relations': relations});
      final resultJson = await bridge.cozoExportRelations(
        db: _handle,
        relationsJson: payload,
      );
      final decoded = json.decode(resultJson) as Map<String, dynamic>;
      if (decoded['ok'] == true && decoded.containsKey('data')) {
        return decoded['data'] as Map<String, dynamic>;
      }
      return decoded;
    } catch (e) {
      throw CozoDatabaseException('Export failed: $e');
    }
  }

  /// Import relations into the database.
  ///
  /// The [data] should be a map where keys are relation names and values
  /// contain 'headers' and 'rows' matching the export format.
  Future<void> importRelations(Map<String, dynamic> data) async {
    _ensureOpen();
    try {
      await bridge.cozoImportRelations(
        db: _handle,
        dataJson: json.encode(data),
      );
    } catch (e) {
      throw CozoDatabaseException('Import failed: $e');
    }
  }

  /// Backup the database to a file.
  Future<void> backup(String path) async {
    _ensureOpen();
    try {
      await bridge.cozoBackup(db: _handle, path: path);
    } catch (e) {
      throw CozoDatabaseException('Backup failed: $e');
    }
  }

  /// Restore the database from a backup file.
  Future<void> restore(String path) async {
    _ensureOpen();
    try {
      await bridge.cozoRestore(db: _handle, path: path);
    } catch (e) {
      throw CozoDatabaseException('Restore failed: $e');
    }
  }

  /// Import relations from a backup file.
  Future<void> importFromBackup(String path, List<String> relations) async {
    _ensureOpen();
    try {
      await bridge.cozoImportFromBackup(
        db: _handle,
        path: path,
        relationsJson: json.encode(relations),
      );
    } catch (e) {
      throw CozoDatabaseException('Import from backup failed: $e');
    }
  }

  /// Close the database and release resources.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // FRB handles Rust object cleanup via Drop when the Dart object is GC'd.
  }

  /// Whether this database instance has been closed.
  bool get isClosed => _closed;
}
