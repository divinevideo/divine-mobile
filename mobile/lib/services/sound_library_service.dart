// ABOUTME: Service for loading and searching bundled Vine sounds from assets
// ABOUTME: Parses manifest JSON, provides search, and supports custom sound imports

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundLibraryService {
  static const String _manifestPath = 'assets/sounds/sounds_manifest.json';
  static const String _customSoundsKey = 'custom_sounds';

  List<VineSound> _sounds = [];
  List<VineSound> _customSounds = [];
  bool _isLoaded = false;

  List<VineSound> get sounds => List.unmodifiable([..._sounds, ..._customSounds]);
  List<VineSound> get customSounds => List.unmodifiable(_customSounds);
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
    return searchSounds(sounds, query);
  }

  static List<VineSound> searchSounds(List<VineSound> sounds, String query) {
    if (query.trim().isEmpty) {
      return sounds;
    }

    return sounds.where((sound) => sound.matchesSearch(query)).toList();
  }

  VineSound? getSoundById(String id) {
    try {
      return sounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Loads custom sounds from persistent storage
  Future<void> loadCustomSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customSoundsJson = prefs.getString(_customSoundsKey);

      if (customSoundsJson != null) {
        final List<dynamic> jsonList = jsonDecode(customSoundsJson);
        _customSounds = jsonList
            .map((json) => VineSound.fromJson(json as Map<String, dynamic>))
            .toList();
        Log.info(
          '🔊 Loaded ${_customSounds.length} custom sounds',
          name: 'SoundLibraryService',
        );
      }
    } catch (e) {
      Log.error(
        '🔊 Failed to load custom sounds: $e',
        name: 'SoundLibraryService',
      );
    }
  }

  /// Saves custom sounds to persistent storage
  Future<void> _saveCustomSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _customSounds.map((s) => s.toJson()).toList();
      await prefs.setString(_customSoundsKey, jsonEncode(jsonList));
    } catch (e) {
      Log.error(
        '🔊 Failed to save custom sounds: $e',
        name: 'SoundLibraryService',
      );
    }
  }

  /// Adds a custom sound to the library and persists it
  Future<void> addCustomSound(VineSound sound) async {
    // Avoid duplicates
    if (_customSounds.any((s) => s.id == sound.id)) {
      return;
    }

    _customSounds.add(sound);
    await _saveCustomSounds();

    Log.info(
      '🔊 Added custom sound: ${sound.title}',
      name: 'SoundLibraryService',
    );
  }

  /// Removes a custom sound from the library
  Future<void> removeCustomSound(String soundId) async {
    _customSounds.removeWhere((s) => s.id == soundId);
    await _saveCustomSounds();

    Log.info(
      '🔊 Removed custom sound: $soundId',
      name: 'SoundLibraryService',
    );
  }
}
