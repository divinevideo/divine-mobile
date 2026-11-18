// ABOUTME: Lays a feed screen out beside its comments panel in wide landscape
// ABOUTME: windows; elsewhere the screen fills its space and comments use the sheet

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/screens/comments/comments_panel_scope.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// The comments panel's width: about a third of the window, within these
/// bounds, plus the system inset on the edge it sits against.
const double _minPanelWidth = 360;
const double _maxPanelWidth = 420;
const double _panelWidthFraction = 0.36;

/// How long the panel takes to slide in or out.
const Duration _slideDuration = Duration(milliseconds: 280);

/// Lays [child], a feed screen, out beside the comments panel.
///
/// Wraps the whole screen — its top bar too — so the screen's chrome stays
/// over the feed while the panel is open. The panel exists only in wide
/// landscape windows ([AdaptiveLayout.isWideLandscape]); everywhere else
/// [CommentsPanelScope] publishes no cubit, so comments open in the sheet as
/// before. The tree keeps its shape either way, so rotating never rebuilds
/// the feed.
class FeedCommentsPanelHost extends StatefulWidget {
  const FeedCommentsPanelHost({
    required this.child,
    this.panelBuilder = _commentsPanel,
    super.key,
  });

  final Widget child;

  /// Builds the panel's content for a request: the comments, which tests
  /// stand in for.
  @visibleForTesting
  final Widget Function(CommentsPanelRequest request, VoidCallback onClose)
  panelBuilder;

  static Widget _commentsPanel(
    CommentsPanelRequest request,
    VoidCallback onClose,
  ) => CommentsPanel(
    // A new request (another video, or the same one reopened) gets fresh
    // blocs.
    key: ObjectKey(request),
    request: request,
    onClose: onClose,
  );

  @override
  State<FeedCommentsPanelHost> createState() => _FeedCommentsPanelHostState();
}

class _FeedCommentsPanelHostState extends State<FeedCommentsPanelHost>
    with SingleTickerProviderStateMixin {
  final _cubit = CommentsPanelCubit();
  bool _closeScheduled = false;

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: _slideDuration,
  );
  late final CurvedAnimation _slideCurve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The request the panel shows, kept while it slides out after a dismiss.
  CommentsPanelRequest? _shown;

  @override
  void dispose() {
    _slideCurve.dispose();
    _slide.dispose();
    _cubit.close().ignore();
    super.dispose();
  }

  /// Slides the panel in for a [request], or out once it is dismissed.
  void _onRequestChanged(BuildContext context, CommentsPanelRequest? request) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (request != null) {
      setState(() => _shown = request);
      if (reduceMotion) {
        _slide.value = 1;
      } else {
        _slide.forward();
      }
      return;
    }
    if (reduceMotion) {
      _slide.value = 0;
      setState(() => _shown = null);
      return;
    }
    _slide.reverse().whenCompleteOrCancel(() {
      // A request that came in meanwhile keeps the panel.
      if (mounted && _cubit.state == null) setState(() => _shown = null);
    });
  }

  /// Closes a panel the window got too narrow for (rotation, folding) after
  /// this frame: the cubit may not emit while the tree builds.
  void _closeIfOpen() {
    if (_cubit.state == null || _closeScheduled) return;
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeScheduled = false;
      if (mounted) _cubit.dismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    final available = layout.isWideLandscape;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final padding = MediaQuery.paddingOf(context);
    // The panel sits against the trailing edge, where the iPhone Duo keeps
    // its status bar: the panel pads its content clear of it, and the feed
    // beside it no longer needs to.
    final trailingInset = isRtl ? padding.left : padding.right;
    final panelWidth =
        math.min(
          _maxPanelWidth,
          math.max(_minPanelWidth, layout.size.width * _panelWidthFraction),
        ) +
        trailingInset;
    if (!available) _closeIfOpen();
    final shown = available ? _shown : null;
    return CommentsPanelScope(
      cubit: available ? _cubit : null,
      child: BlocListener<CommentsPanelCubit, CommentsPanelRequest?>(
        bloc: _cubit,
        listener: _onRequestChanged,
        child: Row(
          children: [
            Expanded(
              key: const ValueKey('feed'),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: shown != null && isRtl,
                removeRight: shown != null && !isRtl,
                child: widget.child,
              ),
            ),
            if (shown != null)
              // Slides in from the trailing edge, the feed narrowing beside
              // it, and back out on close.
              SizeTransition(
                axis: Axis.horizontal,
                sizeFactor: _slideCurve,
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: panelWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.vineColors.surface,
                      border: BorderDirectional(
                        start: BorderSide(
                          color: context.vineColors.surfaceContainer,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      left: isRtl,
                      right: !isRtl,
                      bottom: false,
                      child: widget.panelBuilder(shown, _cubit.dismiss),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
