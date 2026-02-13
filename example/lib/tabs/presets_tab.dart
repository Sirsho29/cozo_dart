import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter/material.dart';

import '../models/load_step.dart';
import '../models/preset_model.dart';
import '../pages/graph_page.dart';
import '../services/db_service.dart';

/// Tab with preset query buttons organized by category.
class PresetsTab extends StatefulWidget {
  const PresetsTab({super.key});

  @override
  State<PresetsTab> createState() => _PresetsTabState();
}

class _PresetsTabState extends State<PresetsTab>
    with AutomaticKeepAliveClientMixin {
  bool _dataLoading = false;

  @override
  bool get wantKeepAlive => true;

  // ──────────── Preset definitions ────────────

  late final List<PresetItem> _presets = [
    // Data Loading
    PresetItem(
      id: 'load_data',
      title: 'Load Test Data',
      subtitle:
          '${DbService.userCount} users, ${DbService.edgeCount} edges, ${DbService.postCount} posts, ${DbService.tagCount} tags + articles + embeddings',
      category: 'Data',
      icon: Icons.cloud_download,
    ),

    // Read Queries
    PresetItem(
      id: 'full_scan',
      title: 'Full Table Scan',
      subtitle: 'Scan all ${DbService.userCount} users',
      category: 'Read',
      icon: Icons.table_rows,
    ),
    PresetItem(
      id: 'filtered',
      title: 'Filtered Query',
      subtitle: 'Users age 50-59',
      category: 'Read',
      icon: Icons.filter_alt,
    ),
    PresetItem(
      id: 'aggregation',
      title: 'Aggregation',
      subtitle: 'count, mean, min, max on users',
      category: 'Read',
      icon: Icons.functions,
    ),
    PresetItem(
      id: 'join',
      title: 'Join (posts x users)',
      subtitle: 'Posts with likes > 80 joined with user names',
      category: 'Read',
      icon: Icons.join_inner,
    ),
    PresetItem(
      id: 'multi_hop',
      title: 'Multi-hop Join',
      subtitle: 'tags -> posts -> users where tag = "dart"',
      category: 'Read',
      icon: Icons.hub,
    ),
    PresetItem(
      id: 'concurrent',
      title: 'Concurrent Reads',
      subtitle: '4 aggregation queries in parallel',
      category: 'Read',
      icon: Icons.sync,
    ),

    // Graph Algorithms
    PresetItem(
      id: 'pagerank',
      title: 'PageRank',
      subtitle: '10 iterations on ${DbService.edgeCount} edges',
      category: 'Graph',
      icon: Icons.trending_up,
    ),
    PresetItem(
      id: 'community',
      title: 'Community Detection',
      subtitle: 'Louvain algorithm',
      category: 'Graph',
      icon: Icons.groups,
    ),
    PresetItem(
      id: 'bfs',
      title: 'BFS',
      subtitle: 'From node 0, age > 90, limit 10',
      category: 'Graph',
      icon: Icons.account_tree,
    ),
    PresetItem(
      id: 'shortest_path',
      title: 'Shortest Path (BFS)',
      subtitle: 'Node 0 -> ${DbService.userCount ~/ 2}',
      category: 'Graph',
      icon: Icons.route,
    ),
    PresetItem(
      id: 'degree_centrality',
      title: 'Degree Centrality',
      subtitle: 'In/out/total degree for all nodes',
      category: 'Graph',
      icon: Icons.stacked_bar_chart,
    ),
    PresetItem(
      id: 'label_propagation',
      title: 'Label Propagation',
      subtitle: 'On small subgraph (< 500 nodes)',
      category: 'Graph',
      icon: Icons.label,
    ),
    PresetItem(
      id: 'scc',
      title: 'Strongly Connected Components',
      subtitle: 'On small subgraph',
      category: 'Graph',
      icon: Icons.grain,
    ),
    PresetItem(
      id: 'connected_components',
      title: 'Connected Components',
      subtitle: 'Undirected, on small subgraph',
      category: 'Graph',
      icon: Icons.scatter_plot,
    ),
    PresetItem(
      id: 'clustering',
      title: 'Clustering Coefficients',
      subtitle: 'Per-node coefficient, triangles, degree',
      category: 'Graph',
      icon: Icons.bubble_chart,
    ),
    PresetItem(
      id: 'topological_sort',
      title: 'Topological Sort',
      subtitle: 'On small subgraph',
      category: 'Graph',
      icon: Icons.sort,
    ),
    PresetItem(
      id: 'dijkstra',
      title: 'Shortest Path (Dijkstra)',
      subtitle: '2 starts -> 2 goals',
      category: 'Graph',
      icon: Icons.alt_route,
    ),
    PresetItem(
      id: 'yen',
      title: 'K Shortest Paths (Yen)',
      subtitle: 'k=3, node 1 -> 500',
      category: 'Graph',
      icon: Icons.fork_right,
    ),
    PresetItem(
      id: 'random_walk',
      title: 'Random Walk',
      subtitle: '3 starts, 10 steps, 2 walks',
      category: 'Graph',
      icon: Icons.directions_walk,
    ),
    PresetItem(
      id: 'dfs',
      title: 'DFS',
      subtitle: 'From node 0, age > 90, limit 5',
      category: 'Graph',
      icon: Icons.explore,
    ),

    // Vector Search
    PresetItem(
      id: 'hnsw_search',
      title: 'HNSW Search',
      subtitle: 'ANN k=10, cosine distance',
      category: 'Vector',
      icon: Icons.radar,
    ),
    PresetItem(
      id: 'hnsw_radius',
      title: 'HNSW Radius Search',
      subtitle: 'k=100, radius <= 1.0',
      category: 'Vector',
      icon: Icons.adjust,
    ),

    // Text Search
    PresetItem(
      id: 'fts_search',
      title: 'FTS Search',
      subtitle: '"graph database" (BM25)',
      category: 'Text',
      icon: Icons.text_snippet,
    ),
    PresetItem(
      id: 'fts_search2',
      title: 'FTS Search #2',
      subtitle: '"vector search similarity"',
      category: 'Text',
      icon: Icons.text_snippet,
    ),
    PresetItem(
      id: 'lsh_search',
      title: 'LSH Similarity',
      subtitle: 'MinHash Jaccard similarity on articles',
      category: 'Text',
      icon: Icons.fingerprint,
    ),
    PresetItem(
      id: 'hybrid_search',
      title: 'Hybrid FTS + Filter',
      subtitle: 'FTS "database" + id < 7',
      category: 'Text',
      icon: Icons.merge_type,
    ),

    // System Ops
    PresetItem(
      id: 'list_relations',
      title: 'List Relations',
      subtitle: '::relations',
      category: 'System',
      icon: Icons.list,
    ),
    PresetItem(
      id: 'describe_relation',
      title: 'Describe Relation',
      subtitle: '::columns users',
      category: 'System',
      icon: Icons.info,
    ),
    PresetItem(
      id: 'explain',
      title: 'Explain Query',
      subtitle: 'Query plan for filtered user query',
      category: 'System',
      icon: Icons.code,
    ),
    PresetItem(
      id: 'running_queries',
      title: 'List Running Queries',
      subtitle: '::running',
      category: 'System',
      icon: Icons.miscellaneous_services,
    ),
    PresetItem(
      id: 'describe_sys',
      title: 'Describe + Rename + Remove',
      subtitle: 'Create temp relation, rename, remove',
      category: 'System',
      icon: Icons.build,
    ),
    PresetItem(
      id: 'access_level',
      title: 'Access Level',
      subtitle: 'Set protected, then reset',
      category: 'System',
      icon: Icons.lock,
    ),
    PresetItem(
      id: 'compact',
      title: 'Compact',
      subtitle: '::compact',
      category: 'System',
      icon: Icons.compress,
    ),

    // Mutations
    PresetItem(
      id: 'update_batch',
      title: 'Bulk Update',
      subtitle: 'Update age of first 1000 users',
      category: 'Mutation',
      icon: Icons.edit,
    ),
    PresetItem(
      id: 'delete_batch',
      title: 'Bulk Delete',
      subtitle: 'Delete edges from last 500 users',
      category: 'Mutation',
      icon: Icons.delete,
    ),

    // Export/Import
    PresetItem(
      id: 'export_import',
      title: 'Export + Import',
      subtitle: 'Export users, import into fresh DB',
      category: 'Export',
      icon: Icons.import_export,
    ),
  ];

  // ──────────── Data Loading Dialog ────────────

  Future<void> _showLoadDataDialog(CozoDatabase db) async {
    final steps = buildLoadSteps();

    setState(() => _dataLoading = true);

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DataLoadDialog(db: db, steps: steps),
    );

    if (mounted) setState(() => _dataLoading = false);
  }

  // ──────────── Run logic ────────────

  void _requireData(PresetItem preset) {
    if (!DbService.dataLoaded) {
      preset.state = PresetRunState.error;
      preset.errorMessage = 'Load test data first';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Load test data first (tap "Load Test Data")'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Load',
            onPressed: () => _runPreset(_presets.first),
          ),
        ),
      );
    }
  }

  Future<void> _runPreset(PresetItem preset) async {
    final db = DbService.db;
    if (db == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Database not initialized'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (preset.id != 'load_data' && !DbService.dataLoaded) {
      _requireData(preset);
      setState(() {});
      return;
    }

    // Special case: load_data opens the progress dialog
    if (preset.id == 'load_data') {
      setState(() {
        preset.state = PresetRunState.running;
        preset.errorMessage = null;
        preset.detail = null;
      });
      final sw = Stopwatch()..start();
      try {
        await _showLoadDataDialog(db);
        sw.stop();
        if (DbService.dataLoaded) {
          setState(() {
            preset.state = PresetRunState.success;
            preset.durationMs = sw.elapsedMilliseconds;
            preset.detail = 'All data loaded successfully';
          });
        } else {
          setState(() {
            preset.state = PresetRunState.error;
            preset.durationMs = sw.elapsedMilliseconds;
            preset.errorMessage = 'Loading failed';
          });
        }
      } catch (e) {
        sw.stop();
        setState(() {
          preset.state = PresetRunState.error;
          preset.durationMs = sw.elapsedMilliseconds;
          preset.errorMessage = e.toString();
        });
      }
      return;
    }

    setState(() {
      preset.state = PresetRunState.running;
      preset.errorMessage = null;
      preset.detail = null;
    });

    final sw = Stopwatch()..start();
    try {
      final (rows, detail) = await _executePreset(db, preset.id);
      sw.stop();
      setState(() {
        preset.state = PresetRunState.success;
        preset.durationMs = sw.elapsedMilliseconds;
        preset.rowCount = rows;
        preset.detail = detail;
      });
    } catch (e) {
      sw.stop();
      setState(() {
        preset.state = PresetRunState.error;
        preset.durationMs = sw.elapsedMilliseconds;
        preset.errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${preset.title}: $e',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<(int?, String?)> _executePreset(CozoDatabase db, String id) async {
    CozoResult result;
    final graph = CozoGraph(db);
    final vecSearch = CozoVectorSearch(db);
    final textSearch = CozoTextSearch(db);

    switch (id) {
      case 'full_scan':
        result = await db.queryImmutable(
            '?[id, name, age, email, score] := *users[id, name, age, email, score]');
        return (result.length, '${result.length} rows');

      case 'filtered':
        result = await db.queryImmutable(
            '?[id, name, age] := *users[id, name, age, _, _], age >= 50, age < 60');
        return (result.length, '${result.length} users age 50-59');

      case 'aggregation':
        result = await db.queryImmutable(
            '?[count(id), mean(age), min(score), max(score)] := *users[id, _, age, _, score]');
        if (result.isNotEmpty) {
          final r = result.rows.first;
          return (1,
              'count=${r[0]}, mean_age=${(r[1] as num).toStringAsFixed(1)}, min=${(r[2] as num).toStringAsFixed(2)}, max=${(r[3] as num).toStringAsFixed(2)}');
        }
        return (0, null);

      case 'join':
        result = await db.queryImmutable('''
          ?[name, title, likes] := *posts[_, author, title, _, likes, _],
                                   *users[author, name, _, _, _],
                                   likes > 80
        ''');
        return (result.length, '${result.length} rows');

      case 'multi_hop':
        result = await db.queryImmutable('''
          ?[name, tag, title] := *tags[post_id, tag],
                                 *posts[post_id, author, title, _, _, _],
                                 *users[author, name, _, _, _],
                                 tag == "dart"
        ''');
        return (result.length, '${result.length} rows');

      case 'concurrent':
        await Future.wait([
          db.queryImmutable(
              '?[count(id)] := *users[id, _, age, _, _], age > 30'),
          db.queryImmutable(
              '?[count(id)] := *posts[id, _, _, _, likes, _], likes > 50'),
          db.queryImmutable('?[count(from)] := *follows[from, _]'),
          db.queryImmutable('?[tag, count(post_id)] := *tags[post_id, tag]'),
        ]);
        return (4, '4 parallel queries completed');

      case 'pagerank':
        result = await graph.pageRank('follows', iterations: 10);
        return (result.length, '${result.length} ranked nodes');

      case 'community':
        result = await graph.communityDetection('follows');
        final n = result.column('community').toSet().length;
        return (result.length, '$n communities');

      case 'bfs':
        result = await graph.bfs(
            'follows', 'users', ['id', 'name', 'age', 'email', 'score'], [0],
            condition: 'age > 90', limit: 10);
        return (result.length, '${result.length} results');

      case 'shortest_path':
        result =
            await graph.shortestPath('follows', 0, DbService.userCount ~/ 2);
        final hops =
            result.isNotEmpty ? (result.rows.first.last as List).length : 0;
        return (result.length, '$hops hops');

      case 'degree_centrality':
        result = await graph.degreeCentrality('follows');
        String? topInfo;
        if (result.isNotEmpty) {
          final top = result.toMaps().first;
          topInfo =
              'Top: node ${top['node']} (deg=${top['degree']}, in=${top['in_degree']}, out=${top['out_degree']})';
        }
        return (result.length, topInfo);

      case 'label_propagation':
        result = await graph.labelPropagation('follows_small');
        final n = result.column('label').toSet().length;
        return (result.length, '$n communities');

      case 'scc':
        result = await graph.stronglyConnectedComponents('follows_small');
        final n = result.column('component').toSet().length;
        return (result.length, '$n components');

      case 'connected_components':
        result = await graph.connectedComponents('follows_small');
        final n = result.column('component').toSet().length;
        return (result.length, '$n components');

      case 'clustering':
        result = await graph.clusteringCoefficients('follows_small');
        String? info;
        if (result.isNotEmpty) {
          final top = result.toMaps().first;
          info =
              'First: node=${top['node']}, coeff=${(top['coefficient'] as num).toStringAsFixed(4)}';
        }
        return (result.length, info);

      case 'topological_sort':
        result = await graph.topologicalSort('follows_small');
        return (result.length, '${result.length} nodes ordered');

      case 'dijkstra':
        result =
            await graph.shortestPathDijkstra('follows', [1, 2], [500, 1000]);
        final buf = StringBuffer('${result.length} paths');
        for (final row in result.toMaps().take(3)) {
          buf.write('\n${row['start']}->${row['goal']}: cost=${row['cost']}');
        }
        return (result.length, buf.toString());

      case 'yen':
        result =
            await graph.kShortestPathsYen('follows', [1], [500], k: 3);
        final buf = StringBuffer('${result.length} paths');
        for (final row in result.toMaps()) {
          buf.write('\ncost=${row['cost']}');
        }
        return (result.length, buf.toString());

      case 'random_walk':
        result =
            await graph.randomWalk('follows', [0, 1, 2], steps: 10, walks: 2);
        return (result.length, '${result.length} walks');

      case 'dfs':
        result = await graph.dfs(
            'follows', 'users', ['id', 'name', 'age', 'email', 'score'], [0],
            condition: 'age > 90', limit: 5);
        return (result.length, '${result.length} results');

      case 'hnsw_search':
        final qv = List.generate(
            DbService.vecDim, (_) => DbService.rng.nextDouble());
        result = await vecSearch.search(
          'embeddings', 'vec_idx',
          queryVector: qv,
          bindFields: ['id', 'label'],
          k: 10,
        );
        String? info;
        if (result.isNotEmpty) {
          final c = result.toMaps().first;
          info =
              'Nearest: ${c['label']} (dist=${(c['distance'] as num).toStringAsFixed(4)})';
        }
        return (result.length, info);

      case 'hnsw_radius':
        final qv = List.generate(
            DbService.vecDim, (_) => DbService.rng.nextDouble());
        result = await vecSearch.search(
          'embeddings', 'vec_idx',
          queryVector: qv,
          bindFields: ['id', 'label'],
          k: 100,
          radius: 1.0,
        );
        return (result.length, '${result.length} within radius 1.0');

      case 'fts_search':
        result = await textSearch.search(
          'articles', 'articles_fts',
          queryText: 'graph database',
          bindFields: ['id', 'title'],
          k: 5,
        );
        final buf = StringBuffer('${result.length} results');
        for (final row in result.toMaps()) {
          buf.write(
              '\n[${row['id']}] ${row['title']} (${(row['score'] as num).toStringAsFixed(3)})');
        }
        return (result.length, buf.toString());

      case 'fts_search2':
        result = await textSearch.search(
          'articles', 'articles_fts',
          queryText: 'vector search similarity',
          bindFields: ['id', 'title'],
          k: 5,
        );
        final buf = StringBuffer('${result.length} results');
        for (final row in result.toMaps()) {
          buf.write(
              '\n[${row['id']}] ${row['title']} (${(row['score'] as num).toStringAsFixed(3)})');
        }
        return (result.length, buf.toString());

      case 'lsh_search':
        result = await textSearch.similaritySearch(
          'articles', 'articles_lsh',
          queryText:
              'Graph databases use nodes and edges to store relationships between entities',
          bindFields: ['id', 'title'],
          k: 5,
        );
        final buf = StringBuffer('${result.length} results');
        for (final row in result.toMaps()) {
          buf.write('\n[${row['id']}] ${row['title']}');
        }
        return (result.length, buf.toString());

      case 'hybrid_search':
        result = await textSearch.searchWithConditions(
          'articles', 'articles_fts',
          queryText: 'database',
          bindFields: ['id', 'body'],
          joinConditions: '*articles{ id, title, body }, id < 7',
          outputFields: ['id', 'title', 'score'],
          k: 10,
        );
        final buf = StringBuffer('${result.length} results');
        for (final row in result.toMaps()) {
          buf.write(
              '\n[${row['id']}] ${row['title']} (${(row['score'] as num).toStringAsFixed(3)})');
        }
        return (result.length, buf.toString());

      case 'list_relations':
        result = await db.listRelations();
        final names = result.column('name').cast<String>().toList();
        return (result.length, names.join(', '));

      case 'describe_relation':
        result = await db.describeRelation('users');
        final cols = result.column('column').cast<String>().toList();
        return (result.length, 'Columns: ${cols.join(', ')}');

      case 'explain':
        result = await db.explain(
            '?[name, age] := *users[_, name, age, _, _], age > 50');
        return (result.length, '${result.length} plan steps');

      case 'running_queries':
        result = await db.listRunningQueries();
        return (result.length, '${result.length} active queries');

      case 'describe_sys':
        await db.query(':create sys_test {id: Int => value: String}');
        await db.query(
            '?[id, value] <- [[1, "test"]] :put sys_test {id, value}');
        final desc = await db.describeRelation('sys_test');
        await db.renameRelations({'sys_test': 'sys_renamed'});
        await db.removeRelations(['sys_renamed']);
        return (desc.length, 'Created -> Described -> Renamed -> Removed');

      case 'access_level':
        await db.query(':create acl_test {id: Int}');
        await db.setAccessLevel('protected', ['acl_test']);
        await db.setAccessLevel('normal', ['acl_test']);
        await db.removeRelations(['acl_test']);
        return (null, 'Set protected -> Reset normal -> Removed');

      case 'compact':
        await db.compact();
        return (null, 'Compaction complete');

      case 'update_batch':
        await db.query('''
          orig[id, name, age, email, score] := *users[id, name, age, email, score], id < 1000
          ?[id, name, age, email, score] := orig[id, name, old_age, email, score], age = old_age + 1
          :put users {id => name, age, email, score}
        ''');
        return (1000, '1000 rows updated');

      case 'delete_batch':
        await db.query('''
          ?[from, to] := *follows[from, to], from >= ${DbService.userCount - 500}
          :rm follows {from, to}
        ''');
        return (null, 'Edges from last 500 users deleted');

      case 'export_import':
        final exported = await db.exportRelations(['users']);
        final db2 = await CozoDatabase.openMemory();
        await db2.query(
            ':create users {id: Int => name: String, age: Int, email: String, score: Float}');
        await db2.importRelations(exported);
        await db2.close();
        return (DbService.userCount,
            '${DbService.userCount} users exported & imported');

      default:
        return (null, 'Unknown preset: $id');
    }
  }

  Future<void> _runAll() async {
    for (final preset in _presets) {
      if (!mounted) break;
      await _runPreset(preset);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _resetAll() {
    setState(() {
      for (final p in _presets) {
        p.reset();
      }
    });
  }

  // ──────────── UI ────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    // Group by category
    final categories = <String, List<PresetItem>>{};
    for (final p in _presets) {
      categories.putIfAbsent(p.category, () => []).add(p);
    }

    return Column(
      children: [
        // Top bar with Run All / Reset / Status — uses Wrap to prevent overflow
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed:
                    _presets.any((p) => p.state == PresetRunState.running)
                        ? null
                        : _runAll,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run All'),
              ),
              OutlinedButton.icon(
                onPressed: _resetAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
              if (_dataLoading)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Loading...',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                )
              else if (DbService.dataLoaded) ...[
                Chip(
                  label: const Text('Data loaded'),
                  avatar: Icon(Icons.check_circle,
                      size: 16, color: theme.colorScheme.primary),
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  height: 34,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const GraphPage()),
                      );
                    },
                    icon: const Icon(Icons.auto_graph, size: 16),
                    label: const Text('Visualize Graph',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ] else
                Chip(
                  label: const Text('No data'),
                  avatar: Icon(Icons.warning_amber,
                      size: 16, color: theme.colorScheme.error),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),

        // Preset cards
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...entry.value.map((preset) => _PresetCard(
                      preset: preset,
                      onRun: () => _runPreset(preset),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────── Data Loading Dialog ────────────

class _DataLoadDialog extends StatefulWidget {
  final CozoDatabase db;
  final List<LoadStep> steps;

  const _DataLoadDialog({required this.db, required this.steps});

  @override
  State<_DataLoadDialog> createState() => _DataLoadDialogState();
}

class _DataLoadDialogState extends State<_DataLoadDialog> {
  bool _done = false;
  bool _hasError = false;
  int _completedCount = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _runLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runLoad() async {
    try {
      await DbService.loadTestData(
        widget.db,
        onStep: (stepId, isStarting, {int? durationMs, String? error}) {
          if (!mounted) return;
          setState(() {
            final step = widget.steps.firstWhere((s) => s.id == stepId);
            if (isStarting) {
              step.status = LoadStepStatus.running;
            } else if (error != null) {
              step.status = LoadStepStatus.error;
              step.error = error;
              step.durationMs = durationMs;
              _hasError = true;
            } else {
              step.status = LoadStepStatus.done;
              step.durationMs = durationMs;
              _completedCount++;
            }
          });
          // Auto-scroll to show the current step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        },
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _done = true;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSteps = widget.steps.length;
    final progress = totalSteps > 0 ? _completedCount / totalSteps : 0.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _done
                          ? (_hasError ? Icons.error_rounded : Icons.check_circle_rounded)
                          : Icons.cloud_download_rounded,
                      key: ValueKey(_done ? 'done' : 'loading'),
                      color: _done
                          ? (_hasError ? theme.colorScheme.error : Colors.green)
                          : theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _done
                              ? (_hasError
                                  ? 'Loading Failed'
                                  : 'Data Loaded Successfully')
                              : 'Loading Test Data...',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_completedCount / $totalSteps steps',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _done ? 1.0 : progress),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: _hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Steps list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: widget.steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (_, i) =>
                      _LoadStepTile(step: widget.steps[i]),
                ),
              ),

              // Close button
              if (_done) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.done, size: 18),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadStepTile extends StatelessWidget {
  final LoadStep step;
  const _LoadStepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget leading;
    final Color textColor;
    final FontWeight fontWeight;

    switch (step.status) {
      case LoadStepStatus.pending:
        leading = Icon(step.icon, size: 20, color: theme.colorScheme.outline);
        textColor = theme.colorScheme.outline;
        fontWeight = FontWeight.normal;
      case LoadStepStatus.running:
        leading = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        );
        textColor = theme.colorScheme.primary;
        fontWeight = FontWeight.w600;
      case LoadStepStatus.done:
        leading =
            const Icon(Icons.check_circle_rounded, size: 20, color: Colors.green);
        textColor = theme.colorScheme.onSurface;
        fontWeight = FontWeight.normal;
      case LoadStepStatus.error:
        leading =
            Icon(Icons.error_rounded, size: 20, color: theme.colorScheme.error);
        textColor = theme.colorScheme.error;
        fontWeight = FontWeight.w500;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: step.status == LoadStepStatus.running
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : step.status == LoadStepStatus.error
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: SizedBox(key: ValueKey(step.status), child: leading),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: fontWeight,
              ),
            ),
          ),
          if (step.durationMs != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: step.status == LoadStepStatus.error
                    ? theme.colorScheme.errorContainer
                    : Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${step.durationMs}ms',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: step.status == LoadStepStatus.error
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────── Preset Card Widget ────────────

class _PresetCard extends StatelessWidget {
  final PresetItem preset;
  final VoidCallback onRun;

  const _PresetCard({required this.preset, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color stateColor;
    final IconData stateIcon;
    switch (preset.state) {
      case PresetRunState.idle:
        stateColor = theme.colorScheme.outline;
        stateIcon = Icons.play_circle_outline;
      case PresetRunState.running:
        stateColor = theme.colorScheme.primary;
        stateIcon = Icons.hourglass_top;
      case PresetRunState.success:
        stateColor = Colors.green;
        stateIcon = Icons.check_circle;
      case PresetRunState.error:
        stateColor = theme.colorScheme.error;
        stateIcon = Icons.error;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: preset.state == PresetRunState.running ? null : onRun,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(preset.icon, size: 20, color: stateColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(preset.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (preset.durationMs != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${preset.durationMs}ms',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: stateColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (preset.rowCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${preset.rowCount} rows',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (preset.state == PresetRunState.running)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(stateIcon, size: 20, color: stateColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(preset.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              if (preset.detail != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preset.detail!,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (preset.errorMessage != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preset.errorMessage!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
