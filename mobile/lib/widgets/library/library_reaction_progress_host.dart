// ABOUTME: Keeps reaction progress in the overlay of its owning route.
// ABOUTME: Routes pushed above the owner remain visible and interactive.

import 'package:flutter/widgets.dart';

/// Hosts progress while a Library reaction's footage is being prepared.
class LibraryReactionProgressHost extends StatefulWidget {
  const LibraryReactionProgressHost({required this.child, super.key});

  final Widget child;

  /// Attaches [progress] to the owning Library or layout screen.
  ///
  /// The returned callback clears only this invocation's progress.
  static VoidCallback? show(BuildContext context, Widget progress) {
    final host = context
        .findAncestorStateOfType<_LibraryReactionProgressHostState>();
    return host?._show(progress);
  }

  @override
  State<LibraryReactionProgressHost> createState() =>
      _LibraryReactionProgressHostState();
}

class _LibraryReactionProgressHostState
    extends State<LibraryReactionProgressHost> {
  final _controller = OverlayPortalController();
  Widget? _progress;

  VoidCallback _show(Widget progress) {
    _progress = progress;
    _controller.show();
    return () {
      if (!mounted || !identical(_progress, progress)) return;
      _progress = null;
      _controller.hide();
    };
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _controller,
    overlayChildBuilder: (_) => _progress ?? const SizedBox.shrink(),
    child: widget.child,
  );
}
