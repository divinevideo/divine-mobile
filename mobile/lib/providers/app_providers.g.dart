// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Connection status service for monitoring network connectivity

@ProviderFor(connectionStatusService)
const connectionStatusServiceProvider = ConnectionStatusServiceProvider._();

/// Connection status service for monitoring network connectivity

final class ConnectionStatusServiceProvider
    extends
        $FunctionalProvider<
          ConnectionStatusService,
          ConnectionStatusService,
          ConnectionStatusService
        >
    with $Provider<ConnectionStatusService> {
  /// Connection status service for monitoring network connectivity
  const ConnectionStatusServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionStatusServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStatusServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectionStatusService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionStatusService create(Ref ref) {
    return connectionStatusService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionStatusService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionStatusService>(value),
    );
  }
}

String _$connectionStatusServiceHash() =>
    r'996c945a4e09628f52d45da659e79a2529d58bcb';

/// Relay capability service for detecting NIP-11 divine extensions

@ProviderFor(relayCapabilityService)
const relayCapabilityServiceProvider = RelayCapabilityServiceProvider._();

/// Relay capability service for detecting NIP-11 divine extensions

final class RelayCapabilityServiceProvider
    extends
        $FunctionalProvider<
          RelayCapabilityService,
          RelayCapabilityService,
          RelayCapabilityService
        >
    with $Provider<RelayCapabilityService> {
  /// Relay capability service for detecting NIP-11 divine extensions
  const RelayCapabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayCapabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayCapabilityServiceHash();

  @$internal
  @override
  $ProviderElement<RelayCapabilityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayCapabilityService create(Ref ref) {
    return relayCapabilityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayCapabilityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayCapabilityService>(value),
    );
  }
}

String _$relayCapabilityServiceHash() =>
    r'4d91346a2bc7573b977898ea944d9b85fc3f1ecf';

/// Video filter builder for constructing relay-aware filters with server-side sorting

@ProviderFor(videoFilterBuilder)
const videoFilterBuilderProvider = VideoFilterBuilderProvider._();

/// Video filter builder for constructing relay-aware filters with server-side sorting

final class VideoFilterBuilderProvider
    extends
        $FunctionalProvider<
          VideoFilterBuilder,
          VideoFilterBuilder,
          VideoFilterBuilder
        >
    with $Provider<VideoFilterBuilder> {
  /// Video filter builder for constructing relay-aware filters with server-side sorting
  const VideoFilterBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFilterBuilderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFilterBuilderHash();

  @$internal
  @override
  $ProviderElement<VideoFilterBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoFilterBuilder create(Ref ref) {
    return videoFilterBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoFilterBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoFilterBuilder>(value),
    );
  }
}

String _$videoFilterBuilderHash() =>
    r'fa2390a9274ddcc619886531d6cfa0671b545d1a';

/// Video visibility manager for controlling video playback based on visibility

@ProviderFor(videoVisibilityManager)
const videoVisibilityManagerProvider = VideoVisibilityManagerProvider._();

/// Video visibility manager for controlling video playback based on visibility

final class VideoVisibilityManagerProvider
    extends
        $FunctionalProvider<
          VideoVisibilityManager,
          VideoVisibilityManager,
          VideoVisibilityManager
        >
    with $Provider<VideoVisibilityManager> {
  /// Video visibility manager for controlling video playback based on visibility
  const VideoVisibilityManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoVisibilityManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoVisibilityManagerHash();

  @$internal
  @override
  $ProviderElement<VideoVisibilityManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoVisibilityManager create(Ref ref) {
    return videoVisibilityManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoVisibilityManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoVisibilityManager>(value),
    );
  }
}

String _$videoVisibilityManagerHash() =>
    r'e1a7642e6cb5e4c1733981be738064df7c3c0a91';

/// Background activity manager singleton for tracking app foreground/background state

@ProviderFor(backgroundActivityManager)
const backgroundActivityManagerProvider = BackgroundActivityManagerProvider._();

/// Background activity manager singleton for tracking app foreground/background state

final class BackgroundActivityManagerProvider
    extends
        $FunctionalProvider<
          BackgroundActivityManager,
          BackgroundActivityManager,
          BackgroundActivityManager
        >
    with $Provider<BackgroundActivityManager> {
  /// Background activity manager singleton for tracking app foreground/background state
  const BackgroundActivityManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backgroundActivityManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backgroundActivityManagerHash();

  @$internal
  @override
  $ProviderElement<BackgroundActivityManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackgroundActivityManager create(Ref ref) {
    return backgroundActivityManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackgroundActivityManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackgroundActivityManager>(value),
    );
  }
}

