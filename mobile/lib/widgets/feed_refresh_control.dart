// ABOUTME: Shared pull-to-refresh wrappers for feed scroll views and states
// ABOUTME: Keeps empty/error feed screens refreshable across touch and trackpad

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shared refresh wrapper for feed scrollables.
///
/// Flutter's [RefreshIndicator] does not handle trackpad pull gestures on
/// desktop, so this also watches top-edge pointer scroll signals and shows the
/// same indicator when the user pulls down far enough.
class FeedRefreshControl extends StatefulWidget {
  const FeedRefreshControl({
    required this.child,
    required this.onRefresh,
    super.key,
    this.scrollController,
    this.semanticsLabel,
    this.displacement = 70,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final ScrollController? scrollController;
  final String? semanticsLabel;
  final double displacement;

  @override
  State<FeedRefreshControl> createState() => _FeedRefreshControlState();
}

class _FeedRefreshControlState extends State<FeedRefreshControl> {
  static const double _pointerRefreshTriggerDistance = 80;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  double _pointerRefreshPullDistance = 0;
  bool _isPointerRefreshRunning = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        semanticsLabel:
            widget.semanticsLabel ?? context.l10n.videoGridRefreshLabel,
        onRefresh: widget.onRefresh,
        displacement: widget.displacement,
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        child: widget.child,
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final position = widget.scrollController?.hasClients == true
        ? widget.scrollController!.position
        : Scrollable.maybeOf(context)?.position;
    if (position == null) {
      return;
    }

    final isAtTop = position.pixels <= position.minScrollExtent + 0.5;
    final isPullingDown = event.scrollDelta.dy < 0;

    if (!isAtTop || !isPullingDown) {
      _pointerRefreshPullDistance = 0;
      return;
    }

    _pointerRefreshPullDistance += -event.scrollDelta.dy;
    if (_pointerRefreshPullDistance < _pointerRefreshTriggerDistance) {
      return;
    }

    _pointerRefreshPullDistance = 0;
    unawaited(_showRefreshFromPointerSignal());
  }

  Future<void> _showRefreshFromPointerSignal() async {
    await showRefreshIndicator();
  }

  Future<void> showRefreshIndicator() async {
    if (_isPointerRefreshRunning) {
      return;
    }

    final refreshIndicator = _refreshIndicatorKey.currentState;
    if (refreshIndicator == null) {
      return;
    }

    _isPointerRefreshRunning = true;
    try {
      await refreshIndicator.show();
    } finally {
      _isPointerRefreshRunning = false;
    }
  }
}

/// Refreshable full-height state view for feed empty/error/unavailable states.
class RefreshableFeedStateView extends StatefulWidget {
  const RefreshableFeedStateView({
    required this.child,
    required this.onRefresh,
    super.key,
    this.autoRefresh = false,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  /// Runs [onRefresh] once after the state first appears.
  ///
  /// This is useful for feeds where an empty state often means a transient
  /// network/server miss rather than a truly terminal result.
  final bool autoRefresh;

  @override
  State<RefreshableFeedStateView> createState() =>
      _RefreshableFeedStateViewState();
}

class _RefreshableFeedStateViewState extends State<RefreshableFeedStateView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoRefreshStarted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoRefreshIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RefreshableFeedStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleAutoRefreshIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return FeedRefreshControl(
      onRefresh: widget.onRefresh,
      scrollController: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(hasScrollBody: false, child: widget.child),
        ],
      ),
    );
  }

  void _scheduleAutoRefreshIfNeeded() {
    if (!widget.autoRefresh || _autoRefreshStarted) {
      return;
    }

    _autoRefreshStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final refreshControlState = context
          .findAncestorStateOfType<_FeedRefreshControlState>();
      if (refreshControlState != null) {
        unawaited(refreshControlState.showRefreshIndicator());
        return;
      }
      unawaited(widget.onRefresh());
    });
  }
}
