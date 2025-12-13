// ABOUTME: Riverpod provider for SoundLibraryService singleton instance
// ABOUTME: Provides access to loaded sound library across the app

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/sound_library_service.dart';

final soundLibraryServiceProvider = Provider<SoundLibraryService>((ref) {
  final service = SoundLibraryService();
  // Note: loadSounds() should be called during app initialization
  return service;
});
