// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(liveNostrCodec)
final liveNostrCodecProvider = LiveNostrCodecProvider._();

final class LiveNostrCodecProvider
    extends $FunctionalProvider<LiveNostrCodec, LiveNostrCodec, LiveNostrCodec>
    with $Provider<LiveNostrCodec> {
  LiveNostrCodecProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveNostrCodecProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveNostrCodecHash();

  @$internal
  @override
  $ProviderElement<LiveNostrCodec> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LiveNostrCodec create(Ref ref) {
    return liveNostrCodec(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveNostrCodec value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveNostrCodec>(value),
    );
  }
}

String _$liveNostrCodecHash() => r'788598190414429d741c84903d3515893346acf1';

@ProviderFor(liveApiService)
final liveApiServiceProvider = LiveApiServiceProvider._();

final class LiveApiServiceProvider
    extends $FunctionalProvider<LiveApiService, LiveApiService, LiveApiService>
    with $Provider<LiveApiService> {
  LiveApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveApiServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveApiServiceHash();

  @$internal
  @override
  $ProviderElement<LiveApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LiveApiService create(Ref ref) {
    return liveApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveApiService>(value),
    );
  }
}

String _$liveApiServiceHash() => r'649a35ab4a7c409884287a7a74b8cce70ffeb8ff';

@ProviderFor(liveKitRoomService)
final liveKitRoomServiceProvider = LiveKitRoomServiceProvider._();

final class LiveKitRoomServiceProvider
    extends
        $FunctionalProvider<
          LiveKitRoomService,
          LiveKitRoomService,
          LiveKitRoomService
        >
    with $Provider<LiveKitRoomService> {
  LiveKitRoomServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveKitRoomServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveKitRoomServiceHash();

  @$internal
  @override
  $ProviderElement<LiveKitRoomService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveKitRoomService create(Ref ref) {
    return liveKitRoomService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveKitRoomService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveKitRoomService>(value),
    );
  }
}

String _$liveKitRoomServiceHash() =>
    r'dc7e09841e678d2cce4749f657cd9458dab67fc3';

@ProviderFor(liveRepository)
final liveRepositoryProvider = LiveRepositoryProvider._();

final class LiveRepositoryProvider
    extends $FunctionalProvider<LiveRepository, LiveRepository, LiveRepository>
    with $Provider<LiveRepository> {
  LiveRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveRepositoryHash();

  @$internal
  @override
  $ProviderElement<LiveRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LiveRepository create(Ref ref) {
    return liveRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveRepository>(value),
    );
  }
}

String _$liveRepositoryHash() => r'7cd238964675e702e1c0fe0b0117c5070b9bad39';

@ProviderFor(liveChatRepository)
final liveChatRepositoryProvider = LiveChatRepositoryProvider._();

final class LiveChatRepositoryProvider
    extends
        $FunctionalProvider<
          LiveChatRepository,
          LiveChatRepository,
          LiveChatRepository
        >
    with $Provider<LiveChatRepository> {
  LiveChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveChatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveChatRepositoryHash();

  @$internal
  @override
  $ProviderElement<LiveChatRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LiveChatRepository create(Ref ref) {
    return liveChatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveChatRepository>(value),
    );
  }
}

String _$liveChatRepositoryHash() =>
    r'39c1ee91d927e2fafcc4ba7dfe426d53ef8e69b6';
