import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => await CozoDatabase.init());

  late CozoDatabase db;

  setUp(() async {
    db = await CozoDatabase.openMemory();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('basic query round-trip', (tester) async {
    final result = await db.query('?[a] := a in [1, 2, 3]');
    expect(result.length, 3);
    expect(result.headers, ['a']);
  });

  testWidgets('create relation and insert data', (tester) async {
    await db.query(':create users {id: String => name: String, age: Int}');
    await db.query(r'''
      ?[id, name, age] <- [
        ["alice", "Alice", 30],
        ["bob", "Bob", 25]
      ]
      :put users {id, name, age}
    ''');

    final result =
        await db.query('?[name, age] := *users[_, name, age], age > 26');
    expect(result.length, 1);
    expect(result.firstOrNull?['name'], 'Alice');
  });

  testWidgets('graph helper put and query', (tester) async {
    await db.query(':create people {id: String => name: String, age: Int}');
    final graph = CozoGraph(db);
    await graph.put('people', [
      {'id': 'alice', 'name': 'Alice', 'age': 30},
      {'id': 'bob', 'name': 'Bob', 'age': 25},
    ]);

    final result = await graph.getAll('people');
    expect(result.length, 2);
  });

  testWidgets('parameterized query', (tester) async {
    await db.query(':create items {id: Int => label: String}');
    await db.query(
        r'?[id, label] <- [[1, "one"], [2, "two"], [3, "three"]] :put items {id, label}');

    final result = await db.query(
      r'?[label] := *items[id, label], id > $min_id',
      params: {'min_id': 1},
    );
    expect(result.length, 2);
  });

  testWidgets('error handling for bad query', (tester) async {
    expect(
      () => db.query('this is not valid cozoscript'),
      throwsA(isA<CozoQueryException>()),
    );
  });

  testWidgets('immutable query rejects writes', (tester) async {
    expect(
      () => db.queryImmutable(':create test {a: Int}'),
      throwsA(anything),
    );
  });

  testWidgets('PageRank on simple graph', (tester) async {
    await db.query(':create follows {from: String, to: String}');
    await db.query(r'''
      ?[from, to] <- [
        ["alice", "bob"],
        ["bob", "charlie"],
        ["charlie", "alice"],
        ["dave", "alice"]
      ]
      :put follows {from, to}
    ''');

    final graph = CozoGraph(db);
    final result = await graph.pageRank('follows');
    expect(result.isNotEmpty, true);
  });

  testWidgets('export and import relations', (tester) async {
    await db.query(':create data {id: Int => val: String}');
    await db
        .query('?[id, val] <- [[1, "a"], [2, "b"]] :put data {id, val}');

    final exported = await db.exportRelations(['data']);
    expect(exported, isNotNull);
    expect(exported.containsKey('data'), true);

    // Create a new db and import
    final db2 = await CozoDatabase.openMemory();
    await db2.query(':create data {id: Int => val: String}');
    await db2.importRelations(exported);
    final result =
        await db2.queryImmutable('?[id, val] := *data[id, val]');
    expect(result.length, 2);
    await db2.close();
  });
}
