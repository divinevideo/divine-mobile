// ABOUTME: Coordinates publishing an uploaded video to Nostr: builds and signs
// ABOUTME: the NIP-71 event, broadcasts it, and records the confirmed publish

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    hide NIP71VideoKinds, PendingUpload, UploadStatus;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/published_event_local_echo.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_event_tag_source.dart';
import 'package:openvine/services/video_publish/proofmode_publish_tagger.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/services/video_publish/video_audio_publisher.dart';
import 'package:openvine/services/video_publish/video_event_tags.dart';
import 'package:openvine/services/video_publish/video_imeta_builder.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/nostr_replacement_timestamp.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/services/video_publish/signed_event_relay_publisher.dart'
    show outerPublishTimeoutFor;
export 'package:openvine/services/video_publish/video_audio_publisher.dart'
    show AudioReuseConsentChecker;

/// Publishes processed videos to Nostr relays.
///
/// The coordinator of a direct upload's publish: it assembles the NIP-71
/// event from the focused builders under `video_publish/`, signs it through
/// [AuthService], hands the signed event to [SignedEventRelayPublisher], and
/// records the confirmed publish locally. Retry-safe by construction — a
/// signed event is cached against its upload so "Try Again" re-broadcasts
/// the same id instead of minting a duplicate.
class VideoEventPublisher {
  VideoEventPublisher({
    required UploadManager uploadManager,
    required NostrClient nostrService,
    AuthService? authService,
    PersonalEventCacheService? personalEventCache,
    VideoEventService? videoEventService,
    BlossomUploadService? blossomUploadService,
    ProfileRepository? profileRepository,
    AudioExtractionService? audioExtractionService,
    ProfileStatsDao? profileStatsDao,
    SavedSoundsService? savedSoundsService,
    SoundSyncRepository? Function()? soundSyncRepositoryGetter,
    EventApiClient? eventApiClient,
    String trustedRelayUrl = AppConstants.defaultRelayUrl,
    AudioReuseConsentChecker? audioReuseConsentChecker,
    IosDeviceAttestationService? iosDeviceAttestationService,
    PublishedEventLocalEcho? publishedEventLocalEcho,
    ProofModePublishTagger? proofModeTagger,
  }) : assert(
         proofModeTagger == null || iosDeviceAttestationService == null,
         'An injected proofModeTagger ignores iosDeviceAttestationService; '
         'give the attestation service to the tagger instead.',
       ),
       _uploadManager = uploadManager,
       _nostrService = nostrService,
       _authService = authService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _profileStatsDao = profileStatsDao,
       _publishedEventLocalEcho = publishedEventLocalEcho,
       _relayPublisher = SignedEventRelayPublisher(
         nostrClient: nostrService,
         eventApiClient: eventApiClient,
         trustedRelayUrl: trustedRelayUrl,
       ),
       _proofModeTagger =
           proofModeTagger ??
           ProofModePublishTagger(
             iosDeviceAttestation:
                 iosDeviceAttestationService ?? IosDeviceAttestationService(),
             currentPubkeyHex: () => authService?.currentPublicKeyHex,
           ) {
    _audioPublisher = VideoAudioPublisher(
      nostrClient: nostrService,
      relayPublisher: _relayPublisher,
      authService: authService,
      blossomUploadService: blossomUploadService,
      profileRepository: profileRepository,
      audioExtractionService: audioExtractionService,
      savedSoundsService: savedSoundsService,
      soundSyncRepositoryGetter: soundSyncRepositoryGetter,
      audioReuseConsentChecker: audioReuseConsentChecker,
    );
  }

  static const String _logName = 'VideoEventPublisher';

  final UploadManager _uploadManager;
  final NostrClient _nostrService;
  final AuthService? _authService;
  final PersonalEventCacheService? _personalEventCache;
  final VideoEventService? _videoEventService;
  final ProfileStatsDao? _profileStatsDao;

  /// Makes the published event readable before any relay can serve it back.
  /// Null disables the write (tests, callers with no storage wired).
  final PublishedEventLocalEcho? _publishedEventLocalEcho;
  final SignedEventRelayPublisher _relayPublisher;
  late final VideoAudioPublisher _audioPublisher;
  final ProofModePublishTagger _proofModeTagger;