String _$backgroundActivityManagerHash() =>
    r'4d3e0698e395bfb6f5b8459e9626b726a126376e';

/// Analytics service with opt-out support

@ProviderFor(analyticsService)
const analyticsServiceProvider = AnalyticsServiceProvider._();

/// Analytics service with opt-out support

final class AnalyticsServiceProvider
    extends
        $FunctionalProvider<
          AnalyticsService,
          AnalyticsService,
          AnalyticsService
        >
    with $Provider<AnalyticsService> {
  /// Analytics service with opt-out support
  const AnalyticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsServiceHash();

  @$internal
  @override
  $ProviderElement<AnalyticsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsService create(Ref ref) {
    return analyticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsService>(value),
    );
  }
}

String _$analyticsServiceHash() => r'8ce8c6be2430cd9f271eb66d8e7fe6fcfbae0154';

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild

@ProviderFor(ageVerificationService)
const ageVerificationServiceProvider = AgeVerificationServiceProvider._();

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild

final class AgeVerificationServiceProvider
    extends
        $FunctionalProvider<
          AgeVerificationService,
          AgeVerificationService,
          AgeVerificationService
        >
    with $Provider<AgeVerificationService> {
  /// Age verification service for content creation restrictions
  /// keepAlive ensures the service persists and maintains in-memory verification state
  /// even when widgets that watch it dispose and rebuild
  const AgeVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ageVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ageVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<AgeVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AgeVerificationService create(Ref ref) {
    return ageVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgeVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgeVerificationService>(value),
    );
  }
}

String _$ageVerificationServiceHash() =>
    r'e866f0341e541ba27ba2b4e4278ed4b35edb8d8b';

/// Geo-blocking service for regional compliance

@ProviderFor(geoBlockingService)
const geoBlockingServiceProvider = GeoBlockingServiceProvider._();

/// Geo-blocking service for regional compliance

final class GeoBlockingServiceProvider
    extends
        $FunctionalProvider<
          GeoBlockingService,
          GeoBlockingService,
          GeoBlockingService
        >
    with $Provider<GeoBlockingService> {
  /// Geo-blocking service for regional compliance
  const GeoBlockingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geoBlockingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geoBlockingServiceHash();

  @$internal
  @override
  $ProviderElement<GeoBlockingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GeoBlockingService create(Ref ref) {
    return geoBlockingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeoBlockingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeoBlockingService>(value),
    );
  }
}

String _$geoBlockingServiceHash() =>
    r'0475466204746fb8b4c6dd614847e3853d360d12';

/// Secure key storage service (foundational service)

@ProviderFor(secureKeyStorage)
const secureKeyStorageProvider = SecureKeyStorageProvider._();

/// Secure key storage service (foundational service)

final class SecureKeyStorageProvider
    extends
        $FunctionalProvider<
          SecureKeyStorage,
          SecureKeyStorage,
          SecureKeyStorage
        >
    with $Provider<SecureKeyStorage> {
  /// Secure key storage service (foundational service)
  const SecureKeyStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeyStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeyStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeyStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureKeyStorage create(Ref ref) {
    return secureKeyStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeyStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeyStorage>(value),
    );
  }
}

String _$secureKeyStorageHash() => r'853547d439994307884d2f47f3d9769daa0a1e96';

/// Web authentication service (for web platform only)

@ProviderFor(webAuthService)
const webAuthServiceProvider = WebAuthServiceProvider._();

/// Web authentication service (for web platform only)

final class WebAuthServiceProvider
    extends $FunctionalProvider<WebAuthService, WebAuthService, WebAuthService>
    with $Provider<WebAuthService> {
  /// Web authentication service (for web platform only)
  const WebAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webAuthServiceHash();

  @$internal
  @override
  $ProviderElement<WebAuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebAuthService create(Ref ref) {
    return webAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAuthService>(value),
    );
  }
}

String _$webAuthServiceHash() => r'53411c0f6a62bb9b59f90a0d7fc738a553a0b575';

/// Nostr key manager for cryptographic operations

@ProviderFor(nostrKeyManager)
const nostrKeyManagerProvider = NostrKeyManagerProvider._();

/// Nostr key manager for cryptographic operations

final class NostrKeyManagerProvider
    extends
        $FunctionalProvider<NostrKeyManager, NostrKeyManager, NostrKeyManager>
    with $Provider<NostrKeyManager> {
  /// Nostr key manager for cryptographic operations
  const NostrKeyManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrKeyManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrKeyManagerHash();

  @$internal
  @override
  $ProviderElement<NostrKeyManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NostrKeyManager create(Ref ref) {
    return nostrKeyManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrKeyManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrKeyManager>(value),
    );
  }
}

