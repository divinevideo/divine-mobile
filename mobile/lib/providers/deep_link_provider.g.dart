// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_link_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the deep link service
/// Note: Does NOT auto-initialize - caller must call initialize() after setting up listeners

@ProviderFor(deepLinkService)
const deepLinkServiceProvider = DeepLinkServiceProvider._();

/// Provider for the deep link service
/// Note: Does NOT auto-initialize - caller must call initialize() after setting up listeners

final class DeepLinkServiceProvider
    extends
        $FunctionalProvider<DeepLinkService, DeepLinkService, DeepLinkService>
    with $Provider<DeepLinkService> {
  /// Provider for the deep link service
  /// Note: Does NOT auto-initialize - caller must call initialize() after setting up listeners
  const DeepLinkServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepLinkServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepLinkServiceHash();

  @$internal
  @override
  $ProviderElement<DeepLinkService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeepLinkService create(Ref ref) {
    return deepLinkService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeepLinkService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeepLinkService>(value),
    );
  }
}

String _$deepLinkServiceHash() => r'e2448d07877558d988a553741b688eeeaaa32098';

/// Stream provider for incoming deep links

@ProviderFor(deepLinks)
const deepLinksProvider = DeepLinksProvider._();

/// Stream provider for incoming deep links

final class DeepLinksProvider
    extends
        $FunctionalProvider<AsyncValue<DeepLink>, DeepLink, Stream<DeepLink>>
    with $FutureModifier<DeepLink>, $StreamProvider<DeepLink> {
  /// Stream provider for incoming deep links
  const DeepLinksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepLinksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepLinksHash();

  @$internal
  @override
  $StreamProviderElement<DeepLink> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DeepLink> create(Ref ref) {
    return deepLinks(ref);
  }
}

String _$deepLinksHash() => r'8bd10dd6b603ca1ec5b3449493be0cafce4235ac';
