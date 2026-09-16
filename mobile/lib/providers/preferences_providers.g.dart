// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Audio sharing preference service for managing whether audio is available
/// for reuse by default. keepAlive ensures setting persists across widget rebuilds.

@ProviderFor(audioSharingPreferenceService)
final audioSharingPreferenceServiceProvider =
    AudioSharingPreferenceServiceProvider._();

/// Audio sharing preference service for managing whether audio is available
/// for reuse by default. keepAlive ensures setting persists across widget rebuilds.

final class AudioSharingPreferenceServiceProvider
    extends
        $FunctionalProvider<
          AudioSharingPreferenceService,
          AudioSharingPreferenceService,
          AudioSharingPreferenceService
        >
    with $Provider<AudioSharingPreferenceService> {
  /// Audio sharing preference service for managing whether audio is available
  /// for reuse by default. keepAlive ensures setting persists across widget rebuilds.
  AudioSharingPreferenceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioSharingPreferenceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioSharingPreferenceServiceHash();

  @$internal
  @override
  $ProviderElement<AudioSharingPreferenceService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioSharingPreferenceService create(Ref ref) {
    return audioSharingPreferenceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioSharingPreferenceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioSharingPreferenceService>(
        value,
      ),
    );
  }
}

String _$audioSharingPreferenceServiceHash() =>
    r'e63c48c60864949925db6eeed76f7e8a67e5444a';

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.

@ProviderFor(audioDevicePreferenceService)
final audioDevicePreferenceServiceProvider =
    AudioDevicePreferenceServiceProvider._();

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.

final class AudioDevicePreferenceServiceProvider
    extends
        $FunctionalProvider<
          AudioDevicePreferenceService,
          AudioDevicePreferenceService,
          AudioDevicePreferenceService
        >
    with $Provider<AudioDevicePreferenceService> {
  /// Audio device preference service for managing the preferred input device
  /// for recording on macOS. keepAlive ensures preference persists.
  AudioDevicePreferenceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioDevicePreferenceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioDevicePreferenceServiceHash();

  @$internal
  @override
  $ProviderElement<AudioDevicePreferenceService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioDevicePreferenceService create(Ref ref) {
    return audioDevicePreferenceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioDevicePreferenceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioDevicePreferenceService>(value),
    );
  }
}

String _$audioDevicePreferenceServiceHash() =>
    r'cd3fc12de7e106a47976b9726f8626aa9dd523a9';

/// Language preference service for managing the user's preferred content
/// language. Used for NIP-32 self-labeling on published video events.
/// keepAlive ensures setting persists across widget rebuilds.

@ProviderFor(languagePreferenceService)
final languagePreferenceServiceProvider = LanguagePreferenceServiceProvider._();

/// Language preference service for managing the user's preferred content
/// language. Used for NIP-32 self-labeling on published video events.
/// keepAlive ensures setting persists across widget rebuilds.

final class LanguagePreferenceServiceProvider
    extends
        $FunctionalProvider<
          LanguagePreferenceService,
          LanguagePreferenceService,
          LanguagePreferenceService
        >
    with $Provider<LanguagePreferenceService> {
  /// Language preference service for managing the user's preferred content
  /// language. Used for NIP-32 self-labeling on published video events.
  /// keepAlive ensures setting persists across widget rebuilds.
  LanguagePreferenceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languagePreferenceServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$languagePreferenceServiceHash();

  @$internal
  @override
  $ProviderElement<LanguagePreferenceService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LanguagePreferenceService create(Ref ref) {
    return languagePreferenceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LanguagePreferenceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LanguagePreferenceService>(value),
    );
  }
}

String _$languagePreferenceServiceHash() =>
    r'97066a39a87e568a25bf048686701348e237bdaa';

/// Rebuild trigger for consumers that need the latest content-language
/// preference in request parameters.
///
/// The subscription is installed once per provider lifetime; a notification
/// publishes the next version to this notifier's state instead of rebuilding
/// the provider. Kept alive so the subscription survives while no consumer
/// is mounted.

@ProviderFor(LanguagePreferenceVersionNotifier)
final languagePreferenceVersionProvider =
    LanguagePreferenceVersionNotifierProvider._();

/// Rebuild trigger for consumers that need the latest content-language
/// preference in request parameters.
///
/// The subscription is installed once per provider lifetime; a notification
/// publishes the next version to this notifier's state instead of rebuilding
/// the provider. Kept alive so the subscription survives while no consumer
/// is mounted.
final class LanguagePreferenceVersionNotifierProvider
    extends $NotifierProvider<LanguagePreferenceVersionNotifier, int> {
  /// Rebuild trigger for consumers that need the latest content-language
  /// preference in request parameters.
  ///
  /// The subscription is installed once per provider lifetime; a notification
  /// publishes the next version to this notifier's state instead of rebuilding
  /// the provider. Kept alive so the subscription survives while no consumer
  /// is mounted.
  LanguagePreferenceVersionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languagePreferenceVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$languagePreferenceVersionNotifierHash();

  @$internal
  @override
  LanguagePreferenceVersionNotifier create() =>
      LanguagePreferenceVersionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$languagePreferenceVersionNotifierHash() =>
    r'597990e8f59b15a7ce877e01c6fe2f65e328db8a';

/// Rebuild trigger for consumers that need the latest content-language
/// preference in request parameters.
///
/// The subscription is installed once per provider lifetime; a notification
/// publishes the next version to this notifier's state instead of rebuilding
/// the provider. Kept alive so the subscription survives while no consumer
/// is mounted.

abstract class _$LanguagePreferenceVersionNotifier extends $Notifier<int> {
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
