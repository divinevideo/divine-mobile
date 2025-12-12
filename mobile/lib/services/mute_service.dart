// ABOUTME: Service for managing NIP-51 mute list (kind 10000) for blocking unwanted content
// ABOUTME: Handles muting users, hashtags, keywords, and threads to improve user experience

import 'dart:async';
import 'dart:convert';

import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of content that can be muted
enum MuteType {
  user, // Mute specific users (pubkeys)
  hashtag, // Mute hashtags
  keyword, // Mute specific words/phrases
  thread, // Mute entire threads/conversations
}

/// Extension for MuteType serialization
extension MuteTypeExtension on MuteType {
  String get value {
    switch (this) {
      case MuteType.user:
        return 'p';
      case MuteType.hashtag:
        return 't';
      case MuteType.keyword:
        return 'word';
      case MuteType.thread:
        return 'e';
    }
  }

  static MuteType fromString(String value) {
    switch (value) {
      case 'p':
        return MuteType.user;
      case 't':
        return MuteType.hashtag;
      case 'word':
        return MuteType.keyword;
      case 'e':
        return MuteType.thread;
      default:
        return MuteType.user;
    }
  }
}

/// Represents a muted item
class MuteItem {
  const MuteItem({
    required this.type,
    required this.value,
    required this.createdAt,
    this.reason,
    this.expireAt,
  });

  final MuteType type;
  final String value; // Pubkey, hashtag, keyword, or event ID
  final String? reason; // Optional reason for muting
  final DateTime createdAt;
  final DateTime? expireAt; // For temporary mutes

  bool get isExpired => expireAt != null && DateTime.now().isAfter(expireAt!);
  bool get isPermanent => expireAt == null;

  List<String> toTag() {
    final tag = [type.value, value];
    if (reason != null && reason!.isNotEmpty) {
      tag.add(reason!);
    }
    return tag;
  }

  static MuteItem fromTag(List<String> tag) {
    return MuteItem(
      type: MuteTypeExtension.fromString(tag[0]),
      value: tag[1],
      reason: tag.length > 2 ? tag[2] : null,
      createdAt: DateTime.now(), // We don't store creation time in tags
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'value': value,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'expireAt': expireAt?.toIso8601String(),
  };

  static MuteItem fromJson(Map<String, dynamic> json) => MuteItem(
    type: MuteTypeExtension.fromString(json['type']),
    value: json['value'],
    reason: json['reason'],
    createdAt: DateTime.parse(json['createdAt']),
    expireAt: json['expireAt'] != null
        ? DateTime.parse(json['expireAt'])
        : null,
  );

  @override
  bool operator ==(Object other) =>
      other is MuteItem && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}

/// Service for managing NIP-51 mute lists
class MuteService {
  MuteService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadMutedItems();
  }

  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  static const String mutedItemsStorageKey = 'muted_items';

  final List<MuteItem> _mutedItems = [];
  bool _isInitialized = false;

