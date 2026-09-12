// ABOUTME: Service for publishing video view events (Kind 22236) to Nostr
// ABOUTME: Tracks video watch time and publishes ephemeral analytics events

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Kind 22236 - Ephemeral video view event (NIP-71 extension)
const int viewEventKind = 22236;

/// Reporting phase of a kind 22236 view event (two-phase view reporting).
///
/// One viewing session publishes one [start] event at playback start — which
/// is what counts the view, so an app kill mid-session cannot erase it — and
/// one or more [end] events carrying watched-time and loop deltas. A null
/// phase is a legacy single-shot event and keeps the pre-phase shape.
enum ViewEventPhase {
  /// Playback start: counts the view. Carries no `viewed` or `loops` tags.
  start,

  /// Session segment end: carries the segment's watch time and fractional
  /// loops. The relay counts this toward loops, not views.
  end,
}

/// Notified every time a view event is dropped instead of published.
///
/// Wired in the app layer to Crashlytics for structural drops. Injected
/// rather than reached for statically so tests can assert on drops.
typedef ViewEventDropReporter = void Function(
  ViewEventDropReason reason, {
  required String videoId,
  required String method,
});

/// Service for publishing video view events to Nostr relays.
///
/// View events are ephemeral (kind 22236) and are processed by analytics
/// services in real-time. They track watch time, traffic sources, and
/// enable creator analytics and recommendation systems.
class ViewEventPublisher {
  ViewEventPublisher({
    required NostrClient nostrService,
    required AuthService authService,
    required String appVersion,
    String? defaultRelayHint,
    ViewEventDropReporter? onDrop,
  }) : _nostrService = nostrService,
       _authService = authService,
       _appVersion = appVersion.trim(),
       _onDrop = onDrop,
       _defaultRelayHint = defaultRelayHint ?? 'wss://relay.divine.video';

  final NostrClient _nostrService;
  final AuthService _authService;
  final String _defaultRelayHint;
  final ViewEventDropReporter? _onDrop;

  /// Shipped app version written into the `version` tag of every view event.
  ///
  /// `view_interactions.client` only says "Divine": it cannot tell a 1.0.19
  /// view from a 1.0.20 one, so a reporting regression could not be pinned to
  /// the release that shipped it (#7921). The NIP-89 `client` tag is left
  /// untouched on purpose — Funnelcake's view-volume detector keys on its
  /// exact value. An empty version omits the tag rather than sending a
  /// placeholder.
  final String _appVersion;

  /// Records a dropped view event and returns `false` for the caller.
  ///
  /// Every early return in this class routes through here, so a new skip
  /// path cannot be added without declaring whether it is a defect.
  bool _drop(ViewEventDropReason reason, String videoId, String method) {
    Log.debug(
      'View event dropped (${reason.name}) for video $videoId',
      name: 'ViewEventPublisher',
      category: LogCategory.video,
    );
    _onDrop?.call(reason, videoId: videoId, method: method);
    return false;
  }

  ViewEventDropReason _missingAddressableReason(VideoEvent video) {
    return switch (video.eventKind) {
      NIP71VideoKinds.shortVideo || NIP71VideoKinds.normalVideo =>
        ViewEventDropReason.nonAddressableVideoKind,
      NIP71VideoKinds.addressableShortVideo ||
      NIP71VideoKinds.addressableNormalVideo =>
        ViewEventDropReason.missingAddressableDTag,
      _ => ViewEventDropReason.missingAddressableDTag,
    };
  }

