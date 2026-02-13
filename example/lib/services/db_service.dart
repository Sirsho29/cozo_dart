import 'dart:math';

import 'package:cozo_dart/cozo_dart.dart';

/// Shared database service for the example app.
///
/// Manages the CozoDB lifecycle and provides data-generation helpers.
class DbService {
  DbService._();

  static CozoDatabase? _db;

  /// The active database, or `null` if not initialized.
  static CozoDatabase? get db => _db;

  /// Whether the database is open and ready.
  static bool get isReady => _db != null;

  /// Whether test data has been loaded.
  static bool dataLoaded = false;

  /// Initialize the CozoDB bridge (call once at startup).
  static Future<void> init() async => CozoDatabase.init();

  /// Open a fresh in-memory database, closing any existing one.
  static Future<CozoDatabase> open() async {
    await _db?.close();
    _db = await CozoDatabase.openMemory();
    dataLoaded = false;
    return _db!;
  }

  /// Close the current database.
  static Future<void> close() async {
    await _db?.close();
    _db = null;
    dataLoaded = false;
  }

  // ──────────── Constants ────────────

  static const userCount = 10000;
  static const edgeCount = 50000;
  static const postCount = 5000;
  static const tagCount = 10000;
  static const vecDim = 32;
  static const vecCount = 1000;

  static const batchSize = 2000;
  static final _rng = Random(42);

  static const firstNames = [
    'Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi',
    'Ivan', 'Judy', 'Karl', 'Lena', 'Mike', 'Nina', 'Oscar', 'Peggy',
    'Quinn', 'Rosa', 'Steve', 'Tina', 'Uma', 'Vince', 'Wendy', 'Xander',
    'Yara', 'Zane',
  ];

  static const lastNames = [
    'Smith', 'Jones', 'Brown', 'Davis', 'Wilson', 'Moore', 'Taylor',
    'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Garcia',
    'Clark', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen',
  ];

  static const tagPool = [
    'dart', 'flutter', 'rust', 'cozo', 'graph', 'database', 'mobile',
    'web', 'performance', 'ai', 'ml', 'iot', 'cloud', 'devops', 'linux',
    'macos', 'android', 'ios', 'ui', 'ux',
  ];

  static Random get rng => _rng;

  // ──────────── Schema + Data Loading ────────────