  // Getters
  List<MuteItem> get mutedItems =>
      List.unmodifiable(_mutedItems.where((item) => !item.isExpired));
  List<MuteItem> get mutedUsers =>
      mutedItems.where((item) => item.type == MuteType.user).toList();
  List<MuteItem> get mutedHashtags =>
      mutedItems.where((item) => item.type == MuteType.hashtag).toList();
  List<MuteItem> get mutedKeywords =>
      mutedItems.where((item) => item.type == MuteType.keyword).toList();
  List<MuteItem> get mutedThreads =>
      mutedItems.where((item) => item.type == MuteType.thread).toList();
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize mute service - user not authenticated',
          name: 'MuteService',
          category: LogCategory.system,
        );
        return;
      }

      // Clean up expired mutes
      _cleanupExpiredMutes();

      _isInitialized = true;
      Log.info(
        'Mute service initialized with ${_mutedItems.length} muted items',
        name: 'MuteService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize mute service: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
    }
  }

  // === MUTE MANAGEMENT ===

  /// Mute a user by pubkey
  Future<bool> muteUser(
    String pubkey, {
    String? reason,
    Duration? duration,
  }) async {
    return muteItem(MuteType.user, pubkey, reason: reason, duration: duration);
  }

  /// Mute a hashtag
  Future<bool> muteHashtag(
    String hashtag, {
    String? reason,
    Duration? duration,
  }) async {
    // Normalize hashtag (remove # if present, convert to lowercase)
    final normalizedHashtag = hashtag.startsWith('#')
        ? hashtag.substring(1).toLowerCase()
        : hashtag.toLowerCase();
    return muteItem(
      MuteType.hashtag,
      normalizedHashtag,
      reason: reason,
      duration: duration,
    );
  }

  /// Mute a keyword or phrase
  Future<bool> muteKeyword(
    String keyword, {
    String? reason,
    Duration? duration,
  }) async {
    return muteItem(
      MuteType.keyword,
      keyword.toLowerCase(),
      reason: reason,
      duration: duration,
    );
  }

  /// Mute an entire thread by event ID
  Future<bool> muteThread(
    String eventId, {
    String? reason,
    Duration? duration,
  }) async {
    return muteItem(
      MuteType.thread,
      eventId,
      reason: reason,
      duration: duration,
    );
  }

  /// Generic method to mute any type of item
  Future<bool> muteItem(
    MuteType type,
    String value, {
    String? reason,
    Duration? duration,
  }) async {
    try {
      final expireAt = duration != null ? DateTime.now().add(duration) : null;

      final muteItem = MuteItem(
        type: type,
        value: value,
        reason: reason,
        createdAt: DateTime.now(),
        expireAt: expireAt,
      );

      // Check if already muted
      if (_mutedItems.contains(muteItem)) {
        Log.debug(
          'Item already muted: $value',
          name: 'MuteService',
          category: LogCategory.system,
        );
        return true;
      }

      _mutedItems.add(muteItem);
      await _saveMutedItems();

      // Publish to Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishMuteListToNostr();
      }

      Log.info(
        'Muted ${type.value}: $value${duration != null ? ' (expires in ${duration.inHours}h)' : ' (permanent)'}',
        name: 'MuteService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to mute item: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Unmute an item
  Future<bool> unmuteItem(MuteType type, String value) async {
    try {
      final muteItem = MuteItem(
        type: type,
        value: value,
        createdAt: DateTime.now(), // Doesn't matter for equality check
      );

      final removed = _mutedItems.remove(muteItem);
      if (!removed) {
        Log.warning(
          'Item not found in mute list: $value',
          name: 'MuteService',
          category: LogCategory.system,
        );
        return false;
      }

      await _saveMutedItems();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishMuteListToNostr();
      }

      Log.info(
        'Unmuted ${type.value}: $value',
        name: 'MuteService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to unmute item: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Unmute a user
  Future<bool> unmuteUser(String pubkey) async {
    return unmuteItem(MuteType.user, pubkey);
  }

  /// Unmute a hashtag
  Future<bool> unmuteHashtag(String hashtag) async {
    final normalizedHashtag = hashtag.startsWith('#')
        ? hashtag.substring(1).toLowerCase()
        : hashtag.toLowerCase();
    return unmuteItem(MuteType.hashtag, normalizedHashtag);
  }

  /// Unmute a keyword
  Future<bool> unmuteKeyword(String keyword) async {
    return unmuteItem(MuteType.keyword, keyword.toLowerCase());
  }

  /// Unmute a thread
  Future<bool> unmuteThread(String eventId) async {
    return unmuteItem(MuteType.thread, eventId);
  }

  // === MUTE CHECKS ===

  /// Check if a user is muted
  bool isUserMuted(String pubkey) {
    return _isItemMuted(MuteType.user, pubkey);
  }

  /// Check if a hashtag is muted
  bool isHashtagMuted(String hashtag) {
    final normalizedHashtag = hashtag.startsWith('#')
        ? hashtag.substring(1).toLowerCase()
        : hashtag.toLowerCase();
    return _isItemMuted(MuteType.hashtag, normalizedHashtag);
  }

  /// Check if a keyword is muted
  bool isKeywordMuted(String keyword) {
    return _isItemMuted(MuteType.keyword, keyword.toLowerCase());
  }

  /// Check if a thread is muted
  bool isThreadMuted(String eventId) {
    return _isItemMuted(MuteType.thread, eventId);
  }

  /// Generic method to check if an item is muted
  bool _isItemMuted(MuteType type, String value) {
    return mutedItems.any((item) => item.type == type && item.value == value);
  }

  /// Check if content should be filtered based on mute rules
  bool shouldFilterContent({
    String? authorPubkey,
    String? content,
    List<String>? hashtags,
    String? eventId,
    String? rootEventId,
  }) {
    // Check if author is muted
    if (authorPubkey != null && isUserMuted(authorPubkey)) {
      return true;
    }

    // Check if thread is muted
    if (eventId != null && isThreadMuted(eventId)) {
      return true;
    }
    if (rootEventId != null && isThreadMuted(rootEventId)) {
      return true;
    }

    // Check for muted hashtags
    if (hashtags != null) {
      for (final hashtag in hashtags) {
        if (isHashtagMuted(hashtag)) {
          return true;
        }
      }
    }

    // Check for muted keywords in content
    if (content != null) {
      final lowerContent = content.toLowerCase();
      for (final mutedKeyword in mutedKeywords) {
        if (lowerContent.contains(mutedKeyword.value)) {
          return true;
        }
      }
    }

    return false;
  }

  // === BULK OPERATIONS ===

  /// Import mute list from another platform or backup
  Future<bool> importMuteList(List<MuteItem> items) async {
    try {
      var importedCount = 0;

      for (final item in items) {
        if (!_mutedItems.contains(item)) {
          _mutedItems.add(item);
          importedCount++;
        }
      }

      if (importedCount > 0) {
        await _saveMutedItems();

        // Publish to Nostr if authenticated
        if (_authService.isAuthenticated) {
          await _publishMuteListToNostr();
        }
      }

      Log.info(
        'Imported $importedCount new muted items',
        name: 'MuteService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to import mute list: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Export current mute list
  List<MuteItem> exportMuteList() {
    return List.from(mutedItems);
  }

  /// Clear all mutes
  Future<bool> clearAllMutes() async {
    try {
      _mutedItems.clear();
      await _saveMutedItems();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishMuteListToNostr();
      }

      Log.info(
        'Cleared all muted items',
        name: 'MuteService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to clear mute list: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  // === NOSTR PUBLISHING ===

  /// Publish mute list to Nostr as NIP-51 kind 10000 event
  Future<void> _publishMuteListToNostr() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot publish mute list - user not authenticated',
          name: 'MuteService',
          category: LogCategory.system,
        );
        return;
      }

      // Create NIP-51 kind 10000 tags
      final tags = <List<String>>[
        ['client', 'diVine'],
      ];

      // Add muted items as tags (only non-expired, permanent mutes for Nostr)
      for (final item in mutedItems.where((item) => item.isPermanent)) {
        tags.add(item.toTag());
      }

      final event = await _authService.createAndSignEvent(
        kind: 10000, // NIP-51 mute list
        content: 'divine mute list',
        tags: tags,
      );

      if (event != null) {
        final result = await _nostrService.broadcast(event);
        if (result.successCount > 0) {
          Log.debug(
            'Published mute list to Nostr: ${event.id}',
            name: 'MuteService',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to publish mute list to Nostr: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
    }
  }

  // === MAINTENANCE ===

  /// Remove expired mutes
  void _cleanupExpiredMutes() {
    final before = _mutedItems.length;
    _mutedItems.removeWhere((item) => item.isExpired);
    final after = _mutedItems.length;

    if (before != after) {
      Log.debug(
        'Cleaned up ${before - after} expired mutes',
        name: 'MuteService',
        category: LogCategory.system,
      );
      _saveMutedItems();
    }
  }

  /// Get statistics about muted content
  Map<String, dynamic> getMuteStats() {
    final activeMutes = mutedItems;
    return {
      'total': activeMutes.length,
      'users': activeMutes.where((item) => item.type == MuteType.user).length,
      'hashtags': activeMutes
          .where((item) => item.type == MuteType.hashtag)
          .length,
      'keywords': activeMutes
          .where((item) => item.type == MuteType.keyword)
          .length,
      'threads': activeMutes
          .where((item) => item.type == MuteType.thread)
          .length,
      'temporary': activeMutes.where((item) => !item.isPermanent).length,
      'permanent': activeMutes.where((item) => item.isPermanent).length,
    };
  }

  // === STORAGE ===

  /// Load muted items from local storage
  void _loadMutedItems() {
    final mutedItemsJson = _prefs.getString(mutedItemsStorageKey);
    if (mutedItemsJson != null) {
      try {
        final List<dynamic> itemsData = jsonDecode(mutedItemsJson);
        _mutedItems.clear();
        _mutedItems.addAll(
          itemsData.map(
            (json) => MuteItem.fromJson(json as Map<String, dynamic>),
          ),
        );
        Log.debug(
          'Loaded ${_mutedItems.length} muted items from storage',
          name: 'MuteService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load muted items: $e',
          name: 'MuteService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save muted items to local storage
  Future<void> _saveMutedItems() async {
    try {
      final mutedItemsJson = _mutedItems.map((item) => item.toJson()).toList();
      await _prefs.setString(mutedItemsStorageKey, jsonEncode(mutedItemsJson));
    } catch (e) {
      Log.error(
        'Failed to save muted items: $e',
        name: 'MuteService',
        category: LogCategory.system,
      );
    }
  }
}
