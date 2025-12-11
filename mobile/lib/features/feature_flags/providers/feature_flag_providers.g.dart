// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Build configuration provider

@ProviderFor(buildConfiguration)
const buildConfigurationProvider = BuildConfigurationProvider._();

/// Build configuration provider

final class BuildConfigurationProvider
    extends
        $FunctionalProvider<
          BuildConfiguration,
          BuildConfiguration,
          BuildConfiguration
        >
    with $Provider<BuildConfiguration> {
  /// Build configuration provider
  const BuildConfigurationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'buildConfigurationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$buildConfigurationHash();

  @$internal
  @override
  $ProviderElement<BuildConfiguration> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BuildConfiguration create(Ref ref) {
    return buildConfiguration(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BuildConfiguration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BuildConfiguration>(value),
    );
  }
}

String _$buildConfigurationHash() =>
    r'a62d4699f2242a50e8b591df8d9c62496bbb0123';

/// Feature flag service provider

@ProviderFor(featureFlagService)
const featureFlagServiceProvider = FeatureFlagServiceProvider._();

/// Feature flag service provider

final class FeatureFlagServiceProvider
    extends
        $FunctionalProvider<
          FeatureFlagService,
          FeatureFlagService,
          FeatureFlagService
        >
    with $Provider<FeatureFlagService> {
  /// Feature flag service provider
  const FeatureFlagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagServiceHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagService create(Ref ref) {
    return featureFlagService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagService>(value),
    );
  }
}

String _$featureFlagServiceHash() =>
    r'f46cff92b5b08bd9517ffa18792018ed99b9350c';

/// Feature flag state provider (reactive to service changes)

@ProviderFor(featureFlagState)
const featureFlagStateProvider = FeatureFlagStateProvider._();

/// Feature flag state provider (reactive to service changes)

final class FeatureFlagStateProvider
    extends
        $FunctionalProvider<
          Map<FeatureFlag, bool>,
          Map<FeatureFlag, bool>,
          Map<FeatureFlag, bool>
        >
    with $Provider<Map<FeatureFlag, bool>> {
  /// Feature flag state provider (reactive to service changes)
  const FeatureFlagStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagStateHash();

  @$internal
  @override
  $ProviderElement<Map<FeatureFlag, bool>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<FeatureFlag, bool> create(Ref ref) {
    return featureFlagState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<FeatureFlag, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<FeatureFlag, bool>>(value),
    );
  }
}

String _$featureFlagStateHash() => r'bf39490bff4b6cb74fd70fff0c499635669fef8d';

/// Individual feature flag check provider family

@ProviderFor(isFeatureEnabled)
const isFeatureEnabledProvider = IsFeatureEnabledFamily._();

/// Individual feature flag check provider family

final class IsFeatureEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Individual feature flag check provider family
  const IsFeatureEnabledProvider._({
    required IsFeatureEnabledFamily super.from,
    required FeatureFlag super.argument,
  }) : super(
         retry: null,
         name: r'isFeatureEnabledProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFeatureEnabledHash();

  @override
  String toString() {
    return r'isFeatureEnabledProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as FeatureFlag;
    return isFeatureEnabled(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsFeatureEnabledProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFeatureEnabledHash() => r'706cae00a5cf7bf715bcb31deb6840a98727e80e';

/// Individual feature flag check provider family

final class IsFeatureEnabledFamily extends $Family
    with $FunctionalFamilyOverride<bool, FeatureFlag> {
  const IsFeatureEnabledFamily._()
    : super(
        retry: null,
        name: r'isFeatureEnabledProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Individual feature flag check provider family

  IsFeatureEnabledProvider call(FeatureFlag flag) =>
      IsFeatureEnabledProvider._(argument: flag, from: this);

  @override
  String toString() => r'isFeatureEnabledProvider';
}
