import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CozoResult', () {
    test('parses successful JSON response', () {
      final json =
          '{"ok": true, "headers": ["a", "b"], "rows": [[1, 2], [3, 4]], "took": 0.001}';
      final result = CozoResult.fromJson(json);
      expect(result.headers, ['a', 'b']);
      expect(result.rows.length, 2);
      expect(result.rows[0], [1, 2]);
      expect(result.took, closeTo(0.001, 0.0001));
    });

    test('throws on error response', () {
      final json = '{"ok": false, "display": "some error"}';
      expect(
          () => CozoResult.fromJson(json), throwsA(isA<CozoQueryException>()));
    });

    test('toMaps converts rows to maps', () {
      final json =
          '{"ok": true, "headers": ["name", "age"], "rows": [["Alice", 30]], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      final maps = result.toMaps();
      expect(maps.first['name'], 'Alice');
      expect(maps.first['age'], 30);
    });

    test('column extracts single column', () {
      final json =
          '{"ok": true, "headers": ["a", "b"], "rows": [[1, 2], [3, 4]], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(result.column('a'), [1, 3]);
    });

    test('column throws on unknown header', () {
      final json =
          '{"ok": true, "headers": ["a", "b"], "rows": [[1, 2]], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(() => result.column('z'), throwsA(isA<ArgumentError>()));
    });

    test('firstOrNull returns first row as map', () {
      final json =
          '{"ok": true, "headers": ["x", "y"], "rows": [[10, 20], [30, 40]], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(result.firstOrNull, {'x': 10, 'y': 20});
    });

    test('firstOrNull returns null for empty result', () {
      final json =
          '{"ok": true, "headers": ["x"], "rows": [], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(result.firstOrNull, isNull);
    });

    test('isEmpty and isNotEmpty', () {
      final emptyJson =
          '{"ok": true, "headers": ["a"], "rows": [], "took": 0.0}';
      final nonEmptyJson =
          '{"ok": true, "headers": ["a"], "rows": [[1]], "took": 0.0}';

      expect(CozoResult.fromJson(emptyJson).isEmpty, true);
      expect(CozoResult.fromJson(emptyJson).isNotEmpty, false);
      expect(CozoResult.fromJson(nonEmptyJson).isEmpty, false);
      expect(CozoResult.fromJson(nonEmptyJson).isNotEmpty, true);
    });

    test('length returns row count', () {
      final json =
          '{"ok": true, "headers": ["a"], "rows": [[1], [2], [3]], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(result.length, 3);
    });

    test('toString is descriptive', () {
      final json =
          '{"ok": true, "headers": ["a", "b"], "rows": [[1, 2]], "took": 0.005}';
      final result = CozoResult.fromJson(json);
      expect(result.toString(), contains('1 rows'));
      expect(result.toString(), contains('2 columns'));
    });

    test('columnIndex returns correct index', () {
      final json =
          '{"ok": true, "headers": ["name", "age", "city"], "rows": [], "took": 0.0}';
      final result = CozoResult.fromJson(json);
      expect(result.columnIndex('name'), 0);
      expect(result.columnIndex('age'), 1);
      expect(result.columnIndex('city'), 2);
      expect(result.columnIndex('missing'), -1);
    });
  });

  group('CozoException', () {
    test('CozoQueryException has message', () {
      final e = CozoQueryException(message: 'bad query');
      expect(e.toString(), contains('bad query'));
    });

    test('CozoQueryException preserves raw response', () {
      final e = CozoQueryException(
        message: 'error',
        rawResponse: '{"ok": false}',
      );
      expect(e.rawResponse, '{"ok": false}');
    });

    test('CozoDatabaseException has message', () {
      final e = CozoDatabaseException('connection failed');
      expect(e.toString(), contains('connection failed'));
    });

    test('CozoException base class', () {
      const e = CozoException('generic error');
      expect(e.message, 'generic error');
      expect(e.toString(), contains('generic error'));
    });
  });
}
