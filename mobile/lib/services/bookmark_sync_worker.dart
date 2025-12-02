// ABOUTME: Background sync worker for NIP-51 bookmark sets
// ABOUTME: Handles retry logic, connectivity awareness, and conflict resolution for bookmark publishing

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background sync worker for bookmark sets
class BookmarkSyncWorker {
  BookmarkSyncWorker({
    required BookmarkService bookmarkService,
    required ConnectionStatusService connectionStatusService,
    required SharedPreferences prefs,
  }) : _bookmarkService = bookmarkService,
       _connectionStatusService = connectionStatusService,
       _prefs = prefs {
    _initializeSync();
  }

  final BookmarkService _bookmarkService;
  final ConnectionStatusService _connectionStatusService;
  final SharedPreferences _prefs;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  static const String _publishedHashesKey = 'bookmark_published_hashes';
  static const String _pendingChangesKey = 'bookmark_pending_changes';

  /// Map of bookmark set ID -> last published content hash
  final Map<String, String> _publishedHashes = {};

  /// Set of bookmark set IDs that need publishing
  final Set<String> _pendingChanges = {};

  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Initialize background sync
  void _initializeSync() {
    if (_isInitialized) return;

    // Load published hashes from storage
    final hashesJson = _prefs.getString(_publishedHashesKey);
    if (hashesJson != null) {
      try {
        final Map<String, dynamic> hashesData = jsonDecode(hashesJson);
        _publishedHashes.addAll(hashesData.cast<String, String>());
      } catch (e) {
        Log.error(
          'Failed to load published hashes: $e',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
      }
    }

    // Load pending changes from storage
    final pendingJson = _prefs.getString(_pendingChangesKey);
    if (pendingJson != null) {
      try {
        final List<dynamic> pendingData = jsonDecode(pendingJson);
        _pendingChanges.addAll(pendingData.cast<String>());
      } catch (e) {
        Log.error(
          'Failed to load pending changes: $e',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
      }
    }

    // Listen to connectivity changes
    _connectivitySubscription = _connectionStatusService.statusStream.listen((
      isOnline,
    ) {
      if (isOnline && _pendingChanges.isNotEmpty) {
        Log.info(
          'Connection restored, syncing pending bookmark changes',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
        syncSets();
      }
    });

    // Periodic sync every 5 minutes (in case of missed events)
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncSets(),
    );

    _isInitialized = true;

    // Initial sync on startup
    Future.delayed(const Duration(seconds: 2), () => syncSets());
  }

  /// Sync all bookmark sets that have local changes
  Future<void> syncSets() async {
    if (_isSyncing || !_connectionStatusService.isOnline) {
      Log.debug(
        'Skipping sync - ${_isSyncing ? "already syncing" : "offline"}',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );
      return;
    }

    _isSyncing = true;

    try {
      final sets = _bookmarkService.bookmarkSets;
      final changedSets = <BookmarkSet>[];

      // Find sets that have changed since last publish
      for (final set in sets) {
        final currentHash = _computeSetHash(set);
        final publishedHash = _publishedHashes[set.id];

        if (publishedHash != currentHash || _pendingChanges.contains(set.id)) {
          changedSets.add(set);
        }
      }

      if (changedSets.isEmpty) {
        Log.debug(
          'No bookmark sets need syncing',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
        _isSyncing = false;
        return;
      }

      Log.info(
        'Syncing ${changedSets.length} bookmark sets to Nostr',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );

      int successCount = 0;
      int failureCount = 0;

      for (final set in changedSets) {
        final success = await _publishSet(set);
        if (success) {
          successCount++;
          _pendingChanges.remove(set.id);
          _publishedHashes[set.id] = _computeSetHash(set);
        } else {
          failureCount++;
          _pendingChanges.add(set.id);
        }
      }

      // Save state to persistent storage
      await _saveState();

      Log.info(
        'Bookmark sync complete: $successCount succeeded, $failureCount failed',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Bookmark sync failed: $e',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Mark a bookmark set as needing sync (called after local modifications)
  void markDirty(String setId) {
    _pendingChanges.add(setId);
    _saveState();

    // Attempt immediate publish if online
    if (_connectionStatusService.isOnline) {
      syncSets();
    }
  }

  /// Publish a single bookmark set to Nostr
  Future<bool> _publishSet(BookmarkSet set) async {
    try {
      // Use BookmarkService's public publish method
      final success = await _bookmarkService.publishBookmarkSetToNostr(set.id);

      if (success) {
        Log.debug(
          'Successfully published bookmark set: ${set.name}',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
        return true;
      } else {
        Log.warning(
          'Failed to publish bookmark set: ${set.name}',
          name: 'BookmarkSyncWorker',
          category: LogCategory.system,
        );
        return false;
      }
    } catch (e) {
      Log.error(
        'Error publishing bookmark set ${set.name}: $e',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Compute content hash for a bookmark set to detect changes
  String _computeSetHash(BookmarkSet set) {
    // Include all mutable fields that affect the Nostr event
    final content = {
      'id': set.id,
      'name': set.name,
      'description': set.description ?? '',
      'imageUrl': set.imageUrl ?? '',
      'items': set.items
          .map(
            (item) => {
              'type': item.type,
              'id': item.id,
              'relay': item.relay ?? '',
              'petname': item.petname ?? '',
            },
          )
          .toList(),
    };

    final jsonStr = jsonEncode(content);
    final bytes = utf8.encode(jsonStr);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save sync state to persistent storage
  Future<void> _saveState() async {
    try {
      // Save published hashes
      await _prefs.setString(_publishedHashesKey, jsonEncode(_publishedHashes));

      // Save pending changes
      await _prefs.setString(
        _pendingChangesKey,
        jsonEncode(_pendingChanges.toList()),
      );
    } catch (e) {
      Log.error(
        'Failed to save sync state: $e',
        name: 'BookmarkSyncWorker',
        category: LogCategory.system,
      );
    }
  }

  /// Get sync status for debugging
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _connectionStatusService.isOnline,
      'isSyncing': _isSyncing,
      'pendingChangesCount': _pendingChanges.length,
      'publishedSetsCount': _publishedHashes.length,
      'pendingSetIds': _pendingChanges.toList(),
    };
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
