// ABOUTME: Helper utilities for video controller lifecycle management
// ABOUTME: Provides functions to dispose video controllers when entering camera or other screens

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';

/// Dispose all video controllers by invalidating the provider family
///
/// This forces all video controllers to dispose, even those kept alive by cache.
/// Use this when entering camera screen or other contexts that need to fully
/// reset video playback state.
///
/// Works with both WidgetRef and ProviderContainer
void disposeAllVideoControllers(Object ref) {
  if (ref is WidgetRef) {
    ref.invalidate(individualVideoControllerProvider);
  } else if (ref is ProviderContainer) {
    ref.invalidate(individualVideoControllerProvider);
  } else {
    throw ArgumentError(
      'Expected WidgetRef or ProviderContainer, got ${ref.runtimeType}',
    );
  }
}
