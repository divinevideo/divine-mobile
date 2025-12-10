// ABOUTME: Service for managing multiple Nostr identities with secure storage
// ABOUTME: Allows users to save, switch between, and manage multiple Nostr accounts

import 'dart:async';
import 'dart:convert';

import 'package:nostr_key_manager/nostr_key_manager.dart' show SecureKeyStorage;
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a saved Nostr identity
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SavedIdentity {
  SavedIdentity({
    required this.npub,
    required this.displayName,
    required this.savedAt,
    this.lastUsedAt,
    this.isActive = false,
  });

  factory SavedIdentity.fromJson(Map<String, dynamic> json) => SavedIdentity(
    npub: json['npub'] as String,
    displayName: json['displayName'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    lastUsedAt: json['lastUsedAt'] != null
        ? DateTime.parse(json['lastUsedAt'] as String)
        : null,
    isActive: json['isActive'] as bool? ?? false,
  );
  final String npub;
  final String displayName;
  final DateTime savedAt;
  final DateTime? lastUsedAt;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'npub': npub,
    'displayName': displayName,
    'savedAt': savedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'isActive': isActive,
  };
}

/// Service for managing multiple Nostr identities
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class IdentityManagerService {
  IdentityManagerService({SecureKeyStorage? keyStorage})
    : _keyStorage = keyStorage ?? SecureKeyStorage();
  static const String _identitiesKey = 'saved_nostr_identities';
  static const String _activeIdentityKey = 'active_nostr_identity';

  final SecureKeyStorage _keyStorage;

  List<SavedIdentity> _savedIdentities = [];
  String? _activeIdentityNpub;

  List<SavedIdentity> get savedIdentities =>
      List.unmodifiable(_savedIdentities);
  String? get activeIdentityNpub => _activeIdentityNpub;

  /// Initialize the service and load saved identities
  Future<void> initialize() async {
    await _loadSavedIdentities();
  }

  /// Load saved identities from storage
  Future<void> _loadSavedIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load the list of saved identities
      final identitiesJson = prefs.getString(_identitiesKey);
      if (identitiesJson != null) {
        final List<dynamic> decoded = jsonDecode(identitiesJson);
        _savedIdentities = decoded
            .map((json) => SavedIdentity.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Load the active identity
      _activeIdentityNpub = prefs.getString(_activeIdentityKey);

      Log.debug(
        '📱 Loaded ${_savedIdentities.length} saved identities',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error loading saved identities: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    }
  }

  /// Save the current identity before switching
  Future<void> saveCurrentIdentity() async {
    try {
      final currentKeyContainer = await _keyStorage.getKeyContainer();
      if (currentKeyContainer == null) {
        Log.warning(
          'No current identity to save',
          name: 'IdentityManagerService',
          category: LogCategory.system,
        );
        return;
      }

      // Check if this identity is already saved
      final existingIndex = _savedIdentities.indexWhere(
        (identity) => identity.npub == currentKeyContainer.npub,
      );

      final displayName = NostrKeyUtils.maskKey(currentKeyContainer.npub);

      if (existingIndex >= 0) {
        // Update existing identity
        _savedIdentities[existingIndex] = SavedIdentity(
          npub: currentKeyContainer.npub,
          displayName: displayName,
          savedAt: _savedIdentities[existingIndex].savedAt,
          lastUsedAt: DateTime.now(),
          isActive: true,
        );
        Log.verbose(
          'Updated existing identity: $displayName',
          name: 'IdentityManagerService',
          category: LogCategory.system,
        );
      } else {
        // Add new identity
        _savedIdentities.add(
          SavedIdentity(
            npub: currentKeyContainer.npub,
            displayName: displayName,
            savedAt: DateTime.now(),
            lastUsedAt: DateTime.now(),
            isActive: true,
          ),
        );
        Log.debug(
          '📱 Saved new identity: $displayName',
          name: 'IdentityManagerService',
          category: LogCategory.system,
        );
      }

      // Mark all other identities as inactive
      for (var i = 0; i < _savedIdentities.length; i++) {
        if (_savedIdentities[i].npub != currentKeyContainer.npub) {
          _savedIdentities[i] = SavedIdentity(
            npub: _savedIdentities[i].npub,
            displayName: _savedIdentities[i].displayName,
            savedAt: _savedIdentities[i].savedAt,
            lastUsedAt: _savedIdentities[i].lastUsedAt,
            isActive: false,
          );
        }
      }

      _activeIdentityNpub = currentKeyContainer.npub;
      await _persistIdentities();
    } catch (e) {
      Log.error(
        'Error saving current identity: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    }
  }

  /// Switch to a saved identity
  Future<bool> switchToIdentity(String npub) async {
    try {
      final identity = _savedIdentities.firstWhere(
        (id) => id.npub == npub,
        orElse: () => throw Exception('Identity not found'),
      );

      // First, save the current identity if it exists
      await saveCurrentIdentity();

      // Find the private key for this npub
      // Note: This requires that we've previously saved the nsec securely
      // For now, this is a limitation - we can only switch to identities
      // that were imported during this app's lifetime

      Log.debug(
        'Switching to identity: ${identity.displayName}',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );

      // Update the active identity
      _activeIdentityNpub = npub;

      // Update saved identities to mark the new one as active
      for (var i = 0; i < _savedIdentities.length; i++) {
        _savedIdentities[i] = SavedIdentity(
          npub: _savedIdentities[i].npub,
          displayName: _savedIdentities[i].displayName,
          savedAt: _savedIdentities[i].savedAt,
          lastUsedAt: _savedIdentities[i].npub == npub
              ? DateTime.now()
              : _savedIdentities[i].lastUsedAt,
          isActive: _savedIdentities[i].npub == npub,
        );
      }

      await _persistIdentities();
      return true;
    } catch (e) {
      Log.error(
        'Error switching identity: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Remove a saved identity
  Future<void> removeIdentity(String npub) async {
    try {
      _savedIdentities.removeWhere((identity) => identity.npub == npub);

      if (_activeIdentityNpub == npub) {
        _activeIdentityNpub = null;
      }

      await _persistIdentities();
      Log.debug(
        '📱️ Removed identity with npub: ${NostrKeyUtils.maskKey(npub)}',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error removing identity: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    }
  }

  /// Persist identities to storage
  Future<void> _persistIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final identitiesJson = jsonEncode(
        _savedIdentities.map((id) => id.toJson()).toList(),
      );

      await prefs.setString(_identitiesKey, identitiesJson);

      if (_activeIdentityNpub != null) {
        await prefs.setString(_activeIdentityKey, _activeIdentityNpub!);
      } else {
        await prefs.remove(_activeIdentityKey);
      }
    } catch (e) {
      Log.error(
        'Error persisting identities: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear all saved identities (use with caution!)
  Future<void> clearAllIdentities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_identitiesKey);
      await prefs.remove(_activeIdentityKey);

      _savedIdentities.clear();
      _activeIdentityNpub = null;

      Log.debug(
        '📱️ Cleared all saved identities',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing identities: $e',
        name: 'IdentityManagerService',
        category: LogCategory.system,
      );
    }
  }
}
