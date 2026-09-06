// ABOUTME: Upload & media Riverpod providers split from app_providers.dart
// ABOUTME: Blossom upload, media-auth chain, upload manager, API clients, audio playback

import 'package:background_uploader/background_uploader.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/background_publish/publish_foreground_session.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/staged_profile_media_store.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sound_service/sound_service.dart';

part 'upload_media_providers.g.dart';

final stagedProfileMediaStoreProvider = Provider<StagedProfileMediaStore>((
  ref,
) {
  return SharedPreferencesStagedProfileMediaStore(
    preferences: ref.watch(sharedPreferencesProvider),
  );
});

/// Adapts the app-level [AuthService] to the package-level
/// [BlossomAuthProvider] interface.
class _BlossomAuthAdapter implements BlossomAuthProvider {
  const _BlossomAuthAdapter(this._authService);

  final AuthService _authService;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );
    if (event == null) return null;
    return BlossomSignedEvent(json: event.toJson());
  }
}

/// Adapts the [BackgroundUploader] plugin to the package-level
/// [BlossomBackgroundTransport] port, so the Blossom service can hand a single
/// PUT to the OS without depending on the plugin directly.
class _BackgroundUploadTransportAdapter implements BlossomBackgroundTransport {
  const _BackgroundUploadTransportAdapter(
    this._uploader, {
    required String Function() notificationTitle,
  }) : _notificationTitle = notificationTitle;

  final BackgroundUploader _uploader;

  /// Resolves the Android foreground-service notification title in the app's
  /// current locale. Owned by the app layer because the `background_uploader`
  /// plugin is intentionally domain-agnostic and l10n-free. Called per enqueue
  /// so a locale change between uploads is picked up.
  final String Function() _notificationTitle;

  @override
  Stream<BlossomBackgroundTransferEvent> get events =>
      _uploader.events.map(_toTransferEvent);

  @override
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String filePath,
  }) {
    return _uploader.enqueue(
      BackgroundUploadRequest(
        taskId: taskId,
        url: Uri.parse(url),
        filePath: filePath,
        method: method,
        headers: headers,
        notificationTitle: _notificationTitle(),
      ),
    );
  }

  @override
  Future<void> cancel(String taskId) => _uploader.cancel(taskId);

  @override
  Future<BlossomBackgroundTransferEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async {
    final event = await _uploader.takeBufferedTerminalEvent(taskId);
    return event == null ? null : _toTransferEvent(event);
  }

  static BlossomBackgroundTransferEvent _toTransferEvent(
    BackgroundUploadEvent event,
  ) {
    return BlossomBackgroundTransferEvent(
      taskId: event.taskId,
      status: switch (event.status) {
        BackgroundUploadStatus.running =>
          BlossomBackgroundTransferStatus.running,
        BackgroundUploadStatus.completed =>
          BlossomBackgroundTransferStatus.completed,
        BackgroundUploadStatus.failed => BlossomBackgroundTransferStatus.failed,
        BackgroundUploadStatus.cancelled =>
          BlossomBackgroundTransferStatus.cancelled,
      },
      progress: event.progress,
      httpStatusCode: event.httpStatusCode,
      responseBody: event.responseBody,
      error: event.error,
    );
  }
}

/// Adapts the [BackgroundUploader] plugin to the [PublishForegroundSession]
/// port, so the background-publish bloc can keep the process foregrounded for
/// the whole publish without depending on the plugin directly.
class _BackgroundUploaderForegroundSession implements PublishForegroundSession {
  const _BackgroundUploaderForegroundSession(this._uploader);

  final BackgroundUploader _uploader;

  @override
  Future<void> begin(String sessionId) =>
      _uploader.beginForegroundSession(sessionId);

  @override
  Future<void> end(String sessionId) =>
      _uploader.endForegroundSession(sessionId);
}

/// Adapts a [PerformanceTraceMonitor] to the package-level
/// [BlossomPerformanceMonitor] interface.
class _FirebasePerformanceAdapter implements BlossomPerformanceMonitor {
  _FirebasePerformanceAdapter(this._monitor);