String _$nostrKeyManagerHash() => r'a0d67b6d79af5ecdc42bc6616542249200a24b64';

/// Profile cache service for persistent profile storage

@ProviderFor(profileCacheService)
const profileCacheServiceProvider = ProfileCacheServiceProvider._();

/// Profile cache service for persistent profile storage

final class ProfileCacheServiceProvider
    extends
        $FunctionalProvider<
          ProfileCacheService,
          ProfileCacheService,
          ProfileCacheService
        >
    with $Provider<ProfileCacheService> {
  /// Profile cache service for persistent profile storage
  const ProfileCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileCacheServiceHash();

  @$internal
  @override
  $ProviderElement<ProfileCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileCacheService create(Ref ref) {
    return profileCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileCacheService>(value),
    );
  }
}

String _$profileCacheServiceHash() =>
    r'2d81bd6aabd04896ce3f967da9c4c3cf99cb2824';

/// Hashtag cache service for persistent hashtag storage

@ProviderFor(hashtagCacheService)
const hashtagCacheServiceProvider = HashtagCacheServiceProvider._();

/// Hashtag cache service for persistent hashtag storage

final class HashtagCacheServiceProvider
    extends
        $FunctionalProvider<
          HashtagCacheService,
          HashtagCacheService,
          HashtagCacheService
        >
    with $Provider<HashtagCacheService> {
  /// Hashtag cache service for persistent hashtag storage
  const HashtagCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagCacheServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HashtagCacheService create(Ref ref) {
    return hashtagCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagCacheService>(value),
    );
  }
}

String _$hashtagCacheServiceHash() =>
    r'9cc0bce9cded786f95dc83e7bf6dbcbc2602e907';

/// Personal event cache service for ALL user's own events

@ProviderFor(personalEventCacheService)
const personalEventCacheServiceProvider = PersonalEventCacheServiceProvider._();

/// Personal event cache service for ALL user's own events

final class PersonalEventCacheServiceProvider
    extends
        $FunctionalProvider<
          PersonalEventCacheService,
          PersonalEventCacheService,
          PersonalEventCacheService
        >
    with $Provider<PersonalEventCacheService> {
  /// Personal event cache service for ALL user's own events
  const PersonalEventCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalEventCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalEventCacheServiceHash();

  @$internal
  @override
  $ProviderElement<PersonalEventCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalEventCacheService create(Ref ref) {
    return personalEventCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalEventCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalEventCacheService>(value),
    );
  }
}

String _$personalEventCacheServiceHash() =>
    r'72d305468d4e52c2b92b093fa583cb8b1ba20a29';

/// Seen videos service for tracking viewed content

@ProviderFor(seenVideosService)
const seenVideosServiceProvider = SeenVideosServiceProvider._();

/// Seen videos service for tracking viewed content

final class SeenVideosServiceProvider
    extends
        $FunctionalProvider<
          SeenVideosService,
          SeenVideosService,
          SeenVideosService
        >
    with $Provider<SeenVideosService> {
  /// Seen videos service for tracking viewed content
  const SeenVideosServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenVideosServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenVideosServiceHash();

  @$internal
  @override
  $ProviderElement<SeenVideosService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SeenVideosService create(Ref ref) {
    return seenVideosService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeenVideosService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeenVideosService>(value),
    );
  }
}

String _$seenVideosServiceHash() => r'74099bd4d859b446a3fc0cf1a7f416756a104e43';

/// Content blocklist service for filtering unwanted content from feeds

@ProviderFor(contentBlocklistService)
const contentBlocklistServiceProvider = ContentBlocklistServiceProvider._();

/// Content blocklist service for filtering unwanted content from feeds

final class ContentBlocklistServiceProvider
    extends
        $FunctionalProvider<
          ContentBlocklistService,
          ContentBlocklistService,
          ContentBlocklistService
        >
    with $Provider<ContentBlocklistService> {
  /// Content blocklist service for filtering unwanted content from feeds
  const ContentBlocklistServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentBlocklistServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentBlocklistServiceHash();

  @$internal
  @override
  $ProviderElement<ContentBlocklistService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContentBlocklistService create(Ref ref) {
    return contentBlocklistService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentBlocklistService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentBlocklistService>(value),
    );
  }
}

String _$contentBlocklistServiceHash() =>
    r'a05020e10b4402686d4630f99b020c4f0e58eab3';

