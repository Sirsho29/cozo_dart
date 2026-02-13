import 'package:cozo_dart/cozo_dart.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../services/db_service.dart';

/// Full-screen page that visualizes a subgraph from CozoDB using force-directed layout.
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  final GraphViewController _controller = GraphViewController();
  Graph? _graph;
  bool _loading = true;
  String? _error;
  int _nodeCount = 0;
  int _edgeCount = 0;

  // Layout algorithm choice
  String _layoutName = 'Force-Directed';

  // Node metadata: id -> name
  final Map<int, String> _nodeNames = {};
  // Node metadata: id -> community (for coloring)
  final Map<int, int> _nodeCommunities = {};

  // For tapped-node details
  int? _selectedNode;

  // Community colors
  static const _communityColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFFF97316), // orange
    Color(0xFF06B6D4), // cyan
    Color(0xFF84CC16), // lime
    Color(0xFFD946EF), // fuchsia
  ];

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = DbService.db;
      if (db == null) throw Exception('Database not initialized');

      // Query the full small subgraph (follows_small has nodes < 500)
      final edgeResult = await db.queryImmutable('''
        ?[from, to] := *follows_small[from, to]
      ''');

      // Collect unique node IDs from edges
      final nodeIds = <int>{};
      for (final row in edgeResult.rows) {
        nodeIds.add(row[0] as int);
        nodeIds.add(row[1] as int);
      }

      if (nodeIds.isEmpty) {
        throw Exception('No graph data found. Load test data first.');
      }

      // Get user names for these nodes
      final nameResult = await db.queryImmutable('''
        ?[id, name] := *users[id, name, _, _, _], id < 500
      ''');
      for (final row in nameResult.rows) {
        _nodeNames[row[0] as int] = row[1] as String;
      }

      // Run community detection on this subgraph for coloring
      try {
        final graph = CozoGraph(db);
        final communityResult = await graph.labelPropagation('follows_small');
        for (final row in communityResult.toMaps()) {
          final node = row['node'] as int;
          if (nodeIds.contains(node)) {
            _nodeCommunities[node] = row['label'] as int;
          }
        }
      } catch (_) {
        // Ignore community detection errors; we'll use a single color
      }

      // Build graphview Graph
      final graph = Graph();
      for (final row in edgeResult.rows) {
        final from = row[0] as int;
        final to = row[1] as int;
        graph.addEdge(
          Node.Id(from),
          Node.Id(to),
          paint: Paint()
            ..color = Colors.grey.withValues(alpha: 0.3)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke,
        );
      }

      if (!mounted) return;
      setState(() {
        _graph = graph;
        _nodeCount = nodeIds.length;
        _edgeCount = edgeResult.rows.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _colorForNode(int nodeId) {
    final community = _nodeCommunities[nodeId];
    if (community != null) {
      return _communityColors[community.abs() % _communityColors.length];
    }
    return _communityColors[nodeId % _communityColors.length];
  }

  Algorithm _getAlgorithm() {
    switch (_layoutName) {
      case 'Sugiyama':
        final config = SugiyamaConfiguration()
          ..nodeSeparation = 40
          ..levelSeparation = 80
          ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
        return SugiyamaAlgorithm(config);
      case 'Circular':
        return CircleLayoutAlgorithm(
          CircleLayoutConfiguration(reduceEdgeCrossing: true),
          null,
        );
      default:
        return FruchtermanReingoldAlgorithm(
          FruchtermanReingoldConfiguration(iterations: 500),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph Visualization'),
        actions: [
          if (_graph != null) ...[
            // Layout selector
            PopupMenuButton<String>(
              icon: const Icon(Icons.auto_graph),
              tooltip: 'Layout',
              initialValue: _layoutName,
              onSelected: (value) => setState(() => _layoutName = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'Force-Directed', child: Text('Force-Directed')),
                PopupMenuItem(value: 'Sugiyama', child: Text('Layered (Sugiyama)')),
                PopupMenuItem(value: 'Circular', child: Text('Circular')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Zoom to fit',
              onPressed: () => _controller.zoomToFit(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: _loadGraph,
            ),
          ],
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading graph data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load graph', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadGraph,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_graph == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              _InfoChip(
                icon: Icons.circle,
                label: '$_nodeCount nodes',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.arrow_forward,
                label: '$_edgeCount edges',
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: Icons.auto_graph,
                label: _layoutName,
                color: theme.colorScheme.tertiary,
              ),
              const Spacer(),
              if (_selectedNode != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _colorForNode(_selectedNode!).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _colorForNode(_selectedNode!), width: 1.5),
                    ),
                    child: Text(
                      'Node $_selectedNode: ${_nodeNames[_selectedNode] ?? "?"}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _colorForNode(_selectedNode!),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Graph
        Expanded(
          child: GraphView.builder(
            graph: _graph!,
            algorithm: _getAlgorithm(),
            controller: _controller,
            animated: true,
            autoZoomToFit: true,
            centerGraph: true,
            paint: Paint()
              ..color = Colors.grey.shade400
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke,
            builder: (Node node) {
              final id = node.key!.value as int;
              final name = _nodeNames[id];
              final color = _colorForNode(id);
              final isSelected = _selectedNode == id;

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedNode = _selectedNode == id ? null : id;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 12 : 8,
                    vertical: isSelected ? 8 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(isSelected ? 12 : 20),
                    border: Border.all(
                      color: color,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Text(
                    name != null ? '${name.split(' ').first}\n#$id' : '$id',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSelected ? 11 : 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : color,
                      height: 1.2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Colors = community (label propagation). Tap a node for details. Pinch to zoom, drag to pan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
