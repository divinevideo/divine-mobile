// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_events_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for NostrClient instance (Video Events specific)

@ProviderFor(videoEventsNostrService)
final videoEventsNostrServiceProvider = VideoEventsNostrServiceProvider._();

/// Provider for NostrClient instance (Video Events specific)

final class VideoEventsNostrServiceProvider
    extends $FunctionalProvider<NostrClient, NostrClient, NostrClient>
    with $Provider<NostrClient> {
  /// Provider for NostrClient instance (Video Events specific)
  VideoEventsNostrServiceProvider._()
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
  $ProviderElement<NostrClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NostrClient create(Ref ref) {
    return videoEventsNostrService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrClient>(value),
    );
  }
}

String _$videoEventsNostrServiceHash() =>
    r'32b1a6239692ba30de39f752aa66dc385ff69f0e';

/// Provider for SubscriptionManager instance (Video Events specific)

@ProviderFor(videoEventsSubscriptionManager)
final videoEventsSubscriptionManagerProvider =
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
  VideoEventsSubscriptionManagerProvider._()
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
final videoEventsProvider = VideoEventsProvider._();

/// Stream provider for video events from Nostr
final class VideoEventsProvider
    extends $StreamNotifierProvider<VideoEvents, List<VideoEvent>> {
  /// Stream provider for video events from Nostr
  VideoEventsProvider._()
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

String _$videoEventsHash() => r'ecd9cc094f3147b0edeecd71e77c57bc376b4b09';

/// Stream provider for video events from Nostr

abstract class _$VideoEvents extends $StreamNotifier<List<VideoEvent>> {
  Stream<List<VideoEvent>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}

/// Provider to check if video events are loading

@ProviderFor(videoEventsLoading)
final videoEventsLoadingProvider = VideoEventsLoadingProvider._();

/// Provider to check if video events are loading

final class VideoEventsLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if video events are loading
  VideoEventsLoadingProvider._()
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
final videoEventCountProvider = VideoEventCountProvider._();

/// Provider to get video event count

final class VideoEventCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get video event count
  VideoEventCountProvider._()
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
final bufferedVideoCountProvider = BufferedVideoCountProvider._();

/// State provider for buffered video count
final class BufferedVideoCountProvider
    extends $NotifierProvider<BufferedVideoCount, int> {
  /// State provider for buffered video count
  BufferedVideoCountProvider._()
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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
