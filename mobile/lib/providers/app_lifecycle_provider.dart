// ABOUTME: Reactive app lifecycle provider using WidgetsBindingObserver
// ABOUTME: Provides foreground/background state as a stream without widget lifecycle mutations

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider for app foreground/background state
/// Returns true when app is in foreground, false when backgrounded
final appForegroundProvider = StreamProvider<bool>((ref) {
  final binding = WidgetsBinding.instance;
  final ctrl = StreamController<bool>(sync: true);

  // Seed initial state (only "resumed" counts as foreground)
  // On Web, lifecycle can be null; default to true for initial load
  final initialState = binding.lifecycleState;
  ctrl.add(initialState == null || initialState == AppLifecycleState.resumed);

  final observer = _LifecycleObserver((state) {
    // Only "resumed" counts as foreground - videos should stop when app loses focus
    // inactive = visible but no focus (another app active) → background
    // paused = not visible (backgrounded on mobile) → background
    // hidden/detached = fully hidden → background
    final next = state == AppLifecycleState.resumed;
    ctrl.add(next);
  });

  binding.addObserver(observer);

  ref.onDispose(() {
    binding.removeObserver(observer);
    ctrl.close();
  });

  return ctrl.stream.distinct(); // avoid extra rebuilds
});

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);
  final void Function(AppLifecycleState state) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}
