// ABOUTME: Service for managing NIP-51 bookmarks (kind 10003) and bookmark sets (kind 30003)
// ABOUTME: Handles creation, updates, and management of user's bookmark collections

import 'dart:async';
import 'dart:convert';

import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/nostr_list_service_mixin.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a bookmarked item
class BookmarkItem {
  const BookmarkItem({
    required this.type,
    required this.id,
    this.relay,
    this.petname,
  });

  final String
      type; // 'e' (event), 'a' (parameterized replaceable), 't' (hashtag), 'r' (URL)
  final String id; // Event ID, article ID, hashtag, or URL
  final String? relay; // Optional relay hint
  final String? petname; // Optional petname/label

  List<String> toTag() {
    final tag = [type, id];
    if (relay != null) tag.add(relay!);
    if (petname != null) tag.add(petname!);
    return tag;
  }

  static BookmarkItem fromTag(List<String> tag) {
    return BookmarkItem(
      type: tag[0],
      id: tag[1],
      relay: tag.length > 2 ? tag[2] : null,
      petname: tag.length > 3 ? tag[3] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'relay': relay,
        'petname': petname,
      };

  static BookmarkItem fromJson(Map<String, dynamic> json) => BookmarkItem(
        type: json['type'],
        id: json['id'],
        relay: json['relay'],
        petname: json['petname'],
      );

  @override
  bool operator ==(Object other) =>
      other is BookmarkItem && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Represents a bookmark set (categorized bookmarks)
class BookmarkSet {
  const BookmarkSet({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.imageUrl,
    this.nostrEventId,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final List<BookmarkItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nostrEventId;

  BookmarkSet copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<BookmarkItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nostrEventId,
  }) =>
      BookmarkSet(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        nostrEventId: nostrEventId ?? this.nostrEventId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'items': items.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nostrEventId': nostrEventId,
      };

  static BookmarkSet fromJson(Map<String, dynamic> json) => BookmarkSet(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        imageUrl: json['imageUrl'],
        items: (json['items'] as List<dynamic>)
            .map((item) => BookmarkItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        nostrEventId: json['nostrEventId'],
      );
}

/// Service for managing NIP-51 bookmarks and bookmark sets
class BookmarkService with NostrListServiceMixin {
  BookmarkService({
    required INostrService nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  })  : _nostrService = nostrService,
        _authService = authService,
        _prefs = prefs {
    _loadBookmarksFromSharedPreferences();
  }

  final INostrService _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  // Mixin interface implementations
  @override
  INostrService get nostrService => _nostrService;
  @override
  AuthService get authService => _authService;

  static const String globalBookmarksStorageKey = 'global_bookmarks';
  static const String bookmarkSetsStorageKey = 'bookmark_sets';
  static const String globalBookmarksId = 'global_bookmarks';

  // Global bookmarks (Kind 10003)
  final List<BookmarkItem> _globalBookmarks = [];

  // Bookmark sets (Kind 30003)
  final List<BookmarkSet> _bookmarkSets = [];

  bool _isInitialized = false;

  // Getters
  List<BookmarkItem> get globalBookmarks => List.unmodifiable(_globalBookmarks);
  List<BookmarkSet> get bookmarkSets => List.unmodifiable(_bookmarkSets);
  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot initialize bookmarks - user not authenticated',
            name: 'BookmarkService', category: LogCategory.system);
        return;
      }

      // 1. Load from SharedPreferences cache (fast, may be stale)
      _loadBookmarksFromSharedPreferences();

      // 2. Load from embedded relay (authoritative, cached locally)
      await _loadBookmarksFromNostr();

      // 3. Update SharedPreferences cache for next startup
      await _saveBookmarksToSharedPreferences();

      _isInitialized = true;
      Log.info(
          'Bookmark service initialized with ${_globalBookmarks.length} global bookmarks and ${_bookmarkSets.length} bookmark sets',
          name: 'BookmarkService',
          category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to initialize bookmark service: $e',
          name: 'BookmarkService', category: LogCategory.system);
    }
  }

  // === GLOBAL BOOKMARKS (Kind 10003) ===

  /// Add a video event to global bookmarks
  Future<bool> addVideoToGlobalBookmarks(String videoEventId,
      {String? relay, String? petname}) async {
    return addToGlobalBookmarks(
      BookmarkItem(
        type: 'e',
        id: videoEventId,
        relay: relay,
        petname: petname,
      ),
    );
  }

  /// Add an item to global bookmarks
  Future<bool> addToGlobalBookmarks(BookmarkItem item) async {
    try {
      // Check if already bookmarked
      if (_globalBookmarks.contains(item)) {
        Log.debug('Item already in global bookmarks: ${item.id}',
            name: 'BookmarkService', category: LogCategory.system);
        return true;
      }

      _globalBookmarks.add(item);
      await _saveBookmarks();

      // Publish to Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishGlobalBookmarksToNostr();
      }

      Log.info('Added item to global bookmarks: ${item.id}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to add to global bookmarks: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Remove an item from global bookmarks
  Future<bool> removeFromGlobalBookmarks(BookmarkItem item) async {
    try {
      final removed = _globalBookmarks.remove(item);
      if (!removed) {
        Log.warning('Item not found in global bookmarks: ${item.id}',
            name: 'BookmarkService', category: LogCategory.system);
        return false;
      }

      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishGlobalBookmarksToNostr();
      }

      Log.info('Removed item from global bookmarks: ${item.id}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to remove from global bookmarks: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Check if an item is in global bookmarks
  bool isInGlobalBookmarks(String itemId, String type) {
    return _globalBookmarks
        .any((item) => item.id == itemId && item.type == type);
  }

  /// Check if a video event is bookmarked globally
  bool isVideoBookmarkedGlobally(String videoEventId) {
    return isInGlobalBookmarks(videoEventId, 'e');
  }

  // === BOOKMARK SETS (Kind 30003) ===

  /// Create a new bookmark set
  Future<BookmarkSet?> createBookmarkSet({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setId = 'bookmarkset_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newSet = BookmarkSet(
        id: setId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        items: [],
        createdAt: now,
        updatedAt: now,
      );

      _bookmarkSets.add(newSet);
      await _saveBookmarks();

      // Publish to Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(newSet);
      }

      Log.info('Created new bookmark set: $name ($setId)',
          name: 'BookmarkService', category: LogCategory.system);

      return newSet;
    } catch (e) {
      Log.error('Failed to create bookmark set: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return null;
    }
  }

  /// Add an item to a bookmark set
  Future<bool> addToBookmarkSet(String setId, BookmarkItem item) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning('Bookmark set not found: $setId',
            name: 'BookmarkService', category: LogCategory.system);
        return false;
      }

      final set = _bookmarkSets[setIndex];

      // Check if item is already in the set
      if (set.items.contains(item)) {
        Log.debug('Item already in bookmark set: ${item.id}',
            name: 'BookmarkService', category: LogCategory.system);
        return true;
      }

      final updatedItems = [...set.items, item];
      final updatedSet = set.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug('Added item to bookmark set "${set.name}": ${item.id}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to add to bookmark set: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Remove an item from a bookmark set
  Future<bool> removeFromBookmarkSet(String setId, BookmarkItem item) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning('Bookmark set not found: $setId',
            name: 'BookmarkService', category: LogCategory.system);
        return false;
      }

      final set = _bookmarkSets[setIndex];
      final updatedItems = set.items.where((i) => i != item).toList();

      final updatedSet = set.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug('Removed item from bookmark set "${set.name}": ${item.id}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to remove from bookmark set: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Update bookmark set metadata
  Future<bool> updateBookmarkSet({
    required String setId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _bookmarkSets[setIndex];
      final updatedSet = set.copyWith(
        name: name ?? set.name,
        description: description ?? set.description,
        imageUrl: imageUrl ?? set.imageUrl,
        updatedAt: DateTime.now(),
      );

      _bookmarkSets[setIndex] = updatedSet;
      await _saveBookmarks();

      // Update on Nostr if authenticated
      if (_authService.isAuthenticated) {
        await _publishBookmarkSetToNostr(updatedSet);
      }

      Log.debug('Updated bookmark set: ${updatedSet.name}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to update bookmark set: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Delete a bookmark set
  Future<bool> deleteBookmarkSet(String setId) async {
    try {
      final setIndex = _bookmarkSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _bookmarkSets[setIndex];

      // For replaceable events (kind 30003), we don't need a deletion event
      // The event is automatically replaced when publishing with the same d-tag

      _bookmarkSets.removeAt(setIndex);
      await _saveBookmarks();

      Log.debug('Deleted bookmark set: ${set.name}',
          name: 'BookmarkService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to delete bookmark set: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Get bookmark set by ID
  BookmarkSet? getBookmarkSetById(String setId) {
    try {
      return _bookmarkSets.firstWhere((set) => set.id == setId);
    } catch (e) {
      return null;
    }
  }

  /// Check if an item is in a specific bookmark set
  bool isInBookmarkSet(String setId, String itemId, String type) {
    final set = getBookmarkSetById(setId);
    return set?.items.any((item) => item.id == itemId && item.type == type) ??
        false;
  }

  // === NOSTR PUBLISHING ===

  /// Public method to publish a bookmark set to Nostr (for background sync)
  Future<bool> publishBookmarkSetToNostr(String setId) async {
    try {
      final set = getBookmarkSetById(setId);
      if (set == null) {
        Log.warning('Cannot publish bookmark set - not found: $setId',
            name: 'BookmarkService', category: LogCategory.system);
        return false;
      }

      await _publishBookmarkSetToNostr(set);
      return true;
    } catch (e) {
      Log.error('Failed to publish bookmark set $setId: $e',
          name: 'BookmarkService', category: LogCategory.system);
      return false;
    }
  }

  /// Publish global bookmarks to Nostr as NIP-51 kind 10003 event
  Future<void> _publishGlobalBookmarksToNostr() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot publish bookmarks - user not authenticated',
            name: 'BookmarkService', category: LogCategory.system);
        return;
      }

      // Create NIP-51 kind 10003 tags
      final tags = <List<String>>[
        ['client', 'diVine'],
      ];

      // Add bookmark items as tags
      for (final item in _globalBookmarks) {
        tags.add(item.toTag());
      }

      final event = await _authService.createAndSignEvent(
        kind: 10003, // NIP-51 global bookmarks
        content: 'divine global bookmarks',
        tags: tags,
      );

      if (event != null) {
        final result = await _nostrService.broadcastEvent(event);
        if (result.successCount > 0) {
          Log.debug('Published global bookmarks to Nostr: ${event.id}',
              name: 'BookmarkService', category: LogCategory.system);
        }
      }
    } catch (e) {
      Log.error('Failed to publish global bookmarks to Nostr: $e',
          name: 'BookmarkService', category: LogCategory.system);
    }
  }

  /// Publish bookmark set to Nostr as NIP-51 kind 30003 event
  Future<void> _publishBookmarkSetToNostr(BookmarkSet set) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot publish bookmark set - user not authenticated',
            name: 'BookmarkService', category: LogCategory.system);
        return;
      }

      // Create NIP-51 kind 30003 tags
      final tags = <List<String>>[
        ['d', set.id], // Identifier for replaceable event
        ['title', set.name],
        ['client', 'diVine'],
      ];

      // Add description if present
      if (set.description != null && set.description!.isNotEmpty) {
        tags.add(['description', set.description!]);
      }

      // Add image if present
      if (set.imageUrl != null && set.imageUrl!.isNotEmpty) {
        tags.add(['image', set.imageUrl!]);
      }

      // Add bookmark items as tags
      for (final item in set.items) {
        tags.add(item.toTag());
      }

      final content = set.description ?? 'Bookmark collection: ${set.name}';

      final event = await _authService.createAndSignEvent(
        kind: 30003, // NIP-51 bookmark set
        content: content,
        tags: tags,
      );

      if (event != null) {
        final result = await _nostrService.broadcastEvent(event);
        if (result.successCount > 0) {
          // Update local set with Nostr event ID
          final setIndex = _bookmarkSets.indexWhere((s) => s.id == set.id);
          if (setIndex != -1) {
            _bookmarkSets[setIndex] = set.copyWith(nostrEventId: event.id);
            await _saveBookmarks();
          }
          Log.debug(
              'Published bookmark set to Nostr: ${set.name} (${event.id})',
              name: 'BookmarkService',
              category: LogCategory.system);
        }
      }
    } catch (e) {
      Log.error('Failed to publish bookmark set to Nostr: $e',
          name: 'BookmarkService', category: LogCategory.system);
    }
  }

  // === NOSTR LOADING ===

  /// Load bookmarks from embedded relay (authoritative)
  Future<void> _loadBookmarksFromNostr() async {
    try {
      // Get all our published events using the universal query
      final myEvents = await getMyPublishedEvents();

      // Filter for bookmark-related events
      final bookmarkEvents = filterMyEventsByKind(myEvents, [10003, 30003]);

      if (bookmarkEvents.isEmpty) {
        Log.debug('No bookmark events found in embedded relay',
            name: 'BookmarkService', category: LogCategory.system);
        return;
      }

      // Process global bookmarks (kind 10003) - latest replaces previous
      final globalBookmarkEvents =
          bookmarkEvents.where((e) => e.kind == 10003).toList();
      if (globalBookmarkEvents.isNotEmpty) {
        // Sort by created_at to get the latest
        globalBookmarkEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _parseGlobalBookmarksFromEvent(globalBookmarkEvents.first);
        Log.debug(
            'Loaded global bookmarks from Nostr event: ${globalBookmarkEvents.first.id}',
            name: 'BookmarkService',
            category: LogCategory.system);
      }

      // Process bookmark sets (kind 30003) - latest per d-tag
      final bookmarkSetEvents = filterMyParameterizedEvents(myEvents, [30003]);
      for (final event in bookmarkSetEvents.values) {
        _parseBookmarkSetFromEvent(event);
      }

      Log.info(
          'Loaded ${_globalBookmarks.length} global bookmarks and ${_bookmarkSets.length} bookmark sets from embedded relay',
          name: 'BookmarkService',
          category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to load bookmarks from embedded relay: $e',
          name: 'BookmarkService', category: LogCategory.system);
    }
  }

  /// Parse global bookmarks from NIP-51 kind 10003 event
  void _parseGlobalBookmarksFromEvent(Event event) {
    _globalBookmarks.clear();

    for (final tag in event.tags) {
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0])) {
        final item = BookmarkItem(
          type: tag[0],
          id: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
          petname: tag.length > 3 ? tag[3] : null,
        );
        _globalBookmarks.add(item);
      }
    }
  }

  /// Parse bookmark set from NIP-51 kind 30003 event
  void _parseBookmarkSetFromEvent(Event event) {
    // Extract d-tag (identifier)
    String? dTag;
    String? title;
    String? description;
    String? imageUrl;

    for (final tag in event.tags) {
      if (tag.length >= 2) {
        switch (tag[0]) {
          case 'd':
            dTag = tag[1];
            break;
          case 'title':
            title = tag[1];
            break;
          case 'description':
            description = tag[1];
            break;
          case 'image':
            imageUrl = tag[1];
            break;
        }
      }
    }

    if (dTag == null) {
      Log.warning('Bookmark set event missing d-tag: ${event.id}',
          name: 'BookmarkService', category: LogCategory.system);
      return;
    }

    // Parse bookmark items from tags
    final items = <BookmarkItem>[];
    for (final tag in event.tags) {
      if (tag.length >= 2 && ['e', 'a', 't', 'r'].contains(tag[0])) {
        final item = BookmarkItem(
          type: tag[0],
          id: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
          petname: tag.length > 3 ? tag[3] : null,
        );
        items.add(item);
      }
    }

    final bookmarkSet = BookmarkSet(
      id: dTag,
      name: title ?? dTag,
      description: description,
      imageUrl: imageUrl,
      items: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      nostrEventId: event.id,
    );

    // Remove existing set with same ID and add updated one
    _bookmarkSets.removeWhere((set) => set.id == dTag);
    _bookmarkSets.add(bookmarkSet);
  }

  // === STORAGE ===

  /// Load bookmarks from SharedPreferences cache (fast startup)
  void _loadBookmarksFromSharedPreferences() {
    // Load global bookmarks
    final globalBookmarksJson = _prefs.getString(globalBookmarksStorageKey);
    if (globalBookmarksJson != null) {
      try {
        final List<dynamic> bookmarksData = jsonDecode(globalBookmarksJson);
        _globalBookmarks.clear();
        _globalBookmarks.addAll(
          bookmarksData.map(
              (json) => BookmarkItem.fromJson(json as Map<String, dynamic>)),
        );
        Log.debug(
            'Loaded ${_globalBookmarks.length} global bookmarks from storage',
            name: 'BookmarkService',
            category: LogCategory.system);
      } catch (e) {
        Log.error('Failed to load global bookmarks: $e',
            name: 'BookmarkService', category: LogCategory.system);
      }
    }

    // Load bookmark sets
    final bookmarkSetsJson = _prefs.getString(bookmarkSetsStorageKey);
    if (bookmarkSetsJson != null) {
      try {
        final List<dynamic> setsData = jsonDecode(bookmarkSetsJson);
        _bookmarkSets.clear();
        _bookmarkSets.addAll(
          setsData.map(
              (json) => BookmarkSet.fromJson(json as Map<String, dynamic>)),
        );
        Log.debug('Loaded ${_bookmarkSets.length} bookmark sets from storage',
            name: 'BookmarkService', category: LogCategory.system);
      } catch (e) {
        Log.error('Failed to load bookmark sets: $e',
            name: 'BookmarkService', category: LogCategory.system);
      }
    }
  }

  /// Get all bookmark sets that contain a specific video
  List<BookmarkSet> getBookmarkSetsContainingVideo(String videoEventId) {
    return _bookmarkSets
        .where((set) => set.items
            .any((item) => item.type == 'e' && item.id == videoEventId))
        .toList();
  }

  /// Get readable summary of bookmark status for a video
  String getVideoBookmarkSummary(String videoEventId) {
    final isInGlobal = isVideoBookmarkedGlobally(videoEventId);
    final bookmarkSets = getBookmarkSetsContainingVideo(videoEventId);

    if (!isInGlobal && bookmarkSets.isEmpty) {
      return 'Not bookmarked';
    }

    final parts = <String>[];
    if (isInGlobal) {
      parts.add('Bookmarked');
    }

    if (bookmarkSets.isNotEmpty) {
      if (bookmarkSets.length == 1) {
        parts.add('in "${bookmarkSets.first.name}"');
      } else {
        parts.add('in ${bookmarkSets.length} bookmark sets');
      }
    }

    return parts.join(' ');
  }

  /// Save bookmarks to SharedPreferences cache
  Future<void> _saveBookmarksToSharedPreferences() async {
    try {
      // Save global bookmarks
      final globalBookmarksJson =
          _globalBookmarks.map((item) => item.toJson()).toList();
      await _prefs.setString(
          globalBookmarksStorageKey, jsonEncode(globalBookmarksJson));

      // Save bookmark sets
      final bookmarkSetsJson =
          _bookmarkSets.map((set) => set.toJson()).toList();
      await _prefs.setString(
          bookmarkSetsStorageKey, jsonEncode(bookmarkSetsJson));
    } catch (e) {
      Log.error('Failed to save bookmarks to SharedPreferences: $e',
          name: 'BookmarkService', category: LogCategory.system);
    }
  }

  /// Save bookmarks to local storage (backwards compatibility)
  Future<void> _saveBookmarks() async {
    await _saveBookmarksToSharedPreferences();
  }
}
