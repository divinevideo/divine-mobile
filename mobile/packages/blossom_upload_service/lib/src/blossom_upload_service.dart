// ABOUTME: Service for uploading videos to user-configured
// ABOUTME: Blossom media servers. Supports Blossom BUD-01
// ABOUTME: authentication and returns media URLs from any
// ABOUTME: Blossom server.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:blossom_upload_service/src/blossom_auth_provider.dart';
import 'package:blossom_upload_service/src/blossom_performance_monitor.dart';
import 'package:blossom_upload_service/src/blossom_resumable_upload_session.dart';
import 'package:blossom_upload_service/src/hash_util.dart';
import 'package:blossom_upload_service/src/upload_constants.dart';
import 'package:dio/dio.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Emits an upload-phase timing line.
///
/// Deliberately mirrors the format of the app layer's `logPublishPhase`
/// (token `PUBTIME`, logger name `PublishTiming`) so one `grep PUBTIME` spans
/// both layers in order. The format is duplicated rather than shared because
/// the helper lives above this package and the dependency only runs one way.
void _logUploadPhase(String phase, Duration elapsed, {String? detail}) {
  final suffix = (detail == null || detail.isEmpty) ? '' : ' $detail';
  Log.info(
    '⏱️ PUBTIME $phase ${elapsed.inMilliseconds}ms$suffix',
    name: 'PublishTiming',
    category: LogCategory.video,
  );
}

bool _hasTransientDioSignal(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode != null && statusCode >= 500) return true;

  return _hasTransientDioTransportSignal(error);
}

bool _hasTransientDioTransportSignal(DioException error) {
  return _isTransientDioType(error.type) ||
      _isRecoverableSocketCloseError(error);
}

bool _isTransientDioType(DioExceptionType type) {
  return switch (type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };
}

bool _isRecoverableSocketCloseError(DioException error) {
  if (error.type != DioExceptionType.unknown &&
      error.type != DioExceptionType.connectionError) {
    return false;
  }

  final detail = _dioErrorDetail(error).toLowerCase();
  return error.error is SocketException ||
      detail.contains('bad file descriptor') ||
      detail.contains('connection closed') ||
      detail.contains('connection reset') ||
      detail.contains('connection aborted') ||
      detail.contains('broken pipe') ||
      detail.contains('socket closed');
}

String _dioErrorDetail(DioException error) {
  final parts = <String>[
    if (error.message != null) error.message!,
    if (error.error != null) error.error.toString(),
  ];

  final inner = error.error;
  if (inner is HttpException) {
    parts.add(inner.message);
  } else if (inner is SocketException) {
    parts
      ..add(inner.message)
      ..add(inner.osError?.message ?? '');
  } else if (inner is OSError) {
    parts.add(inner.message);
  }

  return parts.where((part) => part.isNotEmpty).join(' ');
}

/// Why a Blossom upload failed.
///
/// Classification lives at the HTTP/service boundary so that callers
/// (UI, analytics, telemetry) can branch on a stable enum rather than
/// inspecting raw [BlossomUploadResult.errorMessage] text or HTTP
/// status codes themselves.
enum BlossomUploadFailureReason {
  /// Connection / send / receive timeout, connection error, transient
  /// connectivity loss. Caller may show "check your connection".
  network,

  /// Server-side authentication rejection: HTTP 401 / 403. Permanent —
  /// retrying the same request will be rejected again. Caller may prompt
  /// the user to sign in again. Does NOT cover a failure to *produce* the
  /// auth header — that is the transient [authUnavailable] below.
  auth,

  /// The service could not *produce* a signed Blossom auth header before
  /// the request was sent, because the remote signer (or the network path
  /// to it — e.g. a momentary `Failed host lookup` for the signer host)
  /// was briefly unreachable. Transient: once connectivity returns the
  /// same upload succeeds, so the caller should retry. Distinct from
  /// [auth], which is a permanent server-side rejection.
  authUnavailable,

  /// Server rejected the upload because the file exceeds size limits
  /// (HTTP 413 "payload too large"). Caller may suggest a smaller file.
  fileTooLarge,

  /// Server-side error (HTTP 5xx) — usually transient. Caller may show
  /// "our servers are temporarily unavailable".
  server,

  /// The user stopped the upload (pause / cancel) while it was in flight.
  /// User-initiated and terminal: the caller must NOT retry or fall back to
  /// another transport, and it is NOT reportable to Crashlytics. Distinct
  /// from [unknown] so a deliberate stop is never mistaken for a transport
  /// failure that warrants re-uploading the whole file.
  cancelled,

  /// Anything else: unmapped 4xx, malformed responses, configuration
  /// errors, or unexpected exceptions. Caller falls back to a generic
  /// "upload failed" message.
  unknown;

  /// Classifies an HTTP [statusCode] into a [BlossomUploadFailureReason].
  ///
  /// Returns `null` when [statusCode] is null or represents a success
  /// (`< 400`), so callers can distinguish "not a failure" from
  /// `unknown`.
  static BlossomUploadFailureReason? fromStatusCode(int? statusCode) {
    if (statusCode == null || statusCode < 400) return null;
    if (statusCode == 401 || statusCode == 403) {
      return BlossomUploadFailureReason.auth;
    }
    if (statusCode == 413) return BlossomUploadFailureReason.fileTooLarge;
    if (statusCode >= 500 && statusCode < 600) {
      return BlossomUploadFailureReason.server;
    }
    return BlossomUploadFailureReason.unknown;
  }

  /// Classifies a [DioException] into a [BlossomUploadFailureReason].
  ///
  /// Connection / timeout errors map to [network]. For [bad responses]
  /// (`DioExceptionType.badResponse`) the status code is used; if no
  /// status is available the reason falls through to [unknown].
  ///
  /// [bad responses]: https://pub.dev/documentation/dio/latest/dio/DioExceptionType.html
  static BlossomUploadFailureReason fromDioException(DioException error) {
    if (_hasTransientDioTransportSignal(error)) {
      return BlossomUploadFailureReason.network;
    }

    return fromStatusCode(error.response?.statusCode) ??
        BlossomUploadFailureReason.unknown;
  }
}

/// Result type for Blossom upload operations
class BlossomUploadResult {
  /// Creates a [BlossomUploadResult].
  const BlossomUploadResult({
    required this.success,
    this.videoId,
    this.url,
    this.fallbackUrl,
    this.streamingMp4Url,
    this.streamingHlsUrl,
    this.thumbnailUrl,
    this.streamingStatus,
    this.gifUrl,
    this.blurhash,
    this.errorMessage,
    this.statusCode,
    this.isTransientNetworkFailure = false,
    this.failureReason,
  });

  /// Whether the upload succeeded.
  final bool success;

  /// SHA-256 hash of the uploaded file.
  final String? videoId;

  /// Primary HLS URL from server.
  final String? url;

  /// R2 MP4 URL (always available immediately).
  final String? fallbackUrl;

  /// BunnyStream MP4 URL (may be processing).
  final String? streamingMp4Url;

  /// BunnyStream HLS URL (same as url).
  final String? streamingHlsUrl;

  /// Auto-generated thumbnail.
  final String? thumbnailUrl;

  /// "processing" or "ready".
  final String? streamingStatus;

  /// Deprecated - keeping for backwards compatibility.
  final String? gifUrl;

  /// Deprecated - keeping for backwards compatibility.
  final String? blurhash;

  /// Error message on failure.
  final String? errorMessage;

  /// HTTP status code on failure.
  final int? statusCode;

  /// Whether this failure was caused by a transient network condition
  /// (connection / send / receive timeout, or connection error) that the
  /// upload internals caught and converted to a result instead of
  /// rethrowing. Surfaced as a retry signal symmetric with [statusCode]
  /// for the cases where there is no HTTP status to classify on.
  final bool isTransientNetworkFailure;

  /// Typed reason for the failure, set at the HTTP/service boundary.
  ///
  /// Always `null` on success. On failure, callers should switch on this
  /// rather than parsing [errorMessage] or [statusCode] — the
  /// classification is owned by the service layer so the contract stays
  /// stable across UI, analytics, and telemetry. A `null` value on a
  /// failure result means the boundary couldn't classify the failure;
  /// callers should treat it as [BlossomUploadFailureReason.unknown].
  final BlossomUploadFailureReason? failureReason;

  /// Convenience getter for backwards compatibility.
  String? get cdnUrl => fallbackUrl ?? url;
}

/// Result type for Blossom server health checks
class BlossomHealthCheckResult {
  /// Creates a [BlossomHealthCheckResult].
  const BlossomHealthCheckResult({
    required this.isReachable,
    this.latencyMs,
    this.statusCode,
    this.serverUrl,
    this.errorMessage,
  });

  /// Whether the server is reachable.
  final bool isReachable;

  /// Latency in milliseconds.
  final int? latencyMs;

  /// HTTP status code.
  final int? statusCode;

  /// The server URL that was tested.
  final String? serverUrl;

  /// Error message if unreachable.
  final String? errorMessage;

  @override
  String toString() {
    if (isReachable) {
      return 'OK (${latencyMs}ms)';
    } else {
      return 'FAILED: ${errorMessage ?? "Unknown error"}';
    }
  }
}

/// Exception thrown when a resumable upload operation fails.
class BlossomResumableUploadException implements Exception {
  /// Creates a [BlossomResumableUploadException].
  const BlossomResumableUploadException(
    this.message, {
    this.statusCode,
    this.failureReason,
    this.isRecoverableResumableFailure = false,
  });

  /// The error message.
  final String message;

  /// HTTP status code, if applicable.
  final int? statusCode;

  /// Typed classification when the throw site already knows it — e.g. an
  /// auth-header-creation failure sets
  /// [BlossomUploadFailureReason.authUnavailable] so the boundary can tell
  /// it apart from a missing-field/malformed-response throw. `null` lets
  /// the classifier fall back to [statusCode].
  final BlossomUploadFailureReason? failureReason;

  /// Whether the session reached the resumable transfer phase and failed in a
  /// way the caller can retry by querying/resuming that same session.
  ///
  /// This is deliberately separate from [failureReason]: a connection error
  /// during `/upload/init` has no resumable state yet and can still use legacy
  /// fallback, while the same connection error during chunk PUT should preserve
  /// the session for resume.
  final bool isRecoverableResumableFailure;

  @override
  String toString() => message;
}

/// Lifecycle status of a background transfer reported by a
/// [BlossomBackgroundTransport].
enum BlossomBackgroundTransferStatus {
  /// In flight; [BlossomBackgroundTransferEvent.progress] is meaningful.
  running,

  /// The server accepted the upload (a 2xx response).
  completed,

  /// The upload failed — a transport error or a non-2xx response.
  failed,

  /// The upload was cancelled.
  cancelled,
}

/// A progress or terminal event from a [BlossomBackgroundTransport].
class BlossomBackgroundTransferEvent {
  /// Creates a [BlossomBackgroundTransferEvent].
  const BlossomBackgroundTransferEvent({
    required this.taskId,
    required this.status,
    this.progress = 0,
    this.httpStatusCode,
    this.responseBody,
    this.error,
  });

  /// Identifier correlating this event to the enqueued upload.
  final String taskId;

  /// Current lifecycle status.
  final BlossomBackgroundTransferStatus status;

  /// Fraction uploaded in `[0, 1]` while [status] is
  /// [BlossomBackgroundTransferStatus.running].
  final double progress;

  /// HTTP status code for terminal events, when the server responded.
  final int? httpStatusCode;

  /// Response body for terminal events, when available.
  final String? responseBody;

  /// Transport error for a [BlossomBackgroundTransferStatus.failed] event that
  /// was not an HTTP status (e.g. a dropped socket).
  final String? error;

  /// Whether this event is terminal (no further events follow for [taskId]).
  bool get isTerminal => status != BlossomBackgroundTransferStatus.running;
}

/// Port for an OS-backed background uploader.
///
/// Injected by the app so the Blossom service can hand a single PUT to the
/// operating system and let it finish the transfer across app suspension.
/// Kept abstract so this package takes no dependency on the concrete
/// background-upload plugin (mirroring [BlossomAuthProvider]).
abstract class BlossomBackgroundTransport {
  /// Hands a single upload request to the OS background facility.
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String filePath,
  });

  /// Cancels an in-flight background upload identified by [taskId].
  Future<void> cancel(String taskId);

  /// Progress and terminal events for all enqueued uploads, keyed by taskId.
  Stream<BlossomBackgroundTransferEvent> get events;

  /// Claims a terminal event for [taskId] that the OS delivered while nothing
  /// was listening on [events] — e.g. an upload finished while the app was
  /// dead — or `null` when none is buffered. Claiming removes it.
  Future<BlossomBackgroundTransferEvent?> takeBufferedTerminalEvent(
    String taskId,
  );
}

