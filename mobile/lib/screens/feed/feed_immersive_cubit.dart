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
  const FeedImmersiveState({this.isHolding = false, this.isPinned = false});

  /// Whether a finger is currently held on the video (hold-to-peek).
  final bool isHolding;

  /// Whether the viewer pinned the chrome hidden with a pinch. Unlike a hold,
  /// a pin survives the fingers lifting and is only cleared by a second pinch,
  /// a tap, or the item it was made on going away: a swipe to another video,
  /// the video being replaced, or the feed being torn down.
  final bool isPinned;

  /// Whether the chrome over the video is currently hidden. True for either
  /// source: a transient [isHolding] or a persistent [isPinned].
  bool get isImmersive => isHolding || isPinned;

  FeedImmersiveState copyWith({bool? isHolding, bool? isPinned}) =>
      FeedImmersiveState(
        isHolding: isHolding ?? this.isHolding,
        isPinned: isPinned ?? this.isPinned,
      );

  @override
  List<Object?> get props => [isHolding, isPinned];
}

/// Feed-scoped Cubit that owns the immersive-viewing flag.
///
/// Two independent sources feed [FeedImmersiveState.isImmersive]: the
/// transient hold ([enter]/[exit]) and the persistent pin ([pin]/[unpin]).
/// They are tracked separately so releasing a hold cannot clear a pin, and
/// un-pinning cannot end a hold the viewer is still making.
class FeedImmersiveCubit extends Cubit<FeedImmersiveState> {
  FeedImmersiveCubit() : super(const FeedImmersiveState());

  /// Hides the chrome for as long as the finger stays down. Idempotent.
  void enter() {
    if (state.isHolding) return;
    emit(state.copyWith(isHolding: true));
  }

  /// Ends a hold and restores the chrome, unless a pin still keeps it hidden.
  /// Idempotent, so the several exit paths that guard against a stuck overlay
  /// can all call it unconditionally.
  ///
  /// The guard is load-bearing: `emit` only suppresses an equal state after
  /// the first emission, so without it an `exit()` on an untouched cubit
  /// would emit the initial state.
  void exit() {
    if (!state.isHolding) return;
    emit(state.copyWith(isHolding: false));
  }

  /// Pins the chrome hidden until it is cleared; see
  /// [FeedImmersiveState.isPinned]. Idempotent.
  void pin() {
    if (state.isPinned) return;
    emit(state.copyWith(isPinned: true));
  }

  /// Clears a pin. Idempotent; a hold still in progress keeps the chrome
  /// hidden.
  void unpin() {
    if (!state.isPinned) return;
    emit(state.copyWith(isPinned: false));
  }
}
