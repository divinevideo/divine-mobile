// ABOUTME: Empties Flutter's decoded-image cache when its child leaves the
// ABOUTME: tree, so a screen's decoded images do not outlive the screen.

import 'package:flutter/widgets.dart';

/// Drops every cached decoded image that nothing shows any more once [child]
/// is disposed.
///
/// The camera and the editor decode clip thumbnails, timeline strips, ghost
/// frames and stop-motion stills that no other screen shows. Flutter's
/// [ImageCache] keeps them after the screen closes until its byte budget
/// (`AppConstants.imageCacheMaxBytes`) is full. Impeller holds each one as a
/// GPU texture with a full mip chain, so a full budget measured as about twice
/// its size in graphics memory: ~500 MB on a Galaxy S26 after 50 camera →
/// editor round trips (#10301). The app already empties the cache when it goes
/// to the background or the OS reports memory pressure, but neither happens
/// while the user stays in the app, so the next export ran with the camera's
/// and editor's leftovers still on the GPU.
///
/// Images still on screen are live and stay; everything else is decoded again
/// from disk when it is next shown.
class ReleaseCachedImagesOnDispose extends StatefulWidget {
  /// Creates a scope that releases cached images when it is disposed.
  const ReleaseCachedImagesOnDispose({required this.child, super.key});

  /// The screen whose images should not outlive it.
  final Widget child;

  @override
  State<ReleaseCachedImagesOnDispose> createState() =>
      _ReleaseCachedImagesOnDisposeState();
}

class _ReleaseCachedImagesOnDisposeState
    extends State<ReleaseCachedImagesOnDispose> {
  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
