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
