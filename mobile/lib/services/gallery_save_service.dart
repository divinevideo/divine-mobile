// ABOUTME: Service for saving videos to the device's camera roll/gallery
// ABOUTME: Uses the gal package for cross-platform gallery access

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of a gallery save operation.
sealed class GallerySaveResult {
  const GallerySaveResult();
}

/// Video was successfully saved to the gallery.
class GallerySaveSuccess extends GallerySaveResult {
  const GallerySaveSuccess();
}

/// Video save failed due to an error.
class GallerySaveFailure extends GallerySaveResult {
  const GallerySaveFailure(this.reason);
  final String reason;
}

/// Gallery permission was denied — UI should offer to open Settings.
class GallerySavePermissionDenied extends GallerySaveResult {
  const GallerySavePermissionDenied();
}

/// Service for saving videos to the device's camera roll/gallery.
///
/// This service provides a simple interface for saving videos as a backup
/// when publishing. It handles permission requests internally via the gal
/// package and never throws exceptions - instead returning a result object.
class GallerySaveService {
  /// Creates a [GallerySaveService] with the given [permissionsService].
  const GallerySaveService({required PermissionsService permissionsService})
    : _permissionsService = permissionsService;

  final PermissionsService _permissionsService;

  /// Platform-aware name for the save destination.
  ///
  /// Returns "Camera Roll" on iOS and "Gallery" on Android.
  static String get destinationName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'Camera Roll' : 'Gallery';

  /// Saves a video file to the device's camera roll/gallery.
  ///
  /// This method:
  /// - Crops the video to [aspectRatio] if provided and resolution differs
  /// - Handles permission requests automatically
  /// - Never throws exceptions
  /// - Returns a [GallerySaveResult] indicating success or failure
  ///
  /// The [video] is the video to save.
  /// The optional [aspectRatio] crops the video before saving if needed.
  /// The optional [albumName] specifies the album to save to.
  Future<GallerySaveResult> saveVideoToGallery(
    EditorVideo video, {
    model.AspectRatio? aspectRatio,
    String albumName = 'Divine',
    VideoMetadata? metadata,
  }) async {
    Log.info(
      'saveVideoToGallery started: aspectRatio=$aspectRatio album=$albumName',
      name: 'GallerySaveService',
      category: LogCategory.video,
    );
    // Declare filePath outside try so catch blocks can access it.
    String? resolvedPath;

    try {
      // Crop to aspect ratio if specified
      if (aspectRatio != null) {
        resolvedPath = await VideoEditorRenderService.cropToAspectRatio(
          video: video,
          aspectRatio: aspectRatio,
          metadata: metadata,
        );
      } else {
        resolvedPath = await video.safeFilePath();
      }

      // Verify the file exists
      final file = File(resolvedPath);
      if (!file.existsSync()) {
        Log.warning(
          'Cannot save to gallery: file does not exist at $resolvedPath',
          name: 'GallerySaveService',
          category: LogCategory.video,
        );
        return const GallerySaveFailure('File does not exist');
      }

      // Check gallery permission.
      // On desktop, permission_handler may not be available —
      // fall back to Gal's own permission request or Downloads.
      final permResult = await _checkPermission();
      if (permResult != null) {
        // Permission denied — on desktop, save to Downloads instead.
        if (_isDesktop) {
          return await _saveToDownloads(resolvedPath);
        }
        return permResult;
      }

      // Save the video to the gallery with a timeout to prevent hanging on
      // emulators or when the MediaStore is unresponsive.
      // On iOS, don't use album parameter - it requires full photo library access
      // With album, iOS shows a second permission dialog for full access
      // Without album, it only needs photosAddOnly permission
      Log.info(
        'saveVideoToGallery calling Gal.putVideo: '
        'path=$resolvedPath size=${file.lengthSync()} '
        'platform=$defaultTargetPlatform',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      final galFuture = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          ? Gal.putVideo(resolvedPath)
          : Gal.putVideo(resolvedPath, album: albumName);

      await galFuture.timeout(const Duration(seconds: 15));

      Log.info(
        'Video saved to camera roll successfully',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      return const GallerySaveSuccess();
    } on TimeoutException {
      Log.warning(
        'Gallery save timed out after 15s',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return const GallerySaveFailure('Gallery save timed out');
    } on GalException catch (e) {
      Log.warning(
        'Failed to save video to gallery: ${e.type.name}',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      // On desktop, fall back to saving to Downloads folder
      if (_isDesktop && resolvedPath != null) {
        return _saveToDownloads(resolvedPath);
      }

      return GallerySaveFailure('Gallery error: ${e.type.name}');
    } catch (e) {
      Log.warning(
        'Unexpected error saving video to gallery: $e',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      // On desktop, fall back to saving to Downloads folder
      if (_isDesktop && resolvedPath != null) {
        return _saveToDownloads(resolvedPath);
      }

      return GallerySaveFailure('Unexpected error: $e');
    }
  }

  /// Checks permission and returns null if granted,
  /// or a failure result if denied.
  Future<GallerySaveResult?> _checkPermission() async {
    try {
      final status = await _permissionsService.checkGalleryStatus();
      if (status == PermissionStatus.granted) return null;

      // Not granted yet — try requesting
      if (status == PermissionStatus.canRequest) {
        final requested = await _permissionsService.requestGalleryPermission();
        if (requested == PermissionStatus.granted) return null;

        // Some platforms can briefly report a stale non-granted request result
        // immediately after the user accepts the OS prompt.
        final refreshedStatus = await _permissionsService.checkGalleryStatus();
        if (refreshedStatus == PermissionStatus.granted) return null;
      }

      // Permanently denied or still not granted
      Log.warning(
        'Gallery permission not granted (status: $status)',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return const GallerySavePermissionDenied();
    } on MissingPluginException {
      // Desktop: permission_handler not available.
      // Use Gal's native permission request (triggers macOS TCC prompt).
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (hasAccess) return null;

      final granted = await Gal.requestAccess(toAlbum: true);
      if (granted) return null;

      Log.warning(
        'Gallery access denied via Gal on this platform',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return const GallerySavePermissionDenied();
    }
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Falls back to copying the video to the user's Downloads folder.
  Future<GallerySaveResult> _saveToDownloads(String filePath) async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null || !downloadsDir.existsSync()) {
        return const GallerySaveFailure('Downloads folder not found');
      }

      final fileName = 'Divine_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final destPath = p.join(downloadsDir.path, fileName);
      await File(filePath).copy(destPath);

      Log.info(
        'Video saved to Downloads: $destPath',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );

      return const GallerySaveSuccess();
    } catch (e) {
      Log.warning(
        'Failed to save to Downloads: $e',
        name: 'GallerySaveService',
        category: LogCategory.video,
      );
      return GallerySaveFailure('Could not save to Downloads: $e');
    }
  }
}