/// NIP-05 service for username registration and verification

@ProviderFor(nip05Service)
const nip05ServiceProvider = Nip05ServiceProvider._();

/// NIP-05 service for username registration and verification

final class Nip05ServiceProvider
    extends $FunctionalProvider<Nip05Service, Nip05Service, Nip05Service>
    with $Provider<Nip05Service> {
  /// NIP-05 service for username registration and verification
  const Nip05ServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip05ServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip05ServiceHash();

  @$internal
  @override
  $ProviderElement<Nip05Service> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Nip05Service create(Ref ref) {
    return nip05Service(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip05Service value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip05Service>(value),
    );
  }
}

String _$nip05ServiceHash() => r'b7f7e1471a3783305bf1070cb64f1b95c4bdb516';

/// Draft storage service for persisting vine drafts

@ProviderFor(draftStorageService)
const draftStorageServiceProvider = DraftStorageServiceProvider._();

/// Draft storage service for persisting vine drafts

final class DraftStorageServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DraftStorageService>,
          DraftStorageService,
          FutureOr<DraftStorageService>
        >
    with
        $FutureModifier<DraftStorageService>,
        $FutureProvider<DraftStorageService> {
  /// Draft storage service for persisting vine drafts
  const DraftStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftStorageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftStorageServiceHash();

  @$internal
  @override
  $FutureProviderElement<DraftStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DraftStorageService> create(Ref ref) {
    return draftStorageService(ref);
  }
}

String _$draftStorageServiceHash() =>
    r'e4db2a5863ba06a6c634366edda6e724ea6c67f2';

/// Authentication service depends on secure key storage

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

/// Authentication service depends on secure key storage

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  /// Authentication service depends on secure key storage
  const AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'26555c9f1c9a9a0c322592b6425ac0a6808090d8';

/// Stream provider for reactive auth state changes
/// Widgets should watch this instead of authService.authState to get rebuilds

@ProviderFor(authStateStream)
const authStateStreamProvider = AuthStateStreamProvider._();

/// Stream provider for reactive auth state changes
/// Widgets should watch this instead of authService.authState to get rebuilds

final class AuthStateStreamProvider
    extends
        $FunctionalProvider<AsyncValue<AuthState>, AuthState, Stream<AuthState>>
    with $FutureModifier<AuthState>, $StreamProvider<AuthState> {
  /// Stream provider for reactive auth state changes
  /// Widgets should watch this instead of authService.authState to get rebuilds
  const AuthStateStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateStreamHash();

  @$internal
  @override
  $StreamProviderElement<AuthState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AuthState> create(Ref ref) {
    return authStateStream(ref);
  }
}

String _$authStateStreamHash() => r'bd5c1864e57cfd46c9676d3dc1fe3aa358c2a14b';

/// Core Nostr service with platform-aware embedded relay functionality and P2P capabilities

@ProviderFor(nostrService)
const nostrServiceProvider = NostrServiceProvider._();

/// Core Nostr service with platform-aware embedded relay functionality and P2P capabilities

final class NostrServiceProvider
    extends $FunctionalProvider<INostrService, INostrService, INostrService>
    with $Provider<INostrService> {
  /// Core Nostr service with platform-aware embedded relay functionality and P2P capabilities
  const NostrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrServiceHash();

  @$internal
  @override
  $ProviderElement<INostrService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  INostrService create(Ref ref) {
    return nostrService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(INostrService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<INostrService>(value),
    );
  }
}

String _$nostrServiceHash() => r'fcc6c77c9665ca4fe387f551b48517a756dffac6';

/// Subscription manager for centralized subscription management

@ProviderFor(subscriptionManager)
const subscriptionManagerProvider = SubscriptionManagerProvider._();

/// Subscription manager for centralized subscription management

final class SubscriptionManagerProvider
    extends
        $FunctionalProvider<
          SubscriptionManager,
          SubscriptionManager,
          SubscriptionManager
        >
    with $Provider<SubscriptionManager> {
  /// Subscription manager for centralized subscription management
  const SubscriptionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionManagerHash();

  @$internal
  @override
  $ProviderElement<SubscriptionManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionManager create(Ref ref) {
    return subscriptionManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionManager>(value),
    );
  }
}

String _$subscriptionManagerHash() =>
    r'b65a6978927d3004c6f841e0b80075f9db9645d2';

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager services

@ProviderFor(videoEventService)
const videoEventServiceProvider = VideoEventServiceProvider._();

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager services

