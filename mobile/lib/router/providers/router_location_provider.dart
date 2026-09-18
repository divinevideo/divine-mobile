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
  // Deliberately asynchronous. GoRouterDelegate is a ChangeNotifier and
  // notifies while the widget tree is building — a route redirect runs inside
  // the build pipeline — so a synchronous controller hands that emission
  // straight to the listening [routerLocationProvider], which calls setValue
  // mid-build and throws `Tried to modify a provider while the widget tree was
  // building` into the app zone, and on to Crashlytics, on every cold start.
  final ctrl = StreamController<String>();

  void emit() {
    // Access location via routeInformationProvider
    final location = router.routeInformationProvider.value.uri.toString();
    if (!ctrl.isClosed) ctrl.add(location);
  }

  // Queue the current location so a subscriber gets one without waiting for
  // the first navigation. A single-subscription controller buffers it until
  // [routerLocationProvider] listens.
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
/// reliable change detection. Every emission — including the initial location —
/// arrives asynchronously, so reading this provider during a build sees
/// [AsyncLoading] until the first value lands on a later microtask.
final routerLocationProvider = StreamProvider<String>((ref) {
  return ref.watch(routerLocationStreamProvider);
});
