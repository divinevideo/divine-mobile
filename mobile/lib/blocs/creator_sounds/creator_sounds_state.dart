part of 'creator_sounds_cubit.dart';

enum CreatorSoundsStatus { initial, loading, success, failure }

class CreatorSoundsState extends Equatable {
  const CreatorSoundsState({
    this.status = CreatorSoundsStatus.initial,
    this.sounds = const [],
    this.failureKind,
  });

  final CreatorSoundsStatus status;

  /// The creator's most used sounds, most used first.
  final List<CreatorSound> sounds;

  /// Why the last load failed; `null` unless [status] is
  /// [CreatorSoundsStatus.failure].
  final CreatorAnalyticsFailureKind? failureKind;

  @override
  List<Object?> get props => [status, sounds, failureKind];
}