final class VideoEventServiceProvider
    extends
        $FunctionalProvider<
          VideoEventService,
          VideoEventService,
          VideoEventService
        >
    with $Provider<VideoEventService> {
  /// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager services
  const VideoEventServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventServiceHash();

  @$internal
  @override
  $ProviderElement<VideoEventService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventService create(Ref ref) {
    return videoEventService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventService>(value),
    );
  }
}

String _$videoEventServiceHash() => r'731670bc432ff3ade2e1457649368db85fe77dad';

/// Hashtag service depends on Video event service and cache service

@ProviderFor(hashtagService)
const hashtagServiceProvider = HashtagServiceProvider._();

/// Hashtag service depends on Video event service and cache service

final class HashtagServiceProvider
    extends $FunctionalProvider<HashtagService, HashtagService, HashtagService>
    with $Provider<HashtagService> {
  /// Hashtag service depends on Video event service and cache service
  const HashtagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HashtagService create(Ref ref) {
    return hashtagService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagService>(value),
    );
  }
}

String _$hashtagServiceHash() => r'5cd38d3c2e8d78a6f7b74a72b650d79e28938fe4';

/// User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService

@ProviderFor(userProfileService)
const userProfileServiceProvider = UserProfileServiceProvider._();

/// User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService

final class UserProfileServiceProvider
    extends
        $FunctionalProvider<
          UserProfileService,
          UserProfileService,
          UserProfileService
        >
    with $Provider<UserProfileService> {
  /// User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService
  const UserProfileServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileServiceHash();

  @$internal
  @override
  $ProviderElement<UserProfileService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserProfileService create(Ref ref) {
    return userProfileService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserProfileService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserProfileService>(value),
    );
  }
}

String _$userProfileServiceHash() =>
    r'abc2ef09d33c40550c1bdaf52206aa650c5e97b5';

/// Social service depends on Nostr service, Auth service, and SubscriptionManager

@ProviderFor(socialService)
const socialServiceProvider = SocialServiceProvider._();

/// Social service depends on Nostr service, Auth service, and SubscriptionManager

final class SocialServiceProvider
    extends $FunctionalProvider<SocialService, SocialService, SocialService>
    with $Provider<SocialService> {
  /// Social service depends on Nostr service, Auth service, and SubscriptionManager
  const SocialServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialServiceHash();

  @$internal
  @override
  $ProviderElement<SocialService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SocialService create(Ref ref) {
    return socialService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialService>(value),
    );
  }
}

String _$socialServiceHash() => r'213dee56c5edc2193f20d68b36573570f28148a1';

/// Enhanced notification service with Nostr integration (lazy loaded)

@ProviderFor(notificationServiceEnhanced)
const notificationServiceEnhancedProvider =
    NotificationServiceEnhancedProvider._();

/// Enhanced notification service with Nostr integration (lazy loaded)

final class NotificationServiceEnhancedProvider
    extends
        $FunctionalProvider<
          NotificationServiceEnhanced,
          NotificationServiceEnhanced,
          NotificationServiceEnhanced
        >
    with $Provider<NotificationServiceEnhanced> {
  /// Enhanced notification service with Nostr integration (lazy loaded)
  const NotificationServiceEnhancedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceEnhancedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceEnhancedHash();

  @$internal
  @override
  $ProviderElement<NotificationServiceEnhanced> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationServiceEnhanced create(Ref ref) {
    return notificationServiceEnhanced(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationServiceEnhanced value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationServiceEnhanced>(value),
    );
  }
}

String _$notificationServiceEnhancedHash() =>
    r'70a0b1344beaf6934f1fd0007620aa0dccb5336e';

/// NIP-98 authentication service

@ProviderFor(nip98AuthService)
const nip98AuthServiceProvider = Nip98AuthServiceProvider._();

/// NIP-98 authentication service

final class Nip98AuthServiceProvider
    extends
        $FunctionalProvider<
          Nip98AuthService,
          Nip98AuthService,
          Nip98AuthService
        >
    with $Provider<Nip98AuthService> {
  /// NIP-98 authentication service
  const Nip98AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip98AuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip98AuthServiceHash();

  @$internal
  @override
  $ProviderElement<Nip98AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Nip98AuthService create(Ref ref) {
    return nip98AuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip98AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip98AuthService>(value),
    );
  }
}

String _$nip98AuthServiceHash() => r'cfc2e0a65e1dbd9c559886929257fa66a7afb1c6';

/// Blossom BUD-01 authentication service for age-restricted content

