// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classic_vines_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ClassicVines grid provider, ranked by the repository's recommendation path.
///
/// Uses opaque cursor pagination, with archive fallback owned by the repository.
/// Each page is 50 videos.
///
/// Pull-to-refresh starts a new Classics selection while retrying
/// transient failures and empty pages.

@ProviderFor(ClassicVinesFeed)
final classicVinesFeedProvider = ClassicVinesFeedProvider._();

/// ClassicVines grid provider, ranked by the repository's recommendation path.
///
/// Uses opaque cursor pagination, with archive fallback owned by the repository.
/// Each page is 50 videos.
///
/// Pull-to-refresh starts a new Classics selection while retrying
/// transient failures and empty pages.
final class ClassicVinesFeedProvider
    extends $AsyncNotifierProvider<ClassicVinesFeed, VideoFeedState> {
  /// ClassicVines grid provider, ranked by the repository's recommendation path.
  ///
  /// Uses opaque cursor pagination, with archive fallback owned by the repository.
  /// Each page is 50 videos.
  ///
  /// Pull-to-refresh starts a new Classics selection while retrying
  /// transient failures and empty pages.
  ClassicVinesFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedHash();

  @$internal
  @override
  ClassicVinesFeed create() => ClassicVinesFeed();
}

String _$classicVinesFeedHash() => r'434ef7448fc13c855ab96a03fbc8185c6416227d';

/// ClassicVines grid provider, ranked by the repository's recommendation path.
///
/// Uses opaque cursor pagination, with archive fallback owned by the repository.
/// Each page is 50 videos.
///
/// Pull-to-refresh starts a new Classics selection while retrying
/// transient failures and empty pages.

abstract class _$ClassicVinesFeed extends $AsyncNotifier<VideoFeedState> {
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

/// The same view is used by the grid and its fullscreen feed bridge. Riverpod
/// can retain the previous window while replacing it after a dependency
/// change. Publish an empty loading window so the bridge also drops its replay.

@ProviderFor(visibleClassicVinesFeed)
final visibleClassicVinesFeedProvider = VisibleClassicVinesFeedProvider._();

/// The same view is used by the grid and its fullscreen feed bridge. Riverpod
/// can retain the previous window while replacing it after a dependency
/// change. Publish an empty loading window so the bridge also drops its replay.

final class VisibleClassicVinesFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<VideoFeedState>,
          AsyncValue<VideoFeedState>,
          AsyncValue<VideoFeedState>
        >
    with $Provider<AsyncValue<VideoFeedState>> {
  /// The same view is used by the grid and its fullscreen feed bridge. Riverpod
  /// can retain the previous window while replacing it after a dependency
  /// change. Publish an empty loading window so the bridge also drops its replay.
  VisibleClassicVinesFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleClassicVinesFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleClassicVinesFeedHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<VideoFeedState>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<VideoFeedState> create(Ref ref) {
    return visibleClassicVinesFeed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<VideoFeedState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<VideoFeedState>>(value),
    );
  }
}

String _$visibleClassicVinesFeedHash() =>
    r'4581ff567007ef04860212d39074dfb7fd14f9d3';

/// Provider to check if classic vines feed is loading

@ProviderFor(classicVinesFeedLoading)
final classicVinesFeedLoadingProvider = ClassicVinesFeedLoadingProvider._();

/// Provider to check if classic vines feed is loading

final class ClassicVinesFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if classic vines feed is loading
  ClassicVinesFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return classicVinesFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$classicVinesFeedLoadingHash() =>
    r'b65d115726dafb684dcc892c338896ed73bd70ae';

/// Provider to get current classic vines feed video count

@ProviderFor(classicVinesFeedCount)
final classicVinesFeedCountProvider = ClassicVinesFeedCountProvider._();

/// Provider to get current classic vines feed video count

final class ClassicVinesFeedCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current classic vines feed video count
  ClassicVinesFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return classicVinesFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$classicVinesFeedCountHash() =>
    r'8f9be3ce5ceb7087286e158f4e4c98825de0fed7';

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.

@ProviderFor(classicVinesAvailable)
final classicVinesAvailableProvider = ClassicVinesAvailableProvider._();

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.

final class ClassicVinesAvailableProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if classic vines are available
  ///
  /// Delegates to the centralized funnelcakeAvailableProvider.
  /// Classic vines require Funnelcake REST API to be available.
  ClassicVinesAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classicVinesAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classicVinesAvailableHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return classicVinesAvailable(ref);
  }
}

String _$classicVinesAvailableHash() =>
    r'617a64b91dcb7896bcc986e4a7af0f0db6544825';

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count.
/// Also triggers profile prefetching for Viners without avatars.

@ProviderFor(topClassicViners)
final topClassicVinersProvider = TopClassicVinersProvider._();

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count.
/// Also triggers profile prefetching for Viners without avatars.

final class TopClassicVinersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClassicViner>>,
          List<ClassicViner>,
          FutureOr<List<ClassicViner>>
        >
    with
        $FutureModifier<List<ClassicViner>>,
        $FutureProvider<List<ClassicViner>> {
  /// Provider for top classic Viners derived from classic videos
  ///
  /// Aggregates videos by pubkey and sorts by total loop count.
  /// Also triggers profile prefetching for Viners without avatars.
  TopClassicVinersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topClassicVinersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topClassicVinersHash();

  @$internal
  @override
  $FutureProviderElement<List<ClassicViner>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClassicViner>> create(Ref ref) {
    return topClassicViners(ref);
  }
}

String _$topClassicVinersHash() => r'bb99bcc21ff31717d26e0c4b39afb5bb7b4ab0a8';
