// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_events_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for NostrService instance (Video Events specific)

@ProviderFor(videoEventsNostrService)
const videoEventsNostrServiceProvider = VideoEventsNostrServiceProvider._();

/// Provider for NostrService instance (Video Events specific)

final class VideoEventsNostrServiceProvider
    extends $FunctionalProvider<INostrService, INostrService, INostrService>
    with $Provider<INostrService> {
  /// Provider for NostrService instance (Video Events specific)
  const VideoEventsNostrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventsNostrServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventsNostrServiceHash();

  @$internal
  @override
  $ProviderElement<INostrService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  INostrService create(Ref ref) {
    return videoEventsNostrService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(INostrService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<INostrService>(value),
    );
  }
}

String _$videoEventsNostrServiceHash() =>
    r'04277d1a60fe84fec2e2c0e25e06300b39d64f24';

/// Provider for SubscriptionManager instance (Video Events specific)

@ProviderFor(videoEventsSubscriptionManager)
const videoEventsSubscriptionManagerProvider =
    VideoEventsSubscriptionManagerProvider._();

/// Provider for SubscriptionManager instance (Video Events specific)

final class VideoEventsSubscriptionManagerProvider
    extends
        $FunctionalProvider<
          SubscriptionManager,
          SubscriptionManager,
          SubscriptionManager
        >
    with $Provider<SubscriptionManager> {
  /// Provider for SubscriptionManager instance (Video Events specific)
  const VideoEventsSubscriptionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventsSubscriptionManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventsSubscriptionManagerHash();

  @$internal
  @override
  $ProviderElement<SubscriptionManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionManager create(Ref ref) {
    return videoEventsSubscriptionManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionManager>(value),
    );
  }
}

String _$videoEventsSubscriptionManagerHash() =>
    r'b316afd0b391f09b481040d69432fd9e88fe15ae';

/// Stream provider for video events from Nostr

@ProviderFor(VideoEvents)
const videoEventsProvider = VideoEventsProvider._();

/// Stream provider for video events from Nostr
final class VideoEventsProvider
    extends $StreamNotifierProvider<VideoEvents, List<VideoEvent>> {
  /// Stream provider for video events from Nostr
  const VideoEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventsHash();

  @$internal
  @override
  VideoEvents create() => VideoEvents();
}

String _$videoEventsHash() => r'179e3697f619494be06ad93611cf09b2883f5504';

/// Stream provider for video events from Nostr

abstract class _$VideoEvents extends $StreamNotifier<List<VideoEvent>> {
  Stream<List<VideoEvent>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<VideoEvent>>, List<VideoEvent>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<VideoEvent>>, List<VideoEvent>>,
              AsyncValue<List<VideoEvent>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider to check if video events are loading

@ProviderFor(videoEventsLoading)
const videoEventsLoadingProvider = VideoEventsLoadingProvider._();

/// Provider to check if video events are loading

final class VideoEventsLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if video events are loading
  const VideoEventsLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventsLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventsLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return videoEventsLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$videoEventsLoadingHash() =>
    r'722f24635d8119c0b6611f2dd799443d50043f19';

/// Provider to get video event count

@ProviderFor(videoEventCount)
const videoEventCountProvider = VideoEventCountProvider._();

/// Provider to get video event count

final class VideoEventCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get video event count
  const VideoEventCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return videoEventCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$videoEventCountHash() => r'a46a7c75e516aa2022464dfb9a2ce1988729e413';

/// State provider for buffered video count

@ProviderFor(BufferedVideoCount)
const bufferedVideoCountProvider = BufferedVideoCountProvider._();

/// State provider for buffered video count
final class BufferedVideoCountProvider
    extends $NotifierProvider<BufferedVideoCount, int> {
  /// State provider for buffered video count
  const BufferedVideoCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bufferedVideoCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bufferedVideoCountHash();

  @$internal
  @override
  BufferedVideoCount create() => BufferedVideoCount();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$bufferedVideoCountHash() =>
    r'acdc25c0197ca4a6d46c82d545eb3d258912733d';

/// State provider for buffered video count

abstract class _$BufferedVideoCount extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