@ProviderFor(blossomAuthService)
const blossomAuthServiceProvider = BlossomAuthServiceProvider._();

/// Blossom BUD-01 authentication service for age-restricted content

final class BlossomAuthServiceProvider
    extends
        $FunctionalProvider<
          BlossomAuthService,
          BlossomAuthService,
          BlossomAuthService
        >
    with $Provider<BlossomAuthService> {
  /// Blossom BUD-01 authentication service for age-restricted content
  const BlossomAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blossomAuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blossomAuthServiceHash();

  @$internal
  @override
  $ProviderElement<BlossomAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlossomAuthService create(Ref ref) {
    return blossomAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlossomAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlossomAuthService>(value),
    );
  }
}

String _$blossomAuthServiceHash() =>
    r'e64f2eebfd131f289245c69c1c7dd4f0575bf85d';

/// Media authentication interceptor for handling 401 unauthorized responses

@ProviderFor(mediaAuthInterceptor)
const mediaAuthInterceptorProvider = MediaAuthInterceptorProvider._();

/// Media authentication interceptor for handling 401 unauthorized responses

final class MediaAuthInterceptorProvider
    extends
        $FunctionalProvider<
          MediaAuthInterceptor,
          MediaAuthInterceptor,
          MediaAuthInterceptor
        >
    with $Provider<MediaAuthInterceptor> {
  /// Media authentication interceptor for handling 401 unauthorized responses
  const MediaAuthInterceptorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaAuthInterceptorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaAuthInterceptorHash();

  @$internal
  @override
  $ProviderElement<MediaAuthInterceptor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaAuthInterceptor create(Ref ref) {
    return mediaAuthInterceptor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaAuthInterceptor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaAuthInterceptor>(value),
    );
  }
}

String _$mediaAuthInterceptorHash() =>
    r'adae18db875674843f6ced55608bb65a5ef7f445';

/// Blossom upload service (uses user-configured Blossom server)
/// Blossom upload service (uses user-configured Blossom server)

@ProviderFor(blossomUploadService)
const blossomUploadServiceProvider = BlossomUploadServiceProvider._();

/// Blossom upload service (uses user-configured Blossom server)
/// Blossom upload service (uses user-configured Blossom server)

final class BlossomUploadServiceProvider
    extends
        $FunctionalProvider<
          BlossomUploadService,
          BlossomUploadService,
          BlossomUploadService
        >
    with $Provider<BlossomUploadService> {
  /// Blossom upload service (uses user-configured Blossom server)
  /// Blossom upload service (uses user-configured Blossom server)
  const BlossomUploadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blossomUploadServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blossomUploadServiceHash();

  @$internal
  @override
  $ProviderElement<BlossomUploadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlossomUploadService create(Ref ref) {
    return blossomUploadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlossomUploadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlossomUploadService>(value),
    );
  }
}

String _$blossomUploadServiceHash() =>
    r'd57fa3ec36057b410664e0da59b8067e68bebade';

/// Upload manager uses only Blossom upload service

@ProviderFor(uploadManager)
const uploadManagerProvider = UploadManagerProvider._();

/// Upload manager uses only Blossom upload service

final class UploadManagerProvider
    extends $FunctionalProvider<UploadManager, UploadManager, UploadManager>
    with $Provider<UploadManager> {
  /// Upload manager uses only Blossom upload service
  const UploadManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uploadManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uploadManagerHash();

  @$internal
  @override
  $ProviderElement<UploadManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UploadManager create(Ref ref) {
    return uploadManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UploadManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UploadManager>(value),
    );
  }
}

String _$uploadManagerHash() => r'0c5355f45e237e8409b806088294fe3a96573249';

/// API service depends on auth service

@ProviderFor(apiService)
const apiServiceProvider = ApiServiceProvider._();

/// API service depends on auth service

final class ApiServiceProvider
    extends $FunctionalProvider<ApiService, ApiService, ApiService>
    with $Provider<ApiService> {
  /// API service depends on auth service
  const ApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiServiceHash();

  @$internal
  @override
  $ProviderElement<ApiService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiService create(Ref ref) {
    return apiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiService>(value),
    );
  }
}

String _$apiServiceHash() => r'a114c5e161b816881b395a10c90d043ef94c8de7';

/// Video event publisher depends on multiple services

@ProviderFor(videoEventPublisher)
const videoEventPublisherProvider = VideoEventPublisherProvider._();

/// Video event publisher depends on multiple services

