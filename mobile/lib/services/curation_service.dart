// ABOUTME: Service for managing NIP-51 video curation sets and content discovery
// ABOUTME: Handles fetching, caching, and filtering videos based on curation sets

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/curation_publish_status.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class CurationService {
  CurationService({
    required INostrService nostrService,
    required VideoEventService videoEventService,
    required SocialService socialService,
    required AuthService authService,
  })  : _nostrService = nostrService,
        _videoEventService = videoEventService,
        _socialService = socialService,
        _authService = authService {
    _initializeWithSampleData();

    // Listen for video updates and refresh curation data
    // REFACTORED: Service no longer extends ChangeNotifier - use Riverpod ref.watch instead
  }
  final INostrService _nostrService;
  final VideoEventService _videoEventService;
  final SocialService _socialService;
  final AuthService _authService;

  final Map<String, CurationSet> _curationSets = {};
  final Map<String, List<VideoEvent>> _setVideoCache = {};
  bool _isLoading = false;
  String? _error;
  int _lastEditorVideoCount =
      -1; // Track video count to reduce duplicate logging

  // Analytics-based trending cache
  List<VideoEvent> _analyticsTrendingVideos = [];
  DateTime? _lastTrendingFetch;
  bool _isFetchingTrending = false;

  // Track video IDs that failed to fetch from relays to avoid repeated attempts
  final Set<String> _missingVideoIds = {};

  // Divine Team curation state
  bool _hasFetchedEditorsList = false; // Legacy name, now tracks Divine Team fetch
  List<VideoEvent> _editorPicksVideoCache = []; // Dedicated cache for Divine Team videos

  /// Current curation sets
  List<CurationSet> get curationSets => _curationSets.values.toList();

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;

  /// Initialize with sample data while we're developing
  void _initializeWithSampleData() {
    _isLoading = true;

    Log.debug('🔄 CurationService initializing...',
        name: 'CurationService', category: LogCategory.system);
    Log.debug(
        '  VideoEventService has ${_videoEventService.discoveryVideos.length} videos',
        name: 'CurationService',
        category: LogCategory.system);

    // Load sample curation sets
    for (final sampleSet in SampleCurationSets.all) {
      _curationSets[sampleSet.id] = sampleSet;
    }

    // Populate with actual video data
    _populateSampleSets();

    _isLoading = false;
  }

  /// Populate sample sets with real video data
  void _populateSampleSets() {
    final allVideos = _videoEventService.discoveryVideos;
    // Populating curation sets silently

    // Always create Divine Team picks with default video, even if no other videos
    final editorsPicks = _selectEditorsPicksVideos(allVideos, allVideos);
    _setVideoCache[CurationSetType.editorsPicks.id] = editorsPicks;

    if (allVideos.isEmpty) {
      return;
    }

    // Sort videos by different criteria for different sets
    final sortedByTime = List<VideoEvent>.from(allVideos)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Sort by reaction count (using cached counts from social service)
    final sortedByReactions = List<VideoEvent>.from(allVideos)
      ..sort((a, b) {
        final aReactions = _socialService.getCachedLikeCount(a.id) ?? 0;
        final bReactions = _socialService.getCachedLikeCount(b.id) ?? 0;
        return bReactions.compareTo(aReactions);
      });

    // Update Divine Team with actual data (already created above with default video)
    final updatedEditorsPicks =
        _selectEditorsPicksVideos(sortedByTime, sortedByReactions);
    _setVideoCache[CurationSetType.editorsPicks.id] = updatedEditorsPicks;

    Log.verbose('Populated curation sets:',
        name: 'CurationService', category: LogCategory.system);
    Log.verbose('   Divine Team: ${updatedEditorsPicks.length} videos',
        name: 'CurationService', category: LogCategory.system);
    Log.verbose('   Total available videos: ${allVideos.length}',
        name: 'CurationService', category: LogCategory.system);
  }

  /// Fetch Divine Team videos from relay
  Future<void> _fetchDivineTeamVideos() async {
    if (_hasFetchedEditorsList) {
      return; // Only fetch once
    }

    _hasFetchedEditorsList = true;

    try {
      Log.info("📋 Fetching Divine Team videos from relay...",
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Authors: ${AppConstants.divineTeamPubkeys.join(", ")}',
          name: 'CurationService', category: LogCategory.system);

      // Subscribe to fetch videos from Divine Team authors
      final filter = Filter(
        kinds: [34236], // NIP-71 video events
        authors: AppConstants.divineTeamPubkeys,
        limit: 500, // Get all their videos
      );
      final eventStream = _nostrService.subscribeToEvents(
        filters: [filter],
      );

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
                  "📹 Fetched Divine Team video ($receivedCount): ${video.title ?? video.id}",
                  name: 'CurationService',
                  category: LogCategory.system);
            }

            // Also add to video event service cache for general availability
            _videoEventService.addVideoEvent(video);
          } catch (e) {
            Log.error("Failed to parse Divine Team video event: $e",
                name: 'CurationService', category: LogCategory.system);
          }
        },
        onError: (error) {
          Log.error("Error fetching Divine Team videos: $error",
              name: 'CurationService', category: LogCategory.system);
          streamSubscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for completion or timeout (give it 10 seconds to collect videos)
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 10)),
      ]);

      await streamSubscription.cancel();

      Log.info(
          "✅ Fetched ${receivedCount} Divine Team videos from relay",
          name: 'CurationService',
          category: LogCategory.system);

      // Refresh the cache after fetching
      _populateSampleSets();
    } catch (e) {
      Log.error("Error fetching Divine Team videos: $e",
          name: 'CurationService', category: LogCategory.system);
    }
  }

  /// Algorithm for selecting Divine Team videos
  List<VideoEvent> _selectEditorsPicksVideos(
    List<VideoEvent> byTime,
    List<VideoEvent> byReactions,
  ) {
    // If we don't have the Divine Team videos yet, start fetching them (async)
    if (!_hasFetchedEditorsList) {
      _fetchDivineTeamVideos();
      Log.debug(
          "⏳ Divine Team videos not fetched yet, starting fetch in background",
          name: 'CurationService',
          category: LogCategory.system);
      return []; // Return empty for now
    }

    // Return videos from the dedicated cache
    // This cache contains all videos from Divine Team members
    final picks = List<VideoEvent>.from(_editorPicksVideoCache);

    // Sort by creation time (newest first)
    picks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Only log on changes to avoid spam
    final currentCount = picks.length;
    if (_lastEditorVideoCount != currentCount) {
      Log.debug("🔍 Selecting Divine Team videos from cache...",
          name: 'CurationService', category: LogCategory.system);
      Log.debug('  Cached videos: ${_editorPicksVideoCache.length}',
          name: 'CurationService', category: LogCategory.system);
      Log.debug('  Returning: ${picks.length} videos',
          name: 'CurationService', category: LogCategory.system);

      _lastEditorVideoCount = currentCount;
    }

    return picks;
  }

  /// Get cached trending videos from analytics (returns empty list if not fetched)
  List<VideoEvent> get analyticsTrendingVideos => _analyticsTrendingVideos;

  /// Clear the missing videos cache to allow retrying videos that might have returned
  void clearMissingVideosCache() {
    if (_missingVideoIds.isNotEmpty) {
      Log.info(
          '🔄 Clearing ${_missingVideoIds.length} missing video IDs from cache',
          name: 'CurationService',
          category: LogCategory.system);
      _missingVideoIds.clear();
    }
  }

  /// Refresh trending videos from analytics API (call this when user visits trending)
  Future<void> refreshTrendingFromAnalytics() async {
    await _fetchTrendingFromAnalytics();
  }

  /// Fetch trending videos from analytics API
  Future<void> _fetchTrendingFromAnalytics() async {
    // Prevent concurrent fetches
    if (_isFetchingTrending) {
      Log.debug(
          '📊 Already fetching trending videos, skipping duplicate request',
          name: 'CurationService',
          category: LogCategory.system);
      return;
    }

    // Check if we recently fetched (within 5 minutes)
    if (_lastTrendingFetch != null &&
        DateTime.now().difference(_lastTrendingFetch!).inMinutes < 5) {
      Log.debug('📊 Trending videos recently fetched, using cache',
          name: 'CurationService', category: LogCategory.system);
      return;
    }

    _isFetchingTrending = true;

    // Clear missing videos cache every 6 hours to allow retrying
    if (_lastTrendingFetch != null &&
        DateTime.now().difference(_lastTrendingFetch!).inHours >= 6) {
      clearMissingVideosCache();
    }

    try {
      // Log current state before fetching
      Log.info('📊 Fetching trending videos from analytics API...',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Current cached count: ${_analyticsTrendingVideos.length}',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  URL: https://api.openvine.co/analytics/trending/vines',
          name: 'CurationService', category: LogCategory.system);

      final response = await http.get(
        Uri.parse('https://api.openvine.co/analytics/trending/vines'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'divine-Mobile/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      Log.info('📊 Trending API response:',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Status: ${response.statusCode}',
          name: 'CurationService', category: LogCategory.system);
      Log.info('  Body length: ${response.body.length} chars',
          name: 'CurationService', category: LogCategory.system);

      // Log first 500 chars of response for debugging
      if (response.body.length > 500) {
        Log.info('  Body preview: ${response.body.substring(0, 500)}...',
            name: 'CurationService', category: LogCategory.system);
      } else {
        Log.info('  Body: ${response.body}',
            name: 'CurationService', category: LogCategory.system);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vinesData = data['vines'] as List<dynamic>?;

        Log.info('  Vines in response: ${vinesData?.length ?? 0}',
            name: 'CurationService', category: LogCategory.system);

        if (vinesData != null && vinesData.isNotEmpty) {
          final trending = <VideoEvent>[];
          final allVideos = _videoEventService.discoveryVideos;
          final missingEventIds = <String>[];

          Log.info('  Local videos available: ${allVideos.length}',
              name: 'CurationService', category: LogCategory.system);

          // First pass: collect videos we have locally and track missing ones
          for (final vineData in vinesData) {
            final eventId = vineData['eventId'] as String?;
            final viewCount = vineData['views'] ?? 0;

            if (eventId != null) {
              // Skip videos we know are missing from relays
              if (_missingVideoIds.contains(eventId)) {
                Log.verbose('  Skipping known missing video: $eventId',
                    name: 'CurationService', category: LogCategory.system);
                continue;
              }

              Log.verbose('  Looking for eventId: $eventId ($viewCount views)',
                  name: 'CurationService', category: LogCategory.system);

              // Find the video in our local cache
              final localVideo = allVideos.firstWhere(
                (video) => video.id == eventId,
                orElse: () => VideoEvent(
                  id: '',
                  pubkey: '',
                  createdAt: 0,
                  content: '',
                  timestamp: DateTime.now(),
                ),
              );

              if (localVideo.id.isNotEmpty) {
                trending.add(localVideo);
                // Use verbose logging for individual videos to reduce log spam
                Log.verbose(
                    '✅ Found trending video: ${localVideo.title ?? localVideo.id} ($viewCount views)',
                    name: 'CurationService',
                    category: LogCategory.system);
              } else {
                Log.warning(
                    '❌ Trending video not found locally: $eventId - will fetch from relays',
                    name: 'CurationService',
                    category: LogCategory.system);
                missingEventIds.add(eventId);
              }
            }
          }

          // Fetch missing videos from Nostr relays
          if (missingEventIds.isNotEmpty) {
            Log.info(
                '📡 Fetching ${missingEventIds.length} missing trending videos from relays...',
                name: 'CurationService',
                category: LogCategory.system);

            try {
              // Subscribe to fetch specific video events by ID using proper streaming
              final filter = Filter(
                ids: missingEventIds,
              );
              final eventStream = _nostrService.subscribeToEvents(
                filters: [filter],
              );

              // Collect fetched videos and process them immediately
              final fetchedVideos = <VideoEvent>[];
              final completer = Completer<void>();
              late StreamSubscription<Event> streamSubscription;
              var receivedCount = 0;
              final targetCount = missingEventIds.length;

              streamSubscription = eventStream.listen(
                (event) {
                  try {
                    final video = VideoEvent.fromNostrEvent(event);
                    fetchedVideos.add(video);
                    receivedCount++;

                    Log.info(
                        '📹 Fetched trending video from relay ($receivedCount/$targetCount): ${video.title ?? video.id}',
                        name: 'CurationService',
                        category: LogCategory.system);

                    // Also add to video event service so it's cached
                    _videoEventService.addVideoEvent(video);

                    // Add to trending list immediately for progressive loading
                    trending.add(video);

                    // Complete early if we've received most videos or after reasonable batch
                    if (receivedCount >= targetCount || receivedCount >= 10) {
                      Log.info(
                          '⚡ Got $receivedCount trending videos, proceeding with what we have...',
                          name: 'CurationService',
                          category: LogCategory.system);
                      streamSubscription.cancel();
                      if (!completer.isCompleted) completer.complete();
                    }
                  } catch (e) {
                    Log.error('Failed to parse video event: $e',
                        name: 'CurationService', category: LogCategory.system);
                  }
                },
                onError: (error) {
                  Log.error(
                    'Trending video fetch stream error: $error',
                    name: 'CurationService',
                    category: LogCategory.system,
                  );
                  streamSubscription.cancel();
                  if (!completer.isCompleted) completer.complete();
                },
                onDone: () {
                  Log.debug(
                    '📡 Trending video stream closed - got what existed on relays',
                    name: 'CurationService',
                    category: LogCategory.system,
                  );
                  streamSubscription.cancel();
                  if (!completer.isCompleted) completer.complete();
                },
              );

              // Wait for completion or reasonable timeout (don't wait forever)
              await Future.any([
                completer.future,
                Future.delayed(
                    const Duration(seconds: 5)), // Short timeout for better UX
              ]);

              // Ensure stream is cancelled
              await streamSubscription.cancel();
              Log.info(
                  '✅ Fetched ${fetchedVideos.length}/${missingEventIds.length} trending videos from relays',
                  name: 'CurationService',
                  category: LogCategory.system);

              // Track videos that we failed to fetch - they likely no longer exist on relays
              final fetchedIds = fetchedVideos.map((v) => v.id).toSet();
              final actuallyMissingIds = missingEventIds
                  .where((id) => !fetchedIds.contains(id))
                  .toSet();

              if (actuallyMissingIds.isNotEmpty) {
                _missingVideoIds.addAll(actuallyMissingIds);
                Log.info(
                    '🚫 Marking ${actuallyMissingIds.length} videos as permanently missing (total tracked: ${_missingVideoIds.length})',
                    name: 'CurationService',
                    category: LogCategory.system);
              }
            } catch (e) {
              Log.error('Failed to fetch trending videos from relays: $e',
                  name: 'CurationService', category: LogCategory.system);
            }
          }

          if (trending.isNotEmpty) {
            // Sort by the order from analytics API
            final orderedTrending = <VideoEvent>[];
            for (final vineData in vinesData) {
              final eventId = vineData['eventId'] as String?;
              if (eventId != null) {
                final video = trending.firstWhere(
                  (v) => v.id == eventId,
                  orElse: () => VideoEvent(
                      id: '',
                      pubkey: '',
                      createdAt: 0,
                      content: '',
                      timestamp: DateTime.now()),
                );
                if (video.id.isNotEmpty) {
                  orderedTrending.add(video);
                }
              }
            }

            // Update the analytics trending cache
            final previousCount = _analyticsTrendingVideos.length;
            _analyticsTrendingVideos = orderedTrending;
            _lastTrendingFetch = DateTime.now();

            // Only log if there's a change in video count
            if (previousCount != orderedTrending.length) {
              Log.info(
                  '✅ Updated trending videos from analytics: ${orderedTrending.length} videos (was $previousCount)',
                  name: 'CurationService',
                  category: LogCategory.system);
            } else {
              Log.verbose(
                  '✅ Refreshed trending videos: ${orderedTrending.length} videos (no change)',
                  name: 'CurationService',
                  category: LogCategory.system);
            }
          } else {
            Log.error(
                '🚨 CRITICAL: No trending videos found after fetching from relays! '
                'Analytics API returned ${vinesData.length} trending video IDs, '
                'but none could be fetched from relays. Trending tab will be empty or show stale data. '
                'This indicates a serious relay connectivity issue.',
                name: 'CurationService',
                category: LogCategory.system);
          }
        } else {
          Log.warning('⚠️ No vines data in analytics response',
              name: 'CurationService', category: LogCategory.system);
        }
      } else {
        Log.warning(
            '❌ Analytics API returned ${response.statusCode}: ${response.body}',
            name: 'CurationService',
            category: LogCategory.system);
      }
    } catch (e) {
      Log.error('❌ Failed to fetch trending from analytics: $e',
          name: 'CurationService', category: LogCategory.system);
      // Continue with local algorithm fallback
    } finally {
      _isFetchingTrending = false;
    }
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
      Log.debug('Fetching kind 30005 curation sets from Nostr...',
          name: 'CurationService', category: LogCategory.system);

      // Query for video curation sets (kind 30005)
      final filter = Filter(
        kinds: [30005],
        authors: curatorPubkeys,
        limit: 500,
      );

      // Use bypassLimits for one-time fetch to get all results quickly
      final eventStream = _nostrService.subscribeToEvents(
        filters: [filter],
        bypassLimits: true,
      );

      int fetchedCount = 0;
      final completer = Completer<void>();

      // Listen for events with timeout
      final subscription = eventStream.listen(
        (event) {
          try {
            if (event.kind != 30005) {
              Log.warning(
                  'Received unexpected event kind ${event.kind} (expected 30005)',
                  name: 'CurationService',
                  category: LogCategory.system);
              return;
            }

            final curationSet = CurationSet.fromNostrEvent(event);
            _curationSets[curationSet.id] = curationSet;
            fetchedCount++;

            Log.verbose(
                'Fetched curation set: ${curationSet.title} (${curationSet.videoIds.length} videos)',
                name: 'CurationService',
                category: LogCategory.system);
          } catch (e) {
            Log.error('Failed to parse curation set from event: $e',
                name: 'CurationService', category: LogCategory.system);
          }
        },
        onError: (error) {
          Log.error('Error fetching curation sets: $error',
              name: 'CurationService', category: LogCategory.system);
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
              'Curation set fetch timed out after 10s (fetched $fetchedCount sets)',
              name: 'CurationService',
              category: LogCategory.system);
        },
      );

      await subscription.cancel();

      Log.debug('Fetched $fetchedCount curation sets from Nostr',
          name: 'CurationService', category: LogCategory.system);

      // If no sets were found, populate sample data as fallback
      if (fetchedCount == 0) {
        Log.debug('No curation sets found, using sample data',
            name: 'CurationService', category: LogCategory.system);
        _populateSampleSets();
      }

      _isLoading = false;
    } catch (e) {
      _error = 'Failed to refresh curation sets: $e';
      _isLoading = false;

      Log.error('Error refreshing curation sets: $e',
          name: 'CurationService', category: LogCategory.system);

      // Fallback to sample data on error
      _populateSampleSets();
    }
  }

  /// Subscribe to curation set updates
  Future<void> subscribeToCurationSets({List<String>? curatorPubkeys}) async {
    try {
      Log.debug('Subscribing to kind 30005 curation sets...',
          name: 'CurationService', category: LogCategory.system);

      // Query for video curation sets (kind 30005)
      final filter = {
        'kinds': [30005],
        'limit': 500,
      };

      // If specific curators provided, filter by them
      if (curatorPubkeys != null && curatorPubkeys.isNotEmpty) {
        filter['authors'] = curatorPubkeys;
      }

      // Subscribe to receive curation set events
      final eventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [30005],
            authors: curatorPubkeys,
            limit: 500,
          ),
        ],
      );

      eventStream.listen(
        (event) {
          try {
            // Debug: Check what kind of event we're receiving
            if (event.kind != 30005) {
              Log.warning(
                  'Received unexpected event kind ${event.kind} in curation subscription (expected 30005)',
                  name: 'CurationService',
                  category: LogCategory.system);
              return;
            }

            final curationSet = CurationSet.fromNostrEvent(event);
            _curationSets[curationSet.id] = curationSet;
            Log.verbose(
                'Received curation set: ${curationSet.title} (${curationSet.videoIds.length} videos)',
                name: 'CurationService',
                category: LogCategory.system);

            // Update the video cache for this set
            _updateVideoCache(curationSet);
          } catch (e) {
            Log.error('Failed to parse curation set from event: $e',
                name: 'CurationService', category: LogCategory.system);
          }
        },
        onError: (error) {
          Log.error('Error in curation set subscription: $error',
              name: 'CurationService', category: LogCategory.system);
        },
      );
    } catch (e) {
      Log.error('Error subscribing to curation sets: $e',
          name: 'CurationService', category: LogCategory.system);
    }
  }

  /// Update video cache for a specific curation set
  void _updateVideoCache(CurationSet curationSet) {
    final allVideos = _videoEventService.discoveryVideos;
    final setVideos = <VideoEvent>[];

    // Find videos matching the curation set's video IDs
    for (final videoId in curationSet.videoIds) {
      try {
        final video = allVideos.firstWhere(
          (v) => v.id == videoId,
        );
        setVideos.add(video);
      } catch (e) {
        // Video not found, skip it
      }
    }

    _setVideoCache[curationSet.id] = setVideos;
    Log.info(
        'Updated cache for ${curationSet.id}: ${setVideos.length} videos found',
        name: 'CurationService',
        category: LogCategory.system);
  }

  /// Publish status for a curation
  final Map<String, CurationPublishStatus> _publishStatuses = {};

  /// Currently publishing curations to prevent duplicate publishes
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
      ['client', 'diVine'], // Attribution
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

    // Create and sign event via AuthService
    final event = await _authService.createAndSignEvent(
      kind: 30005, // NIP-51 curation set kind
      content: description ?? title,
      tags: tags,
    );

    return event;
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
      Log.debug('Curation $id already being published, skipping duplicate',
          name: 'CurationService', category: LogCategory.system);
      return CurationPublishResult(
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
        Log.error('Failed to create and sign curation event',
            name: 'CurationService', category: LogCategory.system);

        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: false,
          failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
          lastAttemptAt: DateTime.now(),
          lastFailureReason: 'Failed to create and sign event',
        );

        return CurationPublishResult(
          success: false,
          successCount: 0,
          totalRelays: 0,
          errors: {'signing': 'Failed to create and sign event'},
        );
      }

      // Publish with timeout
      final broadcastFuture = _nostrService.broadcastEvent(event);
      final timeoutDuration = const Duration(seconds: 5);

      NostrBroadcastResult? broadcastResult;

      try {
        broadcastResult = await broadcastFuture.timeout(timeoutDuration);
      } on TimeoutException {
        Log.warning('Curation publish timed out after 5s: $id',
            name: 'CurationService', category: LogCategory.system);

        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: false,
          failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
          lastAttemptAt: DateTime.now(),
          lastFailureReason: 'Timeout after 5 seconds',
        );

        return CurationPublishResult(
          success: false,
          successCount: 0,
          totalRelays: 0,
          errors: {'timeout': 'Publish timed out after 5 seconds'},
        );
      }

      final successCount = broadcastResult.successCount;
      final totalRelays = broadcastResult.totalRelays;
      final isSuccess = successCount > 0;

      if (isSuccess) {
        // Mark as successfully published
        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: true,
          lastPublishedAt: DateTime.now(),
          publishedEventId: broadcastResult.event.id,
          successfulRelays: broadcastResult.results.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList(),
          lastAttemptAt: DateTime.now(),
        );

        Log.info('✅ Published curation "$title" to $successCount/$totalRelays relays',
            name: 'CurationService', category: LogCategory.system);
      } else {
        // Mark as failed
        _publishStatuses[id] = CurationPublishStatus(
          curationId: id,
          isPublishing: false,
          isPublished: false,
          failedAttempts: (_publishStatuses[id]?.failedAttempts ?? 0) + 1,
          lastAttemptAt: DateTime.now(),
          lastFailureReason: broadcastResult.errors.values.join('; '),
        );

        Log.warning('❌ Failed to publish curation "$title": 0/$totalRelays relays succeeded',
            name: 'CurationService', category: LogCategory.system);
      }

      // Build result
      final failedRelays = broadcastResult.results.entries
          .where((e) => e.value == false)
          .map((e) => e.key)
          .toList();

      return CurationPublishResult(
        success: isSuccess,
        successCount: successCount,
        totalRelays: totalRelays,
        eventId: isSuccess ? broadcastResult.event.id : null,
        errors: broadcastResult.errors,
        failedRelays: failedRelays,
      );
    } catch (e) {
      Log.error('Error publishing curation: $e',
          name: 'CurationService', category: LogCategory.system);

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

  /// Retry all unpublished curations with exponential backoff
  Future<void> retryUnpublishedCurations() async {
    final now = DateTime.now();

    for (final entry in _publishStatuses.entries) {
      final curationId = entry.key;
      final status = entry.value;

      // Skip if already published or currently publishing
      if (status.isPublished || status.isPublishing) continue;

      // Skip if max retries reached
      if (!status.shouldRetry) {
        Log.debug('Skipping retry for $curationId: max attempts reached',
            name: 'CurationService', category: LogCategory.system);
        continue;
      }

      // Calculate next retry time with exponential backoff
      final retryDelay = getRetryDelay(status.failedAttempts);
      final nextRetryTime = status.lastAttemptAt?.add(retryDelay);

      if (nextRetryTime == null || now.isBefore(nextRetryTime)) {
        Log.debug('Skipping retry for $curationId: backoff not elapsed',
            name: 'CurationService', category: LogCategory.system);
        continue;
      }

      Log.info('🔄 Retrying publish for curation $curationId (attempt ${status.failedAttempts + 1})',
          name: 'CurationService', category: LogCategory.system);

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
    }
  }

  /// Get retry delay based on attempt count (exponential backoff)
  Duration getRetryDelay(int attemptCount) {
    // Exponential backoff: 2^n seconds
    final seconds = 1 << attemptCount.clamp(0, 10); // Max ~17 minutes
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
      Log.debug('Creating curation set: $title',
          name: 'CurationService', category: LogCategory.system);

      // Publish to Nostr
      final result = await publishCuration(
        id: id,
        title: title,
        videoIds: videoIds,
        description: description,
        imageUrl: imageUrl,
      );

      return result.success;
    } catch (e) {
      Log.error('Error creating curation set: $e',
          name: 'CurationService', category: LogCategory.system);
      return false;
    }
  }

  /// Check if videos need updating and refresh cache
  void refreshIfNeeded() {
    final currentVideoCount = _videoEventService.discoveryVideos.length;
    final cachedCount = _setVideoCache.values.fold<int>(
      0,
      (sum, videos) => sum + videos.length,
    );

    // Refresh if we have new videos
    if (currentVideoCount > cachedCount) {
      _populateSampleSets();
    }
  }

  void dispose() {
    // Clean up any subscriptions
    // REFACTORED: Service no longer needs manual listener cleanup
  }
}
