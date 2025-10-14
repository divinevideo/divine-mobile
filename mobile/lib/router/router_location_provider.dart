// ABOUTME: Reactive provider emitting router location changes
// ABOUTME: Core primitive for router-driven state architecture

import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'package:openvine/router/app_router.dart';

/// Provider that exposes the raw router location stream
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
    ctrl.close();
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