final class VideoEventPublisherProvider
    extends
        $FunctionalProvider<
          VideoEventPublisher,
          VideoEventPublisher,
          VideoEventPublisher
        >
    with $Provider<VideoEventPublisher> {
  /// Video event publisher depends on multiple services
  const VideoEventPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventPublisherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventPublisherHash();

  @$internal
  @override
  $ProviderElement<VideoEventPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventPublisher create(Ref ref) {
    return videoEventPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventPublisher>(value),
    );
  }
}

String _$videoEventPublisherHash() =>
    r'c3075fa95de7b09347358e7c288d2c18c1d9e93a';

/// Curation Service - manages NIP-51 video curation sets

@ProviderFor(curationService)
const curationServiceProvider = CurationServiceProvider._();

/// Curation Service - manages NIP-51 video curation sets

final class CurationServiceProvider
    extends
        $FunctionalProvider<CurationService, CurationService, CurationService>
    with $Provider<CurationService> {
  /// Curation Service - manages NIP-51 video curation sets
  const CurationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curationServiceHash();

  @$internal
  @override
  $ProviderElement<CurationService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CurationService create(Ref ref) {
    return curationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurationService>(value),
    );
  }
}

String _$curationServiceHash() => r'890fd0efd8c105c46fa828ae679b1c6ff58964a5';

/// Content reporting service for NIP-56 compliance

@ProviderFor(contentReportingService)
const contentReportingServiceProvider = ContentReportingServiceProvider._();

/// Content reporting service for NIP-56 compliance

final class ContentReportingServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentReportingService>,
          ContentReportingService,
          FutureOr<ContentReportingService>
        >
    with
        $FutureModifier<ContentReportingService>,
        $FutureProvider<ContentReportingService> {
  /// Content reporting service for NIP-56 compliance
  const ContentReportingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentReportingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentReportingServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentReportingService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentReportingService> create(Ref ref) {
    return contentReportingService(ref);
  }
}

String _$contentReportingServiceHash() =>
    r'90600ce05c4cc607ee58bb9166d14fb5982b7430';

/// Curated list service for NIP-51 kind 30005 video lists

@ProviderFor(curatedListService)
const curatedListServiceProvider = CuratedListServiceProvider._();

/// Curated list service for NIP-51 kind 30005 video lists

final class CuratedListServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<CuratedListService>,
          CuratedListService,
          FutureOr<CuratedListService>
        >
    with
        $FutureModifier<CuratedListService>,
        $FutureProvider<CuratedListService> {
  /// Curated list service for NIP-51 kind 30005 video lists
  const CuratedListServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curatedListServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curatedListServiceHash();

  @$internal
  @override
  $FutureProviderElement<CuratedListService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CuratedListService> create(Ref ref) {
    return curatedListService(ref);
  }
}

String _$curatedListServiceHash() =>
    r'4cb1e31f4432938d5c0f9944a55dc52266d37c96';

/// User list service for NIP-51 kind 30000 people lists

@ProviderFor(userListService)
const userListServiceProvider = UserListServiceProvider._();

/// User list service for NIP-51 kind 30000 people lists

final class UserListServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserListService>,
          UserListService,
          FutureOr<UserListService>
        >
    with $FutureModifier<UserListService>, $FutureProvider<UserListService> {
  /// User list service for NIP-51 kind 30000 people lists
  const UserListServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userListServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userListServiceHash();

  @$internal
  @override
  $FutureProviderElement<UserListService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserListService> create(Ref ref) {
    return userListService(ref);
  }
}

String _$userListServiceHash() => r'1b006662ce4e9219818ed3870ed1ecf8f4a6e2fd';

/// Bookmark service for NIP-51 bookmarks

@ProviderFor(bookmarkService)
const bookmarkServiceProvider = BookmarkServiceProvider._();

/// Bookmark service for NIP-51 bookmarks

final class BookmarkServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookmarkService>,
          BookmarkService,
          FutureOr<BookmarkService>
        >
    with $FutureModifier<BookmarkService>, $FutureProvider<BookmarkService> {
  /// Bookmark service for NIP-51 bookmarks
  const BookmarkServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkServiceHash();

  @$internal
  @override
  $FutureProviderElement<BookmarkService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookmarkService> create(Ref ref) {
    return bookmarkService(ref);
  }
}

String _$bookmarkServiceHash() => r'76b3bef0f2b4f8ddd0f84feac179f7b3b62cdcab';

/// Mute service for NIP-51 mute lists

@ProviderFor(muteService)
const muteServiceProvider = MuteServiceProvider._();

/// Mute service for NIP-51 mute lists