/// Abstraction over the payload of a Blossom upload.
///
/// Two implementations exist:
/// - [_FileUploadSource] streams from a `dart:io` [File], which the video,
///   audio and bug-report paths use to keep memory usage bounded for large
///   media on native platforms.
/// - [_BytesUploadSource] wraps a [Uint8List] held entirely in memory, which
///   the web image-upload path uses because `image_picker` hands back blob
///   URLs that `dart:io` cannot resolve.
///
/// This lets `_uploadToServer`, `_uploadToServerResumable` and `_uploadChunks`
/// share their HTTP plumbing across native and web without leaking File
/// assumptions into the bytes path.
sealed class _UploadSource {
  /// Suggested filename, sent to the resumable init endpoint and used in
  /// log lines. The bytes path threads this through from the caller; the
  /// file path derives it from the underlying URI.
  String get filename;

  /// Body to pass to a non-resumable `dio.put(data: ...)` call.
  ///
  /// File-backed sources return a `Stream<List<int>>` so dio uploads in
  /// constant memory; byte-backed sources return the [Uint8List] directly.
  /// dio accepts either — the legacy PUT path does not branch on type.
  Object getStreamingBody();

  /// Reads `[start, start + length)` from the underlying payload.
  ///
  /// Used by the resumable chunk loop. File-backed sources lazily open a
  /// single [RandomAccessFile] and reuse it across calls; byte-backed
  /// sources slice the in-memory buffer.
  ///
  /// **Not safe for concurrent calls on the same source instance.** The
  /// file impl mutates a shared `RandomAccessFile`'s position; callers
  /// must serialize. The chunk loop in `_uploadChunks` already does so.
  Future<List<int>> readRange(int start, int length);

  /// Releases any resources opened by [readRange]. Always safe to call
  /// (idempotent) and should be invoked from a `finally` once the chunk
  /// loop completes or aborts.
  Future<void> close();
}

class _FileUploadSource extends _UploadSource {
  _FileUploadSource(this.file);

  final File file;

  RandomAccessFile? _reader;

  @override
  String get filename =>
      file.uri.pathSegments.isEmpty ? 'upload.bin' : file.uri.pathSegments.last;

  @override
  Object getStreamingBody() => file.openRead();

  @override
  Future<List<int>> readRange(int start, int length) async {
    final reader = _reader ??= await file.open();
    await reader.setPosition(start);
    return reader.read(length);
  }

  @override
  Future<void> close() async {
    final reader = _reader;
    _reader = null;
    if (reader != null) {
      await reader.close();
    }
  }
}

class _BytesUploadSource extends _UploadSource {
  _BytesUploadSource({required this.bytes, required this.filename});

  final Uint8List bytes;

  @override
  final String filename;

  @override
  Object getStreamingBody() => bytes;

  @override
  Future<List<int>> readRange(int start, int length) async {
    return Uint8List.sublistView(bytes, start, start + length);
  }

  @override
  Future<void> close() async {}
}

class _DivineUploadCapability {
  const _DivineUploadCapability({
    required this.supportsResumable,
    this.controlHost,
    this.dataHost,
  });

  final bool supportsResumable;
  final String? controlHost;
  final String? dataHost;
}

class _CachedCapability {
  _CachedCapability(this.capability, this.expiresAt);

  final _DivineUploadCapability capability;
  final DateTime expiresAt;
}

/// Blossom BUD-01 media upload service with resumable upload support.
class BlossomUploadService {
  /// Creates a [BlossomUploadService].
  ///
  /// [sleep] is the awaitable used to space out retries in
  /// [_uploadWithRetry]. Defaults to `Future<void>.delayed`. Tests pass a
  /// no-op so the retry-behavior group doesn't pay real wall time on each
  /// backoff; production code should leave it at the default.
  ///
  /// [betweenChunks] is awaited once after every successfully-uploaded chunk
  /// of a resumable upload (except the last). It lets the caller apply
  /// backpressure — e.g. yield bandwidth to foreground video playback by
  /// pausing briefly while the home feed is actively streaming. The default
  /// is a no-op, so uploads run at full speed unless a host injects a policy.
  BlossomUploadService({
    required this.authProvider,
    BlossomPerformanceMonitor? performanceMonitor,
    Dio? dio,
    String? defaultServerUrl,
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
    Future<void> Function()? betweenChunks,
    this.backgroundTransport,
  }) : _performanceMonitor =
           performanceMonitor ?? const NoOpPerformanceMonitor(),
       dio = dio ?? Dio(),
       _defaultServerUrl = defaultServerUrl ?? defaultBlossomServer,
       _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed,
       _betweenChunks = betweenChunks;

  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';

  /// The default Divine Blossom media server.
  static const String defaultBlossomServer = 'https://media.divine.video';

  /// Combined wire budget for the `X-ProofMode-*` request headers.
  ///
  /// Measured against `media.divine.video`, combined request headers must
  /// stay under 128 KiB over HTTP/1.1 (past it the edge answers 502) and
  /// under 64 KiB over HTTP/2 (past it the connection is closed mid-request).
  ///
  /// An Android device attestation is the `X509Certificate.toString()` dump
  /// of the whole cert chain, so its size varies per device, and it used to
  /// travel twice — base64 inside `X-ProofMode-Manifest` and again in
  /// `X-ProofMode-Attestation`. Past roughly 47.5 KB of raw attestation the
  /// request crosses 128 KiB and every publish from that device fails, which
  /// is why the failure looked sporadic rather than universal: a Pixel 8 Pro
  /// produced 53,826 bytes and always failed, while shorter chains stayed
  /// under the line and uploaded fine.
  ///
  /// 8 KiB leaves headroom for the auth header and keeps the request inside
  /// the stricter 8 KB-per-header budget common to nginx-fronted Blossom
  /// deployments too.
  ///
  /// Dropping an oversized header loses nothing: no Blossom server reads
  /// these, and the canonical copy of the manifest is the `proofmode` tag on
  /// the kind 34236 event.
  static const int maxProofModeHeaderBytes = 8192;

  /// Maximum retries for a single chunk PUT before bubbling to the caller.
  static const int _maxChunkRetries = 2;
  static const Duration _chunkRetryDelay = Duration(seconds: 1);

  /// Default total attempts for a whole-image upload to a single server.
  /// 1 initial + 2 retries; covers transient 5xx and connection blips on
  /// `media.divine.video`. Callers that already wrap the operation in their
  /// own retry loop can pass `maxAttempts: 1` to avoid compounded delays.
  static const int _defaultUploadImageMaxAttempts = 3;

  /// Base delay between retried image upload attempts. Doubled on each retry
  /// up to [_uploadImageRetryMaxDelay].
  static const Duration _uploadImageRetryBaseDelay = Duration(seconds: 1);

  /// Hard ceiling on the per-attempt backoff for image uploads.
  static const Duration _uploadImageRetryMaxDelay = Duration(seconds: 30);

  /// HTTP status codes that justify retrying an image upload. Mirrors
  /// `UploadManager.isRetriableError` so service-level and orchestrator-level
  /// classification stay in sync.
  static const Set<int> _retriableUploadStatusCodes = {
    408, // Request timeout
    429, // Rate limited
    500, // Generic server error
    502, // Bad gateway
    503, // Service unavailable (the symptom in #3862)
    504, // Gateway timeout
  };

  /// How long a cached capability discovery result stays valid.
  static const Duration _capabilityCacheTtl = Duration(minutes: 5);

  /// How long a signed Blossom auth event stays valid. The in-process upload
  /// paths send the request within seconds of signing, so a short window is
  /// fine.
  static const Duration _defaultAuthTtl = Duration(minutes: 5);

  /// Auth TTL for the OS background path. The operating system owns the
  /// transfer and may defer it — or resume it after a long app suspension —
  /// well after [uploadVideoInBackground] signed the header. A short TTL would
  /// have expired by the time the PUT is actually sent, so the server would
  /// reject it as unauthorized; this wider window keeps the header valid.
  static const Duration _backgroundAuthTtl = Duration(hours: 6);

  /// Safety timeout for [uploadVideoInBackground]. The OS drives the transfer,
  /// so this is deliberately generous — it only exists to guarantee the
  /// returned future completes (and its event subscription is released) if the
  /// OS never reports a terminal event, e.g. the Android foreground service is
  /// killed mid-transfer.
  static const Duration _backgroundUploadTimeout = Duration(minutes: 30);

  /// Size of the uploaded file, reported on both upload traces.
  static const String _fileSizeMetric = 'file_size_bytes';

  /// Trace attribute separating completed uploads from the ones that failed.
  /// Without it a two-minute timeout and an eight-second success sit in the
  /// same duration distribution (#7121).
  static const String _outcomeAttribute = 'outcome';

  /// Attribute value for an upload that reached its terminal success state.
  static const String _outcomeSuccess = 'success';

  /// Attribute value for a trace whose operation threw instead of returning a
  /// result. Distinct from a returned failure, which carries its own reason.
  static const String _outcomeThrew = 'error:threw';

  /// Attribute value for an enqueue that never happened because the OS had
  /// already completed the transfer while the app was dead.
  static const String _outcomeReused = 'reused';

  /// The authentication provider for signing Blossom events.
  final BlossomAuthProvider authProvider;

  /// Optional OS-backed background uploader used by [uploadVideoInBackground].
  /// `null` disables background uploads; that method then fails fast.
  final BlossomBackgroundTransport? backgroundTransport;

  final BlossomPerformanceMonitor _performanceMonitor;

  /// The HTTP client used for uploads.
  final Dio dio;
  final String _defaultServerUrl;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;

  /// Awaited after each non-final chunk to let the host apply upload
  /// backpressure. `null` means no throttling.
  final Future<void> Function()? _betweenChunks;

  /// In-memory cache of capability discovery results keyed by server URL.
  final Map<String, _CachedCapability> _capabilityCache = {};

  /// Determine which Blossom server to use for upload
  ///
  /// Priority order:
  /// 1. Custom configured server (if enabled in settings)
  /// 2. Default Divine media server
  Future<List<String>> _getServerUrlsForUpload() async {
    final servers = <String>[];

    // 1. Check for custom configured server
    final isCustomServerEnabled = await isBlossomEnabled();
    if (isCustomServerEnabled) {
      final customServerUrl = await getBlossomServer();
      if (customServerUrl != null && customServerUrl.isNotEmpty) {
        servers.add(customServerUrl);
        Log.info(
          'Using custom configured server: $customServerUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
      }
    }

    // 2. Always add default Divine server as fallback
    if (!servers.contains(_defaultServerUrl)) {
      servers.add(_defaultServerUrl);
    }

    return servers;
  }

  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored or empty string, return default.
    if (stored == null || stored.isEmpty) return defaultBlossomServer;
    return stored;
  }

