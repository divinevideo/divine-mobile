// ABOUTME: Draws a sticker the same at any system text size and with Bold
// ABOUTME: Text, since the sticker is part of the video.

import 'package:flutter/widgets.dart';

/// Draws [child] at the normal text size and weight, whatever the system's
/// text size and Bold Text settings.
///
/// A sticker is part of the video: the creator sizes it with a pinch, the
/// export bakes it into the frames, and the player lays its copy over them.
/// The creator's settings must not end up in the frames, nor a viewer's in
/// the copy that has to match them.
class StickerTextScope extends StatelessWidget {
  const StickerTextScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: data.copyWith(textScaler: TextScaler.noScaling, boldText: false),
      child: child,
    );
  }
}
