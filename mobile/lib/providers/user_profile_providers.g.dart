// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userProfileReactive)
const userProfileReactiveProvider = UserProfileReactiveFamily._();

final class UserProfileReactiveProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          FutureOr<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $FutureProvider<UserProfile?> {
  const UserProfileReactiveProvider._({
    required UserProfileReactiveFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userProfileReactiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userProfileReactiveHash();

  @override
  String toString() {
    return r'userProfileReactiveProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return userProfileReactive(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileReactiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userProfileReactiveHash() =>
    r'7f0a97ea992b601f1b4205eae0131e1970dc1435';

final class UserProfileReactiveFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserProfile?>, String> {
  const UserProfileReactiveFamily._()
    : super(
        retry: null,
        name: r'userProfileReactiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserProfileReactiveProvider call(String pubkey) =>
      UserProfileReactiveProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'userProfileReactiveProvider';
}

/// Async provider for loading a single user profile
/// Delegates to UserProfileService which is the single source of truth

@ProviderFor(fetchUserProfile)
const fetchUserProfileProvider = FetchUserProfileFamily._();

/// Async provider for loading a single user profile
/// Delegates to UserProfileService which is the single source of truth

final class FetchUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          FutureOr<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $FutureProvider<UserProfile?> {
  /// Async provider for loading a single user profile
  /// Delegates to UserProfileService which is the single source of truth
  const FetchUserProfileProvider._({
    required FetchUserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchUserProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchUserProfileHash();

  @override
  String toString() {
    return r'fetchUserProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return fetchUserProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchUserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchUserProfileHash() => r'8fcb96c584b9590712ec8e1681ebae84e0f66627';

/// Async provider for loading a single user profile
/// Delegates to UserProfileService which is the single source of truth

final class FetchUserProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserProfile?>, String> {
  const FetchUserProfileFamily._()
    : super(
        retry: null,
        name: r'fetchUserProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Async provider for loading a single user profile
  /// Delegates to UserProfileService which is the single source of truth

  FetchUserProfileProvider call(String pubkey) =>
      FetchUserProfileProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchUserProfileProvider';
}

@ProviderFor(UserProfileNotifier)
const userProfileProvider = UserProfileNotifierProvider._();

final class UserProfileNotifierProvider
    extends $NotifierProvider<UserProfileNotifier, UserProfileState> {
  const UserProfileNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileNotifierHash();

  @$internal
  @override
  UserProfileNotifier create() => UserProfileNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserProfileState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserProfileState>(value),
    );
  }
}

String _$userProfileNotifierHash() =>
    r'66d6fbe940e477bbd08ecd5c0d1958ade072cbc8';

abstract class _$UserProfileNotifier extends $Notifier<UserProfileState> {
  UserProfileState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<UserProfileState, UserProfileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserProfileState, UserProfileState>,
              UserProfileState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
