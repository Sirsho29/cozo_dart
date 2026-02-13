import 'dart:async';
import 'dart:math';

import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CozoDatabase.init();
  runApp(const CozoExampleApp());
}

class CozoExampleApp extends StatelessWidget {
  const CozoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CozoDB Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CozoHomePage(),
    );
  }
}

class CozoHomePage extends StatefulWidget {
  const CozoHomePage({super.key});

  @override
  State<CozoHomePage> createState() => _CozoHomePageState();
}

class _CozoHomePageState extends State<CozoHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CozoDatabase? _db;
  String _queryOutput = 'Initializing...';
  String _perfOutput = 'Press "Run All Benchmarks" to start.';
  bool _benchmarkRunning = false;
  final _queryController = TextEditingController(
    text: '?[a] := a in [1, 2, 3]',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      _db = await CozoDatabase.openMemory();
      setState(() => _queryOutput = 'Database ready!\n\n'
          'Try queries like:\n'
          '  ?[a] := a in [1, 2, 3]\n');
    } catch (e) {
      setState(() => _queryOutput = 'Error: $e');
    }
  }

  // ──────────── Query Tab ────────────

  Future<void> _runQuery() async {
    if (_db == null) return;
    try {
      final result = await _db!.query(_queryController.text);
      setState(() {
        _queryOutput = 'Headers: ${result.headers}\n'
            'Rows (${result.length}):\n'
            '${result.toMaps().map((m) => '  $m').join('\n')}\n'
            'Took: ${result.took?.toStringAsFixed(4)}s';
      });
    } catch (e) {
      setState(() => _queryOutput = 'Error: $e');
    }
  }

  // ──────────── Performance Benchmarks ────────────

  Future<void> _runAllBenchmarks() async {
    if (_benchmarkRunning) return;
    setState(() {
      _benchmarkRunning = true;
      _perfOutput = 'Starting benchmarks...\n';
    });

    final db = await CozoDatabase.openMemory();
    final log = StringBuffer();

    try {
      // ── 1. Schema creation ──
      log.writeln('═══  BENCHMARK SUITE  ═══\n');

      var sw = Stopwatch()..start();
      await db.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
      await db.query(':create follows {from: Int, to: Int}');
      await db.query(
          ':create posts {id: Int => author: Int, title: String, body: String, likes: Int, ts: Float}');
      await db.query(':create tags {post_id: Int, tag: String}');
      sw.stop();
      log.writeln('Schema creation (4 relations): ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // ── 2. Bulk insert – 10,000 users ──
      const userCount = 10000;
      sw = Stopwatch()..start();
      await _bulkInsertUsers(db, userCount);
      sw.stop();
      log.writeln(
          'Insert $userCount users: ${sw.elapsedMilliseconds}ms (${(userCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');
      _updatePerf(log);
      await _yieldFrame();

      // ── 3. Bulk insert – 50,000 edges ──
      const edgeCount = 50000;
      sw = Stopwatch()..start();
      await _bulkInsertEdges(db, edgeCount, userCount);
      sw.stop();
      log.writeln(
          'Insert $edgeCount follow edges: ${sw.elapsedMilliseconds}ms (${(edgeCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');
      _updatePerf(log);
      await _yieldFrame();

      // ── 4. Bulk insert – 5000 posts ──
      const postCount = 5000;
      sw = Stopwatch()..start();
      await _bulkInsertPosts(db, postCount, userCount);
      sw.stop();
      log.writeln(
          'Insert $postCount posts: ${sw.elapsedMilliseconds}ms (${(postCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');
      _updatePerf(log);
      await _yieldFrame();

      // ── 5. Bulk insert – 10000 tags ──
      const tagCount = 10000;
      sw = Stopwatch()..start();
      await _bulkInsertTags(db, tagCount, postCount);
      sw.stop();
      log.writeln(
          'Insert $tagCount tags: ${sw.elapsedMilliseconds}ms (${(tagCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');
      _updatePerf(log);
      await _yieldFrame();

      log.writeln(
          '\nTotal data: ${userCount + edgeCount + postCount + tagCount} rows across 4 relations\n');

      // ── 6. Full table scan ──
      log.writeln('─── READ QUERIES ───');
      _updatePerf(log);
      await _yieldFrame();
      sw = Stopwatch()..start();
      var result = await db.queryImmutable(
          '?[id, name, age, email, score] := *users[id, name, age, email, score]');
      sw.stop();
      log.writeln(
          'Full scan $userCount users: ${sw.elapsedMilliseconds}ms → ${result.length} rows');
      _updatePerf(log);
      await _yieldFrame();

      // ── 7. Filtered query ──
      sw = Stopwatch()..start();
      result = await db.queryImmutable(
          '?[id, name, age] := *users[id, name, age, _, _], age >= 50, age < 60');
      sw.stop();
      log.writeln(
          'Filtered users (age 50-59): ${sw.elapsedMilliseconds}ms → ${result.length} rows');
      _updatePerf(log);
      await _yieldFrame();

      // ── 8. Aggregation ──
      sw = Stopwatch()..start();
      result = await db.queryImmutable(
          '?[count(id), mean(age), min(score), max(score)] := *users[id, _, age, _, score]');
      sw.stop();
      log.writeln('Aggregation (count, mean, min, max): ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // ── 9. Join: posts with user info ──
      sw = Stopwatch()..start();
      result = await db.queryImmutable('''
        ?[name, title, likes] := *posts[_, author, title, _, likes, _],
                                 *users[author, name, _, _, _],
                                 likes > 80
      ''');
      sw.stop();
      log.writeln(
          'Join posts×users (likes>80): ${sw.elapsedMilliseconds}ms → ${result.length} rows');
      _updatePerf(log);
      await _yieldFrame();

      // ── 10. Multi-hop join: tags → posts → users ──
      sw = Stopwatch()..start();
      result = await db.queryImmutable('''
        ?[name, tag, title] := *tags[post_id, tag],
                               *posts[post_id, author, title, _, _, _],
                               *users[author, name, _, _, _],
                               tag == "dart"
      ''');
      sw.stop();
      log.writeln(
          'Multi-hop join (tags→posts→users, tag="dart"): ${sw.elapsedMilliseconds}ms → ${result.length} rows');
      _updatePerf(log);
      await _yieldFrame();

      // ── 11. Graph algorithms ──
      log.writeln('\n─── GRAPH ALGORITHMS ($edgeCount edges) ───');
      _updatePerf(log);
      await _yieldFrame();
      final graph = CozoGraph(db);

      sw = Stopwatch()..start();
      result = await graph.pageRank('follows', iterations: 10);
      sw.stop();
      log.writeln(
          'PageRank (10 iter): ${sw.elapsedMilliseconds}ms → ${result.length} ranked nodes');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.communityDetection('follows');
      sw.stop();
      final communities = result.column('community').toSet().length;
      log.writeln(
          'Community detection (Louvain): ${sw.elapsedMilliseconds}ms → $communities communities');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.bfs(
          'follows', 'users', ['id', 'name', 'age', 'email', 'score'], [0],
          condition: 'age > 90', limit: 10);
      sw.stop();
      log.writeln(
          'BFS from node 0 (condition: age>90, limit 10): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.shortestPath('follows', 0, userCount ~/ 2);
      sw.stop();
      final pathLen = result.isNotEmpty
          ? (result.rows.first.last as List).length
          : 0;
      log.writeln(
          'Shortest path (0 → ${userCount ~/ 2}): ${sw.elapsedMilliseconds}ms → $pathLen hops');
      _updatePerf(log);
      await _yieldFrame();

      // ── 11b. Extended Graph Algorithms (Phase 3) ──
      // Create a smaller subgraph to avoid stack overflow on recursion-heavy algos
      await db.query('''
        :create follows_small {from: Int, to: Int}
      ''');
      await db.query('''
        ?[from, to] := *follows[from, to], from < 500, to < 500
        :put follows_small {from, to}
      ''');
      final smallEdges = (await db.queryImmutable('?[count(from)] := *follows_small[from, _]')).rows.first[0];
      log.writeln('\n─── EXTENDED GRAPH ALGORITHMS (small=$smallEdges edges) ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.degreeCentrality('follows');
      sw.stop();
      log.writeln(
          'Degree centrality: ${sw.elapsedMilliseconds}ms → ${result.length} nodes');
      if (result.isNotEmpty) {
        final top = result.toMaps().first;
        log.writeln(
            '  Top node: ${top['node']} (degree=${top['degree']}, in=${top['in_degree']}, out=${top['out_degree']})');
      }
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.labelPropagation('follows_small');
      sw.stop();
      final lpCommunities = result.column('label').toSet().length;
      log.writeln(
          'Label propagation: ${sw.elapsedMilliseconds}ms → $lpCommunities communities');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.stronglyConnectedComponents('follows_small');
      sw.stop();
      final sccCount = result.column('component').toSet().length;
      log.writeln(
          'Strongly connected components: ${sw.elapsedMilliseconds}ms → $sccCount components');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.topologicalSort('follows_small');
      sw.stop();
      log.writeln(
          'Topological sort: ${sw.elapsedMilliseconds}ms → ${result.length} nodes ordered');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.randomWalk('follows', [0, 1, 2], steps: 10, walks: 2);
      sw.stop();
      log.writeln(
          'Random walk (3 starts, 10 steps, 2 walks): ${sw.elapsedMilliseconds}ms → ${result.length} walks');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.dfs(
          'follows', 'users', ['id', 'name', 'age', 'email', 'score'], [0],
          condition: 'age > 90', limit: 5);
      sw.stop();
      log.writeln(
          'DFS from node 0 (condition: age>90, limit 5): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      _updatePerf(log);
      await _yieldFrame();

      // ── 11c. System Operations (Phase 2) ──
      log.writeln('\n─── SYSTEM OPERATIONS ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await db.listRelations();
      sw.stop();
      final relationNames = result.column('name').cast<String>().toList();
      log.writeln(
          'List relations: ${sw.elapsedMilliseconds}ms → ${relationNames.length} relations');
      log.writeln('  Relations: ${relationNames.join(', ')}');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await db.describeRelation('users');
      sw.stop();
      final colNames = result.column('column').cast<String>().toList();
      log.writeln(
          'Describe "users": ${sw.elapsedMilliseconds}ms → ${colNames.length} columns');
      log.writeln('  Columns: ${colNames.join(', ')}');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await db.explain(
          '?[name, age] := *users[_, name, age, _, _], age > 50');
      sw.stop();
      log.writeln(
          'Explain query: ${sw.elapsedMilliseconds}ms → ${result.length} plan steps');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await db.listRunningQueries();
      sw.stop();
      log.writeln(
          'List running queries: ${sw.elapsedMilliseconds}ms → ${result.length} active');
      _updatePerf(log);
      await _yieldFrame();

      // ── 12. Export / Import ──
      log.writeln('\n─── EXPORT / IMPORT ───');
      sw = Stopwatch()..start();
      final exported = await db.exportRelations(['users']);
      sw.stop();
      log.writeln('Export $userCount users: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      final db2 = await CozoDatabase.openMemory();
      await db2.query(
          ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
      sw = Stopwatch()..start();
      await db2.importRelations(exported);
      sw.stop();
      log.writeln('Import $userCount users into fresh db: ${sw.elapsedMilliseconds}ms');
      await db2.close();
      _updatePerf(log);

      // ── 13. Concurrent-style queries ──
      log.writeln('\n─── CONCURRENT READS ───');
      sw = Stopwatch()..start();
      await Future.wait([
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
      log.writeln('4 concurrent aggregation queries: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      // ── 14. Large update batch ──
      log.writeln('\n─── UPDATES ───');
      sw = Stopwatch()..start();
      // bump age of first 1000 users
      await db.query('''
        orig[id, name, age, email, score] := *users[id, name, age, email, score], id < 1000
        ?[id, name, age, email, score] := orig[id, name, old_age, email, score], age = old_age + 1
        :put users {id => name, age, email, score}
      ''');
      sw.stop();
      log.writeln('Update 1000 user rows: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      // ── 15. Bulk delete ──
      sw = Stopwatch()..start();
      await db.query('''
        ?[from, to] := *follows[from, to], from >= ${userCount - 500}
        :rm follows {from, to}
      ''');
      sw.stop();
      log.writeln('Delete edges from last 500 users: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      // ── 16. Vector Search (HNSW) ──
      log.writeln('\n─── VECTOR SEARCH (HNSW) ───');
      _updatePerf(log);
      await _yieldFrame();

      const vecDim = 32;
      sw = Stopwatch()..start();
      await db.query(
          ':create embeddings {id: Int => label: String, vec: <F32; $vecDim>}');
      sw.stop();
      log.writeln('Create vector relation (dim=$vecDim): ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // Insert 1000 random vectors
      const vecCount = 1000;
      sw = Stopwatch()..start();
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
        await vecSearch.upsert('embeddings', rows,
            vectorColumns: {'vec'});
      }
      sw.stop();
      log.writeln(
          'Insert $vecCount vectors: ${sw.elapsedMilliseconds}ms '
          '(${(vecCount / (sw.elapsedMilliseconds / 1000)).toStringAsFixed(0)} rows/s)');
      _updatePerf(log);
      await _yieldFrame();

      // Create HNSW index
      sw = Stopwatch()..start();
      await vecSearch.createIndex(
        'embeddings', 'vec_idx',
        dim: vecDim,
        fields: ['vec'],
        distance: VectorDistance.cosine,
        m: 16,
        efConstruction: 100,
      );
      sw.stop();
      log.writeln('Create HNSW index (m=16, ef=100): ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // ANN search
      final queryVec = List.generate(vecDim, (_) => _rng.nextDouble());
      sw = Stopwatch()..start();
      result = await vecSearch.search(
        'embeddings', 'vec_idx',
        queryVector: queryVec,
        bindFields: ['id', 'label'],
        k: 10,
      );
      sw.stop();
      log.writeln(
          'HNSW search (k=10): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      if (result.isNotEmpty) {
        final closest = result.toMaps().first;
        log.writeln(
            '  Nearest: ${closest['label']} (dist=${(closest['distance'] as num).toStringAsFixed(4)})');
      }
      _updatePerf(log);
      await _yieldFrame();

      // Search with radius constraint
      sw = Stopwatch()..start();
      result = await vecSearch.search(
        'embeddings', 'vec_idx',
        queryVector: queryVec,
        bindFields: ['id', 'label'],
        k: 100,
        radius: 1.0,
      );
      sw.stop();
      log.writeln(
          'HNSW search (k=100, radius≤1.0): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      _updatePerf(log);
      await _yieldFrame();

      // ── 17. Full-Text Search ──
      log.writeln('\n─── FULL-TEXT SEARCH ───');
      _updatePerf(log);
      await _yieldFrame();

      // Create articles with varied content
      await db.query(
          ':create articles {id: Int => title: String, body: String}');
      sw = Stopwatch()..start();
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
      sw.stop();
      log.writeln('Insert 10 articles: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // Create FTS index
      final textSearch = CozoTextSearch(db);
      sw = Stopwatch()..start();
      await textSearch.createIndex(
        'articles', 'articles_fts',
        extractor: 'body',
        tokenizer: FtsTokenizer.simple,
        filters: [FtsLowercase(), FtsAlphaNumOnly()],
      );
      sw.stop();
      log.writeln('Create FTS index on articles.body: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      // FTS search
      sw = Stopwatch()..start();
      result = await textSearch.search(
        'articles', 'articles_fts',
        queryText: 'graph database',
        bindFields: ['id', 'title'],
        k: 5,
      );
      sw.stop();
      log.writeln(
          'FTS search "graph database" (k=5): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      for (final row in result.toMaps()) {
        log.writeln(
            '  [${row['id']}] ${row['title']} (score=${(row['score'] as num).toStringAsFixed(4)})');
      }
      _updatePerf(log);
      await _yieldFrame();

      // FTS with different query
      sw = Stopwatch()..start();
      result = await textSearch.search(
        'articles', 'articles_fts',
        queryText: 'vector search similarity',
        bindFields: ['id', 'title'],
        k: 5,
      );
      sw.stop();
      log.writeln(
          'FTS search "vector search similarity" (k=5): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      for (final row in result.toMaps()) {
        log.writeln(
            '  [${row['id']}] ${row['title']} (score=${(row['score'] as num).toStringAsFixed(4)})');
      }
      _updatePerf(log);
      await _yieldFrame();

      // ── 18. LSH Similarity Search ──
      log.writeln('\n─── LSH SIMILARITY SEARCH ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      await textSearch.createLSHIndex(
        'articles', 'articles_lsh',
        extractor: 'body',
        targetThreshold: 0.3,
        nGram: 3,
      );
      sw.stop();
      log.writeln('Create LSH index (threshold=0.3): ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await textSearch.similaritySearch(
        'articles', 'articles_lsh',
        queryText: 'Graph databases use nodes and edges to store relationships between entities',
        bindFields: ['id', 'title'],
        k: 5,
      );
      sw.stop();
      log.writeln(
          'LSH similarity search (k=5): ${sw.elapsedMilliseconds}ms → ${result.length} results');
      for (final row in result.toMaps()) {
        log.writeln(
            '  [${row['id']}] ${row['title']}');
      }
      _updatePerf(log);
      await _yieldFrame();

      // ── 19. Hybrid Search (FTS + Structured) ──
      log.writeln('\n─── HYBRID SEARCH ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await textSearch.searchWithConditions(
        'articles', 'articles_fts',
        queryText: 'database',
        bindFields: ['id', 'body'],
        joinConditions: '*articles{ id, title, body }, id < 7',
        outputFields: ['id', 'title', 'score'],
        k: 10,
      );
      sw.stop();
      log.writeln(
          'Hybrid FTS "database" + filter id<7: ${sw.elapsedMilliseconds}ms → ${result.length} results');
      for (final row in result.toMaps()) {
        log.writeln(
            '  [${row['id']}] ${row['title']} (score=${(row['score'] as num).toStringAsFixed(4)})');
      }
      _updatePerf(log);

      // ── 20. Connected Components ──
      log.writeln('\n─── CONNECTED COMPONENTS ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.connectedComponents('follows_small');
      sw.stop();
      final numComponents = result.column('component').toSet().length;
      log.writeln(
          'Connected components: ${sw.elapsedMilliseconds}ms → $numComponents components from ${result.length} nodes');
      _updatePerf(log);
      await _yieldFrame();

      // ── 21. Clustering Coefficients ──
      log.writeln('\n─── CLUSTERING COEFFICIENTS ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.clusteringCoefficients('follows_small');
      sw.stop();
      log.writeln(
          'Clustering coefficients: ${sw.elapsedMilliseconds}ms → ${result.length} nodes');
      for (final row in result.toMaps().take(5)) {
        log.writeln(
            '  node=${row['node']}: coeff=${(row['coefficient'] as num).toStringAsFixed(4)}, triangles=${row['triangles']}, degree=${row['degree']}');
      }
      _updatePerf(log);
      await _yieldFrame();

      // ── 22. Shortest Path Dijkstra ──
      log.writeln('\n─── SHORTEST PATH (DIJKSTRA) ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.shortestPathDijkstra(
        'follows', [1, 2], [500, 1000],
      );
      sw.stop();
      log.writeln(
          'Dijkstra shortest paths (2 starts → 2 goals): ${sw.elapsedMilliseconds}ms → ${result.length} paths');
      for (final row in result.toMaps().take(3)) {
        log.writeln(
            '  ${row['start']} → ${row['goal']}: cost=${row['cost']}');
      }
      _updatePerf(log);
      await _yieldFrame();

      // ── 23. K Shortest Paths (Yen) ──
      log.writeln('\n─── K SHORTEST PATHS (YEN) ───');
      _updatePerf(log);
      await _yieldFrame();

      sw = Stopwatch()..start();
      result = await graph.kShortestPathsYen(
        'follows', [1], [500],
        k: 3,
      );
      sw.stop();
      log.writeln(
          'Yen k=3 shortest paths: ${sw.elapsedMilliseconds}ms → ${result.length} paths');
      for (final row in result.toMaps()) {
        log.writeln(
            '  ${row['start']} → ${row['goal']}: cost=${row['cost']}');
      }
      _updatePerf(log);
      await _yieldFrame();

      // ── 24. System Ops: Describe, Rename, Access Level, Compact ──
      log.writeln('\n─── EXTENDED SYSTEM OPS ───');
      _updatePerf(log);
      await _yieldFrame();

      // Create a temp relation for testing
      await db.query(':create sys_test {id: Int => value: String}');
      await db.query('?[id, value] <- [[1, "test"]] :put sys_test {id, value}');

      sw = Stopwatch()..start();
      result = await db.describeRelation('sys_test');
      sw.stop();
      log.writeln('Describe relation: ${sw.elapsedMilliseconds}ms → ${result.length} columns');
      _updatePerf(log);

      sw = Stopwatch()..start();
      await db.renameRelations({'sys_test': 'sys_renamed'});
      sw.stop();
      log.writeln('Rename relation: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      sw = Stopwatch()..start();
      await db.setAccessLevel('protected', ['sys_renamed']);
      sw.stop();
      log.writeln('Set access level to protected: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      // Reset access level so we can clean up
      await db.setAccessLevel('normal', ['sys_renamed']);

      sw = Stopwatch()..start();
      result = await db.showTriggers('sys_renamed');
      sw.stop();
      log.writeln('Show triggers: ${sw.elapsedMilliseconds}ms → ${result.length} triggers');
      _updatePerf(log);

      sw = Stopwatch()..start();
      await db.removeRelations(['sys_renamed']);
      sw.stop();
      log.writeln('Remove relation: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      sw = Stopwatch()..start();
      await db.compact();
      sw.stop();
      log.writeln('Compact database: ${sw.elapsedMilliseconds}ms');
      _updatePerf(log);

      log.writeln('\n═══  BENCHMARKS COMPLETE  ═══');
    } catch (e) {
      log.writeln('\n*** ERROR: $e ***');
    } finally {
      await db.close();
      setState(() {
        _perfOutput = log.toString();
        _benchmarkRunning = false;
      });
    }
  }

  void _updatePerf(StringBuffer log) {
    setState(() => _perfOutput = log.toString());
  }

  /// Wait for the next frame to actually render so the UI updates.
  Future<void> _yieldFrame() async {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) => completer.complete());
    setState(() {}); // schedule a rebuild
    await completer.future;
  }

  // ──────────── Data generators ────────────

  static const _batchSize = 2000;
  static final _rng = Random(42);
  static const _firstNames = [
    'Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi',
    'Ivan', 'Judy', 'Karl', 'Lena', 'Mike', 'Nina', 'Oscar', 'Peggy',
    'Quinn', 'Rosa', 'Steve', 'Tina', 'Uma', 'Vince', 'Wendy', 'Xander',
    'Yara', 'Zane',
  ];
  static const _lastNames = [
    'Smith', 'Jones', 'Brown', 'Davis', 'Wilson', 'Moore', 'Taylor',
    'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Garcia',
    'Clark', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen',
  ];
  static const _tagPool = [
    'dart', 'flutter', 'rust', 'cozo', 'graph', 'database', 'mobile',
    'web', 'performance', 'ai', 'ml', 'iot', 'cloud', 'devops', 'linux',
    'macos', 'android', 'ios', 'ui', 'ux',
  ];

  Future<void> _bulkInsertUsers(CozoDatabase db, int count) async {
    for (var offset = 0; offset < count; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, count);
      final rows = StringBuffer();
      for (var i = offset; i < end; i++) {
        if (i > offset) rows.write(', ');
        final name =
            '${_firstNames[i % _firstNames.length]} ${_lastNames[i % _lastNames.length]}';
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

  Future<void> _bulkInsertEdges(
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
    for (var offset = 0; offset < allEdges.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, allEdges.length);
      final batch = allEdges.sublist(offset, end).join(', ');
      await db.query('?[from, to] <- [$batch]\n:put follows {from, to}');
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> _bulkInsertPosts(
      CozoDatabase db, int count, int userCount) async {
    for (var offset = 0; offset < count; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, count);
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

  Future<void> _bulkInsertTags(CozoDatabase db, int count, int postCount) async {
    // Deterministic generation: cycle through posts and assign tags sequentially
    final allTags = <String>[];
    outer:
    for (var postId = 0; postId < postCount; postId++) {
      // Each post gets ~2 tags on average (10K tags / 5K posts)
      final numTags = (postId % 3 == 0) ? 3 : 2;
      for (var t = 0; t < numTags; t++) {
        final tag = _tagPool[(postId + t) % _tagPool.length];
        allTags.add('[$postId, "$tag"]');
        if (allTags.length >= count) break outer;
      }
    }
    for (var offset = 0; offset < allTags.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, allTags.length);
      final batch = allTags.sublist(offset, end).join(', ');
      await db.query('?[post_id, tag] <- [$batch]\n:put tags {post_id, tag}');
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  @override
  void dispose() {
    _db?.close();
    _queryController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CozoDB Example'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Query'),
            Tab(icon: Icon(Icons.speed), text: 'Benchmarks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQueryTab(),
          _buildBenchmarkTab(),
        ],
      ),
    );
  }

  Widget _buildQueryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              labelText: 'CozoScript Query',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _runQuery,
            child: const Text('Run Query'),
          ),
          const SizedBox(height: 16),
          Expanded(child: _outputCard(_queryOutput)),
        ],
      ),
    );
  }

  Widget _buildBenchmarkTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _benchmarkRunning ? null : _runAllBenchmarks,
            icon: _benchmarkRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_benchmarkRunning
                ? 'Running...'
                : 'Run All Benchmarks (10K users, 50K edges, 5K posts, 10K tags)'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Benchmarks insert 75K+ rows, then test scans, filters, joins, '
            'graph algorithms, export/import, concurrent reads, updates & deletes.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(child: _outputCard(_perfOutput)),
        ],
      ),
    );
  }

  Widget _outputCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
