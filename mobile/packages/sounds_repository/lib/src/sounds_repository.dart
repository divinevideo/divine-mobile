// ABOUTME: Repository for fetching and caching Kind 1063
// audio events from Nostr relays.
// ABOUTME: Provides methods to query sounds (trending,
// by creator, by usage count) for audio reuse.

import 'dart:async';

import 'package:models/models.dart'
    show AudioEvent, NIP71VideoKinds, VideoEvent, audioEventKind;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sounds_repository/src/sound_library_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

/// Repository for managing audio events (Kind 1063) for audio reuse.
///
/// Responsibilities:
/// - Fetching Kind 1063 audio events from Nostr relays
/// - In-memory caching of audio events
/// - Providing methods to query sounds (trending, by creator, by usage count)
/// - Supporting the Sounds Browser UI with reactive streams
///
/// Exposes a stream for reactive updates to the sounds list.
class SoundsRepository {
  /// Creates a [SoundsRepository].
  ///
  /// [nostrClient] is required for the Nostr Kind 1063 audio-event paths
  /// (trending / by-creator / by-id / usage counts). [soundLibraryApiClient]
  /// is optional and only required for the external proxy-search paths
  /// (`searchExternalLibrary` / `fetchExternalProviders`); when omitted those
  /// methods throw [StateError].
  SoundsRepository({
    required NostrClient nostrClient,
    SoundLibraryApiClient? soundLibraryApiClient,
  }) : _nostrClient = nostrClient,
       _soundLibraryApiClient = soundLibraryApiClient;

  /// Default cap on the video events one batched usage-count query pulls.
  ///
  /// Applies to the whole batch, not per sound — see
  /// [fetchVideosUsingSoundCounts].
  static const int maxBatchedUsageCountScan = 500;

  final NostrClient _nostrClient;
  final SoundLibraryApiClient? _soundLibraryApiClient;

  /// BehaviorSubject replays last value to late subscribers
  final _soundsSubject = BehaviorSubject<List<AudioEvent>>.seeded(const []);

  /// Stream of cached audio events for reactive UI updates
  Stream<List<AudioEvent>> get soundsStream => _soundsSubject.stream;

  /// In-memory cache of audio events by event ID
  final Map<String, AudioEvent> _cache = {};

  /// Event IDs whose stable unresolved result was already reported.
  final Set<String> _loggedUnresolvedSoundIds = {};

  /// Active subscription for real-time updates
  StreamSubscription<Event>? _subscription;
  String? _subscriptionId;

  bool _isInitialized = false;

  /// Whether the repository has been initialized
  bool get isInitialized => _isInitialized;

  /// Get all cached sounds as an unmodifiable list
  List<AudioEvent> get cachedSounds =>
      List.unmodifiable(_cache.values.toList());

  /// Get count of cached sounds
  int get cachedSoundCount => _cache.length;

  /// Emit current cache state to stream
  void _emitSounds() {
    if (!_soundsSubject.isClosed) {
      final sounds = _cache.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _soundsSubject.add(List.unmodifiable(sounds));
    }
  }

  /// Initialize the repository and start fetching sounds.
  ///
  /// Call this before using the repository to ensure sounds are loaded.
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.debug(
      'Initializing SoundsRepository',
      name: 'SoundsRepository',
      category: LogCategory.system,
    );

