// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Build configuration provider

@ProviderFor(buildConfiguration)
final buildConfigurationProvider = BuildConfigurationProvider._();

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
  BuildConfigurationProvider._()
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

/// Feature flag service provider — kept alive so flag state survives navigation

@ProviderFor(featureFlagService)
final featureFlagServiceProvider = FeatureFlagServiceProvider._();

/// Feature flag service provider — kept alive so flag state survives navigation

final class FeatureFlagServiceProvider
    extends
        $FunctionalProvider<
          FeatureFlagService,
          FeatureFlagService,
          FeatureFlagService
        >
    with $Provider<FeatureFlagService> {
  /// Feature flag service provider — kept alive so flag state survives navigation
  FeatureFlagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagServiceProvider',
        isAutoDispose: false,
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
    r'3a216f823f891a7d0ea0a6f585ad08dd044e19fb';

/// Feature flag state provider that publishes service changes to its state.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new flags to this notifier's state instead of rebuilding it.

@ProviderFor(FeatureFlagStateNotifier)
final featureFlagStateProvider = FeatureFlagStateNotifierProvider._();

/// Feature flag state provider that publishes service changes to its state.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new flags to this notifier's state instead of rebuilding it.
final class FeatureFlagStateNotifierProvider
    extends
        $NotifierProvider<FeatureFlagStateNotifier, Map<FeatureFlag, bool>> {
  /// Feature flag state provider that publishes service changes to its state.
  ///
  /// The subscription is installed once per provider lifetime; a notification
  /// assigns the new flags to this notifier's state instead of rebuilding it.
  FeatureFlagStateNotifierProvider._()
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
  String debugGetCreateSourceHash() => _$featureFlagStateNotifierHash();

  @$internal
  @override
  FeatureFlagStateNotifier create() => FeatureFlagStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<FeatureFlag, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<FeatureFlag, bool>>(value),
    );
  }
}

String _$featureFlagStateNotifierHash() =>
    r'b790185313696e1056982e7115ff00fdd68a3ebf';

/// Feature flag state provider that publishes service changes to its state.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new flags to this notifier's state instead of rebuilding it.

abstract class _$FeatureFlagStateNotifier
    extends $Notifier<Map<FeatureFlag, bool>> {
  Map<FeatureFlag, bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<FeatureFlag, bool>, Map<FeatureFlag, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<FeatureFlag, bool>, Map<FeatureFlag, bool>>,
              Map<FeatureFlag, bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Individual feature flag check provider family

@ProviderFor(isFeatureEnabled)
final isFeatureEnabledProvider = IsFeatureEnabledFamily._();

/// Individual feature flag check provider family

final class IsFeatureEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Individual feature flag check provider family
  IsFeatureEnabledProvider._({
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
  IsFeatureEnabledFamily._()
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
