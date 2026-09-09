// ABOUTME: State class for tracking seen videos with immutable state pattern
// ABOUTME: Used by SeenVideosNotifier for reactive state management

import 'package:equatable/equatable.dart';
import 'package:openvine/state/equal_unmodifiable_collections.dart';

class SeenVideosState extends Equatable {
  const SeenVideosState({
    Set<String> seenVideoIds = const {},
    this.isInitialized = false,
  }) : _seenVideoIds = seenVideoIds;

  /// Initial empty state
  static const initial = SeenVideosState();

  final Set<String> _seenVideoIds;
  Set<String> get seenVideoIds {
    if (_seenVideoIds is EqualUnmodifiableSetView) return _seenVideoIds;
    return EqualUnmodifiableSetView(_seenVideoIds);
  }

  final bool isInitialized;

  SeenVideosState copyWith({Set<String>? seenVideoIds, bool? isInitialized}) {
    return SeenVideosState(
      seenVideoIds: seenVideoIds ?? _seenVideoIds,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [_seenVideoIds, isInitialized];
}