  /// Publish a video view event.
  ///
  /// [video] - The video that was viewed
  /// [startSeconds] - Elapsed playback seconds at the start of the session
  /// [endSeconds] - Elapsed playback seconds at the end of the session
  /// [source] - Where the video was discovered/viewed from
  ///
  /// Returns true if the event was published successfully.
  Future<bool> publishViewEvent({
    required VideoEvent video,
    required int startSeconds,
    required int endSeconds,
    ViewTrafficSource source = ViewTrafficSource.unknown,
    String? sourceDetail,
    double? loopCount,
    ViewEventPhase? phase,
  }) async {
    const method = 'publishViewEvent';
    // View = playback start per 2026-08-13 view/loop spec: any playback
    // start counts, even if the session ends before completing a loop
    // (a fractional loop is valid). Only reject inverted ranges. A
    // start-phase event carries no watch range at all, so the range check
    // only applies when viewed segments are actually emitted.
    if (phase != ViewEventPhase.start && endSeconds < startSeconds) {
      return _drop(ViewEventDropReason.invalidWatchRange, video.id, method);
    }

    if (!_authService.isAuthenticated) {
      return _drop(ViewEventDropReason.notAuthenticated, video.id, method);
    }

    try {
      // View events require an addressable video reference.
      final aTag = video.addressableId;
      if (aTag == null) {
        return _drop(_missingAddressableReason(video), video.id, method);
      }

      // Explicit publish-readiness gate. `isAuthenticated` only says the
      // pubkey is known: a Keycast identity with no local key is authenticated
      // well before its signer works, and signing in that window returns null,
      // which used to be filed as a structural `signingFailed` invariant
      // (#7505). Sampled at the moment of use, per the getter's contract.
      //
      // Deliberately below the addressable check: a missing `d` tag is a
      // permanent defect, and `ViewEventRetryService` deletes those rows
      // whatever the drop reason, so gating first would bin the evidence
      // before it was ever reported.
      if (!_authService.canPublishNostrWritesNow) {
        return _drop(ViewEventDropReason.signerNotReady, video.id, method);
      }

      // Get relay hint
      String relayHint = _defaultRelayHint;
      if (_nostrService.connectedRelays.isNotEmpty) {
        relayHint = _nostrService.connectedRelays.first;
      }

      // Build tags
      final tags = <List<String>>[
        // Addressable reference (required)
        ['a', aTag, relayHint],
        // Event ID reference (required)
        ['e', video.id, relayHint],
        // Reporting phase (two-phase sessions only; omitted on legacy replay)
        if (phase != null) ['phase', phase.name],
        // Watched segment. Start events know nothing about watch time yet
        // and omit it — a fabricated range would mint engagement the viewer
        // never gave.
        if (phase != ViewEventPhase.start)
          ['viewed', startSeconds.toString(), endSeconds.toString()],
        // Traffic source (optional but recommended)
        if (sourceDetail != null && sourceDetail.isNotEmpty)
          ['source', source.tagValue, sourceDetail]
        else
          ['source', source.tagValue],
        // Loop count as playthrough fraction (optional, omitted if null or <= 0).
        // Fractional to preserve partial passes (median 0.75) per spec.
        if (phase != ViewEventPhase.start && loopCount != null && loopCount > 0)
          ['loops', loopCount.toString()],
        // App version, so reporting regressions attribute to a release.
        if (_appVersion.isNotEmpty) ['version', _appVersion],
      ];

      Log.debug(
        'Publishing view event for video ${video.id}',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      Log.verbose(
        'View data: watched ${endSeconds - startSeconds}s, source=${source.tagValue}',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );

      // Create and sign the ephemeral event
      final event = await _authService.createAndSignEvent(
        kind: viewEventKind,
        content: '',
        tags: tags,
      );

      if (event == null) {
        return _drop(ViewEventDropReason.signingFailed, video.id, method);
      }

      // Publish to relays (fire-and-forget for ephemeral events)
      final sentEvent = await _nostrService.publishEvent(event);

      if (sentEvent is PublishSuccess) {
        Log.info(
          'View event published: video=${video.id}, '
          'watched=${endSeconds - startSeconds}s, version=$_appVersion',
          name: 'ViewEventPublisher',
          category: LogCategory.video,
        );
        return true;
      } else {
        return _drop(ViewEventDropReason.relayRejected, video.id, method);
      }
    } catch (e) {
      Log.error(
        'Error publishing view event: $e',
        name: 'ViewEventPublisher',
        category: LogCategory.video,
      );
      return _drop(ViewEventDropReason.unexpectedError, video.id, method);
    }
  }
}
