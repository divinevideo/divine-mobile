part of 'explore_badges_cubit.dart';

/// Loading status of Explore's curated badges.
enum ExploreBadgesStatus {
  /// Nothing has been requested yet.
  initial,

  /// The definitions are loading.
  loading,

  /// The definitions loaded.
  loaded,

  /// The definitions could not be completely loaded.
  failure,
}

/// State for the [ExploreBadgesCubit].
class ExploreBadgesState extends Equatable {
  /// Creates Explore badge state.
  const ExploreBadgesState({
    this.status = ExploreBadgesStatus.initial,
    this.definitions = const [],
  });

  /// Loading status of [definitions].
  final ExploreBadgesStatus status;

  /// Curated badge definitions, ordered by name.
  final List<Nip58BadgeDefinition> definitions;

  /// Returns a copy with the given fields replaced.
  ExploreBadgesState copyWith({
    ExploreBadgesStatus? status,
    List<Nip58BadgeDefinition>? definitions,
  }) {
    return ExploreBadgesState(
      status: status ?? this.status,
      definitions: definitions ?? this.definitions,
    );
  }

  @override
  List<Object?> get props => [status, definitions];
}
