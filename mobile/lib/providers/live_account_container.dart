// ABOUTME: Resolves the account container that is live at call time, for
// ABOUTME: callbacks registered at startup that outlive an account switch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/device_scope.dart';

/// Returns a function that resolves the account container live when called.
///
/// Startup registers some callbacks once, for the life of the process: static
/// hooks and listeners on platform streams. An in-place account switch mounts
/// a new container and disposes the one the app started with, so a callback
/// that captured [startupContainer] would read a disposed container. Read
/// through this instead. Before the swap host mounts, [startupContainer] is
/// the live one.
///
/// Reads `deviceScopeProvider`, which only an account container built by
/// `buildAccountContainer` overrides, so call it from code that runs at
/// startup rather than where the container is merely created.
ProviderContainer Function() liveAccountContainer(
  ProviderContainer startupContainer,
) {
  final controller = startupContainer
      .read(deviceScopeProvider)
      .switchController;
  return () => controller.currentContainer ?? startupContainer;
}
