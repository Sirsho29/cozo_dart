import 'dart:convert';

import 'cozo_exception.dart';

/// Represents the result of a CozoScript query.
class CozoResult {
  /// Column headers for the result set.
  final List<String> headers;

  /// Row data. Each row is a List of dynamic values.
  final List<List<dynamic>> rows;

  /// Time taken by the query in seconds.
  final double? took;

  const CozoResult({
    required this.headers,
    required this.rows,
    this.took,
  });

  /// Parse a CozoResult from the JSON string returned by the Rust bridge.
  factory CozoResult.fromJson(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;

    if (map['ok'] != true) {
      throw CozoQueryException(
        message: map['display'] as String? ?? 'Unknown query error',
        rawResponse: jsonString,
      );
    }

    final headers =
        (map['headers'] as List<dynamic>).map((h) => h.toString()).toList();

    final rows = (map['rows'] as List<dynamic>)
        .map((row) => (row as List<dynamic>).toList())
        .toList();

    final took = (map['took'] as num?)?.toDouble();

    return CozoResult(headers: headers, rows: rows, took: took);
  }

  /// Number of rows in the result.
  int get length => rows.length;

  /// Whether the result set is empty.
  bool get isEmpty => rows.isEmpty;

  /// Whether the result set is not empty.
  bool get isNotEmpty => rows.isNotEmpty;

  /// Get column index by header name. Returns -1 if not found.
  int columnIndex(String header) => headers.indexOf(header);

  /// Convert result to a list of maps (header → value).
  List<Map<String, dynamic>> toMaps() {
    return rows.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();
  }

  /// Get a single column's values by header name.
  List<dynamic> column(String header) {
    final idx = columnIndex(header);
    if (idx == -1) throw ArgumentError('Column "$header" not found');
    return rows.map((row) => row[idx]).toList();
  }

  /// Get the first row as a map, or null if empty.
  Map<String, dynamic>? get firstOrNull {
    if (isEmpty) return null;
    final map = <String, dynamic>{};
    for (var i = 0; i < headers.length && i < rows[0].length; i++) {
      map[headers[i]] = rows[0][i];
    }
    return map;
  }

  @override
  String toString() =>
      'CozoResult(${rows.length} rows, ${headers.length} columns, took: ${took}s)';
}
