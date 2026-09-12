// ABOUTME: Shared lifecycle helper for permission settings retries.
// ABOUTME: Defers retry work until the app resumes after opening Settings.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

typedef RetryAfterSettingsCallback = Future<void> Function();

/// Runs a pending retry after Settings returns the app to the foreground.
mixin RetryAfterSettingsOnResume<T extends StatefulWidget> on State<T> {
  RetryAfterSettingsCallback? _pendingSettingsRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_settingsResumeObserver);
  }

  late final _SettingsResumeObserver _settingsResumeObserver =
      _SettingsResumeObserver(_handleResume);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_settingsResumeObserver);
    super.dispose();
  }

  Future<void> openSettingsAndRetryOnResume({
    required Future<bool> Function() openSettings,
    required RetryAfterSettingsCallback retry,
  }) async {
    _pendingSettingsRetry = retry;

    try {
      final opened = await openSettings();
      if (!opened) {
        _pendingSettingsRetry = null;
      }
    } catch (_) {
      _pendingSettingsRetry = null;
      rethrow;
    }
  }

  void _handleResume() {
    final retry = _pendingSettingsRetry;
    if (retry == null || !mounted) {
      return;
    }

    _pendingSettingsRetry = null;
    unawaited(retry());
  }
}

class _SettingsResumeObserver extends WidgetsBindingObserver {
  _SettingsResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
