import 'package:flutter/material.dart';

/// Represents the run state of a single preset query.
enum PresetRunState {
  /// Not yet run.
  idle,

  /// Currently executing.
  running,

  /// Completed successfully.
  success,

  /// Failed with an error.
  error,
}

/// A single preset query card model.
class PresetItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;

  PresetRunState state;
  int? durationMs;
  int? rowCount;
  String? detail;
  String? errorMessage;

  PresetItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    this.state = PresetRunState.idle,
  });

  void reset() {
    state = PresetRunState.idle;
    durationMs = null;
    rowCount = null;
    detail = null;
    errorMessage = null;
  }
}