  final PerformanceTraceMonitor _monitor;

  @override
  BlossomPerformanceTrace startOperationTrace(String traceName) =>
      _BlossomTraceAdapter(_monitor.startOperationTrace(traceName));
}

/// Adapts an app-layer [PerformanceTrace] handle to the package-level
/// [BlossomPerformanceTrace] handle.
class _BlossomTraceAdapter implements BlossomPerformanceTrace {
  _BlossomTraceAdapter(this._trace);

  final PerformanceTrace _trace;

  @override
  void setMetric(String metricName, int value) =>
      _trace.setMetric(metricName, value);

  @override
  void putAttribute(String attribute, String value) =>
      _trace.putAttribute(attribute, value);

  @override
  Future<void> stop() => _trace.stop();
}

/// Blossom BUD-01 authentication service for age-restricted content
@riverpod
BlossomAuthService blossomAuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomAuthService(authProvider: _BlossomAuthAdapter(authService));
}

/// Shared viewer auth service for media GET requests.
final mediaViewerAuthServiceProvider = Provider<MediaViewerAuthService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final blossomAuthService = ref.watch(blossomAuthServiceProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  return MediaViewerAuthService(
    authService: authService,
    blossomAuthService: blossomAuthService,
    nip98AuthService: nip98AuthService,
  );
});

/// Media authentication interceptor for handling 401 unauthorized responses
@riverpod
MediaAuthInterceptor mediaAuthInterceptor(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final mediaViewerAuthService = ref.watch(mediaViewerAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
    contentFilterService: contentFilterService,
    mediaViewerAuthService: mediaViewerAuthService,
  );
}

/// How long to pause between upload chunks while the home feed is actively
/// streaming video, so the upload yields bandwidth to playback. Applied only
/// while foreground playback is visible.
const _feedStreamingUploadChunkPause = Duration(milliseconds: 750);

/// Whether a foreground video feed is visible enough that uploads should yield
/// bandwidth between chunks.
final uploadBackpressureActiveProvider = Provider<bool>((ref) {
  if (ref.watch(activeVideoIdProvider) != null) return true;

  final isHomeFeedActive =
      ref.watch(appForegroundProvider) &&
      ref.watch(activeBranchIndexProvider) == 0 &&
      !ref.watch(shellObscuredProvider) &&
      !ref.watch(overlayVisibilityProvider).hasVisibleOverlay;
  return isHomeFeedActive;
});

/// OS-backed background upload transport (URLSession on iOS/macOS, a
/// foreground service on Android), adapted to the Blossom transport port.
final backgroundUploadTransportProvider = Provider<BlossomBackgroundTransport>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _BackgroundUploadTransportAdapter(
    BackgroundUploader.instance,
    notificationTitle: () =>
        currentAppL10n(prefs).backgroundUploadNotificationTitle,
  );
});

/// Foreground session used by the background-publish bloc to keep the process
/// network alive across the whole publish (upload + signing + relay), not just
/// the OS-backed blob transfer.
final publishForegroundSessionProvider = Provider<PublishForegroundSession>(
  (ref) => _BackgroundUploaderForegroundSession(BackgroundUploader.instance),
);

/// Blossom upload service (uses user-configured Blossom server)
@riverpod
BlossomUploadService blossomUploadService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final env = ref.read(currentEnvironmentProvider);
  return BlossomUploadService(
    authProvider: _BlossomAuthAdapter(authService),
    performanceMonitor: _FirebasePerformanceAdapter(
      ref.watch(performanceMonitoringServiceProvider),
    ),
    defaultServerUrl: env.blossomUrl,
    backgroundTransport: ref.watch(backgroundUploadTransportProvider),
    // Backpressure: while a feed video is actively playing in the foreground,
    // pause briefly between chunks so the upload doesn't starve playback on a
    // congested connection. No pause when nothing is streaming.
    betweenChunks: () async {
      if (ref.read(uploadBackpressureActiveProvider)) {
        await Future<void>.delayed(_feedStreamingUploadChunkPause);
      }
    },
  );
}

