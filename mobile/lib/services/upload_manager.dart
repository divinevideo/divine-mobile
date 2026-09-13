// ABOUTME: App-layer facade for the upload repository, which takes no direct
// ABOUTME: Flutter dependency. Owns plugin adapters and background lifecycle.

import 'dart:async';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:upload_repository/upload_repository.dart'
    hide ThumbnailExtractor;
import 'package:upload_repository/upload_repository.dart'
    as upload_core
    show ThumbnailExtractor;

export 'package:upload_repository/upload_repository.dart'
    hide ThumbnailExtractor;

typedef ThumbnailExtractor = Future<ThumbnailFileResult?> Function({
  required String videoPath,
  required Duration targetTimestamp,
  required int quality,
});

class CrashReportingUploadReporter implements UploadCrashReporter {
  const CrashReportingUploadReporter(this._reporter);

  final CrashReporter _reporter;

  @override
  Future<void> setCustomKey(String key, Object value) =>
      _reporter.setCustomKey(key, value);

  @override
  void log(String message) => _reporter.log(message);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {String? reason}) =>
      _reporter.recordError(error, stack, reason: reason);
}

class StopMotionTransientRenderCleaner implements TransientRenderCleaner {
  const StopMotionTransientRenderCleaner();

  @override
  bool isMaterializedOutputPath(String filePath) =>
      StopMotionRenderService.isMaterializedOutputPath(filePath);

  @override
  Future<void> cleanupMaterializedOutputPath(String filePath) =>
      StopMotionRenderService.cleanupMaterializedOutputPath(filePath);
}

class UploadManager extends UploadRepository implements BackgroundAwareService {
  UploadManager({
    required super.blossomService,
    required BackgroundActivityManager backgroundActivityManager,
    super.defaultBlossomUrl,
    super.currentNostrPubkey,
    super.scopeUploadsToCurrentUser = false,
    super.circuitBreaker,
    super.retryConfig,
    UploadCrashReporter? crashReporter,
    CrashReporter crashReporting = const SilentCrashReporter(),
    super.useBackgroundUpload = false,
    ThumbnailExtractor? thumbnailExtractor,
    TransientRenderCleaner? transientRenderCleaner,
  }) : _backgroundActivityManager = backgroundActivityManager,
       _crashReporting = crashReporting,
       super(
         openPendingUploadsBox: UploadInitializationHelper.initializeUploadsBox,
         crashReporter:
             crashReporter ?? CrashReportingUploadReporter(crashReporting),
         thumbnailExtractor: _adaptThumbnailExtractor(
           thumbnailExtractor ?? VideoThumbnailService.extractThumbnail,
         ),
         blurhashGenerator: _generateBlurhash,
         transientRenderCleaner:
             transientRenderCleaner ?? const StopMotionTransientRenderCleaner(),
         connectivityProvider: _checkConnectivity,
         debugStateProvider: UploadInitializationHelper.getDebugState,
         platformName: _platformName,
         isWeb: kIsWeb,
         defaultThumbnailTimestamp:
             VideoEditorConstants.defaultThumbnailExtractTime,
         telemetry: logPublishPhase,
       );

  final BackgroundActivityManager _backgroundActivityManager;
  final CrashReporter _crashReporting;
  bool _isBackgroundRegistered = false;

  @visibleForTesting
  CrashReporter get crashReporterForTesting => _crashReporting;

  static String get _platformName {
    if (kIsWeb) return 'web';
    try {
      return defaultTargetPlatform.name;
    } catch (_) {
      return 'unknown';
    }
  }

  static upload_core.ThumbnailExtractor _adaptThumbnailExtractor(
    ThumbnailExtractor extractor,
  ) =>
      ({
        required String videoPath,
        required Duration targetTimestamp,
        required int quality,
      }) async {
        final result = await extractor(
          videoPath: videoPath,
          targetTimestamp: targetTimestamp,
          quality: quality,
        );
        return result == null ? null : (path: result.path);
      };

  static Future<String?> _generateBlurhash(Uint8List bytes) =>
      BlurhashService.generateBlurhash(bytes);

  static Future<UploadConnectivity> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.wifi)) {
      return UploadConnectivity.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return UploadConnectivity.mobile;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return UploadConnectivity.ethernet;
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return UploadConnectivity.vpn;
    }
    return UploadConnectivity.none;
  }

  static UploadConnectivity _mapConnectivity(ConnectivityResult connectivity) {
    return switch (connectivity) {
      ConnectivityResult.wifi => UploadConnectivity.wifi,
      ConnectivityResult.mobile => UploadConnectivity.mobile,
      ConnectivityResult.ethernet => UploadConnectivity.ethernet,
      ConnectivityResult.vpn => UploadConnectivity.vpn,
      ConnectivityResult.none => UploadConnectivity.none,
      _ => UploadConnectivity.none,
    };
  }

  @visibleForTesting
  String getUserFriendlyErrorMessage(
    String category,
    ConnectivityResult connectivity,
  ) => UploadProgressReporter.userFriendlyErrorMessage(
    category,
    _mapConnectivity(connectivity),
  );

  @override
  void onStorageReady() {
    if (!_isBackgroundRegistered) {
      _backgroundActivityManager.registerService(this);
      _isBackgroundRegistered = true;
    }
  }

  @override
  String get serviceName => 'UploadManager';

  @override
  void onAppBackgrounded() {
    // No-op: the OS owns an in-flight background transfer, and there is no
    // Dart-side work to pause. The recovery sweep runs on [onAppResumed].
  }

  @override
  void onExtendedBackground() {
    // No-op: same rationale as [onAppBackgrounded].
  }

  @override
  void onAppResumed() => unawaited(recoverInterruptedUploads());

  @override
  void dispose() {
    if (_isBackgroundRegistered) {
      _backgroundActivityManager.unregisterService(this);
      _isBackgroundRegistered = false;
    }
    super.dispose();
  }
}
