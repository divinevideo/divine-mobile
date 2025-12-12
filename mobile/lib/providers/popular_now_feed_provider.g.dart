// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popular_now_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)

@ProviderFor(PopularNowFeed)
const popularNowFeedProvider = PopularNowFeedProvider._();

/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)
final class PopularNowFeedProvider
    extends $AsyncNotifierProvider<PopularNowFeed, VideoFeedState> {
  /// PopularNow feed provider - shows newest videos (sorted by creation time)
  ///
  /// Rebuilds when:
  /// - Poll interval elapses (uses same auto-refresh as home feed)
  /// - User pulls to refresh
  /// - VideoEventService updates with new videos
  /// - appReady gate becomes true (triggers rebuild to start subscription)
  const PopularNowFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularNowFeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularNowFeedHash();

  @$internal
  @override
  PopularNowFeed create() => PopularNowFeed();
}

String _$popularNowFeedHash() => r'36a6a1f5dd5b16e3087a0cd35a1b0f5c9302d805';

/// PopularNow feed provider - shows newest videos (sorted by creation time)
///
/// Rebuilds when:
/// - Poll interval elapses (uses same auto-refresh as home feed)
/// - User pulls to refresh
/// - VideoEventService updates with new videos
/// - appReady gate becomes true (triggers rebuild to start subscription)

abstract class _$PopularNowFeed extends $AsyncNotifier<VideoFeedState> {
  FutureOr<VideoFeedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to check if popularNow feed is loading

@ProviderFor(popularNowFeedLoading)
const popularNowFeedLoadingProvider = PopularNowFeedLoadingProvider._();

/// Provider to check if popularNow feed is loading

final class PopularNowFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if popularNow feed is loading
  const PopularNowFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularNowFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularNowFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return popularNowFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$popularNowFeedLoadingHash() =>
    r'5b6df7d0c257598548cbbd121512d12679e5b40d';

/// Provider to get current popularNow feed video count

@ProviderFor(popularNowFeedCount)
const popularNowFeedCountProvider = PopularNowFeedCountProvider._();

/// Provider to get current popularNow feed video count

final class PopularNowFeedCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current popularNow feed video count
  const PopularNowFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popularNowFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popularNowFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return popularNowFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$popularNowFeedCountHash() =>
    r'dce8c06d1e325c89c63962db1f02eac81092e521';
