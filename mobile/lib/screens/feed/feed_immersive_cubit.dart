// ABOUTME: Feed-scoped state for immersive video viewing. Chrome hides either
// ABOUTME: transiently (hold-to-peek, restored on release) or persistently
// ABOUTME: (a pinch pins it hidden until the viewer taps or swipes away).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feed-scoped runtime state for immersive viewing.
///
/// Owned per feed surface (home feed page / fullscreen feed) and provided
/// down the tree via `BlocProvider`, so the page-level chrome (feed mode
/// header, app bar) and the per-item overlay chrome all fade against the
/// same signal.
class FeedImmersiveState extends Equatable {
  const FeedImmersiveState({this.isImmersive = false, this.isPinned = false});

  /// Whether the chrome over the video is currently hidden. True for either
  /// source: a transient hold or a persistent [isPinned].
  final bool isImmersive;

  /// Whether the viewer pinned the chrome hidden with a pinch. Unlike a hold,
  /// a pin survives the fingers lifting and is only cleared by a second pinch,
  /// a tap, a swipe to another video, or leaving the feed.
  final bool isPinned;

  @override
  List<Object?> get props => [isImmersive, isPinned];
}

/// Feed-scoped Cubit that owns the immersive-viewing flag.
///
/// Two independent sources feed [FeedImmersiveState.isImmersive]: the
/// transient hold ([enter]/[exit]) and the persistent pin ([pin]/[unpin]).
/// They are tracked separately so releasing a hold cannot clear a pin, and
/// un-pinning cannot end a hold the viewer is still making.
class FeedImmersiveCubit extends Cubit<FeedImmersiveState> {
  FeedImmersiveCubit() : super(const FeedImmersiveState());

  /// Whether a finger is currently held on the video.
  bool _isHolding = false;

  /// Whether the viewer pinned the chrome hidden with a pinch.
  bool _isPinned = false;

  /// Republish the state for the current sources. `emit` drops an equal state,
  /// so this is safe to call unconditionally.
  void _emit() {
    emit(
      FeedImmersiveState(
        isImmersive: _isHolding || _isPinned,
        isPinned: _isPinned,
      ),
    );
  }

  /// Hides the chrome for as long as the finger stays down. Idempotent.
  void enter() {
    if (_isHolding) return;
    _isHolding = true;
    _emit();
  }

  /// Ends a hold and restores the chrome, unless a pin still keeps it hidden.
  /// Idempotent, so the several exit paths that guard against a stuck overlay
  /// can all call it unconditionally.
  void exit() {
    if (!_isHolding) return;
    _isHolding = false;
    _emit();
  }

  /// Pins the chrome hidden until a second pinch, a tap, a swipe, or leaving
  /// the feed. Idempotent.
  void pin() {
    if (_isPinned) return;
    _isPinned = true;
    _emit();
  }

  /// Clears a pin. Idempotent; a hold still in progress keeps the chrome
  /// hidden.
  void unpin() {
    if (!_isPinned) return;
    _isPinned = false;
    _emit();
  }
}
