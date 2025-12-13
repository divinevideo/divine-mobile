// ABOUTME: Service for persisting video clips to the clip library
// ABOUTME: Handles save, load, delete operations with JSON serialization

import 'dart:convert';

import 'package:openvine/models/saved_clip.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClipLibraryService {
  ClipLibraryService(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'clip_library';

  /// Save a clip to the library. Updates existing clip if ID matches.
  Future<void> saveClip(SavedClip clip) async {
    final clips = await getAllClips();

    final existingIndex = clips.indexWhere((c) => c.id == clip.id);

    if (existingIndex != -1) {
      clips[existingIndex] = clip;
    } else {
      clips.add(clip);
    }

    await _saveClips(clips);
  }

  /// Get all clips from the library, sorted by creation date (newest first)
  Future<List<SavedClip>> getAllClips() async {
    try {
      final String? jsonString = _prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final clips = jsonList
          .map((json) => SavedClip.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by creation date, newest first
      clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return clips;
    } catch (e) {
      // If storage is corrupted, return empty list
      return [];
    }
  }

  /// Get a single clip by ID
  Future<SavedClip?> getClipById(String id) async {
    final clips = await getAllClips();
    try {
      return clips.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Delete a clip by ID
  Future<void> deleteClip(String id) async {
    final clips = await getAllClips();
    clips.removeWhere((clip) => clip.id == id);
    await _saveClips(clips);
  }

  /// Clear all clips from the library
  Future<void> clearAllClips() async {
    await _prefs.remove(_storageKey);
  }

  /// Internal helper to save clips list to storage
  Future<void> _saveClips(List<SavedClip> clips) async {
    final jsonList = clips.map((clip) => clip.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_storageKey, jsonString);
  }
}
