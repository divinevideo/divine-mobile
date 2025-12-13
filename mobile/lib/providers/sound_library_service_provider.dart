// ABOUTME: Riverpod provider for SoundLibraryService singleton instance
// ABOUTME: Provides access to loaded sound library including custom sounds across the app

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/sound_library_service.dart';

/// Async provider that loads sounds (bundled + custom) when first accessed
final soundLibraryServiceProvider =
    FutureProvider<SoundLibraryService>((ref) async {
  final service = SoundLibraryService();
  await service.loadSounds();
  await service.loadCustomSounds();
  return service;
});

/// Sync provider for when sounds are already loaded (use with caution)
final soundLibraryServiceSyncProvider = Provider<SoundLibraryService>((ref) {
  final asyncValue = ref.watch(soundLibraryServiceProvider);
  return asyncValue.value ?? SoundLibraryService();
});
