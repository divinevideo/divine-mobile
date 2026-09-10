// ABOUTME: Shared thumbnail placeholder for profile tab grids
// ABOUTME: Shown while thumbnails load or when the image URL is missing

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Flat color placeholder used as loading and error fallback for
/// profile grid thumbnails.
class ProfileTabThumbnailPlaceholder extends StatelessWidget {
  const ProfileTabThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: .circular(4),
      color: context.vineColors.surfaceContainer,
    ),
  );
}
