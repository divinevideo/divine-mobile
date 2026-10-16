// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_ranking_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Local ranking dependencies, scoped to the current account's repositories.

@ProviderFor(userRankingSignalsLoader)
final userRankingSignalsLoaderProvider = UserRankingSignalsLoaderProvider._();

/// Local ranking dependencies, scoped to the current account's repositories.

final class UserRankingSignalsLoaderProvider
    extends
        $FunctionalProvider<
          UserRankingSignalsLoader,
          UserRankingSignalsLoader,
          UserRankingSignalsLoader
        >
    with $Provider<UserRankingSignalsLoader> {
  /// Local ranking dependencies, scoped to the current account's repositories.
  UserRankingSignalsLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userRankingSignalsLoaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userRankingSignalsLoaderHash();

  @$internal
  @override
  $ProviderElement<UserRankingSignalsLoader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserRankingSignalsLoader create(Ref ref) {
    return userRankingSignalsLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRankingSignalsLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRankingSignalsLoader>(value),
    );
  }
}

String _$userRankingSignalsLoaderHash() =>
    r'e7df7e90a656f7685dcbe39d970570a01362b517';

/// Ranking for the signed-in user's own Following and Followers lists.
///
/// These lists hide only accounts the viewer blocked, as they did before
/// ranking. An account that mutes or blocks the viewer stays listed, so the
/// viewer can still open it to unfollow or report it.

@ProviderFor(ownFollowListRankingSignalsLoader)
final ownFollowListRankingSignalsLoaderProvider =
    OwnFollowListRankingSignalsLoaderProvider._();

/// Ranking for the signed-in user's own Following and Followers lists.
///
/// These lists hide only accounts the viewer blocked, as they did before
/// ranking. An account that mutes or blocks the viewer stays listed, so the
/// viewer can still open it to unfollow or report it.

final class OwnFollowListRankingSignalsLoaderProvider
    extends
        $FunctionalProvider<
          UserRankingSignalsLoader,
          UserRankingSignalsLoader,
          UserRankingSignalsLoader
        >
    with $Provider<UserRankingSignalsLoader> {
  /// Ranking for the signed-in user's own Following and Followers lists.
  ///
  /// These lists hide only accounts the viewer blocked, as they did before
  /// ranking. An account that mutes or blocks the viewer stays listed, so the
  /// viewer can still open it to unfollow or report it.
  OwnFollowListRankingSignalsLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ownFollowListRankingSignalsLoaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$ownFollowListRankingSignalsLoaderHash();

  @$internal
  @override
  $ProviderElement<UserRankingSignalsLoader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserRankingSignalsLoader create(Ref ref) {
    return ownFollowListRankingSignalsLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRankingSignalsLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRankingSignalsLoader>(value),
    );
  }
}

String _$ownFollowListRankingSignalsLoaderHash() =>
    r'f7a9e36a1f553f6396a1c58ce327c50d66bee136';
