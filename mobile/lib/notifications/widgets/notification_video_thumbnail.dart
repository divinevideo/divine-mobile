// ABOUTME: Right-side 56×56 video thumbnail on a video-anchored notification
// ABOUTME: row. Renders the cached thumbnail or a card-background placeholder
// ABOUTME: when the URL is missing.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Diameter of the video thumbnail.
const double _thumbnailSize = 56;

/// Memory-cache decode width for the thumbnail. Sized for 4× DPI
/// (`56 × 4 = 224`) so the rendered chip stays sharp on the highest
/// pixel-density displays we ship to without paying for a full
/// pre-scaled cache. At 2× / 3× the cache decodes slightly oversized
/// and the GPU downscales — cheap.
const int _thumbnailMemCacheWidth = 224;

/// Tap-target wrapper around the 56×56 thumbnail at the right edge of a
/// `VideoNotificationRow`. Public so tests can locate it via
/// `find.byType(NotificationVideoThumbnail)` instead of a
/// hardcoded-string `Key`.
class NotificationVideoThumbnail extends StatelessWidget {
  /// Creates a [NotificationVideoThumbnail].
  const NotificationVideoThumbnail({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    super.key,
  });

  /// Cached thumbnail URL. When null, a flat card-background tile shows
  /// instead so the row's right edge stays a fixed 56×56.
  final String? imageUrl;

  /// Optional video title — used in the screen-reader label so the
  /// thumbnail announces "Video thumbnail for {title}" when known.
  final String? title;

  /// Tap handler — the row body's onTap and the thumbnail's onTap are
  /// split so a tap on the thumbnail can target a different navigation
  /// (e.g. open the video) than a tap elsewhere on the row.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: title != null
          ? l10n.notificationsVideoThumbnailFor(title!)
          : l10n.notificationsVideoThumbnail,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _thumbnailSize,
            height: _thumbnailSize,
            child: imageUrl != null
                ? VineCachedImage(
                    imageUrl: imageUrl!,
                    memCacheWidth: _thumbnailMemCacheWidth,
                  )
                : ColoredBox(color: context.vineColors.card),
          ),
        ),
      ),
    );
  }
}
