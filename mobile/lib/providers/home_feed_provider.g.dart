// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auto-refresh interval for home feed (10 minutes in production, overridable in tests)

@ProviderFor(homeFeedPollInterval)
const homeFeedPollIntervalProvider = HomeFeedPollIntervalProvider._();

/// Auto-refresh interval for home feed (10 minutes in production, overridable in tests)

final class HomeFeedPollIntervalProvider
    extends $FunctionalProvider<Duration, Duration, Duration>
    with $Provider<Duration> {
  /// Auto-refresh interval for home feed (10 minutes in production, overridable in tests)
  const HomeFeedPollIntervalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFeedPollIntervalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFeedPollIntervalHash();

  @$internal
  @override
  $ProviderElement<Duration> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Duration create(Ref ref) {
    return homeFeedPollInterval(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$homeFeedPollIntervalHash() =>
    r'6c71046a4cb805ce77cc4fd5138b9ab4ebf9d2f3';

/// Home feed provider - shows videos only from people you follow
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
/// - User pulls to refresh
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose

@ProviderFor(HomeFeed)
const homeFeedProvider = HomeFeedProvider._();

/// Home feed provider - shows videos only from people you follow
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
/// - User pulls to refresh
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose
final class HomeFeedProvider
    extends $AsyncNotifierProvider<HomeFeed, VideoFeedState> {
  /// Home feed provider - shows videos only from people you follow
  ///
  /// Rebuilds occur when:
  /// - Contact list changes (follow/unfollow)
  /// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
  /// - User pulls to refresh
  ///
  /// Timer lifecycle:
  /// - Starts when provider is first watched
  /// - Pauses when all listeners detach (ref.onCancel)
  /// - Resumes when a new listener attaches (ref.onResume)
  /// - Cancels on dispose
  const HomeFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFeedHash();

  @$internal
  @override
  HomeFeed create() => HomeFeed();
}

String _$homeFeedHash() => r'efd21a724442a234dd51a860fcf8d0b7410e40ee';

/// Home feed provider - shows videos only from people you follow
///
/// Rebuilds occur when:
/// - Contact list changes (follow/unfollow)
/// - Poll interval elapses (default 10 minutes, injectable via homeFeedPollIntervalProvider)
/// - User pulls to refresh
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose

abstract class _$HomeFeed extends $AsyncNotifier<VideoFeedState> {
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

/// Provider to check if home feed is loading

@ProviderFor(homeFeedLoading)
const homeFeedLoadingProvider = HomeFeedLoadingProvider._();

/// Provider to check if home feed is loading

final class HomeFeedLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if home feed is loading
  const HomeFeedLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFeedLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFeedLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return homeFeedLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$homeFeedLoadingHash() => r'e4c96dfd94b15fc125ecebf90f53a52a20081cd1';

/// Provider to get current home feed video count

@ProviderFor(homeFeedCount)
const homeFeedCountProvider = HomeFeedCountProvider._();

/// Provider to get current home feed video count

final class HomeFeedCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current home feed video count
  const HomeFeedCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeFeedCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeFeedCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return homeFeedCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$homeFeedCountHash() => r'fa005197b095b160691887155a79988cbc15f8d4';

/// Provider to check if we have home feed videos

@ProviderFor(hasHomeFeedVideos)
const hasHomeFeedVideosProvider = HasHomeFeedVideosProvider._();

/// Provider to check if we have home feed videos

final class HasHomeFeedVideosProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if we have home feed videos
  const HasHomeFeedVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasHomeFeedVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasHomeFeedVideosHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasHomeFeedVideos(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasHomeFeedVideosHash() => r'7785c6a7ebf4bc3bcd84129c6b1fda16e7f72edf';