    try {
      // Fetch initial trending sounds
      await fetchTrendingSounds();

      // Subscribe for real-time updates
      _subscribeToAudioEvents();

      _isInitialized = true;

      Log.info(
        'SoundsRepository initialized: ${_cache.length} sounds cached',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    } on Exception catch (e) {
      Log.error(
        'SoundsRepository initialization error: $e',
        name: 'SoundsRepository',
        category: LogCategory.system,
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (_subscriptionId != null) {
      await _nostrClient.unsubscribe(_subscriptionId!);
      _subscriptionId = null;
    }
    await _soundsSubject.close();
    _cache.clear();
    _loggedUnresolvedSoundIds.clear();
  }

  /// Fetch trending/recent sounds from relays.
  ///
  /// Returns a list of [AudioEvent]s sorted by creation time (newest first).
  /// Results are cached for future use.
  Future<List<AudioEvent>> fetchTrendingSounds({int limit = 50}) async {
    Log.debug(
      'Fetching trending sounds (limit: $limit)',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(kinds: const [audioEventKind], limit: limit),
      ]);

      final audioEvents = _processAndCacheEvents(events);

      Log.debug(
        'Fetched ${audioEvents.length} trending sounds',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching trending sounds: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch sounds by a specific creator pubkey.
  ///
  /// Returns a list of [AudioEvent]s created by the specified user.
  /// Results are cached for future use.
  Future<List<AudioEvent>> fetchSoundsByCreator(
    String pubkey, {
    int limit = 50,
  }) async {
    if (pubkey.isEmpty) {
      Log.debug(
        'Empty pubkey provided to fetchSoundsByCreator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return [];
    }

    Log.debug(
      'Fetching sounds by creator: ${pubkeyForLogs(pubkey)}',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(authors: [pubkey], kinds: const [audioEventKind], limit: limit),
      ]);

      final audioEvents = _processAndCacheEvents(events);

      Log.debug(
        'Fetched ${audioEvents.length} sounds by creator',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return audioEvents;
    } catch (e) {
      Log.error(
        'Error fetching sounds by creator: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch a specific sound by event ID.
  ///
  /// First checks the cache, then falls back to network query.
  /// Returns null if the sound is not found.
  Future<AudioEvent?> fetchSoundById(String eventId) async {
    if (eventId.isEmpty) {
      Log.debug(
        'Empty eventId provided to fetchSoundById',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }

    // Check cache first
    final cached = _cache[eventId];
    if (cached != null) {
      Log.debug(
        'Sound found in cache: $eventId',
        name: 'SoundsRepository',
        category: LogCategory.storage,
      );
      return cached;
    }

    Log.debug(
      'Fetching sound by ID: $eventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final event = await _nostrClient.fetchEventById(eventId);

      if (event == null) {
        _logUnresolvedSoundOnce(eventId, 'Sound not found: $eventId');
        return null;
      }

      if (event.kind == audioEventKind) {
        final audioEvent = AudioEvent.fromNostrEvent(event);
        _cacheSound(audioEvent);
        return audioEvent;
      }

      // A video's "original sound" is not a standalone Kind 1063 event — it is
      // the audio track of the source Kind 34236 video. When a reusing video
      // references that source video as its audio, synthesize the
      // original-sound attribution so the original creator is credited
      // instead of the reusing user. Title is left null so the reader
      // localizes "Original sound" and resolves the creator name from the
      // synthesized pubkey. Cached under [eventId] directly (not via
      // [_cacheSound]) so it is not surfaced in the sounds-browser stream.
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        try {
          final audioEvent = AudioEvent.fromVideoOriginalSound(
            VideoEvent.fromNostrEvent(event),
          );
          _cache[eventId] = audioEvent;
          return audioEvent;
        } on Object catch (e) {
          // coverage:ignore-start
          // Defensive net for adversarial relay data. For a video-kind event
          // `VideoEvent.fromNostrEvent` does not throw (the kind is already
          // validated by the `isVideoKind` gate above and `Event.tags` is
          // strictly typed), so this is unreachable in practice; kept to
          // downgrade a hypothetical parse failure to a warning + null instead
          // of the outer error + rethrow.
          _logUnresolvedSoundOnce(
            eventId,
            'Failed to synthesize original sound from video $eventId: $e',
          );
          return null;
          // coverage:ignore-end
        }
      }

      _logUnresolvedSoundOnce(
        eventId,
        'Event $eventId is not a Kind $audioEventKind audio event '
        '(got Kind ${event.kind})',
      );
      return null;
    } catch (e) {
      Log.error(
        'Error fetching sound by ID: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Get a sound from the cache without making a network request.
  ///
  /// Returns null if the sound is not in the cache.
  AudioEvent? getSoundFromCache(String eventId) {
    return _cache[eventId];
  }

  void _logUnresolvedSoundOnce(String eventId, String message) {
    if (!_loggedUnresolvedSoundIds.add(eventId)) return;
    Log.warning(
      message,
      name: 'SoundsRepository',
      category: LogCategory.api,
    );
  }

  /// Fetch the count of videos using a specific sound, via NIP-45 COUNT.
  ///
  /// The count is based on Kind 34236 video events that reference the
  /// audio event ID in their tags.
  ///
  /// Returns `null` when the count is unknown, because no relay answered or
  /// the query failed. An empty [audioEventId] cannot be referenced by any
  /// video, so it returns 0.
  Future<int?> fetchVideosUsingSoundCount(String audioEventId) async {
    if (audioEventId.isEmpty) {
      Log.debug(
        'Empty audioEventId provided to fetchVideosUsingSoundCount',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return 0;
    }

    Log.debug(
      'Fetching video count for audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      // Query for Kind 34236 video events that reference this audio event
      final result = await _nostrClient.countEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: [audioEventId], // Events referencing this audio
        ),
      ]);

      Log.debug(
        'Video count for audio $audioEventId: ${result.count}'
        '${result.approximate ? ' (approximate)' : ''}',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return result.count;
    } on CountUnavailableException catch (e) {
      Log.debug(
        'Video count for audio $audioEventId unavailable: ${e.reason}',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    } on Exception catch (e) {
      Log.error(
        'Error fetching video count for audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return null;
    }
  }

  /// Fetch reuse counts for many sounds in a single relay round trip.
  ///
  /// [fetchVideosUsingSoundCount] costs one COUNT request per sound, so a list
  /// that renders a count per row would fan out one relay request per row. This
  /// issues a single query filtered on every requested id and tallies the `e`
  /// tags client-side, so a list costs one round trip no matter how many sounds
  /// it shows.
  ///
  /// A video is counted for an id when it carries an `e` tag holding that id —
  /// the same match the relay applies to `#e`, so a batched entry equals what
  /// [fetchVideosUsingSoundCount] would report for the same sound. A video that
  /// repeats the same reference is still counted once.
  ///
  /// The result holds an entry for every non-empty requested id, mapping to 0
  /// when nothing references it. Returns an empty map without querying when
  /// [audioEventIds] contains no non-empty id.
  ///
  /// Counts saturate at [limit], which caps the video events pulled for the
  /// whole batch rather than per sound, so a batch whose true total exceeds it
  /// under-reports. That is the trade for the single round trip; raise it only
  /// with the extra bandwidth in mind, since these are full video events.
  ///
  /// Throws whatever the underlying query throws; callers that would rather
  /// show no counts than an error should catch it.
  Future<Map<String, int>> fetchVideosUsingSoundCounts(
    Iterable<String> audioEventIds, {
    int limit = maxBatchedUsageCountScan,
  }) async {
    final ids = {
      for (final id in audioEventIds)
        if (id.isNotEmpty) id,
    };
    if (ids.isEmpty) {
      Log.debug(
        'No audio event ids provided to fetchVideosUsingSoundCounts',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      return const {};
    }

    Log.debug(
      'Fetching batched video counts for ${ids.length} sounds',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: ids.toList(),
          limit: limit,
        ),
      ]);

      final counts = {for (final id in ids) id: 0};
      for (final event in events) {
        final referenced = <String>{};
        for (final tag in event.tags) {
          if (tag.length >= 2 && tag[0] == 'e' && counts.containsKey(tag[1])) {
            referenced.add(tag[1]);
          }
        }
        for (final id in referenced) {
          counts[id] = counts[id]! + 1;
        }
      }

      Log.debug(
        'Batched video counts resolved from ${events.length} video events',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return counts;
    } catch (e) {
      Log.error(
        'Error fetching batched video counts: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Fetch videos that use a specific sound.
  ///
  /// Returns a list of video event IDs that reference the audio event.
  Future<List<String>> fetchVideosUsingSound(
    String audioEventId, {
    int limit = 50,
  }) async {
    if (audioEventId.isEmpty) {
      return [];
    }

    Log.debug(
      'Fetching videos using audio: $audioEventId',
      name: 'SoundsRepository',
      category: LogCategory.api,
    );

    try {
      final events = await _nostrClient.queryEvents([
        Filter(
          kinds: const [NIP71VideoKinds.addressableShortVideo],
          e: [audioEventId],
          limit: limit,
        ),
      ]);

      final videoIds = events.map((e) => e.id).toList();

      Log.debug(
        'Found ${videoIds.length} videos using audio',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );

      return videoIds;
    } catch (e) {
      Log.error(
        'Error fetching videos using audio: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
      rethrow;
    }
  }

  /// Subscribe to real-time audio event updates.
  void _subscribeToAudioEvents() {
    Log.debug(
      'Subscribing to audio events',
      name: 'SoundsRepository',
      category: LogCategory.relay,
    );

    _subscriptionId = 'sounds_repo_audio_events';

    final eventStream = _nostrClient.subscribe([
      Filter(kinds: const [audioEventKind], limit: 100),
    ], subscriptionId: _subscriptionId);

    _subscription = eventStream.listen(
      (event) {
        if (event.kind == audioEventKind) {
          _processAndCacheEvent(event);
        }
      },
      onError: (Object error) {
        Log.error(
          'Audio events subscription error: $error',
          name: 'SoundsRepository',
          category: LogCategory.relay,
        );
      },
    );
  }

  /// Process and cache a single Nostr event as an AudioEvent.
  void _processAndCacheEvent(Event event) {
    try {
      final audioEvent = AudioEvent.fromNostrEvent(event);
      _cacheSound(audioEvent);
      // coverage:ignore-start
    } on Exception catch (e) {
      Log.warning(
        'Failed to parse audio event: $e',
        name: 'SoundsRepository',
        category: LogCategory.api,
      );
    }
    // coverage:ignore-end
  }

  /// Process and cache multiple Nostr events.
  ///
  /// Returns a list of successfully parsed [AudioEvent]s sorted by creation
  /// time (newest first).
  List<AudioEvent> _processAndCacheEvents(List<Event> events) {
    final audioEvents = <AudioEvent>[];

    for (final event in events) {
      if (event.kind != audioEventKind) continue;

      try {
        final audioEvent = AudioEvent.fromNostrEvent(event);

        // Skip events without a title or playable URL
        if (audioEvent.title == null || audioEvent.title!.isEmpty) continue;
        if (audioEvent.url == null || audioEvent.url!.isEmpty) continue;

        _cache[audioEvent.id] = audioEvent;
        audioEvents.add(audioEvent);
        // coverage:ignore-start
      } on Exception catch (e) {
        Log.warning(
          'Failed to parse audio event: $e',
          name: 'SoundsRepository',
          category: LogCategory.api,
        );
      }
      // coverage:ignore-end
    }

    // Sort by creation time (newest first)
    audioEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (audioEvents.isNotEmpty) {
      _emitSounds();
    }

    return audioEvents;
  }

  /// Cache a single audio event and emit updated list.
  void _cacheSound(AudioEvent audioEvent) {
    final isNew = !_cache.containsKey(audioEvent.id);
    _cache[audioEvent.id] = audioEvent;

    if (isNew) {
      _emitSounds();
    }
  }

  /// Clear all cached sounds.
  ///
  /// Useful for debugging or forcing a refresh.
  void clearCache() {
    _cache.clear();
    _loggedUnresolvedSoundIds.clear();
    _emitSounds();
  }

  /// Refresh sounds by clearing cache and fetching fresh data.
  Future<void> refresh({int limit = 50}) async {
    clearCache();
    await fetchTrendingSounds(limit: limit);
  }

  /// List the proxy-backed external sound-library providers
  /// (divine / nostr / freesound / openverse).
  ///
  /// Throws [StateError] if this repository was constructed without a
  /// [SoundLibraryApiClient]. Throws [SoundLibraryApiException] on network
  /// or parse failures.
  Future<List<SoundLibraryProviderInfo>> fetchExternalProviders() {
    final client = _requireSoundLibraryApiClient();
    return client.fetchProviders();
  }

  /// Search the external sound library for [request].
  ///
  /// Composition logic for "which proxy provider to call" lives here, not in
  /// the BLoC or UI: the repository owns source-selection. Currently the
  /// proxy itself routes by `provider` query param (including `nostr` →
  /// Funnelcake), so this method delegates straight to the client; if we
  /// later need to fall back from `nostr` → relay on a 5xx, that fallback
  /// belongs in this method.
  ///
  /// Throws [StateError] if this repository was constructed without a
  /// [SoundLibraryApiClient]. Throws [SoundLibraryApiException] on network
  /// or parse failures.
  Future<SoundLibrarySearchResponse> searchExternalLibrary(
    SoundLibrarySearchRequest request,
  ) {
    final client = _requireSoundLibraryApiClient();
    return client.search(
      query: request.query,
      provider: request.provider,
      page: request.page,
      pageSize: request.pageSize,
      licenseType: request.licenseType,
    );
  }

  SoundLibraryApiClient _requireSoundLibraryApiClient() {
    final client = _soundLibraryApiClient;
    if (client == null) {
      throw StateError(
        'SoundsRepository was constructed without a SoundLibraryApiClient; '
        'external sound-library methods are unavailable.',
      );
    }
    return client;
  }
}
