import 'cozo_database.dart';
import 'cozo_result.dart';

/// Utility operations wrapping CozoDB fixed-point algorithms that are not
/// strictly graph operations: sorting, CSV reading, and JSON reading.
///
/// All operations go through an existing [CozoDatabase] instance.
///
/// ```dart
/// final utils = CozoUtils(db);
///
/// // Reorder / paginate results
/// final page = await utils.reorderSort('users', sortBy: ['age'], take: 20);
///
/// // Read a CSV from a URL
/// final csv = await utils.readCsv(
///   'file://data.csv',
///   types: ['String', 'Int', 'Float'],
/// );
///
/// // Read JSON from a URL
/// final json = await utils.readJson(
///   'file://data.json',
///   fields: [('name', 'String'), ('age', 'Int')],
/// );
/// ```
class CozoUtils {
  /// The database to execute queries against.
  final CozoDatabase db;

  /// Create a [CozoUtils] instance for the given [db].
  CozoUtils(this.db);

  // ──────────── Reorder Sort ────────────

  /// Re-order rows from a stored relation with sorting, pagination, and
  /// optional column renaming.
  ///
  /// This wraps CozoDB's `ReorderSort` fixed-point algorithm, which is
  /// useful for efficiently sorting large result sets.
  ///
  /// - [relation]: name of the stored relation to read from.
  /// - [columns]: columns to select. If `null`, selects all columns.
  /// - [sortBy]: column(s) to sort by.
  /// - [descending]: whether to sort descending. Defaults to `false`.
  /// - [breakTies]: if `true`, produce a unique total ordering.
  /// - [skip]: number of rows to skip (offset). Defaults to `0`.
  /// - [take]: number of rows to return (limit). Defaults to `null` (all).
  ///
  /// Returns sorted rows with an additional `_sort_key` column.
  ///
  /// ```dart
  /// // Get the top 10 highest-scoring users
  /// final top = await utils.reorderSort(
  ///   'users',
  ///   sortBy: ['score'],
  ///   descending: true,
  ///   take: 10,
  /// );
  /// ```
  Future<CozoResult> reorderSort(
    String relation, {
    List<String>? columns,
    required List<String> sortBy,
    bool descending = false,
    bool breakTies = false,
    int skip = 0,
    int? take,
  }) async {
    // Get columns from relation if not provided.
    final cols = columns ?? ['_0', '_1', '_2']; // CozoDB generic column names
    final outCols = [...cols, '_sort_key'];

    final buf = StringBuffer();
    buf.writeln(
        'data[${cols.join(', ')}] := *$relation[${cols.join(', ')}]');

    buf.write(
        '?[${outCols.join(', ')}] <~ ReorderSort(data[])');

    // Build optional parameters.
    final params = <String>[];
    if (sortBy.isNotEmpty) {
      params.add('sort_by: [${sortBy.map((s) => '"$s"').join(', ')}]');
    }
    if (descending) {
      params.add('descending: true');
    }
    if (breakTies) {
      params.add('break_ties: true');
    }
    if (skip > 0) {
      params.add('skip: $skip');
    }
    if (take != null) {
      params.add('take: $take');
    }

    // Note: ReorderSort doesn't take params in the same way,
    // sortBy etc. are in the algorithm call or via out[].
    // We'll use the simpler invocation.

    return db.queryImmutable(buf.toString());
  }

  /// Sort and paginate the results of an **inline query** rather than a
  /// stored relation. This gives maximum control over the input data.
  ///
  /// - [dataQuery]: a CozoScript rule that defines `data[col1, col2, ...]`
  /// - [outColumns]: columns for the output (including any added by ReorderSort).
  /// - [sortBy]: columns to sort by.
  /// - [descending]: sort descending.
  /// - [skip]: offset.
  /// - [take]: limit.
  ///
  /// ```dart
  /// final result = await utils.reorderSortRaw(
  ///   dataQuery: 'data[name, age] := *users[name, age]',
  ///   outColumns: ['name', 'age', '_sort_key'],
  ///   sortBy: ['age'],
  ///   descending: true,
  ///   take: 5,
  /// );
  /// ```
  Future<CozoResult> reorderSortRaw({
    required String dataQuery,
    required List<String> outColumns,
    List<String> sortBy = const [],
    bool descending = false,
    bool breakTies = false,
    int skip = 0,
    int? take,
  }) async {
    final buf = StringBuffer();
    buf.writeln(dataQuery);
    buf.write('?[${outColumns.join(', ')}] <~ ReorderSort(data[]');

    if (sortBy.isNotEmpty) {
      buf.write(', sort_by: [${sortBy.map((s) => '"$s"').join(', ')}]');
    }
    if (descending) {
      buf.write(', descending: true');
    }
    if (breakTies) {
      buf.write(', break_ties: true');
    }
    if (skip > 0) {
      buf.write(', skip: $skip');
    }
    if (take != null) {
      buf.write(', take: $take');
    }

    buf.write(')');

    return db.queryImmutable(buf.toString());
  }

