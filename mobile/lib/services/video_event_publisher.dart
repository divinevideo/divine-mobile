// ABOUTME: Service for publishing videos directly to Nostr without backend processing
// ABOUTME: Handles event creation, signing, and relay broadcasting for direct uploads

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:blurhash_service/blurhash_service.dart';
//adding c2pa support for publishing c2pa manifest data into nostr
import 'package:creator_sync/creator_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    hide LogCategory, NIP71VideoKinds, PendingUpload, UploadStatus;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/published_event_local_echo.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_event_tag_source.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/log_tag_sanitizer.dart';
import 'package:openvine/utils/nostr_replacement_timestamp.dart';
import 'package:openvine/utils/proofmode_publishing_helpers.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part '../internal/video_event_publisher_audio.dart';
part '../internal/video_event_publisher_outcome.dart';

/// Floor for the derived outer publish timeout. Covers empty-config /
/// pre-init races where `configuredRelayCount` reads as `0` but the
/// publish would still queue against a tempRelay or wait on
/// initialisation. Also keeps the timeout from collapsing to the buffer
/// alone for `relayCount == 1`, which would leave no slack for normal
/// network latency.
const Duration _outerPublishTimeoutFloor = Duration(seconds: 10);

/// Ceiling for the derived outer publish timeout. Bounds worst-case
/// user-visible publish latency on misconfigured huge relay lists so a
/// user with 50 wedged relays does not wait several minutes for the
/// publish to give up.
///
/// **Trade-off**: clamping to the ceiling means the strict invariant
/// `outer >= inner_worst_case + buffer` only holds while
/// `derived <= ceiling`. Beyond that boundary (currently
/// `relayCount >= 12` with `perRelaySendTimeout = 5s` and `buffer = 5s`)
/// the buffer evaporates; from `relayCount == 13` upward the outer
/// guard can fire before the inner sequential fan-out completes,
/// re-introducing the original false-negative-publish failure mode for
/// that edge case. We accept this because the field worst case is
/// driven by `connecting`-state waits and post-handshake socket
/// wedges — not all configured relays — so practical fan-out times for
/// any reasonable config stay well under the ceiling. The retry loop in
/// [VideoEventPublisher.publishDirectUpload] absorbs the rare
/// false-negative when it does happen.
const Duration _outerPublishTimeoutCeiling = Duration(seconds: 60);

/// Buffer added on top of the per-relay × count derivation. Covers the
/// microtask queue drains between sequential `relay.send` calls inside
/// [RelayPool._sendCollect], plus a small allowance for log formatting
/// and other in-process scheduling jitter. Picked at one
/// `perRelaySendTimeout` worth of slack — small relative to the total
/// `perRelay × N` budget at default-config sizes (≈14% of the 35s outer
/// at N=6) but large enough to absorb realistic dispatch overhead on
/// cold-start without erosion as the relay count grows.
const Duration _outerPublishTimeoutBuffer = RelayPool.perRelaySendTimeout;

/// Computes the outer timeout that bounds the call into
/// [NostrClient.publishEventAwaitOk] inside `_publishEventToNostr`.
///
/// Derivation: `RelayPool.perRelaySendTimeout * relayCount + buffer`,
/// clamped to `[floor, ceiling]`. Encoding the relationship in code
/// keeps the outer guard from silently firing before the inner
/// sequential fan-out inside [RelayPool._sendCollect] can complete on
/// degraded networks, regardless of how many relays the user has
/// configured — up to the ceiling boundary documented on
/// [_outerPublishTimeoutCeiling].
///
/// **Caveats on `relayCount`**: the value passed in is treated as an
/// upper bound on the actual sequential fan-out width. Two factors
/// make the real fan-out narrower:
///   * `_sendCollect` skips relays without `writeAccess` for `EVENT`
///     messages, so read-only relays in the configured set don't
///     consume a per-relay slot.
///   * Callers passing `tempRelays` to `RelayPool.send` add fan-out
///     width that this helper cannot see; the canonical
///     [VideoEventPublisher] path does not, but a future caller might.
/// Both factors err on the conservative side — the derived bound is
/// never tighter than the real worst case.
///
/// Exposed at file scope so unit tests can assert the math directly
/// without spinning up a [NostrClient].
Duration outerPublishTimeoutFor(int relayCount) {
  final derived =
      RelayPool.perRelaySendTimeout * relayCount + _outerPublishTimeoutBuffer;
  if (derived < _outerPublishTimeoutFloor) return _outerPublishTimeoutFloor;
  if (derived > _outerPublishTimeoutCeiling) return _outerPublishTimeoutCeiling;
  return derived;
}

enum _RelayPresence { found, notFound, unknown }

/// Checks whether a selected sound may be reused in a newly published video.
///
/// The callback is injected by the app provider so this service remains
/// independent of Riverpod and can fail closed in tests and other wiring.
typedef AudioReuseConsentChecker = Future<bool> Function(AudioEvent sound);

