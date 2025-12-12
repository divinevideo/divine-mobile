// ABOUTME: Content blocklist service for filtering unwanted content from feeds
// ABOUTME: Maintains internal blocklist while allowing explicit profile visits

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for managing content blocklist
///
/// This service maintains an internal blocklist of npubs whose content
/// should be filtered from all general feeds (home, explore, hashtag feeds).
/// Users can still explicitly visit blocked profiles if they choose to follow them.
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentBlocklistService {
  ContentBlocklistService() {
    // Initialize with the specific npub requested
    _addInitialBlockedContent();
    Log.info(
      'ContentBlocklistService initialized with $totalBlockedCount blocked accounts',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );
  }

  // Internal blocklist of public keys (hex format) - kept empty for now
  static const Set<String> _internalBlocklist = {
    // Add blocked public keys here in hex format if needed
  };

  // Runtime blocklist (can be modified)
  final Set<String> _runtimeBlocklist = <String>{};

  // Mutual mute blocklist (populated from kind 10000 events)
  final Set<String> _mutualMuteBlocklist = <String>{};

  // Subscription tracking for mutual mutes
  String? _mutualMuteSubscriptionId;
  bool _mutualMuteSyncStarted = false;
  String? _ourPubkey;

  void _addInitialBlockedContent() {
    // Add the specific npubs requested by user
    final targetNpubs = [
      'npub1w3z04t3z6n2f88yptqvaeg7ysgkzp96ch7r2l3nrvhd4770k0hds43lfey',
      'npub19hml4ddt36mh2u435epzrd5q2m80hnx3d73hp5e6t7l2mc77he0s4m6pur',
      'npub1t9pu3reuvrxeakcjtfngu2g344qelszwj32fakt2wgvsrhv4sdeqe6jz4j',
    ];

    for (final npub in targetNpubs) {
      final hexPubkey = _npubToHex(npub);
      if (hexPubkey != null) {
        _runtimeBlocklist.add(hexPubkey);
        Log.debug(
          'Added to blocklist: ${npub.substring(0, 16)}... -> ${hexPubkey}...',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Convert any public identifier (npub/nprofile/hex) to hex format
  String? _npubToHex(String identifier) {
    // Use universal normalizer to handle npub, nprofile, and hex formats
    return normalizeToHex(identifier);
  }

  /// Check if a public key is blocked
  bool isBlocked(String pubkey) {
    // Check both internal and runtime blocklists
    return _internalBlocklist.contains(pubkey) ||
        _runtimeBlocklist.contains(pubkey);
  }

  /// Check if content should be filtered from feeds
  bool shouldFilterFromFeeds(String pubkey) {
    return _internalBlocklist.contains(pubkey) ||
        _runtimeBlocklist.contains(pubkey) ||
        _mutualMuteBlocklist.contains(pubkey);
  }

  /// Add a public key to the runtime blocklist
  void blockUser(String pubkey) {
    if (!_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.add(pubkey);

      Log.debug(
        'Added user to blocklist: ${pubkey}...',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Remove a public key from the runtime blocklist
  /// Note: Cannot remove users from internal blocklist
  void unblockUser(String pubkey) {
    if (_runtimeBlocklist.contains(pubkey)) {
      _runtimeBlocklist.remove(pubkey);

      Log.info(
        'Removed user from blocklist: ${pubkey}...',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } else if (_internalBlocklist.contains(pubkey)) {
      Log.warning(
        'Cannot unblock user from internal blocklist: ${pubkey}...',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Get all blocked public keys (for debugging)
  Set<String> get blockedPubkeys => {
    ..._internalBlocklist,
    ..._runtimeBlocklist,
  };

  /// Get count of blocked accounts
  int get totalBlockedCount =>
      _internalBlocklist.length + _runtimeBlocklist.length;

  /// Filter a list of content by removing blocked authors
  List<T> filterContent<T>(List<T> content, String Function(T) getPubkey) =>
      content.where((item) => !shouldFilterFromFeeds(getPubkey(item))).toList();

  /// Check if user is in internal (permanent) blocklist
  bool isInternallyBlocked(String pubkey) =>
      _internalBlocklist.contains(pubkey);

  /// Get runtime blocked users (can be modified)
  Set<String> get runtimeBlockedUsers => Set.unmodifiable(_runtimeBlocklist);

  /// Clear all runtime blocks (keeps internal blocks)
  void clearRuntimeBlocks() {
    if (_runtimeBlocklist.isNotEmpty) {
      _runtimeBlocklist.clear();

      Log.debug(
        '🧹 Cleared all runtime blocks',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Get stats about blocking
  Map<String, dynamic> get blockingStats => {
    'internal_blocks': _internalBlocklist.length,
    'runtime_blocks': _runtimeBlocklist.length,
    'total_blocks': totalBlockedCount,
  };

  /// Start background sync of mutual mute lists (NIP-51 kind 10000)
  /// Subscribes to kind 10000 events WHERE our pubkey appears in 'p' tags
  Future<void> syncMuteListsInBackground(
    NostrClient nostrService,
    String ourPubkey,
  ) async {
    if (_mutualMuteSyncStarted) {
      Log.debug(
        'Mutual mute sync already started, skipping',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    _mutualMuteSyncStarted = true;
    _ourPubkey = ourPubkey;

    Log.info(
      'Starting mutual mute list sync for pubkey: $ourPubkey',
      name: 'ContentBlocklistService',
      category: LogCategory.system,
    );

    try {
      // Subscribe to kind 10000 (mute list) events WHERE our pubkey is in 'p' tags
      final filter = Filter(kinds: const [10000]);
      filter.p = [ourPubkey]; // Filter by 'p' tags containing our pubkey

      final subscription = nostrService.subscribe([filter]);

      _mutualMuteSubscriptionId =
          'mutual-mute-${DateTime.now().millisecondsSinceEpoch}';

      // Listen to the stream
      subscription.listen(_handleMuteListEvent);

      Log.info(
        'Mutual mute subscription created: $_mutualMuteSubscriptionId',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to start mutual mute sync: $e',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
    }
  }

  /// Handle incoming kind 10000 mute list events
  /// Adds/removes muter based on whether our pubkey is in their 'p' tags
  void _handleMuteListEvent(Event event) {
    if (event.kind != 10000) {
      Log.warning(
        'Received non-10000 event in mute list handler: ${event.kind}',
        name: 'ContentBlocklistService',
        category: LogCategory.system,
      );
      return;
    }

    final muterPubkey = event.pubkey;

    // Check if our pubkey is in this user's mute list
    final stillMuted = event.tags.any(
      (tag) =>
          tag.isNotEmpty &&
          tag[0] == 'p' &&
          tag.length >= 2 &&
          tag[1] == _ourPubkey,
    );

    if (stillMuted) {
      // They muted us - add to blocklist
      if (!_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.add(muterPubkey);
        Log.info(
          'Added mutual mute: $muterPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    } else {
      // They removed us from mute list - remove from blocklist
      if (_mutualMuteBlocklist.contains(muterPubkey)) {
        _mutualMuteBlocklist.remove(muterPubkey);
        Log.info(
          'Removed mutual mute (unmuted): $muterPubkey',
          name: 'ContentBlocklistService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Dispose resources (cancel subscriptions)
  void dispose() {
    // Subscription cleanup would go here if NostrService had unsubscribe method
    _mutualMuteSyncStarted = false;
    _mutualMuteSubscriptionId = null;
  }
}
