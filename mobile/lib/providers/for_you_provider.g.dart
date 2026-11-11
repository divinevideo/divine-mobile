// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'for_you_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// For You recommendations feed provider - ML-powered personalized videos
///
/// Uses Gorse-based recommendations from Funnelcake REST API.
/// Falls back to popular videos when personalization isn't available.
/// Currently only enabled on staging environment for testing.

@ProviderFor(ForYouFeed)
final forYouFeedProvider = ForYouFeedProvider._();

/// For You recommendations feed provider - ML-powered personalized videos
///
/// Uses Gorse-based recommendations from Funnelcake REST API.
/// Falls back to popular videos when personalization isn't available.
/// Currently only enabled on staging environment for testing.
final class ForYouFeedProvider
    extends $AsyncNotifierProvider<ForYouFeed, VideoFeedState> {
  /// For You recommendations feed provider - ML-powered personalized videos
  ///
  /// Uses Gorse-based recommendations from Funnelcake REST API.
  /// Falls back to popular videos when personalization isn't available.
  /// Currently only enabled on staging environment for testing.
  ForYouFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouFeedHash();

  @$internal
  @override
  ForYouFeed create() => ForYouFeed();
}

String _$forYouFeedHash() => r'45df0a8bedecab89038db31a6326aa08209bd8a9';

/// For You recommendations feed provider - ML-powered personalized videos
///
/// Uses Gorse-based recommendations from Funnelcake REST API.
/// Falls back to popular videos when personalization isn't available.
/// Currently only enabled on staging environment for testing.

abstract class _$ForYouFeed extends $AsyncNotifier<VideoFeedState> {
  FutureOr<VideoFeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider to check if For You tab should be visible
///
/// Available when Funnelcake REST API is available (has recommendations endpoint).

@ProviderFor(forYouAvailable)
final forYouAvailableProvider = ForYouAvailableProvider._();

/// Provider to check if For You tab should be visible
///
/// Available when Funnelcake REST API is available (has recommendations endpoint).

final class ForYouAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if For You tab should be visible
  ///
  /// Available when Funnelcake REST API is available (has recommendations endpoint).
  ForYouAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return forYouAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$forYouAvailableHash() => r'406ca7b70240fe02deb1c61f455f256440e40cd2';

/// Provider to check if For You feed is loading

@ProviderFor(forYouFeedLoading)
final forYouFeedLoadingProvider = ForYouFeedLoadingProvider._();

/// Provider to check if For You feed is loading

final class ForYouFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if For You feed is loading
  ForYouFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return forYouFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$forYouFeedLoadingHash() => r'9eea3cee5284c8fd12b7a15e734079db6ba63d09';

/// Provider to get current For You feed video count

@ProviderFor(forYouFeedCount)
final forYouFeedCountProvider = ForYouFeedCountProvider._();

/// Provider to get current For You feed video count

final class ForYouFeedCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current For You feed video count
  ForYouFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'forYouFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$forYouFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return forYouFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$forYouFeedCountHash() => r'ef7a65fdc8a7fa0aa837560954743339194d51f6';