/// Service for publishing processed videos to Nostr relays
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
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
  }) : _iosDeviceAttestation =
           iosDeviceAttestationService ?? IosDeviceAttestationService(),
       _uploadManager = uploadManager,
       _nostrService = nostrService,
       _authService = authService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _blossomUploadService = blossomUploadService,
       _profileRepository = profileRepository,
       _audioExtractionService = audioExtractionService,
       _profileStatsDao = profileStatsDao,
       _savedSoundsService = savedSoundsService,
       _soundSyncRepositoryGetter = soundSyncRepositoryGetter,
       _publishedEventLocalEcho = publishedEventLocalEcho,
       _eventApiClient = eventApiClient,
       _trustedRelayUrl = trustedRelayUrl,
       _audioReuseConsentChecker = audioReuseConsentChecker;
  final UploadManager _uploadManager;
  final NostrClient _nostrService;
  final AuthService? _authService;
  final PersonalEventCacheService? _personalEventCache;
  final VideoEventService? _videoEventService;
  final BlossomUploadService? _blossomUploadService;
  final ProfileRepository? _profileRepository;
  final AudioExtractionService? _audioExtractionService;
  final ProfileStatsDao? _profileStatsDao;
  final SavedSoundsService? _savedSoundsService;

  /// Reads the current cross-device sync repository at call time, or null
  /// until the vault key resolves. A getter rather than a captured value:
  /// this publisher lives behind a `keepAlive` Riverpod provider, and
  /// watching `soundSyncAvailabilityProvider` there would rebuild the
  /// provider — discarding `_inFlightDirectPublishes` (the #6018
  /// duplicate-publish coalescer) — every time the vault key resolves,
  /// which lands strictly later than the auth transitions this provider
  /// already rebuilds on. Best-effort: a mirror failure never affects
  /// video publishing, and the next Sounds-tab reconcile pass on this
  /// device picks up anything that did not mirror.
  final SoundSyncRepository? Function()? _soundSyncRepositoryGetter;
  final IosDeviceAttestationService _iosDeviceAttestation;

  /// REST-first publish client. When non-null, video events are published
  /// via `POST /api/events` first and only fall back to the WebSocket relay
  /// pool on transient REST failures. When null (legacy / test wiring), the
  /// publisher uses the WebSocket-only retry path.
  final EventApiClient? _eventApiClient;
  final String _trustedRelayUrl;

  /// Makes the published event readable before any relay can serve it back.
  /// Null disables the write (tests, callers with no storage wired).
  final PublishedEventLocalEcho? _publishedEventLocalEcho;
  final AudioReuseConsentChecker? _audioReuseConsentChecker;

  /// Verifies that a selected sound is permitted to be reused.
  ///
  /// Bundled, local, and provider sounds carry their own terms. Creators may
  /// reuse their own sound; every other sound needs current verified consent.
  ///
  /// Refusal, missing evidence, and failed lookup all fail closed.
  Future<bool> _canReuseSelectedAudio(AudioEvent sound) async {
    if (sound.isBundled ||
        sound.isLocalImport ||
        sound.isExternalProviderSound ||
        (sound.allowsReuse && !sound.requiresCurrentReuseVerification)) {
      return true;
    }

    final currentPubkey = _authService?.currentPublicKeyHex;
    if (currentPubkey != null && currentPubkey == sound.pubkey) {
      return true;
    }

    if (sound.hasExplicitReuseConsent) return false;

    final checker = _audioReuseConsentChecker;
    if (checker == null) return false;

    try {
      return await checker(sound);
    } catch (error, _) {
      Log.warning(
        'Unable to verify selected audio reuse consent; blocking reuse: '
        '$error',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }
  }

  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;

  /// In-flight direct publishes keyed by the upload's d-tag
  /// ([PendingUpload.videoId]). Coalesces concurrent
  /// [publishDirectUpload] calls for the same upload so only one
  /// addressable event is signed and broadcast (#6018).
  final Map<String, Future<bool>> _inFlightDirectPublishes = {};

  /// The outer timeout that will bound the next call into
  /// [NostrClient.publishEventAwaitOk] inside [_publishEventToNostr], computed
  /// live from [outerPublishTimeoutFor] and the current
  /// [NostrClient.configuredRelayCount].
  ///
  /// Exposed so tests can pin the production wiring between the helper
  /// and the call site without instrumenting `Future.timeout`. Reading
  /// this getter has no side effects.
  Duration get currentOuterPublishTimeout =>
      outerPublishTimeoutFor(_nostrService.configuredRelayCount);

  /// Configured authoritative relay used to classify account restrictions.
  @visibleForTesting
  String get trustedRelayUrlForTesting => _trustedRelayUrl;

  void _addReplyTags(List<List<String>> tags, VideoReplyContext context) {
    tags
      ..add(['E', context.rootEventId, '', context.rootAuthorPubkey])
      ..add(['K', context.rootEventKind.toString()])
      ..add(['P', context.rootAuthorPubkey]);

    final rootAddressableId = context.rootAddressableId;
    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      tags.add(['A', rootAddressableId, '']);
    }

    final parentCommentId = context.parentCommentId;
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      tags
        ..add([
          'e',
          parentCommentId,
          '',
          context.parentAuthorPubkey ?? context.rootAuthorPubkey,
        ])
        ..add(['k', EventKind.comment.toString()])
        ..add(['p', context.parentAuthorPubkey ?? context.rootAuthorPubkey]);
      return;
    }

    tags
      ..add(['e', context.rootEventId, '', context.rootAuthorPubkey])
      ..add(['k', context.rootEventKind.toString()])
      ..add(['p', context.rootAuthorPubkey]);

    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      tags.add(['a', rootAddressableId, '']);
    }
  }

  /// Initialize the publisher
  Future<void> initialize() async {
    Log.debug(
      'Initializing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );

    Log.info(
      'VideoEventPublisher initialized',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }

  /// Publishes a signed Nostr [event] to the configured relays and returns
  /// [_EventPublishOutcome.published] iff at least one relay confirmed
  /// acceptance with a NIP-20 `OK true` response
  /// ([PublishOutcome.confirmed]).
  ///
  /// A successful WebSocket send is NOT sufficient — relays can accept
  /// the frame and still reject the event at the protocol level (e.g.
  /// the divine relay's policy rejections). Treating a bare send as
  /// success used to mark rejected videos as published while they were
  /// silently dropped relay-side.
  ///
  /// **Failure contract** (returns [_EventPublishOutcome.transientFailure]):
  /// timeouts, ordinary relay rejection/no response, and inner exceptions.
  /// Video publication retries those outcomes with relay-presence recovery;
  /// single-shot audio/subtitle callers retain their existing null/false
  /// handling.
  ///
  /// **Sentinel-return contract** (audits #3593 / #4592): transport and domain
  /// failures intentionally remain outcomes rather than exceptions because all
  /// internal callers already have explicit recovery behavior. The one narrow
  /// exception is [AccountRestrictedPublishException]: an exact suspended or
  /// banned response from the configured authoritative relay is not retryable,
  /// and callers must preserve it so the UI can offer Account status instead of
  /// another futile attempt. Messages from other relays cannot establish Divine
  /// account standing, and any relay acceptance still wins.
  Future<_EventPublishOutcome> _publishEventToNostr(Event event) async {
    try {
      Log.debug(
        'Publishing event to Nostr relays: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log relay diagnostics
      Log.info(
        '🔍 Relay diagnostics: isInitialized=${_nostrService.isInitialized}, '
        'configured=${_nostrService.configuredRelayCount}, '
        'connected=${_nostrService.connectedRelayCount}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Configured relays: ${_nostrService.configuredRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '🔍 Connected relays: ${_nostrService.connectedRelays}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Ensure NostrClient is initialized before attempting broadcast
      if (!_nostrService.isInitialized) {
        Log.warning(
          '⚠️ NostrClient not initialized, initializing now...',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        await _nostrService.initialize();
      }

      Log.info(
        '📡 ${_nostrService.connectedRelayCount} relay(s) connected',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the complete event details
      Log.info(
        '📤 FULL EVENT TO PUBLISH:',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  ID: ${event.id}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Pubkey: ${pubkeyForLogs(event.pubkey)}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Created At: ${event.createdAt}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Kind: ${event.kind}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Content: "${event.content}"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Tags (${event.tags.length} total):',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      for (final tag in event.tags) {
        final sanitizedTag = sanitizeTagForLog(tag);
        Log.info(
          '    - ${sanitizedTag.join(", ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }
      Log.info(
        '  Signature: ${event.sig}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Valid: ${event.isValid}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.info(
        '  Is Signed: ${event.isSigned}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Log the raw JSON representation
      try {
        final eventMap = sanitizeEventJsonForLog(event.toJson());
        final jsonStr = jsonEncode(eventMap);
        Log.info(
          '📋 FULL EVENT JSON:',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.info(
          jsonStr,
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Could not serialize event to JSON: $e',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Publish and wait for a NIP-20 `OK` from at least one relay. The
      // [outerPublishTimeoutFor]-derived bound (perRelaySendTimeout ×
      // relayCount + buffer) is passed as the OK-wait timeout — the SDK's
      // publish tracker starts that timer before the send fan-out, so it
      // covers both the sequential sends and the OK wait.
      //
      // Defense-in-depth: the outer `Future.timeout` (one extra
      // [RelayPool.perRelaySendTimeout] of slack so the inner tracker
      // normally fires first) guards the code that runs before the
      // tracker exists — e.g. `retryDisconnectedRelays` stuck in
      // reconnect backoff. The retry loop in [publishDirectUpload] picks
      // up after each failed attempt.
      //
      // We use try/catch on [TimeoutException] rather than `.timeout(
      // onTimeout: ...)`: `publishEventAwaitOk` returns a non-nullable
      // [PublishOutcome], so an `onTimeout` closure could not return
      // null, and the try/catch shape also avoids the mocktail
      // runtime-type mismatch on stubbed futures.
      final outerTimeout = currentOuterPublishTimeout;
      PublishOutcome? publishOutcome;
      try {
        publishOutcome = await _nostrService
            .publishEventAwaitOk(event, timeout: outerTimeout)
            .timeout(outerTimeout + RelayPool.perRelaySendTimeout);
      } on TimeoutException {
        Log.error(
          '⏱️ publishEventAwaitOk timed out after '
          '${outerTimeout.inSeconds}s for event ${event.id} '
          '(relayCount=${_nostrService.configuredRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        publishOutcome = null;
      }

      if (publishOutcome != null && publishOutcome.confirmed) {
        Log.info(
          '📡 Event confirmed by relay(s): ${event.id} '
          '(${publishOutcome.summary}, '
          'configured=${_nostrService.configuredRelayCount}, '
          'connected=${_nostrService.connectedRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return _EventPublishOutcome.published;
      } else {
        final restrictionReason = publishOutcome == null
            ? null
            : accountRestrictedReasonFromOutcome(
                publishOutcome,
                trustedRelayUrl: _trustedRelayUrl,
              );
        if (restrictionReason != null) {
          Log.error(
            'Authoritative WebSocket relay restricted event ${event.id} '
            'from ${pubkeyForLogs(event.pubkey)}: $restrictionReason',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          throw AccountRestrictedPublishException(
            reason: restrictionReason,
            source: AccountRestrictionSource.webSocket,
          );
        }
        final failureReason = publishOutcome?.summary ?? 'timeout';
        Log.error(
          '❌ Event publish failed for ${event.id}: $failureReason '
          '(configured=${_nostrService.configuredRelayCount}, '
          'connected=${_nostrService.connectedRelayCount})',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.transientFailure;
      }
    } on AccountRestrictedPublishException {
      rethrow;
    } catch (e) {
      Log.error(
        'Failed to publish event to relays: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _EventPublishOutcome.transientFailure;
    }
  }

  /// Publishes an already-signed video [event] for [upload] using the
  /// REST-first strategy with an OK-aware WebSocket fallback.
  ///
  /// Behaviour when an [EventApiClient] is configured:
  /// 1. If [isRetry], first query configured relays by event id and by
  ///    `author+kind+d-tag`; if the event is already on a relay, mark it
  ///    published and stop (avoids re-publishing a previously accepted
  ///    event whose `OK` was lost).
  /// 2. Up to 3 attempts of `POST /api/events`. A 200 acceptance is
  ///    published; any retryable REST failure falls back to a WebSocket
  ///    publish that waits for relay `OK` frames.
  /// 3. Before each retry, re-check relay presence so a false-negative
  ///    WebSocket `OK` does not produce a duplicate publish.
  ///
  /// When no [EventApiClient] is configured, the legacy WebSocket-only
  /// retry path is used unchanged.
  ///
  /// The same signed [event] is reused across all attempts — no event is
  /// re-signed per retry, so relays deduplicate by id.
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
    final outcome = await _publishSignedVideoEventOutcome(
      upload: upload,
      event: event,
      isRetry: isRetry,
    );
    return outcome == _EventPublishOutcome.published;
  }

  Future<_EventPublishOutcome> _publishSignedVideoEventOutcome({
    required PendingUpload upload,
    required Event event,
    bool isRetry = false,
  }) async {
    final apiClient = _eventApiClient;
    if (apiClient == null) {
      return _publishWithWebSocketRetries(event);
    }

    if (isRetry && await _relayPresence(event) == _RelayPresence.found) {
      Log.info(
        '♻️ Recovered already-published video event ${event.id} from relays; '
        'skipping re-publish',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _EventPublishOutcome.published;
    }

    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      // A lost OK on a prior attempt can leave the event already stored on
      // a relay; re-check before re-broadcasting to avoid duplicates.
      if (attempt > 1 && await _relayPresence(event) == _RelayPresence.found) {
        Log.info(
          '♻️ Event ${event.id} found on relay before retry $attempt; '
          'marking published',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _EventPublishOutcome.published;
      }

      final outcome = await _publishViaRestThenWebSocket(apiClient, event);
      switch (outcome) {
        case _EventPublishOutcome.published:
          return _EventPublishOutcome.published;
        case _EventPublishOutcome.transientFailure:
          if (attempt < maxRetries) {
            final delaySeconds = attempt * 2; // 2s, 4s backoff
            Log.warning(
              '⚠️ Publish attempt $attempt failed, retrying in '
              '${delaySeconds}s...',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            await Future<void>.delayed(Duration(seconds: delaySeconds));
          } else {
            Log.error(
              '❌ All $maxRetries publish attempts failed',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
      }
    }
    if (await _relayPresence(event) == _RelayPresence.found) {
      return _EventPublishOutcome.published;
    }
    return _EventPublishOutcome.transientFailure;
  }

  /// One publish attempt: REST first, then an OK-aware WebSocket publish on a
  /// retryable REST failure.
  Future<_EventPublishOutcome> _publishViaRestThenWebSocket(
    EventApiClient apiClient,
    Event event,
  ) async {
    final restResult = await apiClient.publishEvent(event);
    switch (restResult) {
      case EventApiAccepted():
        return _EventPublishOutcome.published;
      case EventApiRejected(:final statusCode, :final reason):
        if (isAccountRestrictedReason(reason)) {
          Log.error(
            'Authoritative REST publish restricted event ${event.id} from '
            '${pubkeyForLogs(event.pubkey)}: $reason',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          throw AccountRestrictedPublishException(
            reason: reason,
            source: AccountRestrictionSource.rest,
          );
        }
        Log.warning(
          '⚠️ REST publish rejected ($statusCode) for ${event.id}: $reason; '
          'falling back to an OK-aware WebSocket publish',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _publishEventToNostr(event);
      case EventApiTransientFailure(:final reason):
        Log.warning(
          '⚠️ REST publish transient failure for ${event.id} ($reason); '
          'falling back to an OK-aware WebSocket publish',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return _publishEventToNostr(event);
    }
  }

  /// Legacy WebSocket-only publish with the original 3-attempt, 2s/4s backoff
  /// retry loop. Used only when no [EventApiClient] is configured.
  Future<_EventPublishOutcome> _publishWithWebSocketRetries(Event event) async {
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final outcome = await _publishEventToNostr(event);
      if (outcome == _EventPublishOutcome.published) {
        if (attempt > 1) {
          Log.info(
            '✅ Publish succeeded on attempt $attempt',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
        return _EventPublishOutcome.published;
      }

      if (attempt < maxRetries) {
        final delaySeconds = attempt * 2; // 2s, 4s backoff
        Log.warning(
          '⚠️ Publish attempt $attempt failed, retrying in ${delaySeconds}s...',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        await Future<void>.delayed(Duration(seconds: delaySeconds));
      } else {
        Log.error(
          '❌ All $maxRetries publish attempts failed',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }
    }
    return _EventPublishOutcome.transientFailure;
  }

  /// Checks whether [event] is already retrievable from the configured relays,
  /// queried both by event id and by `author+kind+d-tag`.
  Future<_RelayPresence> _relayPresence(Event event) async {
    try {
      final dTag = _dTagOf(event);
      final filters = <Filter>[
        Filter(ids: [event.id], limit: 1),
        if (dTag.isNotEmpty)
          Filter(
            authors: [event.pubkey],
            kinds: [event.kind],
            d: [dTag],
            limit: 1,
          ),
      ];
      final found = await _nostrService.queryEvents(filters, useCache: false);
      for (final candidate in found) {
        if (candidate.id == event.id) return _RelayPresence.found;
        if (candidate.pubkey == event.pubkey &&
            candidate.kind == event.kind &&
            _dTagOf(candidate) == dTag) {
          return _RelayPresence.found;
        }
      }
      return _RelayPresence.notFound;
    } catch (e) {
      Log.warning(
        'Recovery query failed for ${event.id}: $e',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _RelayPresence.unknown;
    }
  }

  String _dTagOf(Event event) {
    var dTag = '';
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'd') {
        dTag = tag[1];
        break;
      }
    }
    return dTag;
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    Log.info(
      'Reusing cached signed video event for retry: ${cachedEvent.id}',
      name: 'VideoEventPublisher',
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

  /// Get publishing statistics
  Map<String, dynamic> get publishingStats => {
    'total_published': _totalEventsPublished,
    'total_failed': _totalEventsFailed,
    'last_publish_time': _lastPublishTime?.toIso8601String(),
  };

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
    String? inspiredByNpub,
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
      inspiredByNpub: inspiredByNpub,
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
    String? inspiredByNpub,
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    final inFlight = _inFlightDirectPublishes[videoId];
    if (inFlight != null) {
      Log.warning(
        'Publish already in flight for video $videoId - awaiting its '
        'result instead of signing a duplicate event',
        name: 'VideoEventPublisher',
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
      inspiredByNpub: inspiredByNpub,
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
      _inFlightDirectPublishes.remove(videoId);
    }
  }

  /// Signs and broadcasts the video event. Must only be called from
  /// [publishDirectUpload], which holds the [_inFlightDirectPublishes]
  /// coalescing lock (#6018); calling it directly bypasses that lock and
  /// can mint a duplicate event. Keep this parameter list in lockstep with
  /// [publishDirectUpload] — every param has a default, so a forgotten
  /// forward at the call site fails silently rather than at compile time.
  Future<bool> _publishDirectUploadUnlocked(
    PendingUpload upload, {
    int? expirationTimestamp,
    bool allowAudioReuse = false,
    List<String> collaboratorPubkeys = const [],
    List<String> mentionedPubkeys = const [],
    Duration? thumbnailTimestamp,
    String? inspiredByAddressableId,
    String? inspiredByRelayUrl,
    String? inspiredByNpub,
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
    // Validate that at least one video URL is publishable.
    // This prevents local file paths and known dead media hosts from being
    // published to Nostr.
    final hasValidVideoUrl =
        _isPublishableMediaUrl(upload.streamingMp4Url) ||
        _isPublishableMediaUrl(upload.fallbackUrl) ||
        _isPublishableMediaUrl(upload.streamingHlsUrl) ||
        _isPublishableMediaUrl(upload.cdnUrl);
    if (!hasValidVideoUrl) {
      Log.error(
        '❌ Cannot publish - no valid HTTP video URLs found. '
        'cdnUrl=${upload.cdnUrl}, fallbackUrl=${upload.fallbackUrl}, '
        'streamingMp4Url=${upload.streamingMp4Url}, '
        'streamingHlsUrl=${upload.streamingHlsUrl}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      Log.debug(
        'Publishing direct upload: ${upload.videoId}',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Create NIP-71 compliant tags for the video
      final tags = <List<String>>[];

      // Generate unique identifier for the addressable event
      // Use videoId if available, otherwise generate from timestamp and upload ID
      final dTag =
          upload.videoId ??
          '${DateTime.now().millisecondsSinceEpoch}_${upload.id}';
      tags.add(['d', dTag]);

      if (replyContext != null) {
        _addReplyTags(tags, replyContext);
        if (addReplyToFeed) {
          tags.add(const [
            videoReplyVisibilityTagName,
            videoReplyVisibilityFeedValue,
          ]);
        }
      }

      // Closed-caption refs (same tag shape as republishWithSubtitles), so a
      // video edited with CC overlay captions carries them from the first
      // publish on.
      for (final ref in textTrackRefs) {
        tags.add([
          'text-track',
          ref,
          'wss://relay.divine.video',
          'captions',
          textTrackLang,
        ]);
      }

      // Build imeta tag components
      final imetaComponents = <String>[];

      final urlsAdded = <String>[];

      void addPublishableUrl({
        required String? url,
        required String fieldName,
        required String label,
      }) {
        if (url == null || url.isEmpty) return;
        if (!_isHttpUrl(url)) {
          Log.error(
            '⚠️ Skipping non-HTTP $fieldName (possible local path): $url',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          return;
        }
        if (VideoUrlResolver.isKnownDeadMediaUrl(url)) {
          Log.warning(
            '⚠️ Skipping known dead media URL in $fieldName: $url',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          return;
        }

        imetaComponents.add('url $url');
        urlsAdded.add('$label: $url');
      }

      addPublishableUrl(
        url: upload.streamingMp4Url,
        fieldName: 'streamingMp4Url',
        label: 'MP4(streaming)',
      );
      addPublishableUrl(
        url: upload.fallbackUrl,
        fieldName: 'fallbackUrl',
        label: 'MP4(R2 fallback)',
      );
      addPublishableUrl(
        url: upload.streamingHlsUrl,
        fieldName: 'streamingHlsUrl',
        label: 'HLS',
      );

      // Fallback to legacy cdnUrl if no Blossom-specific URLs
      if (urlsAdded.isEmpty) {
        addPublishableUrl(
          url: upload.cdnUrl,
          fieldName: 'cdnUrl',
          label: 'Legacy CDN',
        );
      }

      if (urlsAdded.isNotEmpty) {
        Log.info(
          '✅ Added video URLs to imeta:\n  ${urlsAdded.join("\n  ")}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } else {
        Log.error(
          '❌ No valid HTTP video URLs available - refusing to publish. '
          'This prevents local file paths from leaking into Nostr events.',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      imetaComponents.add('m video/mp4');

      // Use uploaded thumbnail CDN URL from Blossom upload
      if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
        final thumbnailPath = upload.thumbnailPath!;
        // Only include HTTP/HTTPS CDN URLs
        if (thumbnailPath.startsWith('http://') ||
            thumbnailPath.startsWith('https://')) {
          imetaComponents.add('image $thumbnailPath');
          Log.info(
            '✅ Using uploaded thumbnail CDN URL: $thumbnailPath',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Add dimensions to imeta if available
      if (upload.videoWidth != null && upload.videoHeight != null) {
        imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
      }

      // x: the digest is the upload's videoId, which every upload path sets
      // from the locally streamed HashUtil.sha256File over this same file —
      // _parseUploadResponse takes fileHash as a parameter and never reads a
      // hash off the response body, so this is value-identical to re-hashing
      // the file (which used to cost a measurable slice of the publish and
      // pulled the whole video into memory). Deliberately independent of the
      // local file still existing: funnelcake materializes events_local.sha256
      // from this sub-field and joins moderation labels on it, so a publish
      // landing after local cleanup must still carry it.
      final hash = upload.videoId;
      if (hash != null && hash.isNotEmpty) {
        imetaComponents.add('x $hash');
      }

      // size genuinely needs the file on disk.
      if (upload.localVideoPath.isNotEmpty) {
        try {
          final videoFile = File(upload.localVideoPath);
          if (videoFile.existsSync()) {
            final fileSize = videoFile.lengthSync();
            imetaComponents.add('size $fileSize');

            Log.verbose(
              'Added file metadata - size: $fileSize bytes, hash: $hash',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to calculate file metadata: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      // Blurhash for progressive image loading. The upload's thumbnail leg
      // already decoded the frame and derived it there, beside the video
      // transfer; deriving it again here meant a second video decode on the
      // critical path (measured at 568ms). Records written before the field
      // existed, and uploads whose thumbnail was reused from an earlier
      // attempt, still fall through to computing it.
      final storedBlurhash = upload.blurhash;
      if (storedBlurhash != null && storedBlurhash.isNotEmpty) {
        imetaComponents.add('blurhash $storedBlurhash');
        Log.info(
          '✅ Reused blurhash from upload: $storedBlurhash',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      } else if (upload.localVideoPath.isNotEmpty) {
        final blurhashWatch = Stopwatch()..start();
        try {
          Log.debug(
            '🎨 Generating blurhash from video thumbnail',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );

          // Extract thumbnail bytes with 10-second timeout
          final thumbnailBytes =
              await VideoThumbnailService.extractThumbnailBytes(
                videoPath: upload.localVideoPath,
                timestamp:
                    thumbnailTimestamp ??
                    VideoEditorConstants.defaultThumbnailExtractTime,
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  Log.warning(
                    '⏱️ Thumbnail extraction timed out after 10 seconds',
                    name: 'VideoEventPublisher',
                    category: LogCategory.video,
                  );
                  return null;
                },
              );

          if (thumbnailBytes != null) {
            // Generate blurhash with 3-second timeout
            final blurhash =
                await BlurhashService.generateBlurhash(
                  thumbnailBytes.bytes,
                ).timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {
                    Log.warning(
                      '⏱️ Blurhash generation timed out after 3 seconds',
                      name: 'VideoEventPublisher',
                      category: LogCategory.video,
                    );
                    return null;
                  },
                );

            if (blurhash != null && blurhash.isNotEmpty) {
              imetaComponents.add('blurhash $blurhash');
              Log.info(
                '✅ Generated blurhash: $blurhash',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            } else {
              Log.warning(
                'Blurhash generation returned null or empty',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }
          } else {
            Log.warning(
              'Thumbnail extraction returned null',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.warning(
            'Failed to generate blurhash: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing without blurhash - it's optional metadata
        } finally {
          blurhashWatch.stop();
          logPublishPhase(PublishPhases.nostrBlurhash, blurhashWatch.elapsed);
        }
      }

      // Add the complete imeta tag
      tags.add(['imeta', ...imetaComponents]);

      // Optional tags
      if (upload.title != null) tags.add(['title', upload.title!]);
      if (upload.description != null) {
        tags.add(['summary', upload.description!]);
      }

      // Add hashtags
      if (upload.hashtags != null) {
        for (final hashtag in upload.hashtags!) {
          tags.add(['t', hashtag]);
        }
      }

      // Add NIP-32 language self-labeling tags
      if (language != null && language.isNotEmpty) {
        tags.add(['L', 'ISO-639-1']);
        tags.add(['l', language, 'ISO-639-1']);
      }

      // Add NIP-32 content-warning self-labeling tags (NIP-36).
      if (contentWarning != null && contentWarning.isNotEmpty) {
        final warnings = contentWarning.split(',').map((value) => value.trim());
        tags.add(['content-warning', warnings.first]);
        tags.add(['L', 'content-warning']);
        for (final warning in warnings) {
          tags.add(['l', warning, 'content-warning']);
        }
      }

      // Add published_at tag (current timestamp)
      tags.add([
        'published_at',
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      ]);

      // Add duration tag if available
      if (upload.videoDuration != null) {
        tags.add(['duration', upload.videoDuration!.inSeconds.toString()]);
      }

      // Add alt tag for accessibility (use title or description as alt text)
      final altText = upload.title ?? upload.description ?? 'Short video';
      tags.add(['alt', altText]);

      // Add expiration tag if specified
      if (expirationTimestamp != null) {
        tags.add(['expiration', expirationTimestamp.toString()]);
      }

      tags.addAll(buildCollaboratorPTags(collaboratorPubkeys));
      tags.addAll(
        buildMentionPTags(
          mentionedPubkeys,
          excludedPubkeys: collaboratorPubkeys,
        ),
      );

      final inspiredByCreatorPubkey = inspiredByAddressableId == null
          ? null
          : InspiredByInfo(
              addressableId: inspiredByAddressableId,
            ).creatorPubkey.trim().toLowerCase();
      final selfPubkey = _authService?.currentPublicKeyHex
          ?.trim()
          .toLowerCase();
      final shouldEmitInspiredByATag =
          inspiredByAddressableId != null &&
          (inspiredByCreatorPubkey == null ||
              inspiredByCreatorPubkey.isEmpty ||
              inspiredByCreatorPubkey != selfPubkey);

      // Add Inspired By a-tag (specific video reference)
      if (shouldEmitInspiredByATag) {
        tags.add([
          'a',
          inspiredByAddressableId,
          inspiredByRelayUrl ?? inspiredByPTagRelayHint,
          'mention',
        ]);
      }

      tags.addAll(
        buildClipSourceCreditATags(
          clipSourceCredits: clipSourceCredits,
          selfPubkey: selfPubkey,
        ),
      );

      // p-tag the inspired-by creator(s) so they are notifiable. Added after
      // the collaborator/mention p-tags so those win dedup and caption
      // @token resolution keeps matching caption mentions first. Reply
      // videos never carry inspired-by p-tags: the model hides inspired-by
      // attribution on replies (VideoEvent.hasInspiredBy) and the edit flow
      // cannot own the tag there, so emitting one would notify a creator the
      // video never visibly credits and could never un-credit.
      if (replyContext == null) {
        tags.addAll(
          buildInspiredByPTags(
            existingTags: tags,
            addressableId: inspiredByAddressableId,
            npub: inspiredByNpub,
            relayHint: inspiredByRelayUrl,
            selfPubkey: _authService?.currentPublicKeyHex,
          ),
        );
        tags.addAll(
          buildClipSourceCreditPTags(
            existingTags: tags,
            clipSourceCredits: clipSourceCredits,
            selfPubkey: _authService?.currentPublicKeyHex,
          ),
        );
      }

      var selectedAudioReferenceId = selectedAudioEventId;
      var selectedAudioReferenceRelay = selectedAudioRelay;

      if (selectedAudio != null &&
          !await _canReuseSelectedAudio(selectedAudio)) {
        // Only the sound's own event carries evidence strong enough to tell
        // the user the sound is the blocker: `hasExplicitReuseConsent` is read
        // off the event already in hand, with no relay in the way. The legacy
        // resolver's `false` is fail-closed rather than a verdict — it also
        // covers an unreachable relay, a source video outside the 50-event
        // query window, and one the viewer's own block/content filters
        // dropped — so it stays an ordinary publish failure the user can
        // retry.
        if (selectedAudio.hasExplicitReuseConsent &&
            !selectedAudio.allowsReuse) {
          Log.warning(
            'Selected audio explicitly forbids reuse; blocking video publish',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          throw AudioReuseNotPermittedException(
            selectedAudio.attributionEventId ?? selectedAudio.id,
          );
        }
        Log.warning(
          'Could not verify selected audio reuse consent; blocking video '
          'publish',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      if (selectedAudio?.isLocalImport == true) {
        if (!allowAudioReuse) {
          selectedAudioReferenceId = null;
          selectedAudioReferenceRelay = null;
        } else {
          final attribution = audioShareAttribution;
          if (attribution == null || !attribution.isValid) {
            Log.error(
              'Reusable imported audio requires valid public attribution',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            return false;
          }

          final userPubkey = _authService?.currentPublicKeyHex;
          final relayHint = _audioRelayHint();
          if (userPubkey == null) {
            Log.error(
              'Cannot publish imported audio without an authenticated pubkey',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            return false;
          }

          selectedAudioReferenceId = await _publishImportedAudioEvent(
            audio: selectedAudio!,
            attribution: attribution,
            allowAudioReuse: true,
            videoDTag: dTag,
            pubkey: userPubkey,
            relayHint: relayHint,
          );
          selectedAudioReferenceRelay = relayHint;

          if (selectedAudioReferenceId == null) {
            Log.error(
              'Imported audio publishing failed; blocking video publish',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            return false;
          }
        }
      } else if (selectedAudio?.isExternalProviderSound == true) {
        final userPubkey = _authService?.currentPublicKeyHex;
        final relayHint = _audioRelayHint();
        if (userPubkey == null) return false;
        selectedAudioReferenceId = await _publishProviderAudioBridge(
          audio: selectedAudio!,
          allowAudioReuse: allowAudioReuse,
          videoDTag: dTag,
          pubkey: userPubkey,
          relayHint: relayHint,
        );
        selectedAudioReferenceRelay = relayHint;
        if (selectedAudioReferenceId == null) {
          // Only a creator who asked for reusable audio/credit loses the
          // publish over a missing bridge; otherwise the video ships without
          // the provider reference rather than stranding the user on a
          // generic failure they cannot clear.
          if (allowAudioReuse) {
            Log.error(
              'Provider credit publishing failed; blocking video publish',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
            return false;
          }
          Log.warning(
            'Provider credit publishing failed; publishing without the '
            'provider audio reference',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          selectedAudioReferenceRelay = null;
        }
      }

      // Handle selected audio: reference an existing Kind 1063 audio event
      // (e.g., when recording with a selected sound from another video)
      final hasSelectedAudioEventId =
          selectedAudioReferenceId != null &&
          selectedAudioReferenceId.isNotEmpty;
      // A reused *original sound* carries the source video's event id behind a
      // `video_` prefix (and, from the editor timeline, a `-<timestamp>`
      // uniqueness suffix). Fall back to [AudioEvent.attributionEventId] to
      // recover the real event id so the reference survives instead of being
      // dropped and the audio mislabelled as the reusing user's own sound.
      final reusableSelectedAudioEventId =
          NostrHexUtils.isValidEventId(selectedAudioReferenceId)
          ? selectedAudioReferenceId
          : selectedAudio?.attributionEventId;
      if (hasSelectedAudioEventId && reusableSelectedAudioEventId == null) {
        Log.warning(
          'Skipping selected audio reference because it is not a Nostr event id: '
          '$selectedAudioReferenceId',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      if (reusableSelectedAudioEventId != null) {
        final audioRelay =
            selectedAudioReferenceRelay ?? 'wss://relay.divine.video';
        tags.add(['e', reusableSelectedAudioEventId, audioRelay, 'audio']);
        Log.info(
          'Added selected audio reference e tag: $reusableSelectedAudioEventId',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
      }

      // Handle audio reuse: extract audio, upload, publish Kind 1063 event
      // Then add e tag linking video to audio event.
      //
      // Skip when the selected audio was actually referenced above. Bundled
      // sounds yield no Nostr reference, so opting into reuse should publish the
      // rendered video audio as the user's reusable Kind 1063. External-provider
      // catalog sounds are also not referenceable, but they carry their own
      // provider/license metadata and must not be republished as the user's
      // reusable sound.
      String? audioEventId;
      // Set when the creator asked for reusable audio and we could not
      // produce it. Two consequences below: the signed event must not enter
      // the retry cache (its tags are missing markers a retry would rebuild),
      // and the caller is told so it can say so rather than reporting a
      // clean success.
      var audioReuseDegraded = false;
      if (!allowAudioReuse) tags.add(['allow_audio_reuse', 'false']);
      if (allowAudioReuse &&
          reusableSelectedAudioEventId == null &&
          selectedAudio?.isExternalProviderSound != true &&
          upload.localVideoPath.isNotEmpty) {
        Log.info(
          'Audio reuse enabled - starting audio publishing flow',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        // Get the user's pubkey for the audio event
        final userPubkey = _authService?.currentPublicKeyHex;
        if (userPubkey != null) {
          // Get a relay hint from connected relays
          String relayHint = 'wss://relay.divine.video';
          if (_nostrService.connectedRelays.isNotEmpty) {
            relayHint = _nostrService.connectedRelays.first;
          }

          // Publish audio event first (we need its ID for the video event)
          audioEventId = await _publishAudioEvent(
            videoPath: upload.localVideoPath,
            videoDTag: dTag,
            pubkey: userPubkey,
            relayHint: relayHint,
            videoTitle: upload.title,
            attribution: audioShareAttribution,
          );

          if (audioEventId != null) {
            // Both tags are added together once the Kind 1063 exists, so this
            // publisher never emits `allow_audio_reuse` without the matching
            // `e` tag. That is a property of this path only — the edit flow
            // (`video_metadata_update_service.dart`) rebuilds
            // `allow_audio_reuse` straight from the toggle and publishes no
            // Kind 1063, so the tag-without-`e` shape is reachable there.
            tags.add(['allow_audio_reuse', 'true']);
            // Format: ["e", <audio-event-id>, <relay-hint>, "audio"]
            tags.add(['e', audioEventId, relayHint, 'audio']);
            Log.info(
              'Added audio reference e tag: $audioEventId',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } else {
            // A transient extraction/upload failure degrades to a video-only
            // publish rather than discarding an already-uploaded video over a
            // glitch. The tag is not cosmetic — `allow_audio_reuse` is the
            // standalone consent marker that `_canReuseSound` reads to offer
            // in-app remixing off the video's own audio, with no Kind 1063
            // involved — so the creator loses a feature they asked for, which
            // is why this is reported rather than swallowed.
            //
            // Deliberately NOT the provider-credit bridge's rule: that block
            // blocks when `allowAudioReuse` is true and degrades only when it
            // is false, and this block is unreachable unless it is true. The
            // two are disjoint. Rendered-audio extraction is treated
            // differently on purpose — the audio it would publish is the
            // video's own, so a retry can always reconstruct it, whereas a
            // provider credit cannot be reconstructed after the fact.
            audioReuseDegraded = true;
            Log.warning(
              'Reusable audio failed to publish; publishing the video without '
              'it',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } else {
          audioReuseDegraded = true;
          Log.warning(
            'No user pubkey available for requested reusable audio; '
            'publishing the video without it',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }
      }

      NativeProofData? proofUsedForTags;
      String? publishDeviceAttestationPubkeyHex;

      // Add ProofMode tags if native proof exists
      if (upload.hasProofMode) {
        try {
          final storedProof = upload.nativeProof;
          if (storedProof != null) {
            Log.info(
              '📜 Adding ProofMode verification tags to Nostr event',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            final attestationResult = await _withPublishDeviceAttestation(
              storedProof,
            );
            final nativeProof = attestationResult.proof;
            proofUsedForTags = nativeProof;
            publishDeviceAttestationPubkeyHex =
                attestationResult.attestedPubkeyHex;

            //check C2PA metadata
            final C2paSigningService c2paSigningService = C2paSigningService();
            final manifestInfo = await c2paSigningService.readManifest(
              upload.localVideoPath,
            );
            if (manifestInfo?.validationStatus != null) {
              tags.add(['c2pa_manifest_id', ?manifestInfo?.activeManifest]);
              Log.verbose(
                'Added c2pa_manifest_id tag: ${manifestInfo?.activeManifest}',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            // Add verification level tag (NIP-145)
            final verificationLevel = getVerificationLevel(nativeProof);
            tags.add(['verification', verificationLevel]);
            Log.verbose(
              'Added verification tag: $verificationLevel',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add ProofMode native proof tag (complete JSON proof data)
            final proofTag = createProofManifestTag(nativeProof);
            tags.add(['proofmode', proofTag]);
            Log.verbose(
              'Added proofmode proof tag (${proofTag.length} chars)',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );

            // Add device attestation tag if available (NIP-145)
            final deviceTag = createDeviceAttestationTag(nativeProof);
            if (deviceTag != null) {
              tags.add(['device_attestation', deviceTag]);
              Log.verbose(
                'Added device_attestation tag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            // Add PGP fingerprint tag if available (NIP-145)
            final pgpTag = createPgpFingerprintTag(nativeProof);
            if (pgpTag != null) {
              tags.add(['pgp_fingerprint', pgpTag]);
              Log.verbose(
                'Added pgp_fingerprint tag: $pgpTag',
                name: 'VideoEventPublisher',
                category: LogCategory.video,
              );
            }

            _addIdentityDiscoveryTags(tags, nativeProof);

            Log.info(
              '✅ ProofMode verification tags added successfully',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.error(
            'Failed to add ProofMode tags: $e',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
          // Continue publishing even if ProofMode tag generation fails
        }
      }

      // Create the event content
      var content = upload.description ?? upload.title ?? '';

      // Append NIP-27 Inspired By person reference to content
      if (inspiredByNpub != null && inspiredByNpub.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      // Create and sign the event
      if (_authService == null) {
        Log.error(
          'Auth service is null - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      if (!_authService.isAuthenticated) {
        Log.error(
          'User not authenticated - cannot create video event',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }

      Log.debug(
        '📱 Creating and signing video event...',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Content: "$content"',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'Tags: ${tags.length} tags',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      final signWatch = Stopwatch()..start();
      final reusedEvent = _loadRetryableSignedEvent(upload);
      final Event? event;
      if (reusedEvent != null) {
        event = reusedEvent;
      } else {
        final expectedPubkeyHex = publishDeviceAttestationPubkeyHex;
        final proof = proofUsedForTags;
        if (expectedPubkeyHex != null &&
            proof != null &&
            _authService.currentPublicKeyHex != expectedPubkeyHex) {
          _clearPublishDeviceAttestationTags(tags: tags, proof: proof);
        }

        event = await _authService.createAndSignEvent(
          kind:
              NIP71VideoKinds.getPreferredAddressableKind(), // NIP-71 addressable short video
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
          name: 'VideoEventPublisher',
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );

      // Publish to Nostr relays with retry logic
      Log.info(
        '🚀 Starting relay publication for event ${event.id}',
        name: 'VideoEventPublisher',
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

      if (publishResult) {
        await _publishedEventLocalEcho?.record(event);

        final shouldAddToDiscoveryCache =
            replyContext == null || addReplyToFeed;
        if (_videoEventService != null && shouldAddToDiscoveryCache) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            _videoEventService.addVideoEvent(videoEvent);
            Log.info(
              'Added confirmed video to discovery cache: ${event.id}',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          } catch (e) {
            Log.warning(
              'Failed to add confirmed video to discovery cache: $e',
              name: 'VideoEventPublisher',
              category: LogCategory.video,
            );
          }
        }

        // Update upload status
        await _uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: event.id,
        );

        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();

        // Note: Discovery cache was already updated immediately after event
        // creation (before relay publish) for instant local UI feedback.

        // Invalidate profile stats cache so video count updates immediately
        final currentPubkey = _nostrService.publicKey;
        if (currentPubkey.isNotEmpty) {
          unawaited(_profileStatsDao?.deleteStats(currentPubkey));
          Log.debug(
            'Invalidated profile stats cache for new video',
            name: 'VideoEventPublisher',
            category: LogCategory.video,
          );
        }

        Log.info(
          'Successfully published direct upload: ${event.id}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        Log.debug(
          'Video URL: ${upload.cdnUrl}',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );

        return true;
      } else {
        Log.error(
          'Failed to publish to Nostr relays',
          name: 'VideoEventPublisher',
          category: LogCategory.video,
        );
        return false;
      }
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      _totalEventsFailed++;
      return false;
    }
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    for (final ref in [textTrackRef, ...extraTextTrackRefs]) {
      tags.add([
        'text-track',
        ref,
        'wss://relay.divine.video',
        'captions',
        textTrackLang,
      ]);
    }

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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    // Publish to relays before updating local cache. A WebSocket send is not
    // enough here; rejected subtitle republishes must not appear locally.
    final published =
        await _publishEventToNostr(event) == _EventPublishOutcome.published;
    if (!published) return null;

    final updatedVideo = VideoEvent.fromNostrEvent(event);

    try {
      _personalEventCache?.cacheUserEvent(event);
      _videoEventService?.updateVideoEvent(updatedVideo);
    } catch (e) {
      Log.warning(
        'Failed to update local cache after subtitle republish: $e',
        name: 'VideoEventPublisher',
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
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }

    final ok =
        await _publishEventToNostr(event) == _EventPublishOutcome.published;
    if (!ok) {
      Log.warning(
        'Failed to publish subtitle event',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return null;
    }
    return '${NIP71VideoKinds.subtitleEventKind}:$pubkey:$dTag';
  }

  /// Check if a URL is a valid HTTP/HTTPS URL (not a local file path)
  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  static bool _isPublishableMediaUrl(String? url) {
    return _isHttpUrl(url) && !VideoUrlResolver.isKnownDeadMediaUrl(url!);
  }

  /// Returns [proof] carrying the device attestation this publish should
  /// broadcast.
  ///
  /// On iOS the payload is minted here rather than at proof generation, because
  /// only now is the publishing account fixed — the challenge binds it, and the
  /// App Attest key is scoped to it. That makes the value computed here
  /// authoritative: it replaces whatever the stored proof carried, so a token
  /// left behind for a different account cannot ride along. Platforms that
  /// attest during generation keep what they produced.
  Future<_PublishDeviceAttestationResult> _withPublishDeviceAttestation(
    NativeProofData proof,
  ) async {
    if (!IosDeviceAttestationService.handlesPublishTimeAttestation) {
      return _PublishDeviceAttestationResult(proof: proof);
    }

    final pubkeyHex = _authService?.currentPublicKeyHex;
    if (pubkeyHex == null) {
      Log.warning(
        'No signing pubkey available - publishing without device attestation',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _PublishDeviceAttestationResult(
        proof: proof.withDeviceAttestation(null),
      );
    }

    final attestation = await _iosDeviceAttestation.attestationFor(
      proofHash: proof.videoHash,
      pubkeyHex: pubkeyHex,
    );

    if (attestation == null) {
      return _PublishDeviceAttestationResult(
        proof: proof.withDeviceAttestation(null),
      );
    }

    if (_authService?.currentPublicKeyHex != pubkeyHex) {
      Log.warning(
        'Signing account changed while minting device attestation - '
        'publishing without device attestation',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
      return _PublishDeviceAttestationResult(
        proof: proof.withDeviceAttestation(null),
      );
    }

    return _PublishDeviceAttestationResult(
      proof: proof.withDeviceAttestation(attestation),
      attestedPubkeyHex: pubkeyHex,
    );
  }

  void _clearPublishDeviceAttestationTags({
    required List<List<String>> tags,
    required NativeProofData proof,
  }) {
    final clearedProof = proof.withDeviceAttestation(null);

    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i];
      if (tag.isEmpty) continue;

      switch (tag[0]) {
        case 'proofmode':
          tags[i] = ['proofmode', createProofManifestTag(clearedProof)];
        case 'verification':
          tags[i] = ['verification', getVerificationLevel(clearedProof)];
      }
    }

    tags.removeWhere((tag) => tag.isNotEmpty && tag[0] == 'device_attestation');
    Log.warning(
      'Signing account changed before event signing - publishing without '
      'device attestation',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }

  void _addIdentityDiscoveryTags(
    List<List<String>> tags,
    NativeProofData nativeProof,
  ) {
    if (_hasCreatorBinding(nativeProof)) {
      tags.add(['identity_binding', 'nostr_creator']);
    }

    if (_hasPortableIdentity(nativeProof)) {
      tags.add(['identity_portable', 'cawg']);
    }

    final verifier = _extractIdentityVerifier(
      nativeProof.verifiedIdentityBundleJson,
    );
    if (verifier != null && verifier.isNotEmpty) {
      tags.add(['identity_verifier', verifier]);
    }
  }

  bool _hasCreatorBinding(NativeProofData nativeProof) {
    return (nativeProof.creatorBindingAssertionLabel?.isNotEmpty ?? false) ||
        (nativeProof.creatorBindingPayloadJson?.isNotEmpty ?? false);
  }

  bool _hasPortableIdentity(NativeProofData nativeProof) {
    return nativeProof.cawgIdentityAssertionLabel == 'cawg.identity' ||
        (nativeProof.verifiedIdentityBundleJson?.isNotEmpty ?? false);
  }

  String? _extractIdentityVerifier(String? verifiedIdentityBundleJson) {
    if (verifiedIdentityBundleJson == null ||
        verifiedIdentityBundleJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(verifiedIdentityBundleJson);
      if (decoded is Map) {
        return decoded['issuer']?.toString();
      }
    } catch (error) {
      Log.warning(
        'Failed to parse verifier identity bundle: $error',
        name: 'VideoEventPublisher',
        category: LogCategory.video,
      );
    }

    return null;
  }

  void dispose() {
    Log.debug(
      'Disposing VideoEventPublisher',
      name: 'VideoEventPublisher',
      category: LogCategory.video,
    );
  }
}

class _PublishDeviceAttestationResult {
  const _PublishDeviceAttestationResult({
    required this.proof,
    this.attestedPubkeyHex,
  });

  final NativeProofData proof;
  final String? attestedPubkeyHex;
}
