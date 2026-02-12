import 'dart:math';

import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Performance / stress benchmarks for cozo_dart.
///
/// Run with:
///   cd example && flutter test integration_test/performance_test.dart -d macos
///
/// Dataset sizes (tuneable constants below):
///   - 10 000 users
///   - 50 000 follow edges
///   - 20 000 posts
///   - 40 000 tags
///   Total: 120 000+ rows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── tuneable knobs ──
  const userCount = 10000;
  const edgeCount = 50000;
  const postCount = 20000;
  const tagCount = 40000;
  const batchSize = 2000;

  const firstNames = [
    'Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi',
    'Ivan', 'Judy', 'Karl', 'Lena', 'Mike', 'Nina', 'Oscar', 'Peggy',
    'Quinn', 'Rosa', 'Steve', 'Tina', 'Uma', 'Vince', 'Wendy', 'Xander',
    'Yara', 'Zane',
  ];
  const lastNames = [
    'Smith', 'Jones', 'Brown', 'Davis', 'Wilson', 'Moore', 'Taylor',
    'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Garcia',
    'Clark', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen',
  ];
  const tagPool = [
    'dart', 'flutter', 'rust', 'cozo', 'graph', 'database', 'mobile',
    'web', 'performance', 'ai', 'ml', 'iot', 'cloud', 'devops', 'linux',
    'macos', 'android', 'ios', 'ui', 'ux',
  ];

  final rng = Random(42);

  setUpAll(() async => await CozoDatabase.init());

  // ───────── helpers ─────────

  Future<void> bulkInsertUsers(CozoDatabase db, int count) async {
    for (var offset = 0; offset < count; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, count);
      final rows = StringBuffer();
      for (var i = offset; i < end; i++) {
        if (i > offset) rows.write(', ');
        final name =
            '${firstNames[i % firstNames.length]} ${lastNames[i % lastNames.length]}';
        final age = 18 + (i % 62);
        final email = 'user$i@example.com';
        final score = (rng.nextDouble() * 100).toStringAsFixed(2);
        rows.write('[$i, "$name", $age, "$email", $score]');
      }
      await db.query(
          '?[id, name, age, email, score] <- [$rows]\n:put users {id => name, age, email, score}');
    }
  }

  Future<void> bulkInsertEdges(CozoDatabase db, int count, int nodeCount) async {
    final edgeSet = <int>{};
    final allEdges = <String>[];
    while (allEdges.length < count) {
      final from = rng.nextInt(nodeCount);
      final to = rng.nextInt(nodeCount);
      if (from == to) continue;
      final key = from * nodeCount + to;
      if (edgeSet.contains(key)) continue;
      edgeSet.add(key);
      allEdges.add('[$from, $to]');
    }
    for (var offset = 0; offset < allEdges.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, allEdges.length);
      final batch = allEdges.sublist(offset, end).join(', ');
      await db.query('?[from, to] <- [$batch]\n:put follows {from, to}');
    }
  }

  Future<void> bulkInsertPosts(CozoDatabase db, int count, int nodeCount) async {
    for (var offset = 0; offset < count; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, count);
      final rows = StringBuffer();
      for (var i = offset; i < end; i++) {
        if (i > offset) rows.write(', ');
        final author = rng.nextInt(nodeCount);
        final likes = rng.nextInt(100);
        final ts = (1700000000 + rng.nextInt(10000000)).toDouble();
        rows.write(
            '[$i, $author, "Post #$i", "Body $i", $likes, $ts]');
      }
      await db.query(
          '?[id, author, title, body, likes, ts] <- [$rows]\n:put posts {id => author, title, body, likes, ts}');
    }
  }

  Future<void> bulkInsertTags(CozoDatabase db, int count, int postCnt) async {
    // Deterministic generation: cycle through posts and assign tags sequentially
    final allTags = <String>[];
    outer:
    for (var postId = 0; postId < postCnt; postId++) {
      final numTags = (postId % 3 == 0) ? 3 : 2;
      for (var t = 0; t < numTags; t++) {
        final tag = tagPool[(postId + t) % tagPool.length];
        allTags.add('[$postId, "$tag"]');
        if (allTags.length >= count) break outer;
      }
    }
    for (var offset = 0; offset < allTags.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, allTags.length);
      final batch = allTags.sublist(offset, end).join(', ');
      await db.query('?[post_id, tag] <- [$batch]\n:put tags {post_id, tag}');
    }
  }

  Future<CozoDatabase> createAndPopulateDb({
    bool users = true,
    bool edges = true,
    bool posts = true,
    bool tags = true,
  }) async {
    final db = await CozoDatabase.openMemory();
    await db.query(
        ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
    await db.query(':create follows {from: Int, to: Int}');
    await db.query(
        ':create posts {id: Int => author: Int, title: String, body: String, likes: Int, ts: Float}');
    await db.query(':create tags {post_id: Int, tag: String}');
    if (users) await bulkInsertUsers(db, userCount);
    if (edges) await bulkInsertEdges(db, edgeCount, userCount);
    if (posts) await bulkInsertPosts(db, postCount, userCount);
    if (tags) await bulkInsertTags(db, tagCount, postCount);
    return db;
  }

  // ───────── WRITE benchmarks ─────────

  group('Bulk insert performance', () {
    testWidgets('insert $userCount users', (tester) async {
      final db = await CozoDatabase.openMemory();
      await db.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');

      final sw = Stopwatch()..start();
      await bulkInsertUsers(db, userCount);
      sw.stop();
      debugPrint(
          'PERF: Insert $userCount users -> ${sw.elapsedMilliseconds}ms '
          '(${(userCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');

      final result = await db.queryImmutable(
          '?[count(id)] := *users[id, _, _, _, _]');
      expect(result.rows.first.first, userCount);
      await db.close();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('insert $edgeCount follow edges', (tester) async {
      final db = await CozoDatabase.openMemory();
      await db.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
      await db.query(':create follows {from: Int, to: Int}');
      await bulkInsertUsers(db, userCount);

      final sw = Stopwatch()..start();
      await bulkInsertEdges(db, edgeCount, userCount);
      sw.stop();
      debugPrint(
          'PERF: Insert $edgeCount edges -> ${sw.elapsedMilliseconds}ms '
          '(${(edgeCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');

      final result = await db.queryImmutable(
          '?[count(from)] := *follows[from, _]');
      expect(result.rows.first.first, edgeCount);
      await db.close();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('insert $postCount posts', (tester) async {
      final db = await CozoDatabase.openMemory();
      await db.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
      await db.query(
          ':create posts {id: Int => author: Int, title: String, body: String, likes: Int, ts: Float}');
      await bulkInsertUsers(db, userCount);

      final sw = Stopwatch()..start();
      await bulkInsertPosts(db, postCount, userCount);
      sw.stop();
      debugPrint(
          'PERF: Insert $postCount posts -> ${sw.elapsedMilliseconds}ms '
          '(${(postCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');

      final result = await db.queryImmutable(
          '?[count(id)] := *posts[id, _, _, _, _, _]');
      expect(result.rows.first.first, postCount);
      await db.close();
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('insert $tagCount tags', (tester) async {
      final db = await CozoDatabase.openMemory();
      await db.query(
          ':create posts {id: Int => author: Int, title: String, body: String, likes: Int, ts: Float}');
      await db.query(':create tags {post_id: Int, tag: String}');
      await bulkInsertPosts(db, postCount, 1000);

      final sw = Stopwatch()..start();
      await bulkInsertTags(db, tagCount, postCount);
      sw.stop();
      debugPrint(
          'PERF: Insert $tagCount tags -> ${sw.elapsedMilliseconds}ms '
          '(${(tagCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');

      final result = await db.queryImmutable(
          '?[count(post_id)] := *tags[post_id, _]');
      expect(result.rows.first.first, tagCount);
      await db.close();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // ───────── READ benchmarks (shared populated db) ─────────

  group('Query performance (120K+ rows)', () {
    late CozoDatabase db;

    setUpAll(() async {
      db = await createAndPopulateDb();
    });

    tearDownAll(() async => await db.close());

    testWidgets('full table scan ($userCount users)', (tester) async {
      final sw = Stopwatch()..start();
      final result = await db.queryImmutable(
          '?[id, name, age, email, score] := *users[id, name, age, email, score]');
      sw.stop();
      debugPrint(
          'PERF: Full scan $userCount users -> ${sw.elapsedMilliseconds}ms');
      expect(result.length, userCount);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('filtered query (age range)', (tester) async {
      final sw = Stopwatch()..start();
      final result = await db.queryImmutable(
          '?[id, name, age] := *users[id, name, age, _, _], age >= 50, age < 60');
      sw.stop();
      debugPrint(
          'PERF: Filtered age 50-59 -> ${sw.elapsedMilliseconds}ms, ${result.length} rows');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('aggregation (count, mean, min, max)', (tester) async {
      final sw = Stopwatch()..start();
      final result = await db.queryImmutable(
          '?[count(id), mean(age), min(score), max(score)] := *users[id, _, age, _, score]');
      sw.stop();
      debugPrint(
          'PERF: Aggregation -> ${sw.elapsedMilliseconds}ms');
      expect(result.length, 1);
      expect(result.rows.first[0], userCount);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('join posts x users (likes > 80)', (tester) async {
      final sw = Stopwatch()..start();
      final result = await db.queryImmutable('''
        ?[name, title, likes] := *posts[_, author, title, _, likes, _],
                                 *users[author, name, _, _, _],
                                 likes > 80
      ''');
      sw.stop();
      debugPrint(
          'PERF: Join posts x users (likes>80) -> ${sw.elapsedMilliseconds}ms, ${result.length} rows');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('multi-hop join tags->posts->users', (tester) async {
      final sw = Stopwatch()..start();
      final result = await db.queryImmutable('''
        ?[name, tag, title] := *tags[post_id, tag],
                               *posts[post_id, author, title, _, _, _],
                               *users[author, name, _, _, _],
                               tag == "dart"
      ''');
      sw.stop();
      debugPrint(
          'PERF: Multi-hop join (tag=dart) -> ${sw.elapsedMilliseconds}ms, ${result.length} rows');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('4 concurrent aggregation queries', (tester) async {
      final sw = Stopwatch()..start();
      final results = await Future.wait([
        db.queryImmutable(
            '?[count(id)] := *users[id, _, age, _, _], age > 30'),
        db.queryImmutable(
            '?[count(id)] := *posts[id, _, _, _, likes, _], likes > 50'),
        db.queryImmutable(
            '?[count(from)] := *follows[from, _]'),
        db.queryImmutable(
            '?[tag, count(post_id)] := *tags[post_id, tag]'),
      ]);
      sw.stop();
      debugPrint(
          'PERF: 4 concurrent queries -> ${sw.elapsedMilliseconds}ms');
      for (final r in results) {
        expect(r.isNotEmpty, true);
      }
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  // ───────── GRAPH ALGORITHM benchmarks ─────────

  group('Graph algorithms ($edgeCount edges)', () {
    late CozoDatabase db;

    setUpAll(() async {
      db = await createAndPopulateDb(posts: false, tags: false);
    });

    tearDownAll(() async => await db.close());

    testWidgets('PageRank (10 iterations)', (tester) async {
      final graph = CozoGraph(db);

      final sw = Stopwatch()..start();
      final result = await graph.pageRank('follows', iterations: 10);
      sw.stop();
      debugPrint(
          'PERF: PageRank (10 iter, $edgeCount edges) -> ${sw.elapsedMilliseconds}ms, '
          '${result.length} ranked nodes');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Community detection (Louvain)', (tester) async {
      final graph = CozoGraph(db);

      final sw = Stopwatch()..start();
      final result = await graph.communityDetection('follows');
      sw.stop();
      final communities = result.column('community').toSet().length;
      debugPrint(
          'PERF: Community detection -> ${sw.elapsedMilliseconds}ms, '
          '$communities communities');
      expect(result.isNotEmpty, true);
      expect(communities, greaterThan(1));
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('BFS from node 0 (depth 4)', (tester) async {
      final graph = CozoGraph(db);

      final sw = Stopwatch()..start();
      final result = await graph.bfs('follows', [0], maxDepth: 4);
      sw.stop();
      debugPrint(
          'PERF: BFS depth 4 -> ${sw.elapsedMilliseconds}ms, '
          '${result.length} reachable nodes');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('Shortest path (0 -> ${userCount ~/ 2})', (tester) async {
      final graph = CozoGraph(db);

      final sw = Stopwatch()..start();
      final result =
          await graph.shortestPath('follows', 0, userCount ~/ 2);
      sw.stop();
      debugPrint(
          'PERF: Shortest path -> ${sw.elapsedMilliseconds}ms, '
          '${result.length} hops');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('PageRank (20 iterations)', (tester) async {
      final graph = CozoGraph(db);

      final sw = Stopwatch()..start();
      final result = await graph.pageRank('follows', iterations: 20);
      sw.stop();
      debugPrint(
          'PERF: PageRank (20 iter, $edgeCount edges) -> ${sw.elapsedMilliseconds}ms, '
          '${result.length} ranked nodes');
      expect(result.isNotEmpty, true);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // ───────── UPDATE / DELETE benchmarks ─────────

  group('Update & delete performance', () {
    late CozoDatabase db;

    setUpAll(() async {
      db = await createAndPopulateDb(posts: false, tags: false);
    });

    tearDownAll(() async => await db.close());

    testWidgets('update 1000 user rows', (tester) async {
      final sw = Stopwatch()..start();
      await db.query('''
        orig[id, name, age, email, score] := *users[id, name, age, email, score], id < 1000
        ?[id, name, age, email, score] := orig[id, name, old_age, email, score], age = old_age + 1
        :put users {id => name, age, email, score}
      ''');
      sw.stop();
      debugPrint('PERF: Update 1000 rows -> ${sw.elapsedMilliseconds}ms');

      // verify: user 0 should now have age 19 (was 18)
      final check = await db.queryImmutable(
          '?[age] := *users[0, _, age, _, _]');
      expect(check.rows.first.first, 19);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('bulk delete edges from last 500 users', (tester) async {
      final sw = Stopwatch()..start();
      await db.query('''
        ?[from, to] := *follows[from, to], from >= ${userCount - 500}
        :rm follows {from, to}
      ''');
      sw.stop();
      debugPrint('PERF: Delete edges (last 500 users) -> ${sw.elapsedMilliseconds}ms');

      final remaining = await db.queryImmutable(
          '?[count(from)] := *follows[from, _]');
      expect(remaining.rows.first.first, lessThan(edgeCount));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  // ───────── EXPORT / IMPORT benchmarks ─────────

  group('Export & import performance', () {
    late CozoDatabase db;

    setUpAll(() async {
      db = await createAndPopulateDb(edges: false, posts: false, tags: false);
    });

    tearDownAll(() async => await db.close());

    testWidgets('export $userCount users', (tester) async {
      final sw = Stopwatch()..start();
      final exported = await db.exportRelations(['users']);
      sw.stop();
      debugPrint('PERF: Export $userCount users -> ${sw.elapsedMilliseconds}ms');
      expect(exported.containsKey('users'), true);
    }, timeout: const Timeout(Duration(minutes: 1)));

    testWidgets('import $userCount users into fresh db', (tester) async {
      final exported = await db.exportRelations(['users']);

      final db2 = await CozoDatabase.openMemory();
      await db2.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');

      final sw = Stopwatch()..start();
      await db2.importRelations(exported);
      sw.stop();
      debugPrint('PERF: Import $userCount users -> ${sw.elapsedMilliseconds}ms');

      final count = await db2.queryImmutable(
          '?[count(id)] := *users[id, _, _, _, _]');
      expect(count.rows.first.first, userCount);
      await db2.close();
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