  static const VideoImetaBuilder _imetaBuilder = VideoImetaBuilder();

  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;

  /// In-flight direct publishes keyed by the upload's d-tag
  /// ([PendingUpload.videoId]). Coalesces concurrent
  /// [publishDirectUpload] calls for the same upload so only one
  /// addressable event is signed and broadcast (#6018).
  final Map<String, Future<bool>> _inFlightDirectPublishes = {};

  /// The outer timeout that will bound the next WebSocket publish; see
  /// [SignedEventRelayPublisher.currentOuterPublishTimeout].
  Duration get currentOuterPublishTimeout =>
      _relayPublisher.currentOuterPublishTimeout;

  /// Configured authoritative relay used to classify account restrictions.
  @visibleForTesting
  String get trustedRelayUrlForTesting => _relayPublisher.trustedRelayUrl;

  /// Get publishing statistics
  Map<String, dynamic> get publishingStats => {
    'total_published': _totalEventsPublished,
    'total_failed': _totalEventsFailed,
    'last_publish_time': _lastPublishTime?.toIso8601String(),
  };

  /// Initialize the publisher
  Future<void> initialize() async {
    Log.debug(
      'Initializing VideoEventPublisher',
      name: _logName,
      category: LogCategory.video,
    );

    Log.info(
      'VideoEventPublisher initialized',
      name: _logName,
      category: LogCategory.video,
    );
  }

  /// Publishes an already-signed video [event] for [upload]; see
  /// [SignedEventRelayPublisher.publish] for the strategy.
  ///
  /// Throws [AccountRestrictedPublishException] when the authoritative REST
  /// endpoint or configured Divine relay reports that the account is suspended
  /// or banned.
  @visibleForTesting
  Future<bool> publishSignedVideoEvent({
    required PendingUpload upload,
    required Event event,
    bool isRetry = false,
  }) async {
    final outcome = await _relayPublisher.publish(event, isRetry: isRetry);
    return outcome == EventPublishOutcome.published;
  }

  /// Publish a video event with custom metadata
  ///
  /// Throws [AudioReuseNotPermittedException] when [selectedAudio] is not
  /// cleared for reuse — see [publishDirectUpload].
  /// Throws [AccountRestrictedPublishException] when an authoritative Divine
  /// publish surface reports that the account is suspended or banned.
  Future<bool> publishVideoEvent({
    required PendingUpload upload,
    String? title,
    String? description,
    List<String>? hashtags,
    int? expirationTimestamp,
    bool allowAudioReuse = false,
    Duration? thumbnailTimestamp,
    List<String> collaboratorPubkeys = const [],
    List<String> mentionedPubkeys = const [],
    String? inspiredByAddressableId,
    String? inspiredByRelayUrl,
    List<String> inspiredByNpubs = const [],
    List<ClipSourceCredit> clipSourceCredits = const [],
    AudioEvent? selectedAudio,
    AudioShareAttribution? audioShareAttribution,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
    String? language,
    String? contentWarning,
    VideoReplyContext? replyContext,
    bool addReplyToFeed = false,
    List<String> textTrackRefs = const [],
    String textTrackLang = 'en',
    void Function()? onEventSigned,
    void Function()? onAudioReuseDegraded,
  }) async {
    // Create a temporary upload with updated metadata
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );

