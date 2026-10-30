// ABOUTME: Riverpod provider for tracking app foreground/background state
// ABOUTME: Ensures video visibility callbacks only trigger when app is actually in foreground

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_foreground_provider.g.dart';

/// State notifier for tracking app foreground/background state
@Riverpod(keepAlive: true)
class AppForeground extends _$AppForeground {
  @override
  bool build() => true; // Start as foreground

  void setForeground(bool isForeground) {
    state = isForeground;
  }
}

/// Convenience provider to read foreground state without watching
final isAppInForegroundProvider = Provider<bool>((ref) {
  return ref.watch(appForegroundProvider);
});

/// Emits each time the app returns to the foreground.
///
/// Pulling down the notification shade or Control Center also counts as
/// leaving the foreground, so this can fire after either closes; it suits work
/// that is harmless to repeat, such as retrying a failed load.
final appForegroundResumesProvider = Provider<Stream<void>>((ref) {
  final resumes = StreamController<void>.broadcast();
  ref
    ..onDispose(resumes.close)
    ..listen<bool>(appForegroundProvider, (_, isForeground) {
      if (isForeground) resumes.add(null);
    });
  return resumes.stream;
});
