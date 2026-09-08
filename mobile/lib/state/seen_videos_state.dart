// ABOUTME: State class for tracking seen videos with immutable state pattern
// ABOUTME: Used by SeenVideosNotifier for reactive state management

import 'package:equatable/equatable.dart';

class SeenVideosState extends Equatable {
  const SeenVideosState({
    this.seenVideoIds = const {},
    this.isInitialized = false,
  });

  /// Initial empty state
  static const initial = SeenVideosState();

  final Set<String> seenVideoIds;
  final bool isInitialized;

  SeenVideosState copyWith({Set<String>? seenVideoIds, bool? isInitialized}) {
    return SeenVideosState(
      seenVideoIds: seenVideoIds ?? this.seenVideoIds,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [seenVideoIds, isInitialized];
}
