// ABOUTME: Tracks fire-and-forget editor work that must settle before test teardown
// ABOUTME: Provides a fixed-point completion boundary shared by editor notifiers

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final editorBackgroundWorkProvider = Provider<EditorBackgroundWork>(
  (ref) => EditorBackgroundWork(),
);

/// Tracks editor operations that remain fire-and-forget in production.
class EditorBackgroundWork {
  final Set<Future<void>> _operations = {};

  /// Registers [operation] until it completes.
  void track(Future<void> operation) {
    late final Future<void> trackedOperation;
    trackedOperation = operation.whenComplete(
      () => _operations.remove(trackedOperation),
    );
    _operations.add(trackedOperation);
    unawaited(trackedOperation);
  }

  /// Completes once all registered work, including work it starts, is done.
  @visibleForTesting
  Future<void> settle() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    while (_operations.isNotEmpty) {
      try {
        await Future.wait(_operations.toList());
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Whether teardown currently has background work to await.
  @visibleForTesting
  bool get isNotEmptyForTest => _operations.isNotEmpty;
}
