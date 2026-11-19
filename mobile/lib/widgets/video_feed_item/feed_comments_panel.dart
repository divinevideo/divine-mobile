// ABOUTME: Lays a feed screen out beside its comments panel in wide landscape
// ABOUTME: windows; elsewhere the screen fills its space and comments use the sheet

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show liveCommentCountSeed;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/comments_panel_scope.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/utils/semantics_announcement.dart';

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
/// over the feed while the panel is open. The panel opens only in wide
/// landscape windows ([AdaptiveLayout.isWideLandscape]); everywhere else
/// [CommentsPanelScope] publishes no cubit, so comments open in the sheet as
/// before. A panel already open when the window stops being wide landscape
/// (rotating, folding, a portrait camera opened over the feed) stays, hidden,
/// with what was typed in it, and shows again once the window is wide again.
/// The tree keeps its shape either way, so rotating never rebuilds the feed.
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
      _announce(context, request);
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

  /// Tells a screen reader the panel opened, with its header: it opens
  /// beside the video, not as a screen of its own, which a screen reader
  /// would announce by itself.
  void _announce(BuildContext context, CommentsPanelRequest request) {
    final count =
        request.initialCommentCount ?? liveCommentCountSeed(request.video);
    announceDetached(
      context,
      context.l10n.commentsHeaderCount(count ?? 0),
      description: 'announce the comments panel',
      logName: 'FeedCommentsPanelHost',
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    final available = layout.isWideLandscape;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final padding = MediaQuery.paddingOf(context);
    // The panel sits against the trailing edge. A side inset still left there
    // (a camera cutout, or a navigation bar on the side in landscape; the
    // iPhone Duo's status bar column is already taken off by the shell and
    // the page frame) is padded inside the panel, and the feed beside it no
    // longer needs to keep clear of it.
    final trailingInset = isRtl ? padding.left : padding.right;
    final panelWidth =
        math.min(
          _maxPanelWidth,
          math.max(_minPanelWidth, layout.size.width * _panelWidthFraction),
        ) +
        trailingInset;
    final shown = _shown;
    // Takes the feed's trailing inset only while it is on screen.
    final panelOnScreen = shown != null && available;
    return CommentsPanelScope(
      cubit: _cubit,
      canOpen: available,
      child: BlocListener<CommentsPanelCubit, CommentsPanelRequest?>(
        bloc: _cubit,
        listener: _onRequestChanged,
        child: Row(
          children: [
            Expanded(
              key: const ValueKey('feed'),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: panelOnScreen && isRtl,
                removeRight: panelOnScreen && !isRtl,
                child: widget.child,
              ),
            ),
            if (shown != null)
              // Hidden while the window is not wide landscape, keeping its
              // state; the keyboard lets go of a field in it meanwhile.
              Offstage(
                offstage: !available,
                child: ExcludeFocus(
                  excluding: !available,
                  // Slides in from the trailing edge, the feed narrowing
                  // beside it, and back out on close.
                  child: SizeTransition(
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