  /// Set the Blossom server URL
  Future<void> setBlossomServer(String? serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await prefs.setString(_blossomServerKey, serverUrl);
    } else {
      // Store empty string to indicate "no server configured"
      await prefs.setString(_blossomServerKey, '');
    }
  }

  /// Check if custom Blossom server is enabled
  /// When false (default), uploads go to Divine's Blossom server
  /// When true, uploads go to the user's custom configured server
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ??
        true; // Default to true for new installs (allow custom/non-Divine media servers)
  }

  /// Enable or disable Blossom upload.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }

  /// Create a Blossom authentication event for upload
  Future<BlossomSignedEvent?> _createBlossomAuthEvent({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
    String contentDescription = 'Upload video to Blossom server',
    Duration authTtl = _defaultAuthTtl,
  }) async {
    try {
      // Blossom requires these tags (BUD-01):
      // - t: "upload" to indicate upload request
      // - expiration: Unix timestamp when auth expires
      // - x: SHA-256 hash of the file (optional but recommended)

      final now = DateTime.now();
      final expiration = now.add(authTtl);
      final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;

      // Build tags for Blossom auth event (kind 24242)
      final tags = [
        ['t', 'upload'],
        ['expiration', expirationTimestamp.toString()],
        ['size', fileSize.toString()], // File size for server validation
        ['x', fileHash], // SHA-256 hash of the file
      ];

      // Use auth provider to create and sign the event
      final signedEvent = await authProvider.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: contentDescription,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create/sign Blossom auth event via auth provider',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        'Created Blossom auth event: ${signedEvent.json['id']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event kind: ${signedEvent.json['kind']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event pubkey: ${signedEvent.json['pubkey']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event created_at: ${signedEvent.json['created_at']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.info(
        '  Event tags: ${signedEvent.json['tags']}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return signedEvent;
    } on Object catch (e) {
      Log.error(
        'Error creating Blossom auth event: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  String _buildAuthHeader(BlossomSignedEvent authEvent) {
    final authEventJson = jsonEncode(authEvent.json);
    return 'Nostr ${base64.encode(utf8.encode(authEventJson))}';
  }

  Future<String?> _createBlossomAuthHeader({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
    required String contentDescription,
    Duration authTtl = _defaultAuthTtl,
  }) async {
    final signWatch = Stopwatch()..start();
    final authEvent = await _createBlossomAuthEvent(
      url: url,
      method: method,
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: contentDescription,
      authTtl: authTtl,
    );
    signWatch.stop();
    _logUploadPhase(
      'auth.sign',
      signWatch.elapsed,
      detail: '$method ${Uri.tryParse(url)?.path ?? url}',
    );

    if (authEvent == null) {
      return null;
    }

    return _buildAuthHeader(authEvent);
  }

  bool _validateHttpStatus(int? statusCode) =>
      statusCode != null && statusCode < 500;

  /// Whether a [DioException] from a chunk PUT is safe to retry.
  /// Returns `true` for 5xx server errors and transient network issues.
  bool _isTransientChunkError(DioException e) => _hasTransientDioSignal(e);

  bool _isTransientCapabilityDiscoveryError(DioException error) =>
      _hasTransientDioSignal(error);

  /// Whether an image-upload attempt threw a transient, retriable error.
  ///
  /// Transient = the same request stands a real chance of succeeding on a
  /// subsequent attempt (5xx server, rate limit, connection / timeout).
  ///
  /// Covers two thrown shapes symmetrically:
  ///   * [DioException] with a retriable status code (5xx, 429, 408) or a
  ///     transient connection / timeout type.
  ///   * [BlossomResumableUploadException] with a retriable status code —
  ///     thrown when chunk PUT exhausts its internal retry budget on a 5xx
  ///     and the resumable session bubbles up. An outer retry rebuilds the
  ///     session via `_initResumableUpload`. It is also transient when the
  ///     throw tagged itself [BlossomUploadFailureReason.authUnavailable]
  ///     (the signer was briefly unreachable while building the auth
  ///     header). 404/410 (session expired) and an otherwise null
  ///     statusCode (malformed-response) are intentionally not transient.
  bool _isTransientUploadError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null &&
          _retriableUploadStatusCodes.contains(statusCode)) {
        return true;
      }
      return _hasTransientDioSignal(error);
    }
    if (error is BlossomResumableUploadException) {
      if (error.isRecoverableResumableFailure ||
          error.failureReason == BlossomUploadFailureReason.authUnavailable) {
        return true;
      }
      final statusCode = error.statusCode;
      return statusCode != null &&
          _retriableUploadStatusCodes.contains(statusCode);
    }
    return false;
  }

  /// Classifies a thrown upload exception into a
  /// [BlossomUploadFailureReason].
  ///
  /// Handles the two thrown shapes the upload internals produce:
  ///
  ///   * [DioException] — delegated to
  ///     [BlossomUploadFailureReason.fromDioException].
  ///   * [BlossomResumableUploadException] — its own `failureReason` wins
  ///     when set (an auth-header build failure tags itself
  ///     [BlossomUploadFailureReason.authUnavailable]); otherwise it is
  ///     classified by `statusCode`. A throw with neither (e.g. a
  ///     malformed init response) falls through to
  ///     [BlossomUploadFailureReason.unknown].
  ///
  /// Anything else falls through to [BlossomUploadFailureReason.unknown].
  static BlossomUploadFailureReason _classifyUploadException(Object error) {
    if (error is DioException) {
      return BlossomUploadFailureReason.fromDioException(error);
    }
    if (error is BlossomResumableUploadException) {
      return error.failureReason ??
          BlossomUploadFailureReason.fromStatusCode(error.statusCode) ??
          BlossomUploadFailureReason.unknown;
    }
    return BlossomUploadFailureReason.unknown;
  }

  /// Maps an upload result onto the trace's `outcome` attribute value.
  ///
  /// A null [result] means the operation threw instead of returning, which is
  /// otherwise indistinguishable from a returned failure. Failure values are
  /// `error:<reason>`, so the attribute's cardinality is bounded by
  /// [BlossomUploadFailureReason]; an unclassified failure reports `unknown`,
  /// matching how callers are told to treat a null reason.
  ///
  /// [BlossomUploadFailureReason.cancelled] needs no special case: it is only
  /// ever produced by [_backgroundTransferResult] from an OS terminal event,
  /// which arrives after the enqueue trace has already been tagged and
  /// stopped. No traced result can carry it.
  static String _traceOutcome(BlossomUploadResult? result) {
    if (result == null) return _outcomeThrew;
    if (result.success) return _outcomeSuccess;
    final reason = result.failureReason ?? BlossomUploadFailureReason.unknown;
    return 'error:${reason.name}';
  }

  /// Whether a [BlossomUploadResult] failure is transient and worth retrying.
  ///
  /// Some failure modes are caught inside the upload internals (notably the
  /// legacy PUT path through [_uploadToServer]) and surface as
  /// `success: false` rather than re-throwing. Two signals classify a
  /// caught failure as transient, symmetric with [_isTransientUploadError]:
  ///
  ///   * `statusCode` is in the retriable set (5xx, 429, 408), or
  ///   * `isTransientNetworkFailure` is `true` — set by [_uploadToServer]
  ///     when it caught a [DioException] of type connection / send /
  ///     receive timeout or connection error and converted it to a result
  ///     (these have no HTTP status to classify on), or
  ///   * `failureReason` is [BlossomUploadFailureReason.authUnavailable] —
  ///     the signer was briefly unreachable while building the auth header
  ///     ([_uploadToServer] returns this instead of throwing).
  bool _isTransientUploadResult(BlossomUploadResult result) {
    if (result.success) return false;
    if (result.isTransientNetworkFailure) return true;
    if (result.failureReason == BlossomUploadFailureReason.authUnavailable) {
      return true;
    }
    final statusCode = result.statusCode;
    return statusCode != null &&
        _retriableUploadStatusCodes.contains(statusCode);
  }

  /// Run [attempt] up to [maxAttempts] times with exponential backoff,
  /// stopping early on success or on a non-transient failure.
  ///
  /// `maxAttempts == 1` disables retry for callers that already wrap the call
  /// in their own retry loop and want to avoid compounded delays.
  Future<BlossomUploadResult> _uploadWithRetry({
    required Future<BlossomUploadResult> Function() attempt,
    required int maxAttempts,
    required String debugContext,
  }) async {
    var attemptNumber = 0;
    while (true) {
      attemptNumber++;
      BlossomUploadResult? result;
      Object? thrown;
      StackTrace? thrownStackTrace;
      try {
        result = await attempt();
      } on Object catch (e, stackTrace) {
        thrown = e;
        thrownStackTrace = stackTrace;
      }

      // Success path — return immediately.
      if (result != null && result.success) {
        return result;
      }

      // Decide whether the failure is retriable.
      final retriable = thrown != null
          ? _isTransientUploadError(thrown)
          : _isTransientUploadResult(result!);

      // Out of budget, or the failure mode is permanent — surface it.
      if (attemptNumber >= maxAttempts || !retriable) {
        if (thrown != null) {
          // The original throwable is preserved so callers see the same
          // exception type and stack trace (DioException,
          // BlossomResumableUploadException, etc.) they would have seen
          // without the retry wrapper.
          Error.throwWithStackTrace(thrown, thrownStackTrace!);
        }
        return result!;
      }

      // Compute the next backoff. Exponential: base, base*2, base*4 ...
      // capped at the configured ceiling. attemptNumber is 1-indexed and
      // we've just *finished* attempt N, so the multiplier is 2^(N-1).
      final multiplier = 1 << (attemptNumber - 1);
      final backoffMs = _uploadImageRetryBaseDelay.inMilliseconds * multiplier;
      final cappedMs = math.min(
        backoffMs,
        _uploadImageRetryMaxDelay.inMilliseconds,
      );
      final delay = Duration(milliseconds: cappedMs);

      Log.warning(
        'Image upload attempt $attemptNumber/$maxAttempts failed '
        '($debugContext); retrying in ${delay.inMilliseconds}ms',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      await _sleep(delay);
    }
  }

  bool _isDivineOwnedUploadHost(String serverUrl) {
    final host = Uri.tryParse(serverUrl)?.host.toLowerCase();
    if (host == null || host.isEmpty) {
      return false;
    }

    return host == 'divine.video' || host.endsWith('.divine.video');
  }

  Future<BlossomUploadResult> _uploadToServerLegacyFallback({
    required String serverUrl,
    required _UploadSource source,
    required String fileHash,
    required int fileSize,
    required String contentType,
    required String fallbackReason,
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    Log.warning(
      'Falling back to legacy upload for $serverUrl '
      'after resumable failure: $fallbackReason',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    return _uploadToServer(
      serverUrl: serverUrl,
      source: source,
      fileHash: fileHash,
      fileSize: fileSize,
      contentType: contentType,
      proofManifestJson: proofManifestJson,
      onProgress: onProgress,
    );
  }

  /// Run the resumable upload first, then fall back to legacy PUT at most once
  /// for Divine-owned hosts when resumable upload either throws or returns a
  /// failure result.
  Future<BlossomUploadResult> _uploadWithSingleLegacyFallback({
    required String serverUrl,
    required Future<BlossomUploadResult> Function() uploadResumable,
    required Future<BlossomUploadResult> Function(String fallbackReason)
    uploadLegacyFallback,
  }) async {
    final isDivineOwnedHost = _isDivineOwnedUploadHost(serverUrl);
    Object? resumableError;
    late BlossomUploadResult result;

    try {
      result = await uploadResumable();
    } catch (error) {
      if (!isDivineOwnedHost) {
        rethrow;
      }

      resumableError = error;
      result = BlossomUploadResult(
        success: false,
        errorMessage: error.toString(),
        failureReason: _classifyUploadException(error),
      );
    }

    if (!isDivineOwnedHost || result.success) {
      return result;
    }

    if (resumableError is BlossomResumableUploadException &&
        resumableError.isRecoverableResumableFailure) {
      return result;
    }

    return uploadLegacyFallback(
      resumableError?.toString() ??
          result.errorMessage ??
          'unknown resumable failure',
    );
  }

  Map<String, String>? _parseRequiredHeaders(dynamic headersData) {
    if (headersData is! Map) {
      return null;
    }

    return headersData.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  DateTime? _parseDateTimeValue(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    final numericMatch = RegExp(r'^-?\d+$').firstMatch(value);
    if (numericMatch != null) {
      final epochValue = int.tryParse(value);
      if (epochValue == null) {
        return null;
      }

      final epochMillis = value.length <= 10 ? epochValue * 1000 : epochValue;
      return DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true);
    }

    return DateTime.tryParse(value);
  }

  int? _parseUploadOffset(Headers headers) {
    final rawOffset = headers.value(DivineUploadHeaders.uploadOffset);
    return rawOffset == null ? null : int.tryParse(rawOffset);
  }

  DateTime? _parseUploadExpiresAt(Headers headers) => _parseDateTimeValue(
    headers.value(DivineUploadHeaders.uploadExpiresAt) ??
        headers.value('Upload-Expires'),
  );

  Future<_DivineUploadCapability> _fetchDivineUploadCapability(
    String serverUrl,
  ) async {
    final cached = _capabilityCache[serverUrl];
    if (cached != null && _clock().isBefore(cached.expiresAt)) {
      Log.debug(
        'Using cached capability for $serverUrl',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return cached.capability;
    }

    try {
      final response = await dio.head<dynamic>(
        '$serverUrl/upload',
        options: Options(
          validateStatus: _validateHttpStatus,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final extensionsHeader = response.headers.value(
        DivineUploadHeaders.extensions,
      );
      final supportsResumable =
          extensionsHeader
              ?.split(',')
              .map((value) => value.trim().toLowerCase())
              .contains(DivineUploadExtensions.resumableSessions) ??
          false;

      final result = _DivineUploadCapability(
        supportsResumable: supportsResumable,
        controlHost: response.headers.value(DivineUploadHeaders.controlHost),
        dataHost: response.headers.value(DivineUploadHeaders.dataHost),
      );

      _capabilityCache[serverUrl] = _CachedCapability(
        result,
        _clock().add(_capabilityCacheTtl),
      );

      return result;
    } on DioException catch (error) {
      Log.warning(
        'Capability discovery failed for $serverUrl: ${error.message}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      if (_isDivineOwnedUploadHost(serverUrl) &&
          _isTransientCapabilityDiscoveryError(error)) {
        final fallback = cached?.capability.supportsResumable == true
            ? cached!.capability
            : const _DivineUploadCapability(supportsResumable: true);

        Log.warning(
          'Assuming resumable upload support for Divine '
          'host $serverUrl after transient capability '
          'probe failure',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        _capabilityCache[serverUrl] = _CachedCapability(
          fallback,
          _clock().add(_capabilityCacheTtl),
        );

        return fallback;
      }

      const fallback = _DivineUploadCapability(supportsResumable: false);

      _capabilityCache[serverUrl] = _CachedCapability(
        fallback,
        _clock().add(_capabilityCacheTtl),
      );

      return fallback;
    }
  }

  Future<BlossomResumableUploadSession> _initResumableUpload({
    required String serverUrl,
    required String fileHash,
    required int fileSize,
    required String contentType,
    required String fileName,
  }) async {
    final authHeader = await _createBlossomAuthHeader(
      url: '$serverUrl/upload/init',
      method: 'POST',
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: 'Initialize resumable Blossom upload',
    );
    if (authHeader == null) {
      throw const BlossomResumableUploadException(
        'Failed to create Blossom authentication for resumable upload init',
        failureReason: BlossomUploadFailureReason.authUnavailable,
      );
    }

    Log.info(
      '📤 Resumable init: POST $serverUrl/upload/init '
      '(file: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );
    final initStopwatch = Stopwatch()..start();

    final response = await dio.post<dynamic>(
      '$serverUrl/upload/init',
      data: {
        'sha256': fileHash,
        'size': fileSize,
        'contentType': contentType,
        'fileName': fileName,
      },
      options: Options(
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        validateStatus: _validateHttpStatus,
      ),
    );
    initStopwatch.stop();

    Log.info(
      '📤 Resumable init response: ${response.statusCode} '
      'in ${initStopwatch.elapsedMilliseconds}ms',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    final responseData = response.data;
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        responseData is! Map) {
      throw BlossomResumableUploadException(
        'Failed to initialize resumable upload: '
        '${response.statusCode} ${response.data}',
        statusCode: response.statusCode,
      );
    }

    final uploadId = responseData['uploadId']?.toString();
    final uploadUrl = responseData['uploadUrl']?.toString();
    final chunkSize = (responseData['chunkSize'] as num?)?.toInt();
    final nextOffset = (responseData['nextOffset'] as num?)?.toInt() ?? 0;

    if (uploadId == null ||
        uploadId.isEmpty ||
        uploadUrl == null ||
        uploadUrl.isEmpty ||
        chunkSize == null ||
        chunkSize <= 0) {
      throw const BlossomResumableUploadException(
        'Resumable upload init response is missing required fields',
      );
    }

    final totalChunks = (fileSize / chunkSize).ceil();
    Log.info(
      '📤 Resumable session created: uploadId=$uploadId, '
      'chunkSize=${(chunkSize / 1024).toStringAsFixed(0)}KB, '
      'totalChunks=$totalChunks, nextOffset=$nextOffset',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    return BlossomResumableUploadSession(
      uploadId: uploadId,
      uploadUrl: uploadUrl,
      chunkSize: chunkSize,
      nextOffset: nextOffset,
      expiresAt: _parseDateTimeValue(responseData['expiresAt']),
      requiredHeaders: _parseRequiredHeaders(responseData['requiredHeaders']),
    );
  }

  Future<BlossomResumableUploadSession> _queryResumableUploadSession(
    BlossomResumableUploadSession session,
  ) async {
    final response = await dio.head<dynamic>(
      session.uploadUrl,
      options: Options(
        headers: session.requiredHeaders,
        validateStatus: _validateHttpStatus,
      ),
    );

    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404 ||
        response.statusCode == 410) {
      throw BlossomResumableUploadException(
        'Resumable upload session is no longer available',
        statusCode: response.statusCode,
        failureReason: BlossomUploadFailureReason.fromStatusCode(
          response.statusCode,
        ),
      );
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw BlossomResumableUploadException(
        'Failed to query resumable upload session: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return session.copyWith(
      nextOffset: _parseUploadOffset(response.headers) ?? session.nextOffset,
      expiresAt: _parseUploadExpiresAt(response.headers) ?? session.expiresAt,
    );
  }

  Future<BlossomResumableUploadSession> _uploadChunks({
    required BlossomResumableUploadSession session,
    required _UploadSource source,
    required int fileSize,
    void Function(double)? onProgress,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
  }) async {
    var currentSession = session;
    final totalChunks = (fileSize / currentSession.chunkSize).ceil();
    final startOffset = currentSession.nextOffset;
    var chunkIndex = 0;
    final uploadStopwatch = Stopwatch()..start();

    Log.info(
      '📤 Chunk upload starting: '
      '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB '
      'in ~$totalChunks chunks '
      '(${(currentSession.chunkSize / 1024).toStringAsFixed(0)}KB each)'
      '${startOffset > 0 ? ', resuming from offset $startOffset' : ''}',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    try {
      while (currentSession.nextOffset < fileSize) {
        final start = currentSession.nextOffset;
        final endExclusive = math.min(
          start + currentSession.chunkSize,
          fileSize,
        );
        final chunkLength = endExclusive - start;
        chunkIndex++;

        final chunkBytes = await source.readRange(start, chunkLength);

        // Per-chunk retry for transient 5xx / network errors.
        // Chunk bytes are already in memory so retries are cheap.
        late Response<dynamic> response;
        var chunkAttempt = 0;
        late Stopwatch chunkStopwatch;
        while (true) {
          chunkStopwatch = Stopwatch()..start();
          try {
            response = await dio.put<dynamic>(
              currentSession.uploadUrl,
              data: chunkBytes,
              options: Options(
                headers: {
                  'Content-Type': 'application/octet-stream',
                  'Content-Length': chunkLength.toString(),
                  'Content-Range': 'bytes $start-${endExclusive - 1}/$fileSize',
                  ...?currentSession.requiredHeaders,
                },
                validateStatus: _validateHttpStatus,
              ),
              // coverage:ignore-start
              onSendProgress: (sent, total) {
                if (fileSize <= 0) {
                  return;
                }
                final progress = 0.2 + ((start + sent) / fileSize) * 0.7;
                onProgress?.call(progress.clamp(0.2, 0.9));
              },
              // coverage:ignore-end
            );
            break;
          } on DioException catch (e) {
            chunkAttempt++;
            if (chunkAttempt > _maxChunkRetries || !_isTransientChunkError(e)) {
              if (_hasTransientDioSignal(e)) {
                throw BlossomResumableUploadException(
                  'Recoverable resumable upload failure: $e',
                  statusCode: e.response?.statusCode,
                  failureReason: BlossomUploadFailureReason.fromDioException(e),
                  isRecoverableResumableFailure: true,
                );
              }
              rethrow;
            }
            Log.warning(
              'Chunk PUT failed at offset $start '
              '(attempt $chunkAttempt/$_maxChunkRetries): '
              '${e.response?.statusCode ?? e.type}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            await Future<void>.delayed(_chunkRetryDelay);
          }
        }

        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 404 ||
            response.statusCode == 410) {
          throw BlossomResumableUploadException(
            'Resumable upload session expired during chunk upload',
            statusCode: response.statusCode,
            failureReason: BlossomUploadFailureReason.fromStatusCode(
              response.statusCode,
            ),
          );
        }
        if (response.statusCode != 200 &&
            response.statusCode != 201 &&
            response.statusCode != 204) {
          final xReason =
              response.headers.value('X-Reason') ??
              response.headers.value('x-reason'); // coverage:ignore-line
          final statusCode = response.statusCode;
          // A transient status leaves the session intact: the offset has not
          // moved and the same chunk can be resent. Falling back to the
          // legacy whole-file PUT would be strictly worse on a link that just
          // failed to finish a single chunk. 5xx never lands here — it throws
          // a DioException — so in practice this covers the edge timeout
          // (408) and rate limiting (429). Retrying is left to the outer
          // policy, whose exponential backoff suits a server that has already
          // spent its own timeout waiting.
          throw BlossomResumableUploadException(
            'Chunk upload failed: $statusCode '
            '${xReason ?? response.data}', // coverage:ignore-line
            statusCode: statusCode,
            isRecoverableResumableFailure:
                statusCode != null &&
                _retriableUploadStatusCodes.contains(statusCode),
          );
        }

        chunkStopwatch.stop();
        final chunkMs = chunkStopwatch.elapsedMilliseconds;
        // coverage:ignore-start
        final chunkSpeed = chunkMs > 0
            ? (chunkLength / 1024 / (chunkMs / 1000)).toStringAsFixed(0)
            : '?';
        // coverage:ignore-end
        Log.debug(
          '📤 Chunk $chunkIndex/$totalChunks: '
          '${(chunkLength / 1024).toStringAsFixed(0)}KB '
          'in ${chunkMs}ms (${chunkSpeed}KB/s) '
          '[${(endExclusive / fileSize * 100).toStringAsFixed(0)}%]',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        currentSession = currentSession.copyWith(
          nextOffset: _parseUploadOffset(response.headers) ?? endExclusive,
          expiresAt:
              _parseUploadExpiresAt(response.headers) ??
              currentSession.expiresAt,
        );
        onResumableSessionUpdated?.call(currentSession);

        // Yield bandwidth between chunks when the host asks for backpressure
        // (e.g. foreground video is streaming). No-op when no policy is set
        // or when this was the final chunk.
        if (currentSession.nextOffset < fileSize) {
          await _betweenChunks?.call();
        }
      }

      uploadStopwatch.stop();
      final totalMs = uploadStopwatch.elapsedMilliseconds;
      final bytesThisSession = fileSize - startOffset;
      final avgSpeed = totalMs > 0
          ? (bytesThisSession / 1024 / 1024 / (totalMs / 1000)).toStringAsFixed(
              2,
            )
          : '?';
      Log.info(
        '📤 Chunk upload complete: '
        '$chunkIndex chunks this session '
        '($totalChunks total), '
        '${(totalMs / 1000).toStringAsFixed(1)}s, '
        '${avgSpeed}MB/s avg',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return currentSession;
    } finally {
      await source.close();
    }
  }

  Future<BlossomUploadResult> _completeResumableUpload({
    required String serverUrl,
    required BlossomResumableUploadSession session,
    required String fileHash,
    required int fileSize,
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    final authHeader = await _createBlossomAuthHeader(
      url: '$serverUrl/upload/${session.uploadId}/complete',
      method: 'POST',
      fileHash: fileHash,
      fileSize: fileSize,
      contentDescription: 'Complete resumable Blossom upload',
    );
    if (authHeader == null) {
      throw const BlossomResumableUploadException(
        'Failed to create Blossom authentication for '
        'resumable upload completion',
        failureReason: BlossomUploadFailureReason.authUnavailable,
      );
    }

    final headers = <String, dynamic>{
      'Authorization': authHeader,
      'Content-Type': 'application/json',
    };

    if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
      _addProofModeHeaders(headers, proofManifestJson);
    }

    Log.info(
      '📤 Completing resumable upload: '
      '${session.uploadId}',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );
    final completeStopwatch = Stopwatch()..start();

    final response = await dio.post<dynamic>(
      '$serverUrl/upload/${session.uploadId}/complete',
      data: {'sha256': fileHash},
      options: Options(headers: headers, validateStatus: _validateHttpStatus),
    );
    completeStopwatch.stop();

    Log.info(
      '📤 Complete response: ${response.statusCode} '
      'in ${completeStopwatch.elapsedMilliseconds}ms',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    return _parseUploadResponse(
      response,
      fileHash: fileHash,
      onProgress: onProgress,
    );
  }

  Future<BlossomUploadResult> _uploadToServerResumable({
    required String serverUrl,
    required _UploadSource source,
    required String fileHash,
    required int fileSize,
    required String contentType,
    String? proofManifestJson,
    BlossomResumableUploadSession? resumableSession,
    void Function(double)? onProgress,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
  }) async {
    final now = _clock();
    final persistedSessionExpired =
        resumableSession?.expiresAt != null &&
        !now.isBefore(resumableSession!.expiresAt!);

    final initialSession = resumableSession == null || persistedSessionExpired
        ? await _initResumableUpload(
            serverUrl: serverUrl,
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: contentType,
            fileName: source.filename,
          )
        : await _queryResumableUploadSession(resumableSession);
    onResumableSessionUpdated?.call(initialSession);

    final uploadedSession = await _uploadChunks(
      session: initialSession,
      source: source,
      fileSize: fileSize,
      onProgress: onProgress,
      onResumableSessionUpdated: onResumableSessionUpdated,
    );

    return _completeResumableUpload(
      serverUrl: serverUrl,
      session: uploadedSession,
      fileHash: fileHash,
      fileSize: fileSize,
      proofManifestJson: proofManifestJson,
      onProgress: onProgress,
    );
  }

  BlossomUploadResult _parseUploadResponse(
    Response<dynamic> response, {
    required String fileHash,
    void Function(double)? onProgress,
  }) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = response.data;

      Log.debug(
        'Server response data type: ${responseData.runtimeType}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.debug(
        'Server response data: $responseData',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      if (responseData is Map) {
        final url = responseData['url']?.toString();
        final fallbackUrl = responseData['fallbackUrl']?.toString();

        Log.debug(
          'Parsed response: url=$url, fallbackUrl=$fallbackUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        var thumbnailUrl = responseData['thumbnail']?.toString() ?? fallbackUrl;

        String? streamingMp4Url;
        String? streamingHlsUrl;
        String? streamingStatus;

        final streamingData = responseData['streaming'];
        if (streamingData is Map) {
          streamingMp4Url = streamingData['mp4Url']?.toString();
          streamingHlsUrl = streamingData['hlsUrl']?.toString();
          thumbnailUrl =
              streamingData['thumbnailUrl']?.toString() ??
              streamingData['thumbnail']?.toString() ??
              thumbnailUrl;
          streamingStatus = streamingData['status']?.toString();
        }

        if (url != null && url.isNotEmpty) {
          onProgress?.call(1);

          return BlossomUploadResult(
            success: true,
            url: url,
            fallbackUrl: fallbackUrl,
            streamingMp4Url: streamingMp4Url,
            streamingHlsUrl: streamingHlsUrl,
            thumbnailUrl: thumbnailUrl,
            streamingStatus: streamingStatus,
            videoId: fileHash,
          );
        }
      }

      return const BlossomUploadResult(
        success: false,
        errorMessage: 'Upload response missing URL field',
        failureReason: BlossomUploadFailureReason.unknown,
      );
    }

    if (response.statusCode == 409) {
      final existingUrl = '$_defaultServerUrl/$fileHash';
      onProgress?.call(1);

      return BlossomUploadResult(
        success: true,
        fallbackUrl: existingUrl,
        videoId: fileHash,
      );
    }

    final xReason =
        response.headers.value('X-Reason') ??
        response.headers.value('x-reason');

    return BlossomUploadResult(
      success: false,
      statusCode: response.statusCode,
      errorMessage:
          'Upload failed: ${response.statusCode} - ${xReason ?? response.data}',
      failureReason:
          BlossomUploadFailureReason.fromStatusCode(response.statusCode) ??
          BlossomUploadFailureReason.unknown,
    );
  }

  /// Core upload logic to a single Blossom server.
  ///
  /// This method encapsulates the common upload flow used by
  /// all upload methods. It handles file streaming, auth events,
  /// progress callbacks, and response parsing.
  Future<BlossomUploadResult> _uploadToServer({
    required String serverUrl,
    required _UploadSource source,
    required String fileHash,
    required int fileSize,
    required String contentType,
    String contentDescription = 'Upload video to Blossom server',
    String? proofManifestJson,
    void Function(double)? onProgress,
  }) async {
    try {
      // Validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        // coverage:ignore-start
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL: $serverUrl',
          failureReason: BlossomUploadFailureReason.unknown,
        );
        // coverage:ignore-end
      }

      final authHeader = await _createBlossomAuthHeader(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
        contentDescription: contentDescription,
      );
      if (authHeader == null) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
          failureReason: BlossomUploadFailureReason.authUnavailable,
        );
      }

      // Add ProofMode headers if manifest is provided
      final headers = <String, dynamic>{
        'Authorization': authHeader,
        'Content-Type': contentType,
        'Content-Length': fileSize.toString(),
      };

      if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
        _addProofModeHeaders(headers, proofManifestJson);
      }

      Log.debug(
        'Sending PUT request to $serverUrl/upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      Log.debug(
        '  File size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // PUT body comes from the upload source: a streamed `Stream<List<int>>`
      // for file-backed sources (constant-memory upload, used for video and
      // audio) or the raw `Uint8List` for byte-backed sources (used by the
      // web image-upload path where there is no filesystem to stream from).
      final putWatch = Stopwatch()..start();
      final response = await dio.put<dynamic>(
        '$serverUrl/upload',
        data: source.getStreamingBody(),
        options: Options(
          headers: headers,
          validateStatus: // coverage:ignore-start
          (status) =>
              status != null && status < 500,
          // coverage:ignore-end
        ),
        // coverage:ignore-start
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            // Progress from 20% to 90% during upload
            final progress = 0.2 + (sent / total) * 0.7;
            onProgress(progress);
          }
        },
        // coverage:ignore-end
      );

      putWatch.stop();
      _logUploadPhase(
        'net.put',
        putWatch.elapsed,
        detail: '$fileSize bytes -> ${response.statusCode}',
      );

      Log.debug(
        'Server response: ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return _parseUploadResponse(
        response,
        fileHash: fileHash,
        onProgress: onProgress,
      );
    } on DioException catch (e) {
      // Build detailed error message
      var errorDetail = e.message ?? 'Unknown error';
      if (e.error != null) {
        errorDetail = '$errorDetail (${e.error})';
      }

      final statusCode = e.response?.statusCode;

      if (e.type == DioExceptionType.connectionTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Connection timeout - check server URL',
          isTransientNetworkFailure: true,
          failureReason: BlossomUploadFailureReason.network,
        );
      } else if (e.type == DioExceptionType.sendTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Send timeout - upload too slow or connection dropped',
          isTransientNetworkFailure: true,
          failureReason: BlossomUploadFailureReason.network,
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Receive timeout - server not responding',
          isTransientNetworkFailure: true,
          failureReason: BlossomUploadFailureReason.network,
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Cannot connect to Blossom server: $errorDetail',
          isTransientNetworkFailure: true,
          failureReason: BlossomUploadFailureReason.network,
        );
      } else if (e.type == DioExceptionType.cancel) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Upload cancelled',
          failureReason: BlossomUploadFailureReason.unknown,
        );
      } else if (e.type == DioExceptionType.badResponse) {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Server error ($statusCode): $errorDetail',
          failureReason:
              BlossomUploadFailureReason.fromStatusCode(statusCode) ??
              BlossomUploadFailureReason.unknown,
        );
      } else {
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Network error: $errorDetail',
          failureReason: BlossomUploadFailureReason.fromDioException(e),
        );
      }
    } on Object catch (e) {
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Upload error: $e',
        failureReason: BlossomUploadFailureReason.unknown,
      );
    }
  }

  /// Upload a video file to the configured Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// [proofManifestJson] - Optional ProofMode manifest JSON
  /// string for cryptographic proof.
  Future<BlossomUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    required String title,
    required String? proofManifestJson,
    required String? description,
    required List<String>? hashtags,
    BlossomResumableUploadSession? resumableSession,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
    void Function(double)? onProgress,
  }) async {
    // Check authentication before attempting any uploads. Deliberately ahead
    // of the trace: a signed-out attempt is rejected without a single await,
    // and timing it only adds near-zero samples to the distribution for the
    // work itself (#7119). This buys nothing for the other pre-network exits —
    // a missing file still throws out of `HashUtil.sha256File` below and
    // reports a few-millisecond trace tagged `error:unknown`. The `outcome`
    // attribute is what keeps those filterable.
    if (!authProvider.isAuthenticated) {
      Log.error(
        'User not authenticated - cannot sign Blossom requests',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return const BlossomUploadResult(
        success: false,
        errorMessage: 'User not authenticated - please sign in to upload',
        failureReason: BlossomUploadFailureReason.auth,
      );
    }

    // Operation-scoped: this upload owns the handle, so a concurrent upload
    // gets its own trace instead of truncating this one.
    final trace = _performanceMonitor.startOperationTrace(uploadTraceName);

    // Set on every exit so the `finally` can tag the outcome. The catch-all
    // below converts every throw into an assigned return, so on this path it
    // is never actually null — the null branch of [_traceOutcome] is carried
    // for `uploadVideoInBackground`, whose outer `finally` can be reached with
    // no result at all.
    BlossomUploadResult? tracedResult;

    try {
      Log.info(
        'User is authenticated, can create signed events',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      // Report initial progress
      onProgress?.call(0.1);

      // Use streaming hash computation to avoid loading entire
      // file into memory. This is critical for iOS where large
      // files (40MB+) can cause memory issues.
      final hashResult = await HashUtil.sha256File(videoFile);
      final fileSize = hashResult.size;
      final fileHash = hashResult.hash;

      trace.setMetric(_fileSizeMetric, fileSize);

      Log.info(
        'File hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers in priority order',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting video upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          final capability = await _fetchDivineUploadCapability(serverUrl);
          final hasProofModeData =
              proofManifestJson != null && proofManifestJson.isNotEmpty;
          final useResumable = capability.supportsResumable;

          if (useResumable) {
            Log.info(
              hasProofModeData
                  ? 'Using Divine resumable upload flow '
                        'for $serverUrl with ProofMode '
                        'metadata on completion'
                  : 'Using Divine resumable upload flow '
                        'for $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
          }

          late BlossomUploadResult result;
          final videoSource = _FileUploadSource(videoFile);
          if (useResumable) {
            result = await _uploadWithSingleLegacyFallback(
              serverUrl: serverUrl,
              uploadResumable: () => _uploadToServerResumable(
                serverUrl: serverUrl,
                source: videoSource,
                fileHash: fileHash,
                fileSize: fileSize,
                contentType: 'video/mp4',
                proofManifestJson: proofManifestJson,
                resumableSession: resumableSession,
                onProgress: onProgress,
                onResumableSessionUpdated: onResumableSessionUpdated,
              ),
              uploadLegacyFallback: (fallbackReason) =>
                  _uploadToServerLegacyFallback(
                    serverUrl: serverUrl,
                    source: videoSource,
                    fileHash: fileHash,
                    fileSize: fileSize,
                    contentType: 'video/mp4',
                    proofManifestJson: proofManifestJson,
                    onProgress: onProgress,
                    fallbackReason: fallbackReason,
                  ),
            );
          } else {
            result = await _uploadToServer(
              serverUrl: serverUrl,
              source: videoSource,
              fileHash: fileHash,
              fileSize: fileSize,
              contentType: 'video/mp4',
              proofManifestJson: proofManifestJson,
              onProgress: onProgress,
            );
          }

          if (result.success) {
            // Construct the canonical Blossom URL from server + hash
            // Per Blossom spec (BUD-01), blobs are always at {server}/{sha256}
            // This is deterministic and doesn't depend on server response
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              'Video uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Server response URL: ${result.url}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Thumbnail: ${result.thumbnailUrl}',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Video ID (hash): $fileHash',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            // Return with canonical URL to ensure we never publish
            // a non-HTTP URL (e.g. local file path)
            return tracedResult = BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
              thumbnailUrl: result.thumbnailUrl,
              streamingMp4Url: result.streamingMp4Url,
              streamingHlsUrl: result.streamingHlsUrl,
              streamingStatus: result.streamingStatus,
            );
          }

          lastError = result;
          Log.warning(
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
            failureReason: _classifyUploadException(e),
          );
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
        }
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for video upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return tracedResult =
          lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
            failureReason: BlossomUploadFailureReason.unknown,
          );
    } on Object catch (e) {
      Log.error(
        'Blossom upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return tracedResult = BlossomUploadResult(
        success: false,
        errorMessage: 'Blossom upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    } finally {
      trace.putAttribute(_outcomeAttribute, _traceOutcome(tracedResult));
      await trace.stop();
    }
  }

  /// Uploads [videoFile] through the injected [backgroundTransport] as a
  /// single Blossom BUD-01 `PUT`, letting the OS finish the transfer across
  /// app suspension.
  ///
  /// Unlike [uploadVideo], this does not chunk or fall back across servers — an
  /// OS background transfer is a single request to the default server. The
  /// returned future completes when the transfer reaches a terminal state,
  /// which — after the app was suspended mid-upload — is when it resumes.
  ///
  /// [taskId] correlates the transfer; pass a stable id (e.g. the pending-
  /// upload id) so it can be reconciled after a relaunch. Returns a failure
  /// result (rather than throwing) when no transport is configured, the user
  /// is unauthenticated, or the auth header cannot be built.
  Future<BlossomUploadResult> uploadVideoInBackground({
    required File videoFile,
    required String taskId,
    required String? proofManifestJson,
    void Function(double)? onProgress,
    Duration timeout = _backgroundUploadTimeout,
  }) async {
    final transport = backgroundTransport;
    if (transport == null) {
      return const BlossomUploadResult(
        success: false,
        errorMessage: 'Background upload transport is not configured',
        failureReason: BlossomUploadFailureReason.unknown,
      );
    }

    if (!authProvider.isAuthenticated) {
      return const BlossomUploadResult(
        success: false,
        errorMessage: 'User not authenticated - please sign in to upload',
        failureReason: BlossomUploadFailureReason.auth,
      );
    }

    // Reports under [enqueueTraceName], not [uploadTraceName]: this trace
    // covers only the in-process handoff, while `uploadVideo` times a whole
    // transfer. Sharing one name blended the two into a distribution that
    // described neither (#7119).
    final trace = _performanceMonitor.startOperationTrace(enqueueTraceName);
    var traceRunning = true;
    Future<void> stopTraceOnce(String outcome) async {
      if (!traceRunning) return;
      traceRunning = false;
      trace.putAttribute(_outcomeAttribute, outcome);
      await trace.stop();
    }

    try {
      onProgress?.call(0.1);
      final hashResult = await HashUtil.sha256File(videoFile);
      final fileSize = hashResult.size;
      final fileHash = hashResult.hash;
      trace.setMetric(_fileSizeMetric, fileSize);
      onProgress?.call(0.2);

      final serverUrl = (await _getServerUrlsForUpload()).first;

      // Startup reconciliation: if the OS already finished this upload while
      // the app was dead, its terminal event was buffered by the transport.
      // Claim it and skip re-uploading the whole file. A failed/cancelled
      // buffered event is simply discarded so this retry proceeds normally.
      final buffered = await transport.takeBufferedTerminalEvent(taskId);
      if (buffered != null &&
          buffered.status == BlossomBackgroundTransferStatus.completed) {
        final result = _backgroundTransferResult(
          buffered,
          fileHash: fileHash,
          serverUrl: serverUrl,
        );
        if (result.success) {
          onProgress?.call(1);
          // The OS finished this transfer while the app was dead, so no
          // handoff happened. Tagged rather than reported as a fast enqueue,
          // which would understate the real distribution.
          await stopTraceOnce(_outcomeReused);
          return result;
        }
      }

      final uploadUrl = '$serverUrl/upload';
      final authHeader = await _createBlossomAuthHeader(
        url: uploadUrl,
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
        contentDescription: 'Upload video to Blossom server',
        authTtl: _backgroundAuthTtl,
      );
      if (authHeader == null) {
        const result = BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
          failureReason: BlossomUploadFailureReason.authUnavailable,
        );
        await stopTraceOnce(_traceOutcome(result));
        return result;
      }

      final headers = <String, dynamic>{
        'Authorization': authHeader,
        'Content-Type': 'video/mp4',
        'Content-Length': fileSize.toString(),
      };
      if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
        _addProofModeHeaders(headers, proofManifestJson);
      }
      final stringHeaders = headers.map(
        (key, value) => MapEntry(key, value.toString()),
      );

      final completer = Completer<BlossomUploadResult>();
      final sub = transport.events
          .where((event) => event.taskId == taskId)
          .listen((event) {
            if (!event.isTerminal) {
              onProgress?.call((0.2 + event.progress * 0.7).clamp(0.2, 0.9));
              return;
            }
            if (completer.isCompleted) return;
            final result = _backgroundTransferResult(
              event,
              fileHash: fileHash,
              serverUrl: serverUrl,
            );
            if (result.success) onProgress?.call(1);
            completer.complete(result);
          });

      // Cancel the subscription no matter how the future resolves — terminal
      // event, enqueue failure, or the safety timeout below — so we never leak
      // a listener on the shared broadcast stream.
      try {
        BlossomUploadResult? enqueueFailure;
        try {
          await transport.enqueue(
            taskId: taskId,
            url: uploadUrl,
            method: 'PUT',
            headers: stringHeaders,
            filePath: videoFile.path,
          );
        } on Object catch (e) {
          enqueueFailure = BlossomUploadResult(
            success: false,
            errorMessage: 'Failed to enqueue background upload: $e',
            failureReason: _classifyUploadException(e),
          );
          if (!completer.isCompleted) {
            completer.complete(enqueueFailure);
          }
        }

        // Setup + enqueue are the only in-process work; stop the trace here so
        // it doesn't span the OS-owned transfer wait (which can include a long
        // app suspension and would otherwise pollute the perf metric).
        //
        // `success` therefore means the transfer reached the OS, not that it
        // finished — the OS leg is not measured by this trace at all.
        await stopTraceOnce(
          enqueueFailure == null
              ? _outcomeSuccess
              : _traceOutcome(enqueueFailure),
        );
        return await completer.future.timeout(
          timeout,
          onTimeout: () => BlossomUploadResult(
            success: false,
            errorMessage:
                'Background upload reported no terminal event within '
                '${timeout.inMinutes} minutes',
            isTransientNetworkFailure: true,
            failureReason: BlossomUploadFailureReason.network,
          ),
        );
      } finally {
        await sub.cancel();
      }
    } finally {
      // Only reached with the trace still running when the body threw before
      // the enqueue stop above; every deliberate exit tags its own outcome.
      await stopTraceOnce(_outcomeThrew);
    }
  }

  /// Stops an in-flight OS background upload previously enqueued via
  /// [uploadVideoInBackground] under [taskId].
  ///
  /// Without this the OS keeps streaming the file to completion even after the
  /// user cancels, wasting bandwidth on a video that will never be published.
  /// A no-op when no [backgroundTransport] is configured.
  Future<void> cancelBackgroundUpload(String taskId) async {
    await backgroundTransport?.cancel(taskId);
  }

  /// Uploads [videoFile], combining the OS-backed whole-file transfer with
  /// Divine resumable sessions so an interrupted publish never re-sends the
  /// whole file.
  ///
  /// Sequencing:
  /// - When [resumableSession] is `null` (a fresh publish), the OS-backed
  ///   [uploadVideoInBackground] whole-file `PUT` is attempted first. It
  ///   survives app suspension and is the fastest path on a healthy
  ///   connection. If it succeeds, we are done.
  /// - When that first attempt fails, *or* when [resumableSession] is already
  ///   present (a prior attempt created a session), the request falls through
  ///   to [uploadVideo], which runs the chunked resumable protocol:
  ///   `POST /upload/init` → `HEAD {uploadUrl}` to recover the server's last
  ///   committed `Upload-Offset` → upload only the remaining chunks →
  ///   `POST /upload/{id}/complete`. Each committed chunk is reported via
  ///   [onResumableSessionUpdated] so the caller can persist the offset; the
  ///   next retry therefore resumes from the last committed byte instead of
  ///   byte 0.
  ///
  /// [useBackgroundFirst] controls the OS-first attempt. Flip it to `false` to
  /// skip the whole-file PUT and go straight to chunked resumable (the kill-
  /// switch equivalent of the pre-combined `useBackgroundUpload` flag). When
  /// `false`, or when no [backgroundTransport] is configured, this behaves
  /// like [uploadVideo].
  ///
  /// [resumableTimeout] bounds only the in-process chunked-resumable leg (and
  /// only when this method reaches it). It is deliberately NOT applied to the
  /// OS-backed [uploadVideoInBackground] attempt, which legitimately survives
  /// long app suspensions under its own generous internal timeout; cutting it
  /// with an aggressive in-process timeout would defeat the suspension
  /// survival that is the whole point of the OS path.
  ///
  /// The OS uploader is whole-file-only on both platforms, so byte-level
  /// resume always happens through the in-process chunk path. The OS path is
  /// only ever used for the first whole-file attempt of a fresh publish.
  Future<BlossomUploadResult> uploadVideoWithResume({
    required File videoFile,
    required String nostrPubkey,
    required String taskId,
    required String title,
    required String? proofManifestJson,
    required String? description,
    required List<String>? hashtags,
    bool useBackgroundFirst = true,
    Duration? resumableTimeout,
    BlossomResumableUploadSession? resumableSession,
    void Function(BlossomResumableUploadSession)? onResumableSessionUpdated,
    void Function(double)? onProgress,
  }) async {
    // A prior attempt already created a session with committed chunks on the
    // server. Re-running the whole-file OS PUT would discard that progress,
    // so go straight to chunked resume via HEAD -> remaining chunks.
    final hasSession = resumableSession != null;

    if (useBackgroundFirst && !hasSession && backgroundTransport != null) {
      Log.info(
        'OS-first upload attempt for task $taskId '
        '(no resumable session yet)',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      try {
        final backgroundResult = await uploadVideoInBackground(
          videoFile: videoFile,
          taskId: taskId,
          proofManifestJson: proofManifestJson,
          onProgress: onProgress,
        );
        if (backgroundResult.success) {
          return backgroundResult;
        }
        // A user pause/cancel tears down the OS transfer, which surfaces as a
        // `cancelled` terminal event. That is a deliberate, terminal stop —
        // falling through to runResumable() would re-upload the whole file
        // from byte 0 and let a later success overwrite the paused/cancelled
        // state (#6086). Only genuine transport failures fall through.
        if (backgroundResult.failureReason ==
            BlossomUploadFailureReason.cancelled) {
          return backgroundResult;
        }
        Log.warning(
          'OS-first upload failed '
          '(${backgroundResult.failureReason}); '
          'falling back to chunked resumable',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
      } on Object catch (e) {
        // uploadVideoInBackground normally returns failures rather than
        // throwing, but guard against unexpected exceptions so the publish
        // still gets a resumable retry rather than dying.
        Log.warning(
          'OS-first upload threw ($e); '
          'falling back to chunked resumable',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
      }

      // The OS attempt failed (or threw) without being cancelled, so we are
      // about to run the in-process resumable leg. The native transfer may
      // still be live — e.g. the OS leg gave up on its own safety timeout
      // while the OS keeps streaming — so cancel it first; otherwise both
      // legs would upload the same file concurrently.
      await cancelBackgroundUpload(taskId);
    }

    // Resumable path (also the only path when the OS attempt is disabled or
    // unavailable). uploadVideo handles capability discovery, server
    // iteration, and the init/HEAD/chunk/complete flow, threading the session
    // callback through so each committed chunk is persisted by the caller.
    //
    // Only this in-process leg is bounded by resumableTimeout — the OS leg
    // above already completed (success or failure) under its own timeout.
    Future<BlossomUploadResult> runResumable() => uploadVideo(
      videoFile: videoFile,
      nostrPubkey: nostrPubkey,
      title: title,
      proofManifestJson: proofManifestJson,
      description: description,
      hashtags: hashtags,
      resumableSession: resumableSession,
      onResumableSessionUpdated: onResumableSessionUpdated,
      onProgress: onProgress,
    );

    if (resumableTimeout == null) {
      return runResumable();
    }
    return runResumable().timeout(resumableTimeout);
  }

  /// Maps a terminal [BlossomBackgroundTransferEvent] to a
  /// [BlossomUploadResult].
  ///
  /// On success it prefers the `url` / `fallbackUrl` the server returned in the
  /// response body (mirroring [_parseUploadResponse]); when the body carries
  /// none, it falls back to the content-addressed URL on [serverUrl] — the
  /// server the file was actually uploaded to, which is not necessarily the
  /// default server when a custom Blossom server is configured.
  BlossomUploadResult _backgroundTransferResult(
    BlossomBackgroundTransferEvent event, {
    required String fileHash,
    required String serverUrl,
  }) {
    switch (event.status) {
      case BlossomBackgroundTransferStatus.completed:
        final canonicalUrl = '$serverUrl/$fileHash';
        final body = event.responseBody;
        final decoded = body == null ? null : _tryDecodeJsonMap(body);
        String? responseUrl;
        String? responseFallbackUrl;
        String? thumbnailUrl;
        String? streamingMp4Url;
        String? streamingHlsUrl;
        String? streamingStatus;
        if (decoded != null) {
          responseUrl = decoded['url']?.toString();
          responseFallbackUrl = decoded['fallbackUrl']?.toString();
          thumbnailUrl =
              decoded['thumbnail']?.toString() ?? responseFallbackUrl;
          final streaming = decoded['streaming'];
          if (streaming is Map) {
            streamingMp4Url = streaming['mp4Url']?.toString();
            streamingHlsUrl = streaming['hlsUrl']?.toString();
            streamingStatus = streaming['status']?.toString();
            thumbnailUrl =
                streaming['thumbnailUrl']?.toString() ??
                streaming['thumbnail']?.toString() ??
                thumbnailUrl;
          }
        }
        return BlossomUploadResult(
          success: true,
          url: (responseUrl != null && responseUrl.isNotEmpty)
              ? responseUrl
              : canonicalUrl,
          fallbackUrl:
              (responseFallbackUrl != null && responseFallbackUrl.isNotEmpty)
              ? responseFallbackUrl
              : canonicalUrl,
          videoId: fileHash,
          thumbnailUrl: thumbnailUrl,
          streamingMp4Url: streamingMp4Url,
          streamingHlsUrl: streamingHlsUrl,
          streamingStatus: streamingStatus,
        );
      case BlossomBackgroundTransferStatus.cancelled:
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Upload cancelled',
          failureReason: BlossomUploadFailureReason.cancelled,
        );
      case BlossomBackgroundTransferStatus.running:
      case BlossomBackgroundTransferStatus.failed:
        final statusCode = event.httpStatusCode;
        // A 409 means the blob is already stored (BUD dedup convention);
        // mirror the in-process parse and treat it as success at the
        // content-addressed URL on the server the file was actually uploaded
        // to (not necessarily the default when a custom server is configured).
        if (statusCode == 409) {
          final existingUrl = '$serverUrl/$fileHash';
          return BlossomUploadResult(
            success: true,
            url: existingUrl,
            fallbackUrl: existingUrl,
            videoId: fileHash,
          );
        }
        return BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage:
              event.error ?? 'Upload failed: ${statusCode ?? 'no response'}',
          isTransientNetworkFailure: statusCode == null && event.error != null,
          failureReason:
              BlossomUploadFailureReason.fromStatusCode(statusCode) ??
              (event.error != null
                  ? BlossomUploadFailureReason.network
                  : BlossomUploadFailureReason.unknown),
        );
    }
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  /// Resume a previously interrupted resumable upload session.
  Future<BlossomResumableUploadSession> resumeUploadSession({
    required BlossomResumableUploadSession session,
  }) => _queryResumableUploadSession(session);

  /// Upload an image file (e.g. thumbnail) to the configured
  /// Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video
  /// uploads but with image MIME type.
  ///
  /// Native callers should prefer this entry point because
  /// [ImageMetadataStripper.stripMetadataInPlace] dispatches to a
  /// hardware-accelerated platform stripper. The web image path cannot use
  /// `dart:io` `File` against an `image_picker` blob URL — it should call
  /// [uploadImageBytes] instead, which strips via the pure-Dart bytes API.
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
    int maxAttempts = _defaultUploadImageMaxAttempts,
    bool allowResumable = true,
  }) async {
    assert(maxAttempts >= 1, 'maxAttempts must be at least 1');
    try {
      // Check authentication
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
          failureReason: BlossomUploadFailureReason.auth,
        );
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Strip EXIF metadata (GPS, device info) before uploading.
      // The stripper may rename the file (e.g. .avif -> .jpg)
      // so use the returned reference for all subsequent ops.
      final strippedFile = await ImageMetadataStripper.stripMetadataInPlace(
        imageFile,
      );

      // Calculate file hash for Blossom.
      // For images we load into memory for the hash
      // (small files).
      final fileBytes = await strippedFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info(
        'Image file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      return await _uploadImageSourceToServers(
        source: _FileUploadSource(strippedFile),
        fileHash: fileHash,
        fileSize: fileSize,
        contentType: mimeType,
        maxAttempts: maxAttempts,
        allowResumable: allowResumable,
        onProgress: onProgress,
      );
    } on Object catch (e) {
      Log.error(
        'Image upload exception: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  /// Upload raw image bytes to the configured Blossom server.
  ///
  /// Designed for the web upload path, where [ImageMetadataStripper]'s
  /// platform-channel based stripping cannot run and `dart:io` `File`
  /// constructed from an `image_picker` blob URL throws on the first I/O
  /// call. EXIF stripping happens in pure Dart via
  /// [ImageMetadataStripper.stripMetadataBytes].
  ///
  /// Native callers that already hold a real filesystem `File` should
  /// prefer [uploadImage] so they get the hardware-accelerated platform
  /// stripper.
  ///
  /// [filename] is used to pick the EXIF strategy (JPEG-direct vs PNG
  /// re-encode vs generic decode→JPEG) and is sent to the resumable
  /// init endpoint. Defaults to `upload.jpg` for unnamed payloads.
  Future<BlossomUploadResult> uploadImageBytes({
    required Uint8List bytes,
    required String nostrPubkey,
    String? filename,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
    int maxAttempts = _defaultUploadImageMaxAttempts,
  }) async {
    assert(maxAttempts >= 1, 'maxAttempts must be at least 1');
    try {
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
          failureReason: BlossomUploadFailureReason.auth,
        );
      }

      onProgress?.call(0.1);

      final stripped = ImageMetadataStripper.stripMetadataBytes(
        bytes: bytes,
        filename: filename ?? 'upload.jpg',
      );
      final processedBytes = stripped.bytes;
      final processedFilename = stripped.filename;

      final fileHash = HashUtil.sha256Hash(processedBytes);
      final fileSize = processedBytes.length;

      Log.info(
        'Image bytes hash: $fileHash, size: $fileSize bytes, '
        'filename: $processedFilename',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      return await _uploadImageSourceToServers(
        source: _BytesUploadSource(
          bytes: processedBytes,
          filename: processedFilename,
        ),
        fileHash: fileHash,
        fileSize: fileSize,
        contentType: mimeType,
        maxAttempts: maxAttempts,
        onProgress: onProgress,
      );
    } on Object catch (e) {
      Log.error(
        'Image upload exception: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  Future<BlossomUploadResult> _uploadImageSourceToServers({
    required _UploadSource source,
    required String fileHash,
    required int fileSize,
    required String contentType,
    required int maxAttempts,
    bool allowResumable = true,
    void Function(double)? onProgress,
  }) async {
    // Get ordered list of servers to try
    final serverUrls = await _getServerUrlsForUpload();

    Log.info(
      'Trying ${serverUrls.length} Blossom servers for image upload',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    BlossomUploadResult? lastError;

    // Try each server in order until one succeeds
    for (final serverUrl in serverUrls) {
      try {
        Log.info(
          'Attempting image upload to: $serverUrl',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );

        // The capability probe only feeds supportsResumable, so a caller that
        // already opted out of resumable cannot be routed by the answer — the
        // HEAD would be a provably inert round-trip (and always a cold one on
        // the publish path: the OS-first video upload never warms this cache).
        // Skipped because it is inert, not because it was measured as the
        // cost; on-device timing showed the thumbnail PUT dominates with or
        // without it.
        final capability = allowResumable
            ? await _fetchDivineUploadCapability(serverUrl)
            : null;

        final result = await _uploadWithRetry(
          attempt: () {
            if (capability != null && capability.supportsResumable) {
              return _uploadWithSingleLegacyFallback(
                serverUrl: serverUrl,
                uploadResumable: () => _uploadToServerResumable(
                  serverUrl: serverUrl,
                  source: source,
                  fileHash: fileHash,
                  fileSize: fileSize,
                  contentType: contentType,
                  onProgress: onProgress,
                ),
                uploadLegacyFallback: (fallbackReason) =>
                    _uploadToServerLegacyFallback(
                      serverUrl: serverUrl,
                      source: source,
                      fileHash: fileHash,
                      fileSize: fileSize,
                      contentType: contentType,
                      fallbackReason: fallbackReason,
                      onProgress: onProgress,
                    ),
              );
            }
            return _uploadToServer(
              serverUrl: serverUrl,
              source: source,
              fileHash: fileHash,
              fileSize: fileSize,
              contentType: contentType,
              onProgress: onProgress,
            );
          },
          maxAttempts: maxAttempts,
          debugContext: 'uploadImage($serverUrl)',
        );

        if (result.success) {
          // Construct canonical Blossom URL from server + hash
          final canonicalUrl = '$_defaultServerUrl/$fileHash';

          Log.info(
            'Image uploaded to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          Log.info(
            '  Canonical URL: $canonicalUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          return BlossomUploadResult(
            success: true,
            url: canonicalUrl,
            fallbackUrl: canonicalUrl,
            videoId: fileHash,
          );
        }

        lastError = result;
        Log.warning(
          'Upload to $serverUrl failed: '
          '${result.errorMessage}, '
          'trying next server...',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        // coverage:ignore-start
      } on Object catch (e) {
        final statusCode = e is DioException ? e.response?.statusCode : null;
        lastError = BlossomUploadResult(
          success: false,
          statusCode: statusCode,
          errorMessage: 'Upload to $serverUrl failed: $e',
          failureReason: _classifyUploadException(e),
        );
        Log.warning(
          'Upload to $serverUrl failed: $e, '
          'trying next server...',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        continue;
        // coverage:ignore-end
      }
    }

    // All servers failed
    Log.error(
      'All ${serverUrls.length} servers failed '
      'for image upload',
      name: 'BlossomUploadService',
      category: LogCategory.video,
    );

    return lastError ??
        const BlossomUploadResult(
          success: false,
          errorMessage: 'All servers failed',
          failureReason: BlossomUploadFailureReason.unknown,
        );
  }

  /// Add ProofMode headers to upload request.
  ///
  /// Generates X-ProofMode-Manifest, X-ProofMode-Signature,
  /// X-ProofMode-PublicKey, X-ProofMode-Attestation and X-ProofMode-C2PA
  /// headers from the provided ProofManifest JSON.
  ///
  /// Headers are attached best-effort within [maxProofModeHeaderBytes]. Large
  /// Android attestations can exceed that budget, so bulk proof fields are
  /// omitted while canonical proof metadata stays in the video event.
  void _addProofModeHeaders(
    Map<String, dynamic> headers,
    String proofManifestJson,
  ) {
    try {
      final manifestMap = jsonDecode(proofManifestJson) as Map<String, dynamic>;

      // Ordered cheapest-and-most-identifying first, so a proof that busts the
      // budget still carries the C2PA id and a verifiable signature/key pair.
      final candidates = <String, String>{
        if (manifestMap['c2paManifestId'] ?? manifestMap['c2pa_manifest_id']
            case final c2paManifestId?)
          'X-ProofMode-C2PA': _encodeHeaderValue(c2paManifestId),
        if (manifestMap['pgpSignature'] case final pgpSignature?)
          'X-ProofMode-Signature': _encodeHeaderValue(pgpSignature),
        // Paired with the signature: without the key the signature cannot be
        // verified from headers alone.
        if (manifestMap['publicKey'] case final publicKey?)
          'X-ProofMode-PublicKey': _encodeHeaderValue(publicKey),
        if (manifestMap['deviceAttestation'] case final deviceAttestation?)
          'X-ProofMode-Attestation': _encodeHeaderValue(deviceAttestation),
        'X-ProofMode-Manifest': base64.encode(utf8.encode(proofManifestJson)),
      };

      var usedBytes = 0;
      final dropped = <String>[];
      for (final candidate in candidates.entries) {
        // `name: value\r\n` is what actually counts against a proxy's budget.
        final wireBytes = candidate.key.length + candidate.value.length + 4;
        if (usedBytes + wireBytes > maxProofModeHeaderBytes) {
          dropped.add('${candidate.key} (${candidate.value.length}B)');
          continue;
        }
        usedBytes += wireBytes;
        headers[candidate.key] = candidate.value;
      }

      if (dropped.isEmpty) {
        Log.info(
          'Added ProofMode headers to upload ($usedBytes bytes)',
          name: 'BlossomUploadService',
          category: LogCategory.video,
        );
        return;
      }

      Log.info(
        'ProofMode headers trimmed to the $maxProofModeHeaderBytes byte '
        'budget; sent $usedBytes bytes and omitted ${dropped.join(', ')}. '
        'The full manifest is canonical in the video event proofmode tag.',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to add ProofMode headers: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      // Don't fail the upload if ProofMode headers can't be added
    }
  }

  /// Base64-encodes a manifest field value for use as an HTTP header.
  ///
  /// Handles both [String] and [Map] values. Maps are JSON-encoded first.
  String _encodeHeaderValue(dynamic value) {
    final stringValue = value is String ? value : jsonEncode(value);
    return base64.encode(utf8.encode(stringValue));
  }

  /// Upload an audio file to the configured Blossom server.
  ///
  /// Tries multiple Blossom servers in priority order with
  /// fallback. Returns success if any server succeeds, failure
  /// only if all servers fail.
  ///
  /// This uses the same Blossom BUD-01 protocol as video/image
  /// uploads but with audio MIME type. Used by the audio reuse
  /// feature when publishing videos with allowAudioReuse
  /// enabled.
  ///
  /// Returns a [BlossomUploadResult] with the audio file URL
  /// on success.
  Future<BlossomUploadResult> uploadAudio({
    required File audioFile,
    String mimeType = 'audio/aac',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check authentication
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
          failureReason: BlossomUploadFailureReason.auth,
        );
      }

      // Report initial progress
      onProgress?.call(0.1);

      // Use streaming hash computation for memory efficiency
      final hashResult = await HashUtil.sha256File(audioFile);
      final fileHash = hashResult.hash;
      final fileSize = hashResult.size;

      Log.info(
        'Audio file hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      onProgress?.call(0.2);

      // Get ordered list of servers to try
      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers for audio upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      // Try each server in order until one succeeds
      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting audio upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            source: _FileUploadSource(audioFile),
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: mimeType,
            onProgress: onProgress,
          );

          if (result.success) {
            // Construct canonical Blossom URL from server + hash
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              'Audio uploaded to: $serverUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );
            Log.info(
              '  Canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
            );
          }

          lastError = result;
          Log.warning(
            'Upload to $serverUrl failed: '
            '${result.errorMessage}, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          // coverage:ignore-start
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
            failureReason: _classifyUploadException(e),
          );
          Log.warning(
            'Upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
          // coverage:ignore-end
        }
      }

      // All servers failed
      Log.error(
        'All ${serverUrls.length} servers failed '
        'for audio upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
            failureReason: BlossomUploadFailureReason.unknown,
          );
    } on Object catch (e) {
      Log.error(
        'Audio upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Audio upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  /// Uploads a subtitle VTT blob (BUD-01) and returns its sha256 and
  /// canonical URL. MIME defaults to `text/vtt`; Blossom is
  /// content-addressed so the stored Content-Type does not affect the
  /// address.
  Future<BlossomUploadResult> uploadSubtitleVtt({
    required Uint8List bytes,
    String mimeType = 'text/vtt',
    void Function(double)? onProgress,
  }) async {
    try {
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
          failureReason: BlossomUploadFailureReason.auth,
        );
      }

      onProgress?.call(0.1);

      final fileHash = HashUtil.sha256Hash(bytes);
      final fileSize = bytes.length;

      Log.info(
        'Subtitle VTT hash: $fileHash, size: $fileSize bytes',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      final serverUrls = await _getServerUrlsForUpload();

      Log.info(
        'Trying ${serverUrls.length} Blossom servers for subtitle upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      BlossomUploadResult? lastError;

      for (final serverUrl in serverUrls) {
        try {
          Log.info(
            'Attempting subtitle upload to: $serverUrl',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );

          final result = await _uploadToServer(
            serverUrl: serverUrl,
            source: _BytesUploadSource(bytes: bytes, filename: 'subtitles.vtt'),
            fileHash: fileHash,
            fileSize: fileSize,
            contentType: mimeType,
            onProgress: onProgress,
          );

          if (result.success) {
            final canonicalUrl = '$_defaultServerUrl/$fileHash';

            Log.info(
              'Subtitle uploaded to: $serverUrl, '
              'canonical URL: $canonicalUrl',
              name: 'BlossomUploadService',
              category: LogCategory.video,
            );

            return BlossomUploadResult(
              success: true,
              url: canonicalUrl,
              fallbackUrl: canonicalUrl,
              videoId: fileHash,
            );
          }

          lastError = result;
          Log.warning(
            'Subtitle upload to $serverUrl failed: '
            '${result.errorMessage}, trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          // coverage:ignore-start
        } on Object catch (e) {
          final statusCode = e is DioException ? e.response?.statusCode : null;
          lastError = BlossomUploadResult(
            success: false,
            statusCode: statusCode,
            errorMessage: 'Upload to $serverUrl failed: $e',
            failureReason: _classifyUploadException(e),
          );
          Log.warning(
            'Subtitle upload to $serverUrl failed: $e, '
            'trying next server...',
            name: 'BlossomUploadService',
            category: LogCategory.video,
          );
          continue;
          // coverage:ignore-end
        }
      }

      Log.error(
        'All ${serverUrls.length} servers failed for subtitle upload',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
            failureReason: BlossomUploadFailureReason.unknown,
          );
    } on Object catch (e) {
      Log.error(
        'Subtitle VTT upload error: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Subtitle VTT upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  /// Uploads pre-encrypted ciphertext to the Blossom server as an opaque
  /// `application/octet-stream` payload.
  ///
  /// Unlike [uploadVideo], the bytes are never transcoded or moderated: the
  /// server stores exactly the ciphertext it receives. The BUD-01 auth event
  /// still carries `t=upload` and `x=<sha256 of the ciphertext>`, and the
  /// returned [BlossomUploadResult.videoId] is that same ciphertext hash with
  /// [BlossomUploadResult.url] `'<serverUrl>/<hash>'`.
  Future<BlossomUploadResult> uploadEncryptedFile({
    required File ciphertextFile,
    void Function(double)? onProgress,
  }) async {
    try {
      if (!authProvider.isAuthenticated) {
        return const BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
          failureReason: BlossomUploadFailureReason.auth,
        );
      }

      onProgress?.call(0.1);

      final hashAndSize = await HashUtil.sha256File(ciphertextFile);
      final fileHash = hashAndSize.hash;
      final fileSize = hashAndSize.size;

      final serverUrls = await _getServerUrlsForUpload();
      BlossomUploadResult? lastError;

      for (final serverUrl in serverUrls) {
        final result = await _uploadToServer(
          serverUrl: serverUrl,
          source: _FileUploadSource(ciphertextFile),
          fileHash: fileHash,
          fileSize: fileSize,
          contentType: 'application/octet-stream',
          contentDescription: 'Upload encrypted file to Blossom server',
          onProgress: onProgress,
        );

        if (result.success) {
          final canonicalUrl = '$_defaultServerUrl/$fileHash';
          return BlossomUploadResult(
            success: true,
            url: canonicalUrl,
            fallbackUrl: canonicalUrl,
            videoId: fileHash,
          );
        }

        lastError = result;
      }

      return lastError ??
          const BlossomUploadResult(
            success: false,
            errorMessage: 'All servers failed',
            failureReason: BlossomUploadFailureReason.unknown,
          );
    } on Object catch (e) {
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Encrypted file upload failed: $e',
        failureReason: _classifyUploadException(e),
      );
    }
  }

  /// Transcribes [bytes] (a WAV/audio clip) server-side, returning the raw
  /// WebVTT, or `null` on any failure (not authenticated, network error,
  /// non-200 response).
  ///
  /// Posts to the Divine edge's `/transcribe` with a Blossom `t=media` auth
  /// event; the edge forwards to the upload service, which calls the
  /// transcoder. Always targets [_defaultServerUrl] (a custom Blossom server
  /// would not expose this Divine-specific endpoint). Callers should fall back
  /// to on-device transcription when this returns `null`.
  Future<String?> transcribeAudio({
    required Uint8List bytes,
    String? language,
    Duration authTtl = _defaultAuthTtl,
  }) async {
    if (!authProvider.isAuthenticated) return null;

    final expirationTimestamp =
        DateTime.now().add(authTtl).millisecondsSinceEpoch ~/ 1000;
    final signedEvent = await authProvider.createAndSignEvent(
      kind: 24242,
      content: 'Transcribe audio',
      tags: [
        ['t', 'media'],
        ['expiration', expirationTimestamp.toString()],
      ],
    );
    if (signedEvent == null) return null;

    final trimmedLang = language?.trim();
    try {
      final response = await dio.post<String>(
        '$_defaultServerUrl/transcribe',
        data: bytes,
        queryParameters: {
          if (trimmedLang != null && trimmedLang.isNotEmpty)
            'language': trimmedLang,
        },
        options: Options(
          headers: {
            'Authorization': _buildAuthHeader(signedEvent),
            'Content-Type': 'audio/wav',
          },
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode == 200) return response.data;
      Log.warning(
        'Transcribe returned ${response.statusCode}',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    } on Object catch (e) {
      Log.warning(
        'Transcribe request failed: $e',
        name: 'BlossomUploadService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Test connection to a Blossom server
  ///
  /// Returns a [BlossomHealthCheckResult] with status, latency, and any errors.
  /// This does a simple HEAD request to check if the server is reachable.
  Future<BlossomHealthCheckResult> testServerConnection([
    String? serverUrl,
  ]) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Use provided URL or get configured server
      final targetUrl = serverUrl ?? await getBlossomServer();
      if (targetUrl == null || targetUrl.isEmpty) {
        return const BlossomHealthCheckResult(
          isReachable: false,
          errorMessage: 'No Blossom server configured',
        );
      }

      Log.info(
        'Testing Blossom server connectivity: $targetUrl',
        name: 'BlossomUploadService',
        category: LogCategory.system,
      );

      // Try HEAD request first (lightweight), fall back to GET if HEAD fails
      try {
        final response = await dio.head<dynamic>(
          targetUrl,
          options: Options(
            validateStatus: // coverage:ignore-start
            (status) =>
                status != null && status < 500,
            // coverage:ignore-end
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        stopwatch.stop();

        final isReachable =
            response.statusCode != null && response.statusCode! < 500;
        return BlossomHealthCheckResult(
          isReachable: isReachable,
          latencyMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          serverUrl: targetUrl,
        );
      } on DioException catch (e) {
        // If HEAD is not supported, try GET
        if (e.response?.statusCode == 405) {
          final response = await dio.get<dynamic>(
            targetUrl,
            options: Options(
              validateStatus: // coverage:ignore-start
              (status) =>
                  status != null && status < 500,
              // coverage:ignore-end
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          stopwatch.stop();

          final isReachable =
              response.statusCode != null && response.statusCode! < 500;
          return BlossomHealthCheckResult(
            isReachable: isReachable,
            latencyMs: stopwatch.elapsedMilliseconds,
            statusCode: response.statusCode,
            serverUrl: targetUrl,
          );
        }
        rethrow;
      }
    } on DioException catch (e) {
      stopwatch.stop();

      String errorMessage;
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect: ${e.message}';
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      return BlossomHealthCheckResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: errorMessage,
        statusCode: e.response?.statusCode,
      );
    } on Object catch (e) {
      stopwatch.stop();
      return BlossomHealthCheckResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }
}
