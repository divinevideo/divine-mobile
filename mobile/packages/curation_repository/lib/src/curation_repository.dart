// ABOUTME: Repository for managing NIP-51 video curation sets and content
// ABOUTME: discovery. Handles fetching, caching, and filtering videos
// ABOUTME: based on curation sets.

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:video_event_cache/video_event_cache.dart';

/// Repository for managing NIP-51 video curation sets and content
/// discovery.
class CurationRepository {
  /// Creates a [CurationRepository].
  ///
  /// [nostrService] is used for relay communication.
  /// [videoEventCache] provides access to the local video cache.
  /// [likesRepository] provides like counts for sorting.
  /// [signer] signs Nostr events for publishing.
  /// [divineTeamPubkeys] lists the pubkeys of Divine team members
  /// used for the "editor's picks" curation set.
  CurationRepository({
    required NostrClient nostrService,
    required VideoEventCache videoEventCache,
    required LikesRepository likesRepository,
    required NostrSigner signer,
    required List<String> divineTeamPubkeys,
  }) : _nostrService = nostrService,
       _videoEventCache = videoEventCache,
       _likesRepository = likesRepository,
       _signer = signer,
       _divineTeamPubkeys = divineTeamPubkeys {
    _initializeWithSampleData();
  }

  final NostrClient _nostrService;
  final VideoEventCache _videoEventCache;
  final LikesRepository _likesRepository;
  final NostrSigner _signer;
  final List<String> _divineTeamPubkeys;

  final Map<String, CurationSet> _curationSets = {};
  final Map<String, List<VideoEvent>> _setVideoCache = {};
  bool _isLoading = false;
  String? _error;
  // Track video count to reduce duplicate logging
  int _lastEditorVideoCount = -1;

  // Divine Team curation state
  // Legacy name, now tracks Divine Team fetch
  bool _hasFetchedEditorsList = false;
  // Dedicated cache for Divine Team videos
  final List<VideoEvent> _editorPicksVideoCache = [];

  /// Current curation sets
  List<CurationSet> get curationSets => _curationSets.values.toList();

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;

  /// Initialize with sample data while we're developing
  void _initializeWithSampleData() {
    _isLoading = true;

    Log.debug(
      '🔄 CurationRepository initializing...',
      name: 'CurationRepository',
      category: LogCategory.system,
    );
    Log.debug(
      '  VideoEventCache has '
      '${_videoEventCache.discoveryVideos.length} videos',
      name: 'CurationRepository',
      category: LogCategory.system,
    );

    // Load sample curation sets
    for (final sampleSet in SampleCurationSets.all) {
      _curationSets[sampleSet.id] = sampleSet;
    }

    // Populate with actual video data
    unawaited(_populateSampleSets());

    _isLoading = false;
  }

  /// Populate sample sets with real video data
  Future<void> _populateSampleSets() async {
    final allVideos = _videoEventCache.discoveryVideos;

    // Always create Divine Team picks with default video, even
    // if no other videos
    final editorsPicks = _selectEditorsPicksVideos(allVideos, allVideos);
    _setVideoCache[CurationSetType.editorsPicks.id] = editorsPicks;

    if (allVideos.isEmpty) {
      return;
    }

    // Sort videos by different criteria for different sets
    final sortedByTime = List<VideoEvent>.from(allVideos)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort by reaction count (fetching from LikesRepository).
    // Include addressable IDs so reactions on any version of a replaced
    // video (different event ID, same d-tag) are counted via 'a' tag.
    final videoIds = allVideos.map((v) => v.id).toList();
    // Keep the event-id keys aligned with getLikeCounts' return shape while
    // still giving the repository the addressable IDs it needs for edited
    // videos.
    final addressableIds = {
      for (final v in allVideos)
        if (v.addressableId != null) v.id: v.addressableId!,
    };
    final likeCounts = await _likesRepository.getLikeCounts(
      videoIds,
      addressableIds: addressableIds.isEmpty ? null : addressableIds,
    );

    final sortedByReactions = List<VideoEvent>.from(allVideos)
      ..sort((a, b) {
        final aReactions = likeCounts[a.id] ?? 0;
        final bReactions = likeCounts[b.id] ?? 0;
        return bReactions.compareTo(aReactions);
      });

    // Update Divine Team with actual data
    final updatedEditorsPicks = _selectEditorsPicksVideos(
      sortedByTime,
      sortedByReactions,
    );
    _setVideoCache[CurationSetType.editorsPicks.id] = updatedEditorsPicks;

    Log.verbose(
      'Populated curation sets:',
      name: 'CurationRepository',
      category: LogCategory.system,
    );
    Log.verbose(
      '   Divine Team: ${updatedEditorsPicks.length} videos',
      name: 'CurationRepository',
      category: LogCategory.system,
    );
    Log.verbose(
      '   Total available videos: ${allVideos.length}',
      name: 'CurationRepository',
      category: LogCategory.system,
    );
  }

