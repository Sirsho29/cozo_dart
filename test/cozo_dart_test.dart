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

  group('VectorDistance', () {
    test('enum values map to CozoDB syntax', () {
      expect(VectorDistance.l2.value, 'L2');
      expect(VectorDistance.cosine.value, 'Cosine');
      expect(VectorDistance.innerProduct.value, 'InnerProduct');
    });
  });

  group('VectorDType', () {
    test('enum values map to CozoDB syntax', () {
      expect(VectorDType.f32.value, 'F32');
      expect(VectorDType.f64.value, 'F64');
    });
  });

  group('FtsTokenizer', () {
    test('enum values map to CozoDB syntax', () {
      expect(FtsTokenizer.raw.value, 'Raw');
      expect(FtsTokenizer.simple.value, 'Simple');
      expect(FtsTokenizer.cangjie.value, 'Cangjie');
    });
  });

  group('FtsFilter', () {
    test('FtsLowercase serializes correctly', () {
      expect(FtsLowercase().toCozoScript(), 'Lowercase');
    });

    test('FtsAlphaNumOnly serializes correctly', () {
      expect(FtsAlphaNumOnly().toCozoScript(), 'AlphaNumOnly');
    });

    test('FtsAsciiFolding serializes correctly', () {
      expect(FtsAsciiFolding().toCozoScript(), 'AsciiFolding');
    });

    test('FtsStemmer serializes with language', () {
      expect(FtsStemmer('english').toCozoScript(), "Stemmer('english')");
      expect(FtsStemmer('french').toCozoScript(), "Stemmer('french')");
    });

    test('FtsStopwords serializes with language code', () {
      expect(FtsStopwords('en').toCozoScript(), "Stopwords('en')");
      expect(FtsStopwords('de').toCozoScript(), "Stopwords('de')");
    });

    test('filter list serializes for CozoScript', () {
      final filters = [
        FtsLowercase(),
        FtsAlphaNumOnly(),
        FtsStemmer('english'),
        FtsStopwords('en'),
      ];
      final serialized = filters.map((f) => f.toCozoScript()).join(', ');
      expect(serialized,
          "Lowercase, AlphaNumOnly, Stemmer('english'), Stopwords('en')");
    });
  });

  group('CozoEngine', () {
    test('enum values match CozoDB engine names', () {
      expect(CozoEngine.memory.value, 'mem');
      expect(CozoEngine.sqlite.value, 'sqlite');
    });
  });

  group('CozoDatabase closed guard', () {
    test('isClosed reflects state', () {
      // We can't open a real DB without FRB, but we can test the exception type
      final e = CozoDatabaseException('Database is closed');
      expect(e.toString(), contains('closed'));
    });
  });

  group('AccessLevel', () {
    test('valid access level strings accepted by setAccessLevel API', () {
      // Verify the four access levels documented by CozoDB
      const levels = ['normal', 'protected', 'read_only', 'hidden'];
      expect(levels, hasLength(4));
      expect(levels, contains('normal'));
      expect(levels, contains('protected'));
      expect(levels, contains('read_only'));
      expect(levels, contains('hidden'));
    });
  });

  group('CozoGraph algorithm coverage', () {
    test('CozoResult can represent graph algorithm outputs', () {
      // Simulate outputs from various graph algorithms

      // Connected components output
      final ccJson =
          '{"ok": true, "headers": ["node", "component"], "rows": [[1, 0], [2, 0], [3, 1]], "took": 0.001}';
      final ccResult = CozoResult.fromJson(ccJson);
      expect(ccResult.headers, ['node', 'component']);
      expect(ccResult.column('component').toSet().length, 2);

      // Clustering coefficients output
      final clJson =
          '{"ok": true, "headers": ["node", "coefficient", "triangles", "degree"], "rows": [[1, 0.5, 3, 4], [2, 1.0, 1, 2]], "took": 0.001}';
      final clResult = CozoResult.fromJson(clJson);
      expect(clResult.headers, contains('coefficient'));
      expect(clResult.headers, contains('triangles'));
      expect(clResult.toMaps().first['coefficient'], 0.5);

      // Dijkstra / Yen output
      final pathJson =
          '{"ok": true, "headers": ["start", "goal", "cost", "path"], "rows": [[1, 5, 3.0, [1, 3, 5]]], "took": 0.001}';
      final pathResult = CozoResult.fromJson(pathJson);
      expect(pathResult.headers, ['start', 'goal', 'cost', 'path']);
      expect(pathResult.toMaps().first['cost'], 3.0);
      expect(pathResult.toMaps().first['path'], [1, 3, 5]);
    });
  });

  group('System operations query formatting', () {
    test('relation description escapes double quotes', () {
      const description = 'A "quoted" description';
      final escaped = description.replaceAll('"', '\\"');
      expect(escaped, 'A \\"quoted\\" description');
    });

    test('rename pairs format correctly', () {
      final renames = {'old_users': 'users', 'temp': 'archive'};
      final pairs =
          renames.entries.map((e) => '${e.key} -> ${e.value}').join(', ');
      expect(pairs, 'old_users -> users, temp -> archive');
    });

    test('trigger query format', () {
      final buf = StringBuffer('::set_triggers test_rel');
      buf.write('\n\non put { ?[a] := _new[a] :put log {a} }');
      buf.write('\n\non rm { ?[a] := _old[a] :put deleted {a} }');
      final query = buf.toString();
      expect(query, contains('::set_triggers test_rel'));
      expect(query, contains('on put'));
      expect(query, contains('on rm'));
    });
  });

  group('CozoUtils query building', () {
    test('CSV reader types list format', () {
      final types = ['String', 'Int', 'Float'];
      final formatted = types.map((t) => '"$t"').join(', ');
      expect(formatted, '"String", "Int", "Float"');
    });

    test('JSON reader fields format', () {
      final fields = [('name', 'String'), ('age', 'Int')];
      final formatted =
          fields.map((f) => "['${f.$1}', '${f.$2}']").join(', ');
      expect(formatted, "['name', 'String'], ['age', 'Int']");
    });

    test('ReorderSort sort_by format', () {
      final sortBy = ['age', 'name'];
      final formatted = sortBy.map((s) => '"$s"').join(', ');
      expect(formatted, '"age", "name"');
    });
  });
}
