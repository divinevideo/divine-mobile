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
class VideoMetadataLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!context.adaptiveLayout.isWideLandscape) {
      return Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [preview, ...details],
              ),
            ),
          ),
          SafeArea(top: false, child: bottomBar),
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
                constraints.maxWidth * previewPaneFraction,
                maxPreviewPaneWidth,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(previewPaneInset),
                  child: LayoutBuilder(
                    builder: (context, pane) =>
                        Center(child: sidePreview(pane.biggest)),
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
                      padding: const EdgeInsets.only(top: previewPaneInset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: details,
                      ),
                    ),
                  ),
                  SafeArea(top: false, child: bottomBar),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