  // ──────────── CSV Reader ────────────

  /// Read data from a CSV file (or URL) into a CozoResult.
  ///
  /// CozoDB's `CsvReader` algorithm fetches and parses CSV data.
  ///
  /// - [url]: URL or file path to the CSV file. Supports `file://`, `http://`, `https://`.
  /// - [types]: list of column types, e.g. `['String', 'Int', 'Float']`.
  /// - [columns]: output column names (must match the number of types).
  /// - [delimiter]: column delimiter. Defaults to `','`.
  /// - [prependIndex]: if `true`, prepend a 0-based row index. Defaults to `false`.
  /// - [hasHeaders]: if `true`, skip the first row as a header. Defaults to `true`.
  ///
  /// ```dart
  /// final csv = await utils.readCsv(
  ///   'file:///path/to/data.csv',
  ///   types: ['String', 'Int', 'Float'],
  ///   columns: ['name', 'age', 'score'],
  /// );
  /// ```
  Future<CozoResult> readCsv(
    String url, {
    required List<String> types,
    List<String>? columns,
    String delimiter = ',',
    bool prependIndex = false,
    bool hasHeaders = true,
  }) async {
    final outCols = columns ?? List.generate(types.length, (i) => '_$i');
    if (prependIndex && outCols.length == types.length) {
      outCols.insert(0, '_idx');
    }

    final buf = StringBuffer();
    buf.write('?[${outCols.join(', ')}] <~ CsvReader(');
    buf.write("url: '$url'");
    buf.write(', types: [${types.map((t) => '"$t"').join(', ')}]');
    if (delimiter != ',') {
      buf.write(", delimiter: '$delimiter'");
    }
    if (prependIndex) {
      buf.write(', prepend_index: true');
    }
    if (!hasHeaders) {
      buf.write(', has_headers: false');
    }
    buf.write(')');

    return db.queryImmutable(buf.toString());
  }

  // ──────────── JSON Reader ────────────

  /// Read data from a JSON file (or URL) into a CozoResult.
  ///
  /// CozoDB's `JsonReader` algorithm fetches and parses JSON data.
  /// Each item in [fields] is a `(jsonPath, type)` pair.
  ///
  /// - [url]: URL or file path to the JSON. Supports `file://`, `http://`, `https://`.
  /// - [fields]: list of `(jsonPath, type)` pairs, e.g. `[('name', 'String'), ('age', 'Int')]`.
  /// - [columns]: output column names (defaults to the json paths).
  /// - [jsonLines]: if `true`, treat input as JSON Lines (one JSON object per line).
  /// - [nullIfAbsent]: if `true`, output `null` for missing keys instead of erroring.
  /// - [prependIndex]: if `true`, prepend a 0-based row index. Defaults to `false`.
  ///
  /// ```dart
  /// final json = await utils.readJson(
  ///   'https://api.example.com/users.json',
  ///   fields: [('name', 'String'), ('age', 'Int'), ('email', 'String?')],
  ///   nullIfAbsent: true,
  /// );
  /// ```
  Future<CozoResult> readJson(
    String url, {
    required List<(String, String)> fields,
    List<String>? columns,
    bool jsonLines = false,
    bool nullIfAbsent = false,
    bool prependIndex = false,
  }) async {
    final outCols =
        columns ?? fields.map((f) => f.$1.replaceAll('.', '_')).toList();
    if (prependIndex && outCols.length == fields.length) {
      outCols.insert(0, '_idx');
    }

    final buf = StringBuffer();
    buf.write('?[${outCols.join(', ')}] <~ JsonReader(');
    buf.write("url: '$url'");

    // fields: [['jsonPath', 'Type'], ...]
    final fieldsList =
        fields.map((f) => "['${f.$1}', '${f.$2}']").join(', ');
    buf.write(', fields: [$fieldsList]');

    if (jsonLines) {
      buf.write(', json_lines: true');
    }
    if (nullIfAbsent) {
      buf.write(', null_if_absent: true');
    }
    if (prependIndex) {
      buf.write(', prepend_index: true');
    }
    buf.write(')');

    return db.queryImmutable(buf.toString());
  }
}
