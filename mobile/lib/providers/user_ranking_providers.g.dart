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
    r'e13bd33f21b2cc49bc9d25a05534f153926aa5da';
