import 'dart:io';

import 'package:models/models.dart';
import 'package:openvine/services/thumbnail_api_service.dart';

extension VideoEventHelper on VideoEvent {
  /// Check if video format is supported on current platform
  /// WebM is not supported on iOS/macOS (AVPlayer limitation)
  bool get isSupportedOnCurrentPlatform {
    // WebM only works on Android and Web, not iOS/macOS
    if (isWebM) {
      return !Platform.isIOS && !Platform.isMacOS;
    }
    // All other formats (MP4, MOV, M4V, HLS) work on all platforms
    return true;
  }

  /// This method provides an async fallback that generates thumbnails when missing
  Future<String?> getApiThumbnailUrl({
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) async {
    // First check if we already have a thumbnail URL
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }

    // Use the new thumbnail API service for automatic generation
    return ThumbnailApiService.getThumbnailWithFallback(
      id,
      timeSeconds: timeSeconds,
      size: size,
    );
  }
}