    return publishDirectUpload(
      updatedUpload,
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: allowAudioReuse,
      collaboratorPubkeys: collaboratorPubkeys,
      mentionedPubkeys: mentionedPubkeys,
      inspiredByAddressableId: inspiredByAddressableId,
      inspiredByRelayUrl: inspiredByRelayUrl,
      inspiredByNpubs: inspiredByNpubs,
      clipSourceCredits: clipSourceCredits,
      selectedAudio: selectedAudio,
      audioShareAttribution: audioShareAttribution,
      selectedAudioEventId: selectedAudioEventId,
      selectedAudioRelay: selectedAudioRelay,
      language: language,
      contentWarning: contentWarning,
      thumbnailTimestamp: thumbnailTimestamp,
      replyContext: replyContext,
      addReplyToFeed: addReplyToFeed,
      textTrackRefs: textTrackRefs,
      textTrackLang: textTrackLang,
      onEventSigned: onEventSigned,
      onAudioReuseDegraded: onAudioReuseDegraded,
    );
  }

  /// Publish a video directly without polling (for direct upload)
  ///
  /// Concurrent calls for the same [PendingUpload.videoId] (the
  /// addressable event's d-tag) are coalesced: the second caller awaits
  /// the in-flight publish's result instead of signing and broadcasting
  /// a duplicate event with a fresh id (#6018). The audio-reuse step can
  /// keep a publish in flight for 20s+, which is the window where the
  /// duplicates were minted.
  ///
  /// Returns `false` when the event could not be signed or broadcast, and
  /// when `selectedAudio`'s reuse consent could not be verified — the legacy
  /// source-video lookup cannot tell a refusal from an unreachable relay, so
  /// it is treated as a transport failure a retry can clear.
  ///
  /// Throws:
  ///
  /// * [AudioReuseNotPermittedException] if `selectedAudio`'s own event
  ///   forbids reuse ([AudioEvent.hasExplicitReuseConsent] without
  ///   [AudioEvent.allowsReuse]). That evidence needs no relay, so it is a
  ///   refusal rather than a transport failure and is raised instead of
  ///   folded into `false`.
  /// * [AccountRestrictedPublishException] if an authoritative Divine publish
  ///   surface reports that the signed-in account is suspended or banned.
  Future<bool> publishDirectUpload(
    PendingUpload upload, {
    int? expirationTimestamp,
    bool allowAudioReuse = false,
    List<String> collaboratorPubkeys = const [],
    List<String> mentionedPubkeys = const [],
    Duration? thumbnailTimestamp,
    String? inspiredByAddressableId,
    String? inspiredByRelayUrl,
    List<String> inspiredByNpubs = const [],
    List<ClipSourceCredit> clipSourceCredits = const [],
    AudioEvent? selectedAudio,
    AudioShareAttribution? audioShareAttribution,
    String? selectedAudioEventId,
    String? selectedAudioRelay,
    String? language,
    String? contentWarning,
    VideoReplyContext? replyContext,
    bool addReplyToFeed = false,
    List<String> textTrackRefs = const [],
    String textTrackLang = 'en',
    void Function()? onEventSigned,
    void Function()? onAudioReuseDegraded,
  }) async {
    final videoId = upload.videoId;
    if (videoId == null || upload.cdnUrl == null) {
      Log.error(
        'Cannot publish upload - missing videoId or cdnUrl',
        name: _logName,
        category: LogCategory.video,
      );
      return false;
    }

    final inFlight = _inFlightDirectPublishes[videoId];
    if (inFlight != null) {
      Log.warning(
        'Publish already in flight for video $videoId - awaiting its '
        'result instead of signing a duplicate event',
        name: _logName,
        category: LogCategory.video,
      );
      return inFlight;
    }

    final publish = _publishDirectUploadUnlocked(
      upload,
      expirationTimestamp: expirationTimestamp,
      allowAudioReuse: allowAudioReuse,
      collaboratorPubkeys: collaboratorPubkeys,
      mentionedPubkeys: mentionedPubkeys,
      thumbnailTimestamp: thumbnailTimestamp,
      inspiredByAddressableId: inspiredByAddressableId,
      inspiredByRelayUrl: inspiredByRelayUrl,
      inspiredByNpubs: inspiredByNpubs,
      clipSourceCredits: clipSourceCredits,
      selectedAudio: selectedAudio,
      audioShareAttribution: audioShareAttribution,
      selectedAudioEventId: selectedAudioEventId,
      selectedAudioRelay: selectedAudioRelay,
      language: language,
      contentWarning: contentWarning,
      replyContext: replyContext,
      addReplyToFeed: addReplyToFeed,
      textTrackRefs: textTrackRefs,
      textTrackLang: textTrackLang,
      onEventSigned: onEventSigned,
      onAudioReuseDegraded: onAudioReuseDegraded,
    );
    _inFlightDirectPublishes[videoId] = publish;
    try {
      return await publish;
    } finally {
      final _ = _inFlightDirectPublishes.remove(videoId);
    }
  }

  /// Signs and broadcasts the video event. Must only be called from
  /// [publishDirectUpload], which holds the [_inFlightDirectPublishes]
  /// coalescing lock (#6018); calling it directly bypasses that lock and
  /// can mint a duplicate event. Every parameter is required, so a value
  /// [publishDirectUpload] forgets to forward fails to compile instead of
  /// silently falling back to a default.
  Future<bool> _publishDirectUploadUnlocked(
    PendingUpload upload, {
    required int? expirationTimestamp,
    required bool allowAudioReuse,
    required List<String> collaboratorPubkeys,
    required List<String> mentionedPubkeys,
    required Duration? thumbnailTimestamp,
    required String? inspiredByAddressableId,
    required String? inspiredByRelayUrl,
    required List<String> inspiredByNpubs,
    required List<ClipSourceCredit> clipSourceCredits,
    required AudioEvent? selectedAudio,
    required AudioShareAttribution? audioShareAttribution,
    required String? selectedAudioEventId,
    required String? selectedAudioRelay,
    required String? language,
    required String? contentWarning,
    required VideoReplyContext? replyContext,
    required bool addReplyToFeed,
    required List<String> textTrackRefs,
    required String textTrackLang,
    required void Function()? onEventSigned,
    required void Function()? onAudioReuseDegraded,
  }) async {
    // Validate that at least one video URL is publishable. This prevents
    // local file paths and known dead media hosts from being published.
    if (!VideoImetaBuilder.hasPublishableVideoUrl(upload)) {
      Log.error(
        '❌ Cannot publish - no valid HTTP video URLs found. '
        'cdnUrl=${upload.cdnUrl}, fallbackUrl=${upload.fallbackUrl}, '
        'streamingMp4Url=${upload.streamingMp4Url}, '
        'streamingHlsUrl=${upload.streamingHlsUrl}',
        name: _logName,
        category: LogCategory.video,
      );
      return false;
    }

    try {
      Log.debug(
        'Publishing direct upload: ${upload.videoId}',
        name: _logName,
        category: LogCategory.video,
      );

      // Generate unique identifier for the addressable event
      // Use videoId if available, otherwise generate from timestamp and upload ID
      final dTag =
          upload.videoId ??
          '${DateTime.now().millisecondsSinceEpoch}_${upload.id}';
      final tags = <List<String>>[
        ['d', dTag],
      ];

      if (replyContext != null) {
        addVideoReplyTags(tags, replyContext, addReplyToFeed: addReplyToFeed);
      }
      // Closed-caption refs, so a video edited with CC overlay captions
      // carries them from the first publish on.
      addTextTrackTags(tags, refs: textTrackRefs, lang: textTrackLang);

      final imetaTag = await _imetaBuilder.build(
        upload,
        thumbnailTimestamp: thumbnailTimestamp,
      );
      if (imetaTag == null) return false;
      tags.add(imetaTag);

      addVideoMetadataTags(
        tags,
        upload: upload,
        publishedAt: DateTime.now(),
        language: language,
        contentWarning: contentWarning,
        expirationTimestamp: expirationTimestamp,
      );
      addVideoCreditTags(
        tags,
        selfPubkeyHex: _authService?.currentPublicKeyHex,
        isReply: replyContext != null,
        collaboratorPubkeys: collaboratorPubkeys,
        mentionedPubkeys: mentionedPubkeys,
        inspiredByAddressableId: inspiredByAddressableId,
        inspiredByRelayUrl: inspiredByRelayUrl,
        inspiredByNpubs: inspiredByNpubs,
        clipSourceCredits: clipSourceCredits,
      );

      final audio = await _audioPublisher.resolveForPublish(
        upload: upload,
        videoDTag: dTag,
        allowAudioReuse: allowAudioReuse,
        selectedAudio: selectedAudio,
        audioShareAttribution: audioShareAttribution,
        selectedAudioEventId: selectedAudioEventId,
        selectedAudioRelay: selectedAudioRelay,
      );
      final bool audioReuseDegraded;
      switch (audio) {
        case VideoAudioBlocked():
          return false;
        case VideoAudioResolved(tags: final audioTags, :final reuseDegraded):
          audioReuseDegraded = reuseDegraded;
          tags.addAll(audioTags);
      }

      var proofTags = ProofModeTagResult.none;
      final storedProof = upload.hasProofMode ? upload.nativeProof : null;
      if (storedProof != null) {
        proofTags = await _proofModeTagger.addTags(
          tags,
          proof: storedProof,
          localVideoPath: upload.localVideoPath,
        );
      }

      // Append NIP-27 Inspired By person reference to content
      final content = withInspiredByContentReference(
        upload.description ?? upload.title ?? '',
        inspiredByNpubs,
      );

      final authService = _authService;
      if (authService == null) {
        Log.error(
          'Auth service is null - cannot create video event',
          name: _logName,
          category: LogCategory.video,
        );
        return false;
      }

      if (!authService.isAuthenticated) {
        Log.error(
          'User not authenticated - cannot create video event',
          name: _logName,
          category: LogCategory.video,
        );
        return false;
      }

      Log.debug(
        '📱 Creating and signing video event...',
        name: _logName,
        category: LogCategory.video,
      );
      Log.verbose(
        'Content: "$content"',
        name: _logName,
        category: LogCategory.video,
      );
      Log.verbose(
        'Tags: ${tags.length} tags',
        name: _logName,
        category: LogCategory.video,
      );

      final signWatch = Stopwatch()..start();
      final reusedEvent = _loadRetryableSignedEvent(upload);
      final Event? event;
      if (reusedEvent != null) {
        event = reusedEvent;
      } else {
        final attestedPubkeyHex = proofTags.attestedPubkeyHex;
        final proof = proofTags.proof;
        if (attestedPubkeyHex != null &&
            proof != null &&
            authService.currentPublicKeyHex != attestedPubkeyHex) {
          _proofModeTagger.clearDeviceAttestationTags(tags, proof: proof);
        }

        event = await authService.createAndSignEvent(
          kind: NIP71VideoKinds.getPreferredAddressableKind(), // NIP-71 addressable short video
          content: content,
          tags: tags,
        );
      }
      signWatch.stop();
      logPublishPhase(
        PublishPhases.nostrSign,
        signWatch.elapsed,
        detail: reusedEvent != null
            ? PublishPhases.reusedDetail
            : PublishPhases.signedDetail,
      );

      if (event == null) {
        Log.error(
          'Failed to create and sign video event - createAndSignEvent returned null',
          name: _logName,
          category: LogCategory.video,
        );
        return false;
      }

      // Signing is a remote Keycast round-trip (~0.3-1.4s measured), so the
      // caller gets a step here rather than waiting out the whole phase. Kept
      // below the null check so a failed signing cannot advance the bar.
      onEventSigned?.call();

      // A degraded event carries none of the audio markers the creator asked
      // for. Caching it would make "Try Again" reuse it verbatim (the reuse
      // path takes `reusedEvent ?? createAndSignEvent(...tags)` above, so
      // freshly rebuilt tags are dropped), permanently stranding the video
      // without its sound while each retry mints another orphan Kind 1063.
      // Skipping the write costs a re-sign on retry and lets the tags heal.
      if (upload.nostrEventId != event.id && !audioReuseDegraded) {
        await _persistRetryableSignedEvent(upload, event);
      }

      Log.info(
        'Created video event: ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );

      // Publish to Nostr relays with retry logic
      Log.info(
        '🚀 Starting relay publication for event ${event.id}',
        name: _logName,
        category: LogCategory.video,
      );

      final publishWatch = Stopwatch()..start();
      final publishResult = await publishSignedVideoEvent(
        upload: upload,
        event: event,
        isRetry: reusedEvent != null,
      );
      if (publishResult && audioReuseDegraded) {
        onAudioReuseDegraded?.call();
      }
      publishWatch.stop();
      logPublishPhase(PublishPhases.nostrPublish, publishWatch.elapsed);

      if (!publishResult) {
        Log.error(
          'Failed to publish to Nostr relays',
          name: _logName,
          category: LogCategory.video,
        );
        return false;
      }

      await _recordConfirmedPublish(
        upload,
        event,
        addToDiscoveryCache: replyContext == null || addReplyToFeed,
      );
      return true;
    } on AudioReuseNotPermittedException {
      // Not a publish failure the user can retry their way out of: the sound's
      // creator withheld reuse. Escape the generic catch below so the publish
      // layer can classify it and name the sound as the blocker.
      _totalEventsFailed++;
      rethrow;
    } on AccountRestrictedPublishException {
      _totalEventsFailed++;
      rethrow;
    } catch (e, stackTrace) {
      Log.error(
        'Error publishing direct upload: $e',
        name: _logName,
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: _logName,
        category: LogCategory.video,
      );
      _totalEventsFailed++;
      return false;
    }
  }

  /// Makes a relay-confirmed [event] visible locally: local echo, the
  /// discovery cache, the upload's published status, and the profile stats
  /// invalidation that bumps the creator's video count.
  Future<void> _recordConfirmedPublish(
    PendingUpload upload,
    Event event, {
    required bool addToDiscoveryCache,
  }) async {
    await _publishedEventLocalEcho?.record(event);

    final videoEventService = _videoEventService;
    if (videoEventService != null && addToDiscoveryCache) {
      try {
        videoEventService.addVideoEvent(VideoEvent.fromNostrEvent(event));
        Log.info(
          'Added confirmed video to discovery cache: ${event.id}',
          name: _logName,
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Failed to add confirmed video to discovery cache: $e',
          name: _logName,
          category: LogCategory.video,
        );
      }
    }

    await _uploadManager.updateUploadStatus(
      upload.id,
      UploadStatus.published,
      nostrEventId: event.id,
    );

    _totalEventsPublished++;
    _lastPublishTime = DateTime.now();

    // Invalidate profile stats cache so video count updates immediately
    final currentPubkey = _nostrService.publicKey;
    if (currentPubkey.isNotEmpty) {
      unawaited(_profileStatsDao?.deleteStats(currentPubkey));
      Log.debug(
        'Invalidated profile stats cache for new video',
        name: _logName,
        category: LogCategory.video,
      );
    }

    Log.info(
      'Successfully published direct upload: ${event.id}',
      name: _logName,
      category: LogCategory.video,
    );
    Log.debug(
      'Video URL: ${upload.cdnUrl}',
      name: _logName,
      category: LogCategory.video,
    );
  }

  Event? _loadRetryableSignedEvent(PendingUpload upload) {
    final cachedEventId = upload.nostrEventId;
    if (cachedEventId == null || cachedEventId.isEmpty) {
      return null;
    }

    final cachedEvent = _personalEventCache?.getEventById(cachedEventId);
    if (cachedEvent == null) {
      Log.warning(
        'Stored retry event $cachedEventId was missing from personal cache',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    Log.info(
      'Reusing cached signed video event for retry: ${cachedEvent.id}',
      name: _logName,
      category: LogCategory.video,
    );
    return cachedEvent;
  }

  Future<void> _persistRetryableSignedEvent(
    PendingUpload upload,
    Event event,
  ) async {
    _personalEventCache?.cacheUserEvent(event);
    await _uploadManager.updateUploadStatus(
      upload.id,
      upload.status,
      nostrEventId: event.id,
    );
  }

  /// Republish a video event with added text-track tags for subtitles.
  ///
  /// Strips any existing text-track tags from the original event, then emits
  /// one tag per ref ([textTrackRef] followed by each entry in
  /// [extraTextTrackRefs]) for read-time redundancy. Returns the updated
  /// video event after relay acceptance, or `null` if publishing failed.
  ///
  /// Throws [AccountRestrictedPublishException] when the configured Divine
  /// relay reports that the account is suspended or banned.
  Future<VideoEvent?> republishWithSubtitles({
    required VideoEvent existingEvent,
    required String textTrackRef,
    List<String> extraTextTrackRefs = const [],
    String textTrackLang = 'en',
  }) async {
    // Start from the original Nostr event tags, stripping old text-track tags.
    final tags =
        sourceOriginalVideoTags(
              video: existingEvent,
              personalEventCache: _personalEventCache,
            )
            .where((t) => t.isNotEmpty && t.first != 'text-track')
            .map(List<String>.from)
            .toList();

    if (!tags.any((tag) => tag.length >= 2 && tag.first == 'd')) {
      Log.error(
        'Cannot republish subtitles for video ${existingEvent.id}: missing d tag',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    addTextTrackTags(
      tags,
      refs: [textTrackRef, ...extraTextTrackRefs],
      lang: textTrackLang,
    );

    // Sign the updated event
    final event = await _authService?.createAndSignEvent(
      kind: NIP71VideoKinds.getPreferredAddressableKind(),
      content: existingEvent.content,
      tags: tags,
      createdAt: nextReplacementCreatedAt(existingEvent),
    );

    if (event == null) {
      Log.error(
        'Failed to sign republished event with subtitles',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    // Publish to relays before updating local cache. A WebSocket send is not
    // enough here; rejected subtitle republishes must not appear locally.
    final published =
        await _relayPublisher.publishViaWebSocket(event) ==
        EventPublishOutcome.published;
    if (!published) return null;

    final updatedVideo = VideoEvent.fromNostrEvent(event);

    try {
      _personalEventCache?.cacheUserEvent(event);
      _videoEventService?.updateVideoEvent(updatedVideo);
    } catch (e) {
      Log.warning(
        'Failed to update local cache after subtitle republish: $e',
        name: _logName,
        category: LogCategory.video,
      );
    }

    return updatedVideo;
  }

  /// Publishes a Kind 39307 subtitle event for [video] and returns its
  /// addressable ref `39307:<pubkey>:subtitles:<vineId>`, or `null` on
  /// failure (not authenticated, no addressable id, sign/publish failed).
  ///
  /// Throws [AccountRestrictedPublishException] when the configured Divine
  /// relay reports that the account is suspended or banned.
  Future<String?> publishSubtitleEvent({
    required VideoEvent video,
    required String vttContent,
    required String blossomUrl,
    String lang = 'en',
  }) async {
    final vineId = video.vineId;
    if (vineId == null || vineId.isEmpty) return null;
    return publishSubtitleTrack(
      vineId: vineId,
      vttContent: vttContent,
      blossomUrl: blossomUrl,
      lang: lang,
    );
  }

  /// Publishes a Kind 39307 subtitle event for the video with [vineId] and
  /// returns its addressable ref `39307:<pubkey>:subtitles:<vineId>`, or
  /// `null` on failure.
  ///
  /// Unlike [publishSubtitleEvent] this needs no published [VideoEvent], so
  /// the initial publish can attach captions before the video event exists —
  /// addressable `a` refs make the forward reference safe.
  ///
  /// Throws [AccountRestrictedPublishException] when the configured Divine
  /// relay reports that the account is suspended or banned.
  Future<String?> publishSubtitleTrack({
    required String vineId,
    required String vttContent,
    required String blossomUrl,
    String lang = 'en',
  }) async {
    final pubkey = _authService?.currentPublicKeyHex;
    if (pubkey == null || vineId.isEmpty) return null;

    final dTag = 'subtitles:$vineId';
    final videoKind = NIP71VideoKinds.getPreferredAddressableKind();

    final event = await _authService?.createAndSignEvent(
      kind: NIP71VideoKinds.subtitleEventKind,
      content: vttContent,
      tags: [
        ['d', dTag],
        ['a', '$videoKind:$pubkey:$vineId'],
        ['url', blossomUrl],
        ['m', 'text/vtt'],
        ['l', lang],
      ],
    );
    if (event == null) {
      Log.error(
        'Failed to sign subtitle event',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final ok =
        await _relayPublisher.publishViaWebSocket(event) ==
        EventPublishOutcome.published;
    if (!ok) {
      Log.warning(
        'Failed to publish subtitle event',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
    return '${NIP71VideoKinds.subtitleEventKind}:$pubkey:$dTag';
  }

  void dispose() {
    Log.debug(
      'Disposing VideoEventPublisher',
      name: _logName,
      category: LogCategory.video,
    );
    _relayPublisher.dispose();
  }
}
