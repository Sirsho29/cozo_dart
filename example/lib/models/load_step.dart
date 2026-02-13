import 'package:flutter/material.dart';

/// Status of a single data-loading step.
enum LoadStepStatus { pending, running, done, error }

/// A single step in the data-loading pipeline.
class LoadStep {
  final String id;
  final String label;
  final IconData icon;
  LoadStepStatus status;
  int? durationMs;
  String? error;

  LoadStep({
    required this.id,
    required this.label,
    required this.icon,
    this.status = LoadStepStatus.pending,
  });

  void reset() {
    status = LoadStepStatus.pending;
    durationMs = null;
    error = null;
  }
}

/// All steps that loadTestData will execute.
List<LoadStep> buildLoadSteps() => [
      LoadStep(id: 'schema', label: 'Create schema (4 relations)', icon: Icons.schema),
      LoadStep(id: 'users', label: 'Insert 10,000 users', icon: Icons.people),
      LoadStep(id: 'edges', label: 'Insert 50,000 edges', icon: Icons.share),
      LoadStep(id: 'posts', label: 'Insert 5,000 posts', icon: Icons.article),
      LoadStep(id: 'tags', label: 'Insert 10,000 tags', icon: Icons.label),
      LoadStep(id: 'subgraph', label: 'Create small subgraph', icon: Icons.hub),
      LoadStep(id: 'articles', label: 'Insert 10 articles', icon: Icons.text_snippet),
      LoadStep(id: 'embeddings', label: 'Insert 1,000 embeddings', icon: Icons.data_array),
      LoadStep(id: 'hnsw', label: 'Create HNSW index', icon: Icons.radar),
      LoadStep(id: 'fts', label: 'Create FTS index', icon: Icons.search),
      LoadStep(id: 'lsh', label: 'Create LSH index', icon: Icons.fingerprint),
    ];
