import 'package:flutter/material.dart';

import '../services/db_service.dart';

/// Tab for running ad-hoc CozoScript queries.
class QueryTab extends StatefulWidget {
  const QueryTab({super.key});

  @override
  State<QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<QueryTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController(text: '?[a] := a in [1, 2, 3]');
  String _output = '';
  bool _running = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkDb();
  }

  Future<void> _checkDb() async {
    if (!DbService.isReady) {
      await DbService.open();
    }
    setState(() => _output = 'Database ready.\n\n'
        'Try queries like:\n'
        '  ?[a] := a in [1, 2, 3]\n'
        '  ::relations\n'
        '  ?[count(id)] := *users[id, _, _, _, _]');
  }

  Future<void> _runQuery() async {
    final db = DbService.db;
    if (db == null) {
      _showSnackBar('Database not initialized');
      return;
    }

    setState(() => _running = true);
    final sw = Stopwatch()..start();
    try {
      final result = await db.query(_controller.text);
      sw.stop();
      setState(() {
        _output = 'Headers: ${result.headers}\n'
            'Rows (${result.length}):\n'
            '${result.toMaps().take(100).map((m) => '  $m').join('\n')}'
            '${result.length > 100 ? '\n  ... (${result.length - 100} more)' : ''}\n'
            'Took: ${sw.elapsedMilliseconds}ms (${result.took?.toStringAsFixed(4)}s engine)';
      });
    } catch (e) {
      sw.stop();
      setState(() => _output = 'Error (${sw.elapsedMilliseconds}ms):\n$e');
    } finally {
      setState(() => _running = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'CozoScript Query',
              border: const OutlineInputBorder(),
              suffixIcon: _running
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _runQuery,
                    ),
            ),
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? null : _runQuery,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _controller.clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!DbService.dataLoaded)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Load test data from DB Presets tab to query relations like users, follows, posts, tags.',
                        style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
