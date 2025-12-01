// ABOUTME: Social interaction service managing likes, follows, comments and reposts
// ABOUTME: Handles NIP-25 reactions, NIP-02 contact lists, and other social Nostr events

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_event.dart';

/// Represents a follow set (NIP-51 Kind 30000)
class FollowSet {
  const FollowSet({
    required this.id,
    required this.name,
    required this.pubkeys,
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
  final List<String> pubkeys;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nostrEventId;

  FollowSet copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    List<String>? pubkeys,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nostrEventId,
  }) =>
      FollowSet(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        pubkeys: pubkeys ?? this.pubkeys,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        nostrEventId: nostrEventId ?? this.nostrEventId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'pubkeys': pubkeys,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nostrEventId': nostrEventId,
      };

  static FollowSet fromJson(Map<String, dynamic> json) => FollowSet(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        imageUrl: json['imageUrl'],
        pubkeys: List<String>.from(json['pubkeys'] ?? []),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        nostrEventId: json['nostrEventId'],
      );
}

/// Service for managing social interactions on Nostr
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class SocialService {
  SocialService(this._nostrService, this._authService,
      {required SubscriptionManager subscriptionManager,
      PersonalEventCacheService? personalEventCache})
      : _subscriptionManager = subscriptionManager,
        _personalEventCache = personalEventCache {
    _initialize();
  }
  final INostrService _nostrService;
  final AuthService _authService;
  final SubscriptionManager _subscriptionManager;
  final PersonalEventCacheService? _personalEventCache;

  // Cache for UI state - liked events by current user
  final Set<String> _likedEventIds = <String>{};

  // Cache for like counts to avoid redundant network requests
  final Map<String, int> _likeCounts = <String, int>{};

  // Cache mapping liked event IDs to their reaction event IDs (needed for deletion)
  final Map<String, String> _likeEventIdToReactionId = <String, String>{};

  // Cache for UI state - reposted events by current user
  final Set<String> _repostedEventIds = <String>{};

  // Cache mapping reposted event IDs to their repost event IDs (needed for deletion)
  final Map<String, String> _repostEventIdToRepostId = <String, String>{};

  // Cache for following list (NIP-02 contact list)
  List<String> _followingPubkeys = <String>[];

  // Cache for follower/following counts
  final Map<String, Map<String, int>> _followerStats =
      <String, Map<String, int>>{};

  // Cache for follow sets (NIP-51 Kind 30000)
  final List<FollowSet> _followSets = <FollowSet>[];

  // Current user's latest Kind 3 event for follow list management
  Event? _currentUserContactListEvent;

  // Managed subscription IDs
  String? _likeSubscriptionId;
  String? _followSubscriptionId;
  String? _repostSubscriptionId;
  String? _userLikesSubscriptionId;
  String? _userRepostsSubscriptionId;

  /// Initialize the service
  Future<void> _initialize() async {
    Log.debug('🤝 Initializing SocialService',
        name: 'SocialService', category: LogCategory.system);

    try {
      // Initialize current user's social data if authenticated
      if (_authService.isAuthenticated) {
        // Load cached following list first for immediate UI display
        await _loadFollowingListFromCache();

        // Load cached personal events for instant access
        await _loadCachedPersonalEvents();

        await _loadUserLikedEvents();
        await _loadUserRepostedEvents();
        await fetchCurrentUserFollowList();
      }

      Log.info('SocialService initialized',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('SocialService initialization error: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Load cached personal events for instant access on startup
  Future<void> _loadCachedPersonalEvents() async {
    if (_personalEventCache?.isInitialized != true) {
      Log.debug(
          'PersonalEventCache not initialized, skipping cached event loading',
          name: 'SocialService',
          category: LogCategory.system);
      return;
    }

    try {
      // Load cached likes (Kind 7 events) to populate _likedEventIds
      final cachedLikes = _personalEventCache!.getEventsByKind(7);
      for (final likeEvent in cachedLikes) {
        final eTags =
            likeEvent.tags.where((tag) => tag.isNotEmpty && tag[0] == 'e');
        for (final eTag in eTags) {
          if (eTag.length > 1) {
            final likedEventId = eTag[1];
            _likedEventIds.add(likedEventId);
            _likeEventIdToReactionId[likedEventId] = likeEvent.id;
          }
        }
      }

      // Load cached reposts (Kind 6 events) to populate _repostedEventIds
      final cachedReposts = _personalEventCache.getEventsByKind(6);
      for (final repostEvent in cachedReposts) {
        _processRepostEvent(repostEvent);
      }

      // Load cached contact lists (Kind 3 events) to populate following data
      final cachedContactLists = _personalEventCache.getEventsByKind(3);
      if (cachedContactLists.isNotEmpty) {
        // Use the most recent contact list event
        final latestContactList =
            cachedContactLists.first; // Already sorted by creation time
        final pTags = latestContactList.tags
            .where((tag) => tag.isNotEmpty && tag[0] == 'p');
        final pubkeys = pTags
            .map((tag) => tag.length > 1 ? tag[1] : '')
            .where((pubkey) => pubkey.isNotEmpty)
            .cast<String>()
            .toList();

        if (pubkeys.isNotEmpty) {
          _followingPubkeys = pubkeys;
          _currentUserContactListEvent = latestContactList;

          // Save to SharedPreferences cache as well
          await _saveFollowingListToCache();
        }
      }

      final stats = _personalEventCache.getCacheStats();
      Log.info('📋 Loaded cached personal events on startup:',
          name: 'SocialService', category: LogCategory.system);
      Log.info('  - Total events: ${stats['total_events']}',
          name: 'SocialService', category: LogCategory.system);
      Log.info('  - Likes loaded: ${cachedLikes.length}',
          name: 'SocialService', category: LogCategory.system);
      Log.info('  - Reposts loaded: ${cachedReposts.length}',
          name: 'SocialService', category: LogCategory.system);
      Log.info('  - Contact lists loaded: ${cachedContactLists.length}',
          name: 'SocialService', category: LogCategory.system);
      Log.info('  - Following count: ${_followingPubkeys.length}',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to load cached personal events: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Get current user's liked event IDs
  Set<String> get likedEventIds => Set.from(_likedEventIds);

  /// Check if current user has liked an event
  bool isLiked(String eventId) => _likedEventIds.contains(eventId);

  /// Check if current user has reposted an event
  /// Checks using the addressable ID format for Kind 32222 events
  bool hasReposted(String eventId, {String? pubkey, String? dTag}) {
    // For addressable events, check using addressable ID format
    if (pubkey != null && dTag != null) {
      final addressableId = '32222:$pubkey:$dTag';
      return _repostedEventIds.contains(addressableId);
    }

    // Fallback to event ID for backward compatibility
    return _repostedEventIds.contains(eventId);
  }

  /// Get cached like count for an event
  int? getCachedLikeCount(String eventId) => _likeCounts[eventId];

  // === FOLLOW SYSTEM GETTERS ===

  /// Get current user's following list
  List<String> get followingPubkeys => List.from(_followingPubkeys);

  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) => _followingPubkeys.contains(pubkey);

  /// Get cached follower stats for a pubkey
  Map<String, int>? getCachedFollowerStats(String pubkey) =>
      _followerStats[pubkey];

  // === FOLLOW SETS GETTERS ===

  /// Get all follow sets
  List<FollowSet> get followSets => List.unmodifiable(_followSets);

  /// Get follow set by ID
  FollowSet? getFollowSetById(String setId) {
    try {
      return _followSets.firstWhere((set) => set.id == setId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a pubkey is in a specific follow set
  bool isInFollowSet(String setId, String pubkey) {
    final set = getFollowSetById(setId);
    return set?.pubkeys.contains(pubkey) ?? false;
  }

  /// Likes or unlikes a Nostr event using proper NIP-09 deletion
  Future<void> toggleLike(String eventId, String authorPubkey) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot like - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      return;
    }

    Log.debug('❤️ Toggling like for event: $eventId',
        name: 'SocialService', category: LogCategory.system);

    try {
      final wasLiked = _likedEventIds.contains(eventId);

      if (!wasLiked) {
        // Add like
        final reactionEventId = await _publishLike(eventId, authorPubkey);

        if (reactionEventId != null) {
          // Update local state immediately for UI responsiveness
          _likedEventIds.add(eventId);
          _likeEventIdToReactionId[eventId] = reactionEventId;

          // Increment like count in cache
          final currentCount = _likeCounts[eventId] ?? 0;
          _likeCounts[eventId] = currentCount + 1;

          Log.info('Like published for event: $eventId',
              name: 'SocialService', category: LogCategory.system);
        }
      } else {
        // Unlike by publishing NIP-09 deletion event
        final reactionEventId = _likeEventIdToReactionId[eventId];
        if (reactionEventId != null) {
          await _publishUnlike(reactionEventId);

          // Update local state
          _likedEventIds.remove(eventId);
          _likeEventIdToReactionId.remove(eventId);

          // Decrement like count in cache
          final currentCount = _likeCounts[eventId] ?? 0;
          if (currentCount > 0) {
            _likeCounts[eventId] = currentCount - 1;
          }

          Log.info(
              'Unlike (deletion) published for event: $eventId',
              name: 'SocialService',
              category: LogCategory.system);
        } else {
          Log.warning('Cannot unlike - reaction event ID not found',
              name: 'SocialService', category: LogCategory.system);

          // Fallback: remove from local state only
          _likedEventIds.remove(eventId);
          final currentCount = _likeCounts[eventId] ?? 0;
          if (currentCount > 0) {
            _likeCounts[eventId] = currentCount - 1;
          }
        }
      }
    } catch (e) {
      Log.error('Error toggling like: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Publishes a NIP-25 reaction event (like) and returns the reaction event ID
  Future<String?> _publishLike(String eventId, String authorPubkey) async {
    try {
      // Create NIP-25 reaction event (Kind 7)
      final event = await _authService.createAndSignEvent(
        kind: 7,
        content: '+', // Standard like reaction
        tags: [
          ['e', eventId], // Reference to liked event
          ['p', authorPubkey], // Reference to liked event author
        ],
      );

      if (event == null) {
        throw Exception('Failed to create like event');
      }

      // Cache the event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast the like event
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast like event: $errorMessages');
      }

      Log.debug('Like event broadcasted: ${event.id}',
          name: 'SocialService', category: LogCategory.system);
      return event.id;
    } catch (e) {
      Log.error('Error publishing like: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Publishes a NIP-09 deletion event for unlike functionality
  Future<void> _publishUnlike(String reactionEventId) async {
    try {
      // Create NIP-09 deletion event (Kind 5)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content: 'Unliked', // Optional deletion reason
        tags: [
          ['e', reactionEventId], // Reference to the reaction event to delete
        ],
      );

      if (event == null) {
        throw Exception('Failed to create deletion event');
      }

      // Cache the deletion event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast the deletion event
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast deletion event: $errorMessages');
      }

      Log.debug('Deletion event broadcasted: ${event.id}',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('Error publishing deletion: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Fetches like count and determines if current user has liked an event
  /// Returns {'count': int, 'user_liked': bool}
  Future<Map<String, dynamic>> getLikeStatus(String eventId) async {
    Log.debug('Fetching like status for event: $eventId',
        name: 'SocialService', category: LogCategory.system);

    try {
      // Check cache first
      final cachedCount = _likeCounts[eventId];
      final userLiked = _likedEventIds.contains(eventId);

      if (cachedCount != null) {
        Log.debug('📱 Using cached like count: $cachedCount',
            name: 'SocialService', category: LogCategory.system);
        return {
          'count': cachedCount,
          'user_liked': userLiked,
        };
      }

      // Fetch from network
      final likeCount = await _fetchLikeCount(eventId);

      // Cache the result
      _likeCounts[eventId] = likeCount;

      Log.debug('Like count fetched: $likeCount',
          name: 'SocialService', category: LogCategory.system);

      return {
        'count': likeCount,
        'user_liked': userLiked,
      };
    } catch (e) {
      Log.error('Error fetching like status: $e',
          name: 'SocialService', category: LogCategory.system);
      return {
        'count': 0,
        'user_liked': false,
      };
    }
  }

  /// Fetches like count for a specific event
  Future<int> _fetchLikeCount(String eventId) async {
    try {
      final completer = Completer<int>();
      var likeCount = 0;

      // Subscribe to Kind 7 reactions for this event using SubscriptionManager
      await _subscriptionManager.createSubscription(
        name: 'like_count_$eventId',
        filters: [
          Filter(
            kinds: [7],
            e: [eventId],
          ),
        ],
        onEvent: (event) {
          // Only count '+' reactions as likes
          if (event.content.trim() == '+') {
            likeCount++;
          }
        },
        onError: (error) {
          Log.error('Error in like count subscription: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete(likeCount);
          }
        },
        timeout: const Duration(seconds: 5),
        priority: 4, // Lower priority for count queries
      );

      return await completer.future;
    } catch (e) {
      Log.error('Error fetching like count: $e',
          name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }

  /// Loads current user's liked events from their reaction history
  Future<void> _loadUserLikedEvents() async {
    if (!_authService.isAuthenticated) return;

    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;

      Log.debug(
          'Loading user liked events for: $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system);

      // Subscribe to current user's reactions (Kind 7) using SubscriptionManager
      _userLikesSubscriptionId = await _subscriptionManager.createSubscription(
        name: 'user_likes_$currentUserPubkey',
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [7],
          ),
        ],
        onEvent: (event) {
          // Only process '+' reactions as likes
          if (event.content.trim() == '+') {
            // Extract the liked event ID from 'e' tags
            for (final tag in event.tags) {
              if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
                final likedEventId = tag[1];
                _likedEventIds.add(likedEventId);
                // Store the reaction event ID for future deletion
                _likeEventIdToReactionId[likedEventId] = event.id;
                Log.debug(
                    '📱 Cached user like: $likedEventId (reaction: ${event.id})',
                    name: 'SocialService',
                    category: LogCategory.system);
                break;
              }
            }
          }
        },
        onError: (error) => Log.error('Error loading user likes: $error',
            name: 'SocialService', category: LogCategory.system),
        priority: 3, // Lower priority for historical data
      );
    } catch (e) {
      Log.error('Error loading user liked events: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Loads current user's reposted events from their repost history
  Future<void> _loadUserRepostedEvents() async {
    if (!_authService.isAuthenticated) return;

    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;

      Log.debug(
          'Loading user reposted events for: $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system);

      // Subscribe to current user's reposts (Kind 6) using SubscriptionManager
      _userRepostsSubscriptionId =
          await _subscriptionManager.createSubscription(
        name: 'user_reposts_$currentUserPubkey',
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [16], // Generic repost (NIP-18) for video events
          ),
        ],
        onEvent: (event) {
          _processRepostEvent(event);
        },
        onError: (error) => Log.error('Error loading user reposts: $error',
            name: 'SocialService', category: LogCategory.system),
        priority: 3, // Lower priority for historical data
      );
    } catch (e) {
      Log.error('Error loading user reposted events: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Fetches all events liked by a specific user
  Future<List<Event>> fetchLikedEvents(String pubkey) async {
    Log.debug('Fetching liked events for user: $pubkey',
        name: 'SocialService', category: LogCategory.system);

    try {
      final likedEvents = <Event>[];
      final likedEventIds = <String>{};

      // First, get all reactions by this user
      final reactionSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [7], // NIP-25 reactions
          ),
        ],
      );

      final completer = Completer<List<Event>>();

      // Collect liked event IDs
      reactionSubscription.listen(
        (reactionEvent) {
          if (reactionEvent.content.trim() == '+') {
            // Extract liked event ID from 'e' tag
            for (final tag in reactionEvent.tags) {
              if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
                likedEventIds.add(tag[1]);
                break;
              }
            }
          }
        },
        onError: (error) {
          Log.error('Error fetching liked events: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onDone: () async {
          // Now fetch the actual liked events
          if (likedEventIds.isNotEmpty) {
            try {
              final eventSubscription = _nostrService.subscribeToEvents(
                filters: [
                  Filter(
                    ids: likedEventIds.toList(),
                  ),
                ],
              );

              eventSubscription.listen(
                likedEvents.add,
                onError: (error) {
                  Log.error('Error fetching liked event details: $error',
                      name: 'SocialService', category: LogCategory.system);
                  if (!completer.isCompleted) {
                    completer.complete(likedEvents);
                  }
                },
                onDone: () {
                  if (!completer.isCompleted) {
                    completer.complete(likedEvents);
                  }
                },
              );
            } catch (e) {
              Log.error('Error fetching liked event details: $e',
                  name: 'SocialService', category: LogCategory.system);
              if (!completer.isCompleted) {
                completer.complete([]);
              }
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete([]);
            }
          }
        },
      );

      final result = await completer.future;
      Log.info('Fetched ${result.length} liked events',
          name: 'SocialService', category: LogCategory.system);
      return result;
    } catch (e) {
      Log.error('Error fetching liked events: $e',
          name: 'SocialService', category: LogCategory.system);
      return [];
    }
  }

  // === NIP-02 FOLLOW SYSTEM ===

  /// Fetches current user's follow list from their latest Kind 3 event
  Future<void> fetchCurrentUserFollowList() async {
    if (!_authService.isAuthenticated) return;

    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;

      Log.debug(
          '📱 Loading follow list for: $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system);

      // ✅ Use immediate completion for contact list query
      final eventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [3], // NIP-02 contact list
            limit: 1, // Get most recent only
          ),
        ],
      );

      final contactListEvent =
          await ContactListCompletionHelper.queryContactList(
        eventStream: eventStream,
        pubkey: currentUserPubkey,
        fallbackTimeoutSeconds: 10,
      );

      if (contactListEvent != null) {
        Log.debug(
          '✅ Contact list received immediately for $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
        _processContactListEvent(contactListEvent);
      } else {
        Log.debug(
          '⏰ No contact list found for $currentUserPubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error('Error fetching follow list: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Process a NIP-02 contact list event (Kind 3)
  void _processContactListEvent(Event event) {
    // Only update if this is newer than our current contact list event
    if (_currentUserContactListEvent == null ||
        event.createdAt > _currentUserContactListEvent!.createdAt) {
      _currentUserContactListEvent = event;

      // Extract followed pubkeys from 'p' tags
      final followedPubkeys = <String>[];
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          followedPubkeys.add(tag[1]);
        }
      }

      _followingPubkeys = followedPubkeys;
      Log.info('Updated follow list: ${_followingPubkeys.length} following',
          name: 'SocialService', category: LogCategory.system);

      // Persist following list to local storage for aggressive caching
      _saveFollowingListToCache();
    }
  }

  /// Follow a user by adding them to the contact list
  Future<void> followUser(String pubkeyToFollow) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot follow - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      return;
    }

    if (_followingPubkeys.contains(pubkeyToFollow)) {
      Log.debug(
          'ℹ️ Already following user: $pubkeyToFollow',
          name: 'SocialService',
          category: LogCategory.system);
      return;
    }

    Log.debug('📱 Following user: $pubkeyToFollow',
        name: 'SocialService', category: LogCategory.system);

    // Optimistically update local state for immediate UI feedback
    final previousFollowList = List<String>.from(_followingPubkeys);
    _followingPubkeys = List<String>.from(_followingPubkeys)
      ..add(pubkeyToFollow);

    try {
      // Create new Kind 3 event with updated follow list
      final tags = _followingPubkeys.map((pubkey) => ['p', pubkey]).toList();

      // Preserve existing content from previous contact list event if available
      final content = _currentUserContactListEvent?.content ?? '';

      final event = await _authService.createAndSignEvent(
        kind: 3,
        content: content,
        tags: tags,
      );

      if (event == null) {
        // Revert on failure
        _followingPubkeys = previousFollowList;
        throw Exception('Failed to create contact list event');
      }

      // Cache the contact list event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast the updated contact list
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        // Revert on failure
        _followingPubkeys = previousFollowList;
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast contact list: $errorMessages');
      }

      // Update the event reference
      _currentUserContactListEvent = event;

      // Save to SharedPreferences cache immediately
      _saveFollowingListToCache();

      Log.info(
          'Successfully followed user: $pubkeyToFollow',
          name: 'SocialService',
          category: LogCategory.system);
    } catch (e) {
      Log.error('Error following user: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Unfollow a user by removing them from the contact list
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot unfollow - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      return;
    }

    if (!_followingPubkeys.contains(pubkeyToUnfollow)) {
      Log.debug('ℹ️ Not following user: $pubkeyToUnfollow',
          name: 'SocialService', category: LogCategory.system);
      return;
    }

    Log.debug('📱 Unfollowing user: $pubkeyToUnfollow',
        name: 'SocialService', category: LogCategory.system);

    // Optimistically update local state for immediate UI feedback
    final previousFollowList = List<String>.from(_followingPubkeys);
    _followingPubkeys = List<String>.from(_followingPubkeys)
      ..remove(pubkeyToUnfollow);

    try {
      // Create new Kind 3 event with updated follow list
      final tags = _followingPubkeys.map((pubkey) => ['p', pubkey]).toList();

      // Preserve existing content from previous contact list event if available
      final content = _currentUserContactListEvent?.content ?? '';

      final event = await _authService.createAndSignEvent(
        kind: 3,
        content: content,
        tags: tags,
      );

      if (event == null) {
        // Revert on failure
        _followingPubkeys = previousFollowList;
        throw Exception('Failed to create contact list event');
      }

      // Cache the contact list event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast the updated contact list
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        // Revert on failure
        _followingPubkeys = previousFollowList;
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast contact list: $errorMessages');
      }

      // Update the event reference
      _currentUserContactListEvent = event;

      // Save to SharedPreferences cache immediately
      _saveFollowingListToCache();

      Log.info(
          'Successfully unfollowed user: $pubkeyToUnfollow',
          name: 'SocialService',
          category: LogCategory.system);
    } catch (e) {
      Log.error('Error unfollowing user: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Get follower and following counts for a specific pubkey
  Future<Map<String, int>> getFollowerStats(String pubkey) async {
    Log.debug('Fetching follower stats for: $pubkey',
        name: 'SocialService', category: LogCategory.system);

    try {
      // Check cache first
      final cachedStats = _followerStats[pubkey];
      if (cachedStats != null) {
        Log.debug('📱 Using cached follower stats: $cachedStats',
            name: 'SocialService', category: LogCategory.system);
        return cachedStats;
      }

      // Fetch from network
      final stats = await _fetchFollowerStats(pubkey);

      // Cache the result
      _followerStats[pubkey] = stats;

      Log.debug('Follower stats fetched: $stats',
          name: 'SocialService', category: LogCategory.system);
      return stats;
    } catch (e) {
      Log.error('Error fetching follower stats: $e',
          name: 'SocialService', category: LogCategory.system);
      return {'followers': 0, 'following': 0};
    }
  }

  /// Fetch follower stats from the network
  Future<Map<String, int>> _fetchFollowerStats(String pubkey) async {
    try {
      // ✅ Use immediate completion for both queries
      var followingCount = 0;
      var followersCount = 0;

      // 1. ✅ Get following count with immediate completion
      final followingEventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [3],
            limit: 1,
          ),
        ],
      );

      final followingEvent = await ContactListCompletionHelper.queryContactList(
        eventStream: followingEventStream,
        pubkey: pubkey,
        fallbackTimeoutSeconds: 8,
      );

      if (followingEvent != null) {
        followingCount = followingEvent.tags
            .where((tag) => tag.isNotEmpty && tag[0] == 'p')
            .length;
        Log.debug(
          '✅ Following count received immediately: $followingCount for $pubkey',
          name: 'SocialService',
          category: LogCategory.system,
        );
      }

      // 2. ✅ Get followers count with immediate completion
      final followersEventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [3],
            p: [pubkey], // Events that mention this pubkey in p tags
          ),
        ],
      );

      // Use exhaustive mode to collect all followers
      final config = CompletionConfig(
        mode: CompletionMode.exhaustive,
        fallbackTimeoutSeconds: 8,
        serviceName: 'FollowersQuery',
        logCategory: LogCategory.system,
      );

      final followerPubkeys = <String>{};
      final followersCompleter = Completer<int>();

      ImmediateCompletionHelper.createImmediateSubscription(
        eventStream: followersEventStream,
        config: config,
        onEvent: (event) {
          // Each unique author who has this pubkey in their contact list is a follower
          followerPubkeys.add(event.pubkey);
        },
        onComplete: (result) {
          followersCount = followerPubkeys.length;
          Log.debug(
            '✅ Followers query completed: $followersCount followers for $pubkey',
            name: 'SocialService',
            category: LogCategory.system,
          );
          if (!followersCompleter.isCompleted) {
            followersCompleter.complete(followersCount);
          }
        },
        onError: (error) {
          Log.error('Error fetching followers count: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!followersCompleter.isCompleted) {
            followersCompleter.complete(followerPubkeys.length);
          }
        },
      );

      await followersCompleter.future;

      return {
        'followers': followersCount,
        'following': followingCount,
      };
    } catch (e) {
      Log.error('Error fetching follower stats: $e',
          name: 'SocialService', category: LogCategory.system);
      return {'followers': 0, 'following': 0};
    }
  }

  // === FOLLOW SETS MANAGEMENT (NIP-51 Kind 30000) ===

  /// Create a new follow set
  Future<FollowSet?> createFollowSet({
    required String name,
    String? description,
    String? imageUrl,
    List<String> initialPubkeys = const [],
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error('Cannot create follow set - user not authenticated',
            name: 'SocialService', category: LogCategory.system);
        return null;
      }

      final setId = 'followset_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      final newSet = FollowSet(
        id: setId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        pubkeys: initialPubkeys,
        createdAt: now,
        updatedAt: now,
      );

      _followSets.add(newSet);

      // Publish to Nostr
      await _publishFollowSetToNostr(newSet);

      Log.info('Created new follow set: $name ($setId)',
          name: 'SocialService', category: LogCategory.system);

      return newSet;
    } catch (e) {
      Log.error('Failed to create follow set: $e',
          name: 'SocialService', category: LogCategory.system);
      return null;
    }
  }

  /// Add a pubkey to a follow set
  Future<bool> addToFollowSet(String setId, String pubkey) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning('Follow set not found: $setId',
            name: 'SocialService', category: LogCategory.system);
        return false;
      }

      final set = _followSets[setIndex];

      // Check if pubkey is already in the set
      if (set.pubkeys.contains(pubkey)) {
        Log.debug('Pubkey already in follow set: $pubkey',
            name: 'SocialService', category: LogCategory.system);
        return true;
      }

      final updatedPubkeys = [...set.pubkeys, pubkey];
      final updatedSet = set.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug('➕ Added pubkey to follow set "${set.name}": $pubkey',
          name: 'SocialService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to add to follow set: $e',
          name: 'SocialService', category: LogCategory.system);
      return false;
    }
  }

  /// Remove a pubkey from a follow set
  Future<bool> removeFromFollowSet(String setId, String pubkey) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        Log.warning('Follow set not found: $setId',
            name: 'SocialService', category: LogCategory.system);
        return false;
      }

      final set = _followSets[setIndex];
      final updatedPubkeys = set.pubkeys.where((pk) => pk != pubkey).toList();

      final updatedSet = set.copyWith(
        pubkeys: updatedPubkeys,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug('➖ Removed pubkey from follow set "${set.name}": $pubkey',
          name: 'SocialService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to remove from follow set: $e',
          name: 'SocialService', category: LogCategory.system);
      return false;
    }
  }

  /// Update follow set metadata
  Future<bool> updateFollowSet({
    required String setId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _followSets[setIndex];
      final updatedSet = set.copyWith(
        name: name ?? set.name,
        description: description ?? set.description,
        imageUrl: imageUrl ?? set.imageUrl,
        updatedAt: DateTime.now(),
      );

      _followSets[setIndex] = updatedSet;

      // Update on Nostr
      await _publishFollowSetToNostr(updatedSet);

      Log.debug('✏️ Updated follow set: ${updatedSet.name}',
          name: 'SocialService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to update follow set: $e',
          name: 'SocialService', category: LogCategory.system);
      return false;
    }
  }

  /// Delete a follow set
  Future<bool> deleteFollowSet(String setId) async {
    try {
      final setIndex = _followSets.indexWhere((set) => set.id == setId);
      if (setIndex == -1) {
        return false;
      }

      final set = _followSets[setIndex];

      // For replaceable events (kind 30000), we don't need a deletion event
      // The event is automatically replaced when publishing with the same d-tag

      _followSets.removeAt(setIndex);

      Log.debug('🗑️ Deleted follow set: ${set.name}',
          name: 'SocialService', category: LogCategory.system);

      return true;
    } catch (e) {
      Log.error('Failed to delete follow set: $e',
          name: 'SocialService', category: LogCategory.system);
      return false;
    }
  }

  /// Publish follow set to Nostr as NIP-51 kind 30000 event
  Future<void> _publishFollowSetToNostr(FollowSet set) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning('Cannot publish follow set - user not authenticated',
            name: 'SocialService', category: LogCategory.system);
        return;
      }

      // Create NIP-51 kind 30000 tags
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

      // Add pubkeys as 'p' tags
      for (final pubkey in set.pubkeys) {
        tags.add(['p', pubkey]);
      }

      final content = set.description ?? 'Follow set: ${set.name}';

      final event = await _authService.createAndSignEvent(
        kind: 30000, // NIP-51 follow set
        content: content,
        tags: tags,
      );

      if (event != null) {
        // Cache the follow set event immediately after creation
        _personalEventCache?.cacheUserEvent(event);

        final result = await _nostrService.broadcastEvent(event);
        if (result.successCount > 0) {
          // Update local set with Nostr event ID
          final setIndex = _followSets.indexWhere((s) => s.id == set.id);
          if (setIndex != -1) {
            _followSets[setIndex] = set.copyWith(nostrEventId: event.id);
          }
          Log.debug('Published follow set to Nostr: ${set.name} (${event.id})',
              name: 'SocialService', category: LogCategory.system);
        }
      }
    } catch (e) {
      Log.error('Failed to publish follow set to Nostr: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  // === PROFILE STATISTICS ===

  /// Get video count for a specific user
  Future<int> getUserVideoCount(String pubkey) async {
    Log.debug('📱 Fetching video count for: $pubkey',
        name: 'SocialService', category: LogCategory.system);

    try {
      final completer = Completer<int>();
      var videoCount = 0;

      // Subscribe to user's video events using NIP-71 compliant kinds
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video kinds: 22, 21, 34236, 34235
          ),
        ],
      );

      subscription.listen(
        (event) {
          videoCount++;
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(videoCount);
          }
        },
        onError: (error) {
          Log.error('Error fetching video count: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
      );

      final result = await completer.future;
      Log.debug('📱 Video count fetched: $result',
          name: 'SocialService', category: LogCategory.system);
      return result;
    } catch (e) {
      Log.error('Error fetching video count: $e',
          name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }

  /// Get total likes across all videos for a specific user
  Future<int> getUserTotalLikes(String pubkey) async {
    Log.debug('❤️ Fetching total likes for: $pubkey',
        name: 'SocialService', category: LogCategory.system);

    try {
      // First, get all video events by this user
      final userVideos = <String>[];
      final videoCompleter = Completer<List<String>>();

      final videoSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video kinds: 22, 21, 34236, 34235
          ),
        ],
      );

      videoSubscription.listen(
        (event) {
          userVideos.add(event.id);
        },
        onDone: () {
          if (!videoCompleter.isCompleted) {
            videoCompleter.complete(userVideos);
          }
        },
        onError: (error) {
          Log.error('Error fetching user videos: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!videoCompleter.isCompleted) {
            videoCompleter.complete([]);
          }
        },
      );

      final videoIds = await videoCompleter.future;

      if (videoIds.isEmpty) {
        Log.info('❤️ No videos found, total likes: 0',
            name: 'SocialService', category: LogCategory.system);
        return 0;
      }

      Log.info('📱 Found ${videoIds.length} videos, fetching likes...',
          name: 'SocialService', category: LogCategory.system);

      // Now get likes for all these videos
      final likesCompleter = Completer<int>();
      var totalLikes = 0;

      final likesSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [7], // Like events
            e: videoIds, // Events that reference our videos
          ),
        ],
      );

      likesSubscription.listen(
        (event) {
          // Only count '+' reactions as likes
          if (event.content.trim() == '+') {
            totalLikes++;
          }
        },
        onDone: () {
          if (!likesCompleter.isCompleted) {
            likesCompleter.complete(totalLikes);
          }
        },
        onError: (error) {
          Log.error('Error fetching likes: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!likesCompleter.isCompleted) {
            likesCompleter.complete(totalLikes);
          }
        },
      );

      final result = await likesCompleter.future;
      Log.debug('❤️ Total likes fetched: $result',
          name: 'SocialService', category: LogCategory.system);
      return result;
    } catch (e) {
      Log.error('Error fetching total likes: $e',
          name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }

  // === COMMENT SYSTEM ===

  /// Posts a comment in reply to a root event (video)
  Future<void> postComment({
    required String content,
    required String rootEventId,
    required String rootEventAuthorPubkey,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot post comment - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }

    if (content.trim().isEmpty) {
      Log.error('Cannot post empty comment',
          name: 'SocialService', category: LogCategory.system);
      throw Exception('Comment content cannot be empty');
    }

    Log.debug('📱 Posting comment to event: $rootEventId',
        name: 'SocialService', category: LogCategory.system);

    try {
      // We don't need the keyPair directly since createAndSignEvent handles signing

      // Create tags for the comment
      final tags = <List<String>>[];

      // Always include root event tag (the video being commented on)
      tags.add(['e', rootEventId, '', 'root']);

      // Tag the root event author
      tags.add(['p', rootEventAuthorPubkey]);

      // If this is a reply to another comment, add reply tags
      if (replyToEventId != null) {
        tags.add(['e', replyToEventId, '', 'reply']);

        if (replyToAuthorPubkey != null) {
          tags.add(['p', replyToAuthorPubkey]);
        }
      }

      // Create the comment event (Kind 1 text note)
      final event = await _authService.createAndSignEvent(
        kind: 1, // Text note
        tags: tags,
        content: content.trim(),
      );

      if (event == null) {
        throw Exception('Failed to create comment event');
      }

      // Broadcast the comment
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast comment: $errorMessages');
      }

      Log.info('Comment posted successfully: ${event.id}',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('Error posting comment: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Fetches all comments for a given root event ID
  Stream<Event> fetchCommentsForEvent(String rootEventId) {
    Log.debug(
        '📱 Fetching comments for event: $rootEventId',
        name: 'SocialService',
        category: LogCategory.system);

    // Create filter for comments
    // Comments are Kind 1 events that have an 'e' tag pointing to the root event
    final filter = Filter(
      kinds: [1], // Text notes
      e: [rootEventId], // Comments that reference this event
    );

    // Create a StreamController to emit events
    final controller = StreamController<Event>();

    // Create managed subscription for comments
    // NOTE: No onComplete callback - keep subscription open for real-time comments
    // Comments should stay live to receive new comments after EOSE
    _subscriptionManager
        .createSubscription(
      name: 'comments_$rootEventId',
      filters: [
        Filter(
          kinds: filter.kinds,
          e: filter.e,
          h: filter.h,
          limit: 50, // Limit comment fetching
        ),
      ],
      onEvent: (event) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      // Removed onComplete callback to keep subscription open for real-time comments
      // Only timeout or explicit cancellation will close this stream
      timeout: const Duration(minutes: 5), // Longer timeout for live comment subscriptions
      priority: 6, // Lower priority for comments
    )
        .catchError((error) {
      Log.error('Failed to create comment subscription: $error',
          name: 'SocialService', category: LogCategory.system);
      if (!controller.isClosed) {
        controller.addError(error);
      }
      return 'error_subscription'; // Return a placeholder subscription ID
    });

    return controller.stream;
  }

  /// Fetches comment count for an event
  Future<int> getCommentCount(String rootEventId) async {
    Log.debug(
        'Fetching comment count for event: $rootEventId',
        name: 'SocialService',
        category: LogCategory.system);

    try {
      final completer = Completer<int>();
      var commentCount = 0;

      // Create a dedicated comment count subscription with higher priority and shorter timeout
      await _subscriptionManager.createSubscription(
        name: 'comment_count_$rootEventId',
        filters: [
          Filter(
            kinds: [1], // Text notes
            e: [rootEventId], // Comments that reference this event
            limit: 100, // Reasonable limit for counting
          ),
        ],
        onEvent: (event) {
          commentCount++;
        },
        onError: (error) {
          Log.error('Error fetching comment count: $error',
              name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(commentCount);
          }
        },
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete(commentCount);
          }
        },
        timeout: const Duration(seconds: 5), // Short timeout for count
        priority: 5, // Higher priority for counts
      );

      final result = await completer.future;
      Log.debug('📱 Comment count fetched: $result',
          name: 'SocialService', category: LogCategory.system);
      return result;
    } catch (e) {
      Log.error('Error fetching comment count: $e',
          name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }

  /// Cancel comment subscriptions for a specific video (call when video scrolls out of view)
  Future<void> cancelCommentSubscriptions(String rootEventId) async {
    await _subscriptionManager.cancelSubscriptionsByName('comments_$rootEventId');
    await _subscriptionManager
        .cancelSubscriptionsByName('comment_count_$rootEventId');
    Log.debug('🗑️ Cancelled comment subscriptions for: $rootEventId',
        name: 'SocialService', category: LogCategory.system);
  }

  // === REPOST SYSTEM (NIP-18) ===

  /// Toggles repost state for a video event (repost/unrepost)
  /// Uses NIP-18 for repost (Kind 6) and NIP-09 for unrepost (Kind 5)
  Future<void> toggleRepost(VideoEvent videoToRepost) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot repost - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }

    Log.debug('🔄 Toggling repost for video: ${videoToRepost.id}',
        name: 'SocialService', category: LogCategory.system);

    // Extract d-tag from video's rawTags
    final dTagValue = videoToRepost.rawTags['d'];
    if (dTagValue == null || dTagValue.isEmpty) {
      throw Exception('Cannot repost: Video event missing required d tag');
    }

    // Check repost state using addressable ID format
    final addressableId = '32222:${videoToRepost.pubkey}:$dTagValue';
    final wasReposted = _repostedEventIds.contains(addressableId);

    try {
      if (!wasReposted) {
        // Repost the video
        Log.debug('➕ Adding repost for video: ${videoToRepost.id}',
            name: 'SocialService', category: LogCategory.system);

        // Create NIP-18 generic repost event (Kind 16) for non-kind-1 events
        final event = await _authService.createAndSignEvent(
          kind: 16,
          content: '',
          tags: [
            ['k', '34236'], // Required k tag for generic repost
            ['a', addressableId],
            ['p', videoToRepost.pubkey],
          ],
        );

        if (event == null) {
          throw Exception('Failed to create repost event');
        }

        // Cache immediately
        _personalEventCache?.cacheUserEvent(event);

        // Broadcast
        final result = await _nostrService.broadcastEvent(event);
        if (!result.isSuccessful) {
          final errorMessages = result.errors.values.join(', ');
          throw Exception('Failed to broadcast repost: $errorMessages');
        }

        // Update local state
        _repostedEventIds.add(addressableId);
        _repostEventIdToRepostId[addressableId] = event.id;

        Log.info('Repost published for video: ${videoToRepost.id}',
            name: 'SocialService', category: LogCategory.system);
      } else {
        // Unrepost by publishing NIP-09 deletion event
        Log.debug('➖ Removing repost for video: ${videoToRepost.id}',
            name: 'SocialService', category: LogCategory.system);

        final repostEventId = _repostEventIdToRepostId[addressableId];
        if (repostEventId != null) {
          await _unrepostEvent(repostEventId);

          // Update local state
          _repostedEventIds.remove(addressableId);
          _repostEventIdToRepostId.remove(addressableId);

          Log.info('Unrepost (deletion) published for video: ${videoToRepost.id}',
              name: 'SocialService', category: LogCategory.system);
        } else {
          Log.warning('Cannot unrepost - repost event ID not found',
              name: 'SocialService', category: LogCategory.system);

          // Fallback: remove from local state only
          _repostedEventIds.remove(addressableId);
        }
      }
    } catch (e) {
      Log.error('Error toggling repost: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Publishes a NIP-09 deletion event for unrepost functionality
  Future<void> _unrepostEvent(String repostEventId) async {
    try {
      // Create NIP-09 deletion event (Kind 5)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content: 'Unreposted',
        tags: [
          ['e', repostEventId], // Reference to the repost event to delete
        ],
      );

      if (event == null) {
        throw Exception('Failed to create unrepost deletion event');
      }

      // Cache immediately
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast
      final result = await _nostrService.broadcastEvent(event);
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast unrepost: $errorMessages');
      }

      Log.debug('Unrepost deletion event broadcasted: ${event.id}',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('Error publishing unrepost deletion: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Reposts a Nostr event (Kind 6)
  Future<void> repostEvent(Event eventToRepost) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot repost - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }

    Log.debug('Reposting event: ${eventToRepost.id}',
        name: 'SocialService', category: LogCategory.system);

    try {
      // Create NIP-18 repost event (Kind 6)
      // For addressable events, we need to extract the 'd' tag value
      String? dTagValue;
      for (final tag in eventToRepost.tags) {
        if (tag.isNotEmpty && tag[0] == 'd' && tag.length > 1) {
          dTagValue = tag[1];
          break;
        }
      }

      if (dTagValue == null) {
        throw Exception('Cannot repost: Video event missing required d tag');
      }

      // Use 'a' tag for addressable event reference
      final repostTags = <List<String>>[
        ['k', '34236'], // Required k tag for generic repost (kind 16)
        ['a', '32222:${eventToRepost.pubkey}:$dTagValue'],
        ['p', eventToRepost.pubkey], // Reference to original author
      ];

      final event = await _authService.createAndSignEvent(
        kind: 16, // Generic repost event for non-kind-1 events (NIP-18)
        content: '', // Content is typically empty for reposts
        tags: repostTags,
      );

      if (event == null) {
        throw Exception('Failed to create repost event');
      }

      // Cache the repost event immediately after creation
      _personalEventCache?.cacheUserEvent(event);

      // Broadcast the repost event
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast repost: $errorMessages');
      }

      // Track the repost locally using the addressable ID format
      final addressableId = '32222:${eventToRepost.pubkey}:$dTagValue';
      _repostedEventIds.add(addressableId);
      _repostEventIdToRepostId[addressableId] = event.id;

      Log.info('Event reposted successfully: ${event.id}',
          name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('Error reposting event: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Publishes a NIP-62 "right to be forgotten" deletion request event
  Future<void> publishRightToBeForgotten() async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot publish deletion request - user not authenticated',
          name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }

    Log.debug('📱️ Publishing NIP-62 right to be forgotten event...',
        name: 'SocialService', category: LogCategory.system);

    try {
      // Create NIP-62 deletion request event (Kind 5 with special formatting)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content:
            'REQUEST: Delete all data associated with this pubkey under right to be forgotten',
        tags: [
          ['p', _authService.currentPublicKeyHex!], // Reference to own pubkey
          ['k', '0'], // Request deletion of Kind 0 (profile) events
          ['k', '1'], // Request deletion of Kind 1 (text note) events
          ['k', '3'], // Request deletion of Kind 3 (contact list) events
          ['k', '6'], // Request deletion of Kind 6 (repost) events
          ['k', '7'], // Request deletion of Kind 7 (reaction) events
          [
            'k',
            '34236'
          ], // Request deletion of Kind 34236 (addressable short video) events per NIP-71
        ],
      );

      if (event == null) {
        throw Exception('Failed to create deletion request event');
      }

      // Broadcast the deletion request
      final result = await _nostrService.broadcastEvent(event);

      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast deletion request: $errorMessages');
      }

      Log.info(
          'NIP-62 deletion request published: ${event.id}',
          name: 'SocialService',
          category: LogCategory.system);
    } catch (e) {
      Log.error('Error publishing deletion request: $e',
          name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Save following list to local storage for aggressive caching
  Future<void> _saveFollowingListToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        await prefs.setString(key, jsonEncode(_followingPubkeys));
        Log.debug(
            '💾 Saved following list to cache: ${_followingPubkeys.length} users',
            name: 'SocialService',
            category: LogCategory.system);
      }
    } catch (e) {
      Log.error('Failed to save following list to cache: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  /// Load following list from local storage
  Future<void> _loadFollowingListFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        final cached = prefs.getString(key);
        if (cached != null) {
          final List<dynamic> decoded = jsonDecode(cached);
          _followingPubkeys = decoded.cast<String>();
          Log.info(
              '📋 Loaded cached following list: ${_followingPubkeys.length} users',
              name: 'SocialService',
              category: LogCategory.system);
        }
      }
    } catch (e) {
      Log.error('Failed to load following list from cache: $e',
          name: 'SocialService', category: LogCategory.system);
    }
  }

  void dispose() {
    Log.debug('📱️ Disposing SocialService',
        name: 'SocialService', category: LogCategory.system);

    // Cancel all managed subscriptions
    if (_likeSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_likeSubscriptionId!);
      _likeSubscriptionId = null;
    }
    if (_followSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_followSubscriptionId!);
      _followSubscriptionId = null;
    }
    if (_repostSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_repostSubscriptionId!);
      _repostSubscriptionId = null;
    }
    if (_userLikesSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_userLikesSubscriptionId!);
      _userLikesSubscriptionId = null;
    }
    if (_userRepostsSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_userRepostsSubscriptionId!);
      _userRepostsSubscriptionId = null;
    }
  }

  /// Process a repost event and extract the reposted event ID
  /// Handles 'a' tags for addressable events
  void _processRepostEvent(Event repostEvent) {
    // Check for 'a' tags (addressable event references)
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
        // Parse the 'a' tag format: "kind:pubkey:d-tag-value"
        final parts = tag[1].split(':');
        if (parts.length >= 3 && parts[0] == '32222') {
          final addressableId = tag[1];
          _repostedEventIds.add(addressableId);
          _repostEventIdToRepostId[addressableId] = repostEvent.id;
          Log.debug(
              '📱 Cached user repost of addressable event: $addressableId (repost: ${repostEvent.id})',
              name: 'SocialService',
              category: LogCategory.system);
          return;
        }
      }
    }
  }
}
