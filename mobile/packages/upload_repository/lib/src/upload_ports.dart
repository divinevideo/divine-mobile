// ABOUTME: Ports decoupling upload orchestration from app and platform APIs.
// ABOUTME: The app supplies storage, diagnostics, media, and telemetry adapters.

import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import 'package:upload_repository/src/pending_upload.dart';

/// Opens the app-owned Hive box used to persist uploads.
typedef PendingUploadBoxOpener =
    Future<Box<PendingUpload>> Function({bool forceReinit});

/// Network classes needed for upload diagnostics and user-facing errors.
enum UploadConnectivity { wifi, mobile, ethernet, vpn, none, other }

/// Returns the current network class without coupling to a platform plugin.
typedef UploadConnectivityProvider = Future<UploadConnectivity> Function();

/// Result of extracting a thumbnail into a local file.
typedef ThumbnailExtraction = ({String path});

/// Extracts a thumbnail without exposing the app's thumbnail service type.
typedef ThumbnailExtractor =
    Future<ThumbnailExtraction?> Function({
      required String videoPath,
      required Duration targetTimestamp,
      required int quality,
    });

/// Generates a blurhash without coupling the repository to Flutter services.
typedef UploadBlurhashGenerator = Future<String?> Function(Uint8List bytes);

/// Records one phase of the app's publish timeline.
typedef UploadTelemetry =
    void Function(String phase, Duration elapsed, {int? bytes, String? detail});

/// Crash/diagnostics reporting port for the upload pipeline.
///
/// Lets the extracted upload concerns (e.g. `UploadProgressReporter`) record
/// diagnostics without importing the Firebase-backed `CrashReportingService`,
/// so they can move into a pure-Dart package. The app layer supplies an
/// adapter that forwards to `CrashReportingService.instance`.
abstract interface class UploadCrashReporter {
  /// Attach a custom key/value to subsequent crash reports.
  Future<void> setCustomKey(String key, Object value);

  /// Log a breadcrumb message to the crash reporter.
  void log(String message);

  /// Record a non-fatal error with an optional [reason].
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
}

/// Cleanup policy for transient video-editor renders an upload consumed.
///
/// The upload pipeline knows *which* paths belong to *which* upload and when
/// they are safe to reap; it does not know how a stop-motion render is
/// recognised or deleted. The app layer supplies an adapter over
/// `StopMotionRenderService` so the pipeline can move into a pure-Dart package.
abstract interface class TransientRenderCleaner {
  /// Whether [filePath] is a materialized editor render safe to delete.
  bool isMaterializedOutputPath(String filePath);

  /// Deletes the materialized render at [filePath], if it is still present.
  Future<void> cleanupMaterializedOutputPath(String filePath);
}
