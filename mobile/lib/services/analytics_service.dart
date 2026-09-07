// ABOUTME: Analytics service for tracking video views with user opt-out support
// ABOUTME: Publishes Kind 22236 ephemeral Nostr view events for decentralized analytics

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

/// Service for tracking video analytics with privacy controls.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
/// The relay processes these events in real-time for creator analytics,
/// recommendation systems, and aggregated view stats.
///
/// Stats are available via the relay REST API:
/// - GET /api/videos/{id}/views - Retrieve view stats
/// - GET /api/videos/{id}/stats - Retrieve engagement stats
class AnalyticsService implements BackgroundAwareService {
  AnalyticsService({
    required BackgroundActivityManager backgroundActivityManager,
    ViewEventPublisher? viewEventPublisher,
    PendingViewEventsDao? pendingViewEventsDao,
    Future<void> Function()? flushPendingViewEvents,
    ProductEventQueue? productEventQueue,
    String? Function()? currentUserPubkey,
    String Function()? anonymousId,
    String Function()? sessionId,
    String Function()? platform,
    String Function()? appVersion,
    DateTime Function()? now,
    bool? productAnalyticsEnabled,
    @visibleForTesting bool? disableNostrPublishing,
  }) : _backgroundActivityManager = backgroundActivityManager,
       _viewEventPublisher = viewEventPublisher,
       _pendingViewEventsDao = pendingViewEventsDao,
       _flushPendingViewEvents = flushPendingViewEvents,
       _productEventQueue = productEventQueue,
       _currentUserPubkey = currentUserPubkey,
       _anonymousIdOverride = anonymousId,
       _sessionIdOverride = sessionId,
       _platform = platform ?? _defaultPlatform,
       _appVersion = appVersion ?? _emptyString,
       _now = now ?? DateTime.now,
       _productAnalyticsEnabled =
           productAnalyticsEnabled ??
           (const bool.fromEnvironment('PRODUCT_ANALYTICS_ENABLED') ||
               const String.fromEnvironment(
                     'DEFAULT_ENV',
                   ).toUpperCase() ==
                   'STAGING'),
       _disableNostrPublishing = disableNostrPublishing ?? false;

  static const Uuid _uuid = Uuid();

  static String _emptyString() => '';

  static String _defaultPlatform() => defaultTargetPlatform.name;

  /// The view event publisher for Kind 22236 Nostr events.
  ViewEventPublisher? _viewEventPublisher;

  final PendingViewEventsDao? _pendingViewEventsDao;
  final Future<void> Function()? _flushPendingViewEvents;
  final ProductEventQueue? _productEventQueue;
  final String? Function()? _currentUserPubkey;
  final String Function()? _anonymousIdOverride;
  final String Function()? _sessionIdOverride;
  final String Function() _platform;
  final String Function() _appVersion;
  final DateTime Function() _now;
  final bool _productAnalyticsEnabled;

  /// Testing flag to disable Nostr publishing in unit tests.
  final bool _disableNostrPublishing;

  static const String _analyticsEnabledKey = 'analytics_enabled';

  bool _analyticsEnabled = true; // Default to enabled
  bool _isInitialized = false;
  Future<void>? _initialization;
  // Not final: rotated at every identity or consent boundary so activity from
  // separate privacy contexts cannot be joined.
  late String _anonymousId = _uuid.v4();
  late String _sessionId = _uuid.v4();
  final Map<String, String> _productAnalyticsUtm = {};

  // Track recent views to prevent duplicate tracking
  final Set<String> _recentlyTrackedViews = {};
  Timer? _cleanupTimer;

  // Background activity management
  bool _isInBackground = false;

  // Track disposal state
  bool _isDisposed = false;

  /// Whether this instance is in [BackgroundActivityManager]'s registry.
  /// Registration is best-effort (see [initialize]), so the flag records
  /// whether it actually succeeded rather than whether it was attempted.
  final BackgroundActivityManager _backgroundActivityManager;

  bool _isBackgroundRegistered = false;

  /// Update the view event publisher (e.g. when Nostr client reconnects).
  void updateViewEventPublisher(ViewEventPublisher? publisher) {
    _viewEventPublisher = publisher;
  }