  /// Fetch Divine Team videos from relay
  Future<void> _fetchDivineTeamVideos() async {
    if (_hasFetchedEditorsList) {
      return; // Only fetch once
    }

    _hasFetchedEditorsList = true;

    try {
      Log.info(
        '📋 Fetching Divine Team videos from relay...',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      Log.info(
        '  Authors: ${_divineTeamPubkeys.join(", ")}',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Subscribe to fetch videos from Divine Team authors
      final filter = Filter(
        kinds: const [NIP71VideoKinds.addressableShortVideo],
        authors: _divineTeamPubkeys,
        limit: 500,
      );
      final eventStream = _nostrService.subscribe([filter]);

      final completer = Completer<void>();
      late StreamSubscription<Event> streamSubscription;
      var receivedCount = 0;

      streamSubscription = eventStream.listen(
        (event) {
          try {
            final video = VideoEvent.fromNostrEvent(event);

            // Add to dedicated cache if not already there
            if (!_editorPicksVideoCache.any((v) => v.id == video.id)) {
              _editorPicksVideoCache.add(video);
              receivedCount++;

              Log.verbose(
                '📹 Fetched Divine Team video '
                '($receivedCount): '
                '${video.title ?? video.id}',
                name: 'CurationRepository',
                category: LogCategory.system,
              );
            }

            // Also add to video event cache for general
            // availability
            _videoEventCache.addVideoEvent(video);
            // coverage:ignore-start
          } on Exception catch (e) {
            Log.error(
              'Failed to parse Divine Team video event: $e',
              name: 'CurationRepository',
              category: LogCategory.system,
            );
          }
          // coverage:ignore-end
        },
        onError: (Object error) {
          Log.error(
            'Error fetching Divine Team videos: $error',
            name: 'CurationRepository',
            category: LogCategory.system,
          );
          unawaited(streamSubscription.cancel());
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for completion or timeout
      await Future.any([
        completer.future,
        Future<void>.delayed(const Duration(seconds: 10)),
      ]);

      await streamSubscription.cancel();

      Log.info(
        '✅ Fetched $receivedCount Divine Team videos '
        'from relay',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Refresh the cache after fetching
      await _populateSampleSets();
      // coverage:ignore-start
    } on Exception catch (e) {
      Log.error(
        'Error fetching Divine Team videos: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
    }
    // coverage:ignore-end
  }

  /// Algorithm for selecting Divine Team videos
  List<VideoEvent> _selectEditorsPicksVideos(
    List<VideoEvent> byTime,
    List<VideoEvent> byReactions,
  ) {
    // If we don't have the Divine Team videos yet, start
    // fetching them (async)
    if (!_hasFetchedEditorsList) {
      unawaited(_fetchDivineTeamVideos());
      Log.debug(
        '⏳ Divine Team videos not fetched yet, starting '
        'fetch in background',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      return []; // Return empty for now
    }

    // Return videos from the dedicated cache
    final picks = List<VideoEvent>.from(_editorPicksVideoCache)
      // Sort by creation time (newest first)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Only log on changes to avoid spam
    final currentCount = picks.length;
    if (_lastEditorVideoCount != currentCount) {
      Log.debug(
        '🔍 Selecting Divine Team videos from cache...',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      Log.debug(
        '  Cached videos: ${_editorPicksVideoCache.length}',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      Log.debug(
        '  Returning: ${picks.length} videos',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      _lastEditorVideoCount = currentCount;
    }

    return picks;
  }

  /// Get videos for a specific curation set
  List<VideoEvent> getVideosForSet(String setId) => _setVideoCache[setId] ?? [];

  /// Get videos for a curation set type
  List<VideoEvent> getVideosForSetType(CurationSetType setType) =>
      getVideosForSet(setType.id);

  /// Get a specific curation set
  CurationSet? getCurationSet(String setId) => _curationSets[setId];

  /// Get curation set by type
  CurationSet? getCurationSetByType(CurationSetType setType) =>
      getCurationSet(setType.id);

  /// Refresh curation sets from Nostr
  Future<void> refreshCurationSets({List<String>? curatorPubkeys}) async {
    _isLoading = true;
    _error = null;

    try {
      Log.debug(
        'Fetching kind 30005 curation sets from Nostr...',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Query for video curation sets (kind 30005)
      final filter = Filter(
        kinds: [30005],
        authors: curatorPubkeys,
        limit: 500,
      );

      final eventStream = _nostrService.subscribe([filter]);

      var fetchedCount = 0;
      final completer = Completer<void>();

      // Listen for events with timeout
      final subscription = eventStream.listen(
        (event) {
          try {
            if (event.kind != 30005) {
              Log.warning(
                'Received unexpected event kind '
                '${event.kind} (expected 30005)',
                name: 'CurationRepository',
                category: LogCategory.system,
              );
              return;
            }

            final curationSet = CurationSet.fromNostrEvent(event);
            _curationSets[curationSet.id] = curationSet;
            fetchedCount++;

            Log.verbose(
              'Fetched curation set: ${curationSet.title} '
              '(${curationSet.videoIds.length} videos)',
              name: 'CurationRepository',
              category: LogCategory.system,
            );
            // coverage:ignore-start
          } on Exception catch (e) {
            Log.error(
              'Failed to parse curation set from event: '
              '$e',
              name: 'CurationRepository',
              category: LogCategory.system,
            );
          }
          // coverage:ignore-end
        },
        onError: (Object error) {
          Log.error(
            'Error fetching curation sets: $error',
            name: 'CurationRepository',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Wait for completion or timeout (10 seconds)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.debug(
            'Curation set fetch timed out after 10s '
            '(fetched $fetchedCount sets)',
            name: 'CurationRepository',
            category: LogCategory.system,
          );
        },
      );

      await subscription.cancel();

      Log.debug(
        'Fetched $fetchedCount curation sets from Nostr',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // If no sets were found, populate sample data as
      // fallback
      if (fetchedCount == 0) {
        Log.debug(
          'No curation sets found, using sample data',
          name: 'CurationRepository',
          category: LogCategory.system,
        );
        await _populateSampleSets();
      }

      _isLoading = false;
    } on Exception catch (e) {
      _error = 'Failed to refresh curation sets: $e';
      _isLoading = false;

      Log.error(
        'Error refreshing curation sets: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Fallback to sample data on error
      await _populateSampleSets();
    }
  }

  /// Subscribe to curation set updates
  Future<void> subscribeToCurationSets({List<String>? curatorPubkeys}) async {
    try {
      Log.debug(
        'Subscribing to kind 30005 curation sets...',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Subscribe to receive curation set events
      _nostrService
          .subscribe([
            Filter(kinds: [30005], authors: curatorPubkeys, limit: 500),
          ])
          .listen(
            (event) {
              try {
                if (event.kind != 30005) {
                  Log.warning(
                    'Received unexpected event kind '
                    '${event.kind} in curation subscription '
                    '(expected 30005)',
                    name: 'CurationRepository',
                    category: LogCategory.system,
                  );
                  return;
                }

                final curationSet = CurationSet.fromNostrEvent(event);
                _curationSets[curationSet.id] = curationSet;
                Log.verbose(
                  'Received curation set: '
                  '${curationSet.title} '
                  '(${curationSet.videoIds.length} videos)',
                  name: 'CurationRepository',
                  category: LogCategory.system,
                );

                // Update the video cache for this set
                _updateVideoCache(curationSet);
                // coverage:ignore-start
              } on Exception catch (e) {
                Log.error(
                  'Failed to parse curation set from event: '
                  '$e',
                  name: 'CurationRepository',
                  category: LogCategory.system,
                );
              }
              // coverage:ignore-end
            },
            onError: (Object error) {
              Log.error(
                'Error in curation set subscription: $error',
                name: 'CurationRepository',
                category: LogCategory.system,
              );
            },
          );
    } on Exception catch (e) {
      Log.error(
        'Error subscribing to curation sets: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Update video cache for a specific curation set
  void _updateVideoCache(CurationSet curationSet) {
    final allVideos = _videoEventCache.discoveryVideos;
    final setVideos = <VideoEvent>[];

    // Find videos matching the curation set's video IDs
    for (final videoId in curationSet.videoIds) {
      final video = allVideos.where((v) => v.id == videoId).firstOrNull;
      if (video != null) {
        setVideos.add(video);
      }
    }

    _setVideoCache[curationSet.id] = setVideos;
    Log.info(
      'Updated cache for ${curationSet.id}: '
      '${setVideos.length} videos found',
      name: 'CurationRepository',
      category: LogCategory.system,
    );
  }

  /// Publish status for a curation
  final Map<String, CurationPublishStatus> _publishStatuses = {};

  /// Currently publishing curations to prevent duplicate
  /// publishes
  final Set<String> _currentlyPublishing = {};

  /// Build a Nostr kind 30005 event for a curation set
  Future<Event?> buildCurationEvent({
    required String id,
    required String title,
    required List<String> videoIds,
    String? description,
    String? imageUrl,
  }) async {
    final tags = <List<String>>[
      ['d', id], // Replaceable event identifier
      ['title', title],
    ];

    if (description != null) {
      tags.add(['description', description]);
    }

    if (imageUrl != null) {
      tags.add(['image', imageUrl]);
    }

    // Add video references as 'e' tags
    for (final videoId in videoIds) {
      tags.add(['e', videoId]);
    }

    // Create and sign event via NostrSigner
    try {
      final pubkey = await _signer.getPublicKey();
      if (pubkey == null) {
        Log.error(
          'Cannot sign event - signer returned null '
          'public key',
          name: 'CurationRepository',
          category: LogCategory.system,
        );
        return null;
      }

      final unsignedEvent = Event(
        pubkey,
        30005, // NIP-51 curation set kind
        tags,
        description ?? title,
      );

      final signedEvent = await _signer.signEvent(unsignedEvent);
      return signedEvent;
    } on Exception catch (e) {
      Log.error(
        'Failed to create and sign curation event: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Publish a curation set to Nostr
  Future<CurationPublishResult> publishCuration({
    required String id,
    required String title,
    required List<String> videoIds,
    String? description,
    String? imageUrl,
  }) async {
    // Prevent duplicate concurrent publishes
    if (_currentlyPublishing.contains(id)) {
      Log.debug(
        'Curation $id already being published, '
        'skipping duplicate',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      return const CurationPublishResult(
        success: false,
        successCount: 0,
        totalRelays: 0,
        errors: {'duplicate': 'Already publishing'},
      );
    }

    _currentlyPublishing.add(id);

    // Mark as publishing
    _publishStatuses[id] = CurationPublishStatus(
      curationId: id,
      isPublishing: true,
      isPublished: false,
      lastAttemptAt: DateTime.now(),
    );

    try {
      // Build the event
      final event = await buildCurationEvent(
        id: id,
        title: title,
        videoIds: videoIds,
        description: description,
        imageUrl: imageUrl,
      );

      if (event == null) {
        Log.error(
          'Failed to create and sign curation event',
          name: 'CurationRepository',
          category: LogCategory.system,
        );

        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: false,
          failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
          lastAttemptAt: DateTime.now(),
          lastFailureReason: 'Failed to create and sign event',
        );

        return const CurationPublishResult(
          success: false,
          successCount: 0,
          totalRelays: 0,
          errors: {'signing': 'Failed to create and sign event'},
        );
      }

      // Publish with timeout
      final publishFuture = _nostrService.publishEvent(event);
      const timeoutDuration = Duration(seconds: 5);

      late final PublishResult publishResult;

      try {
        publishResult = await publishFuture.timeout(timeoutDuration);
      } on TimeoutException {
        Log.warning(
          'Curation publish timed out after 5s: $id',
          name: 'CurationRepository',
          category: LogCategory.system,
        );

        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: false,
          failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
          lastAttemptAt: DateTime.now(),
          lastFailureReason: 'Timeout after 5 seconds',
        );

        return const CurationPublishResult(
          success: false,
          successCount: 0,
          totalRelays: 0,
          errors: {'timeout': 'Publish timed out after 5 seconds'},
        );
      }

      return switch (publishResult) {
        PublishSuccess(:final event) => () {
          _publishStatuses[id] = CurationPublishStatus(
            curationId: id,
            isPublishing: false,
            isPublished: true,
            lastPublishedAt: DateTime.now(),
            publishedEventId: event.id,
            successfulRelays: _nostrService.connectedRelays,
            lastAttemptAt: DateTime.now(),
          );

          Log.info(
            '✅ Published curation "$title" to relays',
            name: 'CurationRepository',
            category: LogCategory.system,
          );

          return CurationPublishResult(
            success: true,
            successCount: 1,
            totalRelays: 1,
            eventId: event.id,
          );
        }(),
        PublishNoRelays() || PublishFailed() => () {
          _publishStatuses[id] = CurationPublishStatus(
            curationId: id,
            isPublishing: false,
            isPublished: false,
            failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
            lastAttemptAt: DateTime.now(),
            lastFailureReason: 'Failed to publish to relays',
          );

          Log.warning(
            '❌ Failed to publish curation "$title" '
            'to relays',
            name: 'CurationRepository',
            category: LogCategory.system,
          );

          return const CurationPublishResult(
            success: false,
            successCount: 0,
            totalRelays: 1,
            errors: {'publish': 'Failed to publish to relays'},
            failedRelays: ['relays'],
          );
        }(),
      };
    } on Exception catch (e) {
      Log.error(
        'Error publishing curation: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      _publishStatuses[id] = CurationPublishStatus(
        curationId: id,
        isPublishing: false,
        isPublished: false,
        failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
        lastAttemptAt: DateTime.now(),
        lastFailureReason: e.toString(),
      );

      return CurationPublishResult(
        success: false,
        successCount: 0,
        totalRelays: 0,
        errors: {'exception': e.toString()},
      );
    } finally {
      _currentlyPublishing.remove(id);
    }
  }

  /// Get publish status for a curation
  CurationPublishStatus getCurationPublishStatus(String curationId) {
    return _publishStatuses[curationId] ??
        CurationPublishStatus(
          curationId: curationId,
          isPublishing: false,
          isPublished: false,
        );
  }

  /// Retry all unpublished curations with exponential
  /// backoff
  Future<void> retryUnpublishedCurations() async {
    final now = DateTime.now();

    for (final entry in _publishStatuses.entries) {
      final curationId = entry.key;
      final status = entry.value;

      // Skip if already published or currently publishing
      if (status.isPublished || status.isPublishing) {
        continue;
      }

      // Skip if max retries reached
      // coverage:ignore-start
      if (!status.shouldRetry) {
        Log.debug(
          'Skipping retry for $curationId: '
          'max attempts reached',
          name: 'CurationRepository',
          category: LogCategory.system,
        );
        continue;
      }
      // coverage:ignore-end

      // Calculate next retry time with exponential backoff
      final retryDelay = getRetryDelay(status.failedAttempts);
      final nextRetryTime = status.lastAttemptAt?.add(retryDelay);

      if (nextRetryTime == null || now.isBefore(nextRetryTime)) {
        Log.debug(
          'Skipping retry for $curationId: '
          'backoff not elapsed',
          name: 'CurationRepository',
          category: LogCategory.system,
        );
        continue;
      }

      // coverage:ignore-start
      Log.info(
        '🔄 Retrying publish for curation $curationId '
        '(attempt ${status.failedAttempts + 1})',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Get curation details to retry
      final curation = _curationSets[curationId];
      if (curation != null) {
        await publishCuration(
          id: curation.id,
          title: curation.title ?? 'Untitled',
          videoIds: curation.videoIds,
          description: curation.description,
          imageUrl: curation.imageUrl,
        );
      }
      // coverage:ignore-end
    }
  }

  /// Get retry delay based on attempt count (exponential
  /// backoff)
  Duration getRetryDelay(int attemptCount) {
    // Exponential backoff: 2^n seconds
    // Max ~17 minutes
    final seconds = 1 << attemptCount.clamp(0, 10);
    return Duration(seconds: seconds);
  }

  /// Create a new curation set and publish to Nostr
  Future<bool> createCurationSet({
    required String id,
    required String title,
    required List<String> videoIds,
    String? description,
    String? imageUrl,
  }) async {
    try {
      Log.debug(
        'Creating curation set: $title',
        name: 'CurationRepository',
        category: LogCategory.system,
      );

      // Publish to Nostr
      final result = await publishCuration(
        id: id,
        title: title,
        videoIds: videoIds,
        description: description,
        imageUrl: imageUrl,
      );

      return result.success;
      // coverage:ignore-start
    } on Exception catch (e) {
      Log.error(
        'Error creating curation set: $e',
        name: 'CurationRepository',
        category: LogCategory.system,
      );
      return false;
    }
    // coverage:ignore-end
  }

  /// Check if videos need updating and refresh cache
  void refreshIfNeeded() {
    final currentVideoCount = _videoEventCache.discoveryVideos.length;
    final cachedCount = _setVideoCache.values.fold<int>(
      0,
      (sum, videos) => sum + videos.length,
    );

    // Refresh if we have new videos
    if (currentVideoCount > cachedCount) {
      unawaited(_populateSampleSets());
    }
  }

  /// Clean up resources
  void dispose() {
    // Clean up any subscriptions
  }
}
