// ABOUTME: Service for persisting vine drafts using shared_preferences
// ABOUTME: Handles save, load, delete, and clear operations with JSON serialization

import 'dart:convert';

import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftStorageService {
  DraftStorageService(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'vine_drafts';

  /// Save a draft to storage. If a draft with the same ID exists, it will be updated.
  Future<void> saveDraft(VineDraft draft) async {
    final drafts = await getAllDrafts();

    // Check if draft with same ID exists
    final existingIndex = drafts.indexWhere((d) => d.id == draft.id);

    if (existingIndex != -1) {
      // Update existing draft
      drafts[existingIndex] = draft;
    } else {
      // Add new draft
      drafts.add(draft);
    }

    await _saveDrafts(drafts);
  }

  /// Get all drafts from storage
  Future<List<VineDraft>> getAllDrafts() async {
    try {
      final String? jsonString = _prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => VineDraft.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If storage is corrupted, return empty list
      return [];
    }
  }

  /// Delete a draft by ID
  Future<void> deleteDraft(String id) async {
    final drafts = await getAllDrafts();
    drafts.removeWhere((draft) => draft.id == id);
    await _saveDrafts(drafts);
  }

  /// Clear all drafts from storage
  Future<void> clearAllDrafts() async {
    await _prefs.remove(_storageKey);
  }

  /// Internal helper to save drafts list to storage
  Future<void> _saveDrafts(List<VineDraft> drafts) async {
    final jsonList = drafts.map((draft) => draft.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_storageKey, jsonString);
  }
}
