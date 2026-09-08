// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Blossom BUD-01 authentication service for age-restricted content

@ProviderFor(blossomAuthService)
final blossomAuthServiceProvider = BlossomAuthServiceProvider._();

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
  BlossomAuthServiceProvider._()
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
    r'18b397ce487844dd002ada34930c6ce08f0566f8';

/// Media authentication interceptor for handling 401 unauthorized responses

@ProviderFor(mediaAuthInterceptor)
final mediaAuthInterceptorProvider = MediaAuthInterceptorProvider._();

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
  MediaAuthInterceptorProvider._()
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
    r'91168d3b391f9274691b22a7c376b1a11ba98833';

/// Blossom upload service (uses user-configured Blossom server)

@ProviderFor(blossomUploadService)
final blossomUploadServiceProvider = BlossomUploadServiceProvider._();

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
  BlossomUploadServiceProvider._()
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
    r'6295420ba4f79375be8e906aa843dd2b6394877e';

/// Upload manager uses only Blossom upload service

@ProviderFor(uploadManager)
final uploadManagerProvider = UploadManagerProvider._();

/// Upload manager uses only Blossom upload service

final class UploadManagerProvider
    extends $FunctionalProvider<UploadManager, UploadManager, UploadManager>
    with $Provider<UploadManager> {
  /// Upload manager uses only Blossom upload service
  UploadManagerProvider._()
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

String _$uploadManagerHash() => r'72ec55a832fef6cf0fd3bb8f23aec505d2d0ead5';

/// API service depends on auth service and the current environment
/// (relay-manager URL is env-aware; watching keeps env switches applied)

@ProviderFor(apiService)
final apiServiceProvider = ApiServiceProvider._();

/// API service depends on auth service and the current environment
/// (relay-manager URL is env-aware; watching keeps env switches applied)

final class ApiServiceProvider
    extends $FunctionalProvider<ApiService, ApiService, ApiService>
    with $Provider<ApiService> {
  /// API service depends on auth service and the current environment
  /// (relay-manager URL is env-aware; watching keeps env switches applied)
  ApiServiceProvider._()
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

String _$apiServiceHash() => r'0fddb607412a0d082c7920f114735bc51a174ece';

/// Crosspost API client for Bluesky toggle settings

@ProviderFor(crosspostApiClient)
final crosspostApiClientProvider = CrosspostApiClientProvider._();

/// Crosspost API client for Bluesky toggle settings

final class CrosspostApiClientProvider
    extends
        $FunctionalProvider<
          CrosspostApiClient,
          CrosspostApiClient,
          CrosspostApiClient
        >
    with $Provider<CrosspostApiClient> {
  /// Crosspost API client for Bluesky toggle settings
  CrosspostApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crosspostApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crosspostApiClientHash();

  @$internal
  @override
  $ProviderElement<CrosspostApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrosspostApiClient create(Ref ref) {
    return crosspostApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrosspostApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrosspostApiClient>(value),
    );
  }
}

String _$crosspostApiClientHash() =>
    r'3c3771a323baade67d52ed7de2882fb42406ba56';

/// Repository for Bluesky toggle settings

@ProviderFor(blueskyCrosspostRepository)
final blueskyCrosspostRepositoryProvider =
    BlueskyCrosspostRepositoryProvider._();

/// Repository for Bluesky toggle settings

final class BlueskyCrosspostRepositoryProvider
    extends
        $FunctionalProvider<
          BlueskyCrosspostRepository,
          BlueskyCrosspostRepository,
          BlueskyCrosspostRepository
        >
    with $Provider<BlueskyCrosspostRepository> {
  /// Repository for Bluesky toggle settings
  BlueskyCrosspostRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blueskyCrosspostRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blueskyCrosspostRepositoryHash();

  @$internal
  @override
  $ProviderElement<BlueskyCrosspostRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BlueskyCrosspostRepository create(Ref ref) {
    return blueskyCrosspostRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BlueskyCrosspostRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BlueskyCrosspostRepository>(value),
    );
  }
}

String _$blueskyCrosspostRepositoryHash() =>
    r'b628946204b48356106b28c09485a54378b6aaea';

/// Crossposter service client for manual per-video crossposting

@ProviderFor(crossposterApiClient)
final crossposterApiClientProvider = CrossposterApiClientProvider._();

/// Crossposter service client for manual per-video crossposting

final class CrossposterApiClientProvider
    extends
        $FunctionalProvider<
          CrosspostingApiClient,
          CrosspostingApiClient,
          CrosspostingApiClient
        >
    with $Provider<CrosspostingApiClient> {
  /// Crossposter service client for manual per-video crossposting
  CrossposterApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crossposterApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crossposterApiClientHash();

  @$internal
  @override
  $ProviderElement<CrosspostingApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrosspostingApiClient create(Ref ref) {
    return crossposterApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrosspostingApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrosspostingApiClient>(value),
    );
  }
}

String _$crossposterApiClientHash() =>
    r'165cb3feea5400f51e48f9ce88a9049d817c78ff';

/// Audio playback service for sound playback during recording and preview
///
/// Used by the camera screen for lip-sync recording. Handles audio
/// loading, play/pause, and cleanup. Uses keepAlive to persist across
/// the session (not auto-disposed).

@ProviderFor(audioPlaybackService)
final audioPlaybackServiceProvider = AudioPlaybackServiceProvider._();

/// Audio playback service for sound playback during recording and preview
///
/// Used by the camera screen for lip-sync recording. Handles audio
/// loading, play/pause, and cleanup. Uses keepAlive to persist across
/// the session (not auto-disposed).

final class AudioPlaybackServiceProvider
    extends
        $FunctionalProvider<
          AudioPlaybackService,
          AudioPlaybackService,
          AudioPlaybackService
        >
    with $Provider<AudioPlaybackService> {
  /// Audio playback service for sound playback during recording and preview
  ///
  /// Used by the camera screen for lip-sync recording. Handles audio
  /// loading, play/pause, and cleanup. Uses keepAlive to persist across
  /// the session (not auto-disposed).
  AudioPlaybackServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlaybackServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlaybackServiceHash();

  @$internal
  @override
  $ProviderElement<AudioPlaybackService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlaybackService create(Ref ref) {
    return audioPlaybackService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlaybackService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlaybackService>(value),
    );
  }
}

String _$audioPlaybackServiceHash() =>
    r'dd192ad5fbcd8f4d42de658e409ef09f3c887f04';
