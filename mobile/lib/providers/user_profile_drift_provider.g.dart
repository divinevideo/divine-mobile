// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_drift_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream provider for a single user profile from Drift database
///
/// This replaces ~100 lines of manual cache management with simple reactive streams.
/// When profile is inserted/updated in database, all watchers auto-update.
///
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
/// profileAsync.when(
///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// );
/// ```

@ProviderFor(userProfile)
const userProfileProvider = UserProfileFamily._();

/// Stream provider for a single user profile from Drift database
///
/// This replaces ~100 lines of manual cache management with simple reactive streams.
/// When profile is inserted/updated in database, all watchers auto-update.
///
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
/// profileAsync.when(
///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// );
/// ```

final class UserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          Stream<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $StreamProvider<UserProfile?> {
  /// Stream provider for a single user profile from Drift database
  ///
  /// This replaces ~100 lines of manual cache management with simple reactive streams.
  /// When profile is inserted/updated in database, all watchers auto-update.
  ///
  /// Usage:
  /// ```dart
  /// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
  /// profileAsync.when(
  ///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
  ///   loading: () => CircularProgressIndicator(),
  ///   error: (e, s) => Text('Error: $e'),
  /// );
  /// ```
  const UserProfileProvider._({
    required UserProfileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @override
  String toString() {
    return r'userProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProfile?> create(Ref ref) {
    final argument = this.argument as String;
    return userProfile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userProfileHash() => r'ca51be8292095a34cb67a86482ee98e73d93bbad';

/// Stream provider for a single user profile from Drift database
///
/// This replaces ~100 lines of manual cache management with simple reactive streams.
/// When profile is inserted/updated in database, all watchers auto-update.
///
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
/// profileAsync.when(
///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// );
/// ```

final class UserProfileFamily extends $Family
    with $FunctionalFamilyOverride<Stream<UserProfile?>, String> {
  const UserProfileFamily._()
    : super(
        retry: null,
        name: r'userProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stream provider for a single user profile from Drift database
  ///
  /// This replaces ~100 lines of manual cache management with simple reactive streams.
  /// When profile is inserted/updated in database, all watchers auto-update.
  ///
  /// Usage:
  /// ```dart
  /// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
  /// profileAsync.when(
  ///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
  ///   loading: () => CircularProgressIndicator(),
  ///   error: (e, s) => Text('Error: $e'),
  /// );
  /// ```

  UserProfileProvider call(String pubkey) =>
      UserProfileProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'userProfileProvider';
}
