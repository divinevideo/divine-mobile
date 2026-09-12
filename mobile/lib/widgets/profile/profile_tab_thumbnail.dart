// ABOUTME: Shared thumbnail widget for profile tab grids
// ABOUTME: Wraps PassiveAuthThumbnailImage with blurhash and placeholder fallbacks

import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Cached thumbnail for profile grid tiles.
///
/// Shows a [PassiveAuthThumbnailImage] when [thumbnailUrl] is non-empty,
/// falling back to a [BlurhashDisplay] (when [blurhash] is provided) or
/// [ProfileTabThumbnailPlaceholder] for loading, error, and null states.
///
/// Set [isPrecached] to `true` to skip fade animations (used when the image
/// was already resolved before the widget mounted).
class ProfileTabThumbnail extends StatelessWidget {
  const ProfileTabThumbnail({
    required this.thumbnailUrl,
    this.blurhash,
    this.isPrecached = false,
    super.key,
  });

  final String? thumbnailUrl;
  final String? blurhash;
  final bool isPrecached;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final rawWidth = constraints.maxWidth;
          // Decode at tile_width × DPR so the profile grid stays under the
          // default ImageCache budget without upscaling. See PR #4220 (#4190).
          final memCacheWidth = rawWidth.isFinite && rawWidth > 0
              ? (rawWidth * MediaQuery.devicePixelRatioOf(context)).round()
              : null;
          return PassiveAuthThumbnailImage(
            url: thumbnailUrl!,
            memCacheWidth: memCacheWidth,
            alignment: Alignment.center,
            fadeInDuration: isPrecached
                ? Duration.zero
                : const Duration(milliseconds: 500),
            fadeOutDuration: isPrecached
                ? Duration.zero
                : const Duration(milliseconds: 1000),
            placeholder: (context, url) => _Fallback(blurhash: blurhash),
            errorWidget: (context, url, error) => _Fallback(blurhash: blurhash),
            logName: 'ProfileTabThumbnail',
            logPrefix: 'Profile thumbnail',
          );
        },
      );
    }
    return _Fallback(blurhash: blurhash);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.blurhash});

  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final blurhashValue = blurhash;
    if (blurhashValue != null && blurhashValue.isNotEmpty) {
      return BlurhashDisplay(blurhash: blurhashValue);
    }
    return const ProfileTabThumbnailPlaceholder();
  }
}