  /// Initialize the analytics service.
  ///
  /// Idempotent under concurrency, not only after completion. The
  /// `_isInitialized` flag is only set past the first `await`, so two callers
  /// that start in the same turn both run the body — a second cleanup timer,
  /// a second registration, a second queue recovery. `analyticsServiceProvider`
  /// kicks this off on a microtask, so anything that needs the stored consent
  /// preference before reading it (the Settings privacy toggle) is exactly
  /// that second caller. Everyone awaits the same run instead.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    // A disposed instance must not come back. `analyticsServiceProvider`
    // defers this call onto a microtask, so a container torn down before that
    // microtask lands calls dispose() first (#8398).
    if (_isDisposed) return;
    if (_isInitialized) return;

    try {
      // Load analytics preference from storage
      final prefs = await SharedPreferences.getInstance();
      _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;
      _isInitialized = true;
      if (!_analyticsEnabled) {
        // Stored opt-out: rows persisted before the preference loaded (or by
        // an older version) must neither linger nor be recovered later.
        _productAnalyticsUtm.clear();
        try {
          await _productEventQueue?.clear();
        } catch (error) {
          Log.warning(
            'Failed to clear queued product analytics for stored opt-out: '
            '$error',
            name: 'AnalyticsService',
            category: LogCategory.system,
          );
        }
      }
      _productEventQueue?.setSendingEnabled(
        _productAnalyticsEnabled && _analyticsEnabled,
      );
      if (_productAnalyticsEnabled && _analyticsEnabled) {
        _recoverQueuedProductEvents();
      }

      // The guard above is not enough on its own: dispose() may have run while
      // the awaits above were in flight. Re-check before the two side effects
      // it can no longer undo — the periodic timer, and joining the manager's
      // registry with no owner left to leave it (#8398).
      if (_isDisposed) return;

      // Set up periodic cleanup of tracked views
      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _recentlyTrackedViews.clear();
      });

      // Register with background activity manager
      try {
        _backgroundActivityManager.registerService(this);
        _isBackgroundRegistered = true;
      } catch (e) {
        Log.warning(
          'Could not register with background activity manager: $e',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      }

      Log.info(
        'Analytics service initialized (enabled: $_analyticsEnabled)',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize analytics service: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Get current analytics enabled state (user preference).
  bool get analyticsEnabled => _analyticsEnabled;

  /// Whether analytics tracking is currently operational.
  bool get isOperational => _analyticsEnabled;

  /// Release label written into first-party product analytics events.
  String get productAnalyticsRelease {
    final release = _appVersion();
    return release.isEmpty ? '0.0.0' : release;
  }

  /// Set analytics enabled state.
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_analyticsEnabled == enabled) return;

    _analyticsEnabled = enabled;
    _productEventQueue?.setSendingEnabled(
      _productAnalyticsEnabled && enabled,
    );

    if (!enabled) {
      _productAnalyticsUtm.clear();
      _rotateProductAnalyticsIdentity();
      try {
        await _productEventQueue?.clear();
      } catch (error) {
        Log.warning(
          'Failed to clear queued product analytics after opt-out: $error',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      }
    } else if (_productAnalyticsEnabled) {
      _recoverQueuedProductEvents();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, enabled);

      Log.info(
        'Analytics ${enabled ? 'enabled' : 'disabled'} by user',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to save analytics preference: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    }
  }

  Map<String, String> get productAnalyticsUtm =>
      Map.unmodifiable(_productAnalyticsUtm);

  void _recoverQueuedProductEvents() {
    try {
      final recovery = _productEventQueue?.recoverPublishingAndFlush();
      if (recovery != null) {
        unawaited(recovery.catchError((Object _) {}));
      }
    } catch (_) {
      // Queue recovery is best-effort and must not prevent app startup.
    }
  }

  /// Retains only the four short campaign values allowed by the contract.
  void captureProductAnalyticsUtm(Map<String, String> queryParameters) {
    const keys = {'utm_source', 'utm_medium', 'utm_campaign', 'utm_content'};
    final boundedValue = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
    final captured = <String, String>{};
    for (final key in keys) {
      final value = queryParameters[key]?.toLowerCase();
      if (value != null && boundedValue.hasMatch(value)) {
        captured[key] = value;
      }
    }
    if (captured.isNotEmpty) {
      _productAnalyticsUtm
        ..clear()
        ..addAll(captured);
    }
  }

  /// Clears queued events before any login, logout, or account switch.
  ///
  /// The first login is an identity boundary too. Rotating both identifiers
  /// prevents pre-login activity from being joined to the authenticated
  /// account, while clearing the whole queue prevents older anonymous or
  /// account-owned rows from crossing the boundary later.
  Future<void> handleIdentityChange() async {
    _productAnalyticsUtm.clear();
    _rotateProductAnalyticsIdentity();
    await _productEventQueue?.clear();
  }

  void _rotateProductAnalyticsIdentity() {
    if (_anonymousIdOverride == null) _anonymousId = _uuid.v4();
    if (_sessionIdOverride == null) _sessionId = _uuid.v4();
  }

  Future<String?> recordContentImpression({
    required String contentId,
    required ProductAnalyticsV2Surface surface,
    required int position,
    required int visibleMs,
    String? recommendationId,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2ContentImpressionRecordedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2ContentImpressionRecordedProperties(
        contentId: contentId,
        surface: surface,
        position: position,
        visibleMs: visibleMs,
        recommendationId: recommendationId,
      ),
    ),
  );

  Future<String?> recordPlaybackSession({
    required String playbackSessionId,
    required String contentId,
    required ProductAnalyticsV2Surface surface,
    required int durationMs,
    required int watchedMs,
    required int loopCount,
    required bool completed,
    required ProductAnalyticsV2PlaybackEndReason endReason,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2PlaybackSessionRecordedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2PlaybackSessionRecordedProperties(
        playbackSessionId: playbackSessionId,
        contentId: contentId,
        surface: surface,
        durationMs: durationMs,
        watchedMs: watchedMs,
        loopCount: loopCount,
        completed: completed,
        endReason: endReason,
      ),
    ),
  );

  Future<String?> recordNavigationContext({
    required ProductAnalyticsV2Surface fromSurface,
    required ProductAnalyticsV2Surface toSurface,
    required ProductAnalyticsV2NavigationAction action,
    String? contentId,
    String? recommendationId,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2NavigationContextRecordedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2NavigationContextRecordedProperties(
        fromSurface: fromSurface,
        toSurface: toSurface,
        action: action,
        contentId: contentId,
        recommendationId: recommendationId,
      ),
    ),
  );

  Future<String?> recordOnboardingStep({
    required ProductAnalyticsV2OnboardingFlow flow,
    required ProductAnalyticsV2OnboardingStep step,
    required ProductAnalyticsV2OnboardingResult result,
    ProductAnalyticsV2OnboardingReason? reason,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2OnboardingStepRecordedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2OnboardingStepRecordedProperties(
        flow: flow,
        step: step,
        result: result,
        reason: reason,
      ),
    ),
  );

  Future<String?> recordExperimentExposure({
    required String experimentKey,
    required String variantKey,
    required ProductAnalyticsV2AssignmentSource assignmentSource,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2ExperimentExposureEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2ExperimentExposureProperties(
        experimentKey: experimentKey,
        variantKey: variantKey,
        assignmentSource: assignmentSource,
      ),
    ),
  );

  Future<String?> recordLandingViewed({
    required ProductAnalyticsV2LandingPage landingPage,
    required ProductAnalyticsV2ReferrerClass referrerClass,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2LandingViewedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2LandingViewedProperties(
        landingPage: landingPage,
        referrerClass: referrerClass,
        utmSource: _productAnalyticsUtm['utm_source'],
        utmMedium: _productAnalyticsUtm['utm_medium'],
        utmCampaign: _productAnalyticsUtm['utm_campaign'],
        utmContent: _productAnalyticsUtm['utm_content'],
      ),
    ),
    anonymous: true,
  );

  Future<String?> recordRegistrationStarted({
    required ProductAnalyticsV2RegistrationEntryPoint entryPoint,
  }) => _trackProductEvent(
    (envelope) => ProductAnalyticsV2RegistrationStartedEvent(
      envelope: envelope,
      properties: ProductAnalyticsV2RegistrationStartedProperties(
        entryPoint: entryPoint,
        utmSource: _productAnalyticsUtm['utm_source'],
        utmMedium: _productAnalyticsUtm['utm_medium'],
        utmCampaign: _productAnalyticsUtm['utm_campaign'],
        utmContent: _productAnalyticsUtm['utm_content'],
      ),
    ),
    anonymous: true,
  );

  Future<String?> _trackProductEvent(
    ProductAnalyticsV2Event Function(ProductAnalyticsV2Envelope) build, {
    bool anonymous = false,
  }) async {
    // Fail closed until the stored consent preference has been loaded:
    // `_analyticsEnabled` defaults to true, so without the `_isInitialized`
    // gate an opted-out user's events could be persisted in the startup
    // window before `initialize()` resolves.
    if (_isDisposed ||
        !_isInitialized ||
        !_analyticsEnabled ||
        !_productAnalyticsEnabled) {
      return null;
    }
    final queue = _productEventQueue;
    if (queue == null) return null;

    final ownerPubkey = anonymous ? null : _currentUserPubkey?.call();
    if (!anonymous && (ownerPubkey == null || ownerPubkey.isEmpty)) return null;

    final emptyEnvelope = _productAnalyticsEnvelope('');
    final eventId = computeProductAnalyticsEventId(
      build(emptyEnvelope).toJson(),
    );
    final event = build(
      ProductAnalyticsV2Envelope(
        eventId: eventId,
        schemaVersion: emptyEnvelope.schemaVersion,
        occurredAt: emptyEnvelope.occurredAt,
        anonymousId: emptyEnvelope.anonymousId,
        sessionId: emptyEnvelope.sessionId,
        source: emptyEnvelope.source,
        platform: emptyEnvelope.platform,
        release: emptyEnvelope.release,
        consentCategory: emptyEnvelope.consentCategory,
      ),
    );
    try {
      await queue.enqueue(event, ownerPubkey: ownerPubkey);
    } catch (error) {
      Log.warning(
        'Failed to enqueue product analytics event ${event.eventName}: $error',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      return null;
    }
    try {
      unawaited(queue.flush().catchError((Object _) {}));
    } catch (_) {
      // The durable row remains available for the next foreground flush.
    }
    return eventId;
  }

  ProductAnalyticsV2Envelope _productAnalyticsEnvelope(String eventId) {
    final platform = switch (_platform().toLowerCase()) {
      'ios' => ProductAnalyticsV2Platform.ios,
      'android' => ProductAnalyticsV2Platform.android,
      _ =>
        defaultTargetPlatform == TargetPlatform.iOS
            ? ProductAnalyticsV2Platform.ios
            : ProductAnalyticsV2Platform.android,
    };
    return ProductAnalyticsV2Envelope(
      eventId: eventId,
      schemaVersion: productAnalyticsV2SchemaVersion,
      occurredAt: _now().toUtc(),
      anonymousId: _anonymousIdOverride?.call() ?? _anonymousId,
      sessionId: _sessionIdOverride?.call() ?? _sessionId,
      source: ProductAnalyticsV2Source.mobile,
      platform: platform,
      release: productAnalyticsRelease,
      consentCategory: ProductAnalyticsV2ConsentCategory.productAnalytics,
    );
  }

  @visibleForTesting
  static String computeProductAnalyticsEventId(Map<String, Object?> event) {
    final unsigned = Map<String, Object?>.from(event)..remove('event_id');
    return sha256.convert(utf8.encode(_canonicalJson(unsigned))).toString();
  }

  static String _canonicalJson(Object? value) {
    if (value == null || value is bool || value is String) {
      return jsonEncode(value);
    }
    if (value is int) return value.toString();
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'must be finite');
      }
      if (value == 0) return '0';
      if (value == value.truncateToDouble()) return value.toInt().toString();
      return value.toString();
    }
    if (value is List) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    if (value is Map) {
      final entries =
          value.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
    }
    throw ArgumentError.value(value, 'value', 'unsupported JSON value');
  }

  /// Track a basic video view (when video starts playing).
  Future<void> trackVideoView(
    VideoEvent video, {
    String source = 'mobile',
  }) async {
    trackDetailedVideoView(video, source: source, eventType: 'view_start');
  }

  /// Track a video view with user identification for proper analytics.
  Future<void> trackVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    String source = 'mobile',
  }) async {
    trackDetailedVideoViewWithUser(
      video,
      userId: userId,
      source: source,
      eventType: 'view_start',
    );
  }

  /// Track detailed video interaction events.
  Future<void> trackDetailedVideoView(
    VideoEvent video, {
    required String source,
    required String eventType,
    Duration? watchDuration,
    Duration? totalDuration,
    double? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    trackDetailedVideoViewWithUser(
      video,
      userId: null,
      source: source,
      eventType: eventType,
      watchDuration: watchDuration,
      totalDuration: totalDuration,
      loopCount: loopCount,
      completedVideo: completedVideo,
      trafficSource: trafficSource,
      sourceDetail: sourceDetail,
    );
  }

  /// Track detailed video interaction events with user identification.
  ///
  /// For both phases of a viewing session, publishes a Kind 22236 ephemeral
  /// Nostr event via [ViewEventPublisher]: a `view_start` (phase `start`,
  /// what counts the view) and each `view_end` segment (phase `end`, what
  /// carries watch time and fractional loops).
  ///
  /// [sessionToken] scopes the view_start dedupe to one tracker mount, so a
  /// remount re-watch reports its own start instead of being suppressed.
  ///
  /// This guard is **process-local and in-memory only**. The token is never
  /// queued, published, or sent to the relay, and `view_handler.rs` does no
  /// per-video dedup — `ViewPhase::Start` returns `view_count: 1`
  /// unconditionally. So it collapses rapid-fire duplicates within one mount
  /// and nothing more. A start row that publishes successfully but then fails
  /// its `deleteById` is re-swept and counted a second time; closing that
  /// window needs an idempotency key the relay can actually see, which no
  /// merged relay work provides.
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String eventType,
    String? sessionToken,
    Duration? watchDuration,
    Duration? totalDuration,
    double? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    if (_isDisposed) return;

    // Check if analytics is enabled by user preference
    if (!_analyticsEnabled) {
      return;
    }

    // Deduplicate rapid-fire tracking of the same video
    final dedupeKey = '${video.id}_${eventType}_${sessionToken ?? ''}';
    if (eventType == 'view_start' &&
        _recentlyTrackedViews.contains(dedupeKey)) {
      return;
    }
    if (eventType == 'view_start') {
      _recentlyTrackedViews.add(dedupeKey);
    }

    Log.debug(
      'Tracking $eventType for video ${video.id}',
      name: 'AnalyticsService',
      category: LogCategory.video,
    );

    if (eventType == 'view_start' && !_disableNostrPublishing) {
      // The view is counted at playback start, so an app kill mid-session
      // cannot erase it. A start event carries no watch time or loops.
      final enqueued = await _enqueuePendingViewEvent(
        video: video,
        userPubkey: userId,
        watchDuration: Duration.zero,
        totalDuration: null,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        phase: ViewEventPhase.start,
      );
      if (!enqueued) {
        _publishNostrViewEvent(
          video: video,
          watchDuration: Duration.zero,
          trafficSource: trafficSource,
          sourceDetail: sourceDetail,
          phase: ViewEventPhase.start,
        );
      }
      return;
    }

    if (eventType == 'view_end' &&
        watchDuration != null &&
        !_disableNostrPublishing) {
      final enqueued = await _enqueuePendingViewEvent(
        video: video,
        userPubkey: userId,
        watchDuration: watchDuration,
        totalDuration: totalDuration,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        loopCount: loopCount,
        phase: ViewEventPhase.end,
      );
      if (!enqueued) {
        _publishNostrViewEvent(
          video: video,
          watchDuration: watchDuration,
          trafficSource: trafficSource,
          sourceDetail: sourceDetail,
          loopCount: loopCount,
          phase: ViewEventPhase.end,
        );
      }
    }
  }

  Future<bool> _enqueuePendingViewEvent({
    required VideoEvent video,
    required String? userPubkey,
    required Duration watchDuration,
    required Duration? totalDuration,
    required ViewTrafficSource trafficSource,
    required ViewEventPhase phase,
    String? sourceDetail,
    double? loopCount,
  }) async {
    if (video.addressableId == null &&
        (video.eventKind == NIP71VideoKinds.shortVideo ||
            video.eventKind == NIP71VideoKinds.normalVideo)) {
      Log.debug(
        'Skipping pending view event for non-addressable video kind ${video.eventKind}',
        name: 'AnalyticsService',
        category: LogCategory.video,
      );
      return true;
    }

    final dao = _pendingViewEventsDao;
    if (dao == null || userPubkey == null) return false;

    final createdAt = DateTime.now();
    try {
      await dao.enqueue(
        PendingViewEvent(
          id: '${video.id}_${userPubkey}_${createdAt.microsecondsSinceEpoch}',
          videoId: video.id,
          videoPubkey: video.pubkey,
          videoVineId: video.vineId,
          videoAddressableDTag: video.addressableDTag,
          videoEventKind: video.eventKind,
          userPubkey: userPubkey,
          watchDurationMs: watchDuration.inMilliseconds,
          totalDurationMs: totalDuration?.inMilliseconds,
          loopCount: loopCount?.round(),
          trafficSource: trafficSource.tagValue,
          sourceDetail: sourceDetail,
          status: PendingViewEventStatus.pending,
          createdAt: createdAt,
          phase: phase.name,
        ),
      );
    } catch (e) {
      Log.warning(
        'Failed to enqueue pending view event: $e',
        name: 'AnalyticsService',
        category: LogCategory.video,
      );
      return false;
    }

    try {
      await _flushPendingViewEvents?.call();
    } catch (e) {
      Log.debug(
        'Failed to flush pending view events immediately: $e',
        name: 'AnalyticsService',
        category: LogCategory.video,
      );
    }
    return true;
  }

  /// Publish Kind 22236 ephemeral view event to Nostr relays.
  void _publishNostrViewEvent({
    required VideoEvent video,
    required Duration watchDuration,
    required ViewTrafficSource trafficSource,
    required ViewEventPhase phase,
    String? sourceDetail,
    double? loopCount,
  }) {
    final publisher = _viewEventPublisher;
    if (publisher == null) {
      Log.debug(
        'ViewEventPublisher not available, skipping Nostr view event',
        name: 'AnalyticsService',
        category: LogCategory.video,
      );
      return;
    }

    // Fire-and-forget: don't await, don't block
    publisher
        .publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: watchDuration.inSeconds,
          source: trafficSource,
          sourceDetail: sourceDetail,
          loopCount: loopCount,
          phase: phase,
        )
        .then((success) {
          if (success) {
            Log.debug(
              'Published Nostr view event for ${video.id}',
              name: 'AnalyticsService',
              category: LogCategory.video,
            );
          }
        })
        .catchError((Object error) {
          // Silently ignore errors - view events are best-effort
          Log.debug(
            'Failed to publish Nostr view event: $error',
            name: 'AnalyticsService',
            category: LogCategory.video,
          );
        });
  }

  /// Track multiple video views in batch (for feed loading).
  Future<void> trackVideoViews(
    List<VideoEvent> videos, {
    String source = 'mobile',
  }) async {
    if (!_analyticsEnabled || videos.isEmpty) return;

    for (final video in videos) {
      await trackVideoView(video, source: source);
    }
  }

  /// Clear tracked views cache.
  void clearTrackedViews() {
    _recentlyTrackedViews.clear();
  }

  // BackgroundAwareService implementation
  @override
  String get serviceName => 'AnalyticsService';

  @override
  void onAppBackgrounded() {
    _isInBackground = true;
  }

  @override
  void onExtendedBackground() {
    // No-op: Nostr events are fire-and-forget
  }

  @override
  void onAppResumed() {
    if (_isInBackground && _sessionIdOverride == null) {
      _sessionId = _uuid.v4();
    }
    _isInBackground = false;
  }

  void dispose() {
    // Unregister before tearing down. The manager outlives this service, so
    // an instance left in its registry keeps receiving lifecycle callbacks —
    // across provider rebuilds in the app, and across every later suite in
    // the merged test isolate (#6880).
    if (_isBackgroundRegistered) {
      _backgroundActivityManager.unregisterService(this);
      _isBackgroundRegistered = false;
    }
    _isDisposed = true;
    _cleanupTimer?.cancel();
  }
}