final class MuteServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<MuteService>,
          MuteService,
          FutureOr<MuteService>
        >
    with $FutureModifier<MuteService>, $FutureProvider<MuteService> {
  /// Mute service for NIP-51 mute lists
  const MuteServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'muteServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$muteServiceHash();

  @$internal
  @override
  $FutureProviderElement<MuteService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MuteService> create(Ref ref) {
    return muteService(ref);
  }
}

String _$muteServiceHash() => r'43392295e4b533da11963085bd0afb4dae5ec3d7';

/// Video sharing service

@ProviderFor(videoSharingService)
const videoSharingServiceProvider = VideoSharingServiceProvider._();

/// Video sharing service

final class VideoSharingServiceProvider
    extends
        $FunctionalProvider<
          VideoSharingService,
          VideoSharingService,
          VideoSharingService
        >
    with $Provider<VideoSharingService> {
  /// Video sharing service
  const VideoSharingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSharingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSharingServiceHash();

  @$internal
  @override
  $ProviderElement<VideoSharingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoSharingService create(Ref ref) {
    return videoSharingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSharingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSharingService>(value),
    );
  }
}

String _$videoSharingServiceHash() =>
    r'143e8562ab0f2c7df911141f5fcc53ec13a5b82a';

/// Content deletion service for NIP-09 delete events

@ProviderFor(contentDeletionService)
const contentDeletionServiceProvider = ContentDeletionServiceProvider._();

/// Content deletion service for NIP-09 delete events

final class ContentDeletionServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentDeletionService>,
          ContentDeletionService,
          FutureOr<ContentDeletionService>
        >
    with
        $FutureModifier<ContentDeletionService>,
        $FutureProvider<ContentDeletionService> {
  /// Content deletion service for NIP-09 delete events
  const ContentDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDeletionServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentDeletionService> create(Ref ref) {
    return contentDeletionService(ref);
  }
}

String _$contentDeletionServiceHash() =>
    r'8594abe369924c5d080809e29ba7745da70450c0';

/// Account Deletion Service for NIP-62 Request to Vanish

@ProviderFor(accountDeletionService)
const accountDeletionServiceProvider = AccountDeletionServiceProvider._();

/// Account Deletion Service for NIP-62 Request to Vanish

final class AccountDeletionServiceProvider
    extends
        $FunctionalProvider<
          AccountDeletionService,
          AccountDeletionService,
          AccountDeletionService
        >
    with $Provider<AccountDeletionService> {
  /// Account Deletion Service for NIP-62 Request to Vanish
  const AccountDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionServiceHash();

  @$internal
  @override
  $ProviderElement<AccountDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDeletionService create(Ref ref) {
    return accountDeletionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDeletionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDeletionService>(value),
    );
  }
}

String _$accountDeletionServiceHash() =>
    r'659c0ee712559ba34e462dc9b236c40c80651240';

/// Broken video tracker service for filtering non-functional videos

@ProviderFor(brokenVideoTracker)
const brokenVideoTrackerProvider = BrokenVideoTrackerProvider._();

/// Broken video tracker service for filtering non-functional videos

final class BrokenVideoTrackerProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrokenVideoTracker>,
          BrokenVideoTracker,
          FutureOr<BrokenVideoTracker>
        >
    with
        $FutureModifier<BrokenVideoTracker>,
        $FutureProvider<BrokenVideoTracker> {
  /// Broken video tracker service for filtering non-functional videos
  const BrokenVideoTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brokenVideoTrackerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brokenVideoTrackerHash();

  @$internal
  @override
  $FutureProviderElement<BrokenVideoTracker> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BrokenVideoTracker> create(Ref ref) {
    return brokenVideoTracker(ref);
  }
}

String _$brokenVideoTrackerHash() =>
    r'36268bd477659a229f13da325ac23403a20e7fa7';

/// Bug report service for collecting diagnostics and sending encrypted reports

@ProviderFor(bugReportService)
const bugReportServiceProvider = BugReportServiceProvider._();

/// Bug report service for collecting diagnostics and sending encrypted reports

final class BugReportServiceProvider
    extends
        $FunctionalProvider<
          BugReportService,
          BugReportService,
          BugReportService
        >
    with $Provider<BugReportService> {
  /// Bug report service for collecting diagnostics and sending encrypted reports
  const BugReportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bugReportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bugReportServiceHash();

  @$internal
  @override
  $ProviderElement<BugReportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BugReportService create(Ref ref) {
    return bugReportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BugReportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BugReportService>(value),
    );
  }
}

String _$bugReportServiceHash() => r'250a5fce245b0ddfe83986b90719d24bff84b58a';
