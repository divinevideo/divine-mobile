// ABOUTME: Service for loading and searching bundled Vine sounds from assets
// ABOUTME: Parses manifest JSON and provides search functionality

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/utils/unified_logger.dart';

class SoundLibraryService {
  static const String _manifestPath = 'assets/sounds/sounds_manifest.json';

  List<VineSound> _sounds = [];
  bool _isLoaded = false;

  List<VineSound> get sounds => List.unmodifiable(_sounds);
  bool get isLoaded => _isLoaded;

  Future<void> loadSounds() async {
    if (_isLoaded) return;

    try {
      final manifestJson = await rootBundle.loadString(_manifestPath);
      _sounds = parseManifest(manifestJson);
      _isLoaded = true;
      Log.info(
        '🔊 Loaded ${_sounds.length} sounds from manifest',
        name: 'SoundLibraryService',
      );
    } catch (e) {
      Log.error(
        '🔊 Failed to load sounds manifest: $e',
        name: 'SoundLibraryService',
      );
      _sounds = [];
      _isLoaded = true; // Mark as loaded even on error to prevent retries
    }
  }

  static List<VineSound> parseManifest(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final soundsJson = json['sounds'] as List<dynamic>;

    return soundsJson
        .map((s) => VineSound.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  List<VineSound> search(String query) {
    return searchSounds(_sounds, query);
  }

  static List<VineSound> searchSounds(List<VineSound> sounds, String query) {
    if (query.trim().isEmpty) {
      return sounds;
    }

    return sounds.where((sound) => sound.matchesSearch(query)).toList();
  }

  VineSound? getSoundById(String id) {
    try {
      return _sounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
