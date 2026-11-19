// ABOUTME: Lays out the video metadata screens' body: preview, form and bottom
// ABOUTME: bar, with the preview in a pane of its own in wide landscape windows

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// Lays out a video metadata screen's body: the video preview, the details
/// that follow it (the render failure banner and the form) and the bottom bar.
///
/// On phones the preview scrolls above the details, as it always did. In a
/// wide landscape window (see [AdaptiveLayout.isWideLandscape]) the preview
/// gets a pane of its own on the leading side, as tall as the window allows,
/// and the details and the bottom bar sit beside it, so neither stretches
/// across the whole window. Like every screen there, it ends at a status bar
/// column.
class VideoMetadataLayout extends StatefulWidget {
  /// Creates the layout of a video metadata screen's body.
  const VideoMetadataLayout({
    required this.preview,
    required this.sidePreview,
    required this.details,
    required this.bottomBar,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The preview above the details, with the space it keeps around it.
  final Widget preview;

  /// The preview in its own pane, fitted into the size it is given.
  final Widget Function(Size maxSize) sidePreview;

  /// What follows the preview: the render failure banner and the form.
  final List<Widget> details;

  /// The actions at the bottom of the screen.
  final Widget bottomBar;

  /// Padding of the scroll view the preview and details share on phones.
  final EdgeInsetsGeometry padding;

  /// The share of the width the preview pane takes, up to
  /// [maxPreviewPaneWidth].
  static const double previewPaneFraction = 0.4;

  /// The widest the preview pane gets.
  static const double maxPreviewPaneWidth = 440;

  /// The space kept around the preview in its pane.
  static const double previewPaneInset = 16;

  @override
  State<VideoMetadataLayout> createState() => _VideoMetadataLayoutState();
}

class _VideoMetadataLayoutState extends State<VideoMetadataLayout> {
  /// Keep the form (its text, focus and keyboard) and the bottom bar (its
  /// busy flags) when a rotation moves them between the two layouts.
  final GlobalKey _detailsKey = GlobalKey(debugLabel: 'video-metadata-details');
  final GlobalKey _bottomBarKey = GlobalKey(
    debugLabel: 'video-metadata-bottom-bar',
  );

  @override
  Widget build(BuildContext context) {
    final details = KeyedSubtree(
      key: _detailsKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.details,
      ),
    );
    final bottomBar = SafeArea(
      top: false,
      child: KeyedSubtree(key: _bottomBarKey, child: widget.bottomBar),
    );
    if (!context.adaptiveLayout.isWideLandscape) {
      return Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: widget.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [widget.preview, details],
              ),
            ),
          ),
          bottomBar,
        ],
      );
    }
    return StatusBarColumnSafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: math.min(
                constraints.maxWidth * VideoMetadataLayout.previewPaneFraction,
                VideoMetadataLayout.maxPreviewPaneWidth,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(
                    VideoMetadataLayout.previewPaneInset,
                  ),
                  child: LayoutBuilder(
                    builder: (context, pane) =>
                        Center(child: widget.sidePreview(pane.biggest)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                spacing: 12,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(
                        top: VideoMetadataLayout.previewPaneInset,
                      ),
                      child: details,
                    ),
                  ),
                  bottomBar,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
