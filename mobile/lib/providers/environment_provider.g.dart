// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'environment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the environment service singleton

@ProviderFor(environmentService)
final environmentServiceProvider = EnvironmentServiceProvider._();

/// Provider for the environment service singleton

final class EnvironmentServiceProvider
    extends
        $FunctionalProvider<
          EnvironmentService,
          EnvironmentService,
          EnvironmentService
        >
    with $Provider<EnvironmentService> {
  /// Provider for the environment service singleton
  EnvironmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'environmentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$environmentServiceHash();

  @$internal
  @override
  $ProviderElement<EnvironmentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EnvironmentService create(Ref ref) {
    return environmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnvironmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnvironmentService>(value),
    );
  }
}

String _$environmentServiceHash() =>
    r'838df3b92839b030c0bae0c59566ffe7ea45e2da';

/// Provider for current environment config that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new config to this notifier's state instead of rebuilding it.

@ProviderFor(CurrentEnvironmentNotifier)
final currentEnvironmentProvider = CurrentEnvironmentNotifierProvider._();

/// Provider for current environment config that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new config to this notifier's state instead of rebuilding it.
final class CurrentEnvironmentNotifierProvider
    extends $NotifierProvider<CurrentEnvironmentNotifier, EnvironmentConfig> {
  /// Provider for current environment config that publishes service changes.
  ///
  /// The subscription is installed once per provider lifetime; a notification
  /// assigns the new config to this notifier's state instead of rebuilding it.
  CurrentEnvironmentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentEnvironmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentEnvironmentNotifierHash();

  @$internal
  @override
  CurrentEnvironmentNotifier create() => CurrentEnvironmentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnvironmentConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnvironmentConfig>(value),
    );
  }
}

String _$currentEnvironmentNotifierHash() =>
    r'e5beea53f71799096cbed281c9efd69cb29593d8';

/// Provider for current environment config that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new config to this notifier's state instead of rebuilding it.

abstract class _$CurrentEnvironmentNotifier
    extends $Notifier<EnvironmentConfig> {
  EnvironmentConfig build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EnvironmentConfig, EnvironmentConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EnvironmentConfig, EnvironmentConfig>,
              EnvironmentConfig,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider for developer mode state that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new value to this notifier's state instead of rebuilding it.

@ProviderFor(IsDeveloperModeEnabledNotifier)
final isDeveloperModeEnabledProvider =
    IsDeveloperModeEnabledNotifierProvider._();

/// Provider for developer mode state that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new value to this notifier's state instead of rebuilding it.
final class IsDeveloperModeEnabledNotifierProvider
    extends $NotifierProvider<IsDeveloperModeEnabledNotifier, bool> {
  /// Provider for developer mode state that publishes service changes.
  ///
  /// The subscription is installed once per provider lifetime; a notification
  /// assigns the new value to this notifier's state instead of rebuilding it.
  IsDeveloperModeEnabledNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDeveloperModeEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDeveloperModeEnabledNotifierHash();

  @$internal
  @override
  IsDeveloperModeEnabledNotifier create() => IsDeveloperModeEnabledNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDeveloperModeEnabledNotifierHash() =>
    r'123b0c2d4f8354a65c6daf1f9324b023097332fd';

/// Provider for developer mode state that publishes service changes.
///
/// The subscription is installed once per provider lifetime; a notification
/// assigns the new value to this notifier's state instead of rebuilding it.

abstract class _$IsDeveloperModeEnabledNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Provider to check if showing environment indicator

@ProviderFor(showEnvironmentIndicator)
final showEnvironmentIndicatorProvider = ShowEnvironmentIndicatorProvider._();

/// Provider to check if showing environment indicator

final class ShowEnvironmentIndicatorProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if showing environment indicator
  ShowEnvironmentIndicatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showEnvironmentIndicatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showEnvironmentIndicatorHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return showEnvironmentIndicator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showEnvironmentIndicatorHash() =>
    r'69c75f591b9b3b88074e4b405b422892bc4eaa0a';
