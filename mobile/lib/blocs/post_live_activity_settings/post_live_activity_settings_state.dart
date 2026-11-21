// ABOUTME: State for PostLiveActivitySettingsCubit: the in-app toggle and
// ABOUTME: whether iOS allows Live Activities for the app at all.

import 'package:equatable/equatable.dart';

/// State for `PostLiveActivitySettingsCubit`.
class PostLiveActivitySettingsState extends Equatable {
  /// Creates the state. Both default to on until loaded.
  const PostLiveActivitySettingsState({
    this.toggleOn = true,
    this.systemEnabled = true,
  });

  /// Whether the in-app toggle is on.
  final bool toggleOn;

  /// Whether the iPhone setting allows Live Activities for Divine.
  final bool systemEnabled;

  /// Whether the row reads as on: both the toggle and the system allow it.
  bool get effectivelyOn => toggleOn && systemEnabled;

  /// A copy with the given fields replaced.
  PostLiveActivitySettingsState copyWith({
    bool? toggleOn,
    bool? systemEnabled,
  }) => PostLiveActivitySettingsState(
    toggleOn: toggleOn ?? this.toggleOn,
    systemEnabled: systemEnabled ?? this.systemEnabled,
  );

  @override
  List<Object> get props => [toggleOn, systemEnabled];
}
