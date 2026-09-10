// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for FunnelcakeApiClient (typed client for Funnelcake REST API)

@ProviderFor(funnelcakeApiClient)
final funnelcakeApiClientProvider = FunnelcakeApiClientProvider._();

/// Provider for FunnelcakeApiClient (typed client for Funnelcake REST API)

final class FunnelcakeApiClientProvider
    extends
        $FunctionalProvider<
          FunnelcakeApiClient,
          FunnelcakeApiClient,
          FunnelcakeApiClient
        >
    with $Provider<FunnelcakeApiClient> {
  /// Provider for FunnelcakeApiClient (typed client for Funnelcake REST API)
  FunnelcakeApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'funnelcakeApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$funnelcakeApiClientHash();

  @$internal
  @override
  $ProviderElement<FunnelcakeApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FunnelcakeApiClient create(Ref ref) {
    return funnelcakeApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FunnelcakeApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FunnelcakeApiClient>(value),
    );
  }
}

String _$funnelcakeApiClientHash() =>
    r'7d81bbae93be6855dc50f105e4df081344c1ebff';

/// Single source of truth for Funnelcake REST API availability.
///
/// Uses capability detection - actually probes the API to verify it works.
/// Re-checks when environment or relay configuration changes.
///
/// All feed providers should watch this instead of checking
/// `client.isAvailable` directly.

@ProviderFor(FunnelcakeAvailable)
final funnelcakeAvailableProvider = FunnelcakeAvailableProvider._();

/// Single source of truth for Funnelcake REST API availability.
///
/// Uses capability detection - actually probes the API to verify it works.
/// Re-checks when environment or relay configuration changes.
///
/// All feed providers should watch this instead of checking
/// `client.isAvailable` directly.
final class FunnelcakeAvailableProvider
    extends $AsyncNotifierProvider<FunnelcakeAvailable, bool> {
  /// Single source of truth for Funnelcake REST API availability.
  ///
  /// Uses capability detection - actually probes the API to verify it works.
  /// Re-checks when environment or relay configuration changes.
  ///
  /// All feed providers should watch this instead of checking
  /// `client.isAvailable` directly.
  FunnelcakeAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'funnelcakeAvailableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$funnelcakeAvailableHash();

  @$internal
  @override
  FunnelcakeAvailable create() => FunnelcakeAvailable();
}

String _$funnelcakeAvailableHash() =>
    r'35bb222c27e7b722396f57582b6fc2f9df4cec2c';

/// Single source of truth for Funnelcake REST API availability.
///
/// Uses capability detection - actually probes the API to verify it works.
/// Re-checks when environment or relay configuration changes.
///
/// All feed providers should watch this instead of checking
/// `client.isAvailable` directly.

abstract class _$FunnelcakeAvailable extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

@ProviderFor(Curation)
final curationProvider = CurationProvider._();

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation
final class CurationProvider
    extends $NotifierProvider<Curation, CurationState> {
  /// Main curation provider that manages curated content sets
  /// keepAlive ensures provider persists across tab navigation
  CurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationHash();

  @$internal
  @override
  Curation create() => Curation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationState>(value),
    );
  }
}

String _$curationHash() => r'997d7c7eee62ed0d110655bcaea3b4f91de9ecb9';

/// Main curation provider that manages curated content sets
/// keepAlive ensures provider persists across tab navigation

abstract class _$Curation extends $Notifier<CurationState> {
  CurationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CurationState, CurationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurationState, CurationState>,
              CurationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider to check if curation is loading

@ProviderFor(curationLoading)
final curationLoadingProvider = CurationLoadingProvider._();

/// Provider to check if curation is loading

final class CurationLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if curation is loading
  CurationLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return curationLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$curationLoadingHash() => r'e1a04d9f8d90870d340665613c0938b356085039';

/// Provider to get editor's picks

@ProviderFor(editorsPicks)
final editorsPicksProvider = EditorsPicksProvider._();

/// Provider to get editor's picks

final class EditorsPicksProvider
    extends
        $FunctionalProvider<
          List<VideoEvent>,
          List<VideoEvent>,
          List<VideoEvent>
        >
    with $Provider<List<VideoEvent>> {
  /// Provider to get editor's picks
  EditorsPicksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorsPicksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorsPicksHash();

  @$internal
  @override
  $ProviderElement<List<VideoEvent>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<VideoEvent> create(Ref ref) {
    return editorsPicks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$editorsPicksHash() => r'47f6f4c73a8e2f6f8aafa718986c063feb530d08';

/// Provider for analytics-based trending videos with cursor pagination

@ProviderFor(AnalyticsTrending)
final analyticsTrendingProvider = AnalyticsTrendingProvider._();

/// Provider for analytics-based trending videos with cursor pagination
final class AnalyticsTrendingProvider
    extends $NotifierProvider<AnalyticsTrending, List<VideoEvent>> {
  /// Provider for analytics-based trending videos with cursor pagination
  AnalyticsTrendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsTrendingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsTrendingHash();

  @$internal
  @override
  AnalyticsTrending create() => AnalyticsTrending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsTrendingHash() => r'5f350bca12baa278295901c155736d8bf63a8822';

/// Provider for analytics-based trending videos with cursor pagination

abstract class _$AnalyticsTrending extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider for analytics-based popular videos

@ProviderFor(AnalyticsPopular)
final analyticsPopularProvider = AnalyticsPopularProvider._();

/// Provider for analytics-based popular videos
final class AnalyticsPopularProvider
    extends $NotifierProvider<AnalyticsPopular, List<VideoEvent>> {
  /// Provider for analytics-based popular videos
  AnalyticsPopularProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsPopularProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsPopularHash();

  @$internal
  @override
  AnalyticsPopular create() => AnalyticsPopular();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<VideoEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<VideoEvent>>(value),
    );
  }
}

String _$analyticsPopularHash() => r'0b9ba30c3115d2a1df6e7e33c39f3fd4f9af428c';

/// Provider for analytics-based popular videos

abstract class _$AnalyticsPopular extends $Notifier<List<VideoEvent>> {
  List<VideoEvent> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<VideoEvent>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<VideoEvent>, List<VideoEvent>>,
              List<VideoEvent>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider for trending hashtags

@ProviderFor(TrendingHashtags)
final trendingHashtagsProvider = TrendingHashtagsProvider._();

/// Provider for trending hashtags
final class TrendingHashtagsProvider
    extends $AsyncNotifierProvider<TrendingHashtags, List<TrendingHashtag>> {
  /// Provider for trending hashtags
  TrendingHashtagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendingHashtagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendingHashtagsHash();

  @$internal
  @override
  TrendingHashtags create() => TrendingHashtags();
}

String _$trendingHashtagsHash() => r'dea971920d5b8852fc6679f9f386c3a3c63c4d35';

/// Provider for trending hashtags

abstract class _$TrendingHashtags
    extends $AsyncNotifier<List<TrendingHashtag>> {
  FutureOr<List<TrendingHashtag>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<TrendingHashtag>>, List<TrendingHashtag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TrendingHashtag>>,
                List<TrendingHashtag>
              >,
              AsyncValue<List<TrendingHashtag>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
