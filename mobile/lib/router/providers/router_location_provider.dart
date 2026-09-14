// ABOUTME: Reactive provider emitting router location changes
// ABOUTME: Core primitive for router-driven state architecture

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:unified_logger/unified_logger.dart';

/// Provider that exposes the raw router location stream
///
/// Single-subscription: the stream accepts exactly one listener, and that
/// listener is [routerLocationProvider]. Consume the locations through that
/// provider — Riverpod multiplexes it — rather than subscribing here a second
/// time, which throws `Stream has already been listened to` and strands the
/// losing consumer in a permanent error state.
///
/// For testing, access this directly: `container.read(routerLocationStreamProvider)`
final routerLocationStreamProvider = Provider<Stream<String>>((ref) {
  final router = ref.read(goRouterProvider);
  final ctrl = StreamController<String>(sync: true);

  void emit() {
    // Access location via routeInformationProvider
    final location = router.routeInformationProvider.value.uri.toString();
    if (!ctrl.isClosed) ctrl.add(location);
  }

  // Emit initial location immediately
  emit();

  // Listen for location changes via delegate
  final delegate = router.routerDelegate;
  delegate.addListener(emit);

  ref.onDispose(() {
    delegate.removeListener(emit);
    unawaited(
      ctrl.close().catchError((Object error, StackTrace stack) {
        Log.error(
          'Failed to close router location stream: $error',
          name: 'RouterLocationProvider',
          category: LogCategory.system,
          stackTrace: stack,
        );
      }),
    );
  });

  return ctrl.stream;
});

/// StreamProvider that emits router location whenever it changes
///
/// Uses routerDelegate listener (not routeInformationProvider) for
/// reliable change detection. Emits synchronously on first read.
final routerLocationProvider = StreamProvider<String>((ref) {
  return ref.watch(routerLocationStreamProvider);
});
