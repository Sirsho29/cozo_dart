import 'package:flutter/material.dart';

/// Placeholder tab for future comparison with sqflite, Hive, etc.
class CompareTab extends StatelessWidget {
  const CompareTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows,
                size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Compare',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon — side-by-side benchmarks comparing CozoDB with sqflite, Hive, Isar, and other embedded databases.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                Chip(label: Text('sqflite')),
                Chip(label: Text('Hive')),
                Chip(label: Text('Isar')),
                Chip(label: Text('ObjectBox')),
                Chip(label: Text('Drift')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