  /// Create all relations and insert test data.
  /// Calls [onStep] before/after each step with (stepId, isStarting).
  static Future<String> loadTestData(
    CozoDatabase db, {
    void Function(String stepId, bool isStarting, {int? durationMs, String? error})? onStep,
  }) async {
    final log = StringBuffer();

    Future<void> runStep(String stepId, Future<void> Function() action) async {
      onStep?.call(stepId, true);
      final sw = Stopwatch()..start();
      try {
        await action();
        sw.stop();
        log.writeln('$stepId: ${sw.elapsedMilliseconds}ms');
        onStep?.call(stepId, false, durationMs: sw.elapsedMilliseconds);
      } catch (e) {
        sw.stop();
        log.writeln('$stepId: ERROR $e');
        onStep?.call(stepId, false, durationMs: sw.elapsedMilliseconds, error: e.toString());
        rethrow;
      }
    }

    await runStep('schema', () async {
      await db.query(':create users {id: Int => name: String, age: Int, email: String, score: Float}');
      await db.query(':create follows {from: Int, to: Int}');
      await db.query(':create posts {id: Int => author: Int, title: String, body: String, likes: Int, ts: Float}');
      await db.query(':create tags {post_id: Int, tag: String}');
    });

    await runStep('users', () => bulkInsertUsers(db, userCount));
    await runStep('edges', () => bulkInsertEdges(db, edgeCount, userCount));
    await runStep('posts', () => bulkInsertPosts(db, postCount, userCount));
    await runStep('tags', () => bulkInsertTags(db, tagCount, postCount));

    await runStep('subgraph', () async {
      await db.query(':create follows_small {from: Int, to: Int}');
      await db.query('''
        ?[from, to] := *follows[from, to], from < 500, to < 500
        :put follows_small {from, to}
      ''');
    });

    await runStep('articles', () async {
      await db.query(':create articles {id: Int => title: String, body: String}');
      await db.query('''
        ?[id, title, body] <- [
          [0, "Introduction to Graph Databases", "Graph databases store data as nodes and edges, making relationship queries efficient."],
          [1, "Vector Search Explained", "HNSW is an algorithm for approximate nearest neighbor search in high-dimensional spaces."],
          [2, "Full-Text Search with BM25", "BM25 is a ranking function used to estimate the relevance of documents to a search query."],
          [3, "Dart Programming Language", "Dart is a client-optimized language for building fast apps on multiple platforms."],
          [4, "Flutter Mobile Development", "Flutter builds beautiful natively compiled applications from a single codebase."],
          [5, "CozoDB: A Hybrid Database", "CozoDB combines relational graph and vector capabilities in a single embedded database engine."],
          [6, "Machine Learning Basics", "Machine learning algorithms learn from data to make predictions without being explicitly programmed."],
          [7, "Building AI Agents", "AI agents use memory reasoning and tool use to accomplish complex tasks autonomously."],
          [8, "Knowledge Graphs", "Knowledge graphs represent real-world entities and their relationships as a network of nodes and edges."],
          [9, "Embedding Models", "Embedding models convert text images or other data into dense vector representations for similarity search."]
        ]
        :put articles {id => title, body}
      ''');
    });

    await runStep('embeddings', () async {
      await db.query(':create embeddings {id: Int => label: String, vec: <F32; $vecDim>}');
      final vecSearch = CozoVectorSearch(db);
      for (var offset = 0; offset < vecCount; offset += 200) {
        final end = (offset + 200).clamp(0, vecCount);
        final rows = <Map<String, dynamic>>[];
        for (var i = offset; i < end; i++) {
          rows.add({
            'id': i,
            'label': 'item_$i',
            'vec': List.generate(vecDim, (_) => _rng.nextDouble()),
          });
        }
        await vecSearch.upsert('embeddings', rows, vectorColumns: {'vec'});
      }
    });

    await runStep('hnsw', () async {
      final vecSearch = CozoVectorSearch(db);
      await vecSearch.createIndex(
        'embeddings', 'vec_idx',
        dim: vecDim,
        fields: ['vec'],
        distance: VectorDistance.cosine,
        m: 16,
        efConstruction: 100,
      );
    });

    await runStep('fts', () async {
      final textSearch = CozoTextSearch(db);
      await textSearch.createIndex(
        'articles', 'articles_fts',
        extractor: 'body',
        tokenizer: FtsTokenizer.simple,
        filters: [FtsLowercase(), FtsAlphaNumOnly()],
      );
    });

    await runStep('lsh', () async {
      final textSearch = CozoTextSearch(db);
      await textSearch.createLSHIndex(
        'articles', 'articles_lsh',
        extractor: 'body',
        targetThreshold: 0.3,
        nGram: 3,
      );
    });

    dataLoaded = true;
    return log.toString();
  }

  // ──────────── Bulk insert helpers ────────────

  static Future<void> bulkInsertUsers(CozoDatabase db, int count) async {
    for (var offset = 0; offset < count; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, count);
      final rows = StringBuffer();
      for (var i = offset; i < end; i++) {
        if (i > offset) rows.write(', ');
        final name =
            '${firstNames[i % firstNames.length]} ${lastNames[i % lastNames.length]}';
        final age = 18 + (i % 62);
        final email = 'user$i@example.com';
        final score = (_rng.nextDouble() * 100).toStringAsFixed(2);
        rows.write('[$i, "$name", $age, "$email", $score]');
      }
      await db.query(
          '?[id, name, age, email, score] <- [$rows]\n:put users {id => name, age, email, score}');
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  static Future<void> bulkInsertEdges(
      CozoDatabase db, int count, int nodeCount) async {
    final edgeSet = <int>{};
    final allEdges = <String>[];
    while (allEdges.length < count) {
      final from = _rng.nextInt(nodeCount);
      final to = _rng.nextInt(nodeCount);
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
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  static Future<void> bulkInsertPosts(
      CozoDatabase db, int count, int userCount) async {
    for (var offset = 0; offset < count; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, count);
      final rows = StringBuffer();
      for (var i = offset; i < end; i++) {
        if (i > offset) rows.write(', ');
        final author = _rng.nextInt(userCount);
        final likes = _rng.nextInt(100);
        final ts = (1700000000 + _rng.nextInt(10000000)).toDouble();
        rows.write('[$i, $author, "Post #$i", "Body $i", $likes, $ts]');
      }
      await db.query(
          '?[id, author, title, body, likes, ts] <- [$rows]\n:put posts {id => author, title, body, likes, ts}');
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  static Future<void> bulkInsertTags(
      CozoDatabase db, int count, int postCount) async {
    final allTags = <String>[];
    outer:
    for (var postId = 0; postId < postCount; postId++) {
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
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }
}