/// Whether video publishing routes through the OS background uploader so the
/// transfer survives app suspension. Kept as a kill-switch: flip to `false` to
/// fall back to the in-process chunked/resumable upload path if a regression
/// surfaces in the OS-backed path (iOS/macOS URLSession + Android foreground
/// service).
const _backgroundUploadEnabled = true;

/// Upload manager uses only Blossom upload service
@Riverpod(keepAlive: true)
UploadManager uploadManager(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  ref.watch(currentAuthStateProvider);
  final currentPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final env = ref.read(currentEnvironmentProvider);
  final manager = UploadManager(
    backgroundActivityManager: ref.read(backgroundActivityManagerProvider),
    crashReporting: ref.read(crashReportingServiceProvider),
    blossomService: blossomService,
    defaultBlossomUrl: env.blossomUrl,
    currentNostrPubkey: currentPubkey,
    scopeUploadsToCurrentUser: true,
    useBackgroundUpload: _backgroundUploadEnabled,
  );
  ref.onDispose(manager.dispose);
  return manager;
}

/// API service depends on auth service and the current environment
/// (relay-manager URL is env-aware; watching keeps env switches applied)
@riverpod
ApiService apiService(Ref ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  final environment = ref.watch(currentEnvironmentProvider);
  final service = ApiService(
    authService: authService,
    relayManagerBaseUrl: environment.relayManagerApiUrl,
    appVersion: ref.watch(appVersionProvider),
    client: ref.watch(instrumentedHttpClientFactoryProvider)(),
  );
  // Close the owned http.Client on rebuild (env switch) — in-flight requests
  // on the old instance fail over, which switchEnvironment's cache/sub reset
  // already assumes
  ref.onDispose(service.dispose);
  return service;
}

/// Crosspost API client for Bluesky toggle settings
@riverpod
CrosspostApiClient crosspostApiClient(Ref ref) {
  final oauthClient = ref.watch(oauthClientProvider);
  final config = ref.watch(oauthConfigProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(httpClient.close);
  return CrosspostApiClient(
    oauthClient: oauthClient,
    serverUrl: config.serverUrl,
    httpClient: httpClient,
  );
}

/// Repository for Bluesky toggle settings
@riverpod
BlueskyCrosspostRepository blueskyCrosspostRepository(Ref ref) {
  final profileRepository = ref.watch(profileRepositoryProvider);
  if (profileRepository == null) {
    throw StateError('ProfileRepository is not ready');
  }
  return BlueskyCrosspostRepository(
    apiClient: ref.watch(crosspostApiClientProvider),
    profileRepository: profileRepository,
  );
}

/// Crossposter service client for manual per-video crossposting
@riverpod
CrosspostingApiClient crossposterApiClient(Ref ref) {
  final oauthClient = ref.watch(oauthClientProvider);
  final client = CrosspostingApiClient(
    accessTokenReader: () async =>
        (await oauthClient.getSession())?.accessToken,
    httpClient: ref.watch(instrumentedHttpClientFactoryProvider)(),
  );
  ref.onDispose(client.close);
  return client;
}

/// Audio playback service for sound playback during recording and preview
///
/// Used by the camera screen for lip-sync recording. Handles audio
/// loading, play/pause, and cleanup. Uses keepAlive to persist across
/// the session (not auto-disposed).
@Riverpod(keepAlive: true)
AudioPlaybackService audioPlaybackService(Ref ref) {
  final service = AudioPlaybackService();

  ref.onDispose(() async {
    await service.dispose();
  });

  return service;
}

/// Audio-session-only configuration used by recorder/editor route handoffs.
///
/// Kept separate from [audioPlaybackServiceProvider] so playback routes can
/// restore `AVAudioSession` without constructing a player or starting headphone
/// detection.
final audioSessionServiceProvider = Provider<AudioSessionService>((ref) {
  return AudioSessionService();
});
