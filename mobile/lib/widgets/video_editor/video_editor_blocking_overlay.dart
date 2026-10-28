// ABOUTME: Scrim that blocks the whole editor for touch and screen readers
// ABOUTME: while a long operation runs, and announces what the user waits on.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/semantics_announcement.dart';

/// Covers the editor while a long-running operation is in flight.
///
/// The scrim absorbs touches, but semantics travel their own path: without
/// [BlockSemantics] the controls underneath stay reachable to a screen reader,
/// which could then start a competing edit mid-render. The control that had
/// screen-reader focus goes away with them, so the overlay announces
/// [announcement] once when it appears.
class VideoEditorBlockingOverlay extends StatefulWidget {
  const VideoEditorBlockingOverlay({
    required this.announcement,
    required this.child,
    super.key,
  });

  /// What the user is waiting for, already localized.
  final String announcement;

  /// The progress drawn over the scrim. Controls in it, such as a Cancel
  /// button, stay reachable.
  final Widget child;

  @override
  State<VideoEditorBlockingOverlay> createState() =>
      _VideoEditorBlockingOverlayState();
}

class _VideoEditorBlockingOverlayState
    extends State<VideoEditorBlockingOverlay> {
  @override
  void initState() {
    super.initState();
    // After the first frame, once the editor underneath is already hidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      announceDetached(
        context,
        widget.announcement,
        description: 'announce blocking editor operation',
        logName: 'VideoEditorBlockingOverlay',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: ColoredBox(
        color: context.vineColors.background.withAlpha(210),
        child: widget.child,
      ),
    );
  }
}
