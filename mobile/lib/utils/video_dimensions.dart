// ABOUTME: Helper functions for video dimension calculations
// ABOUTME: Converts aspect ratios to Nostr NIP-71 dimension tags

import 'package:models/models.dart' show AspectRatio;

/// Get dimension tag for Nostr event based on aspect ratio
///
/// Returns dimension string in format "widthxheight" for NIP-71 dim tag
///
/// Examples:
/// - Square 1080p: "1080x1080"
/// - Vertical 1080p: "607x1080" (9:16 ratio)
String getDimensionTag(AspectRatio aspectRatio, int baseResolution) {
  switch (aspectRatio) {
    case AspectRatio.square:
      // 1:1 - width and height are equal
      return '${baseResolution}x${baseResolution}';

    case AspectRatio.vertical:
      // 9:16 - width is 9/16 of height
      final width = (baseResolution * 9 / 16).floor();
      return '${width}x${baseResolution}';
  }
}
